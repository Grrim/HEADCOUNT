--!strict
-- Input for the camera: raise, record, play. Recording samples the real camera path as numbers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Viewfinder = {}

local CFG = Config.Tape
local controllers: { [string]: any }
local recording = false
local track: { { number } } = {}
local recordStart = 0
local lastSample = 0
local tapesLeft = CFG.PerPlayer
local latestTapeId: number? = nil
local stopRemote: RemoteEvent

local function stopRecording()
	if not recording then
		return
	end
	recording = false
	LensView.setRecording(false)
	stopRemote:FireServer(track)
	track = {}
end

local function startRecording()
	if not LensView.raised or recording then
		return
	end
	if tapesLeft <= 0 then
		controllers.Hud.subtitle(Strings.get("no_tapes"))
		return
	end
	recording = true
	track = {}
	recordStart = os.clock()
	lastSample = 0
	LensView.setRecording(true)
	AudioDirector.play("RecStart", 0.6)
	Net.get("RecordStart"):FireServer()
end

local function isCut(): boolean
	return Players.LocalPlayer:GetAttribute("OffFrame") == true
end

local function onLens()
	if isCut() then
		return
	end
	LensView.toggle()
end

local function onRecord()
	if isCut() then
		return
	end
	if recording then
		stopRecording()
	else
		startRecording()
	end
end

local function onPlay()
	if isCut() then
		return
	end
	if controllers.Playback.active() then
		controllers.Playback.stop()
		return
	end
	stopRecording()
	if not latestTapeId then
		controllers.Hud.subtitle(Strings.get("no_recordings"))
		return
	end
	Net.get("PlayTape"):FireServer(latestTapeId)
end

function Viewfinder.init(all: { [string]: any })
	controllers = all
	stopRemote = Net.get("RecordStop")
end

function Viewfinder.start()
	Input.bind(
		"Lens",
		onLens,
		{ Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2, Enum.KeyCode.Q },
		Strings.get("btn_lens"),
		1
	)
	Input.bind(
		"Record",
		onRecord,
		{ Enum.KeyCode.R, Enum.KeyCode.ButtonR2 },
		Strings.get("btn_rec"),
		2
	)
	Input.bind("Play", onPlay, { Enum.KeyCode.T, Enum.KeyCode.ButtonY }, Strings.get("btn_play"), 3)
	Input.bind("Light", function()
		Net.get("FlashlightToggle"):FireServer()
	end, { Enum.KeyCode.F, Enum.KeyCode.DPadUp }, Strings.get("btn_light"), 4)

	LensView.onChanged(function(raised)
		if not raised then
			stopRecording()
		end
	end)

	Net.get("TapeList").OnClientEvent:Connect(function(list)
		tapesLeft = list.left
		latestTapeId = list.latestId
		LensView.setTapes(tapesLeft)
	end)
	LensView.setTapes(tapesLeft)

	RunService.RenderStepped:Connect(function()
		if not recording then
			return
		end
		local now = os.clock()
		local elapsed = now - recordStart
		if elapsed >= CFG.MaxSeconds then
			stopRecording()
			return
		end
		local camera = Workspace.CurrentCamera
		if camera and now - lastSample >= 1 / CFG.SampleHz then
			lastSample = now
			local p = camera.CFrame.Position
			local l = camera.CFrame.LookVector
			table.insert(track, { p.X, p.Y, p.Z, l.X, l.Y, l.Z })
		end
	end)
end

return Viewfinder
