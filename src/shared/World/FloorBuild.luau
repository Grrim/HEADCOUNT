--!strict
-- One floor of a shift as geometry, built from its data (Core/FloorGen) and its seed, the same
-- way every time. The shift server builds the floor players walk on with it; a client builds a
-- copy of a floor long gone into a ViewportFrame to play a shift tape back (client_common/TapeView).
--
-- Each depth has its own look (World/FloorLooks): the shell here (floors, walls, wall trim, door
-- frames, lamps, windows, the landing by the lift), the furniture in World/FloorDress, and the
-- hand-made special rooms in World/SpecialRooms.
--
-- Rules every piece keeps: surfaces meet at edges or clearly overlap and never share a plane
-- facing the same way (or they flicker: `lune run audit_map shift`); decor stops no lens or ray
-- (Build.decor); and nothing relies on a light to read, because a ViewportFrame has none.
local Build = require("./Build")
local FloorDress = require("./FloorDress")
local FloorGen = require("../Core/FloorGen")
local FloorLooks = require("./FloorLooks")
local RoomLayout = require("../Core/RoomLayout")
local SpecialRooms = require("./SpecialRooms")

local FloorBuild = {}

local CELL = FloorGen.CELL
local ROOM_HEIGHT = FloorDress.HEIGHT
local DOOR_HEIGHT = 9
local HALF_DOOR = FloorGen.DOOR_WIDTH / 2
-- A door frame's outer edge, from the doorway's middle; wall trim stops here.
local FRAME_EDGE = HALF_DOOR + 0.55
-- The lift's front wall fills the lobby's south wall between these (ShiftWorld).
local LIFT_HALF = 7
-- The lift's door portal (ShiftWorld) covers the front wall out to here.
local PORTAL_HALF = 3.9
local PORTAL_TOP = 9.6

FloorBuild.ROOM_HEIGHT = ROOM_HEIGHT

export type Look = FloorLooks.Look

function FloorBuild.look(depth: number): Look
	return FloorLooks.get(depth)
end

local rgb = Color3.fromRGB
local SIDES = { "south", "east", "north", "west" }

local function paint(part: BasePart, surface: FloorLooks.Surface)
	part.Color = surface.color
	part.Material = surface.material
	part.MaterialVariant = surface.variant or ""
end

-- The stretches of a wall left over once the gaps (doorways, the lift) are taken out.
local function spans(lo: number, hi: number, gaps: { { number } }): { { number } }
	local result = { { lo, hi } }
	for _, gap in gaps do
		local nextResult = {}
		for _, span in result do
			if gap[2] <= span[1] or gap[1] >= span[2] then
				table.insert(nextResult, span)
			else
				if gap[1] > span[1] then
					table.insert(nextResult, { span[1], gap[1] })
				end
				if gap[2] < span[2] then
					table.insert(nextResult, { gap[2], span[2] })
				end
			end
		end
		result = nextResult
	end
	return result
end

-- Skirting, a painted or panelled band and a rail along the inside of one wall, broken at its
-- doorway. Walls along Z start inside the trim of the walls along X, so corners meet at edges.
local function trim(ctx: FloorDress.Ctx, side: string, gaps: { { number } })
	local look = ctx.look
	local inner = RoomLayout.INNER
	local alongX = side == "south" or side == "north"
	local pieces: { { any } } = {
		-- name, bottom, top, depth from the wall, colour, material
		{ "Skirting", 0, 0.55, 0.2, look.skirting, Enum.Material.Wood },
	}
	if look.band then
		table.insert(pieces, {
			"Band",
			0,
			look.bandHeight,
			0.12,
			look.band.color,
			look.band.material,
			look.band.variant,
		})
		if look.rail then
			table.insert(pieces, {
				"Rail",
				look.bandHeight,
				look.bandHeight + 0.22,
				0.22,
				look.rail,
				Enum.Material.Wood,
			})
		end
	end
	for _, piece in pieces do
		local depth = piece[4]
		local inset = if alongX then 0 else depth
		-- Skirting tucks a little under the door frame, so its end never lines up with the band's.
		local reach = if piece[1] == "Skirting" then 0.05 else 0
		local cut = {}
		for _, gap in gaps do
			table.insert(cut, { gap[1] + reach, gap[2] - reach })
		end
		for _, span in spans(-inner + inset, inner - inset, cut) do
			local part = FloorDress.onWall(
				ctx,
				piece[1],
				side,
				span[1],
				span[2],
				piece[2],
				piece[3],
				depth,
				piece[5],
				piece[6]
			)
			if piece[7] then
				part.MaterialVariant = piece[7]
			end
		end
	end
end

-- A frame round a doorway, through the wall and proud of it on both sides. The jambs reach 0.15
-- into the opening to cover the wall's cut edge.
local function doorFrame(folder: Folder, look: Look, x: number, z: number, alongX: boolean)
	local function piece(a0: number, y0: number, a1: number, y1: number)
		local part = if alongX
			then Build.decor(
				folder,
				"DoorFrame",
				x + a0,
				y0,
				z - 0.75,
				x + a1,
				y1,
				z + 0.75,
				look.frame.color
			)
			else Build.decor(
				folder,
				"DoorFrame",
				x - 0.75,
				y0,
				z + a0,
				x + 0.75,
				y1,
				z + a1,
				look.frame.color
			)
		paint(part, look.frame)
	end
	piece(-FRAME_EDGE, 0, -HALF_DOOR + 0.15, DOOR_HEIGHT + 0.5)
	piece(HALF_DOOR - 0.15, 0, FRAME_EDGE, DOOR_HEIGHT + 0.5)
	piece(-HALF_DOOR + 0.15, DOOR_HEIGHT - 0.15, HALF_DOOR - 0.15, DOOR_HEIGHT + 0.5)
end

-- The room's light fittings, in the style of the depth. Returns nothing; a dead room keeps its
-- fittings, unlit. A flickering one is tagged for the client (Atmosphere) to stutter.
local function lamps(ctx: FloorDress.Ctx, dead: boolean, flicker: boolean)
	local look = ctx.look
	local folder = ctx.folder
	local cx, cz = ctx.cx, ctx.cz
	local glow = if dead then rgb(92, 94, 92) else look.lampColor
	local glowMaterial = if dead then Enum.Material.SmoothPlastic else Enum.Material.Neon
	local housing = rgb(196, 196, 190)

	-- An invisible part at the room's centre carries the one light of a panel, floor or pendant
	-- room, and the tag; the visible fittings hang off it so a flicker can find them.
	local holderY = if look.lamp == "floor" then 0.4 elseif look.lamp == "pendant" then 8.4 else 11.4
	local holder = Build.decor(
		folder,
		"Lamp",
		cx - 0.5,
		holderY - 0.5,
		cz - 0.5,
		cx + 0.5,
		holderY + 0.5,
		cz + 0.5,
		glow
	)
	holder.Transparency = 1
	if flicker then
		holder:AddTag("Flicker")
	end

	if look.lamp == "panel" then
		for _, u in { -7, 7 } do
			Build.decor(
				holder,
				"LampHousing",
				cx + u - 3.6,
				11.72,
				cz - 0.9,
				cx + u + 3.6,
				12,
				cz + 0.9,
				housing
			)
			Build.decor(
				holder,
				"LampTube",
				cx + u - 3.4,
				11.66,
				cz - 0.7,
				cx + u + 3.4,
				11.72,
				cz + 0.7,
				glow,
				glowMaterial
			)
		end
		if not dead then
			FloorDress.light(
				holder,
				look.lampColor,
				look.lampBrightness,
				look.lampRange,
				Enum.NormalId.Bottom
			)
		end
	elseif look.lamp == "floor" then
		for _, u in { -7, 7 } do
			Build.decor(
				holder,
				"LampHousing",
				cx + u - 3.6,
				0,
				cz - 0.9,
				cx + u + 3.6,
				0.04,
				cz + 0.9,
				rgb(70, 72, 74)
			)
			Build.decor(
				holder,
				"LampTube",
				cx + u - 3.4,
				0,
				cz - 0.7,
				cx + u + 3.4,
				0.07,
				cz + 0.7,
				glow,
				glowMaterial
			)
		end
		if not dead then
			FloorDress.light(
				holder,
				look.lampColor,
				look.lampBrightness,
				look.lampRange,
				Enum.NormalId.Top
			)
		end
	elseif look.lamp == "pendant" then
		for _, u in { -7, 7 } do
			Build.decor(
				holder,
				"PendantCord",
				cx + u - 0.05,
				9.6,
				cz - 0.05,
				cx + u + 0.05,
				12,
				cz + 0.05,
				rgb(40, 40, 40)
			)
			Build.decor(
				holder,
				"PendantShade",
				cx + u - 0.9,
				8.8,
				cz - 0.9,
				cx + u + 0.9,
				9.6,
				cz + 0.9,
				rgb(62, 66, 60),
				Enum.Material.Metal
			)
			Build.decor(
				holder,
				"PendantGlow",
				cx + u - 0.6,
				8.74,
				cz - 0.6,
				cx + u + 0.6,
				8.8,
				cz + 0.6,
				glow,
				glowMaterial
			)
		end
		if not dead then
			FloorDress.light(holder, look.lampColor, look.lampBrightness, look.lampRange)
		end
	else
		-- Bare bulbs in wire cages on cords, each with its own small light.
		for index, u in { -8, 8 } do
			local bz = if index == 1 then -4 else 4
			Build.decor(
				holder,
				"BulbCord",
				cx + u - 0.04,
				9.9,
				cz + bz - 0.04,
				cx + u + 0.04,
				12,
				cz + bz + 0.04,
				rgb(30, 30, 30)
			)
			Build.decor(
				holder,
				"BulbShade",
				cx + u - 1,
				9.6,
				cz + bz - 1,
				cx + u + 1,
				9.9,
				cz + bz + 1,
				rgb(46, 64, 52),
				Enum.Material.Metal
			)
			local bulb = Build.piece(
				holder,
				"Bulb",
				CFrame.new(cx + u, 9.2, cz + bz),
				Vector3.new(0.7, 0.7, 0.7),
				glow,
				glowMaterial,
				Enum.PartType.Ball
			)
			for _, turn in { 0, math.pi / 2 } do
				Build.piece(
					holder,
					"BulbCage",
					CFrame.new(cx + u, 9.15, cz + bz) * CFrame.Angles(0, turn, 0),
					Vector3.new(1.1, 0.9, 0.06),
					rgb(30, 30, 30),
					Enum.Material.Metal
				).Transparency =
					0.3
			end
			if not dead then
				FloorDress.light(bulb, look.lampColor, look.lampBrightness, look.lampRange)
			end
		end
	end
end

-- A window on an outer wall, with what is outside it: daylight on -1, dusk on -2.
local function window(ctx: FloorDress.Ctx, side: string)
	local day = ctx.look.windows == "day"
	local frame = rgb(226, 222, 210)
	local glass = if day then rgb(196, 214, 228) else rgb(34, 44, 86)
	local function on(
		name: string,
		u0: number,
		u1: number,
		y0: number,
		y1: number,
		depth: number,
		color: Color3,
		material: Enum.Material?
	)
		return FloorDress.onWall(ctx, name, side, u0, u1, y0, y1, depth, color, material)
	end
	on("WindowGlass", -3.8, 3.8, 4.6, 8.6, 0.04, glass, Enum.Material.Neon)
	if not day then
		-- The last of the light, low in the sky.
		on("WindowDusk", -3.8, 3.8, 4.6, 5.3, 0.05, rgb(150, 72, 40), Enum.Material.Neon)
	end
	on("WindowHead", -4.1, 4.1, 8.6, 8.9, 0.2, frame)
	on("WindowSill", -4.3, 4.3, 4.2, 4.6, 0.4, frame)
	on("WindowJamb", -4.1, -3.8, 4.6, 8.6, 0.2, frame)
	on("WindowJamb", 3.8, 4.1, 4.6, 8.6, 0.2, frame)
	on("WindowMullion", -0.08, 0.08, 4.6, 8.6, 0.12, frame)
	on("WindowTransom", -3.8, -0.08, 6.95, 7.1, 0.12, frame)
	on("WindowTransom", 0.08, 3.8, 6.95, 7.1, 0.12, frame)
	-- Blinds: up in the day, half down in the evening.
	for slat = 1, if day then 2 else 6 do
		local y = 8.6 - slat * 0.32
		on("Blind", -3.8, 3.8, y, y + 0.14, 0.08, rgb(220, 214, 196))
	end
	on("Radiator", -3, 3, 1, 3.2, 0.5, rgb(228, 224, 212), Enum.Material.Metal)
	for fin = 0, 4 do
		local u = -2.4 + fin * 1.2
		on("RadiatorFin", u - 0.1, u + 0.1, 1.1, 3.1, 0.6, rgb(214, 210, 198), Enum.Material.Metal)
	end
end

-- Lines on the floor along the way through the room: lane markings in the stores, a runner
-- with guide lights in the lobby that is not the lobby. Each arm runs from the centre to an open
-- wall; the arms along Z stop at the arms along X, and the two kinds sit at different heights.
local function waymarks(ctx: FloorDress.Ctx, open: { [string]: boolean })
	local look = ctx.look
	local inner = RoomLayout.INNER
	local west = if open.west then -inner else 0
	local east = if open.east then inner else 0
	local south = if open.south then -inner else 0
	local north = if open.north then inner else 0
	if look.name == "stores" then
		local lane = rgb(196, 160, 52)
		for _, off in { -3.4, 3.4 } do
			if west < east then
				FloorDress.block(ctx, "LaneLine", west, 0, off - 0.12, east, 0.03, off + 0.12, lane)
			end
			if south < north then
				FloorDress.block(
					ctx,
					"LaneLine",
					off - 0.12,
					0,
					south,
					off + 0.12,
					0.02,
					north,
					lane
				)
			end
		end
	elseif look.name == "lobby" then
		local runner = rgb(58, 34, 34)
		local green = rgb(80, 220, 120)
		-- Across the room through the centre, then north and south arms that stop at it.
		FloorDress.block(
			ctx,
			"Runner",
			math.min(west, -2.5),
			0,
			-2.5,
			math.max(east, 2.5),
			0.06,
			2.5,
			runner,
			Enum.Material.Fabric
		)
		if south < -2.5 then
			FloorDress.block(
				ctx,
				"Runner",
				-2.5,
				0,
				south,
				2.5,
				0.06,
				-2.5,
				runner,
				Enum.Material.Fabric
			)
		end
		if north > 2.5 then
			FloorDress.block(
				ctx,
				"Runner",
				-2.5,
				0,
				2.5,
				2.5,
				0.06,
				north,
				runner,
				Enum.Material.Fabric
			)
		end
		-- Green guide lights, airport-style, beside the runner: follow these and you are... here.
		for step = 2, 4 do
			local s = step * 4
			for _, sign in { -1, 1 } do
				local along = s * sign
				for _, off in { -3.1, 3.1 } do
					if along >= west and along <= east then
						FloorDress.block(
							ctx,
							"GuideLight",
							along - 0.15,
							0,
							off - 0.15,
							along + 0.15,
							0.08,
							off + 0.15,
							green,
							Enum.Material.Neon
						)
					end
					if along >= south and along <= north then
						FloorDress.block(
							ctx,
							"GuideLight",
							off - 0.15,
							0,
							along - 0.15,
							off + 0.15,
							0.08,
							along + 0.15,
							green,
							Enum.Material.Neon
						)
					end
				end
			end
		end
	end
end

-- The landing outside the lift, in the start room: the lift's front wall clad to match the floor,
-- and the depth painted large beside the doors, so every floor says which it is at a glance.
local function landing(ctx: FloorDress.Ctx)
	local look = ctx.look
	local folder = ctx.folder
	local z0, z1 = 0.5, 0.6
	local function clad(x0: number, y0: number, x1: number, y1: number)
		paint(
			Build.decor(folder, "LandingClad", x0, y0, z0, x1, y1, z1, look.frame.color),
			look.frame
		)
	end
	clad(-LIFT_HALF, 0, -PORTAL_HALF, ROOM_HEIGHT)
	clad(PORTAL_HALF, 0, LIFT_HALF, ROOM_HEIGHT)
	clad(-PORTAL_HALF, PORTAL_TOP, PORTAL_HALF, ROOM_HEIGHT)

	-- West of the lift, painted on the wall (on the inverted floor, upside down).
	local carrier =
		Build.decor(folder, "DepthSign", -16.5, 2.4, 0.5, -8, 10.4, 0.52, look.wall.color)
	carrier.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 1
	gui.MaxDistance = 140
	gui.Parent = carrier
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Rotation = if look.inverted then 180 else 0
	holder.Parent = gui
	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromScale(1, 0.78)
	number.Font = Enum.Font.Oswald
	number.TextScaled = true
	number.TextColor3 = look.signColor
	number.Text = look.sign
	number.Parent = holder
	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Position = UDim2.fromScale(0.05, 0.8)
	note.Size = UDim2.fromScale(0.9, 0.14)
	note.Font = Enum.Font.Oswald
	note.TextScaled = true
	note.TextColor3 = look.signColor
	note.Text = look.signNote
	note.Parent = holder
end

-- The floor's rooms, walls, lamps and furniture in a new folder, not yet parented. `lensView`
-- builds what only a lens shows as visible too (a tape is footage, so everything on it is).
function FloorBuild.build(floor: FloorGen.Floor, seed: number, lensView: boolean?): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Floor"
	local look = FloorBuild.look(floor.depth)
	local rng = Random.new(seed * 31 + floor.depth)

	for _, link in floor.links do
		local x, z, alongX = FloorGen.doorway(floor, link)
		doorFrame(folder, look, x, z, alongX)
	end

	for id = 1, floor.width * floor.height do
		local room = floor.rooms[id]
		local x0 = floor.originX + room.cx * CELL
		local z0 = floor.originZ + room.cz * CELL
		local x1, z1 = x0 + CELL, z0 + CELL
		local cx, cz = FloorGen.roomCentre(floor, id)
		paint(
			Build.box(folder, "Floor", x0, -1, z0, x1, 0, z1, look.wall.color),
			FloorLooks.floorOf(look, room.kind)
		)
		paint(
			Build.box(
				folder,
				"Ceiling",
				x0,
				ROOM_HEIGHT,
				z0,
				x1,
				ROOM_HEIGHT + 1,
				z1,
				look.wall.color
			),
			look.ceiling
		)

		-- South edge: a doorway to the room below, the lift for the start room, else solid.
		local walls = {}
		local southOpenings = {}
		if room.cz > 0 and FloorGen.linked(floor, id, id - floor.width) then
			table.insert(southOpenings, { cx - HALF_DOOR, cx + HALF_DOOR, 0, DOOR_HEIGHT })
		elseif id == floor.start then
			-- The lift's front wall stands in this gap.
			table.insert(southOpenings, { -LIFT_HALF, LIFT_HALF, 0, ROOM_HEIGHT })
		end
		table.insert(walls, Build.wallX(folder, "Wall", z0, x0, x1, 0, ROOM_HEIGHT, southOpenings))

		-- West edge: a doorway to the room on the left, else solid.
		local westOpenings = {}
		if room.cx > 0 and FloorGen.linked(floor, id, id - 1) then
			table.insert(westOpenings, { cz - HALF_DOOR, cz + HALF_DOOR, 0, DOOR_HEIGHT })
		end
		table.insert(walls, Build.wallZ(folder, "Wall", x0, z0, z1, 0, ROOM_HEIGHT, westOpenings))

		-- The outer north and east edges close the floor.
		if room.cz == floor.height - 1 then
			table.insert(walls, Build.wallX(folder, "Wall", z1, x0, x1, 0, ROOM_HEIGHT, {}))
		end
		if room.cx == floor.width - 1 then
			table.insert(walls, Build.wallZ(folder, "Wall", x1, z0, z1, 0, ROOM_HEIGHT, {}))
		end
		for _, list in walls do
			for _, part in list do
				paint(part, look.wall)
			end
		end

		local spots = {}
		for _, spot in floor.spots do
			if spot.room == id then
				table.insert(spots, { x = spot.x - cx, z = spot.z - cz })
			end
		end
		local ctx: FloorDress.Ctx = {
			folder = folder,
			look = look,
			floor = floor,
			id = id,
			kind = room.kind,
			cx = cx,
			cz = cz,
			rng = rng,
			spots = spots,
			lensView = lensView == true,
		}

		-- Wall trim, broken at doorways and at the lift; windows on the floor's outer walls. The
		-- wall a special room leans on gets neither a window nor dressing.
		local special = if room.special then floor.special else nil
		local open: { [string]: boolean } = {}
		local plain: { string } = {}
		for _, side in SIDES do
			open[side] = FloorGen.sideOpen(floor, id, side)
			local gaps = if open[side] then { { -FRAME_EDGE, FRAME_EDGE } } else {}
			local isLift = id == floor.start and side == "south"
			local isSpecial = special ~= nil and special.side == side
			if isLift then
				gaps = { { -LIFT_HALF, LIFT_HALF } }
			elseif isSpecial and special then
				local gap = SpecialRooms.trimGap(special)
				if gap then
					table.insert(gaps, gap)
				end
			end
			trim(ctx, side, gaps)
			local edge = (side == "south" and room.cz == 0)
				or (side == "north" and room.cz == floor.height - 1)
				or (side == "west" and room.cx == 0)
				or (side == "east" and room.cx == floor.width - 1)
			if edge and not isLift and not isSpecial and look.windows then
				window(ctx, side)
			elseif not isLift and not isSpecial then
				-- A corridor's side walls are curtained.
				local curtained = room.kind == "corridor" and (side == "east" or side == "west")
				if not curtained then
					table.insert(plain, side)
				end
			end
		end
		if id == floor.start then
			open.south = true
		end
		waymarks(ctx, open)

		-- Lamps: deeper floors lose some, never in the lobby.
		local deadRoll, flickerRoll = rng:NextNumber(), rng:NextNumber()
		-- House lights down in the auditorium: its screen lights it.
		local dead = (id ~= floor.start and deadRoll < look.dead) or room.special == "auditorium"
		lamps(ctx, dead, not dead and flickerRoll < look.flicker)

		-- Wall dressing on a few of the plain walls, starting from a different one each room.
		local first = rng:NextInteger(1, math.max(1, #plain))
		local order = {}
		for index = 0, #plain - 1 do
			table.insert(order, plain[(first + index - 1) % #plain + 1])
		end
		FloorDress.walls(ctx, order)

		local skip = nil
		if special then
			skip = SpecialRooms.build(ctx, special)
		end
		FloorDress.furnish(ctx, skip)
		if id == floor.start then
			landing(ctx)
		end
	end
	return folder
end

return FloorBuild
