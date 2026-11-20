--!strict
-- Code doors (docs/09_GDD_V2.md §2.5). A vault room (Core/FloorGen) is shut by a steel door whose
-- three-digit code is painted on it in a way only a tape shows: film the door, watch the tape,
-- read the code, type it in. Wrong codes jam the lock for a moment. The code never leaves the
-- server except inside the viewing of a tape that framed the door (ShiftTapes).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local Framing = require(ReplicatedStorage.Shared.Core.Framing)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Tape = require(ReplicatedStorage.Shared.Core.Tape)

local ShiftDoors = {}

local CFG = Config.Shift
local DOOR_HEIGHT = 9
local HALF = FloorGen.DOOR_WIDTH / 2
-- How near the keypad a player must stand for an entry to count.
local KEYPAD_REACH = 14

type Door = {
	id: number,
	code: string,
	leaf: Part,
	centre: Vector3,
	open: boolean,
	wrong: number,
	jammedUntil: number,
}

local services: { [string]: any }
local doors: { Door } = {}
local nextId = 0
local entryLimit = RateLimit.new(1, 3)
-- Never the floor's own random: clients can rebuild a floor from its seed.
local codeRandom = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- Nothing solid between the lens and the door's face. The ray stops short of the leaf itself.
local function seesDoor(sample: Tape.Sample, door: Door): boolean
	local origin = Vector3.new(sample[1], sample[2], sample[3])
	local offset = door.centre - origin
	local distance = offset.Magnitude
	if distance < 2 then
		return true
	end
	return Workspace:Raycast(origin, offset.Unit * (distance - 1.5), rayParams) == nil
end

-- The closed doors a camera path framed and could see (in the cone, in range, no wall between,
-- at any sample), as { id, code } for a tape's viewing.
function ShiftDoors.framedBy(
	track: { Tape.Sample },
	cosHalfFov: number,
	range: number
): { { id: number, code: string } }
	local map = Workspace:FindFirstChild("Map")
	rayParams.FilterDescendantsInstances = if map then { map } else {}
	local found = {}
	for _, door in doors do
		if not door.open then
			local c = door.centre
			for _, s in track do
				if
					Framing.isFramed(
						s[1],
						s[2],
						s[3],
						s[4],
						s[5],
						s[6],
						c.X,
						c.Y,
						c.Z,
						cosHalfFov,
						range
					) and seesDoor(s, door)
				then
					table.insert(found, { id = door.id, code = door.code })
					break
				end
			end
		end
	end
	return found
end

local function keypad(parent: Instance, door: Door, x: number, z: number, along: boolean)
	local size = if along then Vector3.new(1, 1.4, 0.4) else Vector3.new(0.4, 1.4, 1)
	local box = Build.box(
		parent,
		"Keypad",
		x - size.X / 2,
		4,
		z - size.Z / 2,
		x + size.X / 2,
		4 + size.Y,
		z + size.Z / 2,
		Palette.Ink,
		Enum.Material.Metal
	)
	box:SetAttribute("DoorId", door.id)
	local lamp = Instance.new("PointLight")
	lamp.Color = Palette.Rec
	lamp.Range = 5
	lamp.Brightness = 0.8
	lamp.Parent = box
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter code"
	prompt.ObjectText = "Code lock"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("DoorId", door.id)
	prompt.Parent = box
	CollectionService:AddTag(prompt, "ShiftKeypad")
end

-- Builds the vault door of a new floor, if it has one, into the floor's folder.
function ShiftDoors.build(floor: FloorGen.Floor)
	doors = {}
	local vault = floor.vault
	local folder = services.ShiftWorld.floorFolder
	if not vault or not folder then
		return
	end
	nextId += 1
	local x, z, alongX = FloorGen.doorway(floor, vault.link)
	-- The leaf fills the doorway inside the wall's thickness, never flush with its faces.
	local leaf = if alongX
		then Build.box(
			folder,
			"CodeDoor",
			x - HALF,
			0,
			z - 0.3,
			x + HALF,
			DOOR_HEIGHT,
			z + 0.3,
			Palette.Metal,
			Enum.Material.DiamondPlate
		)
		else Build.box(
			folder,
			"CodeDoor",
			x - 0.3,
			0,
			z - HALF,
			x + 0.3,
			DOOR_HEIGHT,
			z + HALF,
			Palette.Metal,
			Enum.Material.DiamondPlate
		)
	leaf:SetAttribute("CodeDoorId", nextId)
	-- Where the code is painted. Blank to the eye; a viewing of a tape fills it in (client side).
	local faces = if alongX
		then { Enum.NormalId.Front, Enum.NormalId.Back }
		else { Enum.NormalId.Left, Enum.NormalId.Right }
	for _, face in faces do
		local stencil = Build.label(leaf, face, "", Palette.Rec)
		stencil.Name = "CodeText"
		stencil.Size = UDim2.fromScale(0.8, 0.22)
		stencil.Position = UDim2.fromScale(0.1, 0.3)
		local gui = stencil.Parent :: SurfaceGui
		gui.Name = "CodeGui"
		gui.LightInfluence = 0
		gui.Enabled = false
		local plate = Build.label(leaf, face, "ARCHIVE STORE  ·  CODE LOCK", Palette.Paper)
		plate.Size = UDim2.fromScale(0.9, 0.06)
		plate.Position = UDim2.fromScale(0.05, 0.08)
	end

	local door: Door = {
		id = nextId,
		code = `{codeRandom:NextInteger(0, 9)}{codeRandom:NextInteger(0, 9)}{codeRandom:NextInteger(
			0,
			9
		)}`,
		leaf = leaf,
		centre = Vector3.new(x, DOOR_HEIGHT / 2, z),
		open = false,
		wrong = 0,
		jammedUntil = 0,
	}
	table.insert(doors, door)
	-- A keypad beside the doorway on both sides, so it opens from whichever room you stand in.
	if alongX then
		keypad(folder, door, x + HALF + 1.2, z - 0.7, true)
		keypad(folder, door, x + HALF + 1.2, z + 0.7, true)
	else
		keypad(folder, door, x - 0.7, z + HALF + 1.2, false)
		keypad(folder, door, x + 0.7, z + HALF + 1.2, false)
	end
end

local function openDoor(door: Door)
	door.open = true
	local leaf = door.leaf
	leaf.CanQuery = false
	leaf.CanCollide = false
	local start = leaf.CFrame
	task.spawn(function()
		for step = 1, 20 do
			if not leaf.Parent then
				return
			end
			leaf.CFrame = start + Vector3.new(0, (DOOR_HEIGHT - 0.6) * step / 20, 0)
			task.wait(0.05)
		end
	end)
	for _, item in leaf.Parent and leaf.Parent:GetChildren() or {} do
		if item.Name == "Keypad" and item:GetAttribute("DoorId") == door.id then
			local prompt = item:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = false
			end
			local lamp = item:FindFirstChildOfClass("PointLight")
			if lamp then
				lamp.Color = Palette.Crt
			end
		end
	end
end

local function onEntry(player: Player, entry: unknown)
	if not entryLimit:allow(player, os.clock()) then
		return
	end
	local session = services.ShiftSession
	if session.shift.phase ~= "floor" or player:GetAttribute("OffFrame") == true then
		return
	end
	if typeof(entry) ~= "table" or #(entry :: { any }) ~= 3 then
		return
	end
	local digits = {}
	for index = 1, 3 do
		local digit = (entry :: { any })[index]
		if typeof(digit) ~= "number" or digit % 1 ~= 0 or digit < 0 or digit > 9 then
			return
		end
		digits[index] = tostring(digit)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local door: Door? = nil
	for _, candidate in doors do
		if (candidate.centre - root.Position).Magnitude <= KEYPAD_REACH then
			door = candidate
		end
	end
	if not door or door.open then
		return
	end
	local now = os.clock()
	if now < door.jammedUntil then
		session.tell(player, "The lock is jammed. Give it a moment.")
		return
	end
	if table.concat(digits) == door.code then
		openDoor(door)
		session.broadcast(`{player.DisplayName} opened the code door.`)
		services.ShiftQuests.event(player, "door")
		return
	end
	door.wrong += 1
	if door.wrong >= CFG.CodeTries then
		door.wrong = 0
		door.jammedUntil = now + CFG.CodeJamSeconds
		session.broadcast("Wrong code. The lock jammed.")
	else
		session.tell(player, "Wrong code. Watch a tape of the door: the code is only on tape.")
	end
end

function ShiftDoors.init(all: { [string]: any })
	services = all
	Net.get("CodeEntry").OnServerEvent:Connect(onEntry)
	Players.PlayerRemoving:Connect(function(player)
		entryLimit:forget(player)
	end)
end

return ShiftDoors
