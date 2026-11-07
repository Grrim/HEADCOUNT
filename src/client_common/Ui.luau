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

return Ui
