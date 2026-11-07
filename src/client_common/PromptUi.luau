--!strict
-- Our own look for every ProximityPrompt: a key cap, the action, the object in CRT green, and a red
-- bar that fills while a hold is in progress. The engine still decides when a prompt is shown and
-- when it triggers; this only draws it. On touch the whole card is the button.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(script.Parent.Ui)

local PromptUi = {}

local GAMEPAD_NAMES: { [string]: string } = {
	ButtonX = "X",
	ButtonY = "Y",
	ButtonA = "A",
	ButtonB = "B",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
}

local CARD = Color3.fromRGB(10, 12, 14)

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return GAMEPAD_NAMES[name] or name
	end
	return prompt.KeyboardKeyCode.Name
end

local function build(
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType
): BillboardGui
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local board = Instance.new("BillboardGui")
	board.Name = "Prompt"
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.ResetOnSpawn = false
	board.Size = UDim2.fromOffset(250, 58)
	board.SizeOffset = Vector2.new(0, 0.5)
	board.Active = touch
	board.Adornee = prompt.Parent :: Instance

	local card: GuiObject = if touch
		then Ui.make("TextButton", { Text = "", AutoButtonColor = false }, board)
		else Ui.make("Frame", {}, board)
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = CARD
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.75, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, card)

	local cap = Ui.frame({
		Name = "Key",
		Position = UDim2.fromOffset(6, 7),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(26, 28, 30),
		BackgroundTransparency = 1,
	}, card)
	local stroke = Ui.make("UIStroke", {
		Color = Palette.Paper,
		Thickness = 1.5,
		Transparency = 1,
	}, cap)
	local key = Ui.text({
		Size = UDim2.fromScale(1, 1),
		TextSize = if touch then 13 else 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = 1,
		Text = keyText(prompt, inputType),
	}, cap)
	-- Fills left to right while the key is held; hidden for instant prompts.
	local bar = Ui.frame({
		Name = "Hold",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = Palette.Rec,
	}, cap)

	local action = Ui.text({
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.new(1, -64, 0, 24),
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = 1,
		Text = prompt.ActionText,
	}, card)
	local object = Ui.text({
		Position = UDim2.fromOffset(60, 32),
		Size = UDim2.new(1, -64, 0, 18),
		TextSize = 14,
		TextColor3 = Palette.Crt,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = 1,
		Text = if prompt.HoldDuration > 0
			then `{prompt.ObjectText}  ·  {Strings.get("prompt_hold")}`
			else prompt.ObjectText,
	}, card)

	-- Fade in.
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
	TweenService:Create(card, info, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(cap, info, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(stroke, info, { Transparency = 0.2 }):Play()
	for _, label in { key, action, object } do
		TweenService:Create(label, info, { TextTransparency = 0 }):Play()
	end

	local connections: { RBXScriptConnection } = {}
	local holding: Tween? = nil
	table.insert(
		connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			if prompt.HoldDuration > 0 then
				local fill = TweenService:Create(
					bar,
					TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
					{ Size = UDim2.new(1, 0, 0, 4) }
				)
				holding = fill
				fill:Play()
			end
		end)
	)
	table.insert(
		connections,
		prompt.PromptButtonHoldEnded:Connect(function()
			if holding then
				holding:Cancel()
				holding = nil
			end
			bar.Size = UDim2.new(0, 0, 0, 4)
		end)
	)
	table.insert(
		connections,
		prompt.Triggered:Connect(function()
			cap.BackgroundColor3 = Palette.Rec
			TweenService
				:Create(cap, TweenInfo.new(0.35), { BackgroundColor3 = Color3.fromRGB(26, 28, 30) })
				:Play()
		end)
	)
	-- The server can rename or retarget a prompt while it is on screen.
	table.insert(
		connections,
		prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
			action.Text = prompt.ActionText
		end)
	)
	if touch then
		local button = card :: TextButton
		table.insert(
			connections,
			button.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1
				then
					prompt:InputHoldBegin()
				end
			end)
		)
		table.insert(
			connections,
			button.InputEnded:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1
				then
					prompt:InputHoldEnd()
				end
			end)
		)
	end
	board.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	board.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return board
end

function PromptUi.start()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local board = build(prompt, inputType)
		local hidden: RBXScriptConnection
		hidden = prompt.PromptHidden:Connect(function()
			hidden:Disconnect()
			board:Destroy()
		end)
	end)
end

return PromptUi
