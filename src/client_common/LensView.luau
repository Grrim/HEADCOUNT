--!strict
-- The camcorder's viewfinder, shared by the hub tutorial and the missions. It owns the on-screen
-- frame, the colour grade, the field of view, the feel of raising and lowering the camera and the
-- report to the server. What the lens reveals is built by whoever subscribes to onChanged.
--
-- The difference between the eye and the lens has to be obvious at a glance: the lens is a
-- narrower, colder, grainier picture inside a frame, with a timecode, a record light and the
-- tape left; the eye is the plain world with nothing on it.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(script.Parent.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Grades = require(ReplicatedStorage.Shared.Config.Lighting)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(script.Parent.Ui)
local Vhs = require(script.Parent.Vhs)

local LensView = {}

LensView.raised = false

local listeners: { (raised: boolean) -> () } = {}
local recordListeners: { (on: boolean) -> () } = {}
LensView.recording = false
local locked = false
local gui: ScreenGui
local shutter: ScreenGui
local shutterTop: Frame
local shutterBottom: Frame
local recDot: Frame
local statusLabel: TextLabel
local timeLabel: TextLabel
local tapeRow: Frame
local tapeIcons: { Frame } = {}
local tapeLabel: TextLabel
local meter: Frame
local meterFill: Frame
local meterLabel: TextLabel
local stampLabel: TextLabel
local stampToken = 0
local recordingSince: number? = nil
local recordLimit = Config.Tape.MaxSeconds
local grade: ColorCorrectionEffect
local reportRemote: RemoteEvent? = nil
local frameParts: { Frame } = {}
local warningHolder: Frame
local warningBar: Frame
local warningAt = 0
local interferenceBars: { Frame } = {}
local interference = 0
local raisedAt = 0
local tapesLeft = 0
local tapesTotal = Config.Tape.PerPlayer

local INSET_X = 0.045
local INSET_Y = 0.065

-- The frame: long thin corner brackets, like the etched marks in a real viewfinder.
local function bracket(anchor: Vector2, position: UDim2)
	local arm, thick = 0.075, 2
	table.insert(
		frameParts,
		Ui.frame({
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.new(arm, 0, 0, thick),
			BackgroundColor3 = Ui.C.Text,
		}, gui)
	)
	table.insert(
		frameParts,
		Ui.frame({
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.new(0, thick, arm * 1.5, 0),
			BackgroundColor3 = Ui.C.Text,
		}, gui)
	)
end

local function buildGui()
	gui = Ui.screen("Viewfinder", 3, true)
	gui.Enabled = false
	bracket(Vector2.new(0, 0), UDim2.fromScale(INSET_X, INSET_Y))
	bracket(Vector2.new(1, 0), UDim2.fromScale(1 - INSET_X, INSET_Y))
	bracket(Vector2.new(0, 1), UDim2.fromScale(INSET_X, 1 - INSET_Y))
	bracket(Vector2.new(1, 1), UDim2.fromScale(1 - INSET_X, 1 - INSET_Y))

	-- Top left: the record light and its word. STBY is quiet; REC is red and blinks.
	local status = Ui.frame({
		Position = UDim2.new(INSET_X, 18, INSET_Y, 14),
		Size = UDim2.fromOffset(160, 26),
		BackgroundTransparency = 1,
	}, gui)
	recDot = Ui.frame({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Ui.C.Danger,
		Visible = false,
	}, status)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, recDot)
	statusLabel = Ui.mono({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		FontFace = Ui.Fonts.MonoBold,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 0.6,
		Text = Strings.get("standby"),
	}, status)

	timeLabel = Ui.mono({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1 - INSET_X, -18, INSET_Y, 14),
		Size = UDim2.fromOffset(180, 26),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 0.6,
		Text = "00:00:00",
	}, gui)

	-- Bottom left: one small cassette per tape the player holds, filled while unused.
	tapeRow = Ui.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(INSET_X, 18, 1 - INSET_Y, -14),
		Size = UDim2.fromOffset(240, 22),
		BackgroundTransparency = 1,
	}, gui)
	Ui.list(tapeRow, 6, true).VerticalAlignment = Enum.VerticalAlignment.Center
	tapeLabel = Ui.mono({
		LayoutOrder = 0,
		Size = UDim2.fromOffset(44, 22),
		TextSize = 15,
		FontFace = Ui.Fonts.MonoBold,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 0.6,
		Text = "TAPE",
	}, tapeRow)

	-- Bottom centre: the length of the take, filling as the tape runs. It is the only way to
	-- know a recording is about to stop by itself.
	meter = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - INSET_Y, -16),
		Size = UDim2.fromOffset(260, 22),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local track = Ui.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Ui.C.Text,
		BackgroundTransparency = 0.75,
	}, meter)
	meterFill = Ui.frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.C.Danger,
	}, track)
	meterLabel = Ui.mono({
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.6,
		Text = "",
	}, meter)

	-- The centre: a fine cross and four ticks, so the eye finds the middle without a crosshair.
	local centre = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
	}, gui)
	Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 1),
		BackgroundColor3 = Ui.C.Text,
		BackgroundTransparency = 0.35,
	}, centre)
	Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1, 14),
		BackgroundColor3 = Ui.C.Text,
		BackgroundTransparency = 0.35,
	}, centre)
	for _, tick in Ui.ticks(centre, Ui.C.Text, 7, 0) do
		tick.BackgroundTransparency = 0.45
		tick.Size = UDim2.fromOffset(tick.Size.X.Offset, tick.Size.Y.Offset)
		if tick.Size.X.Offset == 2 then
			tick.Size = UDim2.fromOffset(1, 7)
		else
			tick.Size = UDim2.fromOffset(7, 1)
		end
	end

	-- A short line of confirmation in the middle of the lower third: "TAPE 2 SAVED".
	stampLabel = Ui.display({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Ui.C.Ink,
		BackgroundTransparency = 1,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = 1,
		Text = "",
		ZIndex = 4,
	}, gui)
	Ui.pad(stampLabel, 14, 5)
end

-- Two black blades that close over the picture and open again: the moment the eye goes to the
-- viewfinder. It hides the pop of the grade and field of view changing.
local function buildShutter()
	shutter = Ui.screen("Shutter", 50, true)
	shutterTop = Ui.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.55),
		BackgroundColor3 = Color3.new(0, 0, 0),
	}, shutter)
	shutterBottom = Ui.frame({
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.55),
		BackgroundColor3 = Color3.new(0, 0, 0),
	}, shutter)
end

local function blink(closeSeconds: number, openSeconds: number, midway: () -> ())
	local close = TweenInfo.new(closeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local open = TweenInfo.new(openSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(shutterTop, close, { Position = UDim2.fromScale(0, 0.52) }):Play()
	local closing =
		TweenService:Create(shutterBottom, close, { Position = UDim2.fromScale(0, 0.48) })
	closing:Play()
	closing.Completed:Once(function()
		midway()
		TweenService:Create(shutterTop, open, { Position = UDim2.fromScale(0, 0) }):Play()
		TweenService:Create(shutterBottom, open, { Position = UDim2.fromScale(0, 1) }):Play()
	end)
end

-- The viewfinder's own warning that the thing in frame is noticing back.
local function buildWarnings()
	warningHolder = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 44),
		Size = UDim2.fromOffset(300, 34),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	Ui.mono({
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		FontFace = Ui.Fonts.MonoBold,
		TextColor3 = Ui.C.Danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Text = Strings.get("lens_registering"),
	}, warningHolder)
	local track = Ui.frame({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Ui.C.Danger,
		BackgroundTransparency = 0.75,
	}, warningHolder)
	warningBar = Ui.frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.C.Danger,
	}, track)
	for _ = 1, 5 do
		table.insert(
			interferenceBars,
			Ui.frame({
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = Ui.C.Text,
				BackgroundTransparency = 1,
				ZIndex = 0,
			}, gui)
		)
	end
end

-- 0 to 1: how far the thing in frame has got towards registering the player.
function LensView.setWarning(fraction: number)
	warningAt = os.clock()
	warningHolder.Visible = true
	warningBar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

-- 0 to 1. The closer he is, the less the tape holds together.
function LensView.setInterference(amount: number)
	interference = amount
end

local function applyFrameColor()
	local id = Players.LocalPlayer:GetAttribute("FrameId")
	for _, frame in Cosmetics.Frames do
		if frame.id == id then
			for _, part in frameParts do
				part.BackgroundColor3 = frame.color
			end
		end
	end
end

local function tweenGrade(values: { [string]: any }, seconds: number)
	TweenService:Create(grade, TweenInfo.new(seconds), values):Play()
end

local function applyView()
	local camera = Workspace.CurrentCamera
	local raised = LensView.raised
	gui.Enabled = raised
	if raised then
		tweenGrade(Grades.Lens, 0.05)
	else
		tweenGrade({
			Contrast = 0,
			Saturation = 0,
			Brightness = 0,
			TintColor = Color3.new(1, 1, 1),
		}, 0.05)
	end
	if camera then
		-- The field of view lands slightly past its target and settles, like a zoom ring.
		camera.FieldOfView = if raised then Config.Lens.Fov + 4 else Config.Lens.NormalFov - 3
		TweenService:Create(
			camera,
			TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ FieldOfView = if raised then Config.Lens.Fov else Config.Lens.NormalFov }
		):Play()
	end
end

function LensView.onChanged(callback: (raised: boolean) -> ())
	table.insert(listeners, callback)
end

function LensView.setRaised(raised: boolean)
	if locked and raised then
		return
	end
	if raised == LensView.raised then
		return
	end
	LensView.raised = raised
	raisedAt = os.clock()
	-- State flips at once so input and the server never wait on an animation; only the picture
	-- change waits for the blades to close.
	blink(if raised then 0.07 else 0.05, if raised then 0.16 else 0.12, applyView)
	AudioDirector.play("LensUp", 0.5, if raised then 1 else 0.85)
	if reportRemote then
		-- Raised is reported at once, not on the next 5 Hz tick: a record pressed straight after
		-- raising would otherwise reach the server before it knew the camera was up.
		local camera = Workspace.CurrentCamera
		if raised and camera then
			reportRemote:FireServer(true, camera.CFrame)
		elseif not raised then
			reportRemote:FireServer(false)
		end
	end
	if not raised then
		LensView.setRecording(false)
	end
	for _, callback in listeners do
		task.spawn(callback, raised)
	end
end

function LensView.toggle()
	LensView.setRaised(not LensView.raised)
end

-- Locked while something else owns the camera, such as a tape playing.
function LensView.setLocked(value: boolean)
	locked = value
	if value then
		LensView.setRaised(false)
	end
end

local function drawTapes()
	for _, icon in tapeIcons do
		icon:Destroy()
	end
	table.clear(tapeIcons)
	local total = math.max(tapesTotal, tapesLeft)
	for index = 1, total do
		local full = index <= tapesLeft
		-- A cassette: a small box with two reel holes.
		local box = Ui.frame({
			LayoutOrder = index,
			Size = UDim2.fromOffset(24, 15),
			BackgroundColor3 = Ui.C.Text,
			BackgroundTransparency = if full then 0.1 else 1,
		}, tapeRow)
		Ui.stroke(box, Ui.C.Text, if full then 0.1 else 0.5, 1)
		for _, x in { 0.3, 0.7 } do
			local hole = Ui.frame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, 0.5),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = if full then Ui.C.Ink else Ui.C.Text,
				BackgroundTransparency = if full then 0 else 0.5,
			}, box)
			Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, hole)
		end
		table.insert(tapeIcons, box)
	end
	tapeLabel.TextColor3 = if tapesLeft == 0 then Ui.C.Danger else Ui.C.Text
end

-- The lobby has no tapes to count; it hides the cassette row instead of showing an empty one.
function LensView.setTapeCounterVisible(visible: boolean)
	tapeRow.Visible = visible
end

function LensView.setTapes(left: number, total: number?)
	tapesLeft = left
	if total then
		tapesTotal = total
	end
	drawTapes()
end

-- How long one recording may run before the camera stops it.
function LensView.setRecordLimit(seconds: number)
	recordLimit = seconds
end

-- A short confirmation over the lower third of the picture, gone in two seconds.
function LensView.stamp(text: string, color: Color3?)
	stampToken += 1
	local token = stampToken
	stampLabel.Text = text
	stampLabel.TextColor3 = color or Ui.C.Text
	stampLabel.TextTransparency = 0
	stampLabel.BackgroundTransparency = 0.35
	local scale = stampLabel:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", {}, stampLabel)
	scale.Scale = 1.12
	Ui.tween(scale, Ui.Motion.Base, { Scale = 1 })
	task.delay(1.9, function()
		if token == stampToken then
			Ui.tween(
				stampLabel,
				Ui.Motion.Slow,
				{ TextTransparency = 1, BackgroundTransparency = 1 }
			)
		end
	end)
end

-- A white flash over the whole picture, for the moment something is caught on tape.
function LensView.flash(strength: number?)
	local layer = Ui.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1 - (strength or 0.35),
		ZIndex = 6,
	}, gui)
	local fade =
		Ui.tween(layer, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	fade.Completed:Once(function()
		layer:Destroy()
	end)
end

function LensView.onRecording(callback: (on: boolean) -> ())
	table.insert(recordListeners, callback)
end

function LensView.setRecording(on: boolean)
	local was = recordingSince ~= nil
	LensView.recording = on
	if was ~= on then
		for _, callback in recordListeners do
			task.spawn(callback, on)
		end
	end
	recordingSince = if on then os.clock() else nil
	statusLabel.Text = Strings.get(if on then "rec" else "standby")
	statusLabel.TextColor3 = if on then Ui.C.Danger else Ui.C.Muted
	statusLabel.Position = UDim2.fromOffset(if on then 20 else 0, 0)
	recDot.Visible = on
	meter.Visible = on
	meterFill.Size = UDim2.fromScale(0, 1)
	AudioDirector.setLoop("TapeMotor", on, 0.3, 1)
	if was and not on then
		AudioDirector.play("RecStart", 0.4, 0.8)
	end
end

function LensView.init(reportsToServer: RemoteEvent?)
	reportRemote = reportsToServer
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LensGrade"
	grade.Parent = Lighting
	buildGui()
	buildShutter()
	buildWarnings()
	drawTapes()
	-- A camcorder picture, not a clean one: light scanlines and a lens that softens the distance.
	Vhs.apply(gui, { strength = 0.55, focusBlur = 0.12 })
	applyFrameColor()
	Players.LocalPlayer:GetAttributeChangedSignal("FrameId"):Connect(applyFrameColor)

	-- A held camera is never perfectly still. The sway is tiny and added after the engine's camera
	-- has moved. The engine reads its look direction back from the camera every frame, so pitch
	-- and yaw are applied as the change since last frame (never accumulating into drift); roll is
	-- rebuilt by the engine each frame, so it is applied whole.
	local swayPitch, swayYaw = 0, 0
	RunService:BindToRenderStep("LensSway", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local active = LensView.raised
			and not locked
			and camera.CameraType == Enum.CameraType.Custom
		local pitch, yaw, roll = 0, 0, 0
		if active then
			local t = os.clock()
			local settle = math.max(0, 1 - (t - raisedAt) / 0.35)
			pitch = math.sin(t * 1.3) * 0.0016 + math.sin(t * 2.9) * 0.0008 - settle * settle * 0.01
			yaw = math.sin(t * 1.7 + 1) * 0.0012
			roll = math.sin(t * 0.9) * 0.0022
		elseif camera.CameraType ~= Enum.CameraType.Custom then
			-- A scripted camera (a tape, the ending) owns the picture; forget the old offset.
			swayPitch, swayYaw = 0, 0
			return
		end
		if pitch == 0 and yaw == 0 and swayPitch == 0 and swayYaw == 0 then
			return
		end
		camera.CFrame *= CFrame.Angles(pitch - swayPitch, yaw - swayYaw, 0) * CFrame.Angles(
			0,
			0,
			roll
		)
		swayPitch, swayYaw = pitch, yaw
	end)

	local lastReport = 0
	local interval = 1 / Config.Lens.ReportHz
	RunService.RenderStepped:Connect(function()
		if not LensView.raised then
			return
		end
		local now = os.clock()
		if warningHolder.Visible and now - warningAt > 0.7 then
			warningHolder.Visible = false
		end
		for _, bar in interferenceBars do
			if interference > 0.05 and math.random() < interference then
				bar.Position = UDim2.fromScale(0, math.random())
				bar.BackgroundTransparency = 1 - interference * 0.7
			else
				bar.BackgroundTransparency = 1
			end
		end
		if recordingSince then
			local elapsed = now - recordingSince
			timeLabel.Text = string.format("00:%02d:%02d", elapsed // 1, (elapsed % 1 * 25) // 1)
			local blinkOn = now % 1 < 0.6
			recDot.BackgroundTransparency = if blinkOn then 0 else 0.7
			local fraction = math.clamp(elapsed / recordLimit, 0, 1)
			meterFill.Size = UDim2.fromScale(fraction, 1)
			local left = math.max(0, math.ceil(recordLimit - elapsed))
			meterLabel.Text = string.format("%d s", left)
			meterLabel.TextColor3 = if left <= 3 then Ui.C.Danger else Ui.C.Text
		else
			timeLabel.Text = os.date("%H:%M:%S") :: string
		end
		if reportRemote and now - lastReport >= interval then
			lastReport = now
			local camera = Workspace.CurrentCamera
			if camera then
				reportRemote:FireServer(true, camera.CFrame)
			end
		end
	end)
end

return LensView
