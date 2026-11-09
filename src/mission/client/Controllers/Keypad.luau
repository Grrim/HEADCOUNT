--!strict
-- The breaker's keypad. Only collects three digits; whether they are right is the server's call.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Panels = require(ReplicatedStorage.ClientCommon.Panels)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Keypad = {}

local panel: Frame
local display: TextLabel
local entry: { number } = {}

local function render()
	local shown = {}
	for index = 1, 3 do
		shown[index] = if entry[index] then tostring(entry[index]) else "_"
	end
	display.Text = table.concat(shown, " ")
end

local function press(digit: number)
	if #entry >= 3 then
		return
	end
	table.insert(entry, digit)
	AudioDirector.play("LensUp", 0.3, 1.4)
	render()
	if #entry == 3 then
		Net.get("CodeEntry"):FireServer(entry)
		task.delay(0.5, function()
			entry = {}
			render()
			panel.Visible = false
		end)
	end
end

function Keypad.init()
	local gui = Ui.screen("Keypad", 8)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(280, 380),
		BackgroundColor3 = Color3.fromRGB(26, 28, 30),
		BorderSizePixel = 2,
		BorderColor3 = Palette.Metal,
		Visible = false,
	}, gui)
	Ui.text({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 24),
		TextSize = 15,
		Text = Strings.get("obj_breaker"),
	}, panel)
	display = Ui.text({
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -28, 0, 44),
		TextSize = 32,
		TextColor3 = Palette.Rec,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "_ _ _",
	}, panel)
	for digit = 0, 9 do
		local slot = if digit == 0 then 10 else digit - 1
		local col, row = slot % 3, slot // 3
		if digit == 0 then
			col = 1
		end
		Ui.button(
			tostring(digit),
			{
				Position = UDim2.fromOffset(20 + col * 82, 88 + row * 60),
				Size = UDim2.fromOffset(74, 54),
				TextSize = 24,
				Modal = digit == 5,
			},
			panel,
			function()
				press(digit)
			end
		)
	end
	Ui.button(
		"X",
		{
			Position = UDim2.fromOffset(184, 268),
			Size = UDim2.fromOffset(74, 54),
			TextSize = 22,
			TextColor3 = Palette.Rec,
			BorderColor3 = Palette.Rec,
		},
		panel,
		function()
			entry = {}
			render()
			panel.Visible = false
		end
	)
	Panels.watch(panel, function()
		entry = {}
		render()
		panel.Visible = false
	end)
end

function Keypad.start()
	Workspace:WaitForChild("Map")
	local function hook(prompt: Instance)
		(prompt :: ProximityPrompt).Triggered:Connect(function()
			entry = {}
			render()
			panel.Visible = true
		end)
	end
	for _, prompt in CollectionService:GetTagged("BreakerPrompt") do
		hook(prompt)
	end
	CollectionService:GetInstanceAddedSignal("BreakerPrompt"):Connect(hook)
end

return Keypad
