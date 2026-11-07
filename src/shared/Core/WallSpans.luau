--!strict
-- Cuts a wall into solid rectangles around its openings. Works in columns between all opening
-- edges, so openings may overlap along the wall: a door under a wider window stays a door.
local WallSpans = {}

export type Rect = { fromA: number, toA: number, bottom: number, top: number }

-- Openings are { fromA, toA, bottom, top }, where A is the wall's length axis.
function WallSpans.solve(
	minA: number,
	maxA: number,
	bottom: number,
	top: number,
	openings: { { number } }
): { Rect }
	local edges = { minA, maxA }
	for _, gap in openings do
		table.insert(edges, math.clamp(gap[1], minA, maxA))
		table.insert(edges, math.clamp(gap[2], minA, maxA))
	end
	table.sort(edges)

	local rects: { Rect } = {}
	local function add(fromA: number, toA: number, low: number, high: number)
		-- Neighbouring columns with the same height become one part.
		local last = rects[#rects]
		if last and last.toA == fromA and last.bottom == low and last.top == high then
			last.toA = toA
			return
		end
		table.insert(rects, { fromA = fromA, toA = toA, bottom = low, top = high })
	end

	for index = 1, #edges - 1 do
		local fromA, toA = edges[index], edges[index + 1]
		if toA > fromA then
			local holes: { { number } } = {}
			for _, gap in openings do
				if gap[1] <= fromA and gap[2] >= toA then
					table.insert(holes, gap)
				end
			end
			table.sort(holes, function(a, b)
				return a[3] < b[3]
			end)
			local cursor = bottom
			for _, hole in holes do
				if hole[3] > cursor then
					add(fromA, toA, cursor, math.min(hole[3], top))
				end
				cursor = math.max(cursor, hole[4])
			end
			if cursor < top then
				add(fromA, toA, cursor, top)
			end
		end
	end
	return rects
end

return WallSpans
