--!strict
-- One floor of a shift, as data: a grid of rooms joined by doorways, with the lift on the south
-- side of the start room. A spanning tree keeps every room reachable and a few extra doorways
-- make loops, so a hunted player can run round instead of into a dead end. Same seed, same floor.
--
-- From floor -2 a dead-end room may be a vault: its one doorway holds a door with a code that only
-- shows on a tape, and inside waits an anomaly that is never a common one. Only a room with a
-- single doorway can be locked, so locking it never cuts the floor in two. The code is not part
-- of the floor: anyone can rebuild a floor from its seed, so the server draws the code apart.
--
-- Grid rows grow towards +Z. The start room is always in row 0 and its centre sits on x = 0, so
-- the lift, which never moves, always opens into it at z = 0.
local Graph = require("./Graph")
local Rng = require("./Rng")

local FloorGen = {}

FloorGen.CELL = 36
FloorGen.DOOR_WIDTH = 6
FloorGen.VAULT_FROM_DEPTH = 2

export type Room = { id: number, cx: number, cz: number, kind: string }
export type Link = { a: number, b: number }
export type Spot = {
	id: number,
	room: number,
	x: number,
	z: number,
	rarity: string,
	kind: string,
	-- The anomaly of the week (Core/Nights).
	weekly: boolean?,
}
export type Vault = { room: number, link: Link }
export type Floor = {
	depth: number,
	width: number,
	height: number,
	start: number,
	originX: number,
	originZ: number,
	rooms: { Room },
	links: { Link },
	spots: { Spot },
	vault: Vault?,
}

local KINDS = { "hall", "office", "storage", "cloakroom", "corridor" }
local KIND_FOR_RARITY = { common = "sitter", rare = "standing", epic = "watcher" }

local function sizeFor(depth: number): (number, number)
	if depth <= 1 then
		return 3, 2
	end
	return 3, 3
end

local function idOf(width: number, cx: number, cz: number): number
	return cz * width + cx + 1
end

local function linkKey(a: number, b: number): string
	return if a < b then `{a}-{b}` else `{b}-{a}`
end

-- Rarity by depth: deeper floors hide more of the good ones.
function FloorGen.rarity(roll: number, depth: number): string
	local epic = 4 * math.max(0, depth - 1)
	local rare = 18 + 6 * depth
	if roll <= epic then
		return "epic"
	elseif roll <= epic + rare then
		return "rare"
	end
	return "common"
end

-- `guided`: a first shift's floor (docs/09_GDD_V2.md §3), with one plain anomaly right in front of
-- the lift doors so a new player has something to film at once. It draws nothing from the
-- floor's random, so the rest of the floor is the same either way.
--
-- `weekly`: the anomaly of the week's kind (Core/Nights, §9). It may stand in one room of the
-- floor, drawn from its own random, so the rest of the floor is the same either way too.
function FloorGen.generate(seed: number, depth: number, guided: boolean?, weekly: string?): Floor
	local rng = Rng.new(seed * 977 + depth * 131 + 7)
	local width, height = sizeFor(depth)
	local startCx = rng:int(0, width - 1)
	local start = idOf(width, startCx, 0)

	local rooms: { Room } = {}
	for cz = 0, height - 1 do
		for cx = 0, width - 1 do
			local id = idOf(width, cx, cz)
			local kind = if id == start then "lobby" else KINDS[rng:int(1, #KINDS)]
			rooms[id] = { id = id, cx = cx, cz = cz, kind = kind }
		end
	end

	local function neighbours(id: number): { number }
		local room = rooms[id]
		local list = {}
		if room.cx > 0 then
			table.insert(list, id - 1)
		end
		if room.cx < width - 1 then
			table.insert(list, id + 1)
		end
		if room.cz > 0 then
			table.insert(list, id - width)
		end
		if room.cz < height - 1 then
			table.insert(list, id + width)
		end
		return list
	end

	-- Spanning tree: a depth-first walk that picks its next room at random.
	local links: { Link } = {}
	local linked: { [string]: boolean } = {}
	local visited: { [number]: boolean } = { [start] = true }
	local stack = { start }
	while #stack > 0 do
		local current = stack[#stack]
		local open = {}
		for _, other in neighbours(current) do
			if not visited[other] then
				table.insert(open, other)
			end
		end
		if #open == 0 then
			table.remove(stack)
		else
			local chosen = open[rng:int(1, #open)]
			visited[chosen] = true
			table.insert(links, { a = current, b = chosen })
			linked[linkKey(current, chosen)] = true
			table.insert(stack, chosen)
		end
	end

	-- Loops: a few doorways the tree did not need.
	local extra = if depth <= 1 then 1 else 2
	local attempts = 0
	while extra > 0 and attempts < 60 do
		attempts += 1
		local a = rng:int(1, width * height)
		local options = neighbours(a)
		local b = options[rng:int(1, #options)]
		if not linked[linkKey(a, b)] then
			linked[linkKey(a, b)] = true
			table.insert(links, { a = a, b = b })
			extra -= 1
		end
	end

	local originX = -(startCx + 0.5) * FloorGen.CELL
	local originZ = 0
	local spots: { Spot } = {}
	for id = 1, width * height do
		local room = rooms[id]
		if room.kind ~= "lobby" then
			local count = rng:int(1, 2)
			for _ = 1, count do
				local centreX = originX + (room.cx + 0.5) * FloorGen.CELL
				local centreZ = originZ + (room.cz + 0.5) * FloorGen.CELL
				local rarity = FloorGen.rarity(rng:int(1, 100), depth)
				table.insert(spots, {
					id = #spots + 1,
					room = id,
					x = centreX + rng:int(-10, 10),
					z = centreZ + rng:int(-10, 10),
					rarity = rarity,
					kind = KIND_FOR_RARITY[rarity],
				})
			end
		end
	end

	-- Drawn last, so the rest of a floor is the same whether or not it has a vault.
	local vault: Vault? = nil
	if depth >= FloorGen.VAULT_FROM_DEPTH then
		local leaves: { { id: number, link: Link } } = {}
		for id = 1, width * height do
			if id ~= start then
				local count, only = 0, nil
				for _, link in links do
					if link.a == id or link.b == id then
						count += 1
						only = link
					end
				end
				if count == 1 and only then
					table.insert(leaves, { id = id, link = only })
				end
			end
		end
		if #leaves > 0 then
			local pick = leaves[rng:int(1, #leaves)]
			local room = rooms[pick.id]
			local rarity = if rng:int(1, 100) <= 35 then "epic" else "rare"
			table.insert(spots, {
				id = #spots + 1,
				room = pick.id,
				x = originX + (room.cx + 0.5) * FloorGen.CELL + rng:int(-8, 8),
				z = originZ + (room.cz + 0.5) * FloorGen.CELL + rng:int(-8, 8),
				rarity = rarity,
				kind = KIND_FOR_RARITY[rarity],
			})
			vault = { room = pick.id, link = pick.link }
		end
	end

	if weekly then
		local weeklyRng = Rng.new(seed * 613 + depth * 37 + 3)
		if weeklyRng:int(1, 100) <= 60 then
			local options = {}
			for id = 1, width * height do
				if id ~= start and not (vault and vault.room == id) then
					table.insert(options, id)
				end
			end
			local id = options[weeklyRng:int(1, #options)]
			local room = rooms[id]
			local rarity = if weekly == "watcher"
				then "epic"
				elseif weekly == "standing" then "rare"
				else "common"
			table.insert(spots, {
				id = #spots + 1,
				room = id,
				x = originX + (room.cx + 0.5) * FloorGen.CELL + weeklyRng:int(-9, 9),
				z = originZ + (room.cz + 0.5) * FloorGen.CELL + weeklyRng:int(-9, 9),
				rarity = rarity,
				kind = weekly,
				weekly = true,
			})
		end
	end

	if guided then
		local x, z = originX + (startCx + 0.5) * FloorGen.CELL, originZ + 0.5 * FloorGen.CELL
		table.insert(spots, {
			id = #spots + 1,
			room = start,
			x = x + 5,
			z = z + 4,
			rarity = "common",
			kind = KIND_FOR_RARITY.common,
		})
	end

	return {
		depth = depth,
		width = width,
		height = height,
		start = start,
		originX = originX,
		originZ = originZ,
		rooms = rooms,
		links = links,
		spots = spots,
		vault = vault,
	}
end

-- The room a point stands in, or nil outside the floor (the lift is outside it).
function FloorGen.roomAt(floor: Floor, x: number, z: number): number?
	local cx = math.floor((x - floor.originX) / FloorGen.CELL)
	local cz = math.floor((z - floor.originZ) / FloorGen.CELL)
	if cx < 0 or cz < 0 or cx >= floor.width or cz >= floor.height then
		return nil
	end
	return cz * floor.width + cx + 1
end

function FloorGen.roomCentre(floor: Floor, id: number): (number, number)
	local room = floor.rooms[id]
	return floor.originX + (room.cx + 0.5) * FloorGen.CELL,
		floor.originZ + (room.cz + 0.5) * FloorGen.CELL
end

-- The middle of the doorway between two linked rooms, and whether the wall it cuts runs along X
-- (the rooms sit one behind the other in Z).
function FloorGen.doorway(floor: Floor, link: Link): (number, number, boolean)
	local ax, az = FloorGen.roomCentre(floor, link.a)
	local bx, bz = FloorGen.roomCentre(floor, link.b)
	return (ax + bx) / 2, (az + bz) / 2, ax == bx
end

function FloorGen.linked(floor: Floor, a: number, b: number): boolean
	for _, link in floor.links do
		if (link.a == a and link.b == b) or (link.a == b and link.b == a) then
			return true
		end
	end
	return false
end

-- The Registrar's graph: a node in every room and one in every doorway between them.
function FloorGen.graph(floor: Floor): Graph.Graph
	local graph: Graph.Graph = {}
	for id = 1, floor.width * floor.height do
		local x, z = FloorGen.roomCentre(floor, id)
		graph[`r{id}`] = { x = x, y = 0, z = z, edges = {} }
	end
	for _, link in floor.links do
		local name = `d{linkKey(link.a, link.b)}`
		local x, z = FloorGen.doorway(floor, link)
		graph[name] = { x = x, y = 0, z = z, edges = { `r{link.a}`, `r{link.b}` } }
		table.insert(graph[`r{link.a}`].edges, name)
		table.insert(graph[`r{link.b}`].edges, name)
	end
	return graph
end

-- The graph with the vault room and its locked doorway left out: where things that walk (the
-- Extra, the Usher) may go. The Registrar jumps, so he keeps the whole graph.
function FloorGen.openGraph(floor: Floor): Graph.Graph
	local graph = FloorGen.graph(floor)
	local vault = floor.vault
	if not vault then
		return graph
	end
	local blocked = {
		[`d{linkKey(vault.link.a, vault.link.b)}`] = true,
		[`r{vault.room}`] = true,
	}
	local open: Graph.Graph = {}
	for name, node in graph do
		if not blocked[name] then
			local edges = {}
			for _, edge in node.edges do
				if not blocked[edge] then
					table.insert(edges, edge)
				end
			end
			open[name] = { x = node.x, y = node.y, z = node.z, edges = edges }
		end
	end
	return open
end

-- Where the Registrar starts a floor: as far from the lift as the building allows.
function FloorGen.registrarStart(floor: Floor): string
	return Graph.farthest(FloorGen.graph(floor), `r{floor.start}`)
end

return FloorGen
