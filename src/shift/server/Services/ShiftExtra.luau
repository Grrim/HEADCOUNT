--!strict
-- The Extra on a shift (Core/Extra, docs/09_GDD_V2.md §2.3, §2.8). From floor -2 it walks the
-- floor wearing a copy of a teammate's avatar (alone, your own): a real model everyone sees,
-- waving "this way". Through the lens clients draw what it really is (ExtraView).
--
-- When the team rides on and it was never filmed, it may board with them. The sign over the doors
-- counts it; in the cabin it reaches nobody, and filming it there wears it away like anywhere
-- else. Unfilmed, it steps out with the team onto the next floor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Extra = require(ReplicatedStorage.Shared.Core.Extra)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local Graph = require(ReplicatedStorage.Shared.Core.Graph)
local Net = require(ReplicatedStorage.Shared.Net)

local ShiftExtra = {}

local CFG = Config.Shift
local RULES: Extra.Config = CFG.Extra
local STEP = 0.1
-- Stock R15 animations: the walk, and the wave it beckons with.
local WALK_ANIM = "rbxassetid://507777826"
local WAVE_ANIM = "rbxassetid://507770239"
-- Where it stands in the cabin: a back corner, facing the doors.
local CABIN_SPOT = Vector3.new(4.2, 0, -10.2)

local services: { [string]: any }
local eventRemote: RemoteEvent
local layer: Folder
local random = Random.new()

local state: Extra.State? = nil
local graph: Graph.Graph = {}
local floorStart = ""
local running = false
local riding = false
local wakeAt = 0
local model: Model? = nil
local rootHeight = 3
local look: Player? = nil
local walkTrack: AnimationTrack? = nil
local waveTrack: AnimationTrack? = nil
local yaw = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function clearModel()
	if model then
		model:Destroy()
	end
	model = nil
	walkTrack = nil
	waveTrack = nil
	look = nil
end

local function loadTrack(animator: Animator, id: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	return if ok then loaded else nil
end

-- A copy of this player's avatar, with nothing in it that runs, collides or can be clicked.
local function dress(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or not copy then
		return false
	end
	clearModel()
	local clone = copy :: Model
	clone.Name = "Extra"
	for _, item in clone:GetDescendants() do
		if
			item:IsA("BaseScript")
			or item:IsA("ModuleScript")
			or item:IsA("Light")
			or item:IsA("Sound")
			or item:IsA("ForceField")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
			item.Anchored = false
		end
	end
	local root = clone:FindFirstChild("HumanoidRootPart")
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		clone:Destroy()
		return false
	end
	root.Anchored = true
	clone.PrimaryPart = root
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	-- Moved by hand every step; the humanoid must not try to fall, climb or stand it up.
	humanoid.EvaluateStateMachine = false
	rootHeight = if humanoid.RigType == Enum.HumanoidRigType.R6
		then 3
		else humanoid.HipHeight + root.Size.Y / 2
	clone:SetAttribute("Extra", true)
	clone:SetAttribute("Looks", player.UserId)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		walkTrack = loadTrack(animator, WALK_ANIM)
		waveTrack = loadTrack(animator, WAVE_ANIM)
	end
	clone.Parent = layer
	model = clone
	look = player
	return true
end

local function anyone(except: Player?): Player?
	local list = {}
	for _, player in Players:GetPlayers() do
		-- Never a cut player: their copy would come out see-through.
		if player ~= except and rootOf(player) and player:GetAttribute("OffFrame") ~= true then
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[random:NextInteger(1, #list)]
end

local function place(x: number, z: number)
	local current = model
	if current then
		current:PivotTo(CFrame.new(x, rootHeight, z) * CFrame.Angles(0, yaw, 0))
	end
end

local function play(track: AnimationTrack?, on: boolean, speed: number?)
	if not track then
		return
	end
	if on then
		if not track.IsPlaying then
			track:Play(0.2)
		end
		track:AdjustSpeed(speed or 1)
	elseif track.IsPlaying then
		track:Stop(0.2)
	end
end

local function face(fromX: number, fromZ: number, toX: number, toZ: number)
	local dx, dz = toX - fromX, toZ - fromZ
	if dx * dx + dz * dz > 0.01 then
		yaw = math.atan2(-dx, -dz)
	end
end

function ShiftExtra.stop()
	running = false
	riding = false
	state = nil
	clearModel()
	layer:SetAttribute("Riding", false)
end

-- True while it stands in the cabin with the team.
function ShiftExtra.inCabin(): boolean
	return riding and model ~= nil
end

-- The lift is leaving downwards: an unfilmed Extra may come along.
function ShiftExtra.depart()
	local current = state
	local boards = running
		and current ~= nil
		and current.phase ~= "gone"
		and random:NextNumber() < CFG.ExtraBoardChance
	running = false
	if not boards then
		ShiftExtra.stop()
		return
	end
	-- In the cabin it wears whoever it likes, and stands among them.
	local wearing = anyone(nil)
	if not wearing or not dress(wearing) then
		ShiftExtra.stop()
		return
	end
	riding = true
	layer:SetAttribute("Riding", true)
	local cabin: Graph.Graph = { cabin = { x = CABIN_SPOT.X, y = 0, z = CABIN_SPOT.Z, edges = {} } }
	graph = cabin
	state = Extra.new(cabin, "cabin")
	yaw = math.pi -- facing the doors, which are to the north (+Z)
	place(CABIN_SPOT.X, CABIN_SPOT.Z)
end

function ShiftExtra.setFloor(floor: FloorGen.Floor, depth: number)
	floorStart = `r{floor.start}`
	if riding then
		-- It is in the cabin; it gets the floor when the doors open (arrived).
		graph = FloorGen.openGraph(floor)
		return
	end
	ShiftExtra.stop()
	if depth < CFG.ExtraFromDepth then
		return
	end
	graph = FloorGen.openGraph(floor)
	-- Somewhere in the middle of the floor: never the lobby, never where the Registrar starts.
	local registrarNode = FloorGen.registrarStart(floor)
	local options = {}
	for name in graph do
		if string.sub(name, 1, 1) == "r" and name ~= floorStart and name ~= registrarNode then
			table.insert(options, name)
		end
	end
	table.sort(options)
	if #options == 0 then
		return
	end
	state = Extra.new(graph, options[random:NextInteger(1, #options)])
	wakeAt = os.clock() + CFG.RideSeconds + CFG.DoorOpenSeconds + CFG.ExtraWake
	running = true
end

-- The doors opened: if it rode along, it steps out with the team.
function ShiftExtra.arrived()
	if not riding then
		return
	end
	riding = false
	layer:SetAttribute("Riding", false)
	local current = state
	if not current or current.phase == "gone" or not graph[floorStart] then
		ShiftExtra.stop()
		return
	end
	local walker = Extra.new(graph, floorStart, CFG.DoorOpenSeconds + 2)
	-- From where it stood in the cabin it walks straight out through the doorway into the lobby.
	walker.offNode = true
	walker.x, walker.z = CABIN_SPOT.X, CABIN_SPOT.Z
	state = walker
	wakeAt = os.clock()
	running = true
end

local function reward(player: Player)
	local session = services.ShiftSession
	local value = CFG.Values.legendary
	local added = if riding
		then session.addRideFootage(player, value)
		else session.addFootage(player, value)
	session.archive(player, "extra", 5)
	Net.get("FootageScored"):FireClient(player, {
		shots = { { stars = 5, rarity = "legendary" } },
		added = added,
		best = 5,
	})
	session.broadcast(
		`{player.DisplayName} filmed the Extra until it was gone. It was never one of us.`
	)
end

local function framers(at: Vector3): { [number]: number }
	local result: { [number]: number } = {}
	-- A tripod holds it still but is never close enough to wear it away: that takes a person.
	if services.ShiftTripod.frames(at) then
		result[services.ShiftTripod.ID] = 1e6
	end
	for _, player in services.Lens.framers(at) do
		if services.ShiftSession.lensWorks(player) then
			local root = rootOf(player)
			if root then
				result[player.UserId] = (root.Position - at).Magnitude
			end
		end
	end
	return result
end

local function inputs(): { Extra.PlayerInput }
	local list: { Extra.PlayerInput } = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local p = root.Position
			table.insert(list, {
				id = player.UserId,
				x = p.X,
				z = p.Z,
				cut = player:GetAttribute("OffFrame") == true,
				-- In the cabin nobody can be reached, and neither can anyone while it rides.
				safe = riding or services.ShiftWorld.inLift(p),
			})
		end
	end
	return list
end

local function apply(events: { Extra.Event })
	for _, event in events do
		local player = if event.id then Players:GetPlayerByUserId(event.id) else nil
		if event.kind == "marked" and player then
			-- Alone it wears your face; with friends it wears someone else's.
			if #Players:GetPlayers() > 1 and look == player then
				local other = anyone(player)
				if other then
					dress(other)
				end
			end
		elseif event.kind == "turned" and player then
			eventRemote:FireClient(player, "turned")
		elseif event.kind == "cut" and player then
			eventRemote:FireAllClients("cut", player.UserId)
			services.ShiftOffFrame.cut(player, "extra")
		elseif event.kind == "revealed" then
			local current = model
			local at = if current then current:GetPivot().Position else Vector3.zero
			eventRemote:FireAllClients("revealed", at)
			if player then
				reward(player)
			end
			clearModel()
			running = false
			riding = false
			layer:SetAttribute("Riding", false)
		end
	end
end

function ShiftExtra.init(all: { [string]: any })
	services = all
	eventRemote = Net.get("ExtraEvent")
	layer = Instance.new("Folder")
	layer.Name = "ExtraLayer"
	layer:SetAttribute("Riding", false)
	layer.Parent = Workspace
end

function ShiftExtra.start()
	while true do
		task.wait(STEP)
		local current = state
		if not current or (not running and not riding) then
			continue
		end
		if not riding and os.clock() < wakeAt then
			continue
		end
		local paused = RunService:IsStudio() and Workspace:GetAttribute("DevPauseRegistrar") == true
		if paused then
			continue
		end
		if not model then
			local wearing = anyone(nil)
			if not wearing or not dress(wearing) then
				continue
			end
		end
		local chest = Vector3.new(current.x, rootHeight + 1, current.z)
		local beforeX, beforeZ = current.x, current.z
		apply(Extra.step(current, RULES, graph, STEP, inputs(), framers(chest)))
		if not model or current.phase == "gone" then
			continue
		end
		if current.moving then
			face(beforeX, beforeZ, current.x, current.z)
		elseif current.target then
			local target = Players:GetPlayerByUserId(current.target)
			local root = target and rootOf(target)
			if root then
				face(current.x, current.z, root.Position.X, root.Position.Z)
			end
		end
		place(current.x, current.z)
		-- Filmed, it stops dead mid-step: the pose freezes, it does not settle.
		if current.frozen then
			if walkTrack then
				walkTrack:AdjustSpeed(0)
			end
			if waveTrack then
				waveTrack:AdjustSpeed(0)
			end
		else
			play(walkTrack, current.moving, RULES.speed / 12)
			play(waveTrack, current.beckoning and not current.moving)
		end
	end
end

return ShiftExtra
