--!strict
-- Durable player progress. Teleports make two servers race on the same key, so a save never
-- overwrites: sets are unioned and counters are added as session deltas. Progress can only grow,
-- so a stale save cannot undo anything. There is no currency here; anything that can be spent
-- would need a session lock instead.
local Progress = {}

Progress.VERSION = 1

export type Data = {
	v: number,
	missions: { [string]: boolean },
	docs: { [string]: boolean },
	achievements: { [string]: boolean },
	cosmetics: { [string]: boolean },
	flags: { [string]: boolean },
	prefs: { [string]: string },
	stats: { completions: number, replays: number, cuts: number, bestTime: number },
}

export type Delta = { completions: number, replays: number, cuts: number }

local SETS = { "missions", "docs", "achievements", "cosmetics", "flags" }

function Progress.default(): Data
	return {
		v = Progress.VERSION,
		missions = { M001 = true },
		docs = {},
		achievements = {},
		cosmetics = {},
		flags = {},
		prefs = {},
		stats = { completions = 0, replays = 0, cuts = 0, bestTime = 0 },
	}
end

function Progress.newDelta(): Delta
	return { completions = 0, replays = 0, cuts = 0 }
end

-- Fills anything missing from an older or damaged record; unknown keys are dropped.
function Progress.migrate(raw: any): Data
	local data = Progress.default()
	if typeof(raw) ~= "table" then
		return data
	end
	for _, name in SETS do
		local incoming = raw[name]
		if typeof(incoming) == "table" then
			local target = (data :: any)[name]
			for key, value in incoming do
				if typeof(key) == "string" and value == true then
					target[key] = true
				end
			end
		end
	end
	if typeof(raw.prefs) == "table" then
		for key, value in raw.prefs do
			if typeof(key) == "string" and typeof(value) == "string" then
				data.prefs[key] = value
			end
		end
	end
	if typeof(raw.stats) == "table" then
		for key in data.stats do
			local value = raw.stats[key]
			if typeof(value) == "number" and value == value and value >= 0 then
				(data.stats :: any)[key] = value
			end
		end
	end
	return data
end

-- The UpdateAsync transform: what is in the cloud, plus what this session has learned.
function Progress.commit(cloud: Data, session: Data, delta: Delta): Data
	local merged = Progress.migrate(cloud)
	for _, name in SETS do
		local target = (merged :: any)[name]
		for key in (session :: any)[name] do
			target[key] = true
		end
	end
	-- Preferences are the one thing that may change back: the latest choice wins.
	for key, value in session.prefs do
		merged.prefs[key] = value
	end
	merged.stats.completions += delta.completions
	merged.stats.replays += delta.replays
	merged.stats.cuts += delta.cuts
	local best = session.stats.bestTime
	if best > 0 and (merged.stats.bestTime == 0 or best < merged.stats.bestTime) then
		merged.stats.bestTime = best
	end
	return merged
end

return Progress
