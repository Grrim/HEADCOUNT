--!strict
-- The mission's state machine. An action that does not fit the current phase is refused, so a
-- client cannot reach the ending by triggering prompts out of order.
local Flow = {}

export type Phase =
	"Waiting"
	| "Protocol"
	| "Power"
	| "Projector"
	| "Door"
	| "Register"
	| "Climax"
	| "Done"
	| "Failed"

export type State = { phase: Phase, reels: number }

Flow.REELS_NEEDED = 3

local OBJECTIVES: { [Phase]: string } = {
	Waiting = "obj_waiting",
	Protocol = "obj_protocol",
	Power = "obj_power",
	Projector = "obj_projector",
	Door = "obj_door",
	Register = "obj_register",
	Climax = "obj_bell",
	Done = "obj_done",
	Failed = "obj_failed",
}

function Flow.new(): State
	return { phase = "Waiting", reels = 0 }
end

function Flow.objective(state: State): string
	return OBJECTIVES[state.phase]
end

function Flow.isOver(state: State): boolean
	return state.phase == "Done" or state.phase == "Failed"
end

-- Each returns true when the event was accepted and the state changed.
function Flow.begin(state: State): boolean
	if state.phase ~= "Waiting" then
		return false
	end
	state.phase = "Protocol"
	return true
end

-- The last reel takes the power with it: the building goes dark until the breaker is reset.
function Flow.reelFound(state: State): boolean
	if state.phase ~= "Protocol" then
		return false
	end
	state.reels += 1
	if state.reels >= Flow.REELS_NEEDED then
		state.phase = "Power"
	end
	return true
end

function Flow.powerRestored(state: State): boolean
	if state.phase ~= "Power" then
		return false
	end
	state.phase = "Projector"
	return true
end

function Flow.filmPlayed(state: State): boolean
	if state.phase ~= "Projector" then
		return false
	end
	state.phase = "Door"
	return true
end

-- The door has been passed and the register sits within reach.
function Flow.doorPassed(state: State): boolean
	if state.phase ~= "Door" then
		return false
	end
	state.phase = "Register"
	return true
end

function Flow.registerRead(state: State): boolean
	if state.phase ~= "Register" then
		return false
	end
	state.phase = "Climax"
	return true
end

function Flow.bellRung(state: State): boolean
	if state.phase ~= "Climax" then
		return false
	end
	state.phase = "Done"
	return true
end

function Flow.everyoneCut(state: State): boolean
	if Flow.isOver(state) or state.phase == "Waiting" then
		return false
	end
	state.phase = "Failed"
	return true
end

return Flow
