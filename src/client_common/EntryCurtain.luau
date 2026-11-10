--!strict
-- The title card that covers the first seconds after joining, while the world streams in and its
-- lighting settles (playtests showed about ten seconds of near-black, blurred picture otherwise).
-- It is the first thing a new player ever sees, so it sets the tone: a tape being rewound, the
-- name of the game, one rule of the world, and the picture fading up only once it looks right.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(script.Parent.Ui)
local Vhs = require(script.Parent.Vhs)

local EntryCurtain = {}

local MINIMUM_SECONDS = 7
local MAXIMUM_SECONDS = 20
local FADE_SECONDS = 1.6
local TIPS = 4

function EntryCurtain.show()
	local gui = Ui.screen("EntryCurtain", 100, true)
	local cover =
		Ui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0) }, gui)
	Vhs.apply(gui, { strength = 0.6, zIndex = 2 })
	local column = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(0.9, 0, 0, 140),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, cover)
	local title = Ui.display({
		Size = UDim2.new(1, 0, 0, 74),
		FontFace = Ui.Fonts.DisplayBold,
		TextSize = 72,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Text = Strings.get("loading_title"),
		ZIndex = 3,
	}, column)
	Ui.make("UITextSizeConstraint", { MaxTextSize = 72, MinTextSize = 40 }, title)
	title.TextScaled = true
	local rule = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = Ui.C.Danger,
		ZIndex = 3,
	}, column)
	local sub = Ui.eyebrow(Strings.get("loading_sub"), {
		Position = UDim2.fromOffset(0, 96),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 3,
	}, column)

	-- Bottom: what the machine is doing, and one rule of the world to read while it does it.
	local counter = Ui.mono({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -26),
		Size = UDim2.fromOffset(320, 18),
		FontFace = Ui.Fonts.MonoBold,
		TextSize = 14,
		TextColor3 = Ui.C.Muted,
		Text = "",
		ZIndex = 3,
	}, cover)
	local tip = Ui.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.new(0.8, 0, 0, 22),
		TextSize = 16,
		TextColor3 = Ui.C.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Text = Strings.get(`loading_tip_{math.random(1, TIPS)}`),
		ZIndex = 3,
	}, cover)
	local track = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.new(0.5, 0, 0, 2),
		BackgroundColor3 = Ui.C.Text,
		BackgroundTransparency = 0.85,
		ZIndex = 3,
	}, cover)
	local fill = Ui.frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.C.Text,
		BackgroundTransparency = 0.3,
		ZIndex = 3,
	}, track)

	Ui.tween(title, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { TextTransparency = 0 })
	Ui.tween(rule, TweenInfo.new(1.4, Enum.EasingStyle.Quart), { Size = UDim2.fromOffset(120, 2) })
	task.delay(0.6, function()
		Ui.tween(sub, TweenInfo.new(1), { TextTransparency = 0 })
		Ui.tween(tip, TweenInfo.new(1), { TextTransparency = 0.15 })
	end)

	local started = os.clock()
	-- A tape counter running backwards, and a blinking rewind mark.
	local ticker = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local left = math.max(0, 3600 * 0.18 - t * 97)
		local mark = if t % 1 < 0.55 then "◀◀" else "  "
		counter.Text = string.format(
			"%s  %s  %02d:%02d:%02d",
			mark,
			string.upper(Strings.get("hub_loading")),
			left // 3600,
			(left // 60) % 60,
			left % 60
		)
		fill.Size = UDim2.fromScale(math.clamp(t / MINIMUM_SECONDS, 0, 1), 1)
	end)

	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		Workspace:WaitForChild("Map", MAXIMUM_SECONDS)
		while
			os.clock() - started < MINIMUM_SECONDS
			or (ContentProvider.RequestQueueSize > 0 and os.clock() - started < MAXIMUM_SECONDS)
		do
			task.wait(0.2)
		end
		ticker:Disconnect()
		local fade = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Sine)
		for _, label in { title, sub, tip, counter } do
			TweenService:Create(label, TweenInfo.new(FADE_SECONDS / 2), { TextTransparency = 1 })
				:Play()
		end
		TweenService:Create(rule, TweenInfo.new(FADE_SECONDS / 2), { BackgroundTransparency = 1 })
			:Play()
		TweenService:Create(track, TweenInfo.new(FADE_SECONDS / 2), { BackgroundTransparency = 1 })
			:Play()
		TweenService:Create(fill, TweenInfo.new(FADE_SECONDS / 2), { BackgroundTransparency = 1 })
			:Play()
		task.wait(FADE_SECONDS / 3)
		TweenService:Create(cover, fade, { BackgroundTransparency = 1 }):Play()
		task.wait(FADE_SECONDS)
		gui:Destroy()
	end)
end

return EntryCurtain
