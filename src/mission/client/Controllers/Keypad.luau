--!strict
-- The breaker's keypad. Only collects three digits; whether they are right is the server's call.
-- It looks like the panel it is: stamped metal, a red read-out in a black window, square keys.
-- The digits the player has already read off the cards sit under the read-out, so the code never
-- has to be carried in the head from the stage to the basement. Number keys type on a keyboard.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Net = require(ReplicatedStorage.Shared.Net)
local Panels = require(ReplicatedStorage.ClientCommon.Panels)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Keypad = {}

local METAL = Color3.fromRGB(46, 49, 50)
local METAL_LIGHT = Color3.fromRGB(70, 74, 74)
local DIGIT_KEYS = {
	Enum.KeyCode.Zero,
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
	Enum.KeyCode.KeypadZero,
	Enum.KeyCode.KeypadOne,
	Enum.KeyCode.KeypadTwo,
	Enum.KeyCode.KeypadThree,
	Enum.KeyCode.KeypadFour,
	Enum.KeyCode.KeypadFive,
	Enum.KeyCode.KeypadSix,
	Enum.KeyCode.KeypadSeven,
	Enum.KeyCode.KeypadEight,
	Enum.KeyCode.KeypadNine,
}

local controllers: { [string]: any }
local panel: Frame
local display: TextLabel
local notesLabel: TextLabel
local entry: { number } = {}
local phase = "Waiting"

local function render()
	local shown = {}
	for index = 1, 3 do
		shown[index] = if entry[index] then tostring(entry[index]) else "–"
	end
	display.Text = table.concat(shown, "  ")
end

local function close()
	entry = {}
	render()
	panel.Visible = false
	ContextActionService:UnbindAction("KeypadDigits")
end

local function press(digit: number)
	if #entry >= 3 then
		return
	end
	table.insert(entry, digit)
	AudioDirector.play("RecStart", 0.35, 1.5)
	render()
	if #entry == 3 then
		Net.get("CodeEntry"):FireServer(entry)
		task.delay(0.5, close)
	end
end

local function open()
	if phase ~= "Power" then
		controllers.Hud.result(Strings.get("keypad_not_yet"), "info")
		return
	end
	entry = {}
	render()
	local known = controllers.Notebook
		and controllers.Notebook.codeText
		and controllers.Notebook.codeText()
	notesLabel.Text = if known and known ~= "" then Strings.get("keypad_notes", known) else ""
	Ui.open(panel)
	ContextActionService:BindActionAtPriority("KeypadDigits", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local index = table.find(DIGIT_KEYS, input.KeyCode)
		if index then
			press((index - 1) % 10)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 5, table.unpack(DIGIT_KEYS))
end

function Keypad.init(all: { [string]: any })
	controllers = all
	local gui = Ui.screen("Keypad", 8)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 430),
		BackgroundColor3 = METAL,
		Visible = false,
	}, gui)
	Ui.make("UIGradient", {
		Color = ColorSequence.new(METAL_LIGHT, METAL),
		Rotation = 90,
	}, panel)
	Ui.stroke(panel, Color3.new(0, 0, 0), 0.2, 2)
	-- Fits a phone held sideways: the panel shrinks with the screen, never past it.
	local camera = Workspace.CurrentCamera
	if camera and camera.ViewportSize.Y < 470 then
		Ui.make("UIScale", { Scale = math.max(0.7, (camera.ViewportSize.Y - 30) / 430) }, panel)
	end
	-- Four screw heads.
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local screw = Ui.frame({
			AnchorPoint = corner,
			Position = UDim2.new(
				corner.X,
				if corner.X == 0 then 8 else -8,
				corner.Y,
				if corner.Y == 0 then 8 else -8
			),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.fromRGB(110, 112, 108),
		}, panel)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, screw)
	end
	Ui.eyebrow("MAINS  ·  BREAKER 3", {
		Position = UDim2.fromOffset(22, 16),
		Size = UDim2.new(1, -44, 0, 14),
		TextColor3 = Color3.fromRGB(232, 178, 92),
	}, panel)
	local window = Ui.frame({
		Position = UDim2.fromOffset(22, 38),
		Size = UDim2.new(1, -44, 0, 58),
		BackgroundColor3 = Color3.fromRGB(8, 4, 4),
	}, panel)
	Ui.stroke(window, Color3.new(0, 0, 0), 0, 2)
	display = Ui.mono({
		Size = UDim2.fromScale(1, 1),
		FontFace = Ui.Fonts.MonoBold,
		TextSize = 36,
		TextColor3 = Ui.C.Danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "–  –  –",
	}, window)
	notesLabel = Ui.mono({
		Position = UDim2.fromOffset(22, 100),
		Size = UDim2.new(1, -44, 0, 18),
		TextSize = 13,
		TextColor3 = Ui.C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
	}, panel)
	local function key(text: string, col: number, row: number, onPress: () -> (), color: Color3?)
		local button = Ui.button(text, {
			Position = UDim2.fromOffset(22 + col * 88, 126 + row * 66),
			Size = UDim2.fromOffset(80, 58),
			FontFace = Ui.Fonts.MonoBold,
			TextSize = 26,
			BackgroundColor3 = Color3.fromRGB(30, 32, 33),
			TextColor3 = color or Ui.C.Text,
			BorderColor3 = color or Ui.C.Text,
			Modal = text == "5",
		}, panel, onPress)
		Ui.make("UICorner", { CornerRadius = UDim.new(0, 3) }, button)
		return button
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
		AudioDirector.play("Wrong", 0.3)
	end, Ui.C.Radio)
	key("0", 1, 3, function()
		press(0)
	end)
	key("×", 2, 3, close, Ui.C.Danger)
	Panels.watch(panel, close)
end

function Keypad.start()
	Workspace:WaitForChild("Map")
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		phase = state.phase
		if phase ~= "Power" and panel.Visible then
			close()
		end
	end)
	local function hook(prompt: Instance)
		(prompt :: ProximityPrompt).Triggered:Connect(open)
	end
	for _, prompt in CollectionService:GetTagged("BreakerPrompt") do
		hook(prompt)
	end
	CollectionService:GetInstanceAddedSignal("BreakerPrompt"):Connect(hook)
end

return Keypad
