--!strict
-- Studio-only: plays the 15-second teaser from docs/10_TEST_FILMIKIEM.md on the real map, with the
-- real viewfinder and the real Registrar, so it can be screen-recorded. It runs only in Studio and
-- only when Workspace has the attribute Teaser = true (see server/Teaser.luau).
--
-- Every picture and sound is a function of the time since the roll: the camera, the friend's walk
-- and the tilt are computed from t each frame, and one-shot cues fire when t crosses their time in
-- the table T. Retiming the film is an edit to T and nothing else.
--
-- Keys before the roll: 1 / 2 / 3 pick the hook (A / B / C), P rolls. After the end card: R resets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Teaser = {}

-- The timeline, in seconds from the roll. docs/10_TEST_FILMIKIEM.md shows the same beats.
local T = {
	hookLine2 = 1.1,
	hookOut = 3.2,
	chatIn = 3.5,
	silence = 6.2,
	chatOut = 6.5,
	lensUp = 7.0,
	-- The shutter is closed from 7.0 to about 7.07; the swap happens behind it.
	reveal = 7.07,
	recOn = 7.4,
	tiltStart = 8.0,
	tiltEnd = 10.4,
	lurch = 10.6,
	black = 11.4,
	title = 11.8,
	tagline = 12.4,
	footnote = 12.9,
	done = 15.0,
}

local RED = Ui.C.Danger:ToHex()

type Hook = { lines: { string }, chat: string }

local HOOKS: { [string]: Hook } = {
	A = {
		lines = { "THERE WERE 3 OF US.", `THE HEADCOUNT SAID <font color="#{RED}">4</font>.` },
		chat = "where r u?? im in the basement",
	},
	B = {
		lines = { "MY FRIEND WAS IN THE BASEMENT.", "SO WHO WAS I FOLLOWING?" },
		chat = "bro im STILL in the basement. where r u",
	},
	C = {
		lines = { "ONE OF US ISN'T HUMAN.", "ONLY THE CAMERA CAN TELL." },
		chat = "where r u?? im in the basement",
	},
}

-- The curtain corridor west of the hall, walked from south to north (towards -Z).
local LANE_X = (Layout.CORRIDOR.minX + Layout.HALL.minX) / 2 + 0.8 -- clear of the curtains
local FRIEND_START_Z = -11
local FRIEND_STOP_Z = -34
local FRIEND_SPEED = 5.4
local WALK_END = (FRIEND_START_Z - FRIEND_STOP_Z) / FRIEND_SPEED
local CAM_START_Z = Layout.CORRIDOR.maxZ - 1
local CAM_GAP = 8
local EYE = 4.6
local PUSH_SPEED = 0.45
local TILT_DEGREES = 22
local STEP_LENGTH = 2.2
local LURCH_GAP = 2.6
local FOV = 70

local WALK_ANIMATION = "rbxassetid://507777826" -- default R15 walk
local IDLE_ANIMATION = "rbxassetid://507766666" -- default R15 idle
-- Ground speed the walk cycle matches at playback speed 1. Tune it if the feet slide.
local WALK_ANIMATION_STUDS = 8

-- The north end of the corridor is raised 3 studs, reached by a ramp from z -22 to -30.
local function floorY(z: number): number
	if z > -22 then
		return 0
	elseif z < -30 then
		return 3
	end
	return (-22 - z) / 8 * 3
end

local function smooth(u: number): number
	local x = math.clamp(u, 0, 1)
	return x * x * (3 - 2 * x)
end

local function friendZ(t: number): number
	return math.max(FRIEND_STOP_Z, FRIEND_START_Z - FRIEND_SPEED * t)
end

local function cameraZ(t: number): number
	local z = math.min(CAM_START_Z, friendZ(t) + CAM_GAP)
	if t > T.reveal then
		z -= PUSH_SPEED * (math.min(t, T.black) - T.reveal)
	end
	return z
end

local function cameraAt(t: number): CFrame
	local camZ = cameraZ(t)
	local travelled = CAM_START_Z - camZ
	local bob = -math.abs(math.sin(travelled / STEP_LENGTH * math.pi)) * 0.08
	local eye = Vector3.new(LANE_X + 0.3, floorY(camZ) + EYE + bob, camZ)
	local target = Vector3.new(LANE_X, floorY(friendZ(t)) + 3.2, friendZ(t))
	local base = CFrame.lookAt(eye, target)
	local tilt = math.rad(TILT_DEGREES) * smooth((t - T.tiltStart) / (T.tiltEnd - T.tiltStart))
	-- Held by hand: a slow sway, more nervous once the lens is up.
	local nerves = if t > T.reveal then 1.6 else 1
	local pitch = (math.sin(t * 1.3) * 0.004 + math.sin(t * 2.9) * 0.002) * nerves
	local yaw = math.sin(t * 1.7 + 1) * 0.003 * nerves
	local roll = math.sin(t * 0.9) * 0.004 * nerves
	local kick = math.max(0, 1 - (t - T.lurch) / 0.5)
	if t < T.lurch then
		kick = 0
	end
	pitch += kick * 0.025 * math.sin(t * 61)
	yaw += kick * 0.02 * math.sin(t * 47)
	return base * CFrame.Angles(tilt + pitch, yaw, roll)
end

local function figureAt(t: number): CFrame
	if t < T.lurch then
		return CFrame.new(LANE_X, floorY(FRIEND_STOP_Z), FRIEND_STOP_Z)
	end
	local z = cameraZ(T.lurch) - LURCH_GAP
	return CFrame.new(LANE_X, floorY(z), z)
end

-- Interface: everything sits inside one 9:16 frame centred on the screen, so a portrait device
-- emulator shows it whole and a landscape recording can be cropped to it.
type Scaled = { label: TextLabel, px: number, stroke: UIStroke? }

local scaled: { Scaled } = {}
local root: Frame

local function rescale()
	-- Sizes are written in pixels of a 1080-wide frame and scaled to the real one. TextSize is
	-- capped at 100 by the engine.
	local unit = root.AbsoluteSize.X / 1080
	for _, item in scaled do
		item.label.TextSize = math.clamp(math.floor(item.px * unit + 0.5), 1, 100)
		if item.stroke then
			item.stroke.Thickness = math.max(1, 4 * unit)
		end
	end
end

local function label(props: { [string]: any }, px: number, outlined: boolean): TextLabel
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency = 1
	made.TextWrapped = true
	made.RichText = true
	made.TextColor3 = Ui.C.Text
	made.TextTransparency = 1
	made.ZIndex = 5
	for key, value in props do
		(made :: any)[key] = value
	end
	local stroke: UIStroke? = nil
	if outlined then
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.new(0, 0, 0)
		outline.Transparency = 0.15
		outline.Parent = made
		stroke = outline
	end
	made.Parent = root
	table.insert(scaled, { label = made, px = px, stroke = stroke })
	return made
end

local function fade(object: GuiObject, property: string, to: number, seconds: number)
	Ui.tween(object, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		[property] = to,
	})
end

function Teaser.enabled(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("Teaser") == true
end

function Teaser.run(registrarModule: ModuleScript)
	local player = Players.LocalPlayer
	UserInputService.MouseIconEnabled = false
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)

	local RegistrarView = require(registrarModule) :: any
	RegistrarView.init({})
	task.spawn(RegistrarView.start)

	Workspace:WaitForChild("Map")
	local template = ReplicatedStorage:WaitForChild("TeaserFriend") :: Model
	local friendName = template:GetAttribute("DisplayName") or "Max"
	local friend = template:Clone()
	local humanoid = friend:FindFirstChildOfClass("Humanoid") :: Humanoid
	local rootPart = friend:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	rootPart.Anchored = true
	local rootHeight = humanoid.HipHeight + rootPart.Size.Y / 2
	friend.Parent = Workspace

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local function load(id: string): AnimationTrack?
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok then
			warn(`[Teaser] animation {id} did not load: {track}`)
			return nil
		end
		return track
	end
	local walk = load(WALK_ANIMATION)
	local idle = load(IDLE_ANIMATION)

	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV

	-- The film's interface.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Teaser"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.Parent = player:WaitForChild("PlayerGui")
	root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	-- Above the black card (a sibling), so the end titles show on it.
	root.ZIndex = 10
	root.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 9 / 16
	aspect.Parent = root

	local hookA = label({
		Position = UDim2.fromScale(0.07, 0.1),
		Size = UDim2.fromScale(0.86, 0.075),
		FontFace = Ui.Fonts.DisplayBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 88, true)
	local hookB = label({
		Position = UDim2.fromScale(0.07, 0.18),
		Size = UDim2.fromScale(0.86, 0.075),
		FontFace = Ui.Fonts.DisplayBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 88, true)

	local chatBox = Instance.new("Frame")
	chatBox.Position = UDim2.fromScale(0.05, 0.66)
	chatBox.Size = UDim2.fromScale(0.9, 0.085)
	chatBox.BackgroundColor3 = Color3.new(0, 0, 0)
	chatBox.BackgroundTransparency = 1
	chatBox.BorderSizePixel = 0
	chatBox.ZIndex = 4
	chatBox.Parent = root
	local chat = label({
		Position = UDim2.fromScale(0.08, 0.668),
		Size = UDim2.fromScale(0.84, 0.07),
		FontFace = Ui.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 52, false)

	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Ui.C.Ink
	black.BorderSizePixel = 0
	black.Visible = false
	black.ZIndex = 8
	black.Parent = gui
	local title = label({
		Position = UDim2.fromScale(0.05, 0.4),
		Size = UDim2.fromScale(0.9, 0.09),
		FontFace = Ui.Fonts.DisplayBold,
		Text = "HEADCOUNT",
		ZIndex = 9,
	}, 150, false)
	local rule = Instance.new("Frame")
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.fromScale(0.5, 0.5)
	rule.Size = UDim2.fromScale(0, 0.003)
	rule.BackgroundColor3 = Ui.C.Danger
	rule.BorderSizePixel = 0
	rule.ZIndex = 9
	rule.Parent = root
	local tagline = label({
		Position = UDim2.fromScale(0.05, 0.52),
		Size = UDim2.fromScale(0.9, 0.05),
		FontFace = Ui.Fonts.Display,
		Text = "One of you isn't human.",
		ZIndex = 9,
	}, 60, false)
	local footnote = label({
		Position = UDim2.fromScale(0.05, 0.88),
		Size = UDim2.fromScale(0.9, 0.03),
		FontFace = Ui.Fonts.Mono,
		TextColor3 = Ui.C.Muted,
		Text = "IN-ENGINE CONCEPT · IN DEVELOPMENT FOR ROBLOX",
		ZIndex = 9,
	}, 30, false)

	local hint = label({
		Position = UDim2.fromScale(0.05, 0.94),
		Size = UDim2.fromScale(0.9, 0.03),
		FontFace = Ui.Fonts.Mono,
		TextColor3 = Ui.C.Accent,
		TextTransparency = 0,
		ZIndex = 9,
	}, 30, true)

	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	rescale()

	local configuredHook = Workspace:GetAttribute("TeaserHook")
	local hookId = if typeof(configuredHook) == "string" and HOOKS[configuredHook]
		then configuredHook
		else "A"
	local rolling = false
	local finished = false
	local startedAt = 0
	local fired: { [string]: boolean } = {}
	local lastStep = 0

	local function showHint()
		hint.Text = `HOOK {hookId}  ·  1 / 2 / 3 PICKS  ·  P ROLLS`
		hint.TextTransparency = 0
	end

	local function placeFriend(t: number)
		local z = friendZ(t)
		rootPart.CFrame = CFrame.new(LANE_X, floorY(z) + rootHeight, z)
	end

	local function arm()
		rolling, finished = false, false
		fired = {}
		lastStep = 0
		for _, item in scaled do
			if item.label ~= hint then
				item.label.TextTransparency = 1
			end
		end
		chatBox.BackgroundTransparency = 1
		rule.Size = UDim2.fromScale(0, 0.003)
		black.Visible = false
		RegistrarView.setOverride(nil)
		LensView.setRecording(false)
		LensView.setRaised(false)
		AudioDirector.setBed("MissionBed", false, 0, 0.05)
		friend.Parent = Workspace
		if walk then
			walk:Stop(0)
		end
		if idle then
			idle:Stop(0)
		end
		placeFriend(0)
		camera.CFrame = cameraAt(0)
		showHint()
	end

	-- One-shot cues, in timeline order.
	local cues: { { at: number, name: string, run: () -> () } } = {
		{
			at = T.hookLine2,
			name = "hookLine2",
			run = function()
				fade(hookB, "TextTransparency", 0, 0.25)
			end,
		},
		{
			at = T.hookOut,
			name = "hookOut",
			run = function()
				fade(hookA, "TextTransparency", 1, 0.15)
				fade(hookB, "TextTransparency", 1, 0.15)
			end,
		},
		{
			at = WALK_END,
			name = "friendStops",
			run = function()
				if walk then
					walk:Stop(0.3)
				end
				if idle then
					idle:Play(0.3)
				end
			end,
		},
		{
			at = T.chatIn,
			name = "chatIn",
			run = function()
				fade(chatBox, "BackgroundTransparency", 0.45, 0.2)
				fade(chat, "TextTransparency", 0, 0.2)
			end,
		},
		{
			at = T.silence,
			name = "silence",
			run = function()
				AudioDirector.silence(2)
			end,
		},
		{
			at = T.chatOut,
			name = "chatOut",
			run = function()
				fade(chatBox, "BackgroundTransparency", 1, 0.15)
				fade(chat, "TextTransparency", 1, 0.15)
			end,
		},
		{
			at = T.lensUp,
			name = "lensUp",
			run = function()
				LensView.setRaised(true)
			end,
		},
		{
			at = T.reveal,
			name = "reveal",
			run = function()
				friend.Parent = nil
				RegistrarView.setOverride(figureAt(T.reveal))
				AudioDirector.play("Reach", 1, 0.9)
				AudioDirector.setBed("MissionBed", true, 0.35, 0.4)
			end,
		},
		{
			at = T.recOn,
			name = "recOn",
			run = function()
				LensView.setRecording(true)
			end,
		},
		{
			at = T.lurch,
			name = "lurch",
			run = function()
				RegistrarView.setOverride(figureAt(T.lurch))
				AudioDirector.play("RegistrarJump", 0.8)
				LensView.flash(0.5)
			end,
		},
		{
			at = T.black,
			name = "black",
			run = function()
				black.Visible = true
				RegistrarView.setOverride(nil)
				LensView.setRecording(false)
				AudioDirector.setBed("MissionBed", false, 0, 0.05)
				AudioDirector.silence(10)
			end,
		},
		{
			at = T.title,
			name = "title",
			run = function()
				fade(title, "TextTransparency", 0, 0.35)
				Ui.tween(
					rule,
					TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(0.4, 0.003) }
				)
				AudioDirector.play("Bell", 0.6)
			end,
		},
		{
			at = T.tagline,
			name = "tagline",
			run = function()
				fade(tagline, "TextTransparency", 0, 0.35)
			end,
		},
		{
			at = T.footnote,
			name = "footnote",
			run = function()
				fade(footnote, "TextTransparency", 0, 0.35)
			end,
		},
		{
			at = T.done,
			name = "done",
			run = function()
				finished = true
				print("[Teaser] done; press R to reset")
			end,
		},
	}

	local function roll()
		local hook = HOOKS[hookId]
		hookA.Text = hook.lines[1]
		hookB.Text = hook.lines[2]
		chat.Text = `<b><font color="#{Ui.C.Accent:ToHex()}">{friendName}:</font></b> {hook.chat}`
		hint.TextTransparency = 1
		-- Frame 0 already carries the first line of the hook.
		hookA.TextTransparency = 0
		if walk then
			walk:Play(0)
			walk:AdjustSpeed(FRIEND_SPEED / WALK_ANIMATION_STUDS)
		end
		startedAt = os.clock()
		rolling = true
		print(`[Teaser] rolling, hook {hookId}`)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject)
		local key = input.KeyCode
		if not rolling then
			if key == Enum.KeyCode.One or key == Enum.KeyCode.Two or key == Enum.KeyCode.Three then
				hookId = if key == Enum.KeyCode.One
					then "A"
					elseif key == Enum.KeyCode.Two then "B"
					else "C"
				showHint()
			elseif key == Enum.KeyCode.P then
				roll()
			end
		elseif finished and key == Enum.KeyCode.R then
			arm()
		end
	end)

	RunService:BindToRenderStep("Teaser", Enum.RenderPriority.Camera.Value + 1, function()
		camera.CameraType = Enum.CameraType.Scriptable
		if not rolling then
			camera.CFrame = cameraAt(0)
			return
		end
		local t = os.clock() - startedAt
		for _, cue in cues do
			if t >= cue.at and not fired[cue.name] then
				fired[cue.name] = true
				cue.run()
			end
		end
		if t < T.reveal then
			placeFriend(t)
		end
		camera.CFrame = cameraAt(math.min(t, T.black))
		-- A footstep each time the camera covers another stride.
		local step = (CAM_START_Z - cameraZ(math.min(t, T.reveal))) // STEP_LENGTH
		if step > lastStep then
			lastStep = step
			AudioDirector.play("Step", 0.22, 0.9 + (step % 3) * 0.05)
		end
	end)

	arm()
	print("[Teaser] ready: 1 / 2 / 3 pick the hook, P rolls")
end

return Teaser
