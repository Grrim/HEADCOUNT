--!strict
-- Teaches the camera by doing, one step at a time, with the real key for the device in hand.
-- Each hint waits for the action before it, disappears once performed, and never comes back.
-- It is a small chip at the bottom of the screen: a key cap and a few words, nothing to read twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Hints = {}

-- The chapter card owns the first seconds of the mission; the first hint follows it.
local FIRST_HINT_DELAY = 5.5

local controllers: { [string]: any }
local chip: Frame
local keyLabel: TextLabel
local textLabel: TextLabel
local step = 0
local tapeSaved = false
local ready = false
local pending: (() -> ())? = nil

local function keyFor(action: string): string
	local device = Ui.device()
	if device == "touch" then
		return Strings.get(`btn_{action}`)
	elseif device == "gamepad" then
		return ({ lens = "L2", rec = "R2", play = "Y", light = "D-PAD ↑" } :: any)[action]
	end
	return ({ lens = "Q", rec = "R", play = "T", light = "F" } :: any)[action]
end

local function show(action: string?, textKey: string?)
	if not ready then
		pending = function()
			show(action, textKey)
		end
		return
	end
	if not textKey then
		Ui.tween(chip, Ui.Motion.Base, { Position = UDim2.new(0.5, 0, 1, 40) }).Completed
			:Once(function()
				if textLabel.Text == "" then
					chip.Visible = false
				end
			end)
		textLabel.Text = ""
		return
	end
	keyLabel.Text = if action then keyFor(action) else ""
	keyLabel.Visible = action ~= nil
	textLabel.Text = Strings.get(textKey)
	chip.Visible = true
	chip.Position = UDim2.new(0.5, 0, 1, 40)
	Ui.tween(chip, Ui.Motion.Base, { Position = UDim2.new(0.5, 0, 1, -14) })
end

local function advance(toStep: number)
	if toStep <= step then
		return
	end
	step = toStep
	if step == 1 then
		show("lens", "hint_lens")
	elseif step == 2 then
		show("rec", "hint_rec")
	elseif step == 3 then
		show("play", "hint_play")
	elseif step == 4 then
		show(nil, "hint_seats")
	else
		show(nil, nil)
	end
end

function Hints.init(all: { [string]: any })
	controllers = all
	local gui = Ui.screen("Hints", 6)
	chip = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 40),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Ui.C.Ink,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, gui)
	Ui.stroke(chip, Ui.C.Accent, 0.6)
	Ui.pad(chip, 10, 8)
	local layout = Ui.list(chip, 10, true)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	keyLabel = Ui.keycap("Q", { LayoutOrder = 1, BackgroundColor3 = Ui.C.Accent }, chip)
	textLabel = Ui.text({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Ui.Fonts.BodyBold,
		TextSize = if Ui.compact() then 15 else 17,
		TextColor3 = Ui.C.Text,
		TextWrapped = false,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	}, chip)
end

function Hints.start()
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		if state.phase == "Protocol" and not ready then
			task.delay(FIRST_HINT_DELAY, function()
				ready = true
				local queued = pending
				pending = nil
				if queued then
					queued()
				end
			end)
		elseif state.phase ~= "Waiting" then
			ready = true
		end
		if state.phase == "Power" then
			show("light", "hint_power")
			task.delay(10, function()
				if controllers.Hints and step >= 5 then
					show(nil, nil)
				end
			end)
			step = math.max(step, 5)
			return
		elseif state.phase == "Projector" then
			show(nil, nil)
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
	-- Once the tape is running, "press record" has done its job; it comes back only if the take
	-- is thrown away.
	LensView.onRecording(function(on)
		if step == 2 then
			if on then
				show(nil, nil)
			else
				task.delay(1.5, function()
					if step == 2 and not LensView.recording then
						show("rec", "hint_rec")
					end
				end)
			end
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
		-- Only a tape that caught someone has a seat to send the player to. An empty one says so
		-- when it ends (the notebook), and the hint steps aside.
		if step < 4 then
			step = 4
			-- What the tape found is on the objective card and the marker; the chip steps aside.
			show(nil, nil)
		end
	end)
end

return Hints
