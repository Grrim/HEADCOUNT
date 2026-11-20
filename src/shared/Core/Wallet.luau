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
local Highlight = require("./Highlight")
local Pass = require("./Pass")
local PassConfig = require("../Config/Pass")
local Quests = require("./Quests")

local Wallet = {}

Wallet.VERSION = 1
-- Ranks of the Archive, from the least to the most prized.
Wallet.KINDS = { "sitter", "standing", "watcher", "extra" }
-- Commendations for a place on a finished week's board, best first.
Wallet.HONOURS = { "gold", "silver", "bronze", "top10" }
-- How many finished weeks back a returning player can still collect.
Wallet.CLAIM_WEEKS = 3
-- Shift tapes a player can keep in their Archive.
Wallet.TAPES = 5

-- A shift tape kept in the Archive: enough to rebuild the floor and fly the camera again.
export type Tape = {
	seed: number,
	depth: number,
	stars: number,
	rarity: string,
	kind: string,
	by: string,
	at: number,
	hz: number,
	track: { number },
}

export type Data = {
	v: number,
	frames: number,
	-- Every Frame ever paid, spent or not: what the lobby's records board ranks ties by.
	earned: number,
	levels: { [string]: number },
	deepest: number,
	shifts: number,
	archive: { [string]: number },
	-- This week's standing for the weekly board (Core/Records.week), reset when a new week starts.
	week: number,
	weekDeepest: number,
	weekEarned: number,
	-- The last finished week whose board was checked for this player's place (paid or not), and
	-- the commendations won so far, counted by kind (gold, silver, bronze, top10).
	rewardedWeek: number,
	honours: { [string]: number },
	tapes: { Tape },
	-- Today's daily tasks: how far each has got and which are done (Core/Quests).
	quests: Quests.Progress,
	-- The Biuro Pass: this season's standing, and what its rewards unlocked for good.
	pass: Pass.State,
	cosmetics: { [string]: boolean },
	titles: { [string]: boolean },
	-- What the player wears: a viewfinder frame and a title (nil for none).
	frame: string?,
	title: string?,
}

export type Lock = { id: string, at: number }
export type Record = { data: Data, lock: Lock? }

function Wallet.default(): Data
	return {
		v = Wallet.VERSION,
		frames = 0,
		earned = 0,
		levels = {},
		deepest = 0,
		shifts = 0,
		archive = {},
		week = 0,
		weekDeepest = 0,
		weekEarned = 0,
		rewardedWeek = 0,
		honours = {},
		tapes = {},
		quests = Quests.fresh(0),
		pass = Pass.fresh(""),
		cosmetics = {},
		titles = {},
		frame = nil,
		title = nil,
	}
end

-- Viewfinder frames everyone has; the rest are unlocked (Config/Cosmetics).
Wallet.BASE_FRAMES = { "paper", "crt", "amber" }

local rewardFrames: { [string]: boolean } = {}
local rewardTitles: { [string]: boolean } = {}
for _, season in PassConfig.Seasons do
	for _, track in { season.free, season.premium } do
		for _, reward in track do
			if reward.frame then
				rewardFrames[reward.frame] = true
			end
			if reward.title then
				rewardTitles[reward.title] = true
			end
		end
	end
end

function Wallet.ownsFrame(data: Data, id: string): boolean
	return table.find(Wallet.BASE_FRAMES, id) ~= nil or data.cosmetics[id] == true
end

-- Pays rewards: Frames into the wallet, cosmetics and titles unlocked for good.
function Wallet.grant(data: Data, rewards: { Pass.Reward })
	for _, reward in rewards do
		if reward.frames then
			data.frames += reward.frames
			data.earned += reward.frames
		end
		if reward.frame then
			data.cosmetics[reward.frame] = true
		end
		if reward.title then
			data.titles[reward.title] = true
		end
	end
end

-- Experience towards the season's pass, and every reward it reaches. Returns those rewards.
function Wallet.passXp(
	data: Data,
	season: Pass.Season,
	amount: number,
	premium: boolean
): { Pass.Reward }
	Pass.addXp(data.pass, season, amount)
	local due = Pass.collect(data.pass, season, premium)
	Wallet.grant(data, due)
	return due
end

local RARITIES = { common = true, rare = true, epic = true, legendary = true }
local FIGURES = { sitter = true, standing = true, watcher = true, extra = true }

-- A tape as stored, or nil for anything that is not one.
function Wallet.readTape(raw: any): Tape?
	if typeof(raw) ~= "table" then
		return nil
	end
	local seed, depth, stars, at, hz = raw.seed, raw.depth, raw.stars, raw.at, raw.hz
	if
		typeof(seed) ~= "number"
		or typeof(depth) ~= "number"
		or typeof(stars) ~= "number"
		or typeof(at) ~= "number"
		or typeof(hz) ~= "number"
		or depth < 1
		or depth > 20
		or stars < 1
		or stars > 5
		or hz < 1
		or hz > 30
		or not RARITIES[raw.rarity]
		or not FIGURES[raw.kind]
		or typeof(raw.by) ~= "string"
	then
		return nil
	end
	if not Highlight.unpack(raw.track) then
		return nil
	end
	return {
		seed = math.floor(seed),
		depth = math.floor(depth),
		stars = math.floor(stars),
		rarity = raw.rarity,
		kind = raw.kind,
		by = string.sub(raw.by, 1, 40),
		at = math.floor(at),
		hz = hz,
		track = table.clone(raw.track),
	}
end

-- Keeps a tape in the Archive. A full Archive gives up its weakest tape for a better one.
-- Returns whether it was kept and, when not, why ("kept" for one already there, or "full").
function Wallet.saveTape(data: Data, tape: Tape): (boolean, string?)
	for _, kept in data.tapes do
		if kept.seed == tape.seed and kept.depth == tape.depth and kept.at == tape.at then
			return false, "kept"
		end
	end
	if #data.tapes < Wallet.TAPES then
		table.insert(data.tapes, tape)
		return true, nil
	end
	local weakest, weakestIndex = math.huge, 0
	for index, kept in data.tapes do
		if kept.stars < weakest then
			weakest, weakestIndex = kept.stars, index
		end
	end
	if tape.stars <= weakest then
		return false, "full"
	end
	data.tapes[weakestIndex] = tape
	return true, nil
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
			-- Records saved before `earned` existed: at least what they still hold was earned.
			data.earned = math.max(count(stored.earned, 0, 1e12) or 0, data.frames)
			data.deepest = count(stored.deepest, 0, 100) or 0
			data.shifts = count(stored.shifts, 0, 1e9) or 0
			data.week = count(stored.week, 0, 1e7) or 0
			data.weekDeepest = count(stored.weekDeepest, 0, 100) or 0
			data.weekEarned = count(stored.weekEarned, 0, 1e12) or 0
			data.rewardedWeek = count(stored.rewardedWeek, 0, 1e7) or 0
			local pass = stored.pass
			if typeof(pass) == "table" and typeof(pass.season) == "string" then
				data.pass = {
					season = string.sub(pass.season, 1, 16),
					xp = count(pass.xp, 0, 1e7) or 0,
					freePaid = count(pass.freePaid, 0, 1000) or 0,
					premiumPaid = count(pass.premiumPaid, 0, 1000) or 0,
				}
			end
			if typeof(stored.cosmetics) == "table" then
				for id in rewardFrames do
					if stored.cosmetics[id] == true then
						data.cosmetics[id] = true
					end
				end
			end
			if typeof(stored.titles) == "table" then
				for title in rewardTitles do
					if stored.titles[title] == true then
						data.titles[title] = true
					end
				end
			end
			if typeof(stored.frame) == "string" and Wallet.ownsFrame(data, stored.frame) then
				data.frame = stored.frame
			end
			if typeof(stored.title) == "string" and data.titles[stored.title] then
				data.title = stored.title
			end
			local quests = stored.quests
			if typeof(quests) == "table" and typeof(quests.day) == "number" then
				data.quests.day = math.floor(quests.day)
				for _, quest in Quests.POOL do
					local counted = if typeof(quests.counts) == "table"
						then count(quests.counts[quest.id], 0, quest.target)
						else nil
					if counted and counted > 0 then
						data.quests.counts[quest.id] = counted
					end
					if typeof(quests.done) == "table" and quests.done[quest.id] == true then
						data.quests.done[quest.id] = true
					end
				end
			end
			if typeof(stored.tapes) == "table" then
				for _, storedTape in stored.tapes do
					local tape = Wallet.readTape(storedTape)
					if tape and #data.tapes < Wallet.TAPES then
						table.insert(data.tapes, tape)
					end
				end
			end
			if typeof(stored.honours) == "table" then
				for _, kind in Wallet.HONOURS do
					data.honours[kind] = count(stored.honours[kind], 1, 1e6)
				end
			end
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
-- A new week wipes last week's standing.
function Wallet.rollWeek(data: Data, week: number)
	if data.week ~= week then
		data.week = week
		data.weekDeepest = 0
		data.weekEarned = 0
	end
end

-- `week` (Core/Records.week) also counts the shift towards that week's board.
function Wallet.recordShift(
	data: Data,
	pay: number,
	deepest: number,
	returned: boolean,
	week: number?
)
	local paid = math.max(0, math.floor(pay))
	data.frames += paid
	data.earned += paid
	data.shifts += 1
	if returned then
		data.deepest = math.max(data.deepest, deepest)
	end
	if week then
		Wallet.rollWeek(data, week)
		data.weekEarned += paid
		if returned then
			data.weekDeepest = math.max(data.weekDeepest, deepest)
		end
	end
end

-- The finished weeks whose boards this player has not been checked against yet, oldest first:
-- at most the last few, never the week still running.
function Wallet.weeksToClaim(data: Data, currentWeek: number): { number }
	local weeks = {}
	local first = math.max(data.rewardedWeek + 1, currentWeek - Wallet.CLAIM_WEEKS)
	for week = first, currentWeek - 1 do
		table.insert(weeks, week)
	end
	return weeks
end

-- Settles one finished week: pays the place (nil when not on the board) once, and never again
-- for that week or any before it. Returns the Frames paid.
function Wallet.claimWeek(data: Data, week: number, pay: number, honour: string?): number
	if week <= data.rewardedWeek then
		return 0
	end
	data.rewardedWeek = week
	local paid = math.max(0, math.floor(pay))
	data.frames += paid
	data.earned += paid
	if honour and table.find(Wallet.HONOURS, honour) then
		data.honours[honour] = (data.honours[honour] or 0) + 1
	end
	return paid
end

-- Counts something that happened on a shift towards today's tasks and pays any it finished.
-- Returns the tasks finished.
function Wallet.questEvent(data: Data, now: number, event: string, amount: number): { Quests.Quest }
	local finished = Quests.record(data.quests, Quests.day(now), event, amount)
	for _, quest in finished do
		data.frames += quest.reward
		data.earned += quest.reward
	end
	return finished
end

-- What was earned on a fresh wallet before the saved one arrived, added onto the saved one.
-- Levels are not merged: buying waits for the saved wallet.
function Wallet.merge(record: Data, early: Data): Data
	record.frames += early.frames
	record.earned += early.earned
	record.shifts += early.shifts
	record.deepest = math.max(record.deepest, early.deepest)
	for kind, stars in early.archive do
		record.archive[kind] = math.max(record.archive[kind] or 0, stars)
	end
	if early.week > record.week then
		record.week = early.week
		record.weekDeepest = early.weekDeepest
		record.weekEarned = early.weekEarned
	elseif early.week == record.week then
		record.weekDeepest = math.max(record.weekDeepest, early.weekDeepest)
		record.weekEarned += early.weekEarned
	end
	-- Today's tasks: what the early wallet counted adds to the saved one. Rewards it paid are in
	-- its frames already, merged above.
	local earlyQuests, savedQuests = early.quests, record.quests
	if earlyQuests.day > savedQuests.day then
		record.quests = earlyQuests
	elseif earlyQuests.day == savedQuests.day then
		for id, counted in earlyQuests.counts do
			savedQuests.counts[id] = math.max(savedQuests.counts[id] or 0, counted)
		end
		for id in earlyQuests.done do
			savedQuests.done[id] = true
		end
	end
	-- The pass: what the early wallet earned adds on; what it unlocked stays unlocked.
	if early.pass.season == record.pass.season then
		record.pass.xp += early.pass.xp
	elseif early.pass.season ~= "" and early.pass.xp > 0 then
		record.pass = early.pass
	end
	for id in early.cosmetics do
		record.cosmetics[id] = true
	end
	for title in early.titles do
		record.titles[title] = true
	end
	-- Weekly rewards are only ever claimed on a saved wallet, so the early one holds none.
	return record
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
