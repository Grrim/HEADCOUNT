--!strict
-- The records boards high on the hall's east wall: the ten deepest returns from the shift of all
-- time, over the two lifts, and beside it the same for this week, which starts over every Monday
-- at 00:00 UTC (Core/Records). Ties go to Frames earned. The shift place writes the scores
-- (ShiftRecords); this reads the top of each list once a minute and writes the rows.
--
-- Headings are written by each client in its own language (Lifts), and a row carries the UserId
-- it belongs to, so a client can light up its own player's line.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Records = require(ReplicatedStorage.Shared.Core.Records)

local HubRecords = {}

local REFRESH = 60
-- Characters per row in the board's monospaced font.
local WIDTH = 44

type Board = { part: Part, rows: { TextLabel }, storeName: () -> string }

local names: { [number]: string } = {}
local boards: { Board } = {}

local function label(parent: Instance, name: string, y: number, height: number, size: number)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 24, 0, y)
	text.Size = UDim2.new(1, -48, 0, height)
	text.Font = Enum.Font.Code
	text.TextSize = size
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Color3.fromRGB(240, 186, 92)
	text.Text = ""
	text.Parent = parent
	return text
end

-- One board on the east wall, its face at x 39.5, centred on `z`, 16 studs wide.
local function build(map: Instance, name: string, z: number, kind: string, storeName: () -> string)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Color = Color3.fromRGB(14, 14, 14)
	part.Material = Enum.Material.SmoothPlastic
	part.Size = Vector3.new(0.3, 8, 16)
	part.CFrame = CFrame.new(39.3, 16.6, z)
	part.Parent = map
	local frame = Instance.new("Part")
	frame.Name = `{name}Frame`
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.Color = Color3.fromRGB(70, 58, 44)
	frame.Material = Enum.Material.Wood
	frame.Size = Vector3.new(0.06, 8.6, 16.6)
	frame.CFrame = CFrame.new(39.45, 16.6, z)
	frame.Parent = map
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Left
	light.Color = Palette.Bulb
	light.Brightness = 0.4
	light.Range = 6
	light.Parent = part

	local gui = Instance.new("SurfaceGui")
	gui.Name = "RecordsGui"
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 160
	gui.Parent = part
	label(gui, "RecordsTitle", 16, 48, 40)
	local columns = label(gui, "RecordsColumns", 64, 26, 20)
	columns.TextColor3 = Color3.fromRGB(128, 100, 58)
	-- Longer in some languages: shrink to fit rather than run off the board.
	columns.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 20
	fit.Parent = columns
	local rows = {}
	for index = 1, Records.SHOWN do
		table.insert(rows, label(gui, `Row{index}`, 96 + (index - 1) * 29, 28, 24))
	end
	label(gui, "RecordsNote", 96, 28, 22).TextColor3 = Color3.fromRGB(128, 100, 58)
	part:SetAttribute("Kind", kind)
	part:SetAttribute("State", "loading")
	table.insert(boards, { part = part, rows = rows, storeName = storeName })
end

-- Display names for these users, from a cache, asking the platform only for the new ones.
local function resolve(ids: { number })
	local missing = {}
	for _, id in ids do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos do
			if typeof(info.Id) == "number" and typeof(info.DisplayName) == "string" then
				names[info.Id] = info.DisplayName
			end
		end
	end
end

local function clear(board: Board)
	for _, row in board.rows do
		row.Text = ""
		row:SetAttribute("UserId", nil)
	end
end

local function refresh(board: Board)
	local storeName = board.storeName()
	-- A new week: last week's rows go at once, before the new list is even read.
	if board.part:GetAttribute("Store") ~= storeName then
		board.part:SetAttribute("Store", storeName)
		clear(board)
		board.part:SetAttribute("State", "loading")
	end
	local ok, entries = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName)
			:GetSortedAsync(false, Records.SHOWN)
			:GetCurrentPage()
	end)
	if not ok then
		warn(`[HubRecords] could not read {storeName}: {entries}`)
		-- A blip after a good read keeps the rows it has; only a board never filled says so.
		if board.part:GetAttribute("State") ~= "ok" then
			board.part:SetAttribute("State", "offline")
		end
		return
	end
	local ids = {}
	for _, entry in entries do
		local id = tonumber(entry.key)
		if id then
			table.insert(ids, id)
		end
	end
	resolve(ids)
	for index, row in board.rows do
		local entry = entries[index]
		local id = entry and tonumber(entry.key)
		if entry and id then
			row.Text = Records.line(index, names[id] or `#{id}`, entry.value, WIDTH)
			row:SetAttribute("UserId", id)
		else
			row.Text = ""
			row:SetAttribute("UserId", nil)
		end
	end
	board.part:SetAttribute("State", if #entries == 0 then "empty" else "ok")
end

function HubRecords.start()
	local map = Workspace:WaitForChild("Map")
	-- Above the lift doorways (z -37.5..-23), then north of the tape room's door (z -10..-2).
	build(map, "RecordsBoard", -30.5, "all", function()
		return Records.STORE
	end)
	build(map, "WeeklyRecordsBoard", -13.8, "week", function()
		return Records.weeklyStore(Records.week(os.time()))
	end)
	while true do
		for _, board in boards do
			refresh(board)
		end
		task.wait(REFRESH)
	end
end

return HubRecords
