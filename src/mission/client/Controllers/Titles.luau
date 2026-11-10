--!strict
-- Chapter cards: each turn of the mission opens like a reel change, with a part number and a name
-- typed out over the picture. They give the night a shape and tell the player something changed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Titles = {}

local CHAPTERS = { "Protocol", "Power", "Projector", "Door", "Climax" }
local NUMERALS = { "I", "II", "III", "IV", "V" }

local controllers: { [string]: any }
local holder: Frame
local partLabel: TextLabel
local nameLabel: TextLabel
local placeLabel: TextLabel
local rule: Frame
local shown: { [string]: boolean } = {}
local queue: { string } = {}
local busy = false

local function setFade(alpha: number)
	partLabel.TextTransparency = alpha
	nameLabel.TextTransparency = alpha
	placeLabel.TextTransparency = alpha
	rule.BackgroundTransparency = alpha
	nameLabel.TextStrokeTransparency = 0.4 + 0.6 * alpha
end

local function fadeTo(alpha: number, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine)
	for _, label in { partLabel, nameLabel, placeLabel } do
		TweenService:Create(label, info, { TextTransparency = alpha }):Play()
	end
	TweenService:Create(nameLabel, info, { TextStrokeTransparency = 0.4 + 0.6 * alpha }):Play()
	TweenService:Create(rule, info, { BackgroundTransparency = alpha }):Play()
	task.wait(seconds)
end

local function play(phase: string)
	local index = table.find(CHAPTERS, phase) :: number
	-- A tape owns the picture; the card waits for it to end.
	while controllers.Playback.active() do
		task.wait(0.3)
	end
	holder.Visible = true
	setFade(1)
	partLabel.Text = Strings.get("chapter_part", NUMERALS[index])
	placeLabel.Text = if index == 1 then Strings.get("chapter_place") else ""
	local name = Strings.get(`chapter_{phase}`)
	nameLabel.Text = ""
	fadeTo(0, 0.6)
	-- Typed out, one character at a time, with a soft key click now and then.
	local typed = ""
	local count = 0
	for _, code in utf8.codes(name) do
		count += 1
		typed ..= utf8.char(code)
		nameLabel.Text = typed
		if count % 3 == 1 then
			AudioDirector.play("RecStart", 0.12, 1.6)
		end
		task.wait(0.045)
	end
	task.wait(2.8)
	fadeTo(1, 1.2)
	holder.Visible = false
end

local function pump()
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		play(table.remove(queue, 1) :: string)
	end
	busy = false
end

function Titles.init(all: { [string]: any })
	controllers = all
	local gui = Ui.screen("Titles", 3, true)
	holder = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.new(0.8, 0, 0, 120),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	partLabel = Ui.mono({
		FontFace = Ui.Fonts.MonoBold,
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		TextColor3 = Palette.Rec,
		Text = "",
	}, holder)
	rule = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(80, 2),
		BackgroundColor3 = Palette.Rec,
	}, holder)
	nameLabel = Ui.display({
		FontFace = Ui.Fonts.DisplayBold,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 52),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 44,
		TextColor3 = Ui.C.Text,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		Text = "",
	}, holder)
	placeLabel = Ui.mono({
		Position = UDim2.new(0, 0, 0, 92),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = Ui.C.Muted,
		Text = "",
	}, holder)
	Ui.make("UITextSizeConstraint", { MaxTextSize = 44, MinTextSize = 22 }, nameLabel)
	nameLabel.TextScaled = true
end

function Titles.start()
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		local phase = state.phase
		-- Register is the second half of the door chapter, not a chapter of its own.
		if table.find(CHAPTERS, phase) and not shown[phase] then
			shown[phase] = true
			table.insert(queue, phase)
			task.spawn(pump)
		end
	end)
end

return Titles
