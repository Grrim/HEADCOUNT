--!strict
-- What this player should do next, worked out from what they actually know: their own tapes, the
-- digits they have read, the clues the team has called out. Pure, so it is tested headless.
-- Every step has a plain line for the objective card and a blunter radio line for a player who
-- has been stuck on it for a while.
local Guide = {}

export type Facts = {
	phase: string,
	-- Coat tags found under seats whose coat nobody has searched yet.
	pendingTags: { number },
	-- Rows where one of this player's tapes caught someone turned round, seat not found yet.
	pendingRows: { string },
	reels: number,
	tapesSaved: number,
	-- The newest tape has been watched at least once.
	latestWatched: boolean,
	tapesLeft: number,
	-- Digits this player has read off the cards, by position.
	code: { [number]: number },
	codeLength: number,
	-- Positions of the code dealt to this player; the rest are on teammates' cards.
	dealt: number,
	order: string?,
	doorSide: number?,
}

export type Step = {
	key: string,
	args: { any },
	nudge: string,
	nudgeArgs: { any },
	-- Seconds on this step before the radio spells it out.
	nudgeAfter: number,
}

Guide.NUDGE_AFTER = 150

local function step(key: string, args: { any }, nudge: string, after: number?): Step
	return {
		key = key,
		args = args,
		nudge = nudge,
		nudgeArgs = args,
		nudgeAfter = after or Guide.NUDGE_AFTER,
	}
end

-- Seen from the hall, facing the stage: +X is on the right.
function Guide.sideKey(doorSide: number?): string
	if doorSide == 1 then
		return "side_right"
	elseif doorSide == -1 then
		return "side_left"
	end
	return "side_unknown"
end

-- The code as this player can write it down: known digits, and a gap for each one still missing.
function Guide.codeText(code: { [number]: number }, length: number): string
	local parts = {}
	for position = 1, length do
		local digit = code[position]
		table.insert(parts, if digit then tostring(digit) else "_")
	end
	return table.concat(parts, " ")
end

local function count(map: { [number]: number }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

local function protocol(f: Facts): Step
	if #f.pendingTags > 0 then
		local tags = {}
		for _, tag in f.pendingTags do
			table.insert(tags, tostring(tag))
		end
		return step("step_coat", { table.concat(tags, ", ") }, "nudge_coat", 120)
	end
	if #f.pendingRows > 0 then
		return step("step_seat", { table.concat(f.pendingRows, ", ") }, "nudge_seat", 120)
	end
	if f.tapesSaved > 0 and not f.latestWatched then
		return step("step_play", {}, "nudge_play", 60)
	end
	if f.tapesLeft <= 0 then
		return step("step_no_tape", {}, "nudge_no_tape", 30)
	end
	if f.tapesSaved == 0 then
		return step("step_film", {}, "nudge_film", 90)
	end
	if f.reels > 0 then
		return step("step_more_reels", { f.reels }, "nudge_film_more")
	end
	return step("step_film_more", {}, "nudge_film_more")
end

local function power(f: Facts): Step
	local known = count(f.code)
	if f.dealt == 0 or known < f.dealt then
		return step("step_code_find", {}, "nudge_code")
	end
	local text = Guide.codeText(f.code, f.codeLength)
	if f.dealt < f.codeLength then
		return step("step_code_share", { text }, "nudge_share")
	end
	return step("step_code_enter", { text }, "nudge_basement", 120)
end

-- translate turns a nested string key (the door's side) into words; tests pass the identity.
function Guide.step(f: Facts, translate: ((string) -> string)?): Step?
	local t = translate or function(key: string): string
		return key
	end
	local phase = f.phase
	if phase == "Protocol" then
		return protocol(f)
	elseif phase == "Power" then
		return power(f)
	elseif phase == "Projector" then
		if f.order then
			return step("step_order_load", { f.order }, "nudge_load", 120)
		end
		return step("step_order_find", {}, "nudge_order")
	elseif phase == "Door" then
		return step("step_door", { t(Guide.sideKey(f.doorSide)) }, "nudge_door", 90)
	elseif phase == "Register" then
		return step("step_register", {}, "nudge_register", 60)
	elseif phase == "Climax" then
		return step("step_bell", {}, "nudge_bell", 35)
	end
	return nil
end

-- Two steps are the same step when they would print the same line.
function Guide.id(s: Step?): string
	if not s then
		return ""
	end
	local parts = { s.key }
	for _, arg in s.args do
		table.insert(parts, tostring(arg))
	end
	return table.concat(parts, "|")
end

return Guide
