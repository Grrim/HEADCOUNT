--!strict
-- Input for the camera: raise, record, play. Recording samples the real camera path as numbers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Conditions = require(ReplicatedStorage.Shared.Core.Conditions)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

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
-- Tonight's length of one recording; a short-tape night cuts it down.
local maxSeconds = CFG.MaxSeconds
local keyName: (action: string) -> string

local function stopRecording()
	if not recording then
		return
	end
	recording = false
	LensView.setRecording(false)
	Input.setState("Record", "idle")
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
	Input.setState("Record", "danger")
	AudioDirector.play("RecStart", 0.6)
	Net.get("RecordStart"):FireServer()
end

-- The key for an action on the device in hand, for on-screen instructions.
keyName = function(action: string): string
	local device = Ui.device()
	if device == "touch" then
		return Strings.get(`btn_{action}`)
	elseif device == "gamepad" then
		return ({ lens = "L2", rec = "R2", play = "Y" } :: any)[action] or action
	end
	return ({ lens = "Q", rec = "R", play = "T" } :: any)[action] or action
end
Viewfinder.keyName = keyName

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
		Input.setState("Lens", if raised then "active" else "idle")
		if not raised then
			stopRecording()
		end
	end)

	Net.get("SessionState").OnClientEvent:Connect(function(state)
		maxSeconds = Conditions.byId(state.condition).tapeSeconds
		LensView.setRecordLimit(maxSeconds)
	end)
	local savedCount = 0
	Net.get("TapeList").OnClientEvent:Connect(function(list)
		tapesLeft = list.left
		latestTapeId = list.latestId
		LensView.setTapes(math.max(0, tapesLeft), CFG.PerPlayer)
		Input.setState("Play", if latestTapeId then "idle" else "disabled")
		if list.count > savedCount then
			-- The take is safe: say so where the player is looking, and what to do with it.
			LensView.stamp(Strings.get("tape_saved_stamp", list.count, keyName("play")))
		end
		savedCount = list.count
	end)
	LensView.setTapes(tapesLeft, CFG.PerPlayer)
	Input.setState("Play", "disabled")

	RunService.RenderStepped:Connect(function()
		if not recording then
			return
		end
		local now = os.clock()
		local elapsed = now - recordStart
		if elapsed >= maxSeconds then
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
