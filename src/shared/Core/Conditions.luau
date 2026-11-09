--!strict
-- Tonight's conditions: from the second visit on, each expedition draws one change to how the
-- night goes, so a team that knows the building still meets something new. The first visit is
-- always standard, because that one is for learning the rules.
local Rng = require("./Rng")

local Conditions = {}

export type Condition = {
	id: string,
	-- Seconds one recording can run before the camera stops it.
	tapeSeconds: number,
	-- Multiplies the Registrar's wait between jumps (below 1 is faster).
	jumpScale: number,
	-- Multiplies the brightness of the building's lights (not the emergency lamps).
	lightScale: number,
	-- Multiplies how many of the audience turn to watch the lens.
	watcherScale: number,
}

local STANDARD: Condition = {
	id = "standard",
	tapeSeconds = 12,
	jumpScale = 1,
	lightScale = 1,
	watcherScale = 1,
}

local VARIANTS: { Condition } = {
	{ id = "short_tape", tapeSeconds = 8, jumpScale = 1, lightScale = 1, watcherScale = 1 },
	{ id = "restless", tapeSeconds = 12, jumpScale = 0.82, lightScale = 1, watcherScale = 1 },
	{ id = "dim_bulbs", tapeSeconds = 12, jumpScale = 1, lightScale = 0.55, watcherScale = 1 },
	{ id = "attentive", tapeSeconds = 12, jumpScale = 1, lightScale = 1, watcherScale = 2 },
}

Conditions.STANDARD = STANDARD

function Conditions.forRun(seed: number, completions: number): Condition
	if completions <= 0 then
		return STANDARD
	end
	-- Its own stream, so the choice never shifts the puzzle drawn from the same seed.
	local rng = Rng.new(seed * 31 + 17)
	return VARIANTS[rng:int(1, #VARIANTS)]
end

-- Clients only learn the id; anything unknown falls back to a standard night.
function Conditions.byId(id: string?): Condition
	for _, condition in VARIANTS do
		if condition.id == id then
			return condition
		end
	end
	return STANDARD
end

function Conditions.all(): { Condition }
	return table.clone(VARIANTS)
end

return Conditions
