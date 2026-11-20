--!strict
-- The shift prototype: floors, the lift's state machine, scoring footage and upgrades.
local FloorGen = require("../src/shared/Core/FloorGen")
local Footage = require("../src/shared/Core/Footage")
local Graph = require("../src/shared/Core/Graph")
local Highlight = require("../src/shared/Core/Highlight")
local Shift = require("../src/shared/Core/Shift")
local Upgrades = require("../src/shared/Core/Upgrades")
local Wallet = require("../src/shared/Core/Wallet")

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
		local vaultRoom = floor.vault and floor.vault.room
		for id = 1, floor.width * floor.height do
			if id ~= floor.start then
				local n = perRoom[id] or 0
				local most = if id == vaultRoom then 3 else 2
				assert(n >= 1 and n <= most, `room {id} has {n}`)
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
		local shots = Footage.score(
			samples,
			{
				{ id = 1, x = 0, y = 0, z = -10, value = 10 },
			},
			10,
			math.cos(math.rad(24)),
			110,
			function()
				return true
			end
		)
		assert(#shots == 0)
	end,

	["filming the same subject again only pays the improvement"] = function()
		local best = {}
		local gain =
			Footage.improve(best, { { id = 1, stars = 2, value = 4, seconds = 2, distance = 30 } })
		assert(gain == 4)
		gain =
			Footage.improve(best, { { id = 1, stars = 3, value = 6, seconds = 3, distance = 20 } })
		assert(gain == 2)
		gain =
			Footage.improve(best, { { id = 1, stars = 1, value = 2, seconds = 1, distance = 50 } })
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
	["a vault is a dead end off the lift's floor, never the lobby, never on floor -1"] = function()
		local vaults = 0
		for seed = 1, 60 do
			assert(FloorGen.generate(seed, 1).vault == nil, "a vault on the first floor")
			for depth = 2, 5 do
				local floor = FloorGen.generate(seed, depth)
				local vault = floor.vault
				if vault then
					vaults += 1
					assert(vault.room ~= floor.start, "the lobby locked")
					local doorways = 0
					for _, link in floor.links do
						if link.a == vault.room or link.b == vault.room then
							doorways += 1
						end
					end
					assert(doorways == 1, `vault room {vault.room} has {doorways} doorways`)
					local prize = false
					for _, spot in floor.spots do
						if spot.room == vault.room and spot.rarity ~= "common" then
							prize = true
						end
					end
					assert(prize, "a vault with nothing worth the code")
				end
			end
		end
		assert(vaults > 120, `only {vaults} vaults in 240 floors`)
	end,

	["locking the vault leaves every other room reachable from the lift"] = function()
		for seed = 1, 40 do
			for depth = 2, 5 do
				local floor = FloorGen.generate(seed, depth)
				local vault = floor.vault
				if vault then
					local open = FloorGen.openGraph(floor)
					assert(open[`r{vault.room}`] == nil, "the vault is open to walkers")
					assert(
						reachable(open, `r{floor.start}`) == count(open),
						`seed {seed} depth {depth}: the vault cut the floor in two`
					)
					assert(count(open) == count(FloorGen.graph(floor)) - 2)
				end
			end
		end
	end,

	["a point is placed in the room it stands in, and the lift is in none"] = function()
		local floor = FloorGen.generate(5, 2)
		for id = 1, floor.width * floor.height do
			local x, z = FloorGen.roomCentre(floor, id)
			assert(FloorGen.roomAt(floor, x, z) == id)
			assert(FloorGen.roomAt(floor, x + 17, z - 17) == id)
		end
		assert(FloorGen.roomAt(floor, 0, -6) == nil, "the lift counted as a room")
	end,

	["footage rides on the camera that shot it, and falls with it"] = function()
		local state = Shift.new(40)
		Shift.descend(state)
		Shift.arrive(state)
		assert(Shift.addFootage(state, 20, 1) == 20 and Shift.addFootage(state, 5, 2) == 5)
		assert(Shift.carriedOf(state, 1) == 20 and state.carried == 25)
		assert(Shift.drop(state, 1) == 20 and state.carried == 5)
		assert(Shift.drop(state, 1) == 0, "nothing left to drop")
		assert(Shift.pickUp(state, 2, 20) and Shift.carriedOf(state, 2) == 25)
		assert(state.carried == 25)
		assert(Shift.ascend(state) and state.banked == 25 and next(state.carriedBy) == nil)
	end,

	["a camera left on the floor is gone once the lift leaves"] = function()
		local state = Shift.new(10)
		Shift.descend(state)
		Shift.arrive(state)
		Shift.addFootage(state, 30, 7)
		local fallen = Shift.drop(state, 7)
		Shift.descend(state)
		assert(state.banked == 0, "the fallen footage was banked")
		assert(not Shift.pickUp(state, 3, fallen), "picked up during the ride")
	end,

	["something filmed in the lift counts on the ride, and only there"] = function()
		local state = Shift.new(10)
		Shift.descend(state)
		Shift.arrive(state)
		assert(Shift.addRideFootage(state, 50, 1) == 0, "a ride bonus on a floor")
		Shift.descend(state)
		assert(Shift.addRideFootage(state, 50, 1) == 75, "the ride to -2 pays x1.5")
		Shift.arrive(state)
		Shift.ascend(state)
		assert(Shift.addRideFootage(state, 10, 1) == 15)
		Shift.finish(state)
		assert(state.banked == 90, `banked {state.banked}`)
	end,

	["the tripod starts at nothing, and alone it costs less"] = function()
		local levels = {}
		assert(Upgrades.value(levels, "tripod") == 0, "everyone starts with a tripod")
		assert(Upgrades.nextCost(levels, "tripod") == 120)
		assert(Upgrades.nextCost(levels, "tripod", true) == 60)
		assert(Upgrades.nextCost(levels, "battery", true) == 60, "solo changed a battery price")
		local ok, money = Upgrades.buy(levels, 100, "tripod")
		assert(not ok and money == 100, "the team price was not charged")
		ok, money = Upgrades.buy(levels, 100, "tripod", true)
		assert(ok and money == 40 and Upgrades.value(levels, "tripod") == 12)
		levels.tripod = 4
		assert(
			Upgrades.value(levels, "tripod") == 30
				and Upgrades.nextCost(levels, "tripod", true) == nil
		)
	end,

	["a zoom lens rates a far shot as a nearer one"] = function()
		local samples = {}
		for _ = 1, 30 do
			table.insert(samples, { 0, 0, 0, 0, 0, -1 })
		end
		local target = { id = 1, x = 0, y = 0, z = -30, value = 10 }
		local bare = Footage.score(samples, { target }, 10, math.cos(math.rad(24)), 110)
		local zoomed = Footage.score(samples, { target }, 10, math.cos(math.rad(24)), 110, nil, 1.5)
		assert(bare[1].stars == 3 and zoomed[1].stars == 4, `{bare[1].stars} / {zoomed[1].stars}`)
		assert(zoomed[1].distance == 20)
	end,

	["every piece of kit costs something for what it gives"] = function()
		local levels = {}
		assert(Upgrades.value(levels, "lens") == 1 and Upgrades.value(levels, "night") == 0)
		assert(Upgrades.value(levels, "torch") == 40 and Upgrades.torchNotice(40) == 16)
		levels.torch = 4
		assert(
			Upgrades.torchNotice(Upgrades.value(levels, "torch")) == 25,
			"a bright torch went unseen"
		)
		assert(Upgrades.drain(0) == 1 and Upgrades.drain(3) == 1.3)
		levels.lens = 4
		assert(
			Upgrades.halfAngle(24, Upgrades.value(levels, "lens")) < 24,
			"zoom kept the wide frame"
		)
		assert(Upgrades.halfAngle(24, 0.5) == 24)
	end,

	["the shift tape keeps the eight seconds that held the subject longest"] = function()
		local samples = {}
		-- 5 s looking away, then 6 s at the subject, then 2 s away again.
		for index = 1, 130 do
			local on = index > 50 and index <= 110
			table.insert(samples, { 0, 0, 0, if on then 0 else 1, 0, if on then -1 else 0 })
		end
		local first, last =
			Highlight.window(samples, { x = 0, y = 0, z = -10 }, 10, 8, math.cos(math.rad(24)), 110)
		assert(last - first + 1 == 80, `window of {last - first + 1}`)
		assert(first <= 51 and last >= 110, `window {first}..{last} cut the shot`)
		local short = { { 0, 0, 0, 0, 0, -1 } }
		local a, b = Highlight.window(short, { x = 0, y = 0, z = -10 }, 10, 8, 0.9, 110)
		assert(a == 1 and b == 1)
	end,

	["a packed path comes back the same, and junk does not come back"] = function()
		local samples = { { 1.234, 5.678, -9.87, 0.123, -0.456, 0.789 }, { 2, 3, 4, 0, 0, -1 } }
		local back = Highlight.unpack(Highlight.pack(samples))
		assert(back and #back == 2)
		assert(math.abs(back[1][1] - 1.2) < 1e-9 and math.abs(back[1][5] + 0.46) < 1e-9)
		assert(Highlight.unpack({ 1, 2, 3 }) == nil and Highlight.unpack("x") == nil)
		assert(Highlight.unpack({ 0 / 0, 0, 0, 0, 0, 0 }) == nil)
		local long = {}
		for _ = 1, 200 do
			table.insert(long, { 0, 0, 0, 0, 0, -1 })
		end
		assert(#Highlight.pack(long) == Highlight.MAX_SAMPLES * 6, "a path ran past the limit")
	end,

	["the Archive keeps five tapes, trading its weakest for a better one"] = function()
		local data = Wallet.default()
		local function tape(stars: number, at: number): Wallet.Tape
			return {
				seed = 7,
				depth = 2,
				stars = stars,
				rarity = "rare",
				kind = "standing",
				by = "Ann",
				at = at,
				hz = 10,
				track = Highlight.pack({ { 0, 0, 0, 0, 0, -1 } }),
			}
		end
		for at = 1, 5 do
			assert(Wallet.saveTape(data, tape(if at == 3 then 2 else 4, at)))
		end
		local kept, why = Wallet.saveTape(data, tape(4, 1))
		assert(not kept and why == "kept", "the same tape was kept twice")
		kept, why = Wallet.saveTape(data, tape(2, 9))
		assert(not kept and why == "full")
		assert(Wallet.saveTape(data, tape(5, 10)))
		assert(#data.tapes == 5)
		for _, saved in data.tapes do
			assert(saved.stars >= 4, "the weakest tape stayed")
		end
		local stored = Wallet.migrate({ data = data }).data
		assert(#stored.tapes == 5 and stored.tapes[1].by == "Ann")
		local hostile =
			Wallet.migrate({ data = { tapes = { { seed = 1, depth = 99 }, "x" } } }).data
		assert(#hostile.tapes == 0)
	end,
}
