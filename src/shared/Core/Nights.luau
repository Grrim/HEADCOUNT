--!strict
-- Live events on a shift (docs/09_GDD_V2.md §9): tonight's modifier, one a day and the same for
-- everyone, and the anomaly of the week. They are the shift's version of Mission 001's night
-- conditions (Core/Conditions), with the same four nights.
--
-- A first shift is always a standard night: that one is for learning the rules.
local Rng = require("./Rng")

local Nights = {}

export type Night = {
	id: string,
	name: string,
	text: string,
	-- Seconds one recording may run (nil: the standard length).
	recordSeconds: number?,
	-- Multiplies the Registrar's wait between jumps (below 1 is faster).
	jumpScale: number,
	-- Multiplies the brightness of the floors' lamps.
	lightScale: number,
	-- Multiplies what footage pays.
	valueScale: number,
	-- Every figure turns to face the lens, not just the watchers.
	attentive: boolean,
}

Nights.STANDARD = {
	id = "standard",
	name = "A quiet night",
	text = "Nothing out of the ordinary.",
	jumpScale = 1,
	lightScale = 1,
	valueScale = 1,
	attentive = false,
} :: Night

Nights.ALL = {
	{
		id = "short_tape",
		name = "Short tape",
		text = "Recordings stop after 7 s.",
		recordSeconds = 7,
		jumpScale = 1,
		lightScale = 1,
		valueScale = 1,
		attentive = false,
	},
	{
		id = "restless",
		name = "Restless",
		text = "The Registrar moves sooner.",
		jumpScale = 0.82,
		lightScale = 1,
		valueScale = 1,
		attentive = false,
	},
	{
		id = "dim_bulbs",
		name = "Weak bulbs",
		text = "The floors are darker.",
		jumpScale = 1,
		lightScale = 0.55,
		valueScale = 1,
		attentive = false,
	},
	{
		id = "attentive",
		name = "An attentive house",
		text = "Every figure turns to the lens. Footage pays 20% more.",
		jumpScale = 1,
		lightScale = 1,
		valueScale = 1.2,
		attentive = true,
	},
} :: { Night }

-- Tonight's modifier for a day (Core/Quests.day): the same for everyone.
function Nights.tonight(day: number): Night
	local rng = Rng.new(day * 104729 + 7)
	return Nights.ALL[rng:int(1, #Nights.ALL)]
end

-- Clients learn only the id; anything unknown is a standard night.
function Nights.byId(id: any): Night
	for _, night in Nights.ALL do
		if night.id == id then
			return night
		end
	end
	return Nights.STANDARD
end

-- The anomaly of the week: an anomaly kind that turns up on more floors that week, pays double,
-- and pays a bonus the first time a player films it well (3 stars or more) that week.
export type Weekly = { kind: string, rarity: string, name: string }

Nights.WEEKLIES = {
	{ kind = "standing", rarity = "rare", name = "The one who stands" },
	{ kind = "watcher", rarity = "epic", name = "The one who watches" },
} :: { Weekly }
Nights.WEEKLY_CHANCE = 0.6
Nights.WEEKLY_VALUE = 2
Nights.WEEKLY_REWARD = 100
Nights.WEEKLY_STARS = 3

-- The week's anomaly for a week (Core/Records.week): the same for everyone.
function Nights.weekly(week: number): Weekly
	return Nights.WEEKLIES[(week % #Nights.WEEKLIES) + 1]
end

return Nights
