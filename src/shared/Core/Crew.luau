--!strict
-- The crew lift in the lobby (docs/09_GDD_V2.md §7, "dołącz do ekipy"), as plain data keyed by
-- UserId. Whoever stands in the cabin is aboard, in the order they stepped in. The first one in
-- starts the clock; the lift leaves when it is full, when the clock runs out, or when someone
-- aboard presses GO. Anyone who steps out is off, and an empty cabin stops the clock.
local Crew = {}

export type State = {
	members: { number },
	since: number?,
	capacity: number,
	wait: number,
	now: boolean,
	-- Who pressed GO: if they step out, the rest wait again.
	goBy: number?,
}

function Crew.new(capacity: number, wait: number): State
	return {
		members = {},
		since = nil,
		capacity = capacity,
		wait = wait,
		now = false,
		goBy = nil,
	}
end

-- Matches the cabin to who is in it. Returns who stood in it but did not fit.
function Crew.sync(state: State, inside: { number }, now: number): { number }
	local present: { [number]: boolean } = {}
	for _, id in inside do
		present[id] = true
	end
	local kept = {}
	local aboard: { [number]: boolean } = {}
	for _, id in state.members do
		if present[id] then
			table.insert(kept, id)
			aboard[id] = true
		end
	end
	local left = {}
	-- Newcomers in a fixed order, so two who step in together board the same way every time.
	local newcomers = {}
	for _, id in inside do
		if not aboard[id] then
			table.insert(newcomers, id)
			aboard[id] = true
		end
	end
	table.sort(newcomers)
	for _, id in newcomers do
		if #kept < state.capacity then
			table.insert(kept, id)
		else
			table.insert(left, id)
		end
	end
	state.members = kept
	if state.goBy and not table.find(kept, state.goBy) then
		state.now = false
		state.goBy = nil
	end
	if #kept == 0 then
		state.since = nil
		state.now = false
	elseif state.since == nil then
		state.since = now
	end
	return left
end

-- Seconds until it leaves on its own, or nil while it stands empty.
function Crew.secondsLeft(state: State, now: number): number?
	local since = state.since
	if not since then
		return nil
	end
	return math.max(0, state.wait - (now - since))
end

function Crew.due(state: State, now: number): boolean
	if #state.members == 0 then
		return false
	end
	if state.now or #state.members >= state.capacity then
		return true
	end
	local left = Crew.secondsLeft(state, now)
	return left ~= nil and left <= 0
end

-- Someone aboard does not want to wait. Returns whether they were aboard to ask.
function Crew.go(state: State, id: number): boolean
	if not table.find(state.members, id) then
		return false
	end
	state.now = true
	state.goBy = id
	return true
end

-- The lift leaves with everyone aboard and stands empty again.
function Crew.take(state: State): { number }
	local members = state.members
	state.members = {}
	state.since = nil
	state.now = false
	state.goBy = nil
	return members
end

return Crew
