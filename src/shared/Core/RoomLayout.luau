--!strict
-- Where furniture may stand in a room of a shift floor (World/FloorBuild), in the room's own
-- coordinates: the centre is 0, 0 and the walls' inner faces are at +-INNER.
--
-- Two things must stay clear. The cross between the four doorways, because the Registrar, the
-- Extra and the Usher walk doorway to centre to doorway, and a player running from them should
-- never meet a desk in the middle of a room. And every anomaly's spot, so no figure is ever built
-- inside a shelf where no lens could frame it.
local RoomLayout = {}

-- Half the width of the clear cross (a doorway is 6 wide, so this leaves 1.5 either side).
RoomLayout.AISLE = 4.5
-- Half a room inside its walls (rooms are 36 across, walls 1 thick).
RoomLayout.INNER = 17.5
-- How near a block may come to a figure's spot, and a seat to one.
RoomLayout.SPOT_CLEARANCE = 3
RoomLayout.SEAT_CLEARANCE = 2.6

export type Rect = { number } -- { minX, minZ, maxX, maxZ }
export type Point = { x: number, z: number }

local function gap(low: number, high: number, value: number): number
	if value < low then
		return low - value
	elseif value > high then
		return value - high
	end
	return 0
end

-- Whether a block over `rect` keeps clear of the walls, the cross and every spot.
function RoomLayout.free(rect: Rect, spots: { Point }): boolean
	local minX, minZ, maxX, maxZ = rect[1], rect[2], rect[3], rect[4]
	local inner = RoomLayout.INNER
	if minX < -inner or maxX > inner or minZ < -inner or maxZ > inner then
		return false
	end
	local aisle = RoomLayout.AISLE
	if (minX < aisle and maxX > -aisle) or (minZ < aisle and maxZ > -aisle) then
		return false
	end
	for _, spot in spots do
		local dx = gap(minX, maxX, spot.x)
		local dz = gap(minZ, maxZ, spot.z)
		if math.sqrt(dx * dx + dz * dz) < RoomLayout.SPOT_CLEARANCE then
			return false
		end
	end
	return true
end

-- An auditorium's seats, facing +Z: rows either side of the centre aisle, before and behind the
-- cross aisle, leaving out any seat on a figure's spot (that figure brings its own chair).
local ROWS = { -14, -11, -8, 7.5, 10.5, 13.5 }
local SEATS = { -12, -9, -6, 6, 9, 12 }

function RoomLayout.rows(spots: { Point }): { Point }
	local seats = {}
	for _, z in ROWS do
		for _, x in SEATS do
			local clear = true
			for _, spot in spots do
				local dx, dz = spot.x - x, spot.z - z
				if math.sqrt(dx * dx + dz * dz) < RoomLayout.SEAT_CLEARANCE then
					clear = false
					break
				end
			end
			if clear then
				table.insert(seats, { x = x, z = z })
			end
		end
	end
	return seats
end

-- A point in a room's own frame, turned so that `side` is +Z (the way a special room faces).
-- Returns the turn in quarter turns, for the builder to apply the other way.
local QUARTERS = { north = 0, east = 1, south = 2, west = 3 }

function RoomLayout.quarters(side: string): number
	return QUARTERS[side] or 0
end

-- From world offsets (dx, dz from the room centre) into the frame where `side` is +Z.
function RoomLayout.toLocal(dx: number, dz: number, side: string): (number, number)
	local q = QUARTERS[side] or 0
	if q == 1 then
		return -dz, dx
	elseif q == 2 then
		return -dx, -dz
	elseif q == 3 then
		return dz, -dx
	end
	return dx, dz
end

-- And back.
function RoomLayout.toWorld(lx: number, lz: number, side: string): (number, number)
	local q = QUARTERS[side] or 0
	if q == 1 then
		return lz, -lx
	elseif q == 2 then
		return -lx, -lz
	elseif q == 3 then
		return -lz, lx
	end
	return lx, lz
end

return RoomLayout
