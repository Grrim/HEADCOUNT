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
--
-- Carried footage lives on the camera that shot it (`carriedBy`, keyed by holder). A camera that
-- falls when its owner is cut takes its footage with it, and whoever picks it up carries it on.
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
	carriedBy: { [number]: number },
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
		carriedBy = {},
		result = nil,
	}
end

function Shift.multiplier(depth: number): number
	return MULTIPLIERS[math.clamp(depth, 1, #MULTIPLIERS)]
end

local function bank(state: State)
	state.banked += state.carried
	state.carried = 0
	state.carriedBy = {}
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
		-- Anything filmed inside the lift on the way up still arrives with it.
		bank(state)
		state.phase = "over"
		state.result = "returned"
	end
end

function Shift.fail(state: State)
	if state.phase == "floor" or state.phase == "ride" then
		state.carried = 0
		state.carriedBy = {}
		state.phase = "over"
		state.result = "cut"
	end
end

local function carry(state: State, value: number, holder: number?): number
	local added = math.floor(value * Shift.multiplier(state.depth) + 0.5)
	local key = holder or 0
	state.carriedBy[key] = (state.carriedBy[key] or 0) + added
	state.carried += added
	return added
end

-- Footage counts only on a floor, already multiplied by that floor's depth. `holder` is whose
-- camera holds it (0 when nobody in particular). Returns what it added.
function Shift.addFootage(state: State, value: number, holder: number?): number
	if state.phase ~= "floor" or value <= 0 then
		return 0
	end
	return carry(state, value, holder)
end

-- The one thing worth filming inside the lift is whatever rode along with the team. It counts
-- during a ride either way, and arrives with the lift.
function Shift.addRideFootage(state: State, value: number, holder: number?): number
	if (state.phase ~= "ride" and state.phase ~= "return") or value <= 0 then
		return 0
	end
	return carry(state, value, holder)
end

-- What this holder's camera carries.
function Shift.carriedOf(state: State, holder: number): number
	return state.carriedBy[holder] or 0
end

-- The holder's camera fell: its footage leaves the team's hands. Returns how much it held.
function Shift.drop(state: State, holder: number): number
	local amount = state.carriedBy[holder] or 0
	state.carriedBy[holder] = nil
	state.carried -= amount
	return amount
end

-- Someone picked a fallen camera up on a floor and carries its footage on. Returns whether it was
-- taken: only on a floor, because a camera left behind is gone with its floor.
function Shift.pickUp(state: State, holder: number, amount: number): boolean
	if state.phase ~= "floor" or amount < 0 then
		return false
	end
	state.carriedBy[holder] = (state.carriedBy[holder] or 0) + amount
	state.carried += amount
	return true
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
