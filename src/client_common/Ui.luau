--!strict
-- The interface kit. Every screen in both places is built from these pieces, so the game reads as
-- one product: an archive's field equipment from 1979, built today.
--
--   Type     Oswald for headings (stencilled institutional signage), Builder Sans for anything a
--            player must read quickly, Roboto Mono for counters and timecodes, Special Elite for
--            paper documents.
--   Colour   ink surfaces, paper text, phosphor green for "you can act on this", record red for
--            danger and recording, amber for the radio. Nothing else.
--   Shape    square corners, hairline borders, small corner ticks like a case-file stamp.
--   Motion   short and quiet: 0.12-0.25 s eases, never in the player's way.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(script.Parent.AudioDirector)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local Ui = {}

-- Kept for any old caller; new code uses Ui.Fonts.
Ui.FONT = Enum.Font.BuilderSans

Ui.Fonts = {
	Display = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium),
	DisplayBold = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	BodyBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
	MonoBold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
	Type = Font.new("rbxasset://fonts/families/SpecialElite.json"),
}

-- Colour tokens. World colours stay in Config/Palette; these are for the interface only.
Ui.C = {
	Ink = Color3.fromRGB(9, 10, 11),
	Surface = Color3.fromRGB(15, 16, 17),
	Raised = Color3.fromRGB(26, 27, 27),
	Line = Color3.fromRGB(214, 206, 186),
	Text = Color3.fromRGB(232, 226, 210),
	Muted = Color3.fromRGB(160, 154, 140),
	Faint = Color3.fromRGB(104, 100, 92),
	Accent = Palette.Crt,
	AccentDeep = Color3.fromRGB(28, 40, 26),
	Danger = Palette.Rec,
	Radio = Color3.fromRGB(232, 178, 92),
	Paper = Color3.fromRGB(226, 216, 190),
	PaperInk = Color3.fromRGB(30, 26, 22),
}

-- Spacing scale, in pixels.
Ui.S = { xs = 4, sm = 8, md = 12, lg = 18, xl = 28 }

Ui.Motion = {
	Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Base = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
}

-- A phone in landscape is about 390 points tall; anything under 560 gets the compact layout.
function Ui.compact(): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	local size = camera.ViewportSize
	return size.Y < 560 or size.X < 900
end

function Ui.tween(instance: Instance, info: TweenInfo?, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info or Ui.Motion.Base, goal)
	tween:Play()
	return tween
end

-- fullBleed screens cover the notch area too (vignette, curtains, viewfinder frame). Everything
-- else stays inside the device's safe area, so a notch never eats a button.
function Ui.screen(name: string, displayOrder: number?, fullBleed: boolean?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = if fullBleed
		then Enum.ScreenInsets.None
		else Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 1
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Ui.make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance: any = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.frame(props: { [string]: any }, parent: Instance?): Frame
	local merged = { BorderSizePixel = 0, BackgroundColor3 = Ui.C.Ink }
	for key, value in props do
		merged[key] = value
	end
	return Ui.make("Frame", merged, parent)
end

local function textWith(font: Font, props: { [string]: any }, parent: Instance?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = font,
		TextColor3 = Ui.C.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.make("TextLabel", merged, parent)
end

-- Body text: anything a player reads in a hurry.
function Ui.text(props: { [string]: any }, parent: Instance?): TextLabel
	return textWith(Ui.Fonts.Body, props, parent)
end

-- Headings and titles.
function Ui.display(props: { [string]: any }, parent: Instance?): TextLabel
	return textWith(Ui.Fonts.Display, props, parent)
end

-- Counters, timecodes, codes.
function Ui.mono(props: { [string]: any }, parent: Instance?): TextLabel
	return textWith(Ui.Fonts.Mono, props, parent)
end

-- A small spaced-out heading over a block ("OBJECTIVE", "CLUES").
function Ui.eyebrow(text: string, props: { [string]: any }, parent: Instance?): TextLabel
	local merged: { [string]: any } = {
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = Ui.C.Muted,
		Text = Ui.spaced(text),
	}
	for key, value in props do
		merged[key] = value
	end
	return textWith(Ui.Fonts.MonoBold, merged, parent)
end

-- Short labels are set in capitals. Kept as a hook: Roblox has no letter-spacing, and a thin
-- space between letters renders as a missing glyph in some fonts, so no tracking is faked.
function Ui.spaced(text: string): string
	return string.upper(text)
end

function Ui.stroke(
	parent: Instance,
	color: Color3?,
	transparency: number?,
	thickness: number?
): UIStroke
	return Ui.make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Ui.C.Line,
		Transparency = transparency or 0.78,
		Thickness = thickness or 1,
	}, parent)
end

function Ui.pad(parent: Instance, x: number, y: number?)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
	}, parent)
end

function Ui.list(parent: Instance, gap: number?, horizontal: boolean?): UIListLayout
	return Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 6),
		FillDirection = if horizontal
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical,
	}, parent)
end

-- Four small L-shaped ticks in the corners, the mark of every panel and the viewfinder.
function Ui.ticks(parent: GuiObject, color: Color3?, arm: number?, inset: number?): { Frame }
	-- Inside a list or grid the ticks would be laid out like content; put them on a wrapper.
	assert(
		parent:FindFirstChildWhichIsA("UIGridStyleLayout") == nil,
		"Ui.ticks: parent has a layout; tick a wrapper frame instead"
	)
	local made = {}
	local length = arm or 10
	local offset = inset or -1
	local tint = color or Ui.C.Line
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local x = UDim.new(corner.X, if corner.X == 0 then offset else -offset)
		local y = UDim.new(corner.Y, if corner.Y == 0 then offset else -offset)
		local position = UDim2.new(x, y)
		table.insert(
			made,
			Ui.frame({
				Name = "Tick",
				AnchorPoint = corner,
				Position = position,
				Size = UDim2.fromOffset(length, 2),
				BackgroundColor3 = tint,
				ZIndex = 8,
			}, parent)
		)
		table.insert(
			made,
			Ui.frame({
				Name = "Tick",
				AnchorPoint = corner,
				Position = position,
				Size = UDim2.fromOffset(2, length),
				BackgroundColor3 = tint,
				ZIndex = 8,
			}, parent)
		)
	end
	return made
end

-- Hover, press and gamepad-selection feedback shared by every button: the border lights up in the
-- accent, the button dips a few percent while held, and a soft deck click confirms the press.
local selectionTemplate: Frame? = nil
local function selectionImage(): Frame
	if not selectionTemplate then
		local frame = Ui.frame({
			Name = "Selection",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		})
		Ui.stroke(frame, Ui.C.Accent, 0, 2)
		selectionTemplate = frame
	end
	return selectionTemplate :: Frame
end

local function feedback(button: TextButton, stroke: UIStroke, rest: number, silent: boolean?)
	local scale = Ui.make("UIScale", { Scale = 1 }, button)
	button.SelectionImageObject = selectionImage()
	local function lit(on: boolean)
		Ui.tween(stroke, Ui.Motion.Quick, { Transparency = if on then 0.05 else rest })
	end
	button.MouseEnter:Connect(function()
		lit(true)
	end)
	button.MouseLeave:Connect(function()
		lit(false)
		Ui.tween(scale, Ui.Motion.Quick, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		lit(true)
	end)
	button.SelectionLost:Connect(function()
		lit(false)
	end)
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			Ui.tween(scale, Ui.Motion.Quick, { Scale = 0.96 })
		end
	end)
	button.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			Ui.tween(scale, Ui.Motion.Base, { Scale = 1 })
		end
	end)
	if not silent then
		button.Activated:Connect(function()
			AudioDirector.play("RecStart", 0.18, 1.35)
		end)
	end
end

-- A secondary action: dark, hairline border, text in the accent.
function Ui.button(
	text: string,
	props: { [string]: any },
	parent: Instance?,
	onClick: (() -> ())?
): TextButton
	local merged: { [string]: any } = {
		Text = text,
		FontFace = Ui.Fonts.BodyBold,
		TextSize = 17,
		TextColor3 = Ui.C.Accent,
		BackgroundColor3 = Ui.C.Raised,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		TextWrapped = true,
	}
	local strokeColor = Ui.C.Accent
	for key, value in props do
		if key == "BorderColor3" then
			strokeColor = value
		elseif key ~= "BorderSizePixel" then
			merged[key] = value
		end
	end
	local button: TextButton = Ui.make("TextButton", merged, parent)
	local rest = 0.55
	local stroke = Ui.stroke(button, strokeColor, rest, 1)
	feedback(button, stroke, rest)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- The one action a screen is for: filled, so it reads before anything else on the panel.
function Ui.primary(
	text: string,
	props: { [string]: any },
	parent: Instance?,
	onClick: (() -> ())?,
	color: Color3?
): TextButton
	local fill = color or Ui.C.Accent
	local merged: { [string]: any } = {
		BackgroundColor3 = fill,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.new(1, 1, 1),
		TextColor3 = Ui.C.Ink,
		FontFace = Ui.Fonts.DisplayBold,
		TextSize = 19,
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.button(text, merged, parent, onClick)
end

-- A plain text button for "close" and "back": no box, so it never competes with the real action.
function Ui.quiet(
	text: string,
	props: { [string]: any },
	parent: Instance?,
	onClick: (() -> ())?
): TextButton
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = Ui.C.Muted,
		FontFace = Ui.Fonts.MonoBold,
		TextSize = 14,
		BorderColor3 = Ui.C.Line,
	}
	for key, value in props do
		merged[key] = value
	end
	local button = Ui.button(text, merged, parent, onClick)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0.85
	end
	return button
end

-- A key cap: "E", "Q", "R2". On touch the caller passes an icon word instead.
function Ui.keycap(text: string, props: { [string]: any }, parent: Instance?): TextLabel
	local merged: { [string]: any } = {
		Size = UDim2.fromOffset(28, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Ui.C.Text,
		BackgroundTransparency = 0,
		TextColor3 = Ui.C.Ink,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = text,
	}
	for key, value in props do
		merged[key] = value
	end
	local cap = textWith(Ui.Fonts.MonoBold, merged, parent)
	Ui.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, cap)
	Ui.make("UICorner", { CornerRadius = UDim.new(0, 3) }, cap)
	return cap
end

export type Panel = {
	root: Frame,
	header: Frame,
	title: TextLabel,
	subtitle: TextLabel,
	body: Frame,
	close: TextButton?,
}

-- A modal case-file panel: ink body, hairline border, corner ticks, a header with an eyebrow
-- ("ARCHIVE 03"), a title and an optional close. Sized by the caller; clamped to the screen.
function Ui.panel(
	parent: Instance,
	options: {
		eyebrow: string?,
		title: string,
		size: Vector2,
		onClose: (() -> ())?,
		closeText: string?,
		zIndex: number?,
	}
): Panel
	local z = options.zIndex or 10
	local root = Ui.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.88, 0),
		BackgroundColor3 = Ui.C.Surface,
		BackgroundTransparency = 0.04,
		ZIndex = z,
		Visible = false,
	}, parent)
	Ui.make("UISizeConstraint", { MaxSize = options.size }, root)
	Ui.stroke(root, Ui.C.Line, 0.8)
	Ui.ticks(root, Ui.C.Line, 12, -1)
	local header = Ui.frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, root)
	Ui.pad(header, 20, 10)
	Ui.eyebrow(options.eyebrow or "ARCHIVE 03", {
		TextColor3 = Ui.C.Danger,
		ZIndex = z,
	}, header)
	local title = Ui.display({
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, -110, 0, 26),
		TextSize = 24,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Text = options.title,
		ZIndex = z,
	}, header)
	local subtitle = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -96, 0, 18),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 14,
		TextColor3 = Ui.C.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = z,
	}, header)
	Ui.frame({
		Name = "Rule",
		Position = UDim2.new(0, 20, 0, 58),
		Size = UDim2.new(1, -40, 0, 1),
		BackgroundColor3 = Ui.C.Line,
		BackgroundTransparency = 0.82,
		ZIndex = z,
	}, root)
	local body = Ui.frame({
		Name = "Body",
		Position = UDim2.fromOffset(0, 59),
		Size = UDim2.new(1, 0, 1, -59),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, root)
	local close: TextButton? = nil
	if options.onClose then
		close = Ui.quiet(options.closeText or "CLOSE  ×", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 12),
			Size = UDim2.fromOffset(88, 34),
			ZIndex = z + 1,
			-- Releases the first-person mouse lock, or no click could reach the panel.
			Modal = true,
		}, root, options.onClose)
	end
	return {
		root = root,
		header = header,
		title = title,
		subtitle = subtitle,
		body = body,
		close = close,
	}
end

-- Opens a panel with a short rise and fade; closes it the same way. Never longer than 0.2 s, so a
-- panel is always usable by the time the player's eye lands on it.
function Ui.open(frame: GuiObject)
	if frame.Visible then
		return
	end
	local scale = frame:FindFirstChild("OpenScale") :: UIScale?
	if not scale then
		scale = Ui.make("UIScale", { Name = "OpenScale" }, frame)
	end
	local s = scale :: UIScale
	s.Scale = 0.97
	frame.Visible = true
	Ui.tween(s, Ui.Motion.Base, { Scale = 1 })
	if frame:IsA("Frame") then
		local target = frame.BackgroundTransparency
		frame.BackgroundTransparency = math.min(1, target + 0.4)
		Ui.tween(frame, Ui.Motion.Base, { BackgroundTransparency = target })
	end
	AudioDirector.play("Paper", 0.22, 1.25)
end

-- A line of text on its own dark strip, so it stays readable on a lit wall or a white screen.
-- The strip sizes itself to the text, hides when the text is empty and fades with the text.
-- Position it with AnchorPoint and Position as usual; Size is ignored.
local CAPTION_BACKING = 0.28

function Ui.caption(props: { [string]: any }, parent: Instance?, maxWidth: number?): TextLabel
	local merged: { [string]: any } = {
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = CAPTION_BACKING,
		BackgroundColor3 = Ui.C.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 1,
		LineHeight = 1.1,
	}
	for key, value in props do
		if key ~= "Size" then
			merged[key] = value
		end
	end
	local label = Ui.text(merged, parent)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 8),
	}, label)
	local camera = Workspace.CurrentCamera
	local width = maxWidth or 760
	if camera then
		width = math.min(width, camera.ViewportSize.X - 40)
	end
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(width, math.huge) }, label)
	local function sync()
		local fade = label.TextTransparency
		label.Visible = label.Text ~= "" and fade < 1
		label.BackgroundTransparency = CAPTION_BACKING + (1 - CAPTION_BACKING) * fade
	end
	label:GetPropertyChangedSignal("Text"):Connect(sync)
	label:GetPropertyChangedSignal("TextTransparency"):Connect(sync)
	sync()
	return label
end

-- Which device the player is holding right now, for key labels. Touch wins on a phone even when a
-- keyboard is reported, because the thumb is what is on the glass.
function Ui.device(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	local last = UserInputService:GetLastInputType()
	if
		last.Name:find("Gamepad")
		or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled)
	then
		return "gamepad"
	end
	return "keyboard"
end

-- True while a controller drives the menus, so panels can select their main button.
function Ui.usingGamepad(): boolean
	return GuiService.SelectedObject ~= nil or Ui.device() == "gamepad"
end

return Ui
