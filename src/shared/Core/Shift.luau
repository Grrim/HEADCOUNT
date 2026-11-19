--!strict
-- One shift as a state machine, with no Instances. The lift is the only way between floors:
--
--   ready  --descend-->  ride  --arrive-->  floor  --descend-->  ride ...
--                                           floor  --ascend-->   return  --finish-->  over
--                                           floor  --fail-->     over
--
-- Footage shot on a floor is carried until the team rides the lift away from it; only then is it
-- banked. Losing everyone on a floor loses what was carried, and the Bureau still pays a quarter
-- of what was banked. Bringing back less than the quota pays the same quarter.
local Shift = {}

Shift.MAX_DEPTH = 5
Shift.BASE_PAY = 0.25

local MULTIPLIERS = { 1, 1.5, 2, 3, 4 }

export type State = {
	phase: string,
	depth: number,
	deepest: number,
	quota: number,
	banked: number,
	carried: number,
	result: string?,
}

function Shift.quotaFor(players: number): number
	return 40 + 20 * (math.clamp(players, 1, 4) - 1)
end

function Shift.new(quota: number): State
	return {
		phase = "ready",
		depth = 0,
		deepest = 0,
		quota = quota,
		banked = 0,
		carried = 0,
		result = nil,
	}
end

function Shift.multiplier(depth: number): number
	return MULTIPLIERS[math.clamp(depth, 1, #MULTIPLIERS)]
end

local function bank(state: State)
	state.banked += state.carried
	state.carried = 0
end

function Shift.canDescend(state: State): boolean
	return (state.phase == "ready" or state.phase == "floor") and state.depth < Shift.MAX_DEPTH
end

function Shift.descend(state: State): boolean
	if not Shift.canDescend(state) then
		return false
	end
	bank(state)
	state.depth += 1
	state.phase = "ride"
	return true
end

function Shift.arrive(state: State)
	if state.phase == "ride" then
		state.phase = "floor"
		state.deepest = math.max(state.deepest, state.depth)
	end
end

function Shift.ascend(state: State): boolean
	if state.phase ~= "floor" then
		return false
	end
	bank(state)
	state.phase = "return"
	return true
end

function Shift.finish(state: State)
	if state.phase == "return" then
		state.phase = "over"
		state.result = "returned"
	end
end

function Shift.fail(state: State)
	if state.phase == "floor" or state.phase == "ride" then
		state.carried = 0
		state.phase = "over"
		state.result = "cut"
	end
end

-- Footage counts only on a floor, already multiplied by that floor's depth. Returns what it added.
function Shift.addFootage(state: State, value: number): number
	if state.phase ~= "floor" or value <= 0 then
		return 0
	end
	local added = math.floor(value * Shift.multiplier(state.depth) + 0.5)
	state.carried += added
	return added
end

function Shift.quotaMet(state: State): boolean
	return state.banked + state.carried >= state.quota
end

function Shift.payout(state: State): number
	if state.phase ~= "over" then
		return 0
	end
	if state.result == "returned" and state.banked >= state.quota then
		return state.banked
	end
	return math.floor(state.banked * Shift.BASE_PAY)
end

return Shift
