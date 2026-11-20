--!strict
-- One floor of a shift as geometry, built from its data (Core/FloorGen) and its seed, the same
-- way every time. The shift server builds the floor players walk on with it; a client builds a
-- copy of a floor long gone into a ViewportFrame to play a shift tape back (ShiftTapeView).
-- Greybox by design: the prototype tests whether the shift is fun, not how it looks.
local Build = require("./Build")
local FloorGen = require("../Core/FloorGen")
local Palette = require("../Config/Palette")

local FloorBuild = {}

local CELL = FloorGen.CELL
local ROOM_HEIGHT = 12
local DOOR_HEIGHT = 9
local HALF_DOOR = FloorGen.DOOR_WIDTH / 2

FloorBuild.ROOM_HEIGHT = ROOM_HEIGHT

-- How each depth looks: carpet, walls, how bright the lamps are, and the air.
export type Look = {
	carpet: Color3,
	wall: Color3,
	lamp: number,
	ambient: Color3,
	density: number,
	tint: Color3,
}
local LOOKS: { Look } = {
	{
		carpet = Palette.Carpet,
		wall = Palette.Wall,
		lamp = 1.4,
		ambient = Color3.fromRGB(50, 54, 62),
		density = 0.3,
		tint = Color3.new(1, 1, 1),
	},
	{
		carpet = Color3.fromRGB(18, 66, 70),
		wall = Palette.WallDark,
		lamp = 0.9,
		ambient = Color3.fromRGB(40, 43, 50),
		density = 0.36,
		tint = Color3.fromRGB(240, 244, 255),
	},
	{
		carpet = Color3.fromRGB(70, 70, 66),
		wall = Color3.fromRGB(110, 108, 100),
		lamp = 0.7,
		ambient = Color3.fromRGB(34, 36, 42),
		density = 0.42,
		tint = Color3.fromRGB(235, 240, 230),
	},
	{
		carpet = Color3.fromRGB(40, 36, 34),
		wall = Color3.fromRGB(80, 74, 66),
		lamp = 0.5,
		ambient = Color3.fromRGB(30, 30, 34),
		density = 0.5,
		tint = Color3.fromRGB(240, 230, 222),
	},
	{
		carpet = Color3.fromRGB(44, 20, 20),
		wall = Color3.fromRGB(70, 56, 52),
		lamp = 0.4,
		ambient = Color3.fromRGB(30, 22, 24),
		density = 0.58,
		tint = Color3.fromRGB(255, 220, 214),
	},
}

function FloorBuild.look(depth: number): Look
	return LOOKS[math.clamp(depth, 1, #LOOKS)]
end

-- Furniture by room kind. `rng` is the floor's own, so a floor always looks the same.
local function furnish(
	parent: Folder,
	kind: string,
	x: number,
	z: number,
	depth: number,
	rng: Random
)
	local upsideDown = depth >= 4
	local function chairAt(cx: number, cz: number)
		local cf = CFrame.lookAt(Vector3.new(cx, 0, cz), Vector3.new(cx, 0, cz + 1))
		if upsideDown then
			cf = CFrame.new(cx, ROOM_HEIGHT, cz) * CFrame.Angles(0, 0, math.pi)
		end
		Build.chair(parent, "Chair", cf)
	end
	if kind == "lobby" then
		Build.box(
			parent,
			"Bench",
			x - 14,
			0,
			z - 4,
			x - 12,
			1.6,
			z + 6,
			Palette.WoodDark,
			Enum.Material.Wood
		)
		Build.box(
			parent,
			"Bench",
			x + 12,
			0,
			z - 4,
			x + 14,
			1.6,
			z + 6,
			Palette.WoodDark,
			Enum.Material.Wood
		)
	elseif kind == "hall" then
		for row = 0, 2 do
			for seat = -2, 2 do
				chairAt(x + seat * 3.5, z + 6 + row * 3.6)
			end
		end
	elseif kind == "office" then
		for _, side in { -1, 1 } do
			local dx = x + side * 11
			local bottom = if upsideDown then ROOM_HEIGHT - 2.6 else 0
			local top = if upsideDown then ROOM_HEIGHT else 2.6
			Build.box(
				parent,
				"Desk",
				dx - 3,
				bottom,
				z + 8,
				dx + 3,
				top,
				z + 11,
				Palette.WoodDark,
				Enum.Material.Wood
			)
		end
	elseif kind == "storage" then
		Build.shelf(parent, x - 14, z + 11, x - 4, z + 13, 0, 7)
		Build.shelf(parent, x + 4, z + 11, x + 14, z + 13, 0, 7)
	elseif kind == "cloakroom" then
		Build.box(
			parent,
			"Rail",
			x - 12,
			6.5,
			z + 12,
			x + 12,
			6.8,
			z + 12.3,
			Palette.Metal,
			Enum.Material.Metal
		)
		for index = 0, 9 do
			if rng:NextNumber() < 0.7 then
				local cx = x - 11 + index * 2.4
				Build.box(
					parent,
					"Coat",
					cx - 0.9,
					2.6,
					z + 11.6,
					cx + 0.9,
					6.4,
					z + 12.6,
					Palette.Suit,
					Enum.Material.Fabric
				)
			end
		end
	elseif kind == "corridor" then
		-- Curtains along both side walls, parted where a doorway may be (z - 3..z + 3), and soft:
		-- nobody should be walled in by fabric.
		for _, side in { -1, 1 } do
			local wx = x + side * (CELL / 2 - 1.2)
			for _, span in { { -12, -4.5 }, { 4.5, 12 } } do
				local curtain = Build.box(
					parent,
					"Curtain",
					wx - 0.4,
					0,
					z + span[1],
					wx + 0.4,
					ROOM_HEIGHT,
					z + span[2],
					Palette.Curtain,
					Enum.Material.Fabric
				)
				curtain.CanCollide = false
			end
		end
	end
end

-- The floor's rooms, walls, lamps and furniture in a new folder, not yet parented.
function FloorBuild.build(floor: FloorGen.Floor, seed: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Floor"
	local look = FloorBuild.look(floor.depth)
	local rng = Random.new(seed * 31 + floor.depth)

	for id = 1, floor.width * floor.height do
		local room = floor.rooms[id]
		local x0 = floor.originX + room.cx * CELL
		local z0 = floor.originZ + room.cz * CELL
		local x1, z1 = x0 + CELL, z0 + CELL
		local cx, cz = FloorGen.roomCentre(floor, id)
		Build.box(folder, "Floor", x0, -1, z0, x1, 0, z1, look.carpet, Enum.Material.Fabric)
		Build.box(folder, "Ceiling", x0, ROOM_HEIGHT, z0, x1, ROOM_HEIGHT + 1, z1, Palette.Ceiling)

		-- South edge: a doorway to the room below, the lift for the start room, else solid.
		local southOpenings = {}
		if room.cz > 0 and FloorGen.linked(floor, id, id - floor.width) then
			table.insert(southOpenings, { cx - HALF_DOOR, cx + HALF_DOOR, 0, DOOR_HEIGHT })
		elseif id == floor.start then
			-- The lift's front wall stands in this gap.
			table.insert(southOpenings, { -7, 7, 0, ROOM_HEIGHT })
		end
		Build.wallX(folder, "Wall", z0, x0, x1, 0, ROOM_HEIGHT, southOpenings, look.wall)

		-- West edge: a doorway to the room on the left, else solid.
		local westOpenings = {}
		if room.cx > 0 and FloorGen.linked(floor, id, id - 1) then
			table.insert(westOpenings, { cz - HALF_DOOR, cz + HALF_DOOR, 0, DOOR_HEIGHT })
		end
		Build.wallZ(folder, "Wall", x0, z0, z1, 0, ROOM_HEIGHT, westOpenings, look.wall)

		-- The outer north and east edges close the floor.
		if room.cz == floor.height - 1 then
			Build.wallX(folder, "Wall", z1, x0, x1, 0, ROOM_HEIGHT, {}, look.wall)
		end
		if room.cx == floor.width - 1 then
			Build.wallZ(folder, "Wall", x1, z0, z1, 0, ROOM_HEIGHT, {}, look.wall)
		end

		-- A lamp in most rooms; deeper floors lose some of them.
		local dark = id ~= floor.start and rng:NextNumber() < 0.12 * (floor.depth - 1)
		if not dark then
			Build.panel(folder, cx, ROOM_HEIGHT - 0.2, cz, 6, 6, look.lamp, 44, nil, false)
		end
		furnish(folder, room.kind, cx, cz, floor.depth, rng)
	end
	return folder
end

return FloorBuild
