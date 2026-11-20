--!strict
-- Frames, upgrade levels, the depth record and the Archive, saved per player (Core/Wallet). The
-- record is owned by one server at a time through a lock inside it; this server takes it when the
-- player joins, refreshes it while they play, saves after every pay and purchase, and gives it
-- back when they leave.
--
-- Until the record is read the player plays on a fresh wallet. Whatever they earn meanwhile is
-- added onto the record once it arrives (purchases wait for it), so a slow claim loses nothing.
-- Writes for one player never overlap: a change during a save is saved right after it.
--
-- Without DataStore access (Studio with API Services off) everything works in memory, as the
-- prototype did, and says so once in Output.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)

local ShiftBank = {}

local CFG = Config.Shift
local STORE_NAME = "Shift_v1"
local CLAIM_WAIT = 6
-- Long enough for a lock left by a crashed server to go stale.
local CLAIM_ATTEMPTS = math.ceil(CFG.LockTtl / CLAIM_WAIT) + 2

type Entry = {
	data: Wallet.Data,
	owned: boolean,
	loaded: boolean,
	dirty: boolean,
	writing: boolean,
	gone: boolean,
	-- True after this server gave the lock back for a teleport: only then may it take it back.
	released: boolean,
}

local session = HttpService:GenerateGUID(false)
local entries: { [Player]: Entry } = {}
local requested: { [Player]: boolean } = {}
local store: DataStore? = nil
local storeChecked = false
local listeners: { (player: Player) -> () } = {}

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
		warn(`[ShiftBank] no DataStore, frames live in memory only: {result}`)
	end
	return store
end

local function key(player: Player): string
	return `u_{player.UserId}`
end

-- A player who already left gets a throwaway wallet, never a new entry.
local function entryOf(player: Player): Entry
	local entry = entries[player]
	if entry then
		return entry
	end
	local fresh: Entry = {
		data = Wallet.default(),
		owned = false,
		loaded = false,
		dirty = false,
		writing = false,
		gone = false,
		released = false,
	}
	if player.Parent then
		entries[player] = fresh
	end
	return fresh
end

-- Adds what was earned on the fresh wallet before the record arrived onto the record.
local merge = Wallet.merge

local function snapshot(data: Wallet.Data): Wallet.Data
	local copy = table.clone(data)
	copy.levels = table.clone(data.levels)
	copy.archive = table.clone(data.archive)
	return copy
end

-- One UpdateAsync: a commit, or a release that also gives the lock back.
local function write(player: Player, entry: Entry, release: boolean): boolean
	local dataStore = getStore()
	if not entry.owned or not dataStore then
		return false
	end
	local data = snapshot(entry.data)
	local held = true
	local ok, err = pcall(function()
		dataStore:UpdateAsync(key(player), function(raw)
			local now = os.time()
			local record = if release
				then Wallet.release(raw, data, session, now)
				else Wallet.commit(raw, data, session, now)
			held = record ~= nil
			return record
		end)
	end)
	if not ok then
		warn(`[ShiftBank] save failed for {player.Name}: {err}`)
		return false
	end
	if not held then
		-- Someone else took the record over: stop writing, or two servers would fight over it.
		entry.owned = false
		warn(`[ShiftBank] lost the lock on {player.Name}'s record; no longer saving it`)
		return false
	end
	if release then
		entry.owned = false
	end
	return true
end

-- Saves until nothing is left to save; never two writes for one player at once.
local function flush(player: Player, entry: Entry)
	if entry.writing then
		return
	end
	entry.writing = true
	while entry.dirty and entry.owned do
		entry.dirty = false
		if not write(player, entry, false) then
			break
		end
	end
	entry.writing = false
end

-- Takes the record's lock, waiting for a server that still holds it (a teleport in progress, or a
-- crash whose lock has to go stale). In Studio every playtest is a new server and the last one
-- may not have let go, so a Studio session simply takes the record.
local function claim(player: Player, dataStore: DataStore): Wallet.Data?
	local ttl = if RunService:IsStudio() then 0 else CFG.LockTtl
	for attempt = 1, CLAIM_ATTEMPTS do
		local owned = false
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key(player), function(raw)
				local record, got = Wallet.claim(raw, session, os.time(), ttl)
				owned = got
				return if got then record else nil
			end)
		end)
		if ok and owned then
			return Wallet.migrate(result).data
		end
		if not ok then
			warn(`[ShiftBank] claim failed for {player.Name}: {result}`)
			if RunService:IsStudio() then
				return nil
			end
		end
		if not player.Parent then
			return nil
		end
		if attempt < CLAIM_ATTEMPTS then
			task.wait(CLAIM_WAIT)
		end
	end
	warn(`[ShiftBank] {player.Name}'s record is still held elsewhere; playing without saving`)
	return nil
end

local function load(player: Player)
	if requested[player] then
		return
	end
	requested[player] = true
	local entry = entryOf(player)
	local dataStore = getStore()
	local data = if dataStore then claim(player, dataStore) else nil
	if data then
		entry.data = merge(data, entry.data)
		entry.owned = true
		if not player.Parent or entry.gone then
			-- They left while the claim was waiting: hand the lock straight back.
			write(player, entry, true)
			return
		end
		entry.dirty = true
		task.spawn(flush, player, entry)
	end
	entry.loaded = true
	player:SetAttribute("WalletLoaded", true)
	for _, listener in listeners do
		task.spawn(listener, player)
	end
end

function ShiftBank.data(player: Player): Wallet.Data
	return entryOf(player).data
end

function ShiftBank.loaded(player: Player): boolean
	return entryOf(player).loaded
end

-- True while this server owns the player's saved record (false offline or in Studio without API).
function ShiftBank.saving(player: Player): boolean
	return entryOf(player).owned
end

-- Called with each player whose wallet has just been read.
function ShiftBank.onLoaded(listener: (player: Player) -> ())
	table.insert(listeners, listener)
end

-- Marks the wallet changed and saves it in the background.
function ShiftBank.changed(player: Player)
	local entry = entries[player]
	if entry then
		entry.dirty = true
		task.spawn(flush, player, entry)
	end
end

-- Before a teleport to the lobby: save and give the lock back, so whichever server the player
-- lands on next can take the record at once. True when nothing is left unsaved.
function ShiftBank.release(player: Player): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	local deadline = os.clock() + 10
	while entry.writing and os.clock() < deadline do
		task.wait(0.1)
	end
	if not entry.owned then
		-- Never owned (playing unsaved): there is nothing to give back.
		return true
	end
	local ok = write(player, entry, true)
	entry.released = ok
	return ok
end

-- The teleport failed and the player stays: take the lock back and keep saving this wallet,
-- which is the newest copy there is (this server wrote last).
function ShiftBank.resume(player: Player)
	local entry = entries[player]
	local dataStore = getStore()
	-- Only a wallet this server saved and let go of is newer than the cloud's. A wallet that was
	-- never saved must never be written over the stored one.
	if not entry or not entry.released or entry.owned or not dataStore then
		return
	end
	entry.released = false
	task.spawn(function()
		if claim(player, dataStore) and entries[player] == entry then
			entry.owned = true
			entry.dirty = true
			flush(player, entry)
		end
	end)
end

local function leave(player: Player)
	local entry = entries[player]
	entries[player] = nil
	requested[player] = nil
	if not entry then
		return
	end
	entry.gone = true
	-- Let a save under way finish, then save once more and give the lock back.
	local deadline = os.clock() + 10
	while entry.writing and os.clock() < deadline do
		task.wait(0.1)
	end
	if entry.owned then
		write(player, entry, true)
	end
end

function ShiftBank.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	Players.PlayerRemoving:Connect(leave)
	game:BindToClose(function()
		local pending = 0
		for player, entry in entries do
			if entry.owned then
				pending += 1
				task.spawn(function()
					write(player, entry, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + (if RunService:IsStudio() then 3 else 25)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function ShiftBank.start()
	-- Anyone who joined before PlayerAdded was connected (common in Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	-- Keeps every lock fresh: a save is also the lock's heartbeat.
	while true do
		task.wait(CFG.AutosaveSeconds)
		for player, entry in entries do
			if entry.owned then
				entry.dirty = true
				task.spawn(flush, player, entry)
			end
		end
	end
end

return ShiftBank
