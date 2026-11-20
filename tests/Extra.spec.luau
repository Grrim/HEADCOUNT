--!strict
-- The Extra: lures, turns, freezes in frame, wears away from close by, never reaches the lift.
local Extra = require("../src/shared/Core/Extra")
local FloorGen = require("../src/shared/Core/FloorGen")
local Graph = require("../src/shared/Core/Graph")

local CONFIG: Extra.Config = {
	speed = 10,
	lureDistance = 20,
	lureSeconds = 12,
	touchRadius = 3,
	revealRange = 18,
	revealSeconds = 2,
	revealDecay = 0.5,
	graceAfterCut = 10,
}

-- Three rooms in a row along X, 36 studs apart, joined by doorways halfway between them.
local function corridor(): Graph.Graph
	return {
		r1 = { x = 0, y = 0, z = 0, edges = { "d12" } },
		d12 = { x = 18, y = 0, z = 0, edges = { "r1", "r2" } },
		r2 = { x = 36, y = 0, z = 0, edges = { "d12", "d23" } },
		d23 = { x = 54, y = 0, z = 0, edges = { "r2", "r3" } },
		r3 = { x = 72, y = 0, z = 0, edges = { "d23" } },
	}
end

local function player(id: number, x: number, z: number, safe: boolean?): Extra.PlayerInput
	return { id = id, x = x, z = z, cut = false, safe = safe == true }
end

local function has(events: { Extra.Event }, kind: string): Extra.Event?
	for _, event in events do
		if event.kind == kind then
			return event
		end
	end
	return nil
end

return {
	["in frame it does not move, even while it is closing in"] = function()
		local graph = corridor()
		local state = Extra.new(graph, "r1")
		state.phase = "close"
		state.target = 1
		local mark = player(1, 36, 0)
		for _ = 1, 20 do
			Extra.step(state, CONFIG, graph, 0.1, { mark }, { [1] = 36 })
		end
		assert(state.x == 0 and state.z == 0 and state.frozen, "it moved in frame")
	end,

	["held close in frame for two seconds, it is gone and the shot is credited"] = function()
		local graph = corridor()
		local state = Extra.new(graph, "r2")
		local revealed = nil
		for _ = 1, 25 do
			local events = Extra.step(state, CONFIG, graph, 0.1, { player(4, 46, 0) }, { [4] = 10 })
			revealed = revealed or has(events, "revealed")
		end
		assert(state.phase == "gone" and revealed and revealed.id == 4)
	end,

	["filmed from far away it only freezes"] = function()
		local graph = corridor()
		local state = Extra.new(graph, "r3")
		for _ = 1, 60 do
			Extra.step(state, CONFIG, graph, 0.1, { player(1, 0, 0) }, { [1] = 72 })
		end
		assert(state.phase ~= "gone" and state.reveal == 0)
	end,

	["after luring for a while it turns, walks over and cuts its mark"] = function()
		local graph = corridor()
		local state = Extra.new(graph, "r3")
		local mark = player(9, 2, 1)
		local turned, cut = false, false
		for _ = 1, 400 do
			local events = Extra.step(state, CONFIG, graph, 0.1, { mark }, {})
			turned = turned or has(events, "turned") ~= nil
			local hit = has(events, "cut")
			if hit then
				assert(hit.id == 9)
				cut = true
				break
			end
		end
		assert(turned and cut, "never turned on its mark")
		assert(state.rest == CONFIG.graceAfterCut and state.target == nil)
	end,

	["nobody in the lift is ever its mark"] = function()
		local graph = corridor()
		local state = Extra.new(graph, "r2")
		for _ = 1, 300 do
			local events = Extra.step(state, CONFIG, graph, 0.1, { player(1, 1, 0, true) }, {})
			assert(not has(events, "cut") and not has(events, "marked"))
		end
		assert(state.target == nil and state.x == 36, "it went for someone in the lift")
	end,

	["followed while luring, it backs away deeper into the floor"] = function()
		local graph = corridor()
		local state = Extra.new(graph, "r2")
		local mark = player(1, 30, 0)
		for _ = 1, 20 do
			Extra.step(state, CONFIG, graph, 0.1, { mark }, {})
		end
		assert(state.x > 36, `it stood its ground at x {state.x}`)
		assert(state.phase == "lure")
	end,

	["cornered at the end of the floor, it stops pretending"] = function()
		local graph = corridor()
		local state = Extra.new(graph, "r3")
		local events = Extra.step(state, CONFIG, graph, 0.1, { player(1, 66, 0) }, {})
		assert(has(events, "turned") and state.phase == "close")
	end,

	["on a real floor it walks the graph to a far mark and reaches them"] = function()
		for seed = 1, 10 do
			local floor = FloorGen.generate(seed, 3)
			local graph = FloorGen.graph(floor)
			local state = Extra.new(graph, FloorGen.registrarStart(floor))
			state.phase = "close"
			local x, z = FloorGen.roomCentre(floor, floor.start)
			local mark = player(1, x + 5, z + 4)
			local reached = false
			for _ = 1, 2000 do
				if has(Extra.step(state, CONFIG, graph, 0.1, { mark }, {}), "cut") then
					reached = true
					break
				end
				-- Never outside the floor: walking the graph keeps it inside the rooms.
				assert(FloorGen.roomAt(floor, state.x, state.z) ~= nil, "it left the floor")
			end
			assert(reached, `seed {seed}: never reached its mark`)
		end
	end,
}
