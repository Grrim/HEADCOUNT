--!strict
-- The camera on a shift: raise, record, flashlight. Raising slows you down and drains the battery
-- the server keeps; an empty battery drops the lens until it has charged back up.
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

local ShiftCamera = {}

local TAPE = Config.Tape
local WALK = 13
local WALK_LENS = WALK * 0.6

local controllers: { [string]: any }
local player = Players.LocalPlayer
local recording = false
local track: { { number } } = {}
local recordStart = 0
local lastSample = 0
local light: SpotLight? = nil

local function isCut(): boolean
	return player:GetAttribute("OffFrame") == true
end

local function stopRecording()
	if not recording then
		return
	end
	recording = false
	LensView.setRecording(false)
	Input.setState("Record", "idle")
	Net.get("RecordStop"):FireServer(track)
	track = {}
end

local function startRecording()
	if not LensView.raised or recording then
		return
	end
	if controllers.ShiftHud.phase() ~= "floor" then
		controllers.ShiftHud.toast("Nothing to film here. Footage counts on a floor.")
		return
	end
	local left = player:GetAttribute("TapesLeft")
	if typeof(left) == "number" and left <= 0 then
		controllers.ShiftHud.toast("No tapes left. The lift has new ones.")
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

local function onLens()
	if isCut() then
		return
	end
	if not LensView.raised and player:GetAttribute("BatteryEmpty") == true then
		controllers.ShiftHud.toast("Battery flat. Lower the camera and let it charge.")
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

local function onLight()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	if not light or light.Parent ~= head then
		local made = Instance.new("SpotLight")
		made.Angle = 50
		made.Range = 40
		made.Brightness = 2.2
		made.Color = Color3.fromRGB(255, 236, 200)
		made.Shadows = true
		made.Enabled = false
		made.Parent = head
		light = made
	end
	local current = light :: SpotLight
	current.Enabled = not current.Enabled
	AudioDirector.play("Wrong", 0.25, 1.4)
end

local function applyWalk()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if LensView.raised then WALK_LENS else WALK
	end
end

local function refreshTapes()
	local left = player:GetAttribute("TapesLeft")
	local total = player:GetAttribute("TapesMax")
	if typeof(left) == "number" and typeof(total) == "number" then
		LensView.setTapes(math.max(0, left), total)
	end
end

function ShiftCamera.init(all: { [string]: any })
	controllers = all
end

function ShiftCamera.start()
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
	Input.bind(
		"Light",
		onLight,
		{ Enum.KeyCode.F, Enum.KeyCode.DPadUp },
		Strings.get("btn_light"),
		4
	)
	LensView.setRecordLimit(Config.Shift.RecordSeconds)
	LensView.onChanged(function(raised)
		Input.setState("Lens", if raised then "active" else "idle")
		if not raised then
			stopRecording()
		end
		applyWalk()
	end)
	player:GetAttributeChangedSignal("BatteryEmpty"):Connect(function()
		if player:GetAttribute("BatteryEmpty") == true and LensView.raised then
			LensView.setRaised(false)
			controllers.ShiftHud.toast("Battery flat.")
		end
	end)
	player:GetAttributeChangedSignal("OffFrame"):Connect(function()
		if isCut() and LensView.raised then
			LensView.setRaised(false)
		end
	end)
	player:GetAttributeChangedSignal("TapesLeft"):Connect(refreshTapes)
	player:GetAttributeChangedSignal("TapesMax"):Connect(refreshTapes)
	player.CharacterAdded:Connect(function()
		light = nil
		task.defer(applyWalk)
	end)
	refreshTapes()

	RunService.RenderStepped:Connect(function()
		if not recording then
			return
		end
		local now = os.clock()
		if now - recordStart >= Config.Shift.RecordSeconds then
			stopRecording()
			return
		end
		local camera = Workspace.CurrentCamera
		if camera and now - lastSample >= 1 / TAPE.SampleHz then
			-- A steady 10 Hz: the server counts seconds as samples / 10. After a stall, start afresh.
			lastSample = if now - lastSample > 0.25 then now else lastSample + 1 / TAPE.SampleHz
			local p = camera.CFrame.Position
			local l = camera.CFrame.LookVector
			table.insert(track, { p.X, p.Y, p.Z, l.X, l.Y, l.Z })
		end
	end)
end

return ShiftCamera
