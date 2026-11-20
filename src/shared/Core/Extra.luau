--!strict
-- The rules of the Extra ("Statysta"), with no Instances (docs/09_GDD_V2.md §2.3). It wears the
-- look of someone on the team (alone, your own) and never speaks. To the eye it is a teammate
-- waving you on; the lens shows what it really is.
--
--   lure    it picks a mark and stays a little ahead of them, beckoning. Follow it and it backs
--           away, deeper into the floor. Fall behind and it comes back into view.
--   close   after a while, or once it runs out of floor to back into, it turns and walks at its
--           mark. If it touches them they are cut out of frame.
--   gone    held in someone's frame from close by for long enough, it freezes and is gone.
--
-- One rule it shares with the Registrar, so the game stays learnable: while any working lens
-- frames it, it does not move. Players in the lift or already cut are never its mark.
--
-- It walks the floor's graph (Core/FloorGen.graph): along the edges between rooms and doorways,
-- and straight at its mark only inside the room they share, so it never walks through a wall.
local Graph = require("./Graph")

local Extra = {}

export type Config = {
	-- Walking speed, studs per second.
	speed: number,
	-- How far ahead of its mark it likes to stand while luring.
	lureDistance: number,
	-- How long it leads a mark on before it turns on them.
	lureSeconds: number,
	-- Touching distance: closer than this and the mark is cut.
	touchRadius: number,
	-- A lens nearer than this, holding it in frame, wears it away...
	revealRange: number,
	-- ...in this many seconds.
	revealSeconds: number,
	-- Reveal progress lost per second while nobody holds it from close by.
	revealDecay: number,
	-- After a cut it stands still this long before it picks a new mark.
	graceAfterCut: number,
}

-- safe: in the lift, where it never reaches.
export type PlayerInput = { id: number, x: number, z: number, cut: boolean, safe: boolean }
export type Event = { kind: string, id: number? }

export type State = {
	phase: string,
	-- The last node it stood on, and the node it is walking to (the same when standing on one).
	node: string,
	nextNode: string,
	-- True when it has stepped off `node` to walk straight at its mark inside that room.
	offNode: boolean,
	x: number,
	z: number,
	target: number?,
	lureTime: number,
	reveal: number,
	rest: number,
	frozen: boolean,
	beckoning: boolean,
	moving: boolean,
}

local ARRIVE = 0.05

function Extra.new(graph: Graph.Graph, node: string, rest: number?): State
	local at = graph[node]
	return {
		phase = "lure",
		node = node,
		nextNode = node,
		offNode = false,
		x = at.x,
		z = at.z,
		target = nil,
		lureTime = 0,
		reveal = 0,
		rest = rest or 0,
		frozen = false,
		beckoning = false,
		moving = false,
	}
end

local function distance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- Moves toward a point by at most `step`; returns whether it got there.
local function moveTo(state: State, x: number, z: number, step: number): boolean
	local gap = distance(state.x, state.z, x, z)
	if gap <= step + ARRIVE then
		state.x, state.z = x, z
		return true
	end
	state.x += (x - state.x) / gap * step
	state.z += (z - state.z) / gap * step
	state.moving = true
	return false
end

-- One step of walking along the graph toward `goal`. A walk already under way between two nodes
-- is finished before a new one is chosen, so it never cuts across a wall.
local function walkGraph(state: State, graph: Graph.Graph, goal: string, step: number)
	if state.offNode then
		local home = graph[state.node]
		if moveTo(state, home.x, home.z, step) then
			state.offNode = false
		end
		return
	end
	if state.nextNode == state.node then
		state.nextNode = Graph.nextStep(graph, state.node, { [goal] = true })
		if state.nextNode == state.node then
			return
		end
	end
	local next = graph[state.nextNode]
	if moveTo(state, next.x, next.z, step) then
		state.node = state.nextNode
	end
end

local function nodeOf(graph: Graph.Graph, x: number, z: number): string
	return Graph.nearest(graph, x, 0, z)
end

-- Walks at the mark: straight at them when they are in the room it stands in, by the graph else.
local function approach(state: State, graph: Graph.Graph, mark: PlayerInput, step: number)
	local markNode = nodeOf(graph, mark.x, mark.z)
	local standing = state.nextNode == state.node
	if standing and markNode == state.node and string.sub(state.node, 1, 1) == "r" then
		state.offNode = true
		moveTo(state, mark.x, mark.z, step)
		return
	end
	walkGraph(state, graph, markNode, step)
end

-- The neighbour that takes it furthest from its mark: further than where it stands, and away
-- from them, never past them.
local function retreatNode(state: State, graph: Graph.Graph, mark: PlayerInput): string?
	local here = graph[state.node]
	local awayX, awayZ = here.x - mark.x, here.z - mark.z
	local best, bestDistance = nil, distance(here.x, here.z, mark.x, mark.z)
	local edges = table.clone(here.edges)
	table.sort(edges)
	for _, name in edges do
		local node = graph[name]
		local gap = distance(node.x, node.z, mark.x, mark.z)
		local outward = (node.x - here.x) * awayX + (node.z - here.z) * awayZ > 0
		if outward and gap > bestDistance + 1 then
			best, bestDistance = name, gap
		end
	end
	return best
end

local function eligible(player: PlayerInput): boolean
	return not player.cut and not player.safe
end

-- framers: the players whose working lens holds it in frame, and how far away each one is.
function Extra.step(
	state: State,
	config: Config,
	graph: Graph.Graph,
	dt: number,
	players: { PlayerInput },
	framers: { [number]: number }
): { Event }
	local events: { Event } = {}
	state.moving = false
	state.beckoning = false
	if state.phase == "gone" then
		return events
	end

	-- In frame: it does not move, and from close by the frame wears it away.
	local closest, closestDistance = nil, math.huge
	local ids = {}
	for id in framers do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		if framers[id] < closestDistance then
			closest, closestDistance = id, framers[id]
		end
	end
	state.frozen = closest ~= nil
	if closest then
		if closestDistance <= config.revealRange then
			state.reveal += dt
			if state.reveal >= config.revealSeconds then
				state.phase = "gone"
				table.insert(events, { kind = "revealed", id = closest })
			end
		end
		return events
	end
	state.reveal = math.max(0, state.reveal - config.revealDecay * dt)

	if state.rest > 0 then
		state.rest = math.max(0, state.rest - dt)
		return events
	end

	-- Its mark: keep the one it has while it can be reached, else the nearest who can.
	local mark: PlayerInput? = nil
	for _, player in players do
		if player.id == state.target and eligible(player) then
			mark = player
		end
	end
	if not mark then
		local best = math.huge
		for _, player in players do
			if eligible(player) then
				local gap = distance(state.x, state.z, player.x, player.z)
				if gap < best then
					mark, best = player, gap
				end
			end
		end
		if not mark then
			state.target = nil
			return events
		end
		state.target = mark.id
		state.phase = "lure"
		state.lureTime = 0
		table.insert(events, { kind = "marked", id = mark.id })
	end
	local current = mark :: PlayerInput
	local step = config.speed * dt
	local gap = distance(state.x, state.z, current.x, current.z)

	if state.phase == "lure" then
		state.lureTime += dt
		local turn = state.lureTime >= config.lureSeconds
		if not turn and gap < config.lureDistance * 0.6 then
			-- Followed: back away, deeper in. With nowhere left to back into, it turns.
			if state.offNode or state.nextNode ~= state.node then
				walkGraph(state, graph, state.nextNode, step)
			else
				local away = retreatNode(state, graph, current)
				if away then
					walkGraph(state, graph, away, step)
				else
					turn = true
				end
			end
		elseif not turn and gap > config.lureDistance * 1.6 then
			approach(state, graph, current, step)
		elseif not turn then
			state.beckoning = true
		end
		if turn then
			state.phase = "close"
			table.insert(events, { kind = "turned", id = current.id })
		end
		return events
	end

	-- Closing in.
	approach(state, graph, current, step)
	if distance(state.x, state.z, current.x, current.z) <= config.touchRadius then
		table.insert(events, { kind = "cut", id = current.id })
		state.target = nil
		state.phase = "lure"
		state.lureTime = 0
		state.rest = config.graceAfterCut
	end
	return events
end

return Extra
