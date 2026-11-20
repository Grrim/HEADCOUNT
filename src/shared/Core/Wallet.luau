--!strict
-- What a player keeps between shifts: Frames, upgrade levels, the deepest floor they came back
-- from, and the Archive of anomalies they have filmed. Unlike Core/Progress this holds money,
-- which can go down, so merging is not enough (docs/09_GDD_V2.md §11.3): one server at a time
-- owns the record through a session lock kept inside it.
--
--   claim    the UpdateAsync transform on join: take the lock if it is free, stale or ours
--   commit   the transform for a save: write only while we still hold the lock
--   release  the same, and give the lock back (on leave or before a teleport)
--
-- A lock is stale once nobody has refreshed it for `ttl` seconds, so a crashed server can not
-- hold a record for ever. A transform that returns nil leaves the cloud record untouched.
local Wallet = {}

Wallet.VERSION = 1
-- Ranks of the Archive, from the least to the most prized.
Wallet.KINDS = { "sitter", "standing", "watcher", "extra" }

export type Data = {
	v: number,
	frames: number,
	levels: { [string]: number },
	deepest: number,
	shifts: number,
	archive: { [string]: number },
}

export type Lock = { id: string, at: number }
export type Record = { data: Data, lock: Lock? }

function Wallet.default(): Data
	return { v = Wallet.VERSION, frames = 0, levels = {}, deepest = 0, shifts = 0, archive = {} }
end

local function count(value: any, low: number, high: number): number?
	if typeof(value) ~= "number" or value ~= value or value < low or value > high then
		return nil
	end
	return math.floor(value)
end

-- Reads whatever is stored, keeping only what makes sense; anything else falls back to defaults.
function Wallet.migrate(raw: any): Record
	local data = Wallet.default()
	local lock: Lock? = nil
	if typeof(raw) == "table" then
		local stored = raw.data
		if typeof(stored) == "table" then
			data.frames = count(stored.frames, 0, 1e9) or 0
			data.deepest = count(stored.deepest, 0, 100) or 0
			data.shifts = count(stored.shifts, 0, 1e9) or 0
			if typeof(stored.levels) == "table" then
				for key, value in stored.levels do
					local level = count(value, 1, 20)
					if typeof(key) == "string" and level then
						data.levels[key] = level
					end
				end
			end
			if typeof(stored.archive) == "table" then
				for key, value in stored.archive do
					local stars = count(value, 1, 5)
					if typeof(key) == "string" and stars then
						data.archive[key] = stars
					end
				end
			end
		end
		local storedLock = raw.lock
		if
			typeof(storedLock) == "table"
			and typeof(storedLock.id) == "string"
			and typeof(storedLock.at) == "number"
		then
			lock = { id = storedLock.id, at = storedLock.at }
		end
	end
	return { data = data, lock = lock }
end

local function freeFor(lock: Lock?, session: string, now: number, ttl: number): boolean
	return lock == nil or lock.id == session or now - lock.at >= ttl
end

-- Returns the record to write and whether the lock is now ours. When it is not, the record is
-- returned unchanged so the caller can wait and try again.
function Wallet.claim(raw: any, session: string, now: number, ttl: number): (Record, boolean)
	local record = Wallet.migrate(raw)
	if not freeFor(record.lock, session, now, ttl) then
		return record, false
	end
	record.lock = { id = session, at = now }
	return record, true
end

-- Writes this session's data over the cloud's, and refreshes the lock, only while we hold it.
function Wallet.commit(raw: any, data: Data, session: string, now: number): Record?
	local record = Wallet.migrate(raw)
	local lock = record.lock
	if not lock or lock.id ~= session then
		return nil
	end
	return { data = Wallet.migrate({ data = data }).data, lock = { id = session, at = now } }
end

function Wallet.release(raw: any, data: Data, session: string, now: number): Record?
	local record = Wallet.commit(raw, data, session, now)
	if record then
		record.lock = nil
	end
	return record
end

-- After a shift: the pay, and the depth only when the team came back up in the lift.
function Wallet.recordShift(data: Data, pay: number, deepest: number, returned: boolean)
	data.frames += math.max(0, math.floor(pay))
	data.shifts += 1
	if returned then
		data.deepest = math.max(data.deepest, deepest)
	end
end

-- Keeps the best stars per kind of anomaly. Returns true for a new kind or a better shot.
function Wallet.archive(data: Data, kind: string, stars: number): boolean
	if not table.find(Wallet.KINDS, kind) then
		return false
	end
	local best = data.archive[kind] or 0
	if stars <= best then
		return false
	end
	data.archive[kind] = math.clamp(math.floor(stars), 1, 5)
	return true
end

-- How many kinds the Archive holds, out of how many there are.
function Wallet.archiveCount(data: Data): (number, number)
	local found = 0
	for _, kind in Wallet.KINDS do
		if data.archive[kind] then
			found += 1
		end
	end
	return found, #Wallet.KINDS
end

return Wallet
