--!strict
-- The breaker code is held up by the front row. Each player sees only the digits dealt to them; the
-- other cards are blank on their copy, so a team has to read the number out across the hall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)

local CodeCards = {}

-- Front row, left to right as seen from the stage: those three seats hold positions 3, 2 and 1.
local CARD_COLUMNS = { 13, 8, 3 }

local cards: { { part: Part, digit: TextLabel, gui: SurfaceGui } } = {}
local active = false
local controllers: { [string]: any }
local seenListeners: { (position: number, digit: number) -> () } = {}
-- A card counts as read when it is on screen and near enough for its digit to be legible.
local READ_DISTANCE = 50

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "CodeCards"
	for position, col in CARD_COLUMNS do
		local x, z = Seats.position(Seats.id(1, col))
		local part = Instance.new("Part")
		part.Name = `Card{position}`
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Size = Vector3.new(2.2, 2.8, 0.1)
		part.Position = Vector3.new(x, 8.6, z - 0.3)
		part.Color = Palette.Paper
		part.Transparency = 1
		part.Parent = folder
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(110, 140)
		gui.LightInfluence = 0
		gui.Brightness = 0.7
		gui.Enabled = false
		gui.Parent = part
		local sheet = Instance.new("Frame")
		sheet.Size = UDim2.fromScale(1, 1)
		sheet.BackgroundColor3 = Palette.Paper
		sheet.BorderSizePixel = 0
		sheet.Parent = gui
		local badge = Instance.new("TextLabel")
		badge.BackgroundTransparency = 1
		badge.Position = UDim2.fromScale(0, 0.02)
		badge.Size = UDim2.fromScale(1, 0.22)
		badge.Font = Enum.Font.Code
		badge.TextScaled = true
		badge.TextColor3 = Palette.Ink
		badge.Text = `{position}/3`
		badge.Parent = gui
		local digit = Instance.new("TextLabel")
		digit.BackgroundTransparency = 1
		digit.Position = UDim2.fromScale(0, 0.24)
		digit.Size = UDim2.fromScale(1, 0.74)
		digit.Font = Enum.Font.Code
		digit.TextScaled = true
		digit.TextColor3 = Palette.Rec
		digit.Text = ""
		digit.Parent = gui
		cards[position] = { part = part, digit = digit, gui = gui }
	end
	folder.Parent = Workspace
end

local function refresh()
	local visible = active
		and (LensView.raised or controllers.Audience.offFrame)
		and not controllers.Playback.active()
	for _, card in cards do
		card.part.Transparency = if visible then 0 else 1
		card.gui.Enabled = visible
	end
end

-- Called with each digit this player has actually looked at, so the notebook can write it down.
function CodeCards.onSeen(listener: (position: number, digit: number) -> ())
	table.insert(seenListeners, listener)
end

local function readLoop()
	while true do
		task.wait(0.3)
		local camera = Workspace.CurrentCamera
		if camera and #seenListeners > 0 then
			for position, card in cards do
				local digit = tonumber(card.digit.Text)
				if card.gui.Enabled and digit then
					local point, onScreen = camera:WorldToViewportPoint(card.part.Position)
					if onScreen and point.Z > 0 and point.Z < READ_DISTANCE then
						for _, listener in seenListeners do
							listener(position, digit)
						end
					end
				end
			end
		end
	end
end

function CodeCards.init(all: { [string]: any })
	controllers = all
	build()
end

function CodeCards.start()
	LensView.onChanged(refresh)
	Net.get("CodeDigits").OnClientEvent:Connect(function(hand: { [string]: number })
		for position, card in cards do
			local digit = hand[tostring(position)]
			card.digit.Text = if digit then tostring(digit) else ""
		end
	end)
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		active = state.phase == "Power"
		refresh()
	end)
	task.spawn(readLoop)
end

return CodeCards
