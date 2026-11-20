--!strict
-- The records board high on the hall's east wall, over the two lifts: the ten deepest returns
-- from the shift of all time, ties broken by Frames earned (Core/Records). The shift place writes
-- the scores (ShiftRecords); this reads the top of the list once a minute and writes the rows.
-- Headings are written by each client in its own language (Lifts); a row carries the UserId it
-- belongs to, so a client can light up its own player's line.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Records = require(ReplicatedStorage.Shared.Core.Records)

local HubRecords = {}

local STORE_NAME = "ShiftRecords_v1"
local REFRESH = 60
-- Characters per row in the board's monospaced font.
local WIDTH = 44

local rows: { TextLabel } = {}
local names: { [number]: string } = {}
local board: Part

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

-- On the east wall, its face at x 39.5, above both lift doorways (z -37.5..-23).
local function build(map: Instance)
	board = Instance.new("Part")
	board.Name = "RecordsBoard"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CastShadow = false
	board.Color = Color3.fromRGB(14, 14, 14)
	board.Material = Enum.Material.SmoothPlastic
	board.Size = Vector3.new(0.3, 8, 16)
	board.CFrame = CFrame.new(39.3, 16.6, -30.5)
	board.Parent = map
	local frame = Instance.new("Part")
	frame.Name = "RecordsFrame"
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.Color = Color3.fromRGB(70, 58, 44)
	frame.Material = Enum.Material.Wood
	frame.Size = Vector3.new(0.06, 8.6, 16.6)
	frame.CFrame = CFrame.new(39.45, 16.6, -30.5)
	frame.Parent = map
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Left
	light.Color = Palette.Bulb
	light.Brightness = 0.4
	light.Range = 6
	light.Parent = board

	local gui = Instance.new("SurfaceGui")
	gui.Name = "RecordsGui"
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 160
	gui.Parent = board
	label(gui, "RecordsTitle", 16, 48, 40)
	label(gui, "RecordsColumns", 64, 26, 20).TextColor3 = Color3.fromRGB(128, 100, 58)
	for index = 1, Records.SHOWN do
		local row = label(gui, `Row{index}`, 96 + (index - 1) * 29, 28, 24)
		table.insert(rows, row)
	end
	label(gui, "RecordsNote", 96, 28, 22).TextColor3 = Color3.fromRGB(128, 100, 58)
	board:SetAttribute("State", "loading")
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

local function refresh(ordered: OrderedDataStore)
	local ok, entries = pcall(function()
		return ordered:GetSortedAsync(false, Records.SHOWN):GetCurrentPage()
	end)
	if not ok then
		warn(`[HubRecords] could not read the records: {entries}`)
		-- A blip after a good read keeps the rows it has; only a board never filled says so.
		if board:GetAttribute("State") ~= "ok" then
			board:SetAttribute("State", "offline")
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
	for index, row in rows do
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
	board:SetAttribute("State", if #entries == 0 then "empty" else "ok")
end

function HubRecords.start()
	build(Workspace:WaitForChild("Map"))
	local ok, ordered = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if not ok then
		warn(`[HubRecords] no records store: {ordered}`)
		board:SetAttribute("State", "offline")
		return
	end
	while true do
		refresh(ordered)
		task.wait(REFRESH)
	end
end

return HubRecords
