--!strict
-- Mission 002 logic: the stand-in's replay buffer and the night bus's run.
local Route17 = require("../src/shared/Core/Route17")
local StandIn = require("../src/shared/Core/StandIn")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return {
	["the stand-in is the player half a minute late, and not before"] = function()
		local buffer = StandIn.new(30)
		for second = 0, 40 do
			StandIn.record(buffer, second, second, 0, 0, if second < 20 then 0 else 1)
		end
		assert(StandIn.at(buffer, 29.9) == nil, "no stand-in before the delay has passed")
		local ghost = StandIn.at(buffer, 35.5) :: StandIn.Sample
		assert(near(ghost.x, 5.5), `expected x 5.5, got {ghost.x}`)
		assert(
			StandIn.at(buffer, 49.4).yaw == 0 and StandIn.at(buffer, 50.6).yaw == 1,
			"turns snap"
		)
		-- Past the newest sample it holds the last known place.
		assert(near((StandIn.at(buffer, 80) :: StandIn.Sample).x, 40))
	end,

	["out-of-order samples are ignored"] = function()
		local buffer = StandIn.new(10)
		StandIn.record(buffer, 5, 1, 0, 0, 0)
		StandIn.record(buffer, 4, 99, 0, 0, 0)
		StandIn.record(buffer, 5, 99, 0, 0, 0)
		assert(#buffer.samples == 1 and buffer.samples[1].x == 1)
	end,

	["the stand-in presses what the player pressed, once, late"] = function()
		local buffer = StandIn.new(30)
		StandIn.act(buffer, 12, "stop")
		StandIn.act(buffer, 14, "validator")
		assert(#StandIn.actions(buffer, 40, 41.9) == 0, "too early")
		local first = StandIn.actions(buffer, 41.9, 42)
		assert(#first == 1 and first[1] == "stop", "the press at 12 comes back at 42")
		assert(#StandIn.actions(buffer, 42, 43.9) == 0, "and only once")
		assert(StandIn.actions(buffer, 43.9, 44.5)[1] == "validator")
	end,

	["history older than the delay plus the margin is dropped"] = function()
		local buffer = StandIn.new(10, 2)
		for second = 0, 100 do
			StandIn.record(buffer, second, second, 0, 0, 0)
		end
		StandIn.act(buffer, 50, "stop")
		StandIn.trim(buffer, 100)
		assert(#buffer.samples <= 14, `kept {#buffer.samples} samples`)
		assert(StandIn.at(buffer, 100) ~= nil, "the stand-in itself must survive trimming")
		assert(#buffer.actions == 0, "a press from 50 s ago is long done")
	end,

	["standing still lets your stand-in catch you"] = function()
		local buffer = StandIn.new(30)
		StandIn.record(buffer, 0, 0, 0, 0, 0)
		assert(not StandIn.catches(buffer, 20, 0, 0, 2), "no stand-in yet")
		-- Recorded as time passes, the way the server does it.
		for second = 1, 45 do
			StandIn.record(buffer, second, 0, 0, 0, 0)
		end
		assert(StandIn.catches(buffer, 45, 0, 0, 2), "still in the same place half a minute later")
		assert(not StandIn.catches(buffer, 45, 5, 0, 2), "a step aside is enough")
	end,

	["the night run is repeatable and keeps its own rules"] = function()
		for seed = 1, 300 do
			local run = Route17.generate(seed)
			local again = Route17.generate(seed)
			assert(run.itemStop == again.itemStop and run.emptySeat == again.emptySeat)
			assert(run.firstLap[1] == "depot" and run.firstLap[5] == "west_estate")
			assert(run.secondLap[1] == "depot" and run.secondLap[5] == "west_estate")
			local same = true
			for index = 1, 5 do
				same = same and run.firstLap[index] == run.secondLap[index]
			end
			assert(not same, `seed {seed}: second lap repeats the first`)
			assert(run.itemStop ~= "depot" and run.itemStop ~= "west_estate")
			assert(
				Route17.stopForTicket(run, run.ticketMinutes) == run.itemStop,
				"ticket points elsewhere"
			)
			assert(not table.find(Route17.DOOR_SEATS, run.emptySeat), "empty seat by a door")
			local previous = -1
			for _, stop in run.firstLap do
				assert(run.timetable[stop] > previous, "timetable goes backwards")
				previous = run.timetable[stop]
			end
		end
		assert(Route17.clock(Route17.DEPARTURE_MINUTES) == "23:17")
		assert(Route17.clock(24 * 60 + 5) == "00:05", "past midnight wraps")
	end,

	["stop and validator only count when pressed together"] = function()
		assert(Route17.inSync(10, 11.2))
		assert(not Route17.inSync(10, 12))
		assert(not Route17.inSync(10, nil))
	end,
}
