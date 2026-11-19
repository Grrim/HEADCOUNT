--!strict
-- Recording on a shift: a tape is a camera path, checked like any client data, then scored against
-- the anomalies only the server knows the place of (Core/Footage). The team keeps its best shot of
-- each anomaly, so pay comes from filming new ones well, not filming one over and over.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Footage = require(ReplicatedStorage.Shared.Core.Footage)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Tape = require(ReplicatedStorage.Shared.Core.Tape)

local ShiftTapes = {}

local TAPE = Config.Tape
local LIMITS: Tape.Limits = {
	maxSamples = TAPE.MaxSamples,
	sampleHz = TAPE.SampleHz,
	maxSpeed = TAPE.MaxSpeed,
	maxStartDistance = TAPE.MaxStartDistance,
}
local COS = math.cos(math.rad(Config.Lens.FramingHalfAngle))

local services: { [string]: any }
local scoredRemote: RemoteEvent
local recordLimit = RateLimit.new(Config.Rates.Record[1], Config.Rates.Record[2])
local recording: { [Player]: Vector3 } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function onStart(player: Player)
	if not recordLimit:allow(player, os.clock()) then
		return
	end
	local session = services.ShiftSession
	if session.shift.phase ~= "floor" or not session.lensWorks(player) then
		return
	end
	if not services.Lens.isRaised(player) then
		return
	end
	local head = headOf(player)
	if not head or not session.useTape(player) then
		return
	end
	recording[player] = head.Position
end

local function blocked(sample: { number }, target: Footage.Target): boolean
	local origin = Vector3.new(sample[1], sample[2], sample[3])
	local offset = Vector3.new(target.x, target.y, target.z) - origin
	local distance = offset.Magnitude
	if distance < 2 then
		return false
	end
	return Workspace:Raycast(origin, offset.Unit * (distance - 1.5), rayParams) ~= nil
end

local function onStop(player: Player, raw: unknown)
	local start = recording[player]
	recording[player] = nil
	if not start then
		return
	end
	local session = services.ShiftSession
	if session.shift.phase ~= "floor" then
		return
	end
	local samples, problem = Tape.sanitize(raw, LIMITS, start.X, start.Y, start.Z)
	if not samples then
		warn(`[ShiftTapes] refused a tape from {player.Name}: {problem}`)
		return
	end
	local targets: { Footage.Target } = {}
	local byId: { [number]: any } = {}
	for _, anomaly in session.anomalies do
		local p = anomaly.position
		table.insert(targets, { id = anomaly.id, x = p.X, y = p.Y, z = p.Z, value = anomaly.value })
		byId[anomaly.id] = anomaly
	end
	local map = Workspace:FindFirstChild("Map")
	rayParams.FilterDescendantsInstances = if map then { map } else {}
	local shots =
		Footage.score(samples, targets, TAPE.SampleHz, COS, Config.Lens.FramingRange, blocked)
	local gain, improved = Footage.improve(session.best, shots)
	local added = session.addFootage(player, gain)

	local report = {}
	for _, shot in improved do
		local anomaly = byId[shot.id]
		session.markFilmed(shot.id, shot.stars)
		table.insert(
			report,
			{ stars = shot.stars, rarity = anomaly and anomaly.rarity or "common" }
		)
	end
	scoredRemote:FireClient(
		player,
		{ shots = report, added = added, best = shots[1] and shots[1].stars or 0 }
	)
	if added > 0 then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				scoredRemote:FireClient(other, { teammate = player.DisplayName, added = added })
			end
		end
	end
end

function ShiftTapes.init(all: { [string]: any })
	services = all
	scoredRemote = Net.get("FootageScored")
	Net.get("RecordStart").OnServerEvent:Connect(onStart)
	Net.get("RecordStop").OnServerEvent:Connect(onStop)
	Players.PlayerRemoving:Connect(function(player)
		recording[player] = nil
		recordLimit:forget(player)
	end)
end

return ShiftTapes
