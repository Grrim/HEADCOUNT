--!strict
-- How each depth of the shift looks (docs/09_GDD_V2.md §2.8): the deeper, the stranger. One
-- table per floor: what the surfaces are made of, how the rooms are lit, and the air (applied by
-- ShiftWorld.applyDepth). World/FloorBuild and World/FloorDress read it.
--
--   -1  day      a bright, ordinary community centre: cream walls, teal paint, daylight windows
--   -2  evening  the same building after hours: dusk in the windows, half the tubes dead
--   -3  stores   the tape stores: bare block walls, concrete, shelving, bulbs on cords
--   -4  inverted corridors where the furniture is on the ceiling, carpet up there too, lamps in
--                the floor shining up
--   -5  lobby    something that looks like the lobby of the game (Archive 03), only wrong
--
-- Colours of textured surfaces are tints over a MaterialVariant (src/materials), as in
-- World/Surfaces: the same numbers as there give the same look as the hub and the mission.
local Palette = require("../Config/Palette")

export type Surface = { color: Color3, material: Enum.Material, variant: string? }

export type Look = {
	name: string,
	-- The big painted number by the lift, and what is written under it.
	sign: string,
	signNote: string,
	signColor: Color3,
	wall: Surface,
	-- A painted or panelled band along the bottom of every wall (the top, when inverted).
	band: Surface?,
	bandHeight: number,
	rail: Color3?,
	skirting: Color3,
	frame: Surface,
	ceiling: Surface,
	-- Floors by room kind; `default` for the rest.
	floors: { [string]: Surface },
	-- Light fittings: "panel" (fluorescent tubes), "bulb" (on a cord, in a cage), "floor" (set
	-- in the floor, shining up), "pendant" (warm shades, like the hub's).
	lamp: string,
	lampColor: Color3,
	lampBrightness: number,
	lampRange: number,
	-- Chance a room's lamps are out (never the lobby's), and that a lit one flickers.
	dead: number,
	flicker: number,
	-- "day", "dusk" or nil: fake windows on the floor's outer walls.
	windows: string?,
	inverted: boolean,
	-- The air (ShiftWorld.applyDepth).
	ambient: Color3,
	outdoor: Color3,
	exposure: number,
	density: number,
	haze: number,
	air: Color3,
	decay: Color3,
	tint: Color3,
	saturation: number,
	contrast: number,
}

local function surface(color: Color3, material: Enum.Material, variant: string?): Surface
	return { color = color, material = material, variant = variant }
end

local rgb = Color3.fromRGB
local M = Enum.Material

local LOOKS: { Look } = {
	{
		name = "day",
		sign = "-1",
		signColor = rgb(52, 98, 92),
		signNote = "COMMUNITY HALL",
		wall = surface(rgb(222, 212, 186), M.Plaster, "PK_Wallpaper"),
		band = surface(rgb(62, 108, 100), M.SmoothPlastic),
		bandHeight = 3.8,
		rail = rgb(214, 200, 166),
		skirting = rgb(40, 50, 48),
		frame = surface(rgb(178, 134, 92), M.Wood, "PK_Veneer"),
		ceiling = surface(rgb(214, 214, 206), M.Plaster, "PK_CeilingTile"),
		floors = {
			default = surface(rgb(172, 166, 142), M.SmoothPlastic),
			lobby = surface(rgb(205, 196, 182), M.Marble, "PK_Terrazzo"),
			cloakroom = surface(rgb(196, 188, 172), M.Marble, "PK_Terrazzo"),
			hall = surface(rgb(158, 110, 68), M.WoodPlanks),
			office = surface(rgb(118, 104, 98), M.Carpet, "PK_Carpet"),
		},
		lamp = "panel",
		lampColor = rgb(238, 242, 230),
		lampBrightness = 1.1,
		lampRange = 30,
		dead = 0,
		flicker = 0,
		windows = "day",
		inverted = false,
		ambient = rgb(80, 82, 86),
		outdoor = rgb(42, 44, 48),
		exposure = 0.5,
		density = 0.16,
		haze = 0.4,
		air = rgb(176, 180, 176),
		decay = rgb(120, 120, 110),
		tint = rgb(255, 252, 244),
		saturation = 0.02,
		contrast = 0.08,
	},
	{
		name = "evening",
		sign = "-2",
		signColor = rgb(196, 188, 160),
		signNote = "COMMUNITY HALL",
		wall = surface(rgb(150, 142, 124), M.Plaster, "PK_Wallpaper"),
		band = surface(rgb(30, 58, 56), M.SmoothPlastic),
		bandHeight = 3.8,
		rail = rgb(120, 108, 86),
		skirting = rgb(24, 30, 30),
		frame = surface(rgb(120, 90, 66), M.Wood, "PK_Veneer"),
		ceiling = surface(rgb(128, 130, 128), M.Plaster, "PK_CeilingTile"),
		floors = {
			default = surface(rgb(110, 106, 92), M.SmoothPlastic),
			lobby = surface(rgb(150, 142, 132), M.Marble, "PK_Terrazzo"),
			cloakroom = surface(rgb(140, 134, 122), M.Marble, "PK_Terrazzo"),
			hall = surface(rgb(104, 72, 46), M.WoodPlanks),
			office = surface(rgb(84, 74, 72), M.Carpet, "PK_Carpet"),
		},
		lamp = "panel",
		lampColor = rgb(214, 232, 210),
		lampBrightness = 0.85,
		lampRange = 28,
		dead = 0.5,
		flicker = 0.3,
		windows = "dusk",
		inverted = false,
		ambient = rgb(38, 42, 58),
		outdoor = rgb(20, 22, 34),
		exposure = 0.3,
		density = 0.3,
		haze = 1.2,
		air = rgb(44, 52, 80),
		decay = rgb(14, 16, 32),
		tint = rgb(214, 224, 255),
		saturation = -0.12,
		contrast = 0.14,
	},
	{
		name = "stores",
		sign = "-3",
		signColor = rgb(206, 170, 64),
		signNote = "TAPE STORES",
		wall = surface(rgb(124, 128, 114), M.Concrete),
		band = surface(rgb(70, 82, 72), M.SmoothPlastic),
		bandHeight = 4.4,
		rail = nil,
		skirting = rgb(44, 44, 40),
		frame = surface(rgb(70, 74, 72), M.Metal),
		ceiling = surface(rgb(56, 58, 58), M.Concrete),
		floors = { default = surface(rgb(106, 104, 98), M.Concrete) },
		lamp = "bulb",
		lampColor = rgb(255, 198, 132),
		lampBrightness = 1.1,
		lampRange = 24,
		dead = 0.25,
		flicker = 0.2,
		windows = nil,
		inverted = false,
		ambient = rgb(48, 46, 42),
		outdoor = rgb(22, 20, 18),
		exposure = 0.3,
		density = 0.42,
		haze = 2.2,
		air = rgb(76, 66, 50),
		decay = rgb(30, 24, 16),
		tint = rgb(255, 234, 204),
		saturation = -0.2,
		contrast = 0.18,
	},
	{
		name = "inverted",
		sign = "-4",
		signColor = rgb(206, 176, 128),
		signNote = "CORRIDORS",
		wall = surface(rgb(92, 66, 48), M.Wood, "PK_Veneer"),
		band = surface(rgb(52, 36, 28), M.Wood),
		bandHeight = 3.8,
		rail = rgb(150, 116, 80),
		skirting = rgb(30, 22, 18),
		frame = surface(rgb(52, 36, 28), M.Wood),
		ceiling = surface(rgb(96, 40, 40), M.Carpet, "PK_Carpet"),
		floors = { default = surface(rgb(150, 152, 150), M.Plaster, "PK_CeilingTile") },
		lamp = "floor",
		lampColor = rgb(222, 228, 238),
		lampBrightness = 0.9,
		lampRange = 26,
		dead = 0.35,
		flicker = 0.25,
		windows = nil,
		inverted = true,
		ambient = rgb(38, 34, 40),
		outdoor = rgb(18, 16, 20),
		exposure = 0.25,
		density = 0.46,
		haze = 1.8,
		air = rgb(54, 44, 58),
		decay = rgb(20, 14, 22),
		tint = rgb(242, 228, 242),
		saturation = -0.18,
		contrast = 0.22,
	},
	{
		name = "lobby",
		sign = "0",
		signColor = Palette.Crt,
		signNote = "ARCHIVE 03",
		wall = surface(rgb(150, 146, 134), M.Plaster, "PK_Wallpaper"),
		band = surface(rgb(150, 120, 104), M.Wood, "PK_Veneer"),
		bandHeight = 4.5,
		rail = rgb(62, 36, 24),
		skirting = Palette.WoodDark,
		frame = surface(rgb(110, 84, 70), M.Wood, "PK_Veneer"),
		ceiling = surface(rgb(118, 116, 114), M.Plaster, "PK_CeilingTile"),
		floors = { default = surface(rgb(92, 82, 78), M.Carpet, "PK_Carpet") },
		lamp = "pendant",
		lampColor = rgb(255, 188, 150),
		lampBrightness = 1.1,
		lampRange = 22,
		dead = 0.15,
		flicker = 0.3,
		windows = nil,
		inverted = false,
		ambient = rgb(62, 44, 40),
		outdoor = rgb(26, 18, 16),
		exposure = 0.35,
		density = 0.38,
		haze = 1.4,
		air = rgb(92, 56, 44),
		decay = rgb(40, 18, 14),
		tint = rgb(255, 210, 196),
		saturation = -0.04,
		contrast = 0.18,
	},
}

local FloorLooks = {}

FloorLooks.COUNT = #LOOKS

function FloorLooks.get(depth: number): Look
	return LOOKS[math.clamp(depth, 1, #LOOKS)]
end

-- The floor a room of this kind gets at this look.
function FloorLooks.floorOf(look: Look, kind: string): Surface
	return look.floors[kind] or look.floors.default
end

return FloorLooks
