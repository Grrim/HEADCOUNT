--!strict
-- The hand-made special rooms Core/FloorGen places now and then (docs/09_GDD_V2.md §8), so a
-- floor is never only the same few rooms shuffled:
--
--   auditorium  a hall set out for a screening: rows of empty seats facing a screen, house lights
--               down. Through the lens, every seat is taken.
--   meeting     a meeting room table with its chairs. Through the lens the meeting is on, and one
--               chair is free, with a card on the table that says it is for whoever comes next.
--   lift        a second lift door on a wall of an ordinary room, shut, its indicator lit,
--               counting people in a cabin that is not yours. It never opens.
--
-- What only a lens shows goes in a "LensOnly" folder, built invisible (the client's Atmosphere
-- controller shows it when the lens is up) or visible when building for a tape. Nothing here
-- scores or moves; the anomalies of the room are the usual ones.
--
-- A special room is laid out in its own frame, where the wall it leans on (`special.side`) is
-- +Z; Core/RoomLayout turns it into the room's.
local Build = require("./Build")
local FloorDress = require("./FloorDress")
local FloorGen = require("../Core/FloorGen")
local Palette = require("../Config/Palette")
local Props = require("./Props")
local RoomLayout = require("../Core/RoomLayout")

local SpecialRooms = {}

local H = FloorDress.HEIGHT
local INNER = RoomLayout.INNER
local rgb = Color3.fromRGB
local M = Enum.Material

type Ctx = FloorDress.Ctx

-- Quadrant indices as FloorDress numbers them: (-x,-z), (+x,-z), (-x,+z), (+x,+z).
local function quadrantOf(dx: number, dz: number): number
	return (if dx > 0 then 2 else 1) + (if dz > 0 then 2 else 0)
end

local BESIDE: { [string]: { number } } = {
	south = { 1, 2 },
	north = { 3, 4 },
	west = { 1, 3 },
	east = { 2, 4 },
}

-- A box given in the special's frame (x across, z towards its wall), turned into the room's.
local function box(
	ctx: Ctx,
	side: string,
	name: string,
	lx0: number,
	y0: number,
	lz0: number,
	lx1: number,
	y1: number,
	lz1: number,
	color: Color3,
	material: Enum.Material?
): Part
	local ax, az = RoomLayout.toWorld(lx0, lz0, side)
	local bx, bz = RoomLayout.toWorld(lx1, lz1, side)
	return FloorDress.block(
		ctx,
		name,
		math.min(ax, bx),
		y0,
		math.min(az, bz),
		math.max(ax, bx),
		y1,
		math.max(az, bz),
		color,
		material
	)
end

local function solid(
	ctx: Ctx,
	side: string,
	lx0: number,
	lz0: number,
	lx1: number,
	lz1: number,
	height: number
)
	local ax, az = RoomLayout.toWorld(lx0, lz0, side)
	local bx, bz = RoomLayout.toWorld(lx1, lz1, side)
	FloorDress.solid(
		ctx,
		math.min(ax, bx),
		math.min(az, bz),
		math.max(ax, bx),
		math.max(az, bz),
		height
	)
end

-- A place on the floor in the special's frame, looking along (fx, fz) of that frame.
local function placeAt(
	ctx: Ctx,
	side: string,
	lx: number,
	lz: number,
	fx: number,
	fz: number,
	y: number?
): CFrame
	local dx, dz = RoomLayout.toWorld(lx, lz, side)
	local wx, wz = RoomLayout.toWorld(fx, fz, side)
	local position = Vector3.new(ctx.cx + dx, y or 0, ctx.cz + dz)
	return CFrame.lookAt(position, position + Vector3.new(wx, 0, wz))
end

-- The face of a part in the special's frame that looks back along -Z (into the room from its wall).
local function faceToRoom(side: string): Enum.NormalId
	return FloorDress.faceOf(side)
end

-- The folder for what only a lens shows. Invisible unless the floor is built for a tape.
local function lensLayer(ctx: Ctx): Folder
	local layer = Instance.new("Folder")
	layer.Name = "LensOnly"
	layer:AddTag("LensOnly")
	layer.Parent = ctx.folder
	return layer
end

local function hideForEye(ctx: Ctx, layer: Folder)
	for _, part in layer:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			if not ctx.lensView then
				part:SetAttribute("LensTransparency", part.Transparency)
				part.Transparency = 1
			end
		end
	end
end

local function localSpots(ctx: Ctx, side: string): { RoomLayout.Point }
	local list = {}
	for _, spot in ctx.spots do
		local lx, lz = RoomLayout.toLocal(spot.x, spot.z, side)
		table.insert(list, { x = lx, z = lz })
	end
	return list
end

local function auditorium(ctx: Ctx, side: string): { [number]: boolean }
	local layer = lensLayer(ctx)
	local seats = RoomLayout.rows(localSpots(ctx, side))
	for index, seat in seats do
		local floor = placeAt(ctx, side, seat.x, seat.z, 0, 1)
		local chair = Props.place(ctx.folder, "Chair", floor, 1.5)
		chair.CastShadow = false
		solid(ctx, side, seat.x - 0.6, seat.z - 0.6, seat.x + 0.6, seat.z + 0.6, 1.6)
		Props.sitter(layer, floor, index + ctx.rng:NextInteger(0, 2))
	end

	-- The screen, and the stage curtains either side. Over a doorway if the wall has one.
	local wallOpen = FloorGen.sideOpen(ctx.floor, ctx.id, side)
	local bottom = if wallOpen then 9.7 else 3.6
	local top = if wallOpen then 11.7 else 9.8
	local half = if wallOpen then 5 else 7
	local screen =
		box(ctx, side, "Screen", -half, bottom, INNER - 0.08, half, top, INNER, rgb(232, 230, 222))
	local gui = Instance.new("SurfaceGui")
	gui.Face = faceToRoom(side)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = screen
	local leader = Instance.new("Frame")
	leader.BackgroundColor3 = rgb(214, 210, 198)
	leader.BorderSizePixel = 0
	leader.Size = UDim2.fromScale(1, 1)
	leader.Parent = gui
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.5, 0.5)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ring.BackgroundTransparency = 1
	ring.Parent = leader
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = rgb(60, 58, 54)
	stroke.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.Size = UDim2.fromScale(1, 1)
	count.Font = Enum.Font.Oswald
	count.TextScaled = true
	count.TextColor3 = rgb(40, 38, 36)
	count.Text = tostring(ctx.rng:NextInteger(1, 4))
	count.Parent = ring
	local glow = Instance.new("SurfaceLight")
	glow.Face = faceToRoom(side)
	glow.Angle = 110
	glow.Brightness = 1.1
	glow.Range = 30
	glow.Color = rgb(226, 230, 240)
	glow.Shadows = false
	glow.Parent = screen

	local curtain = rgb(98, 26, 30)
	for _, sign in { -1, 1 } do
		local a, b = sign * (half + 0.4), sign * (half + 2.8)
		for fold = 0, 3 do
			local u0 = math.min(a, b) + fold * 0.6
			local depth = if fold % 2 == 0 then 0.6 else 0.35
			box(
				ctx,
				side,
				"StageCurtain",
				u0,
				0.2,
				INNER - depth,
				u0 + 0.6,
				H - 0.6,
				INNER,
				curtain,
				M.Fabric
			)
		end
	end
	box(
		ctx,
		side,
		"Valance",
		-(half + 3),
		H - 1.6,
		INNER - 0.75,
		half + 3,
		H - 0.4,
		INNER,
		curtain,
		M.Fabric
	)

	-- The projector on a bracket at the back, and its beam across the dark room.
	box(
		ctx,
		side,
		"ProjectorShelf",
		-1.4,
		7.2,
		-INNER,
		1.4,
		7.4,
		-INNER + 2.6,
		Palette.WoodDark,
		M.Wood
	)
	local lensPoint = placeAt(ctx, side, 0, -INNER + 1.4, 0, 1, 7.4)
	Props.place(ctx.folder, "Projector", lensPoint, 1).CastShadow = false
	local from = (lensPoint * CFrame.new(0, 1.6, -1.2)).Position
	local tdx, tdz = RoomLayout.toWorld(0, INNER - 0.2, side)
	local target = Vector3.new(ctx.cx + tdx, (bottom + top) / 2, ctx.cz + tdz)
	local length = (target - from).Magnitude
	local beam = Build.piece(
		ctx.folder,
		"ProjectorBeam",
		CFrame.lookAt((from + target) / 2, target),
		Vector3.new(2.2, 1.6, length),
		rgb(255, 244, 214),
		M.Neon
	)
	beam.Transparency = 0.93
	hideForEye(ctx, layer)
	return { [1] = true, [2] = true, [3] = true, [4] = true }
end

local function meeting(ctx: Ctx, side: string): { [number]: boolean }
	local spots = localSpots(ctx, side)
	-- The table goes in the first corner of the room where it fits, nearest its wall first.
	for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local sx, sz = corner[1], corner[2]
		local x, z = sx * 11, sz * 10.8
		if RoomLayout.free({ x - 5.6, z - 4.4, x + 5.6, z + 4.4 }, spots) then
			local layer = lensLayer(ctx)
			local wood = rgb(124, 88, 60)
			box(
				ctx,
				side,
				"MeetingTable",
				x - 3.6,
				2.5,
				z - 1.4,
				x + 3.6,
				2.75,
				z + 1.4,
				wood,
				M.Wood
			)
			for _, lx in { -3.2, 3.2 } do
				box(
					ctx,
					side,
					"TableLeg",
					x + lx - 0.15,
					0,
					z - 1.1,
					x + lx + 0.15,
					2.5,
					z + 1.1,
					Palette.WoodDark,
					M.Wood
				)
			end
			solid(ctx, side, x - 3.6, z - 1.4, x + 3.6, z + 1.4, 2.75)
			-- Seats: three down each long side and one at each end. The far end is the free one.
			local seats = {}
			for _, along in { -2.4, 0, 2.4 } do
				table.insert(seats, { x + along, z - 2.6, 0, 1 })
				table.insert(seats, { x + along, z + 2.6, 0, -1 })
			end
			table.insert(seats, { x - 4.9, z, 1, 0 })
			table.insert(seats, { x + 4.9, z, -1, 0 })
			for index, seat in seats do
				local floor = placeAt(ctx, side, seat[1], seat[2], seat[3], seat[4])
				Props.place(ctx.folder, "Chair", floor, 1.5).CastShadow = false
				local card = placeAt(
					ctx,
					side,
					seat[1] + seat[3] * 1.6,
					seat[2] + seat[4] * 1.6,
					-seat[3],
					-seat[4],
					2.75
				)
				local tent = Build.piece(
					ctx.folder,
					"NameCard",
					card * CFrame.new(0, 0.22, 0),
					Vector3.new(0.9, 0.44, 0.06),
					Palette.Paper
				)
				if index == #seats then
					local label = Build.label(tent, Enum.NormalId.Front, "NEXT", Palette.Ink)
					label.Font = Enum.Font.SpecialElite
				else
					Props.sitter(layer, floor, index + ctx.rng:NextInteger(0, 2))
				end
			end
			-- A flip chart that has already done the count.
			local stand = placeAt(ctx, side, x + sx * 0.5, z + sz * 4, 0, -sz)
			Build.piece(
				ctx.folder,
				"FlipChartLeg",
				stand * CFrame.new(0, 2.6, 0),
				Vector3.new(0.15, 5.2, 0.15),
				Palette.Metal,
				M.Metal
			)
			local sheet = Build.piece(
				ctx.folder,
				"FlipChart",
				stand * CFrame.new(0, 4.6, -0.12),
				Vector3.new(2.6, 3.2, 0.06),
				Palette.Paper
			)
			local text =
				Build.label(sheet, Enum.NormalId.Front, "HEADCOUNT\n8 / 9", rgb(40, 50, 120))
			text.Font = Enum.Font.SpecialElite
			-- A lamp low over the table.
			local lamp = box(
				ctx,
				side,
				"MeetingLamp",
				x - 1.2,
				7.6,
				z - 0.5,
				x + 1.2,
				8,
				z + 0.5,
				Palette.Bulb,
				M.Neon
			)
			box(
				ctx,
				side,
				"MeetingLampCord",
				x - 0.05,
				8,
				z - 0.05,
				x + 0.05,
				H,
				z + 0.05,
				rgb(40, 40, 40)
			)
			if not ctx.look.inverted then
				FloorDress.light(lamp, Palette.Bulb, 0.9, 14)
			end
			hideForEye(ctx, layer)
			local dx, dz = RoomLayout.toWorld(x, z, side)
			return { [quadrantOf(dx, dz)] = true }
		end
	end
	return {}
end

local function otherLift(ctx: Ctx, side: string): { [number]: boolean }
	local metal = rgb(120, 124, 126)
	local dark = rgb(70, 72, 74)
	local wall = INNER
	local function on(
		name: string,
		u0: number,
		u1: number,
		y0: number,
		y1: number,
		depth: number,
		color: Color3,
		material: Enum.Material?
	): Part
		return box(ctx, side, name, u0, y0, wall - depth, u1, y1, wall, color, material)
	end
	-- Steel cladding round the doors, then the portal and the two shut leaves.
	on("LiftClad", -7, -4.2, 0, H, 0.1, dark, M.Metal)
	on("LiftClad", 4.2, 7, 0, H, 0.1, dark, M.Metal)
	on("LiftClad", -4.2, 4.2, 9.6, H, 0.1, dark, M.Metal)
	on("LiftPortal", -4.2, -3.2, 0, 9.6, 0.35, metal, M.Metal)
	on("LiftPortal", 3.2, 4.2, 0, 9.6, 0.35, metal, M.Metal)
	on("LiftPortal", -3.2, 3.2, 9, 9.6, 0.35, metal, M.Metal)
	on("LiftSeam", -3.2, 3.2, 0, 9, 0.1, Palette.Ink)
	on("LiftDoor", -3.2, -0.03, 0, 9, 0.2, rgb(150, 154, 156), M.Metal)
	on("LiftDoor", 0.03, 3.2, 0, 9, 0.2, rgb(150, 154, 156), M.Metal)
	-- Its indicator: this floor, and how many are inside.
	local sign = on("LiftIndicator", -2.4, 2.4, 10, 11.2, 0.3, Palette.Ink)
	local label = Build.label(
		sign,
		faceToRoom(side),
		`-{ctx.floor.depth}    PERSONS: {ctx.rng:NextInteger(5, 9)}`,
		Palette.Rec
	)
	local gui = label.Parent :: SurfaceGui
	gui.LightInfluence = 0
	on("LiftCallPlate", 5.1, 6.1, 3.4, 5.4, 0.15, metal, M.Metal)
	local button = on("LiftCallButton", 5.35, 5.85, 4.1, 4.6, 0.25, Palette.Rec, M.Neon)
	if not ctx.look.inverted then
		FloorDress.light(button, Palette.Rec, 0.6, 5)
	end
	return {
		[BESIDE[side][1]] = true,
		[BESIDE[side][2]] = true,
	}
end

-- Builds the special in its room and returns the corners of the room it uses, which the usual
-- furniture then leaves alone.
function SpecialRooms.build(roomCtx: Ctx, special: FloorGen.Special): { [number]: boolean }
	-- Hand-made rooms stand the right way up, even on the floor where nothing else does.
	local ctx = table.clone(roomCtx)
	local look = table.clone(roomCtx.look)
	look.inverted = false
	ctx.look = look
	if special.kind == "auditorium" then
		return auditorium(ctx, special.side)
	elseif special.kind == "meeting" then
		return meeting(ctx, special.side)
	elseif special.kind == "lift" then
		return otherLift(ctx, special.side)
	end
	return {}
end

-- The gap the special leaves in the wall trim of its side, if any (the other lift's cladding).
function SpecialRooms.trimGap(special: FloorGen.Special): { number }?
	if special.kind == "lift" then
		return { -7, 7 }
	end
	return nil
end

return SpecialRooms
