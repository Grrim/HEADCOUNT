--!strict
-- Recording on a shift: a tape is a camera path, checked like any client data, then scored against
-- the anomalies only the server knows the place of (Core/Footage). The team keeps its best shot of
-- each anomaly, so pay comes from filming new ones well, not filming one over and over.
--
-- Tapes can also be watched (docs/09_GDD_V2.md §2.5). A viewing flies the recorded path again and
-- shows what the eye never saw live: the code of a code door the tape framed. The viewer stands
-- still and undefended, and every viewing after the team's first on a floor pulls the Registrar
-- one node closer to the viewer.
--
-- A tape is client data, so the server keeps its own log of where the player's head really was
-- while recording and refuses a path that leaves it, or that is longer than the time it took.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Footage = require(ReplicatedStorage.Shared.Core.Footage)
local Highlight = require(ReplicatedStorage.Shared.Core.Highlight)
local Shift = require(ReplicatedStorage.Shared.Core.Shift)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Registrar = require(ReplicatedStorage.Shared.Core.Registrar)
local Tape = require(ReplicatedStorage.Shared.Core.Tape)

local ShiftTapes = {}

local TAPE = Config.Tape
local SHIFT = Config.Shift
local LIMITS: Tape.Limits = {
	maxSamples = TAPE.MaxSamples,
	sampleHz = TAPE.SampleHz,
	maxSpeed = TAPE.MaxSpeed,
	maxStartDistance = TAPE.MaxStartDistance,
}
-- Tapes a camera keeps for watching; the oldest goes first.
local KEPT = 3
-- How far a sample may be from where the head was at about that moment, and how loose "about".
local HEAD_SLACK = Config.Lens.MaxCameraDistanceFromHead
local TIME_SLACK = 0.6

type Take = { at: number, heads: { { t: number, p: Vector3 } } }

type Clip = { id: number, track: { Tape.Sample }, viewings: number }

local services: { [string]: any }
local scoredRemote: RemoteEvent
local playRemote: RemoteEvent
local recordLimit = RateLimit.new(Config.Rates.Record[1], Config.Rates.Record[2])
local playLimit = RateLimit.new(Config.Rates.Play[1], Config.Rates.Play[2])
local recording: { [Player]: Take } = {}
local clips: { [Player]: { Clip } } = {}
local playing: { [Player]: number } = {}
local floorViewings = 0
local nextClipId = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- The shift tape: the best shot of the shift so far (by what it paid before any earlier shot of
-- the same subject was taken off), cut to the stretch that held its subject longest.
ShiftTapes.highlight = nil :: Wallet.Tape?
local highlightWorth = 0

function ShiftTapes.resetHighlight()
	ShiftTapes.highlight = nil
	highlightWorth = 0
end

local function considerHighlight(
	player: Player,
	samples: { Tape.Sample },
	shot: Footage.Shot,
	anomaly: any,
	cos: number
)
	local session = services.ShiftSession
	local worth = shot.value * Shift.multiplier(session.shift.depth)
	if worth <= highlightWorth then
		return
	end
	local p = anomaly.position
	local first, last = Highlight.window(
		samples,
		{ x = p.X, y = p.Y, z = p.Z },
		TAPE.SampleHz,
		Highlight.SECONDS,
		cos,
		Config.Lens.FramingRange
	)
	highlightWorth = worth
	ShiftTapes.highlight = {
		seed = session.seed(),
		depth = session.shift.depth,
		stars = shot.stars,
		rarity = anomaly.rarity,
		kind = anomaly.kind,
		by = player.DisplayName,
		at = os.time(),
		hz = TAPE.SampleHz,
		track = Highlight.pack(samples, first, last),
	}
end

function ShiftTapes.isPlaying(player: Player): boolean
	local untilTime = playing[player]
	return untilTime ~= nil and os.clock() < untilTime
end

-- A new floor: the tapes of the last one show a building that is no longer there.
function ShiftTapes.clearFloor()
	clips = {}
	recording = {}
	floorViewings = 0
	for _, player in Players:GetPlayers() do
		player:SetAttribute("TapesKept", 0)
	end
	playing = {}
end

local function onStart(player: Player)
	if not recordLimit:allow(player, os.clock()) then
		return
	end
	local session = services.ShiftSession
	if session.shift.phase ~= "floor" or not session.lensWorks(player) then
		return
	end
	if not services.Lens.isRaised(player) or ShiftTapes.isPlaying(player) then
		return
	end
	local head = headOf(player)
	if not head or not session.useTape(player) then
		return
	end
	recording[player] = { at = os.clock(), heads = { { t = 0, p = head.Position } } }
end

-- A cut drops the camera mid-take: whatever it was recording is lost with it.
function ShiftTapes.cancel(player: Player)
	recording[player] = nil
	playing[player] = nil
end

-- Every sample must sit near where the head really was at that point of the take, and the take
-- can not hold more samples than the seconds it lasted.
local function matchesHead(take: Take, samples: { Tape.Sample }): boolean
	local elapsed = os.clock() - take.at
	if (#samples - 1) / TAPE.SampleHz > elapsed + TIME_SLACK then
		return false
	end
	for index, sample in samples do
		local t = (index - 1) / TAPE.SampleHz
		local position = Vector3.new(sample[1], sample[2], sample[3])
		local near = false
		for _, logged in take.heads do
			if
				math.abs(logged.t - t) <= TIME_SLACK
				and (logged.p - position).Magnitude <= HEAD_SLACK
			then
				near = true
				break
			end
		end
		if not near then
			return false
		end
	end
	return true
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

local function keep(player: Player, track: { Tape.Sample })
	nextClipId += 1
	local list = clips[player] or {}
	table.insert(list, { id = nextClipId, track = track, viewings = 0 })
	while #list > KEPT do
		table.remove(list, 1)
	end
	clips[player] = list
	player:SetAttribute("TapesKept", #list)
end

local function onStop(player: Player, raw: unknown)
	local take = recording[player]
	recording[player] = nil
	if not take then
		return
	end
	local session = services.ShiftSession
	-- A flat battery mid-take keeps the tape; a fallen camera does not.
	if
		session.shift.phase ~= "floor"
		or player:GetAttribute("OffFrame") == true
		or not session.hasCamera(player)
	then
		return
	end
	local start = take.heads[1].p
	local samples, problem = Tape.sanitize(raw, LIMITS, start.X, start.Y, start.Z)
	if not samples then
		warn(`[ShiftTapes] refused a tape from {player.Name}: {problem}`)
		return
	end
	if not matchesHead(take, samples) then
		warn(`[ShiftTapes] refused a tape from {player.Name}: it does not follow their head`)
		return
	end
	keep(player, samples)
	local targets: { Footage.Target } = {}
	local byId: { [number]: any } = {}
	for _, anomaly in session.anomalies do
		local p = anomaly.position
		table.insert(targets, { id = anomaly.id, x = p.X, y = p.Y, z = p.Z, value = anomaly.value })
		byId[anomaly.id] = anomaly
	end
	local map = Workspace:FindFirstChild("Map")
	rayParams.FilterDescendantsInstances = if map then { map } else {}
	-- A zoom lens frames narrower and rates distance as if it stood closer.
	local zoom = player:GetAttribute("LensZoom")
	local magnify = if typeof(zoom) == "number" then zoom else 1
	local cos = services.Lens.cosFor(player)
	local shots = Footage.score(
		samples,
		targets,
		TAPE.SampleHz,
		cos,
		Config.Lens.FramingRange,
		blocked,
		magnify
	)
	for _, shot in shots do
		local anomaly = byId[shot.id]
		if anomaly then
			session.archive(player, anomaly.kind, shot.stars)
		end
	end
	local top = shots[1]
	if top and byId[top.id] then
		considerHighlight(player, samples, top, byId[top.id], cos)
	end
	local gain, improved = Footage.improve(session.best, shots)
	local added = session.addFootage(player, gain)

	local report = {}
	for _, shot in improved do
		local anomaly = byId[shot.id]
		session.markFilmed(shot.id, shot.stars)
		local quests = services.ShiftQuests
		quests.event(player, "film")
		if anomaly and (anomaly.rarity == "rare" or anomaly.rarity == "epic") then
			quests.event(player, "film_rare")
		end
		if shot.stars >= 5 then
			quests.event(player, "five_stars")
		end
		table.insert(
			report,
			{ stars = shot.stars, rarity = anomaly and anomaly.rarity or "common" }
		)
	end
	-- A tape that framed a code door says so: that is the tape worth watching.
	local doors = services.ShiftDoors.framedBy(samples, cos, SHIFT.CodeReadRange)
	scoredRemote:FireClient(player, {
		shots = report,
		added = added,
		best = shots[1] and shots[1].stars or 0,
		door = #doors > 0,
	})
	if added > 0 then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				scoredRemote:FireClient(other, { teammate = player.DisplayName, added = added })
			end
		end
	end
end

local function onPlay(player: Player)
	if not playLimit:allow(player, os.clock()) then
		return
	end
	local session = services.ShiftSession
	if session.shift.phase ~= "floor" or player:GetAttribute("OffFrame") == true then
		return
	end
	if ShiftTapes.isPlaying(player) or recording[player] then
		return
	end
	if not session.hasCamera(player) then
		session.tell(player, "Your tapes fell with your camera.")
		return
	end
	local list = clips[player]
	local clip = list and list[#list]
	if not clip then
		session.tell(player, "No tape on this floor yet. Record something first (R).")
		return
	end
	clip.viewings += 1
	floorViewings += 1
	playing[player] = os.clock() + TAPE.MaxPlaySeconds
	services.Lens.clear(player)
	local codes = {}
	for _, door in
		services.ShiftDoors.framedBy(clip.track, services.Lens.cosFor(player), SHIFT.CodeReadRange)
	do
		table.insert(codes, { id = door.id, code = door.code })
	end
	playRemote:FireClient(player, {
		id = clip.id,
		track = clip.track,
		hz = TAPE.SampleHz,
		viewings = clip.viewings,
		codes = codes,
		free = floorViewings <= 1,
		registrarDistance = Tape.registrarDistance(
			clip.viewings,
			TAPE.RegistrarStart,
			TAPE.RegistrarStep,
			TAPE.RegistrarMinimum
		),
	})
	services.ShiftQuests.event(player, "tape_watch")
	if Registrar.replaySteps(floorViewings) > 0 then
		services.ShiftRegistrar.onReplay(player)
	end
end

function ShiftTapes.start()
	-- The server's own record of each take: where the head was, ten times a second.
	while true do
		task.wait(1 / TAPE.SampleHz)
		for player, take in recording do
			local head = headOf(player)
			local t = os.clock() - take.at
			if head and #take.heads < TAPE.MaxSamples * 2 then
				table.insert(take.heads, { t = t, p = head.Position })
			end
			if t > TAPE.MaxSeconds + 2 then
				-- A take nobody stopped: the client went quiet.
				recording[player] = nil
			end
		end
	end
end

function ShiftTapes.init(all: { [string]: any })
	services = all
	scoredRemote = Net.get("FootageScored")
	playRemote = Net.get("TapePlay")
	Net.get("RecordStart").OnServerEvent:Connect(onStart)
	Net.get("RecordStop").OnServerEvent:Connect(onStop)
	Net.get("PlayTape").OnServerEvent:Connect(onPlay)
	Net.get("PlayEnded").OnServerEvent:Connect(function(player: Player)
		playing[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		recording[player] = nil
		clips[player] = nil
		playing[player] = nil
		recordLimit:forget(player)
		playLimit:forget(player)
	end)
end

return ShiftTapes
