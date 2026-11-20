--!strict
-- The tripod (docs/09_GDD_V2.md §5): a camera set down on three legs that keeps filming on its own.
-- For as many seconds as its upgrade gives, whatever it frames is held in frame: the Registrar
-- freezes (and can not hold the lift doors open), the Extra stands still. It records nothing,
-- pays nothing and rescues nobody; it buys time. One a floor, a fresh one with every ride.
--
-- It shines no light, so the Usher does not see it. Everyone sees the tripod itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Framing = require(ReplicatedStorage.Shared.Core.Framing)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local ShiftTripod = {}

-- The tripod frames like a raised lens, from the height of a camera on its legs.
local COS = math.cos(math.rad(Config.Lens.FramingHalfAngle))
local RANGE = Config.Lens.FramingRange
local HEIGHT = 4.6
-- The id the tripod goes by where a player's UserId would stand (Registrar exposure, the Extra).
ShiftTripod.ID = -1

type Tripod = { origin: Vector3, look: Vector3, untilTime: number, model: Model, owner: Player }

local services: { [string]: any }
local folder: Folder
local tripods: { Tripod } = {}
local limit = RateLimit.new(1, 2)

local function piece(
	model: Model,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

local function build(feet: Vector3, look: Vector3, owner: Player): Model
	local model = Instance.new("Model")
	model.Name = `Tripod_{owner.UserId}`
	local flat = Vector3.new(look.X, 0, look.Z)
	local facing =
		CFrame.lookAt(feet, feet + (if flat.Magnitude > 0.01 then flat else Vector3.zAxis))
	-- Three legs splayed from the head down to the floor.
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		local foot = feet + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.2
		local head = feet + Vector3.new(0, HEIGHT - 0.4, 0)
		local middle = (foot + head) / 2
		piece(
			model,
			Vector3.new(0.12, 0.12, (head - foot).Magnitude),
			CFrame.lookAt(middle, head),
			Palette.Metal,
			Enum.Material.Metal
		)
	end
	-- The camera on top, pointed where it was aimed, with its recording lamp.
	local body = facing
		* CFrame.new(0, HEIGHT, 0)
		* CFrame.Angles(math.asin(math.clamp(look.Y, -1, 1)), 0, 0)
	piece(model, Vector3.new(0.6, 0.6, 1.2), body, Palette.Ink)
	local lamp = piece(
		model,
		Vector3.new(0.12, 0.12, 0.05),
		body * CFrame.new(0.2, 0.2, -0.62),
		Palette.Rec,
		Enum.Material.Neon
	)
	lamp.Name = "RecLamp"
	model.Parent = folder
	return model
end

-- Does any running tripod hold this point in frame, with nothing solid in between?
function ShiftTripod.frames(point: Vector3): boolean
	local now = os.clock()
	for _, tripod in tripods do
		if now < tripod.untilTime then
			local o, l = tripod.origin, tripod.look
			if
				Framing.isFramed(
					o.X,
					o.Y,
					o.Z,
					l.X,
					l.Y,
					l.Z,
					point.X,
					point.Y,
					point.Z,
					COS,
					RANGE
				) and services.Lens.clearLine(o, point)
			then
				return true
			end
		end
	end
	return false
end

-- A new floor (or a lost shift): the tripods stay behind with the floor they stood on.
function ShiftTripod.clear()
	for _, tripod in tripods do
		tripod.model:Destroy()
	end
	tripods = {}
end

local function onPlace(player: Player, look: unknown)
	if not limit:allow(player, os.clock()) then
		return
	end
	local session = services.ShiftSession
	if session.shift.phase ~= "floor" or player:GetAttribute("OffFrame") == true then
		return
	end
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.5 or look ~= look then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or services.ShiftWorld.inLift(root.Position) then
		return
	end
	local seconds = session.takeTripod(player)
	if seconds <= 0 then
		return
	end
	local feet = Vector3.new(root.Position.X, 0, root.Position.Z)
	local direction = look.Unit
	local tripod: Tripod = {
		origin = feet + Vector3.new(0, HEIGHT, 0),
		look = direction,
		untilTime = os.clock() + seconds,
		model = build(feet, direction, player),
		owner = player,
	}
	table.insert(tripods, tripod)
	session.tell(player, `Tripod set. It holds what it frames for {seconds} s.`)
end

function ShiftTripod.init(all: { [string]: any })
	services = all
	folder = Instance.new("Folder")
	folder.Name = "Tripods"
	folder.Parent = Workspace
	Net.get("TripodPlace").OnServerEvent:Connect(onPlace)
	Players.PlayerRemoving:Connect(function(player)
		limit:forget(player)
	end)
end

function ShiftTripod.start()
	-- A tripod whose battery has run out stops filming: its lamp goes dark and it stays where it
	-- stood, a reminder that the hold is over.
	while true do
		task.wait(0.25)
		local now = os.clock()
		for _, tripod in tripods do
			local lamp = tripod.model:FindFirstChild("RecLamp")
			if
				now >= tripod.untilTime
				and lamp
				and lamp:IsA("BasePart")
				and lamp.Material == Enum.Material.Neon
			then
				lamp.Material = Enum.Material.SmoothPlastic
				lamp.Color = Palette.Ink
				if tripod.owner.Parent then
					services.ShiftSession.tell(tripod.owner, "Your tripod's battery ran out.")
				end
			end
		end
	end
end

return ShiftTripod
