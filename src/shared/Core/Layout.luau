--!strict
-- The Mission 001 floor plan as data. North is -Z (the stage), south is +Z (the foyer).
-- Geometry, the Registrar's graph and the specs all read this one table.
local Layout = {}

Layout.HALL = { minX = -39, maxX = 39, minZ = -40, maxZ = 44, height = 24 }
Layout.STAGE = { minZ = -40, maxZ = -24, height = 3 }
Layout.FOYER = { minX = -30, maxX = 30, minZ = 44, maxZ = 76, height = 14 }
Layout.COATS = { minX = 30, maxX = 52, minZ = 46, maxZ = 74, height = 14 }
Layout.BOOTH = { minX = -30, maxX = 20, minZ = 44, maxZ = 56, floorY = 14, height = 10 }
Layout.CORRIDOR = { minX = -48, maxX = -39, minZ = -44, maxZ = -4, height = 13 }
Layout.OFFICE = { minX = 39, maxX = 60, minZ = 12, maxZ = 34, height = 12 }
Layout.BASEMENT = { minX = -90, maxX = -50, minZ = 14, maxZ = 44, floorY = -12, height = 10 }
-- Storage behind the boiler room: rows of shelving laid out as one long switchback aisle, with
-- the breaker at the very end of it.
Layout.CELLAR = { minX = -90, maxX = -50, minZ = 44, maxZ = 82, floorY = -12, height = 10 }
Layout.ARCHIVE = { minX = -30, maxX = 30, minZ = -68, maxZ = -40, floorY = 3, height = 12 }

Layout.SPAWN = { x = 0, y = 3, z = 68 }
Layout.DESK = { x = 0, y = 3, z = -32 }
Layout.BELL = { x = -2, y = 6.6, z = -32 }
Layout.PROJECTOR = { x = 0, y = 14, z = 47.5 }
Layout.REGISTER = { x = 0, y = 3, z = -62 }
Layout.BENCH = { x = -18, y = 0, z = 60 }
Layout.SPLICE_MARK = { x = 16, y = 0, z = 66 }

-- The Usher's round during the power cut: down the west side aisle, through the curtain
-- corridor and the landing, down the stairs, across the boiler room and along every aisle of the
-- storage cellar to the breaker, then back the same way. Every leg runs through open floor or a
-- doorway, so he never walks through a wall. y is the floor under his feet.
Layout.USHER_ROUTE = {
	{ x = -35, y = 0, z = 34 },
	{ x = -35, y = 0, z = -9 },
	{ x = -43, y = 0, z = -9 },
	{ x = -43, y = 0, z = -11 },
	{ x = -63, y = 0, z = -11 },
	{ x = -63, y = 0, z = -8 },
	{ x = -63, y = -12, z = 14 },
	{ x = -63, y = -12, z = 20 },
	{ x = -70, y = -12, z = 38 },
	{ x = -70, y = -12, z = 47 },
	{ x = -55, y = -12, z = 47 },
	{ x = -55, y = -12, z = 55.5 },
	{ x = -85, y = -12, z = 55.5 },
	{ x = -85, y = -12, z = 63.5 },
	{ x = -55, y = -12, z = 63.5 },
	{ x = -55, y = -12, z = 71.5 },
	{ x = -85, y = -12, z = 71.5 },
	{ x = -85, y = -12, z = 79.5 },
	{ x = -62, y = -12, z = 79.5 },
}

-- x of the hidden door in the stage's back wall, by puzzle.doorSide.
Layout.DOOR_OFFSET_X = 20
Layout.DOOR_Z = -40

-- Registrar node graph: each edge is a place he can cut to next.
Layout.NODES = {
	foyer = { x = 0, y = 0, z = 60, edges = { "foyerWest", "coats", "aisleRear" } },
	foyerWest = { x = -20, y = 0, z = 70, edges = { "foyer", "booth" } },
	coats = { x = 40, y = 0, z = 60, edges = { "foyer" } },
	booth = { x = 0, y = 14, z = 50, edges = { "foyerWest" } },
	aisleRear = { x = 0, y = 0, z = 38, edges = { "foyer", "rearWest", "rearEast", "aisleMid" } },
	rearWest = { x = -34, y = 0, z = 36, edges = { "aisleRear", "midWest" } },
	rearEast = { x = 34, y = 0, z = 36, edges = { "aisleRear", "midEast" } },
	aisleMid = { x = 0, y = 0, z = 12, edges = { "aisleRear", "aisleFront", "midWest", "midEast" } },
	midWest = { x = -35, y = 0, z = 10, edges = { "rearWest", "aisleMid", "frontWest" } },
	midEast = { x = 35, y = 0, z = 10, edges = { "rearEast", "aisleMid", "frontEast", "office" } },
	office = { x = 48, y = 0, z = 24, edges = { "midEast" } },
	aisleFront = {
		x = 0,
		y = 0,
		z = -19,
		edges = { "aisleMid", "frontWest", "frontEast", "stage" },
	},
	frontWest = { x = -34, y = 0, z = -19, edges = { "midWest", "aisleFront", "corridorSouth" } },
	frontEast = { x = 34, y = 0, z = -19, edges = { "midEast", "aisleFront" } },
	corridorSouth = { x = -43, y = 0, z = -9, edges = { "frontWest", "corridorNorth", "landing" } },
	landing = { x = -55, y = 0, z = -13, edges = { "corridorSouth", "stairs" } },
	stairs = { x = -63, y = -6, z = 3, edges = { "landing", "basement" } },
	basement = { x = -68, y = -12, z = 30, edges = { "stairs", "cellar" } },
	cellar = { x = -70, y = -12, z = 63, edges = { "basement" } },
	corridorNorth = { x = -43, y = 3, z = -38, edges = { "corridorSouth", "wing" } },
	wing = { x = -33, y = 3, z = -32, edges = { "corridorNorth", "stage" } },
	stage = { x = 12, y = 3, z = -30, edges = { "aisleFront", "wing", "archive" } },
	archive = { x = 0, y = 3, z = -52, edges = { "stage" } },
}

return Layout
