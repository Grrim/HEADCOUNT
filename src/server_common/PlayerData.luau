--!strict
-- Durable progress for both places. See Core/Progress for why a save merges instead of overwrites.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)

local PlayerData = {}

local STORE_NAME = "Progress_v1"
local RETRIES = 3

type Record = { data: Progress.Data, delta: Progress.Delta, dirty: boolean, loaded: boolean }

local records: { [Player]: Record } = {}
local store: DataStore? = nil
local storeChecked = false

local function getStore(): DataStore?
	if storeChecked then
		return store
	end
	storeChecked = true
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerData] running in memory only: {result}`)
	end
	return store
end

local function withRetry(action: () -> any): (boolean, any)
	local lastError: any
	-- Studio without API access fails every time, so do not make the playtest wait on backoff.
	local attempts = if RunService:IsStudio() then 1 else RETRIES
	for attempt = 1, attempts do
		local ok, result = pcall(action)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < attempts then
			task.wait(2 ^ (attempt - 1))
		end
	end
	warn(`[PlayerData] gave up: {lastError}`)
	return false, nil
end

local function key(player: Player): string
	return `u_{player.UserId}`
end

local function load(player: Player)
	local record: Record =
		{ data = Progress.default(), delta = Progress.newDelta(), dirty = false, loaded = false }
	records[player] = record
	local dataStore = getStore()
	if dataStore then
		local ok, raw = withRetry(function()
			return dataStore:GetAsync(key(player))
		end)
		if ok then
			record.data = Progress.migrate(raw)
		end
	end
	record.loaded = true
	player:SetAttribute("FrameId", record.data.prefs.frame or "paper")
	player:SetAttribute("DataLoaded", true)
end

function PlayerData.get(player: Player): Progress.Data?
	local record = records[player]
	return if record then record.data else nil
end

-- Yields until the record exists; returns nil if the player left first.
function PlayerData.waitFor(player: Player): Progress.Data?
	while player.Parent do
		local record = records[player]
		if record and record.loaded then
			return record.data
		end
		task.wait(0.1)
	end
	return nil
end

-- Marks a set entry, e.g. mark(player, "docs", "doc_list"). Returns true when it was new.
function PlayerData.mark(player: Player, setName: string, id: string): boolean
	local record = records[player]
	if not record then
		return false
	end
	local set = (record.data :: any)[setName]
	if set[id] then
		return false
	end
	set[id] = true
	record.dirty = true
	return true
end

function PlayerData.setPref(player: Player, name: string, value: string)
	local record = records[player]
	if record then
		record.data.prefs[name] = value
		record.dirty = true
	end
end

function PlayerData.addStat(player: Player, name: string, amount: number)
	local record = records[player]
	if not record then
		return
	end
	local stats: any = record.data.stats
	local delta: any = record.delta
	stats[name] += amount
	delta[name] += amount
	record.dirty = true
end

function PlayerData.recordTime(player: Player, seconds: number)
	local record = records[player]
	if not record then
		return
	end
	local best = record.data.stats.bestTime
	if best == 0 or seconds < best then
		record.data.stats.bestTime = seconds
		record.dirty = true
	end
end

function PlayerData.save(player: Player): boolean
	local record = records[player]
	if not record or not record.loaded or not record.dirty then
		return true
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	local delta = record.delta
	record.delta = Progress.newDelta()
	record.dirty = false
	local ok = withRetry(function()
		return dataStore:UpdateAsync(key(player), function(cloud)
			return Progress.commit(Progress.migrate(cloud), record.data, delta)
		end)
	end)
	if not ok then
		-- Keep the delta for the next save: a blip must not lose counters.
		local carried: any = record.delta
		for name, amount in delta :: any do
			carried[name] += amount
		end
		record.dirty = true
	end
	return ok
end

-- Saves everyone and yields until done or a deadline, so a teleport follows a finished save.
function PlayerData.saveAll(deadlineSeconds: number?)
	local pending = 0
	for player in records do
		pending += 1
		task.spawn(function()
			PlayerData.save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + (deadlineSeconds or 10)
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function PlayerData.start()
	local function onJoin(player: Player)
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerData.save(player)
		records[player] = nil
	end)
	game:BindToClose(function()
		if not RunService:IsStudio() then
			PlayerData.saveAll(25)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Session.AutosaveSeconds)
			for player in records do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
end

return PlayerData
