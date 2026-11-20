--!strict
-- Watching your latest tape on a shift (T / Y / PLAY). The main camera flies the recorded path
-- through the live world in the tape's look, as in Mission 001's Playback: nothing here needs a
-- screen capture. What the tape shows that the eye did not is filled in only while it plays: the
-- code painted on a code door the tape framed (the server sends only those).
--
-- Your body stays behind, standing still. After the team's first viewing on a floor, each one
-- pulls the Registrar a node closer, and from the second viewing of a tape he stands in its
-- picture, nearer every time.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Grades = require(ReplicatedStorage.Shared.Config.Lighting)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Tape = require(ReplicatedStorage.Shared.Core.Tape)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)
local Vhs = require(ReplicatedStorage.ClientCommon.Vhs)

local ShiftPlayback = {}

local player = Players.LocalPlayer
local controllers: { [string]: any }
local gui: ScreenGui
local infoLabel: TextLabel
local captionLabel: TextLabel
local band: Frame
local progressFill: Frame
local grade: ColorCorrectionEffect
local connection: RBXScriptConnection? = nil
local isActive = false
local shownCodes: { GuiObject } = {}

local function setControls(enabled: boolean)
	local ok, err = pcall(function()
		local playerModule = require(
			player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
		) :: any
		local controls = playerModule:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
	if not ok then
		warn(`[ShiftPlayback] controls: {err}`)
	end
end

local function buildGui()
	gui = Ui.screen("ShiftPlayback", 4, true)
	gui.Enabled = false
	for _, side in { 0, 1 } do
		Ui.frame({
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.fromScale(side, 0),
			Size = UDim2.new(0.125, 0, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
		}, gui)
	end
	Ui.mono({
		Position = UDim2.fromScale(0.15, 0.06),
		Size = UDim2.fromOffset(240, 30),
		FontFace = Ui.Fonts.MonoBold,
		TextSize = 24,
		TextStrokeTransparency = 0.5,
		Text = "▶ PLAY",
	}, gui)
	infoLabel = Ui.mono({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.85, 0.06),
		Size = UDim2.fromOffset(320, 30),
		FontFace = Ui.Fonts.MonoBold,
		TextSize = 18,
		TextColor3 = Ui.C.Danger,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, gui)
	local timeline = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -74),
		Size = UDim2.new(0.66, 0, 0, 3),
		BackgroundColor3 = Ui.C.Text,
		BackgroundTransparency = 0.75,
		ZIndex = 3,
	}, gui)
	progressFill = Ui.frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.C.Text,
		ZIndex = 3,
	}, timeline)
	Ui.mono({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(420, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextTransparency = 0.25,
		TextStrokeTransparency = 0.5,
		Text = "T to stop. You stand still while you watch.",
		ZIndex = 3,
	}, gui)
	captionLabel = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.new(0.7, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		Text = "",
		Visible = false,
	}, gui)
	band = Ui.frame({
		Position = UDim2.fromScale(0.125, 0),
		Size = UDim2.new(0.75, 0, 0.03, 0),
		BackgroundColor3 = Palette.Paper,
		BackgroundTransparency = 0.88,
	}, gui)
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ShiftTapeGrade"
	grade.Enabled = false
	for key, value in Grades.Playback do
		(grade :: any)[key] = value
	end
	grade.Parent = Lighting
	Vhs.apply(gui, { strength = 1, focusBlur = 0.3 })
end

-- Paints each code the tape caught onto its door, for the length of the viewing.
local function showCodes(codes: { any })
	local map = Workspace:FindFirstChild("Map")
	local floor = map and map:FindFirstChild("Floor")
	if not floor then
		return
	end
	local byId: { [number]: string } = {}
	for _, entry in codes do
		if typeof(entry.id) == "number" and typeof(entry.code) == "string" then
			byId[entry.id] = entry.code
		end
	end
	for _, door in floor:GetChildren() do
		local id = door:GetAttribute("CodeDoorId")
		local code = if typeof(id) == "number" then byId[id] else nil
		if code then
			local spaced = table.concat(string.split(code, ""), " ")
			for _, item in door:GetChildren() do
				if item:IsA("SurfaceGui") and item.Name == "CodeGui" then
					local label = item:FindFirstChild("CodeText")
					if label and label:IsA("TextLabel") then
						label.Text = spaced
					end
					item.Enabled = true
					table.insert(shownCodes, item)
				end
			end
		end
	end
end

local function hideCodes()
	for _, item in shownCodes do
		if item.Parent then
			(item :: any).Enabled = false
			local label = item:FindFirstChild("CodeText")
			if label and label:IsA("TextLabel") then
				label.Text = ""
			end
		end
	end
	shownCodes = {}
end

function ShiftPlayback.active(): boolean
	return isActive
end

function ShiftPlayback.stop()
	if not isActive then
		return
	end
	isActive = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	gui.Enabled = false
	grade.Enabled = false
	hideCodes()
	controllers.RegistrarView.setOverride(nil)
	AudioDirector.setLoop("TapeMotor", false)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = Config.Lens.NormalFov
	end
	LensView.setLocked(false)
	setControls(true)
	Input.setState("Play", "idle")
	Net.get("PlayEnded"):FireServer()
end

local function start(clip: any)
	if isActive or typeof(clip) ~= "table" or typeof(clip.track) ~= "table" then
		return
	end
	if #clip.track == 0 then
		return
	end
	isActive = true
	controllers.ShiftCamera.stopRecording()
	if LensView.raised then
		LensView.setRaised(false)
	end
	LensView.setLocked(true)
	setControls(false)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Lens.Fov
	gui.Enabled = true
	grade.Enabled = true
	Input.setState("Play", "active")
	infoLabel.Text = if clip.free
		then `VIEWING {clip.viewings}  ·  FREE`
		else `VIEWING {clip.viewings}  ·  IT HEARS THIS`
	local codes = if typeof(clip.codes) == "table" then clip.codes else {}
	showCodes(codes)
	captionLabel.Text = if #codes > 0
		then "There's a code on the door. Read it, then enter it at the lock."
		else ""
	captionLabel.Visible = #codes > 0
	AudioDirector.setLoop("TapeMotor", true, 0.35, 0.92)

	local track = clip.track
	local hz = if typeof(clip.hz) == "number" then clip.hz else Config.Tape.SampleHz
	local duration = Tape.duration(track, hz)
	local elapsed = 0
	local distance = clip.registrarDistance
	if typeof(distance) == "number" then
		-- He stands in the middle of the shot, a little nearer every time this tape is watched.
		local midpoint = Tape.sampleAt(track, duration / 2, hz)
		local look = Vector3.new(midpoint[4], 0, midpoint[6])
		if look.Magnitude > 0.01 then
			local place = Vector3.new(midpoint[1], midpoint[2] - 4.5, midpoint[3])
				+ look.Unit * distance
			controllers.RegistrarView.setOverride(CFrame.new(place))
		end
	end

	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			ShiftPlayback.stop()
			return
		end
		local s = Tape.sampleAt(track, elapsed, hz)
		local position = Vector3.new(s[1], s[2], s[3])
		camera.CFrame = CFrame.lookAt(position, position + Vector3.new(s[4], s[5], s[6]))
		band.Position = UDim2.fromScale(0.125, (elapsed * 0.27) % 1)
		progressFill.Size = UDim2.fromScale(math.clamp(elapsed / duration, 0, 1), 1)
	end)
end

local function onPlay()
	if isActive then
		ShiftPlayback.stop()
		return
	end
	if player:GetAttribute("OffFrame") == true then
		return
	end
	if controllers.ShiftHud.phase() ~= "floor" then
		controllers.ShiftHud.toast("Tapes are for the floor they were shot on.")
		return
	end
	Net.get("PlayTape"):FireServer()
end

local function refreshButton()
	local kept = player:GetAttribute("TapesKept")
	Input.setState(
		"Play",
		if isActive
			then "active"
			elseif typeof(kept) == "number" and kept > 0 then "idle"
			else "disabled"
	)
end

function ShiftPlayback.init(all: { [string]: any })
	controllers = all
	buildGui()
	Net.get("TapePlay").OnClientEvent:Connect(start)
end

function ShiftPlayback.start()
	Input.bind("Play", onPlay, { Enum.KeyCode.T, Enum.KeyCode.ButtonY }, Strings.get("btn_play"), 3)
	player:GetAttributeChangedSignal("TapesKept"):Connect(refreshButton)
	refreshButton()
	-- Cut out of frame, or the floor left behind: the viewing ends.
	player:GetAttributeChangedSignal("OffFrame"):Connect(function()
		if player:GetAttribute("OffFrame") == true then
			ShiftPlayback.stop()
		end
	end)
	Net.get("ShiftState").OnClientEvent:Connect(function(state)
		if state.phase ~= "floor" then
			ShiftPlayback.stop()
		end
	end)
end

return ShiftPlayback
