--!strict
-- Mission 002, "Route 17": the night bus's run as data. Which stops come in which order on each
-- lap, the timetable posted at the stops, the time printed on the team's ticket (which names the
-- stop where the next piece waits), and the empty seat among the passengers. Server only, like
-- Puzzle: a client that knew this would know the answers.
local Rng = require("./Rng")

local Route17 = {}

Route17.STOPS = { "depot", "jutrzenka", "hospital", "loop", "west_estate" }
-- The ones the bus can be asked to stop at for a piece; the first and last are fixed.
local MIDDLE = { "jutrzenka", "hospital", "loop" }
-- The team gets off only at the middle stops, for this long: the depot is the start and the
-- estate is the way out in the climax (docs/08_MISJA_002.md, decisions).
Route17.EXIT_STOPS = table.clone(MIDDLE)
Route17.EXIT_SECONDS = 90
-- Two coaches, nine rows each: eighteen seats, and the ones beside the three doors.
Route17.SEATS = 18
Route17.DOOR_SEATS = { 1, 2, 9, 10, 17, 18 }
Route17.PASSENGERS_FIRST_LAP = 17
-- Seconds within which the STOP button and the validator count as pressed together.
Route17.SYNC_WINDOW = 1.5
-- The run leaves the depot at 23:17, which is not in any city timetable.
Route17.DEPARTURE_MINUTES = 23 * 60 + 17

export type Run = {
	firstLap: { string },
	secondLap: { string },
	-- Minutes after midnight the bus is due at each stop, first lap.
	timetable: { [string]: number },
	itemStop: string,
	ticketMinutes: number,
	emptySeat: number,
}

function Route17.clock(minutes: number): string
	local wrapped = minutes % (24 * 60)
	return string.format("%02d:%02d", wrapped // 60, wrapped % 60)
end

local function isDoorSeat(seat: number): boolean
	return table.find(Route17.DOOR_SEATS, seat) ~= nil
end

function Route17.generate(seed: number): Run
	local rng = Rng.new(seed)
	local firstLap = table.clone(Route17.STOPS)
	local timetable: { [string]: number } = {}
	local minutes = Route17.DEPARTURE_MINUTES
	for index, stop in firstLap do
		if index > 1 then
			minutes += rng:int(3, 7)
		end
		timetable[stop] = minutes
	end
	-- The second lap shuffles the middle stops, and never back into the same order.
	local middle = table.clone(MIDDLE)
	for index = #middle, 2, -1 do
		local other = rng:int(1, index)
		middle[index], middle[other] = middle[other], middle[index]
	end
	if middle[1] == MIDDLE[1] and middle[2] == MIDDLE[2] then
		middle[1], middle[2], middle[3] = middle[2], middle[3], middle[1]
	end
	local secondLap = { "depot" }
	for _, stop in middle do
		table.insert(secondLap, stop)
	end
	table.insert(secondLap, "west_estate")
	local itemStop = MIDDLE[rng:int(1, #MIDDLE)]
	local emptySeat = rng:int(1, Route17.SEATS)
	while isDoorSeat(emptySeat) do
		emptySeat = emptySeat % Route17.SEATS + 1
	end
	return {
		firstLap = firstLap,
		secondLap = secondLap,
		timetable = timetable,
		itemStop = itemStop,
		ticketMinutes = timetable[itemStop],
		emptySeat = emptySeat,
	}
end

-- The stop a ticket's printed time points at, read off the posted timetable.
function Route17.stopForTicket(run: Run, minutes: number): string?
	for stop, due in run.timetable do
		if due == minutes then
			return stop
		end
	end
	return nil
end

function Route17.canExit(stop: string): boolean
	return table.find(Route17.EXIT_STOPS, stop) ~= nil
end

-- STOP and the validator, pressed by two people (or a person and their stand-in) together.
function Route17.inSync(a: number?, b: number?): boolean
	return a ~= nil and b ~= nil and math.abs(a - b) <= Route17.SYNC_WINDOW
end

return Route17
