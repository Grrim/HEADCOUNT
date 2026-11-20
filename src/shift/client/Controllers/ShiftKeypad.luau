--!strict
-- The lock of a code door. It only collects three digits; whether they are right is the server's
-- call (ShiftDoors). Number keys type on a keyboard, and the panel says where the code is: on a
-- tape of the door, never on the door itself.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Net = require(ReplicatedStorage.Shared.Net)
local Panels = require(ReplicatedStorage.ClientCommon.Panels)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local ShiftKeypad = {}

local METAL = Color3.fromRGB(46, 49, 50)
local DIGIT_KEYS = {
	[Enum.KeyCode.Zero] = 0,
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.KeypadZero] = 0,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
}

local panel: Frame
local display: TextLabel
local entry: { number } = {}

local function render()
	local shown = {}
	for index = 1, 3 do
		shown[index] = if entry[index] then tostring(entry[index]) else "–"
	end
	display.Text = table.concat(shown, "  ")
end

local function close()
	entry = {}
	panel.Visible = false
	ContextActionService:UnbindAction("ShiftKeypadDigits")
end

local function press(digit: number)
	if #entry >= 3 then
		return
	end
	table.insert(entry, digit)
	AudioDirector.play("Wrong", 0.2, 1.8)
	render()
	if #entry == 3 then
		Net.get("CodeEntry"):FireServer(entry)
		task.delay(0.35, close)
	end
end

local function open()
	entry = {}
	render()
	panel.Visible = true
	Ui.open(panel)
	local keys = {}
	for key in DIGIT_KEYS do
		table.insert(keys, key)
	end
	ContextActionService:BindActionAtPriority("ShiftKeypadDigits", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin then
			local digit = DIGIT_KEYS[input.KeyCode]
			if digit then
				press(digit)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 5, table.unpack(keys))
end

function ShiftKeypad.init()
	local gui = Ui.screen("ShiftKeypad", 8)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 440),
		BackgroundColor3 = METAL,
		Visible = false,
	}, gui)
	Ui.stroke(panel, Color3.new(0, 0, 0), 0.2, 2)
	Ui.eyebrow("ARCHIVE STORE  ·  CODE LOCK", {
		Position = UDim2.fromOffset(22, 16),
		Size = UDim2.new(1, -44, 0, 14),
		TextColor3 = Color3.fromRGB(232, 178, 92),
	}, panel)
	local window = Ui.frame({
		Position = UDim2.fromOffset(22, 38),
		Size = UDim2.new(1, -44, 0, 58),
		BackgroundColor3 = Color3.fromRGB(8, 4, 4),
	}, panel)
	display = Ui.mono({
		Size = UDim2.fromScale(1, 1),
		FontFace = Ui.Fonts.MonoBold,
		TextSize = 36,
		TextColor3 = Ui.C.Danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "–  –  –",
	}, window)
	Ui.mono({
		Position = UDim2.fromOffset(22, 100),
		Size = UDim2.new(1, -44, 0, 30),
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Ui.C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "The code shows only on tape. Film the door, then watch it (T).",
	}, panel)
	local function key(text: string, col: number, row: number, onPress: () -> (), color: Color3?)
		local button = Ui.button(text, {
			Position = UDim2.fromOffset(22 + col * 88, 140 + row * 66),
			Size = UDim2.fromOffset(80, 58),
			FontFace = Ui.Fonts.MonoBold,
			TextSize = 26,
			BackgroundColor3 = Color3.fromRGB(30, 32, 33),
			TextColor3 = color or Ui.C.Text,
			Modal = text == "5",
		}, panel, onPress)
		Ui.make("UICorner", { CornerRadius = UDim.new(0, 3) }, button)
	end
	for digit = 1, 9 do
		local slot = digit - 1
		key(tostring(digit), slot % 3, slot // 3, function()
			press(digit)
		end)
	end
	key("C", 0, 3, function()
		entry = {}
		render()
	end, Ui.C.Radio)
	key("0", 1, 3, function()
		press(0)
	end)
	key("×", 2, 3, close, Ui.C.Danger)
	Panels.watch(panel, close)
end

function ShiftKeypad.start()
	local function hook(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(open)
		end
	end
	for _, prompt in CollectionService:GetTagged("ShiftKeypad") do
		hook(prompt)
	end
	CollectionService:GetInstanceAddedSignal("ShiftKeypad"):Connect(hook)
	Net.get("ShiftState").OnClientEvent:Connect(function(state)
		if state.phase ~= "floor" and panel.Visible then
			close()
		end
	end)
end

return ShiftKeypad
