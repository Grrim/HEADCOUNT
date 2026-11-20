--!strict
-- The furniture of a shift floor, room by room (World/FloorBuild builds the shell). Each room's
-- four corners take one group each (a block of chairs, a desk, a run of shelving...), picked
-- from what suits the room's kind at that depth, and only where Core/RoomLayout says it keeps
-- out of the way: never on the cross between the doorways, never on an anomaly's spot.
--
-- Everything is placed in the room's own coordinates (centre 0, 0). On an inverted floor (-4)
-- the same furniture is built upside down against the ceiling, which is all it takes for a
-- corridor to feel wrong. What can be walked into is one invisible block per group; what is
-- seen is decor that stops no lens.
--
-- All choices come from the floor's own Random, so a floor rebuilt from its seed for a tape
-- looks exactly as it did.
local Build = require("./Build")
local FloorGen = require("../Core/FloorGen")
local FloorLooks = require("./FloorLooks")
local Palette = require("../Config/Palette")
local Posters = require("./Posters")
local Props = require("./Props")
local RoomLayout = require("../Core/RoomLayout")

local FloorDress = {}

local H = 12
FloorDress.HEIGHT = H

export type Ctx = {
	folder: Folder,
	look: FloorLooks.Look,
	floor: FloorGen.Floor,
	id: number,
	kind: string,
	cx: number,
	cz: number,
	rng: Random,
	-- This room's anomaly spots, in the room's coordinates.
	spots: { RoomLayout.Point },
	-- True when building for a tape (everything the lens saw is shown).
	lensView: boolean,
}

local rgb = Color3.fromRGB
local M = Enum.Material

local CARD = rgb(122, 98, 68)
local TAPE = rgb(20, 20, 22)
local LABEL = rgb(222, 214, 190)
local LEAF = rgb(52, 88, 50)
local DEAD_LEAF = rgb(96, 74, 44)
local POT = rgb(88, 54, 40)
local GREY_METAL = rgb(112, 116, 118)

-- A box in room coordinates, as decor. On an inverted floor its heights are mirrored.
function FloorDress.block(
	ctx: Ctx,
	name: string,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	color: Color3,
	material: Enum.Material?
): Part
	local a, b = y0, y1
	if ctx.look.inverted then
		a, b = H - y1, H - y0
	end
	return Build.decor(
		ctx.folder,
		name,
		ctx.cx + x0,
		a,
		ctx.cz + z0,
		ctx.cx + x1,
		b,
		ctx.cz + z1,
		color,
		material
	)
end

-- What a group can be walked into: one invisible block, and only on a floor the right way up.
-- It stops a lens as the furniture would.
function FloorDress.solid(ctx: Ctx, x0: number, z0: number, x1: number, z1: number, height: number)
	if ctx.look.inverted then
		return
	end
	local part = Build.box(
		ctx.folder,
		"Block",
		ctx.cx + x0,
		0,
		ctx.cz + z0,
		ctx.cx + x1,
		height,
		ctx.cz + z1,
		Palette.Shadow
	)
	part.Transparency = 1
	part.CastShadow = false
end

-- A model from Shared/Models standing at (x, y, z), turned by yaw; hung from the ceiling when the
-- floor is inverted.
function FloorDress.prop(
	ctx: Ctx,
	model: string,
	x: number,
	y: number,
	z: number,
	yaw: number,
	scale: (number | Vector3)?
): MeshPart
	local cf = if ctx.look.inverted
		then CFrame.new(ctx.cx + x, H - y, ctx.cz + z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(
			0,
			0,
			math.pi
		)
		else CFrame.new(ctx.cx + x, y, ctx.cz + z) * CFrame.Angles(0, yaw, 0)
	local part = Props.place(ctx.folder, model, cf, scale)
	part.CastShadow = false
	return part
end

-- A light in a part (the part may be invisible).
function FloorDress.light(
	part: BasePart,
	color: Color3,
	brightness: number,
	range: number,
	face: Enum.NormalId?
): Light
	local light: Light
	if face then
		local spot = Instance.new("SpotLight")
		spot.Face = face
		spot.Angle = 150
		light = spot
	else
		light = Instance.new("PointLight")
	end
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
	return light
end

-- Turning a chair to face +Z.
local FACE_NORTH = math.pi

local function chair(ctx: Ctx, x: number, z: number, yaw: number)
	FloorDress.prop(ctx, "Chair", x, 0, z, yaw, 1.5)
end

local function plant(ctx: Ctx, x: number, z: number)
	FloorDress.block(ctx, "PlantPot", x - 0.7, 0, z - 0.7, x + 0.7, 1.1, z + 0.7, POT)
	local leaf = if ctx.look.name == "lobby" then DEAD_LEAF else LEAF
	for index = 0, 2 do
		local spread = 0.9 - index * 0.25
		local y = 1.1 + 2.6 * (index + 1) / 3
		if ctx.look.inverted then
			y = H - y
		end
		Build.piece(
			ctx.folder,
			"PlantLeaf",
			CFrame.new(ctx.cx + x, y, ctx.cz + z),
			Vector3.new(2.4 * spread + 0.8, 1.8, 2.4 * spread + 0.8),
			leaf,
			M.Grass,
			Enum.PartType.Ball
		)
	end
end

-- A stack of cassettes, spine out, each with its paper label.
local function tapes(ctx: Ctx, x: number, y: number, z: number, count: number)
	for index = 0, count - 1 do
		local shift = (ctx.rng:NextNumber() - 0.5) * 0.16
		local bottom = y + index * 0.26
		FloorDress.block(
			ctx,
			"Tape",
			x - 0.7 + shift,
			bottom,
			z - 0.5,
			x + 0.7 + shift,
			bottom + 0.24,
			z + 0.5,
			TAPE
		)
		FloorDress.block(
			ctx,
			"TapeLabel",
			x - 0.45 + shift,
			bottom + 0.05,
			z - 0.55,
			x + 0.45 + shift,
			bottom + 0.19,
			z - 0.5,
			LABEL
		)
	end
end

type Group = {
	hx: number,
	hz: number,
	build: (ctx: Ctx, x: number, z: number, sx: number, sz: number) -> (),
}

local GROUPS: { [string]: Group } = {}

-- Two rows of three folding chairs, all facing the same way, as if set out for a meeting.
GROUPS.chairs = {
	hx = 4.4,
	hz = 2.6,
	build = function(ctx, x, z)
		for _, row in { -1.6, 1.6 } do
			for _, seat in { -3.5, 0, 3.5 } do
				chair(ctx, x + seat, z + row, FACE_NORTH)
			end
			FloorDress.solid(ctx, x - 4.3, z + row - 0.8, x + 4.3, z + row + 0.8, 1.6)
		end
	end,
}

-- After hours: a folding table with the chairs put up on it, legs in the air.
GROUPS.tables = {
	hx = 3.4,
	hz = 1.8,
	build = function(ctx, x, z)
		local wood = rgb(150, 132, 104)
		FloorDress.block(
			ctx,
			"TableTop",
			x - 3.2,
			2.5,
			z - 1.5,
			x + 3.2,
			2.7,
			z + 1.5,
			wood,
			M.Wood
		)
		for _, lx in { -2.9, 2.9 } do
			FloorDress.block(
				ctx,
				"TableLeg",
				x + lx - 0.1,
				0,
				z - 1.3,
				x + lx + 0.1,
				2.5,
				z + 1.3,
				GREY_METAL,
				M.Metal
			)
		end
		for _, seat in { -2, 0, 2 } do
			local cx, cz = ctx.cx + x + seat, ctx.cz + z
			local top = 2.7 + 3
			local cf = if ctx.look.inverted
				then CFrame.new(cx, H - top, cz) * CFrame.Angles(
					0,
					ctx.rng:NextNumber(-0.2, 0.2),
					0
				)
				else CFrame.new(cx, top, cz) * CFrame.Angles(
					0,
					ctx.rng:NextNumber(-0.2, 0.2),
					0
				) * CFrame.Angles(0, 0, math.pi)
			Props.place(ctx.folder, "Chair", cf, 1.5).CastShadow = false
		end
		FloorDress.solid(ctx, x - 3.2, z - 1.5, x + 3.2, z + 1.5, 2.7)
	end,
}

-- A desk with a chair pulled up to it and a lamp. On the evening floor the lamps were left on.
GROUPS.desk = {
	hx = 3.4,
	hz = 3,
	build = function(ctx, x, z, _, sz)
		local yaw = if sz > 0 then 0 else math.pi
		FloorDress.prop(ctx, "Desk", x, 0, z, yaw, 0.86)
		chair(ctx, x + 0.6, z - sz * 2.4, if sz > 0 then FACE_NORTH else 0)
		local lamp = FloorDress.prop(ctx, "DeskLamp", x - 2, 2.7, z, yaw + 0.5, 1)
		if ctx.look.name == "evening" then
			FloorDress.light(lamp, Palette.Bulb, 1.4, 12)
		end
		if ctx.look.name == "lobby" or ctx.rng:NextNumber() < 0.4 then
			FloorDress.prop(ctx, "Crt", x + 1.4, 2.7, z, yaw, 0.6)
		else
			for index = 0, 2 do
				local y = 2.7 + index * 0.05
				FloorDress.block(
					ctx,
					"Paper",
					x + 0.6,
					y,
					z - 0.5,
					x + 2.2,
					y + 0.04,
					z + 0.6,
					Palette.Paper
				)
			end
		end
		FloorDress.solid(ctx, x - 3, z - 1.7, x + 3, z + 1.7, 2.7)
	end,
}

-- Shelving: to the ceiling in the tape stores and in the lobby that is not the lobby.
GROUPS.shelf = {
	hx = 5.4,
	hz = 1.4,
	build = function(ctx, x, z, _, sz)
		local height = if ctx.look.name == "stores"
			then 9.5
			elseif ctx.look.name == "lobby" then 11
			else 7
		Build.shelf(
			ctx.folder,
			ctx.cx + x - 5.2,
			ctx.cz + z - 1.2,
			ctx.cx + x + 5.2,
			ctx.cz + z + 1.2,
			0,
			height
		)
		if ctx.look.name == "stores" then
			-- An aisle code on each end, so the stores read as a filing system that goes on forever.
			local code =
				`{string.char(65 + ctx.rng:NextInteger(0, 7))}-{ctx.rng:NextInteger(10, 199)}`
			for _, side in { -1, 1 } do
				local ex = x + side * 5.2
				local plate = FloorDress.block(
					ctx,
					"AisleCode",
					math.min(ex, ex + side * 0.05),
					6.6,
					z - 0.9,
					math.max(ex, ex + side * 0.05),
					7.6,
					z + 0.9,
					rgb(206, 170, 64)
				)
				local label = Build.label(
					plate,
					if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left,
					code,
					Palette.Ink
				)
				label.Font = Enum.Font.Oswald
			end
			if ctx.rng:NextNumber() < 0.6 then
				tapes(
					ctx,
					x + ctx.rng:NextNumber(-3, 3),
					0,
					z - sz * 1.9,
					ctx.rng:NextInteger(2, 6)
				)
			end
		end
	end,
}

-- Grey filing cabinets, drawers marked out.
GROUPS.cabinets = {
	hx = 2.8,
	hz = 1.2,
	build = function(ctx, x, z, _, sz)
		for index = -1, 1 do
			local cx = x + index * 1.75
			FloorDress.block(
				ctx,
				"Cabinet",
				cx - 0.82,
				0,
				z - 1,
				cx + 0.82,
				4.4,
				z + 1,
				GREY_METAL,
				M.Metal
			)
			-- The drawers face the room's centre.
			local front = z - sz * 1
			for drawer = 1, 3 do
				local y = drawer * 1.4 - 0.1
				FloorDress.block(
					ctx,
					"Drawer",
					cx - 0.3,
					y - 0.08,
					math.min(front, front - sz * 0.06),
					cx + 0.3,
					y + 0.08,
					math.max(front, front - sz * 0.06),
					Palette.Shadow
				)
			end
		end
		FloorDress.solid(ctx, x - 2.6, z - 1, x + 2.6, z + 1, 4.4)
	end,
}

-- A rail of coats nobody came back for.
GROUPS.coats = {
	hx = 4.4,
	hz = 1.2,
	build = function(ctx, x, z)
		for _, side in { -4.1, 4.1 } do
			FloorDress.block(
				ctx,
				"RackPost",
				x + side - 0.1,
				0,
				z - 0.1,
				x + side + 0.1,
				6.8,
				z + 0.1,
				Palette.Metal,
				M.Metal
			)
		end
		FloorDress.block(
			ctx,
			"RackRail",
			x - 4.1,
			6.6,
			z - 0.08,
			x + 4.1,
			6.76,
			z + 0.08,
			Palette.Metal,
			M.Metal
		)
		for index = 0, 4 do
			if ctx.rng:NextNumber() < 0.8 then
				local cx = x - 3.2 + index * 1.6
				FloorDress.prop(
					ctx,
					"Coat",
					cx,
					4.25,
					z,
					math.rad(90) + ctx.rng:NextNumber(-0.2, 0.2),
					0.95
				)
			end
		end
		FloorDress.solid(ctx, x - 4.2, z - 0.6, x + 4.2, z + 0.6, 6.8)
	end,
}

-- Cardboard boxes, some stacked.
GROUPS.boxes = {
	hx = 2.6,
	hz = 2.2,
	build = function(ctx, x, z)
		for index = 0, 2 do
			local bx = x - 1.3 + (index % 2) * 2.4
			local bz = z - 1 + math.floor(index / 2) * 2.1
			local height = ctx.rng:NextNumber(1.6, 2.6)
			local box = FloorDress.prop(
				ctx,
				"Boxes",
				bx,
				0,
				bz,
				ctx.rng:NextNumber(-0.4, 0.4),
				Vector3.new(1.9, height / 2, 1.9)
			)
			-- The generated texture came out pink and a texture ignores Color (docs/06_ASSETS.md).
			box.TextureID = ""
			box.Color = CARD
			box.Material = M.Cardboard
		end
		FloorDress.solid(ctx, x - 2.4, z - 2, x + 2.4, z + 2, 2)
	end,
}

-- A bench against nothing in particular, and a plant at its end.
GROUPS.bench = {
	hx = 5.6,
	hz = 1.2,
	build = function(ctx, x, z, sx)
		FloorDress.prop(ctx, "Bench", x - sx * 0.6, 0, z, 0, Vector3.new(1.6, 1, 1.2))
		plant(ctx, x + sx * 4.6, z)
		FloorDress.solid(ctx, x - sx * 0.6 - 4.2, z - 0.9, x - sx * 0.6 + 4.2, z + 0.9, 1.9)
	end,
}

GROUPS.plant = {
	hx = 1,
	hz = 1,
	build = function(ctx, x, z)
		plant(ctx, x, z)
		FloorDress.solid(ctx, x - 0.7, z - 0.7, x + 0.7, z + 0.7, 1.1)
	end,
}

-- An upright piano with its lid shut and a stool.
GROUPS.piano = {
	hx = 2.8,
	hz = 1.8,
	build = function(ctx, x, z, _, sz)
		local black = rgb(28, 22, 20)
		local back = z + sz * 0.5
		FloorDress.block(
			ctx,
			"Piano",
			x - 2.6,
			0,
			back - 0.8,
			x + 2.6,
			4.4,
			back + 0.8,
			black,
			M.Wood
		)
		local keys = back - sz * 1.2
		FloorDress.block(
			ctx,
			"PianoKeys",
			x - 2.4,
			2.4,
			math.min(back, keys),
			x + 2.4,
			2.7,
			math.max(back, keys),
			rgb(230, 224, 210)
		)
		local stool = back - sz * 2.4
		FloorDress.block(
			ctx,
			"Stool",
			x - 0.8,
			0,
			stool - 0.5,
			x + 0.8,
			1.6,
			stool + 0.5,
			black,
			M.Wood
		)
		FloorDress.solid(
			ctx,
			x - 2.6,
			math.min(back - 0.8, keys),
			x + 2.6,
			math.max(back + 0.8, keys),
			4.4
		)
	end,
}

-- A trolley of returned tapes on its way back to the shelves.
GROUPS.cart = {
	hx = 1.8,
	hz = 1.2,
	build = function(ctx, x, z)
		FloorDress.block(ctx, "Cart", x - 1.6, 0.6, z - 1, x + 1.6, 2.8, z + 1, GREY_METAL, M.Metal)
		for _, lx in { -1.3, 1.3 } do
			for _, lz in { -0.8, 0.8 } do
				FloorDress.block(
					ctx,
					"Wheel",
					x + lx - 0.15,
					0,
					z + lz - 0.15,
					x + lx + 0.15,
					0.6,
					z + lz + 0.15,
					Palette.Shadow
				)
			end
		end
		tapes(ctx, x - 0.85, 2.8, z, ctx.rng:NextInteger(2, 5))
		tapes(ctx, x + 0.85, 2.8, z, ctx.rng:NextInteger(1, 4))
		FloorDress.solid(ctx, x - 1.6, z - 1, x + 1.6, z + 1, 2.8)
	end,
}

-- Staff lockers, like the ones in the lobby's locker room.
GROUPS.lockers = {
	hx = 4.6,
	hz = 1,
	build = function(ctx, x, z, _, sz)
		local front = z - sz * 0.8
		for index = 0, 3 do
			local lx = x - 4.4 + index * 2.2
			FloorDress.block(
				ctx,
				"Locker",
				lx + 0.05,
				0,
				z - 0.8,
				lx + 2.15,
				8,
				z + 0.8,
				Palette.Metal,
				M.Metal
			)
			FloorDress.block(
				ctx,
				"LockerVent",
				lx + 0.5,
				6.6,
				math.min(front, front - sz * 0.05),
				lx + 1.7,
				7.2,
				math.max(front, front - sz * 0.05),
				Palette.Shadow
			)
		end
		FloorDress.solid(ctx, x - 4.4, z - 0.8, x + 4.4, z + 0.8, 8)
	end,
}

-- A reception counter with a bell, the way the real lobby has one.
GROUPS.reception = {
	hx = 4.6,
	hz = 1.6,
	build = function(ctx, x, z, _, sz)
		FloorDress.block(
			ctx,
			"Counter",
			x - 4.4,
			0,
			z - 1.3,
			x + 4.4,
			3.6,
			z + 1.3,
			rgb(150, 120, 104),
			M.Wood
		)
		FloorDress.block(
			ctx,
			"CounterTop",
			x - 4.6,
			3.6,
			z - 1.5,
			x + 4.6,
			3.8,
			z + 1.5,
			rgb(46, 36, 30)
		)
		FloorDress.prop(ctx, "Bell", x + 2.6, 3.8, z, 0)
		FloorDress.prop(ctx, "Crt", x - 2, 3.8, z, if sz > 0 then 0 else math.pi, 0.7)
		FloorDress.solid(ctx, x - 4.6, z - 1.5, x + 4.6, z + 1.5, 3.8)
	end,
}

local COMMUNITY: { [string]: { string } } = {
	lobby = { "bench", "plant", "bench", "plant" },
	hall = { "chairs", "chairs", "piano", "plant" },
	office = { "desk", "desk", "cabinets", "plant" },
	storage = { "shelf", "boxes", "shelf", "cabinets" },
	cloakroom = { "coats", "coats", "bench", "plant" },
	corridor = { "bench", "plant", "plant", "bench" },
}
local EVENING: { [string]: { string } } = {
	hall = { "tables", "chairs", "piano", "tables" },
}
local STORES: { [string]: { string } } = {
	lobby = { "cart", "boxes", "boxes", "cart" },
	office = { "desk", "shelf", "cabinets", "cart" },
	default = { "shelf", "shelf", "shelf", "boxes", "cart" },
}
local LOBBY: { [string]: { string } } = {
	lobby = { "reception", "plant", "reception", "bench" },
	hall = { "shelf", "shelf", "chairs", "plant" },
	office = { "desk", "desk", "shelf", "plant" },
	storage = { "shelf", "shelf", "boxes", "shelf" },
	cloakroom = { "lockers", "lockers", "bench", "plant" },
	corridor = { "plant", "bench", "shelf", "plant" },
}

local function choices(look: FloorLooks.Look, kind: string): { string }
	if look.name == "stores" then
		return STORES[kind] or STORES.default
	elseif look.name == "lobby" then
		return LOBBY[kind] or COMMUNITY.hall
	elseif look.name == "evening" and EVENING[kind] then
		return EVENING[kind]
	end
	return COMMUNITY[kind] or COMMUNITY.hall
end

local QUADRANTS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

-- One group in each corner of the room where one fits. `skip` lists corners (by index) that a
-- special room keeps for itself.
function FloorDress.furnish(ctx: Ctx, skip: { [number]: boolean }?)
	local list = choices(ctx.look, ctx.kind)
	for index, quadrant in QUADRANTS do
		local name = list[ctx.rng:NextInteger(1, #list)]
		if skip and skip[index] then
			continue
		end
		if ctx.look.inverted and name == "shelf" then
			name = "cabinets"
		end
		local group = GROUPS[name]
		local sx, sz = quadrant[1], quadrant[2]
		-- The middle of the corner first, then pushed into the corner.
		local anchors = {
			{ sx * 11, sz * 11 },
			{ sx * (RoomLayout.INNER - group.hx - 0.4), sz * (RoomLayout.INNER - group.hz - 0.4) },
			{ sx * 11, sz * (RoomLayout.INNER - group.hz - 0.4) },
		}
		for _, anchor in anchors do
			local x, z = anchor[1], anchor[2]
			if
				RoomLayout.free(
					{ x - group.hx, z - group.hz, x + group.hx, z + group.hz },
					ctx.spots
				)
			then
				group.build(ctx, x, z, sx, sz)
				break
			end
		end
	end
	if ctx.kind == "corridor" then
		FloorDress.curtains(ctx)
	end
end

-- Curtains along both side walls, parted where a doorway may be, and soft: nobody should be
-- walled in by fabric.
function FloorDress.curtains(ctx: Ctx)
	local color = if ctx.look.name == "lobby" then rgb(92, 30, 30) else Palette.Curtain
	for _, side in { -1, 1 } do
		local wx = side * (RoomLayout.INNER - 0.7)
		for _, span in { { -12, -4.5 }, { 4.5, 12 } } do
			-- Gathered into folds, so they read as fabric and not as a wall.
			local folds = 6
			local width = (span[2] - span[1]) / folds
			for fold = 0, folds - 1 do
				local depth = if fold % 2 == 0 then 0.3 else 0.12
				local z0 = span[1] + fold * width
				FloorDress.block(
					ctx,
					"Curtain",
					wx - depth,
					0.2,
					z0,
					wx + depth,
					H - 0.4,
					z0 + width,
					color,
					M.Fabric
				)
			end
		end
		FloorDress.block(
			ctx,
			"CurtainRail",
			wx - 0.1,
			H - 0.4,
			-12.2,
			wx + 0.1,
			H - 0.2,
			12.2,
			Palette.Metal,
			M.Metal
		)
	end
end

-- The wall in room coordinates: where its inner face is and which way it faces.
-- Returns the face position on the axis across the wall, the inward normal sign, and whether
-- the wall runs along X.
function FloorDress.wallFace(side: string): (number, number, boolean)
	local inner = RoomLayout.INNER
	if side == "south" then
		return -inner, 1, true
	elseif side == "north" then
		return inner, -1, true
	elseif side == "west" then
		return -inner, 1, false
	end
	return inner, -1, false
end

-- A flat thing on a wall: `u` along it, from y0 to y1, standing `depth` off the face.
function FloorDress.onWall(
	ctx: Ctx,
	name: string,
	side: string,
	u0: number,
	u1: number,
	y0: number,
	y1: number,
	depth: number,
	color: Color3,
	material: Enum.Material?
): Part
	local face, normal, alongX = FloorDress.wallFace(side)
	local a, b = face, face + normal * depth
	local lo, hi = math.min(a, b), math.max(a, b)
	if alongX then
		return FloorDress.block(ctx, name, u0, y0, lo, u1, y1, hi, color, material)
	end
	return FloorDress.block(ctx, name, lo, y0, u0, hi, y1, u1, color, material)
end

-- The NormalId of a wall-mounted part's face that looks into the room.
function FloorDress.faceOf(side: string): Enum.NormalId
	if side == "south" then
		return Enum.NormalId.Back
	elseif side == "north" then
		return Enum.NormalId.Front
	elseif side == "west" then
		return Enum.NormalId.Right
	end
	return Enum.NormalId.Left
end

local function normalOf(side: string): Vector3
	if side == "south" then
		return Vector3.zAxis
	elseif side == "north" then
		return -Vector3.zAxis
	elseif side == "west" then
		return Vector3.xAxis
	end
	return -Vector3.xAxis
end

local POSTERS = { "meeting", "cinema", "safety", "choir", "missing", "headcount" }

-- A cork board with notices pinned to it.
local function noticeBoard(ctx: Ctx, side: string, u: number)
	local cork = rgb(150, 112, 72)
	FloorDress.onWall(
		ctx,
		"NoticeFrame",
		side,
		u - 2.3,
		u + 2.3,
		4.4,
		7.8,
		0.15,
		Palette.WoodDark,
		M.Wood
	)
	FloorDress.onWall(ctx, "NoticeBoard", side, u - 2.1, u + 2.1, 4.6, 7.6, 0.18, cork, M.Fabric)
	for index = 0, 3 do
		local pu = u - 1.7 + index * 0.95 + ctx.rng:NextNumber(-0.08, 0.08)
		local py = ctx.rng:NextNumber(5, 6.6)
		FloorDress.onWall(ctx, "Notice", side, pu, pu + 0.75, py, py + 0.9, 0.2, Palette.Paper)
	end
end

-- A wall clock stopped at the archive's hour, 18:04 (the lobby's clock says the same).
local function clock(ctx: Ctx, side: string, u: number, y: number)
	local face, normal, alongX = FloorDress.wallFace(side)
	local depth = 0.2
	local yy = if ctx.look.inverted then H - y else y
	local across = face + normal * depth / 2
	local position = if alongX
		then Vector3.new(ctx.cx + u, yy, ctx.cz + across)
		else Vector3.new(ctx.cx + across, yy, ctx.cz + u)
	-- A cylinder's axis is its X: turn it to stand out of the wall.
	local axis = if alongX then CFrame.Angles(0, math.pi / 2, 0) else CFrame.new()
	Build.piece(
		ctx.folder,
		"Clock",
		CFrame.new(position) * axis,
		Vector3.new(depth, 2.2, 2.2),
		rgb(236, 232, 220),
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	local n = normalOf(side) * (depth / 2 + 0.03)
	local centre = position + n
	local spin = if ctx.look.inverted then math.pi else 0
	-- Hour hand just past six, minute hand on the four.
	for _, hand in { { 0.55, 0.12, math.rad(182) }, { 0.85, 0.08, math.rad(24) } } do
		local cf = CFrame.lookAt(centre, centre + normalOf(side))
			* CFrame.Angles(0, 0, -hand[3] + spin)
			* CFrame.new(0, hand[1] / 2, 0)
		Build.piece(ctx.folder, "ClockHand", cf, Vector3.new(hand[2], hand[1], 0.04), Palette.Ink)
	end
end

-- Wall dressing: up to two pieces per room, a third of the way along walls with no window in
-- that spot, where no doorway (always mid-wall) can be.
function FloorDress.walls(ctx: Ctx, sides: { string })
	local look = ctx.look
	for index, side in sides do
		if index > 2 then
			break
		end
		local u = if ctx.rng:NextNumber() < 0.5 then -10.5 else 10.5
		local roll = ctx.rng:NextNumber()
		if look.name == "stores" then
			-- Store numbers stencilled straight on the block.
			local plate = FloorDress.onWall(
				ctx,
				"Stencil",
				side,
				u - 3,
				u + 3,
				7.2,
				9.4,
				0.04,
				look.wall.color
			)
			plate.Transparency = 1
			local label = Build.label(
				plate,
				FloorDress.faceOf(side),
				`STORE {string.char(65 + ctx.id % 8)}{ctx.id}`,
				rgb(30, 30, 28)
			)
			label.Font = Enum.Font.Oswald
			if roll < 0.5 then
				-- A fuse box with a conduit up to the ceiling.
				FloorDress.onWall(
					ctx,
					"FuseBox",
					side,
					-u - 1,
					-u + 1,
					4,
					6.4,
					0.6,
					GREY_METAL,
					M.Metal
				)
				FloorDress.onWall(
					ctx,
					"Conduit",
					side,
					-u - 0.1,
					-u + 0.1,
					6.4,
					H,
					0.25,
					GREY_METAL,
					M.Metal
				)
			end
		elseif roll < 0.4 then
			noticeBoard(ctx, side, u)
		elseif roll < 0.75 then
			local poster = POSTERS[ctx.rng:NextInteger(1, #POSTERS)]
			local face, _, alongX = FloorDress.wallFace(side)
			local y = if look.inverted then H - 6.4 else 6.4
			local centre = if alongX
				then Vector3.new(ctx.cx + u, y, ctx.cz + face)
				else Vector3.new(ctx.cx + face, y, ctx.cz + u)
			local tilt = (if look.inverted then 180 else 0) + ctx.rng:NextNumber(-3, 3)
			Posters.hang(ctx.folder, poster, centre, normalOf(side), 2.8, tilt)
		else
			clock(ctx, side, u, 8.6)
		end
	end
end

return FloorDress
