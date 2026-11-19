--!strict
-- One floor of a shift, as data: a grid of rooms joined by doorways, with the lift on the south
-- side of the start room. A spanning tree keeps every room reachable and a few extra doorways
-- make loops, so a hunted player can run round instead of into a dead end. Same seed, same floor.
--
-- Grid rows grow towards +Z. The start room is always in row 0 and its centre sits on x = 0, so
-- the lift, which never moves, always opens into it at z = 0.
local Graph = require("./Graph")
local Rng = require("./Rng")

local FloorGen = {}

FloorGen.CELL = 36
FloorGen.DOOR_WIDTH = 6

export type Room = { id: number, cx: number, cz: number, kind: string }
export type Link = { a: number, b: number }
export type Spot = {
	id: number,
	room: number,
	x: number,
	z: number,
	rarity: string,
	kind: string,
}
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

function FloorGen.generate(seed: number, depth: number): Floor
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
	}
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

-- Where the Registrar starts a floor: as far from the lift as the building allows.
function FloorGen.registrarStart(floor: Floor): string
	return Graph.farthest(FloorGen.graph(floor), `r{floor.start}`)
end

return FloorGen
