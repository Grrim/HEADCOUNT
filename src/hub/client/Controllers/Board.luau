--!strict
-- The departures board on the hall's north wall, left of the terminal: what runs tonight, which
-- expeditions are forming on this floor and who is on shift. It makes the lobby legible from the
-- corridor door (there is a terminal, there are missions, other people are going) and gives the
-- hall something that changes. Each line flips like a split-flap board when it changes.
-- Purely local and purely a display: it reads the same party state the terminal does.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Board = {}

local LINES = 9
local WIDTH = 30
local AMBER = Color3.fromRGB(240, 186, 92)
local DIM = Color3.fromRGB(128, 100, 58)
local GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-/:"

local board: Part
local labels: { TextLabel } = {}
local shown: { string } = {}
local parties: { any } = {}

local function pad(text: string): string
	local upper = string.upper(text)
	if #upper > WIDTH then
		return upper:sub(1, WIDTH)
	end
	return upper .. string.rep(" ", WIDTH - #upper)
end

-- Two columns in one fixed-width line: name on the left, status on the right.
local function columns(left: string, right: string): string
	local room = WIDTH - #right - 1
	local name = string.upper(left)
	if #name > room then
		name = name:sub(1, room)
	end
	return name .. string.rep(" ", WIDTH - #name - #right) .. string.upper(right)
end

local function missionTitle(id: string): string
	for _, mission in Missions do
		if mission.id == id then
			return Strings.get(mission.titleKey)
		end
	end
	return id
end

local function compose(): { { text: string, color: Color3 } }
	local rows: { { text: string, color: Color3 } } = {}
	local function add(text: string, color: Color3?)
		table.insert(rows, { text = text, color = color or AMBER })
	end
	add(columns(Strings.get("board_title"), "18:04"))
	for _, mission in Missions do
		add(
			columns(
				Strings.get(mission.titleKey),
				Strings.get(if mission.available then "board_open" else "board_sealed")
			),
			if mission.available then AMBER else DIM
		)
	end
	add("")
	add(Strings.get("board_forming"), DIM)
	if #parties == 0 then
		add(Strings.get("board_none"), DIM)
	end
	for index, party in parties do
		if index > 3 then
			break
		end
		local lead = party.members[1] and party.members[1].name or "?"
		local status = if party.starting
			then Strings.get("board_boarding")
			else `{#party.members}/4`
		-- The case number is enough here; the full title is two lines up.
		local title = missionTitle(party.missionId)
		add(columns(`{lead} · {title:match("^(%d+)") or title}`, status))
	end
	local names = {}
	for _, player in Players:GetPlayers() do
		table.insert(names, player.DisplayName)
	end
	while #rows < LINES - 1 do
		add("")
	end
	add(Strings.get("board_shift", table.concat(names, ", ")), DIM)
	return rows
end

-- One line changes: its letters spin through the alphabet for a moment, then land.
local function flip(index: number, text: string, color: Color3)
	local label = labels[index]
	local final = pad(text)
	if shown[index] == final then
		label.TextColor3 = color
		return
	end
	shown[index] = final
	task.spawn(function()
		local random = Random.new()
		for step = 1, 6 do
			if shown[index] ~= final then
				return
			end
			local out = {}
			for position = 1, WIDTH do
				local char = final:sub(position, position)
				if char ~= " " and random:NextNumber() < 1 - step / 6 then
					local pick = random:NextInteger(1, #GLYPHS)
					char = GLYPHS:sub(pick, pick)
				end
				table.insert(out, char)
			end
			label.Text = table.concat(out)
			task.wait(0.05)
		end
		label.Text = final
		label.TextColor3 = color
	end)
	AudioDirector.playAt("RecStart", board.Position, 0.25, 50)
end

local function refresh()
	if not board then
		return
	end
	for index, row in compose() do
		if labels[index] then
			flip(index, row.text, row.color)
		end
	end
end

local function build()
	board = Instance.new("Part")
	board.Name = "DepartureBoard"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CastShadow = false
	board.Color = Color3.fromRGB(14, 14, 14)
	board.Material = Enum.Material.SmoothPlastic
	-- North wall, left of the terminal; the case board hangs at the same height on the right.
	-- The wall's face is at z = -39.5; the board stands 0.1 off it, like the case board opposite.
	board.Size = Vector3.new(10, 6.4, 0.4)
	board.CFrame = CFrame.new(-13.5, 9.6, -39.2)
	board.Parent = Workspace
	-- A thin frame so it reads as an object hung on the wall.
	local frame = Instance.new("Part")
	frame.Name = "DepartureFrame"
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.Color = Color3.fromRGB(70, 58, 44)
	frame.Material = Enum.Material.Wood
	frame.Size = Vector3.new(10.6, 7, 0.14)
	frame.CFrame = CFrame.new(-13.5, 9.6, -39.43)
	frame.Parent = Workspace
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.LightInfluence = 0
	surface.Brightness = 1.4
	surface.MaxDistance = 140
	surface.Parent = board
	local holder = Ui.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 9, 8),
	}, surface)
	Ui.pad(holder, 18, 14)
	Ui.list(holder, 2)
	for index = 1, LINES do
		local label = Ui.mono({
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 1 / LINES, -3),
			FontFace = Ui.Fonts.MonoBold,
			TextScaled = true,
			TextColor3 = AMBER,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Text = "",
		}, holder)
		-- Each line sits on its own dark slat, the way flap boards are built.
		label.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
		label.BackgroundTransparency = 0
		table.insert(labels, label)
		shown[index] = ""
	end
	-- Lit from within: a faint warm glow onto the wall around it.
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Color = AMBER
	glow.Brightness = 0.6
	glow.Range = 8
	glow.Angle = 100
	glow.Parent = board
end

function Board.start()
	Workspace:WaitForChild("Map")
	build()
	Net.get("PartyState").OnClientEvent:Connect(function(state)
		parties = state
		refresh()
	end)
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	refresh()
end

return Board
