--!strict
-- The set dressing that makes a box read as a provincial community centre: wainscoting, pillars,
-- ceiling grid, drapes, signs and notices. No gameplay in here: everything is non-colliding unless
-- a player could plausibly bump into it, and removing this service must change nothing else.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Posters = require(ReplicatedStorage.Shared.World.Posters)
local Props = require(ReplicatedStorage.Shared.World.Props)
local Surfaces = require(ReplicatedStorage.Shared.World.Surfaces)

local MissionDressing = {}

-- Stage velvet. The first shade (70, 28, 30) read as black under the hall lights in the playtest.
local DRAPE = Color3.fromRGB(116, 38, 40)

local function decor(
	folder: Folder,
	name: string,
	a: number,
	b: number,
	c: number,
	d: number,
	e: number,
	f: number,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Build.box(folder, name, a, b, c, d, e, f, color, material)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

local function sign(
	folder: Folder,
	x: number,
	y: number,
	z: number,
	width: number,
	height: number,
	face: Enum.NormalId,
	text: string,
	paper: Color3,
	ink: Color3
)
	local alongX = face == Enum.NormalId.Front or face == Enum.NormalId.Back
	local halfX = if alongX then width / 2 else 0.05
	local halfZ = if alongX then 0.05 else width / 2
	local plate = decor(
		folder,
		"Sign",
		x - halfX,
		y - height / 2,
		z - halfZ,
		x + halfX,
		y + height / 2,
		z + halfZ,
		paper
	)
	plate.CastShadow = false
	Build.label(plate, face, text, ink)
end

local function hall(folder: Folder)
	local H = Layout.HALL
	local wood = Palette.Wood
	local mat = Enum.Material.Wood
	-- Wainscoting
	decor(folder, "Wainscot", H.minX + 0.5, 0, -4, H.minX + 0.8, 4.5, H.maxZ - 0.5, wood, mat)
	decor(folder, "Wainscot", H.maxX - 0.8, 0, -24, H.maxX - 0.5, 4.5, 20, wood, mat)
	decor(folder, "Wainscot", H.maxX - 0.8, 0, 28, H.maxX - 0.5, 4.5, H.maxZ - 0.5, wood, mat)
	sign(
		folder,
		H.maxX - 0.6,
		11,
		24,
		6,
		1,
		Enum.NormalId.Left,
		"DIRECTOR",
		Palette.Paper,
		Palette.Ink
	)
	-- The rear runs start where the side runs end, so no two tops share a corner (that flickered).
	decor(folder, "WainscotRear", H.minX + 0.8, 0, H.maxZ - 0.8, -5, 4.5, H.maxZ - 0.5, wood, mat)
	decor(folder, "WainscotRear", 5, 0, H.maxZ - 0.8, H.maxX - 0.8, 4.5, H.maxZ - 0.5, wood, mat)
	-- Pillars break up the side walls and give the eye something to count.
	-- Spaced to stay clear of the corridor door in the west wall.
	local z = 0
	while z <= 40 do
		decor(
			folder,
			"Pillar",
			H.minX + 0.5,
			0,
			z - 1,
			H.minX + 2,
			H.height,
			z + 1,
			Palette.WallDark
		)
		decor(
			folder,
			"Pillar",
			H.maxX - 2,
			0,
			z - 1,
			H.maxX - 0.5,
			H.height,
			z + 1,
			Palette.WallDark
		)
		z += 15
	end
	-- A few motes always hanging in the air over the seats. Lit by the room, so they vanish in the dark.
	local air = decor(folder, "HallAir", -32, 4, -20, 32, 16, 40, Palette.Ceiling)
	air.Transparency = 1
	air.CanCollide = false
	air.CanQuery = false
	air.CastShadow = false
	local motes = Instance.new("ParticleEmitter")
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Rate = 14
	motes.Lifetime = NumberRange.new(9, 14)
	motes.Speed = NumberRange.new(0.03, 0.15)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Size = NumberSequence.new(0.07)
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Color = ColorSequence.new(Palette.Paper)
	motes.LightEmission = 0.15
	motes.RotSpeed = NumberRange.new(-20, 20)
	motes.Parent = air

	-- Ceiling grid
	local gridZ = H.minZ + 6
	while gridZ < H.maxZ do
		local strip = decor(
			folder,
			"CeilingGrid",
			H.minX,
			H.height - 0.12,
			gridZ - 0.08,
			H.maxX,
			H.height,
			gridZ + 0.08,
			Palette.Shadow
		)
		strip.CastShadow = false
		gridZ += 6
	end
	local gridX = H.minX + 6
	while gridX < H.maxX do
		local strip = decor(
			folder,
			"CeilingGrid",
			gridX - 0.08,
			H.height - 0.12,
			H.minZ,
			gridX + 0.08,
			H.height,
			H.maxZ,
			Palette.Shadow
		)
		strip.CastShadow = false
		gridX += 6
	end
	-- Stage drapes between the screen (out to 14) and the hidden doors (from 16).
	for side = -1, 1, 2 do
		for fold = 0, 2 do
			local x = side * (14.5 + fold * 0.5)
			decor(
				folder,
				"Drape",
				x - 0.25,
				3,
				-39.3,
				x + 0.25,
				23,
				-38.7 + (fold % 2) * 0.4,
				DRAPE,
				Enum.Material.Fabric
			)
		end
	end
	-- Valance and banner across the top of the stage opening.
	decor(
		folder,
		"Valance",
		H.minX + 0.5,
		21.5,
		-24.4,
		H.maxX - 0.5,
		24,
		-23.9,
		DRAPE,
		Enum.Material.Fabric
	)
	sign(
		folder,
		0,
		20.4,
		-23.9,
		30,
		2,
		Enum.NormalId.Back,
		"STAFF MEETING  12 XI 1987",
		Palette.Paper,
		Palette.Rec
	)
	-- Lectern lamp base and mug on the desk: the desk is the room's only warm thing.
	local D = Layout.DESK
	local mug = Instance.new("Part")
	mug.Name = "Mug"
	mug.Shape = Enum.PartType.Cylinder
	mug.Anchored = true
	mug.CanCollide = false
	mug.Size = Vector3.new(0.8, 0.55, 0.55)
	mug.CFrame = CFrame.new(D.x + 2.4, D.y + 3.6, D.z) * CFrame.Angles(0, 0, math.rad(90))
	mug.Color = Palette.Paper
	mug.Parent = folder
	decor(
		folder,
		"Papers",
		D.x - 0.2,
		D.y + 3.2,
		D.z - 1,
		D.x + 1.4,
		D.y + 3.26,
		D.z + 0.6,
		Palette.Paper
	)
	-- Exit signs
	sign(
		folder,
		0,
		11,
		H.maxZ - 0.6,
		5,
		1,
		Enum.NormalId.Front,
		"EXIT",
		Color3.fromRGB(40, 90, 50),
		Palette.Paper
	)
	sign(
		folder,
		H.minX + 0.6,
		11,
		-9,
		5,
		1,
		Enum.NormalId.Right,
		"BACKSTAGE",
		Palette.Ink,
		Palette.Paper
	)
end

local function foyer(folder: Folder)
	local F = Layout.FOYER
	local wood = Palette.Wood
	decor(folder, "Wainscot", -23.5, 0, 56.5, -23.2, 4, 71.5, wood, Enum.Material.Wood)
	decor(
		folder,
		"Wainscot",
		F.maxX - 0.8,
		0,
		66,
		F.maxX - 0.5,
		4,
		F.maxZ - 0.5,
		wood,
		Enum.Material.Wood
	)
	decor(
		folder,
		"Wainscot",
		-5,
		0,
		F.maxZ - 0.8,
		F.maxX - 0.8,
		4,
		F.maxZ - 0.5,
		wood,
		Enum.Material.Wood
	)
	-- Doormat and a worn runner leading to the hall, so the floor points the way.
	decor(folder, "Runner", -3, 0, 46, 3, 0.1, 72, Color3.fromRGB(58, 34, 34), Enum.Material.Fabric).CastShadow =
		false
	-- Ticket window: a dim, warm-lit kiosk behind the glass instead of a black hole in the wall.
	sign(folder, 19, 8, 45.2, 8, 1.6, Enum.NormalId.Back, "TICKETS", Palette.Paper, Palette.Ink)
	local kiosk = decor(
		folder,
		"TicketKiosk",
		13,
		3.4,
		45.2,
		25,
		7,
		45.3,
		Color3.fromRGB(92, 70, 48),
		Enum.Material.Wood
	)
	kiosk.CastShadow = false
	local kioskLight = Instance.new("SurfaceLight")
	kioskLight.Face = Enum.NormalId.Back
	kioskLight.Color = Palette.Bulb
	kioskLight.Brightness = 0.6
	kioskLight.Range = 6
	kioskLight.Angle = 120
	kioskLight.Parent = kiosk
	decor(folder, "TicketLamp", 14, 6.5, 45.3, 24, 6.75, 45.38, Palette.Bulb, Enum.Material.Neon).CastShadow =
		false
	sign(folder, 19, 4.6, 45.35, 3.2, 0.9, Enum.NormalId.Back, "CLOSED", Palette.Paper, Palette.Rec)
	decor(
		folder,
		"TicketGlass",
		13,
		3.4,
		45.45,
		25,
		7,
		45.7,
		Color3.fromRGB(120, 140, 150),
		Enum.Material.Glass
	).Transparency =
		0.7
	-- Notice boards: readable set dressing that also tells the story.
	decor(
		folder,
		"NoticeBoard",
		4,
		3.5,
		F.maxZ - 1.0,
		22,
		10.5,
		F.maxZ - 0.7,
		Palette.WoodDark,
		Enum.Material.Wood
	)
	sign(
		folder,
		8,
		7.5,
		F.maxZ - 1.05,
		5,
		5,
		Enum.NormalId.Front,
		"MEETING\n12 XI\n18:00\nATTENDANCE\nCOMPULSORY",
		Palette.Paper,
		Palette.Ink
	)
	sign(
		folder,
		14,
		7,
		F.maxZ - 1.05,
		4.4,
		4,
		Enum.NormalId.Front,
		"Please do\nnot remove\nchairs from\nthe hall.",
		Palette.Paper,
		Palette.Ink
	)
	sign(
		folder,
		19.4,
		7.5,
		F.maxZ - 1.05,
		3.8,
		5,
		Enum.NormalId.Front,
		"LIST\nCLOSED\n192 / 192",
		Palette.Paper,
		Palette.Rec
	)
	-- A stopped clock over the hall doors.
	sign(folder, 0, 12, F.minZ + 0.6, 3, 1.4, Enum.NormalId.Back, "18:04", Palette.Ink, Palette.Rec)
	-- Coat room
	local K = Layout.COATS
	sign(
		folder,
		K.minX - 0.6,
		10.5,
		60,
		7,
		1.4,
		Enum.NormalId.Left,
		"CLOAKROOM",
		Palette.Paper,
		Palette.Ink
	)
	Build.box(
		folder,
		"CoatCounter",
		42,
		0,
		K.minZ + 1,
		44.5,
		3.4,
		K.maxZ - 12,
		Palette.Wood,
		Enum.Material.Wood
	)
	-- Direction to the booth, at the foot of the ramp.
	sign(folder, -23.3, 7, 70, 5, 1.2, Enum.NormalId.Right, "BOOTH", Palette.Paper, Palette.Ink)
end

local function booth(folder: Folder)
	-- Film cans on shelves, and a stool nobody has moved in decades.
	for level = 0, 2 do
		local y = 15.5 + level * 2.4
		decor(
			folder,
			"ShelfBoard",
			12,
			y,
			54.5,
			19.4,
			y + 0.25,
			55.5,
			Palette.WoodDark,
			Enum.Material.Wood
		)
		for can = 0, 4 do
			local x = 13 + can * 1.4
			decor(
				folder,
				"FilmCan",
				x,
				y + 0.25,
				54.7,
				x + 1.1,
				y + 1.4,
				55.4,
				Palette.Metal,
				Enum.Material.Metal
			)
		end
	end
	decor(folder, "Stool", -3.8, 14, 50, -2.4, 16.2, 51.4, Palette.WoodDark, Enum.Material.Wood)
end

local function corridor(folder: Folder)
	local R = Layout.CORRIDOR
	-- Framed photographs of past meetings, each a row of pale dots on black. They hang north of the
	-- door into the hall, which is open from -13 to -5.
	for _, z in { -28, -24, -20, -16 } do
		sign(
			folder,
			Layout.HALL.minX - 0.6,
			7,
			z,
			2.6,
			2,
			Enum.NormalId.Left,
			"· · · · ·\n· · · · ·",
			Palette.Ink,
			Palette.Paper
		)
	end
	decor(
		folder,
		"Runner",
		R.minX + 2,
		0,
		-21,
		Layout.HALL.minX - 1.5,
		0.1,
		-5,
		Color3.fromRGB(58, 34, 34),
		Enum.Material.Fabric
	).CastShadow =
		false
end

local function archive(folder: Folder)
	local A = Layout.ARCHIVE
	-- Tapes spilled across the floor near the register, inside the aisle between the shelves.
	for index = 0, 14 do
		local angle = index * 2.4
		local radius = 3 + index * 0.25
		local x = math.cos(angle) * radius
		local z = A.minZ + 14 + math.sin(angle) * radius
		local tape = decor(
			folder,
			"Tape",
			x - 0.7,
			A.floorY,
			z - 0.4,
			x + 0.7,
			A.floorY + 0.28,
			z + 0.4,
			-- Pure ink reads as a stain on this carpet, not as an object.
			Color3.fromRGB(74, 70, 64)
		)
		tape.CFrame *= CFrame.Angles(0, angle, 0)
	end
	sign(
		folder,
		0,
		10.5,
		A.minZ + 0.6,
		10,
		1.8,
		Enum.NormalId.Back,
		"PERSONNEL",
		Palette.Paper,
		Palette.Ink
	)
end

-- How far a door frame reaches into its opening. It must cover the cut edge of the wall: a frame
-- that merely touches it shares a plane with the wall and flickers as the player moves.
local FRAME_INSET = 0.15

-- A wooden door frame around an opening in a wall along X (fixed z) or Z (fixed x).
local function frameX(
	folder: Folder,
	z: number,
	minX: number,
	maxX: number,
	bottom: number,
	top: number
)
	local c = Palette.WoodDark
	local m = Enum.Material.Wood
	local i = FRAME_INSET
	decor(folder, "DoorFrame", minX - 0.5, bottom, z - 0.7, minX + i, top + 0.5, z + 0.7, c, m)
	decor(folder, "DoorFrame", maxX - i, bottom, z - 0.7, maxX + 0.5, top + 0.5, z + 0.7, c, m)
	decor(folder, "DoorFrame", minX + i, top - i, z - 0.7, maxX - i, top + 0.5, z + 0.7, c, m)
end

local function frameZ(
	folder: Folder,
	x: number,
	minZ: number,
	maxZ: number,
	bottom: number,
	top: number
)
	local c = Palette.WoodDark
	local m = Enum.Material.Wood
	local i = FRAME_INSET
	decor(folder, "DoorFrame", x - 0.7, bottom, minZ - 0.5, x + 0.7, top + 0.5, minZ + i, c, m)
	decor(folder, "DoorFrame", x - 0.7, bottom, maxZ - i, x + 0.7, top + 0.5, maxZ + 0.5, c, m)
	decor(folder, "DoorFrame", x - 0.7, top - i, minZ + i, x + 0.7, top + 0.5, maxZ - i, c, m)
end

local function openings(folder: Folder)
	local H = Layout.HALL
	frameX(folder, H.maxZ, -5, 5, 0, 10)
	frameZ(folder, H.minX, -13, -5, 0, 10)
	frameZ(folder, H.minX, -38, -30, 3, 12)
	frameZ(folder, H.maxX, 20, 28, 0, 10)
	frameZ(folder, Layout.FOYER.maxX, 54, 66, 0, 9)
	frameZ(folder, Layout.CORRIDOR.minX, -14, -8, 0, 9)
	-- The hall's double doors stand open, one leaf either side.
	for side = -1, 1, 2 do
		local x = side * 5.2
		decor(
			folder,
			"HallDoorLeaf",
			x - 0.2,
			0,
			44.6,
			x + 0.2,
			10,
			49.5,
			Palette.Wood,
			Enum.Material.Wood
		)
	end
end

-- Tall windows on the foyer's blind wall: cold light from a street nobody has seen.
local function windows(folder: Folder)
	local F = Layout.FOYER
	for _, x in { -20, -12 } do
		local pane = decor(
			folder,
			"Window",
			x - 2.5,
			3.5,
			F.maxZ - 0.75,
			x + 2.5,
			12,
			F.maxZ - 0.6,
			Color3.fromRGB(84, 108, 140),
			Enum.Material.Neon
		)
		pane.CastShadow = false
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 70
		light.Brightness = 1.4
		light.Range = 30
		light.Color = Color3.fromRGB(120, 150, 190)
		light.Shadows = true
		light.Parent = pane
		-- Glazing bars break up the shape and throw it onto the floor.
		decor(
			folder,
			"GlazingBar",
			x - 0.1,
			3.5,
			F.maxZ - 0.85,
			x + 0.1,
			12,
			F.maxZ - 0.75,
			Palette.Shadow
		)
		decor(
			folder,
			"GlazingBar",
			x - 2.5,
			7.6,
			F.maxZ - 0.85,
			x + 2.5,
			7.8,
			F.maxZ - 0.75,
			Palette.Shadow
		)
	end
end

-- Warm wall lamps: small pools between the cold ceiling panels.
local function sconces(folder: Folder)
	local H = Layout.HALL
	for _, wallZ in { 8, 22, 36 } do
		for side = -1, 1, 2 do
			local x = side * (H.maxX - 1)
			-- The office door takes up the east wall at 22, so that lamp hangs beside it instead.
			local z = if side > 0 and wallZ == 22 then 17.5 else wallZ
			local lamp = decor(
				folder,
				"Sconce",
				x - 0.4,
				9,
				z - 0.5,
				x + 0.4,
				10.4,
				z + 0.5,
				Palette.Bulb,
				Enum.Material.Neon
			)
			lamp.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = Palette.Bulb
			light.Brightness = 0.7
			light.Range = 13
			light.Parent = lamp
		end
	end
end

local function coatRail(folder: Folder)
	local K = Layout.COATS
	for row = 0, 3 do
		local y = 3 + row * 2.6
		decor(
			folder,
			"CoatRail",
			51.2,
			y,
			K.minZ + 1.5,
			51.5,
			y + 0.15,
			K.minZ + 26,
			Palette.Metal,
			Enum.Material.Metal
		)
	end
end

-- Swaps blockout boxes for their models. The box stays, invisible, for collision and prompts.
local function hide(map: Instance, name: string): BasePart?
	local part = map:FindFirstChild(name) :: BasePart?
	if part then
		part.Transparency = 1
		part.CastShadow = false
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") then
				child.Enabled = false
			end
		end
	end
	return part
end

local function heroProps(folder: Folder, map: Instance)
	local D = Layout.DESK
	hide(map, "Desk")
	Props.place(folder, "Desk", CFrame.new(D.x, D.y, D.z), Vector3.new(1.43, 1.02, 1))
	local R = Layout.REGISTER
	hide(map, "RegisterDesk")
	Props.place(folder, "Desk", CFrame.new(R.x, R.y, R.z), Vector3.new(0.86, 1.02, 0.75))
	hide(map, "DirectorDesk")
	Props.place(
		folder,
		"Desk",
		CFrame.new(52, 0, 23) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(1.43, 1.02, 1)
	)
	local bell = hide(map, "Bell")
	if bell then
		Props.place(folder, "Bell", CFrame.new(bell.Position.X, D.y + 3.3, bell.Position.Z))
	end
	local P = Layout.PROJECTOR
	hide(map, "Projector")
	Props.place(folder, "Projector", CFrame.new(P.x, P.y, P.z), 1.3)
	local recorder = hide(map, "Recorder")
	if recorder then
		Props.place(
			folder,
			"Recorder",
			CFrame.new(recorder.Position.X, 3.2, recorder.Position.Z),
			1.7
		)
	end
	local lamp = hide(map, "OfficeLamp")
	if lamp then
		Props.place(
			folder,
			"DeskLamp",
			CFrame.new(lamp.Position.X, 3.2, lamp.Position.Z) * CFrame.Angles(0, math.rad(90), 0),
			1.1
		)
	end
	local boiler = hide(map, "Boiler")
	if boiler then
		local foot = boiler.Position.Y - boiler.Size.Y / 2
		Props.place(folder, "Boiler", CFrame.new(boiler.Position.X, foot, boiler.Position.Z), 1.2)
	end
	for _, spool in map:GetChildren() do
		if spool.Name == "Spool" then
			(spool :: BasePart).Transparency = 1
		end
	end
	hide(map, "Bench")
	Props.place(
		folder,
		"Bench",
		CFrame.new(Layout.BENCH.x, 0, Layout.BENCH.z),
		Vector3.new(1.92, 1, 1.3)
	)
	-- Coats: the numbered tag stays readable, as a small paper tag above each one.
	local rack = map:FindFirstChild("Coats")
	if rack then
		for _, coat in rack:GetChildren() do
			local box = coat :: BasePart
			box.Transparency = 1
			box.CastShadow = false
			Props.place(
				rack,
				"Coat",
				CFrame.new(box.Position.X + 0.1, box.Position.Y - 1.15, box.Position.Z)
					* CFrame.Angles(0, math.rad(90), 0),
				0.95
			)
			local gui = box:FindFirstChildOfClass("SurfaceGui")
			local label = gui and gui:FindFirstChildOfClass("TextLabel")
			if label then
				label.Size = UDim2.fromScale(0.5, 0.26)
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Position = UDim2.fromScale(0.5, 0.02)
				label.BackgroundTransparency = 0
				label.BackgroundColor3 = Palette.Paper
				label.TextColor3 = Palette.Ink
			end
		end
	end
end

-- Bills on the walls between the pillars and below the sconces, and one by the foyer bench.
-- Each spot was checked against the pillars (z 0, 15, 30), the sconces (z 8, 17.5 and 22, 36 at
-- y 9 and up), the wainscot (up to y 4.5) and the doors (west z -13..-5, east z 20..28).
local function posters(folder: Folder)
	local H = Layout.HALL
	local west, east = H.minX + 0.5, H.maxX - 0.5
	local spots = {
		{ "safety", Vector3.new(west, 7, 4), Vector3.xAxis, 0 },
		{ "missing", Vector3.new(west, 7, 19), Vector3.xAxis, -2 },
		{ "choir", Vector3.new(west, 7, 40), Vector3.xAxis, 1 },
		{ "cinema", Vector3.new(east, 7, 4), -Vector3.xAxis, 0 },
		{ "headcount", Vector3.new(east, 7, 11.5), -Vector3.xAxis, 1.5 },
		{ "missing", Vector3.new(east, 7, 39), -Vector3.xAxis, 3 },
		{ "meeting", Vector3.new(-23.5, 7.2, 61), Vector3.xAxis, -1 },
	}
	for _, spot in spots do
		Posters.hang(folder, spot[1], spot[2], spot[3], 3, spot[4])
	end
end

function MissionDressing.start()
	local map = Workspace:WaitForChild("Map")
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	hall(folder)
	foyer(folder)
	booth(folder)
	corridor(folder)
	archive(folder)
	openings(folder)
	windows(folder)
	sconces(folder)
	posters(folder)
	coatRail(folder)
	heroProps(folder, map)
	folder.Parent = map
	Surfaces.apply(map)
end

return MissionDressing
