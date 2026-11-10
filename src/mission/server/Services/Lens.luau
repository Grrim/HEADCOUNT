--!strict
-- Who has a camera up and where it points. The client reports, the server decides what is framed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Framing = require(ReplicatedStorage.Shared.Core.Framing)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local Lens = {}

type View = { raised: boolean, cf: CFrame, at: number }

local views: { [Player]: View } = {}
local limit = RateLimit.new(Config.Rates.Lens[1], Config.Rates.Lens[2])
local COS = math.cos(math.rad(Config.Lens.FramingHalfAngle))
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

function Lens.isRaised(player: Player): boolean
	local view = views[player]
	return view ~= nil and view.raised and os.clock() - view.at <= Config.Lens.StaleAfter
end

function Lens.clear(player: Player)
	views[player] = nil
end

-- Is this point in this player's frame, with nothing solid between lens and subject?
function Lens.frames(player: Player, target: Vector3): boolean
	if not Lens.isRaised(player) or player:GetAttribute("OffFrame") == true then
		return false
	end
	local view = views[player]
	local origin = view.cf.Position
	local look = view.cf.LookVector
	if
		not Framing.isFramed(
			origin.X,
			origin.Y,
			origin.Z,
			look.X,
			look.Y,
			look.Z,
			target.X,
			target.Y,
			target.Z,
			COS,
			Config.Lens.FramingRange
		)
	then
		return false
	end
	local offset = target - origin
	local distance = offset.Magnitude
	if distance < 2 then
		return true
	end
	-- Stop just short: the subject may be standing against the very wall we are testing through.
	local hit = Workspace:Raycast(origin, offset.Unit * (distance - 1.5), rayParams)
	return hit == nil
end

-- Nothing solid between these two points (the same test framing uses), stopping just short of
-- the target.
function Lens.clearLine(origin: Vector3, target: Vector3): boolean
	local offset = target - origin
	local distance = offset.Magnitude
	if distance < 2 then
		return true
	end
	return Workspace:Raycast(origin, offset.Unit * (distance - 1.5), rayParams) == nil
end

-- Up close a large subject overflows the framing cone, so a door right in front of the lens must
-- still count. Roughly facing it within this radius is enough; no line of sight is needed at this
-- distance because the subject is the nearest thing there.
function Lens.holdsCloseUp(player: Player, target: Vector3, radius: number): boolean
	if not Lens.isRaised(player) or player:GetAttribute("OffFrame") == true then
		return false
	end
	local view = views[player]
	local offset = target - view.cf.Position
	local distance = offset.Magnitude
	if distance > radius then
		return false
	end
	return distance < 0.5 or view.cf.LookVector:Dot(offset.Unit) >= 0.4
end

function Lens.framers(target: Vector3): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if Lens.frames(player, target) then
			table.insert(result, player)
		end
	end
	return result
end

function Lens.init()
	Net.get("LensState").OnServerEvent
		:Connect(function(player: Player, raised: unknown, cf: unknown)
			if not limit:allow(player, os.clock()) then
				return
			end
			if typeof(raised) ~= "boolean" then
				return
			end
			if not raised then
				views[player] = nil
				return
			end
			if typeof(cf) ~= "CFrame" then
				return
			end
			local head = headOf(player)
			if not head then
				return
			end
			-- A camera far from the player's own head is a forged camera.
			if (cf.Position - head.Position).Magnitude > Config.Lens.MaxCameraDistanceFromHead then
				return
			end
			views[player] = { raised = true, cf = cf, at = os.clock() }
		end)
	Players.PlayerRemoving:Connect(function(player)
		views[player] = nil
		limit:forget(player)
	end)
end

function Lens.start()
	local map = Workspace:WaitForChild("Map")
	rayParams.FilterDescendantsInstances = { map }
end

return Lens
