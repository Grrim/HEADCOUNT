--!strict
-- The rules of the Registrar ("Kadrowy"), with no Instances:
--   * framed by a lens: he freezes, but whoever watches him is slowly registered
--   * unframed: a timer runs; silence warns before he cuts one node closer
--   * a player inside his radius gets a short window to frame him or be cut out
--   * each tape replay pulls him one node toward the viewer
-- Fairness rules, so a cut is always something the player could have stopped:
--   * he only reaches for someone who can see where he stands (line of sight to his anchor)
--   * after arriving anywhere he waits a moment before reaching, even after an unsignalled pull
--   * watching him costs exposure, but it drains away again while nobody watches
--   * a player stuck in a tape gets extra time to look up and frame him
local Graph = require("./Graph")

local Registrar = {}

export type Config = {
	jumpInterval: number,
	silenceLead: number,
	registerTime: number,
	contactRadius: number,
	reachTime: number,
	graceAfterCut: number,
	-- Seconds after any arrival before he may reach. Optional, 0 when absent.
	arrivalGrace: number?,
	-- Exposure lost per second while nobody frames him. Optional, 0 when absent.
	exposureDecay: number?,
}

-- sees: false when a wall stands between the player and him (nil counts as seeing).
-- reachBonus: extra seconds of warning for this player, such as one watching a tape.
export type PlayerInput = {
	id: number,
	x: number,
	y: number,
	z: number,
	cut: boolean,
	sees: boolean?,
	reachBonus: number?,
}

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
	-- Seconds left before he may reach after arriving at his node.
	settle: number,
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
		settle = 0,
	}
end

-- Any move, signalled or not, starts the settle time.
function Registrar.arrived(state: State, config: Config)
	state.settle = config.arrivalGrace or 0
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

-- A faster pace takes effect at once: the countdown already running is cut to the new interval,
-- never lengthened. Without this the first jump after the change still comes at the old pace.
function Registrar.hasten(state: State, config: Config, scale: number)
	state.timer = math.min(state.timer, config.jumpInterval * scale)
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

	state.settle = math.max(0, state.settle - dt)
	local decay = config.exposureDecay or 0
	if decay > 0 then
		local watching = {}
		for _, id in framedBy do
			watching[id] = true
		end
		for id, exposure in state.exposure do
			if not watching[id] and not state.registered[id] then
				state.exposure[id] = math.max(0, exposure - decay * dt)
			end
		end
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

	if state.settle <= 0 then
		for _, player in players do
			if
				not player.cut
				and player.sees ~= false
				and distanceTo(graph, state.node, player) <= config.contactRadius
			then
				state.reachId = player.id
				state.reachLeft = config.reachTime + (player.reachBonus or 0)
				table.insert(events, { kind = "reach", id = player.id })
				return events
			end
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
			Registrar.arrived(state, config)
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
	viewerZ: number,
	config: Config?
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
	if config then
		Registrar.arrived(state, config)
	end
	return { kind = "jump", node = nextNode }
end

-- The first replay of a mission is free, so players see what a tape shows before paying for it.
function Registrar.replaySteps(totalReplaysInMission: number): number
	return if totalReplaysInMission <= 1 then 0 else 1
end

return Registrar
