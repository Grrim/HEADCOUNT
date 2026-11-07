--!strict
-- A tiny UI factory. Monospace on black, one red accent, sizes that work on a phone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local Ui = {}

Ui.FONT = Enum.Font.Code

function Ui.screen(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
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
	local merged = { BorderSizePixel = 0, BackgroundColor3 = Palette.Ink }
	for key, value in props do
		merged[key] = value
	end
	return Ui.make("Frame", merged, parent)
end

function Ui.text(props: { [string]: any }, parent: Instance?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextColor3 = Palette.Paper,
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

function Ui.button(
	text: string,
	props: { [string]: any },
	parent: Instance?,
	onClick: (() -> ())?
): TextButton
	local merged: { [string]: any } = {
		Text = text,
		Font = Ui.FONT,
		TextSize = 18,
		TextColor3 = Palette.Crt,
		BackgroundColor3 = Color3.fromRGB(24, 32, 24),
		BorderSizePixel = 1,
		BorderColor3 = Palette.Crt,
		AutoButtonColor = true,
		TextWrapped = true,
	}
	for key, value in props do
		merged[key] = value
	end
	local button: TextButton = Ui.make("TextButton", merged, parent)
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
	local fill = color or Palette.Crt
	local merged: { [string]: any } = {
		BackgroundColor3 = fill,
		BorderColor3 = fill,
		TextColor3 = Color3.fromRGB(10, 14, 10),
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.button(text, merged, parent, onClick)
end

-- A line of text on its own dark strip, so it stays readable on a lit wall or a white screen.
-- The strip sizes itself to the text, hides when the text is empty and fades with the text.
-- Position it with AnchorPoint and Position as usual; Size is ignored.
local CAPTION_BACKING = 0.4

function Ui.caption(props: { [string]: any }, parent: Instance?, maxWidth: number?): TextLabel
	local merged: { [string]: any } = {
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = CAPTION_BACKING,
		BackgroundColor3 = Color3.fromRGB(8, 10, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 1,
	}
	for key, value in props do
		if key ~= "Size" then
			merged[key] = value
		end
	end
	local label = Ui.text(merged, parent)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 7),
	}, label)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(maxWidth or 760, math.huge) }, label)
	local stroke = Ui.make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.Paper,
		Transparency = 0.85,
		Thickness = 1,
	}, label)
	local function sync()
		local fade = label.TextTransparency
		label.Visible = label.Text ~= "" and fade < 1
		label.BackgroundTransparency = CAPTION_BACKING + (1 - CAPTION_BACKING) * fade
		stroke.Transparency = 0.85 + 0.15 * fade
	end
	label:GetPropertyChangedSignal("Text"):Connect(sync)
	label:GetPropertyChangedSignal("TextTransparency"):Connect(sync)
	sync()
	return label
end

return Ui
