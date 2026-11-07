--!strict
-- Small sounds with no visible source: a creak two rooms away, a drip, a chair folding somewhere in
-- the dark. Each plays at a real point around the listener, muffled if there is a wall in the way,
-- so direction and distance do the frightening. The building stays quiet when silence is the point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(script.Parent.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)

local RoomTone = {}

local random = Random.new()

-- A spot at a random bearing, kept out of the listener's head.
local function pointAround(origin: Vector3): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local radius = random:NextNumber(14, 34)
	return origin
		+ Vector3.new(math.cos(angle) * radius, random:NextNumber(-2, 4), math.sin(angle) * radius)
end

local function isBlocked(from: Vector3, to: Vector3, map: Instance): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	return Workspace:Raycast(from, to - from, params) ~= nil
end

function RoomTone.start(pool: { string })
	local cfg = Config.RoomTone
	task.spawn(function()
		local map = Workspace:WaitForChild("Map")
		while true do
			task.wait(random:NextNumber(cfg.MinGap, cfg.MaxGap))
			local camera = Workspace.CurrentCamera
			if camera and not AudioDirector.isSilent() then
				local origin = camera.CFrame.Position
				local point = pointAround(origin)
				local name = pool[random:NextInteger(1, #pool)]
				AudioDirector.playAt(name, point, cfg.Volume, 60, isBlocked(origin, point, map))
			end
		end
	end)
end

return RoomTone
