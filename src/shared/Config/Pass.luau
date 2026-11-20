--!strict
-- The Biuro Pass (docs/09_GDD_V2.md §4, §6): a season of 30 tiers earned by playing shifts. The
-- free track pays Frames and a few cosmetics; the premium track (a Game Pass) pays cosmetics only.
-- Frames buy camera upgrades, so Frames on a paid track would sell an advantage for Robux, which
-- §6 rules out ("Nigdy: ulepszenia sprzętu za Robux").
--
-- A season is a date range in UTC. A new season is a new entry here (and a new Game Pass): the
-- previous season's progress stays behind, its rewards stay unlocked.

export type Reward = { frames: number?, frame: string?, title: string? }
export type Season = {
	id: string,
	name: string,
	starts: number,
	ends: number,
	-- The Game Pass that unlocks the premium track; 0 until the owner creates it.
	gamePassId: number,
	xpPerTier: number,
	tiers: number,
	free: { [number]: Reward },
	premium: { [number]: Reward },
}

local function season1(): Season
	local free: { [number]: Reward } = {}
	for tier = 1, 30 do
		free[tier] = { frames = 25 }
	end
	free[10] = { frames = 25, frame = "bureau" }
	free[15] = { frames = 25, title = "Night Porter" }
	free[20] = { frames = 25, frame = "tapehead" }
	free[30] = { frames = 50, frame = "deep" }

	local premium: { [number]: Reward } = {
		[2] = { frame = "ledger" },
		[4] = { title = "Junior Archivist" },
		[6] = { frame = "sodium" },
		[8] = { title = "Lift Operator" },
		[10] = { frame = "curtain" },
		[12] = { title = "Continuity Clerk" },
		[14] = { frame = "static" },
		[16] = { title = "Registrar's Shadow" },
		[18] = { frame = "jutrzenka" },
		[20] = { title = "Senior Archivist" },
		[22] = { frame = "neon" },
		[24] = { title = "Floor Walker" },
		[26] = { frame = "minus13" },
		[28] = { title = "Keeper of Tape Zero" },
		[30] = { frame = "gold" },
	}
	return {
		id = "S1",
		name = "SEASON 1: NIGHT SHIFT",
		-- Monday 2026-11-16 00:00 UTC, for six weeks.
		starts = 1_794_787_200,
		ends = 1_794_787_200 + 42 * 86400,
		gamePassId = 0,
		xpPerTier = 100,
		tiers = 30,
		free = free,
		premium = premium,
	}
end

return {
	Seasons = { season1() },
	-- Experience earned on a shift.
	Xp = {
		-- Per point of footage brought back up in the lift.
		banked = 1,
		-- A shift come back with the quota met.
		quota = 50,
		-- A daily task done, by its tier (easy, medium, hard).
		task = { 50, 100, 200 },
	},
}
