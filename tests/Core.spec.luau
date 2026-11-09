--!strict
local Achievements = require("../src/shared/Core/Achievements")
local Conditions = require("../src/shared/Core/Conditions")
local Flow = require("../src/shared/Core/Flow")
local Framing = require("../src/shared/Core/Framing")
local Graph = require("../src/shared/Core/Graph")
local Guide = require("../src/shared/Core/Guide")
local Layout = require("../src/shared/Core/Layout")
local Omens = require("../src/shared/Core/Omens")
local Party = require("../src/shared/Core/Party")
local Progress = require("../src/shared/Core/Progress")
local Puzzle = require("../src/shared/Core/Puzzle")
local RateLimit = require("../src/shared/Core/RateLimit")
local Registrar = require("../src/shared/Core/Registrar")
local Rng = require("../src/shared/Core/Rng")
local Seats = require("../src/shared/Core/Seats")
local Take = require("../src/shared/Core/Take")
local Tape = require("../src/shared/Core/Tape")
local WallSpans = require("../src/shared/Core/WallSpans")

local CONFIG: Registrar.Config = {
	jumpInterval = 10,
	silenceLead = 2,
	registerTime = 6,
	contactRadius = 10,
	reachTime = 1.5,
	graceAfterCut = 20,
}

local LIMITS: Tape.Limits =
	{ maxSamples = 130, sampleHz = 10, maxSpeed = 60, maxStartDistance = 14 }

local function hasEvent(events: { Registrar.Event }, kind: string): boolean
	for _, event in events do
		if event.kind == kind then
			return true
		end
	end
	return false
end

local function farPlayer(id: number): Registrar.PlayerInput
	return { id = id, x = 0, y = 0, z = 60, cut = false } -- in the foyer
end

return {
	["the first night is standard and later nights draw a repeatable condition"] = function()
		for seed = 1, 50 do
			assert(Conditions.forRun(seed, 0).id == "standard", "first visit must be standard")
		end
		local seen: { [string]: boolean } = {}
		for seed = 1, 200 do
			local a = Conditions.forRun(seed, 2)
			assert(a.id == Conditions.forRun(seed, 2).id, "same seed, same night")
			assert(a.id ~= "standard", "a later visit always changes something")
			assert(Conditions.byId(a.id).id == a.id, "clients must resolve the id")
			assert(a.tapeSeconds >= 6 and a.tapeSeconds <= 12, "tape length out of range")
			assert(a.jumpScale > 0.5 and a.lightScale > 0.3 and a.watcherScale >= 1)
			seen[a.id] = true
		end
		for _, condition in Conditions.all() do
			assert(seen[condition.id], `{condition.id} is never drawn`)
		end
		assert(Conditions.byId("nonsense").id == "standard")
		assert(Conditions.byId(nil).id == "standard")
	end,

	["guide walks a solo player through the hall in order"] = function()
		local f: Guide.Facts = {
			phase = "Protocol",
			pendingTags = {},
			pendingRows = {},
			reels = 0,
			tapesSaved = 0,
			latestWatched = false,
			tapesLeft = 3,
			code = {},
			codeLength = 3,
			dealt = 0,
		}
		local function key(): string
			return (Guide.step(f) :: Guide.Step).key
		end
		assert(key() == "step_film", "no tape yet: film")
		f.tapesSaved, f.tapesLeft = 1, 2
		assert(key() == "step_play", "unwatched tape: play it")
		f.latestWatched = true
		assert(key() == "step_film_more", "watched, nobody turned: film more")
		f.pendingRows = { "D" }
		assert(key() == "step_seat", "someone turned: go to the row")
		f.pendingRows, f.pendingTags = {}, { 17 }
		local coat = Guide.step(f) :: Guide.Step
		assert(coat.key == "step_coat" and coat.args[1] == "17", "a tag points at its coat")
		f.pendingTags, f.reels = {}, 1
		assert(key() == "step_more_reels", "one reel: keep filming")
		f.tapesLeft = 0
		assert(key() == "step_no_tape", "out of tape: fetch a cassette")
		f.pendingRows = { "K" }
		assert(key() == "step_seat", "a lead beats the empty camera")
	end,

	["guide reads the code as far as this player has seen it"] = function()
		local f: Guide.Facts = {
			phase = "Power",
			pendingTags = {},
			pendingRows = {},
			reels = 3,
			tapesSaved = 1,
			latestWatched = true,
			tapesLeft = 2,
			code = {},
			codeLength = 3,
			dealt = 3,
		}
		assert((Guide.step(f) :: Guide.Step).key == "step_code_find")
		f.code = { [1] = 4, [3] = 7 }
		assert((Guide.step(f) :: Guide.Step).key == "step_code_find", "one card still unread")
		f.code[2] = 0
		local enter = Guide.step(f) :: Guide.Step
		assert(enter.key == "step_code_enter" and enter.args[1] == "4 0 7", enter.args[1])
		f.dealt, f.code = 1, { [2] = 5 }
		local share = Guide.step(f) :: Guide.Step
		assert(share.key == "step_code_share" and share.args[1] == "_ 5 _", share.args[1])
	end,

	["guide covers the late phases and names the door's side"] = function()
		local f: Guide.Facts = {
			phase = "Projector",
			pendingTags = {},
			pendingRows = {},
			reels = 3,
			tapesSaved = 1,
			latestWatched = true,
			tapesLeft = 2,
			code = {},
			codeLength = 3,
			dealt = 3,
		}
		assert((Guide.step(f) :: Guide.Step).key == "step_order_find")
		f.order = "C - A - B"
		assert((Guide.step(f) :: Guide.Step).args[1] == "C - A - B")
		f.phase, f.doorSide = "Door", 1
		assert((Guide.step(f) :: Guide.Step).args[1] == "side_right")
		f.doorSide = -1
		assert((Guide.step(f) :: Guide.Step).args[1] == "side_left")
		f.phase = "Climax"
		local bell = Guide.step(f) :: Guide.Step
		assert(bell.key == "step_bell" and bell.nudgeAfter < Guide.NUDGE_AFTER)
		f.phase = "Done"
		assert(Guide.step(f) == nil and Guide.id(nil) == "")
	end,

	["seed gives the same sequence, different seeds differ"] = function()
		local a, b, c = Rng.new(7), Rng.new(7), Rng.new(8)
		local first = a:next()
		assert(first == b:next())
		assert(first ~= c:next())
	end,

	["rng.int stays inside inclusive bounds"] = function()
		local rng = Rng.new(99)
		local sawLow, sawHigh = false, false
		for _ = 1, 500 do
			local value = rng:int(1, 3)
			assert(value >= 1 and value <= 3)
			sawLow = sawLow or value == 1
			sawHigh = sawHigh or value == 3
		end
		assert(sawLow and sawHigh)
	end,

	["seat ids round-trip across the whole grid"] = function()
		for id = 1, Seats.TOTAL do
			local row, col = Seats.fromId(id)
			assert(Seats.id(row, col) == id)
		end
	end,

	["the final tape keeps four different seats free in row C"] = function()
		local seen = {}
		for index = 1, 4 do
			local id = Seats.castSeat(index)
			assert(Seats.isValidId(id))
			assert(Seats.fromId(id) == 3)
			assert(not seen[id])
			seen[id] = true
		end
	end,

	["seat labels read like a ticket"] = function()
		assert(Seats.label(1) == "A-01")
		assert(Seats.label(Seats.TOTAL) == "L-16")
	end,

	["every seat sits inside the hall and off the stage and aisle"] = function()
		for id = 1, Seats.TOTAL do
			local x, z = Seats.position(id)
			assert(x > Layout.HALL.minX and x < Layout.HALL.maxX, "seat outside hall x")
			assert(z > Layout.STAGE.maxZ and z < Layout.HALL.maxZ, "seat outside hall z")
			assert(math.abs(x) >= Seats.AISLE_HALF_WIDTH, "seat blocks the aisle")
		end
	end,

	["puzzle is reproducible from its seed and has unique hooks, one target per band"] = function()
		for seed = 1, 300 do
			local a, b = Puzzle.generate(seed), Puzzle.generate(seed)
			assert(#a.targets == Puzzle.TARGET_COUNT)
			local hooks = {}
			for index, target in a.targets do
				assert(target.seatId == b.targets[index].seatId)
				assert(target.hook >= 1 and target.hook <= Puzzle.HOOK_COUNT)
				assert(not hooks[target.hook], "two reels on one hook")
				hooks[target.hook] = true
				local row = Seats.fromId(target.seatId)
				assert(row > (index - 1) * 4 and row <= index * 4, "target left its band")
			end
			assert(a.doorSide == 1 or a.doorSide == -1)
		end
	end,

	["puzzle lookups find targets and refuse decoys"] = function()
		local puzzle = Puzzle.generate(5)
		local target = puzzle.targets[2]
		assert(Puzzle.targetAtSeat(puzzle, target.seatId) == target)
		assert(Puzzle.targetAtHook(puzzle, target.hook) == target)
		assert(Puzzle.targetAtHook(puzzle, 999) == nil)
	end,

	["code cards: solo sees every digit, a team must share them"] = function()
		local code = { 4, 0, 7 }
		local solo = Puzzle.dealCode(code, { 9 })
		assert(solo[9][1] == 4 and solo[9][2] == 0 and solo[9][3] == 7)
		local duo = Puzzle.dealCode(code, { 2, 1 })
		local seen = 0
		for position = 1, 3 do
			local inOne = duo[1][position] ~= nil
			local inTwo = duo[2][position] ~= nil
			assert(inOne ~= inTwo, "a digit went to both players or to neither")
			seen += 1
		end
		assert(seen == 3)
		assert(next(duo[1]) and next(duo[2]), "someone was dealt nothing")
		local four = Puzzle.dealCode(code, { 1, 2, 3, 4 })
		local total = 0
		for _, hand in four do
			for _ in hand do
				total += 1
			end
		end
		assert(total == 3, "digits lost or duplicated in a full team")
	end,

	["code entry must match exactly and survive junk"] = function()
		local code = { 4, 0, 7 }
		assert(Puzzle.codeMatches(code, { 4, 0, 7 }))
		assert(not Puzzle.codeMatches(code, { 4, 0, 8 }))
		assert(not Puzzle.codeMatches(code, { 4, 0 }))
		assert(not Puzzle.codeMatches(code, { 4, 0, 7, 1 }))
		assert(not Puzzle.codeMatches(code, "407"))
		assert(not Puzzle.codeMatches(code, { "4", "0", "7" }))
	end,

	["reel order is never plain A-B-C, and code digits are single"] = function()
		for seed = 1, 200 do
			local puzzle = Puzzle.generate(seed)
			assert(table.concat(puzzle.reelOrder) ~= "ABC")
			for _, digit in puzzle.code do
				assert(digit >= 0 and digit <= 9 and digit % 1 == 0)
			end
		end
	end,

	["a wrong reel empties the projector"] = function()
		local order = { "C", "A", "B" }
		local loaded, mistake = Puzzle.loadReel(order, 0, "C")
		assert(loaded == 1 and not mistake)
		loaded, mistake = Puzzle.loadReel(order, 1, "B")
		assert(loaded == 0 and mistake)
		loaded = Puzzle.loadReel(order, 0, "C")
		loaded = Puzzle.loadReel(order, loaded, "A")
		loaded, mistake = Puzzle.loadReel(order, loaded, "B")
		assert(loaded == 3 and not mistake)
	end,

	["achievements need a success and follow their own rules"] = function()
		local base: Achievements.Result = {
			success = true,
			replays = 2,
			playerReplays = 2,
			wasCut = false,
			docsThisRun = Achievements.TOTAL_DOCS_IN_MISSION,
			take = 3,
			teamSize = 1,
			seconds = 600,
		}
		local function has(list: { string }, id: string): boolean
			return table.find(list, id) ~= nil
		end
		local all = Achievements.earned(base)
		for _, id in
			{
				"first_meeting",
				"no_second_viewing",
				"never_cut",
				"paperwork",
				"second_take",
				"third_take",
				"alone",
				"quick_meeting",
			}
		do
			assert(has(all, id), `missing {id}`)
		end
		assert(not has(all, "full_team"))
		local failed = table.clone(base)
		failed.success = false
		assert(#Achievements.earned(failed) == 0, "a failed run earned something")
		local rough = table.clone(base)
		rough.replays, rough.wasCut, rough.take, rough.teamSize = 3, true, 1, 4
		local list = Achievements.earned(rough)
		assert(not has(list, "no_second_viewing") and not has(list, "never_cut"))
		assert(not has(list, "second_take") and has(list, "full_team"))
		for _, id in list do
			assert(table.find(Achievements.ALL, id), `{id} is not in the catalogue`)
		end
	end,

	["save: preferences take the latest choice and survive bad data"] = function()
		local cloud = Progress.default()
		cloud.prefs.frame = "paper"
		local session = Progress.default()
		session.prefs.frame = "amber"
		assert(Progress.commit(cloud, session, Progress.newDelta()).prefs.frame == "amber")
		local keep = Progress.commit(cloud, Progress.default(), Progress.newDelta())
		assert(keep.prefs.frame == "paper", "a session with no choice erased the old one")
		assert(Progress.migrate({ prefs = { frame = 5 } }).prefs.frame == nil)
	end,

	["flow refuses the ending until every step happened in order"] = function()
		local state = Flow.new()
		assert(not Flow.bellRung(state))
		assert(not Flow.reelFound(state), "reel before start")
		assert(Flow.begin(state))
		assert(not Flow.filmPlayed(state), "film before reels")
		assert(not Flow.registerRead(state))
		assert(Flow.reelFound(state) and Flow.reelFound(state))
		assert(state.phase == "Protocol")
		assert(Flow.reelFound(state))
		assert(state.phase == "Power")
		assert(not Flow.reelFound(state), "a fourth reel must be refused")
		assert(not Flow.filmPlayed(state), "no film without power")
		assert(Flow.powerRestored(state))
		assert(not Flow.powerRestored(state), "power can only come back once")
		assert(Flow.filmPlayed(state))
		assert(Flow.doorPassed(state))
		assert(not Flow.bellRung(state), "bell before register")
		assert(Flow.registerRead(state))
		assert(Flow.bellRung(state))
		assert(Flow.isOver(state))
		assert(not Flow.everyoneCut(state), "a finished mission cannot then fail")
	end,

	["point dead ahead is framed, behind and beyond range are not"] = function()
		local cos = math.cos(math.rad(30))
		assert(Framing.isFramed(0, 0, 0, 0, 0, -1, 0, 0, -10, cos, 50))
		assert(not Framing.isFramed(0, 0, 0, 0, 0, -1, 0, 0, 10, cos, 50))
		assert(not Framing.isFramed(0, 0, 0, 0, 0, -1, 0, 0, -51, cos, 50))
	end,

	["point exactly at max range is still framed"] = function()
		assert(Framing.isFramed(0, 0, 0, 0, 0, -1, 0, 0, -50, 0.5, 50))
	end,

	["the mission graph is symmetric and every node can reach every other"] = function()
		local graph = Layout.NODES
		for name, node in graph do
			for _, neighbour in node.edges do
				assert(graph[neighbour], `{name} points to missing {neighbour}`)
				assert(table.find(graph[neighbour].edges, name), `{name}->{neighbour} is one-way`)
			end
		end
		for name in graph do
			local seen, queue = { [name] = true }, { name }
			while #queue > 0 do
				local current = table.remove(queue) :: string
				for _, neighbour in graph[current].edges do
					if not seen[neighbour] then
						seen[neighbour] = true
						table.insert(queue, neighbour)
					end
				end
			end
			for other in graph do
				assert(seen[other], `{name} cannot reach {other}`)
			end
		end
	end,

	["graph step takes the shortest route"] = function()
		assert(Graph.nextStep(Layout.NODES, "archive", { aisleFront = true }) == "stage")
		assert(Graph.nextStep(Layout.NODES, "stage", { stage = true }) == "stage")
	end,

	["every take start node exists"] = function()
		for completions = 0, 5 do
			assert(Layout.NODES[Take.forCompletions(completions).registrarStart])
		end
	end,

	["omens are repeatable per player, differ between players, and run in time order"] = function()
		local a, again, other =
			Omens.schedule(11, 100), Omens.schedule(11, 100), Omens.schedule(11, 200)
		local differs = false
		for index, omen in a do
			assert(omen.at == again[index].at and omen.kind == again[index].kind)
			if index > 1 then
				assert(omen.at >= a[index - 1].at, "out of order")
			end
			if omen.at ~= other[index].at or omen.kind ~= other[index].kind then
				differs = true
			end
			if omen.seatId then
				assert(Seats.isValidId(omen.seatId), "omen targets a seat that does not exist")
			end
		end
		assert(differs, "two players got the identical hall")
	end,

	["unframed he warns before he jumps, and silence comes first"] = function()
		local state = Registrar.new("archive", CONFIG)
		local players = { farPlayer(1) }
		local events = Registrar.step(state, CONFIG, Layout.NODES, 8.5, {}, players, 1)
		assert(hasEvent(events, "preJump"))
		assert(not hasEvent(events, "jump"), "a jump needs its warning first")
		events = Registrar.step(state, CONFIG, Layout.NODES, 2, {}, players, 1)
		assert(hasEvent(events, "jump"))
		assert(state.node == "stage")
	end,

	["a faster pace cuts the running countdown at once, a slower one never stretches it"] = function()
		local state = Registrar.new("archive", CONFIG)
		local players = { farPlayer(1) }
		Registrar.step(state, CONFIG, Layout.NODES, 1, {}, players, 1.5)
		assert(state.timer == 9)
		Registrar.hasten(state, CONFIG, 0.45)
		assert(state.timer == 4.5)
		Registrar.hasten(state, CONFIG, 1.5)
		assert(state.timer == 4.5, "hasten must not give him more time")
		-- The cut countdown still warns before the jump.
		local events = Registrar.step(state, CONFIG, Layout.NODES, 2.6, {}, players, 0.45)
		assert(hasEvent(events, "preJump") and not hasEvent(events, "jump"))
		events = Registrar.step(state, CONFIG, Layout.NODES, 2, {}, players, 0.45)
		assert(hasEvent(events, "jump"))
	end,

	["framing him stops the clock but registers the watcher at the threshold"] = function()
		local state = Registrar.new("archive", CONFIG)
		local players = { farPlayer(1) }
		for _ = 1, 23 do
			local events = Registrar.step(state, CONFIG, Layout.NODES, 0.25, { 1 }, players, 1)
			assert(not hasEvent(events, "registered"), "registered too early")
			assert(not hasEvent(events, "jump"), "moved while framed")
		end
		assert(state.timer == CONFIG.jumpInterval)
		local events = Registrar.step(state, CONFIG, Layout.NODES, 0.25, { 1 }, players, 1)
		assert(hasEvent(events, "registered"))
	end,

	["a registered player is hunted ahead of a closer one"] = function()
		local state = Registrar.new("stage", CONFIG)
		state.registered[2] = true
		state.timer = 0.1
		state.warned = true
		local near = { id = 1, x = -33, y = 3, z = -32, cut = true }
		local players = {
			{ id = 3, x = 34, y = 0, z = -19, cut = false }, -- frontEast, 2 hops
			near,
			{ id = 2, x = 0, y = 0, z = 60, cut = false }, -- foyer, far but registered
		}
		Registrar.step(state, CONFIG, Layout.NODES, 0.25, {}, players, 1)
		-- Both routes pass through aisleFront, so verify via the target set on a later hop.
		assert(state.node == "aisleFront")
		state.timer, state.warned = 0.1, true
		Registrar.step(state, CONFIG, Layout.NODES, 0.25, {}, players, 1)
		assert(state.node == "aisleMid", "he chased the unregistered player")
	end,

	["contact gives a window, framing inside it saves the player"] = function()
		local state = Registrar.new("aisleMid", CONFIG)
		local victim = { { id = 1, x = 0, y = 0, z = 15, cut = false } }
		local events = Registrar.step(state, CONFIG, Layout.NODES, 0.25, {}, victim, 1)
		assert(hasEvent(events, "reach"))
		events = Registrar.step(state, CONFIG, Layout.NODES, 0.25, { 2 }, victim, 1)
		assert(hasEvent(events, "reachCancelled"))
		assert(state.reachId == nil)
	end,

	["contact window expiring cuts the player and sends him far away"] = function()
		local state = Registrar.new("aisleMid", CONFIG)
		local victim = { { id = 1, x = 0, y = 0, z = 15, cut = false } }
		Registrar.step(state, CONFIG, Layout.NODES, 0.25, {}, victim, 1)
		local events = Registrar.step(state, CONFIG, Layout.NODES, 1.5, {}, victim, 1)
		assert(hasEvent(events, "cut"))
		assert(state.node ~= "aisleMid")
		assert(state.timer == CONFIG.graceAfterCut)
	end,

	["outrunning the window cancels the cut"] = function()
		local state = Registrar.new("aisleMid", CONFIG)
		local victim = { { id = 1, x = 0, y = 0, z = 15, cut = false } }
		Registrar.step(state, CONFIG, Layout.NODES, 0.25, {}, victim, 1)
		victim[1].z = 40
		local events = Registrar.step(state, CONFIG, Layout.NODES, 0.25, {}, victim, 1)
		assert(hasEvent(events, "reachCancelled"))
		assert(not hasEvent(events, "cut"))
	end,

	["with everyone cut he stays where he is and makes no jump"] = function()
		local state = Registrar.new("stage", CONFIG)
		state.timer, state.warned = 0.1, true
		local events = Registrar.step(
			state,
			CONFIG,
			Layout.NODES,
			0.25,
			{},
			{ { id = 1, x = 0, y = 0, z = 60, cut = true } },
			1
		)
		assert(not hasEvent(events, "jump"))
		assert(state.node == "stage")
	end,

	["a replay pulls him one node toward the viewer"] = function()
		local state = Registrar.new("archive", CONFIG)
		local event = Registrar.onReplay(state, Layout.NODES, 0, 0, 60)
		assert(event and event.node == "stage")
		assert(state.node == "stage")
	end,

	["the first replay of a mission is free, later ones cost a step"] = function()
		assert(Registrar.replaySteps(1) == 0)
		assert(Registrar.replaySteps(2) == 1)
		assert(Registrar.replaySteps(9) == 1)
	end,

	["he stays out of tape replays until the second viewing, then closes in"] = function()
		assert(Tape.registrarDistance(1, 45, 13, 5) == nil)
		assert(Tape.registrarDistance(2, 45, 13, 5) == 45)
		assert(Tape.registrarDistance(3, 45, 13, 5) == 32)
		assert(Tape.registrarDistance(50, 45, 13, 5) == 5)
	end,

	["a valid track survives sanitising with its look vector normalised"] = function()
		local clean =
			Tape.sanitize({ { 0, 5, 0, 0, 0, -2 }, { 1, 5, 0, 0, 0, -1 } }, LIMITS, 0, 5, 0)
		-- A look of length 2 is out of tolerance and must be refused.
		assert(clean == nil)
		clean = Tape.sanitize({ { 0, 5, 0, 0, 0, -1.2 }, { 1, 5, 0, 0, 0, -1 } }, LIMITS, 0, 5, 0)
		assert(clean and clean[1][6] == -1)
	end,

	["hostile tracks are refused"] = function()
		local nan = 0 / 0
		local cases: { { any } } = {
			{ "hello", "not_table" },
			{ { { 0, 0, 0, 0, 0, -1 } }, "too_short" },
			{ { { 0, 0, 0, 0, 0, -1 }, "x" }, "bad_sample" },
			{ { { 0, 0, 0, 0, 0, -1 }, { nan, 0, 0, 0, 0, -1 } }, "bad_number" },
			{ { { 0, 0, 0, 0, 0, -1 }, { 0, 0, 0, 0, 0, 0 } }, "bad_look" },
			{ { { 900, 0, 0, 0, 0, -1 }, { 900, 0, 0, 0, 0, -1 } }, "far_start" },
			{ { { 0, 0, 0, 0, 0, -1 }, { 50, 0, 0, 0, 0, -1 } }, "too_fast" },
		}
		for _, case in cases do
			local clean, reason = Tape.sanitize(case[1], LIMITS, 0, 0, 0)
			assert(clean == nil, `{case[2]} was accepted`)
			assert(reason == case[2], `expected {case[2]}, got {reason}`)
		end
		local huge = table.create(LIMITS.maxSamples + 1, { 0, 0, 0, 0, 0, -1 })
		local _, reason = Tape.sanitize(huge, LIMITS, 0, 0, 0)
		assert(reason == "too_long")
	end,

	["sampling a tape blends between frames and holds the last one"] = function()
		local track = { { 0, 0, 0, 0, 0, -1 }, { 10, 0, 0, 0, 0, -1 } }
		assert(Tape.sampleAt(track, 0, 10)[1] == 0)
		assert(math.abs(Tape.sampleAt(track, 0.05, 10)[1] - 5) < 1e-9)
		assert(Tape.sampleAt(track, 99, 10)[1] == 10)
	end,

	["a tape reveals only the points it framed"] = function()
		local track = { { 0, 0, 0, 0, 0, -1 }, { 0, 0, 0, 0, 0, -1 } }
		local found = Tape.framedPoints(track, { { 0, 0, -10 }, { 0, 0, 10 } }, 0.8, 50)
		assert(#found == 1 and found[1] == 1)
	end,

	["party: fifth member is refused"] = function()
		local registry = Party.newRegistry()
		local party = assert(Party.create(registry, 1, "M001"))
		for user = 2, 4 do
			assert(Party.join(registry, user, party.id))
		end
		local ok, reason = Party.join(registry, 5, party.id)
		assert(not ok and reason == "party_full")
	end,

	["party: nobody is in two parties"] = function()
		local registry = Party.newRegistry()
		local first = assert(Party.create(registry, 1, "M001"))
		assert(Party.create(registry, 2, "M001"))
		local ok, reason = Party.join(registry, 2, first.id)
		assert(not ok and reason == "already_in_party")
	end,

	["party: leader leaving promotes, last one out deletes"] = function()
		local registry = Party.newRegistry()
		local party = assert(Party.create(registry, 1, "M001"))
		assert(Party.join(registry, 2, party.id))
		Party.leave(registry, 1)
		assert(party.leader == 2)
		Party.leave(registry, 2)
		assert(registry.parties[party.id] == nil)
		assert(registry.byUser[2] == nil)
	end,

	["party: only a ready party starts, and only by its leader"] = function()
		local registry = Party.newRegistry()
		local party = assert(Party.create(registry, 1, "M001"))
		assert(Party.join(registry, 2, party.id))
		Party.setReady(registry, 1, true)
		local ok, reason = Party.canStart(registry, 1)
		assert(not ok and reason == "not_all_ready")
		Party.setReady(registry, 2, true)
		ok, reason = Party.canStart(registry, 2)
		assert(not ok and reason == "not_leader")
		assert((Party.canStart(registry, 1)))
	end,

	["party: leaving or unreadying cancels a running countdown"] = function()
		local registry = Party.newRegistry()
		local party = assert(Party.create(registry, 1, "M001"))
		assert(Party.join(registry, 2, party.id))
		party.starting = true
		Party.setReady(registry, 2, false)
		assert(not party.starting)
		party.starting = true
		Party.leave(registry, 2)
		assert(not party.starting)
	end,

	["party: leader cannot kick themselves or a stranger"] = function()
		local registry = Party.newRegistry()
		local party = assert(Party.create(registry, 1, "M001"))
		assert(Party.join(registry, 2, party.id))
		assert(not (Party.kick(registry, 1, 1)))
		assert(not (Party.kick(registry, 1, 77)))
		assert(not (Party.kick(registry, 2, 1)), "member kicked the leader")
		assert((Party.kick(registry, 1, 2)))
		assert(#party.members == 1)
	end,

	["save race: a stale save from the other server cannot lose progress"] = function()
		-- The mission saved a completion and a doc while the hub still held old data.
		local cloud = Progress.default()
		cloud.docs.doc_register = true
		cloud.stats.completions = 1
		local staleHub = Progress.default()
		staleHub.flags.introDone = true
		local merged = Progress.commit(cloud, staleHub, Progress.newDelta())
		assert(merged.docs.doc_register, "stale hub erased a document")
		assert(merged.flags.introDone, "hub's own news was dropped")
		assert(merged.stats.completions == 1, "stale hub reset a counter")
	end,

	["save: counters add session deltas exactly once"] = function()
		local delta = Progress.newDelta()
		delta.replays = 3
		local cloud = Progress.default()
		cloud.stats.replays = 10
		local merged = Progress.commit(cloud, Progress.default(), delta)
		assert(merged.stats.replays == 13)
	end,

	["save: best time keeps the lower, and zero means no time yet"] = function()
		local cloud = Progress.default()
		local session = Progress.default()
		session.stats.bestTime = 900
		local merged = Progress.commit(cloud, session, Progress.newDelta())
		assert(merged.stats.bestTime == 900)
		session.stats.bestTime = 1200
		merged = Progress.commit(merged, session, Progress.newDelta())
		assert(merged.stats.bestTime == 900)
	end,

	["migrate survives garbage and keeps valid fields"] = function()
		assert(Progress.migrate("nonsense").v == Progress.VERSION)
		local data = Progress.migrate({
			docs = { a = true, b = "no", [3] = true },
			stats = { cuts = -5, replays = 4 },
		})
		assert(data.docs.a and not data.docs.b)
		assert(data.stats.cuts == 0, "negative stat accepted")
		assert(data.stats.replays == 4)
		assert(data.missions.M001, "first mission must always be available")
	end,

	["rate limit refuses past the burst and refills with time"] = function()
		local limit = RateLimit.new(2, 2)
		assert(limit:allow("p", 0))
		assert(limit:allow("p", 0))
		assert(not limit:allow("p", 0))
		assert(limit:allow("other", 0), "buckets must be per key")
		assert(limit:allow("p", 0.5))
		assert(not limit:allow("p", 0.5))
	end,

	["a door under a wider window stays open, and everything else stays solid"] = function()
		local rects = WallSpans.solve(-39, 39, 0, 24, { { -5, 5, 0, 10 }, { -14, 14, 16, 21 } })
		local function solidAt(a: number, y: number): boolean
			for _, rect in rects do
				if a > rect.fromA and a < rect.toA and y > rect.bottom and y < rect.top then
					return true
				end
			end
			return false
		end
		assert(not solidAt(0, 3), "door is walled up")
		assert(not solidAt(0, 18), "window over the door is walled up")
		assert(not solidAt(10, 18), "window beside the door is walled up")
		assert(solidAt(0, 13), "lintel between door and window is missing")
		assert(solidAt(10, 3), "wall beside the door is missing")
		assert(solidAt(0, 22), "wall above the window is missing")
		assert(solidAt(30, 12), "plain wall is missing")
	end,
}
