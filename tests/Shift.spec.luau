--!strict
-- The shift prototype: floors, the lift's state machine, scoring footage and upgrades.
local FloorGen = require("../src/shared/Core/FloorGen")
local Footage = require("../src/shared/Core/Footage")
local Graph = require("../src/shared/Core/Graph")
local Shift = require("../src/shared/Core/Shift")
local Upgrades = require("../src/shared/Core/Upgrades")

local function reachable(graph: Graph.Graph, from: string): number
	local seen = { [from] = true }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, edge in graph[current].edges do
			if not seen[edge] then
				seen[edge] = true
				table.insert(queue, edge)
			end
		end
	end
	local count = 0
	for _ in seen do
		count += 1
	end
	return count
end

local function count(graph: Graph.Graph): number
	local total = 0
	for _ in graph do
		total += 1
	end
	return total
end

return {
	["every room of every floor can be reached from the lift"] = function()
		for seed = 1, 40 do
			for depth = 1, 5 do
				local floor = FloorGen.generate(seed, depth)
				local graph = FloorGen.graph(floor)
				assert(
					reachable(graph, `r{floor.start}`) == count(graph),
					`seed {seed} depth {depth} has an unreachable room`
				)
			end
		end
	end,

	["floors have loops, so there is always a way round"] = function()
		for seed = 1, 40 do
			for depth = 1, 3 do
				local floor = FloorGen.generate(seed, depth)
				local rooms = floor.width * floor.height
				assert(#floor.links >= rooms, `seed {seed} depth {depth}: a tree has no loop`)
			end
		end
	end,

	["the same seed builds the same floor"] = function()
		local a = FloorGen.generate(1234, 2)
		local b = FloorGen.generate(1234, 2)
		assert(a.start == b.start and #a.links == #b.links and #a.spots == #b.spots)
		for index, link in a.links do
			assert(link.a == b.links[index].a and link.b == b.links[index].b)
		end
		for index, spot in a.spots do
			assert(spot.x == b.spots[index].x and spot.rarity == b.spots[index].rarity)
		end
	end,

	["the lift opens into the start room, which is on the south row at x 0"] = function()
		for seed = 1, 20 do
			local floor = FloorGen.generate(seed, 1)
			assert(floor.rooms[floor.start].cz == 0 and floor.rooms[floor.start].kind == "lobby")
			local x, z = FloorGen.roomCentre(floor, floor.start)
			assert(x == 0 and z == FloorGen.CELL / 2, `start room centre was {x}, {z}`)
		end
	end,

	["the lobby holds no anomalies and every other room holds one or two"] = function()
		local floor = FloorGen.generate(77, 3)
		local perRoom: { [number]: number } = {}
		for _, spot in floor.spots do
			assert(spot.room ~= floor.start, "an anomaly in the lobby")
			perRoom[spot.room] = (perRoom[spot.room] or 0) + 1
		end
		for id = 1, floor.width * floor.height do
			if id ~= floor.start then
				local n = perRoom[id] or 0
				assert(n >= 1 and n <= 2, `room {id} has {n}`)
			end
		end
	end,

	["no epic anomalies on the first floor; deeper floors have more rare ones"] = function()
		assert(FloorGen.rarity(1, 1) ~= "epic")
		assert(FloorGen.rarity(1, 3) == "epic")
		assert(FloorGen.rarity(30, 1) == "common" and FloorGen.rarity(30, 3) == "rare")
	end,

	["the Registrar starts as far from the lift as he can"] = function()
		local floor = FloorGen.generate(9, 2)
		local graph = FloorGen.graph(floor)
		local startNode = FloorGen.registrarStart(floor)
		assert(startNode ~= `r{floor.start}`)
		assert(Graph.farthest(graph, `r{floor.start}`) == startNode)
	end,

	["a shift: descend, film, descend again, come back up"] = function()
		local state = Shift.new(40)
		assert(Shift.descend(state) and state.phase == "ride" and state.depth == 1)
		assert(Shift.addFootage(state, 10) == 0, "nothing counts during the ride")
		Shift.arrive(state)
		assert(Shift.addFootage(state, 30) == 30)
		assert(Shift.descend(state) and state.banked == 30 and state.carried == 0)
		Shift.arrive(state)
		assert(Shift.addFootage(state, 10) == 15, "floor -2 pays x1.5")
		assert(Shift.ascend(state) and state.banked == 45)
		Shift.finish(state)
		assert(state.phase == "over" and state.result == "returned")
		assert(Shift.payout(state) == 45 and state.deepest == 2)
	end,

	["coming back short of the quota pays a quarter"] = function()
		local state = Shift.new(100)
		Shift.descend(state)
		Shift.arrive(state)
		Shift.addFootage(state, 40)
		Shift.ascend(state)
		Shift.finish(state)
		assert(Shift.payout(state) == 10)
	end,

	["losing everyone loses what was carried, not what was banked"] = function()
		local state = Shift.new(10)
		Shift.descend(state)
		Shift.arrive(state)
		Shift.addFootage(state, 40)
		Shift.descend(state)
		Shift.arrive(state)
		Shift.addFootage(state, 100)
		Shift.fail(state)
		assert(state.result == "cut" and state.carried == 0)
		assert(Shift.payout(state) == 10, "a quarter of the 40 banked")
	end,

	["the lift goes no deeper than the bottom floor"] = function()
		local state = Shift.new(10)
		for _ = 1, Shift.MAX_DEPTH do
			assert(Shift.descend(state))
			Shift.arrive(state)
		end
		assert(not Shift.descend(state) and state.depth == Shift.MAX_DEPTH)
	end,

	["holding a subject close and central earns five stars"] = function()
		local samples = {}
		for _ = 1, 30 do
			table.insert(samples, { 0, 0, 0, 0, 0, -1 })
		end
		local shots = Footage.score(samples, {
			{ id = 1, x = 0, y = 0, z = -10, value = 10 },
		}, 10, math.cos(math.rad(24)), 110)
		assert(#shots == 1 and shots[1].stars == 5 and shots[1].value == 10)
	end,

	["a glance is not a shot, and a far shot earns less"] = function()
		local glance = {}
		for _ = 1, 5 do
			table.insert(glance, { 0, 0, 0, 0, 0, -1 })
		end
		local target = { id = 1, x = 0, y = 0, z = -10, value = 10 }
		assert(#Footage.score(glance, { target }, 10, math.cos(math.rad(24)), 110) == 0)
		local far = {}
		for _ = 1, 30 do
			table.insert(far, { 0, 0, 0, 0, 0, -1 })
		end
		local farTarget = { id = 2, x = 0, y = 0, z = -60, value = 10 }
		local shots = Footage.score(far, { farTarget }, 10, math.cos(math.rad(24)), 110)
		assert(shots[1].stars == 3, `expected 3 stars, got {shots[1].stars}`)
	end,

	["something in the way spoils the shot"] = function()
		local samples = {}
		for _ = 1, 30 do
			table.insert(samples, { 0, 0, 0, 0, 0, -1 })
		end
		local shots = Footage.score(samples, {
			{ id = 1, x = 0, y = 0, z = -10, value = 10 },
		}, 10, math.cos(math.rad(24)), 110, function()
			return true
		end)
		assert(#shots == 0)
	end,

	["filming the same subject again only pays the improvement"] = function()
		local best = {}
		local gain = Footage.improve(best, { { id = 1, stars = 2, value = 4, seconds = 2, distance = 30 } })
		assert(gain == 4)
		gain = Footage.improve(best, { { id = 1, stars = 3, value = 6, seconds = 3, distance = 20 } })
		assert(gain == 2)
		gain = Footage.improve(best, { { id = 1, stars = 1, value = 2, seconds = 1, distance = 50 } })
		assert(gain == 0)
	end,

	["upgrades cost money, go up a level and stop at the top"] = function()
		local levels = {}
		assert(Upgrades.value(levels, "battery") == 30)
		local ok, money = Upgrades.buy(levels, 50, "battery")
		assert(not ok and money == 50, "too poor")
		ok, money = Upgrades.buy(levels, 100, "battery")
		assert(ok and money == 40 and Upgrades.value(levels, "battery") == 40)
		levels.battery = 4
		assert(Upgrades.nextCost(levels, "battery") == nil)
		ok = Upgrades.buy(levels, 9999, "battery")
		assert(not ok)
	end,
}
