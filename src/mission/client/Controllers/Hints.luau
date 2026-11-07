--!strict
-- Teaches the camera by doing, one step at a time, in the words of the device the player holds.
-- Each hint waits for the action before it, disappears once performed, and never comes back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Hints = {}

local label: TextLabel
local step = 0
local tapeSaved = false

local function keyFor(action: string): string
	if Input.isTouch then
		return Strings.get(`btn_{action}`)
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return ({ lens = "L2", rec = "R2", play = "Y" } :: any)[action]
	end
	return ({ lens = "Q / RMB", rec = "R", play = "T" } :: any)[action]
end

local function show(text: string)
	label.Text = text
	label.Visible = text ~= ""
end

local function advance(toStep: number)
	if toStep <= step then
		return
	end
	step = toStep
	if step == 1 then
		show(Strings.get("hint_lens", keyFor("lens")))
	elseif step == 2 then
		show(Strings.get("hint_rec", keyFor("rec")))
	elseif step == 3 then
		show(Strings.get("hint_play", keyFor("play")))
	elseif step == 4 then
		show(Strings.get("hint_seats"))
	else
		show("")
	end
end

function Hints.init()
	local gui = Ui.screen("Hints", 6)
	label = Ui.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.965),
		Size = UDim2.new(0.7, 0, 0, 28),
		TextSize = 16,
		TextColor3 = Palette.Crt,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextStrokeTransparency = 0.5,
		Visible = false,
		Text = "",
	}, gui)
end

function Hints.start()
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		if state.phase == "Power" then
			local key = if Input.isTouch
				then Strings.get("btn_light")
				elseif
					UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
				then "D-pad"
				else "F"
			show(Strings.get("hint_power", key))
			return
		elseif state.phase == "Projector" then
			show("")
		end
		if state.phase == "Protocol" then
			if #state.tags > 0 then
				advance(5)
			else
				advance(1)
			end
		elseif state.phase ~= "Waiting" then
			advance(5)
		end
	end)
	LensView.onChanged(function(raised)
		if raised and step == 1 then
			advance(if tapeSaved then 3 else 2)
		end
	end)
	Net.get("TapeList").OnClientEvent:Connect(function(list)
		if list.count > 0 then
			tapeSaved = true
			advance(3)
		end
	end)
	Net.get("TapePlay").OnClientEvent:Connect(function()
		advance(4)
	end)
end

return Hints
