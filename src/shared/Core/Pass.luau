--!strict
-- The Biuro Pass as plain data (season definitions in Config/Pass). Experience earned in a season
-- moves a player up its tiers; every tier reached pays its free reward, and its premium reward too
-- for a player who owns the season's Game Pass, also for tiers reached before buying it.
local PassConfig = require("../Config/Pass")

local Pass = {}

export type Season = PassConfig.Season
export type Reward = PassConfig.Reward

-- A player's standing in one season: experience, and the highest tier paid on each track.
export type State = { season: string, xp: number, freePaid: number, premiumPaid: number }

function Pass.fresh(season: string): State
	return { season = season, xp = 0, freePaid = 0, premiumPaid = 0 }
end

-- The season running at this time, if any.
function Pass.current(now: number, seasons: { Season }?): Season?
	for _, season in seasons or PassConfig.Seasons do
		if now >= season.starts and now < season.ends then
			return season
		end
	end
	return nil
end

function Pass.tier(season: Season, xp: number): number
	return math.clamp(math.floor(xp / season.xpPerTier), 0, season.tiers)
end

-- Adds experience; a state from another season starts over (its rewards stay with the player).
function Pass.addXp(state: State, season: Season, amount: number)
	if state.season ~= season.id then
		state.season = season.id
		state.xp = 0
		state.freePaid = 0
		state.premiumPaid = 0
	end
	state.xp = math.min(state.xp + math.max(0, math.floor(amount)), season.xpPerTier * season.tiers)
end

-- Every reward due and not yet paid, in tier order, marked paid. `premium` is whether the player
-- owns the season's Game Pass.
function Pass.collect(state: State, season: Season, premium: boolean): { Reward }
	local due = {}
	if state.season ~= season.id then
		return due
	end
	local reached = Pass.tier(season, state.xp)
	for tier = state.freePaid + 1, reached do
		local reward = season.free[tier]
		if reward then
			table.insert(due, reward)
		end
	end
	state.freePaid = math.max(state.freePaid, reached)
	if premium then
		for tier = state.premiumPaid + 1, reached do
			local reward = season.premium[tier]
			if reward then
				table.insert(due, reward)
			end
		end
		state.premiumPaid = math.max(state.premiumPaid, reached)
	end
	return due
end

local function describe(reward: Reward?): string?
	if not reward then
		return nil
	end
	local parts = {}
	if reward.frames then
		table.insert(parts, `{reward.frames} frames`)
	end
	if reward.frame then
		table.insert(parts, `"{reward.frame}" viewfinder`)
	end
	if reward.title then
		table.insert(parts, `title "{reward.title}"`)
	end
	return table.concat(parts, " + ")
end
Pass.describe = describe

-- What a screen shows: the season, the tier and how far into the next, what comes next on each
-- track, and the time left.
function Pass.view(state: State, season: Season, now: number, premium: boolean): { [string]: any }
	local xp = if state.season == season.id then state.xp else 0
	local tier = Pass.tier(season, xp)
	local nextFree, nextPremium = nil, nil
	for at = tier + 1, season.tiers do
		nextFree = nextFree
			or (if season.free[at] then { tier = at, text = describe(season.free[at]) } else nil)
		nextPremium = nextPremium
			or (
				if season.premium[at]
					then { tier = at, text = describe(season.premium[at]) }
					else nil
			)
	end
	return {
		name = season.name,
		tier = tier,
		tiers = season.tiers,
		xp = xp - tier * season.xpPerTier,
		xpPerTier = season.xpPerTier,
		premium = premium,
		forSale = season.gamePassId ~= 0,
		gamePassId = season.gamePassId,
		nextFree = nextFree,
		nextPremium = nextPremium,
		daysLeft = math.max(0, math.ceil((season.ends - now) / 86400)),
	}
end

return Pass
