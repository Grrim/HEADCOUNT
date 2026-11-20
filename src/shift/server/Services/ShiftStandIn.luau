--!strict
-- The Stand-in ("Dubler", docs/09_GDD_V2.md §2.3) on the deep floors: behind every player walks
-- their own past, the path they took 30 seconds ago (Core/StandIn). If it steps where they stand
-- now, it takes their place and they are cut out of frame. So on these floors nobody can stand
-- still for long or go back the way they came half a minute ago.
--
-- To the eye it is not there; its signal is the player's own footsteps behind them. Through the
-- lens it shows (StandInView). Filming does not stop it: it is a recording, not a creature. The
-- lift is safe, and a player who was cut starts a fresh past once they are back in frame.
--
-- Each Stand-in is an invisible anchor in Workspace.StandIns, moved ten times a second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local StandIn = require(ReplicatedStorage.Shared.Core.StandIn)

local ShiftStandIn = {}

local CFG = Config.Shift
local STEP = 0.1

local services: { [string]: any }
local folder: Folder
local active = false
local startAt = 0
local buffers: { [Player]: StandIn.Buffer } = {}
local anchors: { [Player]: Part } = {}

local function anchorOf(player: Player): Part
	local anchor = anchors[player]
	if anchor and anchor.Parent then
		return anchor
	end
	local made = Instance.new("Part")
	made.Name = `StandIn_{player.UserId}`
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.Transparency = 1
	made.Size = Vector3.one
	made.Position = Vector3.new(0, -300, 0)
	made:SetAttribute("Owner", player.UserId)
	made:SetAttribute("Active", false)
	made.Parent = folder
	anchors[player] = made
	return made
end

local function reset(player: Player)
	buffers[player] = StandIn.new(CFG.StandInDelay, 2)
	local anchor = anchors[player]
	if anchor then
		anchor:SetAttribute("Active", false)
		anchor.Position = Vector3.new(0, -300, 0)
	end
end

function ShiftStandIn.stop()
	active = false
	for player in anchors do
		reset(player)
	end
end

-- A new floor: from the Stand-ins' depth down, everyone's past starts when the doors open.
function ShiftStandIn.setFloor(depth: number)
	ShiftStandIn.stop()
	if depth < CFG.StandInFromDepth then
		return
	end
	for _, player in Players:GetPlayers() do
		reset(player)
	end
	startAt = os.clock() + CFG.RideSeconds + CFG.DoorOpenSeconds
	active = true
end

function ShiftStandIn.init(all: { [string]: any })
	services = all
	folder = Instance.new("Folder")
	folder.Name = "StandIns"
	folder.Parent = Workspace
	Players.PlayerRemoving:Connect(function(player)
		buffers[player] = nil
		local anchor = anchors[player]
		if anchor then
			anchor:Destroy()
		end
		anchors[player] = nil
	end)
end

function ShiftStandIn.start()
	while true do
		task.wait(STEP)
		local now = os.clock()
		local paused = RunService:IsStudio() and Workspace:GetAttribute("DevPauseRegistrar") == true
		if not active or now < startAt or paused then
			continue
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				continue
			end
			if player:GetAttribute("OffFrame") == true then
				-- Cut out of frame: no past to follow. Back in frame, a new one begins.
				if buffers[player] and #buffers[player].samples > 0 then
					reset(player)
				end
				continue
			end
			local buffer = buffers[player]
			if not buffer then
				reset(player)
				buffer = buffers[player]
			end
			local p = root.Position
			local look = root.CFrame.LookVector
			StandIn.record(buffer, now, p.X, p.Y, p.Z, math.atan2(-look.X, -look.Z))
			local anchor = anchorOf(player)
			local ghost = StandIn.at(buffer, now)
			if ghost then
				anchor.CFrame = CFrame.new(ghost.x, ghost.y, ghost.z)
					* CFrame.Angles(0, ghost.yaw, 0)
				anchor:SetAttribute("Active", true)
				if
					not services.ShiftWorld.inLift(p)
					and StandIn.catches(buffer, now, p.X, p.Z, CFG.StandInRadius)
				then
					services.ShiftOffFrame.cut(player, "standin")
					reset(player)
				end
			end
		end
	end
end

return ShiftStandIn
