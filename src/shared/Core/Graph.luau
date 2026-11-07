--!strict
-- A small node graph. The Registrar never walks, it cuts from node to node, so this replaces
-- pathfinding entirely and stays predictable.
local Graph = {}

export type Node = { x: number, y: number, z: number, edges: { string } }
export type Graph = { [string]: Node }

local function sortedNames(graph: Graph): { string }
	local names = {}
	for name in graph do
		table.insert(names, name)
	end
	table.sort(names) -- pairs order is not stable; every tie must break the same way.
	return names
end

function Graph.nearest(graph: Graph, x: number, y: number, z: number): string
	local best, bestDistance = "", math.huge
	for _, name in sortedNames(graph) do
		local node = graph[name]
		local dx, dy, dz = node.x - x, node.y - y, node.z - z
		local distance = dx * dx + dy * dy + dz * dz
		if distance < bestDistance then
			best, bestDistance = name, distance
		end
	end
	return best
end

-- Next node on a shortest path from `from` to the closest of `targets`. Returns `from` when it is
-- already a target or nothing is reachable.
function Graph.nextStep(graph: Graph, from: string, targets: { [string]: boolean }): string
	if targets[from] then
		return from
	end
	local cameFrom: { [string]: string } = { [from] = from }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		local edges = table.clone(graph[current].edges)
		table.sort(edges)
		for _, neighbour in edges do
			if not cameFrom[neighbour] then
				cameFrom[neighbour] = current
				if targets[neighbour] then
					local step = neighbour
					while cameFrom[step] ~= from do
						step = cameFrom[step]
					end
					return step
				end
				table.insert(queue, neighbour)
			end
		end
	end
	return from
end

-- The node with the most hops from `from`; where the Registrar retreats after a cut.
function Graph.farthest(graph: Graph, from: string): string
	local distance: { [string]: number } = { [from] = 0 }
	local queue = { from }
	local head = 1
	local best = from
	while head <= #queue do
		local current = queue[head]
		head += 1
		local edges = table.clone(graph[current].edges)
		table.sort(edges)
		for _, neighbour in edges do
			if distance[neighbour] == nil then
				distance[neighbour] = distance[current] + 1
				if distance[neighbour] > distance[best] then
					best = neighbour
				end
				table.insert(queue, neighbour)
			end
		end
	end
	return best
end

return Graph
