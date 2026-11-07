--!strict
-- The rules of the Registrar ("Kadrowy"), with no Instances:
--   * framed by a lens: he freezes, but whoever watches him is slowly registered
--   * unframed: a timer runs; silence warns before he cuts one node closer
--   * a player inside his radius gets a short window to frame him or be cut out
--   * each tape replay pulls him one node toward the viewer
local Graph = require("./Graph")

local Registrar = {}

export type Config = {
	jumpInterval: number,
	silenceLead: number,
	registerTime: number,
	contactRadius: number,
	reachTime: number,
	graceAfterCut: number,
}

export type PlayerInput = { id: number, x: number, y: number, z: number, cut: boolean }

export type Event = { kind: string, id: number?, node: string? }

export type State = {
	node: string,
	timer: number,
	warned: boolean,
	exposure: { [number]: number },
	registered: { [number]: boolean },
	reachId: number?,
	reachLeft: number,
	dormant: boolean,
}

function Registrar.new(startNode: string, config: Config): State
	return {
		node = startNode,
		timer = config.jumpInterval,
		warned = false,
		exposure = {},
		registered = {},
		reachId = nil,
		reachLeft = 0,
		dormant = false,
	}
end

local function targetsFor(
	state: State,
	graph: Graph.Graph,
	players: { PlayerInput }
): { [string]: boolean }
	local registered, everyone = {}, {}
	local anyRegistered = false
	for _, player in players do
		if not player.cut then
			local name = Graph.nearest(graph, player.x, player.y, player.z)
			everyone[name] = true
			if state.registered[player.id] then
				registered[name] = true
				anyRegistered = true
			end
		end
	end
	return if anyRegistered then registered else everyone
end

local function distanceTo(graph: Graph.Graph, node: string, player: PlayerInput): number
	local position = graph[node]
	local dx, dy, dz = position.x - player.x, position.y - player.y, position.z - player.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function resetTimer(state: State, config: Config, scale: number)
	state.timer = config.jumpInterval * scale
	state.warned = false
end

-- Advances the rules by dt and returns what happened, for the service to act on.
function Registrar.step(
	state: State,
	config: Config,
	graph: Graph.Graph,
	dt: number,
	framedBy: { number },
	players: { PlayerInput },
	scale: number
): { Event }
	local events: { Event } = {}
	if state.dormant then
		return events
	end

	if #framedBy > 0 then
		-- Watching holds him still, but it costs the watcher. Shared watching splits nothing:
		-- each watcher accumulates separately, which is why teams should take turns.
		for _, id in framedBy do
			local exposure = (state.exposure[id] or 0) + dt
			state.exposure[id] = exposure
			if exposure >= config.registerTime and not state.registered[id] then
				state.registered[id] = true
				table.insert(events, { kind = "registered", id = id })
			end
		end
		if state.reachId then
			table.insert(events, { kind = "reachCancelled", id = state.reachId })
			state.reachId = nil
		end
		return events
	end

	if state.reachId then
		local victim: PlayerInput? = nil
		for _, player in players do
			if player.id == state.reachId and not player.cut then
				victim = player
			end
		end
		if victim == nil or distanceTo(graph, state.node, victim) > config.contactRadius * 1.5 then
			table.insert(events, { kind = "reachCancelled", id = state.reachId })
			state.reachId = nil
		else
			state.reachLeft -= dt
			if state.reachLeft <= 0 then
				table.insert(events, { kind = "cut", id = state.reachId })
				state.reachId = nil
				state.registered[victim.id] = nil
				state.exposure[victim.id] = 0
				state.node = Graph.farthest(graph, state.node)
				state.timer = config.graceAfterCut
				state.warned = false
				table.insert(events, { kind = "retreat", node = state.node })
			end
		end
		return events
	end

	for _, player in players do
		if not player.cut and distanceTo(graph, state.node, player) <= config.contactRadius then
			state.reachId = player.id
			state.reachLeft = config.reachTime
			table.insert(events, { kind = "reach", id = player.id })
			return events
		end
	end

	state.timer -= dt
	if state.timer <= config.silenceLead and not state.warned then
		state.warned = true
		table.insert(events, { kind = "preJump" })
	end
	if state.timer <= 0 then
		local nextNode = Graph.nextStep(graph, state.node, targetsFor(state, graph, players))
		resetTimer(state, config, scale)
		-- With nobody left to hunt he simply stays put, and stays silent about it.
		if nextNode ~= state.node then
			state.node = nextNode
			table.insert(events, { kind = "jump", node = nextNode })
		end
	end
	return events
end

-- The core rule of the game: watching a tape brings him closer to whoever watched it.
function Registrar.onReplay(
	state: State,
	graph: Graph.Graph,
	viewerX: number,
	viewerY: number,
	viewerZ: number
): Event?
	if state.dormant then
		return nil
	end
	local target = Graph.nearest(graph, viewerX, viewerY, viewerZ)
	local nextNode = Graph.nextStep(graph, state.node, { [target] = true })
	if nextNode == state.node then
		return nil
	end
	state.node = nextNode
	return { kind = "jump", node = nextNode }
end

-- The first replay of a mission is free, so players see what a tape shows before paying for it.
function Registrar.replaySteps(totalReplaysInMission: number): number
	return if totalReplaysInMission <= 1 then 0 else 1
end

return Registrar
