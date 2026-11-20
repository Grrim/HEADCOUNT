--!strict
-- Archive 03: the starting room, a corridor, the Registry Hall, the tape room, a room with no
-- door, and the Bureau's two lifts down to the shift behind the hall's east wall. Greybox, built
-- from code like the mission.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local LightingApply = require(ReplicatedStorage.Shared.World.LightingApply)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local HubWorld = {}

HubWorld.prompts = {} :: { [string]: ProximityPrompt }

export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

-- The lifts, north of the tape room. Openings in the east wall, then a cabin behind each.
local SOLO =
	{ open = { -37.5, -33.5 }, inside = { minX = 40.5, maxX = 47.5, minZ = -38.5, maxZ = -32.5 } }
local CREW = { open = { -29, -23 }, inside = { minX = 40.5, maxX = 49.5, minZ = -30, maxZ = -22 } }

-- Inside the crew cabin (anyone standing here is aboard); the doorway does not count.
HubWorld.soloCabin =
	{ minX = 40, maxX = SOLO.inside.maxX, minZ = SOLO.inside.minZ, maxZ = SOLO.inside.maxZ } :: Box
HubWorld.crewCabin =
	{ minX = 41, maxX = CREW.inside.maxX, minZ = CREW.inside.minZ, maxZ = CREW.inside.maxZ } :: Box

local PD = Config.Puzzle.PromptDistance

local function structure(map: Folder)
	local C, F = Palette.Ceiling, Enum.Material.Fabric
	local carpet = Palette.Carpet

	-- Workstation 03-B, where every player starts.
	Build.box(map, "RoomFloor", -10, -1, 40, 10, 0, 60, carpet, F)
	Build.box(map, "RoomCeiling", -10, 10, 40, 10, 11, 60, C)
	Build.wallZ(map, "RoomWest", -10, 40, 60, 0, 10, {})
	Build.wallZ(map, "RoomEast", 10, 40, 60, 0, 10, {})
	Build.wallX(map, "RoomSouth", 60, -10, 10, 0, 10, {})
	Build.wallX(map, "RoomNorth", 40, -10, 10, 0, 10, { { -3, 3, 0, 8 } })
	-- Each client opens this door for itself once its own intro is done.
	local door =
		Build.box(map, "IntroDoor", -3, 0, 39.6, 3, 8, 40.4, Palette.Wood, Enum.Material.Wood)
	door:AddTag("IntroDoor")

	-- Corridor
	Build.box(map, "CorridorFloor", -4, -1, 20, 4, 0, 40, carpet, F)
	-- Stops short of the hall wall, whose lintel sits at this same height.
	Build.box(map, "CorridorCeiling", -4, 9, 20.5, 4, 10, 40, C)
	Build.wallZ(map, "CorridorWest", -4, 20, 40, 0, 9, {})
	Build.wallZ(map, "CorridorEast", 4, 20, 40, 0, 9, {})

	-- Registry Hall
	Build.box(map, "HallFloor", -40, -1, -40, 40, 0, 20, carpet, F)
	Build.box(map, "HallCeiling", -40, 26, -40, 40, 27, 20, C)
	Build.wallX(map, "HallNorth", -40, -40, 40, 0, 26, {}, Palette.WallDark)
	Build.wallX(map, "HallSouth", 20, -40, 40, 0, 26, { { -4, 4, 0, 9 } }, Palette.WallDark)
	Build.wallZ(map, "HallEast", 40, -40, 20, 0, 26, {
		{ -10, -2, 0, 9 },
		{ 10, 18, 0, 9 },
		{ SOLO.open[1], SOLO.open[2], 0, 9 },
		{ CREW.open[1], CREW.open[2], 0, 9 },
	}, Palette.WallDark)
	Build.wallZ(map, "HallWest", -40, -40, 20, 0, 26, { { -6, 2, 0, 9 } }, Palette.WallDark)
	-- The west opening looks like wall. Only a lens shows the door in it.
	local plug = Build.box(map, "SecretPlug", -40.5, 0, -6, -39.5, 9, 2, Palette.WallDark)
	plug:AddTag("SecretPlug")

	-- Shelving to the ceiling: the hall should feel like the tapes outnumber everyone.
	for _, x in { -32, -22, 18, 28 } do
		Build.shelf(map, x, -34, x + 4, -12, 0, 24)
		Build.shelf(map, x, 2, x + 4, 14, 0, 24)
	end

	-- Tape room, east
	Build.box(map, "TapeFloor", 40, -1, -20, 60, 0, 8, Palette.WallDark, Enum.Material.Concrete)
	Build.box(map, "TapeCeiling", 40, 11, -20, 60, 12, 8, C)
	Build.wallZ(map, "TapeEast", 60, -20, 8, 0, 11, {})
	Build.wallX(map, "TapeNorth", -20, 40, 60, 0, 11, {})
	Build.wallX(map, "TapeSouth", 8, 40, 60, 0, 11, {})
	Build.shelf(map, 46, -18, 58, -14, 0, 10)
	Build.shelf(map, 46, 2, 58, 6, 0, 10)

	-- The room with no door, west
	Build.box(map, "SecretFloor", -60, -1, -14, -40, 0, 10, carpet, F)
	-- Same here: the lintel of the hidden door is at this height.
	Build.box(map, "SecretCeiling", -60, 9, -14, -40.5, 10, 10, C)
	Build.wallZ(map, "SecretWest", -60, -14, 10, 0, 9, {})
	Build.wallX(map, "SecretNorth", -14, -60, -40, 0, 9, {})
	Build.wallX(map, "SecretSouth", 10, -60, -40, 0, 9, {})
end

-- The hall's house light: warm white, so the archive reads as staffed rather than abandoned.
local WARM = Color3.fromRGB(252, 234, 202)

local function lights(map: Folder)
	local lamp =
		Build.box(map, "DeskLamp", -0.4, 3.6, 44.2, 0.4, 4, 45, Palette.Bulb, Enum.Material.Neon)
	lamp.CanCollide = false
	lamp.CastShadow = false
	local glow = Instance.new("PointLight")
	glow.Color = Palette.Bulb
	glow.Brightness = 2.4
	glow.Range = 24
	glow.Shadows = true
	glow.Parent = lamp
	Build.panel(map, 0, 9.9, 54, 3, 2, 1.4, 18, WARM)
	Build.panel(map, 0, 8.9, 30, 3, 2, 1.8, 22, WARM)
	-- A full grid over the hall. The aisles between the shelves get their own light, so no route
	-- the player can take is a walk into the dark; the terminal spot still wins on warmth.
	for _, x in { -26, 0, 26 } do
		for _, z in { -28, -6, 12 } do
			Build.panel(map, x, 25.9, z, 14, 3, 1.5, 48, WARM)
		end
	end
	local beam = Instance.new("Part")
	beam.Name = "TerminalSpot"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Transparency = 1
	beam.Size = Vector3.new(1, 1, 1)
	beam.CFrame = CFrame.lookAt(Vector3.new(0, 18, -22), Vector3.new(0, 3, -32))
	beam.Parent = map
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Color = Palette.Bulb
	spot.Brightness = 4
	spot.Range = 30
	spot.Angle = 34
	spot.Shadows = true
	spot.Parent = beam
	-- A few motes of dust turning in that light, the only movement in a still room.
	local air = Instance.new("Part")
	air.Name = "TerminalDust"
	air.Anchored = true
	air.CanCollide = false
	air.CanQuery = false
	air.CanTouch = false
	air.CastShadow = false
	air.Transparency = 1
	air.Size = Vector3.new(10, 9, 8)
	air.Position = Vector3.new(0, 7, -29)
	air.Parent = map
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 5
	dust.Lifetime = NumberRange.new(7, 11)
	dust.Speed = NumberRange.new(0.05, 0.25)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(0.07)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Color = ColorSequence.new(Palette.Bulb)
	dust.LightEmission = 0.4
	dust.RotSpeed = NumberRange.new(-20, 20)
	dust.Parent = air
	Build.panel(map, 50, 10.9, -6, 6, 3, 2.2, 26, WARM)
	Build.panel(map, -50, 8.9, -2, 3, 2, 1.6, 20, Palette.Bulb, true)
end

-- A camcorder in profile, lens towards the CRT, built from parts so it reads at a glance where
-- the old black box did not. The box stays, invisible, for the prompt and the intro tag; the
-- intro hides these parts with it when the camera is taken.
local function camcorderModel(holder: BasePart)
	holder.Transparency = 1
	local base = CFrame.new(3.7, 3.2, 45.3)
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		shape: Enum.PartType?
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = base * offset
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = holder
		return p
	end
	local body = Color3.fromRGB(38, 38, 42)
	piece("Body", Vector3.new(1.3, 0.62, 0.55), CFrame.new(0.1, 0.31, 0), body)
	piece(
		"Grip",
		Vector3.new(0.9, 0.35, 0.2),
		CFrame.new(0.15, 0.32, -0.36),
		Color3.fromRGB(24, 24, 26)
	)
	-- Cylinders run along their X axis, which is the lens axis here.
	piece(
		"Lens",
		Vector3.new(0.45, 0.46, 0.46),
		CFrame.new(-0.72, 0.33, 0),
		body,
		Enum.PartType.Cylinder
	)
	local glass = piece(
		"Glass",
		Vector3.new(0.04, 0.36, 0.36),
		CFrame.new(-0.96, 0.33, 0),
		Color3.fromRGB(60, 80, 110),
		Enum.PartType.Cylinder
	)
	glass.Material = Enum.Material.Glass
	glass.Reflectance = 0.3
	piece(
		"Viewfinder",
		Vector3.new(0.5, 0.2, 0.2),
		CFrame.new(0.55, 0.72, 0.12),
		body,
		Enum.PartType.Cylinder
	)
	local rec = piece(
		"RecLight",
		Vector3.new(0.08, 0.08, 0.08),
		CFrame.new(-0.3, 0.55, 0.28),
		Palette.Rec,
		Enum.PartType.Ball
	)
	rec.Material = Enum.Material.Neon
	-- A little light of its own, so the one thing to pick up is the one thing that shines.
	local cue = Instance.new("PointLight")
	cue.Color = Palette.Rec
	cue.Brightness = 0.6
	cue.Range = 3
	cue.Parent = rec
end

-- The inside of a cabin dressed as the Bureau's lift on the shift (ShiftWorld): steel kick plate,
-- veneer and a brass frieze, a handrail on the back wall, a brass plate behind the button with a
-- lamp for every floor, "0" lit. Layers meet at edges: the back wall's run the full width, the
-- side walls' start inside them, the front wall's stop at the door frame (HubDressing).
local function cabinInterior(map: Folder, name: string, spec: any)
	local box: Box = spec.inside
	local front, back = 40.5, box.maxX
	local layers: { { any } } = {
		{ "KickPlate", 0, 0.6, 0.15, Palette.Steel, Enum.Material.Metal },
		{ "Veneer", 0.6, 7, 0.12, Palette.Veneer, Enum.Material.Wood },
		{ "Frieze", 7, 7.25, 0.16, Palette.Brass, Enum.Material.Metal },
	}
	for _, layer in layers do
		local part, y0, y1, t, color, material =
			layer[1], layer[2], layer[3], layer[4], layer[5], layer[6]
		local made = {
			Build.decor(
				map,
				`{name}{part}`,
				back - t,
				y0,
				box.minZ,
				back,
				y1,
				box.maxZ,
				color,
				material
			),
			Build.decor(
				map,
				`{name}{part}`,
				front + t,
				y0,
				box.minZ,
				back - t,
				y1,
				box.minZ + t,
				color,
				material
			),
			Build.decor(
				map,
				`{name}{part}`,
				front + t,
				y0,
				box.maxZ - t,
				back - t,
				y1,
				box.maxZ,
				color,
				material
			),
			Build.decor(
				map,
				`{name}{part}`,
				front,
				y0,
				box.minZ,
				front + t,
				y1,
				spec.open[1] - 0.5,
				color,
				material
			),
			Build.decor(
				map,
				`{name}{part}`,
				front,
				y0,
				spec.open[2] + 0.5,
				front + t,
				y1,
				box.maxZ,
				color,
				material
			),
		}
		if part == "Veneer" then
			for _, piece in made do
				piece.MaterialVariant = "PK_Veneer"
			end
		end
	end
	-- A handrail along the back wall, on two posts.
	local railX = back - 0.5
	Build.piece(
		map,
		`{name}Handrail`,
		CFrame.new(railX, 3.3, (box.minZ + box.maxZ) / 2) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(box.maxZ - box.minZ - 1.2, 0.2, 0.2),
		Palette.Brass,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for _, z in { box.minZ + 1, box.maxZ - 1 } do
		Build.decor(
			map,
			`{name}HandrailPost`,
			railX,
			3.24,
			z - 0.06,
			back - 0.12,
			3.36,
			z + 0.06,
			Palette.Brass,
			Enum.Material.Metal
		)
	end
	-- The brass plate behind the button, a lamp for each floor, and the Bureau's number.
	local midZ = (box.minZ + box.maxZ) / 2
	local plate = Build.decor(
		map,
		`{name}Panel`,
		back - 0.2,
		2.6,
		midZ + 0.9,
		back,
		7,
		midZ + 2.9,
		Palette.Brass,
		Enum.Material.Metal
	)
	local engraved = Build.label(
		plate,
		Enum.NormalId.Left,
		if name == "SoloLift" then "BUREAU LIFT 1" else "BUREAU LIFT 2",
		Palette.Ink
	)
	engraved.Font = Enum.Font.SpecialElite
	engraved.Size = UDim2.fromScale(1, 0.1)
	engraved.Position = UDim2.fromScale(0, 0.03)
	for index = 0, 5 do
		local y = 6.1 - math.floor(index / 2) * 0.5
		local z = midZ + 1.5 + (index % 2) * 0.8
		local lit = index == 0
		Build.decor(
			map,
			`{name}FloorLamp`,
			back - 0.28,
			y - 0.15,
			z - 0.15,
			back - 0.2,
			y + 0.15,
			z + 0.15,
			if lit then Palette.LampLit else Color3.fromRGB(70, 64, 56),
			if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
	end
end

-- One lift cabin: a steel box with the Bureau's interior, a lamp, the button, and a sign over the
-- doorway in the hall. The back wall stands between the side walls so no two outer faces share a
-- plane at the corners.
local function liftCabin(map: Folder, name: string, spec: any, actionKey: string, objectKey: string)
	local box: Box = spec.inside
	local metal = Palette.Metal
	Build.box(
		map,
		`{name}Floor`,
		40,
		-1,
		box.minZ,
		box.maxX,
		0,
		box.maxZ,
		Color3.fromRGB(46, 46, 48),
		Enum.Material.DiamondPlate
	)
	Build.box(map, `{name}Ceiling`, 40.5, 9, box.minZ, box.maxX, 10, box.maxZ, Palette.Ceiling)
	Build.wallX(
		map,
		`{name}North`,
		box.minZ - 0.5,
		40.5,
		box.maxX + 1,
		0,
		10,
		{},
		metal,
		Enum.Material.Metal
	)
	Build.wallX(
		map,
		`{name}South`,
		box.maxZ + 0.5,
		40.5,
		box.maxX + 1,
		0,
		10,
		{},
		metal,
		Enum.Material.Metal
	)
	Build.box(
		map,
		`{name}Back`,
		box.maxX,
		0,
		box.minZ,
		box.maxX + 1,
		10,
		box.maxZ,
		metal,
		Enum.Material.Metal
	)
	cabinInterior(map, name, spec)
	local midZ = (box.minZ + box.maxZ) / 2
	Build.panel(map, (40.5 + box.maxX) / 2, 8.9, midZ, 3, 2, 1.3, 16, Palette.Bulb)
	local button = Build.box(
		map,
		`{name}Button`,
		box.maxX - 0.3,
		3.4,
		midZ + 1.5,
		box.maxX,
		4.4,
		midZ + 2.3,
		Palette.Rec,
		Enum.Material.Neon
	)
	button.CanCollide = false
	local prompt = Build.prompt(button, actionKey, objectKey, nil, 8, 0.4)
	-- Never through a wall: each button belongs to its own cabin.
	prompt.RequiresLineOfSight = true
	HubWorld.prompts[name] = prompt
	-- Over the doorway on the hall side; each client writes its own text on it (Lifts).
	local sign = Build.box(
		map,
		`{name}Sign`,
		39.2,
		9.6,
		spec.open[1] - 0.5,
		39.5,
		11.4,
		spec.open[2] + 0.5,
		Palette.Ink
	)
	sign.CanCollide = false
	local label = Build.label(sign, Enum.NormalId.Left, "", Palette.Rec)
	label.Name = "SignText";
	(label.Parent :: SurfaceGui).Name = "SignGui"
	sign:AddTag("LiftSign")
	sign:SetAttribute("Lift", name)
end

local function dressing(map: Folder)
	-- The starting room
	Build.box(map, "Desk", -5, 0, 43, 5, 3.2, 47, Palette.Wood, Enum.Material.Wood)
	local crt = Build.box(map, "Crt", -3.8, 3.2, 43.5, -1, 5.8, 45.5, Palette.Metal)
	local screen = Build.box(map, "CrtScreen", -3.6, 3.5, 45.5, -1.2, 5.5, 45.6, Palette.Shadow)
	screen.CanCollide = false
	screen.Name = "IntroScreen"
	crt.CastShadow = true
	local folder = Build.box(map, "Folder", 1.2, 3.2, 44.8, 2.8, 3.4, 46.2, Palette.Paper)
	folder.CanCollide = false
	HubWorld.prompts.Rules = Build.prompt(folder, "act_read", "obj_document", nil, PD)
	local camcorder = Build.box(map, "Camcorder", 3.1, 3.2, 44.8, 4.3, 3.9, 45.8, Palette.Ink)
	camcorder:AddTag("IntroCamera")
	camcorderModel(camcorder)
	local chair =
		Build.chair(map, "IntroChair", CFrame.new(-7, 0, 52) * CFrame.Angles(0, math.rad(40), 0))
	chair.CanCollide = true

	-- Registry Hall: reception with a bell to ring while waiting. It stands east of the runner,
	-- so the way from the corridor to the terminal is a straight, open line.
	Build.box(map, "Reception", 5, 0, -3, 17, 3.6, 1, Palette.Wood, Enum.Material.Wood)
	local bell = Instance.new("Part")
	bell.Name = "ReceptionBell"
	bell.Shape = Enum.PartType.Ball
	bell.Anchored = true
	bell.Size = Vector3.new(0.9, 0.9, 0.9)
	bell.Position = Vector3.new(14, 4, -1)
	bell.Color = Palette.Bulb
	bell.Material = Enum.Material.Metal
	bell.Parent = map
	HubWorld.prompts.Bell = Build.prompt(bell, "act_ring", "hub_bell", nil, PD)

	-- Expedition terminal and the board of case files beside it.
	local terminal = Build.box(map, "Terminal", -5, 0, -33, 5, 6, -31, Palette.Metal)
	Build.label(terminal, Enum.NormalId.Back, "ARCHIVE 03", Palette.Crt)
	HubWorld.prompts.Terminal = Build.prompt(terminal, "hub_open", "hub_terminal", nil, 9)
	terminal:AddTag("ExpeditionTerminal")
	local board = Build.box(map, "CaseBoard", 8, 4, -39.4, 16, 14, -39, Palette.WoodDark)
	board.CanCollide = false
	local file = Build.box(map, "CaseFile", 9, 8, -39, 11.5, 12, -38.8, Palette.Paper)
	file.CanCollide = false
	Build.label(file, Enum.NormalId.Back, "001", Palette.Ink)
	local sealed = Build.box(map, "CaseFileSealed", 12.5, 8, -39, 15, 12, -38.8, Palette.Rec)
	sealed.CanCollide = false
	Build.label(sealed, Enum.NormalId.Back, "002", Palette.Ink)

	-- Tape room archive terminal
	local archive = Build.box(map, "ArchiveTerminal", 56, 0, -7, 59, 5, -3, Palette.Metal)
	HubWorld.prompts.Docs = Build.prompt(archive, "hub_open", "hub_docs", nil, PD)

	-- A file only reachable through the hidden door.
	Build.box(map, "SecretDesk", -56, 0, -5, -52, 3.2, 1, Palette.WoodDark, Enum.Material.Wood)
	local secret = Build.box(map, "SecretFile", -55, 3.2, -3, -53.6, 3.4, -1.8, Palette.Paper)
	secret.CanCollide = false
	HubWorld.prompts.Secret = Build.prompt(secret, "act_read", "obj_document", nil, PD)
end

function HubWorld.init()
	LightingApply.apply("Hub")
	local base = Workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace
	structure(map)
	lights(map)
	dressing(map)
	liftCabin(map, "SoloLift", SOLO, "lift_go_alone", "lift_solo")
	liftCabin(map, "CrewLift", CREW, "lift_go_now", "lift_crew")
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Size = Vector3.new(6, 0.2, 4)
	spawn.Position = Vector3.new(0, 0.1, 54)
	spawn.Parent = map
end

return HubWorld
