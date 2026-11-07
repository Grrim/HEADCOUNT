--!strict
-- Recording and playback as data. The server keeps each tape, decides what it contains and counts
-- every viewing, because a viewing is what moves the Registrar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerData = require(ServerScriptService.Common.PlayerData)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)
local Tape = require(ReplicatedStorage.Shared.Core.Tape)

local Tapes = {}

type Ghost = { name: string, track: { { number } } }
type Clip = {
	id: number,
	track: { Tape.Sample },
	ghosts: { Ghost },
	seats: { number },
	viewings: number,
}
type Recording = { startedAt: number, startPos: Vector3, ghosts: { [Player]: Ghost } }

local CFG = Config.Tape
local COS = math.cos(math.rad(Config.Lens.FramingHalfAngle + 6))
local LIMITS: Tape.Limits = {
	maxSamples = CFG.MaxSamples,
	sampleHz = CFG.SampleHz,
	maxSpeed = CFG.MaxSpeed,
	maxStartDistance = CFG.MaxStartDistance,
}

local services: { [string]: any }
local clips: { [Player]: { Clip } } = {}
local shot: { [Player]: number } = {}
local recordings: { [Player]: Recording } = {}
local playing: { [Player]: number } = {} -- clock time the viewing ends at the latest
local archiveViewings = 0
local recordLimit = RateLimit.new(Config.Rates.Record[1], Config.Rates.Record[2])
local playLimit = RateLimit.new(Config.Rates.Play[1], Config.Rates.Play[2])
local listRemote: RemoteEvent
local playRemote: RemoteEvent

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Tapes.isPlaying(player: Player): boolean
	local untilTime = playing[player]
	return untilTime ~= nil and os.clock() < untilTime
end

function Tapes.sendList(player: Player)
	local list = clips[player] or {}
	local latest = list[#list]
	listRemote:FireClient(player, {
		left = CFG.PerPlayer - (shot[player] or 0),
		count = #list,
		latestId = if latest then latest.id else nil,
	})
end

local function targetPoints(): ({ { number } }, { number })
	local puzzle = services.Session.puzzle
	local points, seatIds = {}, {}
	if puzzle then
		for _, target in puzzle.targets do
			local x, z = Seats.position(target.seatId)
			table.insert(points, { x, 4.5, z })
			table.insert(seatIds, target.seatId)
		end
	end
	return points, seatIds
end

local function onRecordStart(player: Player)
	if not recordLimit:allow(player, os.clock()) then
		return
	end
	if player:GetAttribute("OffFrame") == true or recordings[player] then
		return
	end
	if (shot[player] or 0) >= CFG.PerPlayer then
		services.Session.notifyOne(player, "no_tapes")
		return
	end
	if not services.Lens.isRaised(player) or services.Session.flow.phase == "Waiting" then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local ghosts: { [Player]: Ghost } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			ghosts[other] = { name = other.Name, track = {} }
		end
	end
	recordings[player] = { startedAt = os.clock(), startPos = root.Position, ghosts = ghosts }
end

local function onRecordStop(player: Player, rawTrack: unknown)
	local recording = recordings[player]
	if not recording then
		return
	end
	recordings[player] = nil
	if os.clock() - recording.startedAt > CFG.MaxSeconds + 3 then
		return
	end
	local start = recording.startPos
	-- The camera sits a couple of studs above the root.
	local track, reason = Tape.sanitize(rawTrack, LIMITS, start.X, start.Y + 2, start.Z)
	if not track then
		warn(`[Tapes] refused a tape from {player.Name}: {reason}`)
		return
	end
	local points, seatIds = targetPoints()
	local found = Tape.framedPoints(track, points, COS, CFG.TargetRange)
	-- Filming the bench in the foyer, where someone sits only through the lens, earns a document.
	local bench = Layout.BENCH
	if #Tape.framedPoints(track, { { bench.x, 4, bench.z } }, COS, 45) > 0 then
		services.Puzzles.showDoc(player, "doc_bench")
	end
	local seats = {}
	for _, index in found do
		table.insert(seats, seatIds[index])
	end
	local ghosts = {}
	for _, ghost in recording.ghosts do
		table.insert(ghosts, ghost)
	end
	local list = clips[player] or {}
	clips[player] = list
	shot[player] = (shot[player] or 0) + 1
	local clip: Clip =
		{ id = #list + 1, track = track, ghosts = ghosts, seats = seats, viewings = 0 }
	table.insert(list, clip)
	services.Session.notifyOne(player, "tape_saved", clip.id)
	Tapes.sendList(player)
end

local function onPlay(player: Player, tapeId: unknown)
	if not playLimit:allow(player, os.clock()) then
		return
	end
	if typeof(tapeId) ~= "number" or player:GetAttribute("OffFrame") == true then
		return
	end
	if Tapes.isPlaying(player) or recordings[player] then
		return
	end
	local list = clips[player]
	local clip = list and list[tapeId]
	if not clip then
		services.Session.notifyOne(player, "no_recordings")
		return
	end
	clip.viewings += 1
	local total = services.Session.addReplay()
	PlayerData.addStat(player, "replays", 1)
	playing[player] = os.clock() + CFG.MaxPlaySeconds
	services.Lens.clear(player)
	playRemote:FireClient(player, {
		id = clip.id,
		track = clip.track,
		ghosts = clip.ghosts,
		seats = clip.seats,
		viewings = clip.viewings,
		registrarDistance = Tape.registrarDistance(
			clip.viewings,
			CFG.RegistrarStart,
			CFG.RegistrarStep,
			CFG.RegistrarMinimum
		),
		hz = CFG.SampleHz,
	})
	services.RegistrarAi.onReplay(player, total)
end

-- The office recorder holds a tape nobody on the team shot. Its picture pans across the hall from
-- the stage; it names the order of the reels, and it costs what any viewing costs.
function Tapes.playArchive(player: Player)
	if not playLimit:allow(player, os.clock()) or player:GetAttribute("OffFrame") == true then
		return
	end
	if Tapes.isPlaying(player) or recordings[player] then
		return
	end
	local session = services.Session
	if not session.puzzle then
		return
	end
	archiveViewings += 1
	local total = session.addReplay()
	PlayerData.addStat(player, "replays", 1)
	playing[player] = os.clock() + CFG.MaxPlaySeconds
	services.Lens.clear(player)
	local track = {}
	for sample = 0, 110 do
		local angle = math.rad(-38 + sample * 0.7)
		table.insert(track, { 0, 9, -23 - sample * 0.01, math.sin(angle), -0.12, math.cos(angle) })
	end
	playRemote:FireClient(player, {
		id = 0,
		track = track,
		ghosts = {},
		seats = {},
		viewings = archiveViewings,
		registrarDistance = Tape.registrarDistance(
			archiveViewings,
			CFG.RegistrarStart,
			CFG.RegistrarStep,
			CFG.RegistrarMinimum
		),
		hz = CFG.SampleHz,
		archiveOrder = table.concat(session.puzzle.reelOrder, " - "),
	})
	services.RegistrarAi.onReplay(player, total)
end

function Tapes.init(all: { [string]: any })
	services = all
	listRemote = Net.get("TapeList")
	playRemote = Net.get("TapePlay")
	Net.get("RecordStart").OnServerEvent:Connect(onRecordStart)
	Net.get("RecordStop").OnServerEvent:Connect(onRecordStop)
	Net.get("PlayTape").OnServerEvent:Connect(onPlay)
	Net.get("PlayEnded").OnServerEvent:Connect(function(player: Player)
		playing[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		clips[player] = nil
		shot[player] = nil
		recordings[player] = nil
		playing[player] = nil
		recordLimit:forget(player)
		playLimit:forget(player)
	end)
end

function Tapes.start()
	-- Teammates' positions while someone is shooting: they appear as ghosts on the tape.
	local interval = 1 / CFG.GhostHz
	while true do
		task.wait(interval)
		for _, recording in recordings do
			for other, ghost in recording.ghosts do
				local root = rootOf(other)
				if root and #ghost.track < CFG.MaxSeconds * CFG.GhostHz + 4 then
					local p = root.Position
					local look = root.CFrame.LookVector
					table.insert(ghost.track, { p.X, p.Y, p.Z, look.X, look.Z })
				end
			end
		end
	end
end

return Tapes
