--!strict
-- How a shift floor is dressed: the hand-made special rooms FloorGen places and the rules that
-- keep furniture out of everyone's way (Core/RoomLayout).
local FloorGen = require("../src/shared/Core/FloorGen")
local RoomLayout = require("../src/shared/Core/RoomLayout")

local KINDS = { auditorium = "hall", meeting = "office", lift = true }

return {
	["a special room is never the lobby or the vault, and is named as its room kind"] = function()
		local seen: { [string]: number } = {}
		local floors = 0
		for seed = 1, 120 do
			for depth = 1, 5 do
				local floor = FloorGen.generate(seed, depth)
				local special = floor.special
				if special then
					floors += 1
					seen[special.kind] = (seen[special.kind] or 0) + 1
					assert(KINDS[special.kind], `unknown special {special.kind}`)
					assert(special.room ~= floor.start, "a special in the lobby")
					assert(
						not floor.vault or floor.vault.room ~= special.room,
						"a special in the vault"
					)
					local room = floor.rooms[special.room]
					assert(room.special == special.kind)
					local named = KINDS[special.kind]
					if typeof(named) == "string" then
						assert(room.kind == named, `{special.kind} is a {room.kind}`)
					end
					-- Only one room per floor.
					for id, other in floor.rooms do
						assert(id == special.room or other.special == nil, "two specials")
					end
				end
			end
		end
		assert(floors > 300 and floors < 480, `{floors} specials in 600 floors`)
		for kind in KINDS do
			assert((seen[kind] or 0) > 20, `{kind} came up {seen[kind] or 0} times`)
		end
	end,

	["the other lift stands on a wall with no doorway, and never on floor -1"] = function()
		for seed = 1, 200 do
			local first = FloorGen.generate(seed, 1).special
			assert(not first or first.kind ~= "lift", "the other lift on -1")
			for depth = 2, 5 do
				local floor = FloorGen.generate(seed, depth)
				local special = floor.special
				if special and special.kind == "lift" then
					assert(
						not FloorGen.sideOpen(floor, special.room, special.side),
						`seed {seed} depth {depth}: a lift door in a doorway`
					)
				end
			end
		end
	end,

	["a special room changes nothing else about the floor"] = function()
		-- The spots, links and vault come out the same as on a floor that has none: the special is
		-- drawn last, and a floor rebuilt from an old tape's seed must still match where it was shot.
		for seed = 1, 60 do
			local floor = FloorGen.generate(seed, 3)
			local again = FloorGen.generate(seed, 3)
			assert(#floor.spots == #again.spots and #floor.links == #again.links)
			for index, spot in floor.spots do
				assert(spot.room ~= floor.start, "an anomaly in the lobby")
				assert(spot.x == again.spots[index].x and spot.z == again.spots[index].z)
			end
			assert((floor.special == nil) == (again.special == nil))
			if floor.special and again.special then
				assert(floor.special.room == again.special.room)
				assert(floor.special.side == again.special.side)
			end
		end
	end,

	["furniture keeps the cross between the doorways clear"] = function()
		-- The Registrar, the Extra and the Usher walk from doorway to centre to doorway.
		assert(not RoomLayout.free({ -1, 6, 1, 8 }, {}), "a block on the north aisle")
		assert(not RoomLayout.free({ 6, -1, 8, 1 }, {}), "a block on the east aisle")
		assert(RoomLayout.free({ 6, 6, 10, 10 }, {}))
		assert(not RoomLayout.free({ 6, 6, 18, 10 }, {}), "a block through the wall")
	end,

	["furniture keeps clear of every anomaly"] = function()
		local spots = { { x = 8, z = 8 } }
		assert(not RoomLayout.free({ 6, 6, 10, 10 }, spots), "a block on a figure")
		assert(not RoomLayout.free({ 10.5, 6, 12, 10 }, spots), "a block a step from a figure")
		assert(RoomLayout.free({ 12, 12, 16, 16 }, spots))
	end,

	["seats are offered only where they fit"] = function()
		local spots = { { x = 9, z = 10 } }
		for _, seat in RoomLayout.rows(spots) do
			assert(math.abs(seat.x) >= RoomLayout.AISLE and math.abs(seat.z) >= RoomLayout.AISLE)
			assert(
				math.abs(seat.x) <= RoomLayout.INNER - 1
					and math.abs(seat.z) <= RoomLayout.INNER - 1
			)
			local dx, dz = seat.x - 9, seat.z - 10
			assert(math.sqrt(dx * dx + dz * dz) >= RoomLayout.SEAT_CLEARANCE, "a seat on a figure")
		end
		assert(#RoomLayout.rows({}) >= 24, "an auditorium with few seats")
	end,

	["a special room's frame turns its wall to +Z and back"] = function()
		local cases = { north = { 0, 1 }, east = { 1, 0 }, south = { 0, -1 }, west = { -1, 0 } }
		for side, wall in cases do
			local lx, lz = RoomLayout.toLocal(wall[1] * 10, wall[2] * 10, side)
			assert(math.abs(lx) < 1e-9 and math.abs(lz - 10) < 1e-9, `{side} is not ahead`)
			local wx, wz = RoomLayout.toWorld(3, -7, side)
			local bx, bz = RoomLayout.toLocal(wx, wz, side)
			assert(bx == 3 and bz == -7, `{side} does not turn back`)
		end
	end,
}
