--!strict
-- Gives Archive 03 somewhere to be between missions: a personnel board, a staff locker room, a
-- coffee machine, a television nobody turned off, and signs that treat the player as staff.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Props = require(ReplicatedStorage.Shared.World.Props)
local Surfaces = require(ReplicatedStorage.Shared.World.Surfaces)

local HubDressing = {}

HubDressing.prompts = {} :: { [string]: ProximityPrompt }

-- Matches the hall panels in HubWorld, so every lit surface agrees on what white is.
local WARM = Color3.fromRGB(252, 234, 202)
local PLANT_POT = Color3.fromRGB(88, 54, 40)
local PLANT_LEAF = Color3.fromRGB(52, 88, 50)

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
	return part
end

local function lockerRoom(folder: Folder)
	local C, F = Palette.Ceiling, Enum.Material.Fabric
	Build.box(folder, "LockerFloor", 40, -1, 8, 58, 0, 24, Palette.Carpet, F)
	Build.box(folder, "LockerCeiling", 40, 11, 8, 58, 12, 24, C)
	Build.wallZ(folder, "LockerEast", 58, 8, 24, 0, 11, {})
	Build.wallX(folder, "LockerSouth", 24, 40, 58, 0, 11, {})
	-- Starts where the hall's own east wall ends: overlapping it makes both surfaces flicker.
	Build.wallZ(folder, "LockerWestLow", 40, 20, 24, 0, 11, {}, Palette.WallDark)
	-- A row of grey lockers. The last one has the player's name on it (added by the client).
	for index = 0, 6 do
		local x = 42 + index * 2.2
		local door = Build.box(
			folder,
			`Locker{index + 1}`,
			x,
			0,
			22.4,
			x + 2.05,
			8,
			23.6,
			Palette.Metal,
			Enum.Material.Metal
		)
		door:AddTag("StaffLocker")
		door:SetAttribute("LockerIndex", index + 1)
		if index == 6 then
			Build.prompt(
				door,
				"act_open_locker",
				"obj_locker",
				nil,
				Config.Puzzle.PromptDistance + 2
			)
		end
	end
	Build.box(folder, "LockerBench", 44, 0, 15, 54, 1.8, 17, Palette.Wood, Enum.Material.Wood)
	Build.panel(folder, 49, 10.9, 16, 6, 2, 1.6, 22, WARM)
end

-- A lit box sign hanging from the ceiling on two wires, readable from the south (the side every
-- player approaches from, since the corridor enters the hall at its south wall).
local function hangingSign(
	folder: Folder,
	name: string,
	text: string,
	ink: Color3,
	cx: number,
	bottomY: number,
	cz: number,
	width: number,
	height: number
)
	local box = decor(
		folder,
		name,
		cx - width / 2,
		bottomY,
		cz - 0.3,
		cx + width / 2,
		bottomY + height,
		cz + 0.3,
		Palette.Shadow
	)
	box.CastShadow = false
	local label = Build.label(box, Enum.NormalId.Back, text, ink)
	local gui = label.Parent :: SurfaceGui
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	for _, x in { cx - width / 2 + 0.5, cx + width / 2 - 0.5 } do
		decor(
			folder,
			"SignWire",
			x - 0.04,
			bottomY + height,
			cz - 0.04,
			x + 0.04,
			26,
			cz + 0.04,
			Palette.Metal
		)
	end
end

-- Everything that answers "where am I and where do I go": a hanging directory just inside the
-- hall, arrows on it, guide lights along the runner, and a clock over the way back.
local function wayfinding(folder: Folder)
	-- At z = 16 the signs hang in the clear strip between the shelf rows (which end at z = 14)
	-- and the south wall, right where the corridor door frames the view.
	hangingSign(folder, "DirectorySign", "EXPEDITIONS  ^", Palette.Crt, 0, 11.4, 16, 11, 2.6)
	hangingSign(folder, "DirectoryEast", "TAPE ROOM  >\nPERSONNEL  >", WARM, 12.5, 11.4, 16, 8, 2.6)
	hangingSign(folder, "DirectoryWest", "<  RECORDS", WARM, -12.5, 11.4, 16, 8, 2.6)
	-- Low green guide lights along both edges of the runner, airport-style: follow these and you
	-- are at the terminal. They sit outside the runner so neither surface shares a plane.
	for _, x in { -3.6, 3.2 } do
		local z = 16
		while z >= -28 do
			local strip = decor(
				folder,
				"GuideLight",
				x,
				0,
				z - 0.6,
				x + 0.4,
				0.12,
				z + 0.6,
				Palette.Crt,
				Enum.Material.Neon
			)
			strip.CanQuery = false
			z -= 8
		end
	end
	-- A clock over the corridor door, hall side. 18:04 is the archive's hour: office hours on the
	-- television end at 18:04, and the mission's foyer clock starts there too.
	local clock = decor(folder, "HallClock", -2, 12, 19.35, 2, 13.8, 19.5, Palette.Shadow)
	clock.CastShadow = false
	local face = Build.label(clock, Enum.NormalId.Front, "18:04", Palette.Crt)
	local clockGui = face.Parent :: SurfaceGui
	clockGui.LightInfluence = 0
	clockGui.Brightness = 1.2
end

-- A potted plant: the cheapest way a room says someone waters something here.
local function plant(folder: Folder, x: number, z: number, tall: boolean?)
	local pot = Build.box(folder, "PlantPot", x - 0.7, 0, z - 0.7, x + 0.7, 1.1, z + 0.7, PLANT_POT)
	pot.Material = Enum.Material.SmoothPlastic
	local height = if tall then 5.2 else 3.6
	for index = 0, 2 do
		local spread = 0.9 - index * 0.25
		local leaf = Instance.new("Part")
		leaf.Name = "PlantLeaf"
		leaf.Shape = Enum.PartType.Ball
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.CanTouch = false
		leaf.Size = Vector3.new(2.4 * spread + 0.8, 1.8, 2.4 * spread + 0.8)
		leaf.Position = Vector3.new(x, 1.1 + (height - 1.1) * (index + 1) / 3, z)
		leaf.Color = PLANT_LEAF
		leaf.Material = Enum.Material.Grass
		leaf.Parent = folder
	end
end

-- A warm pendant lamp: a cord from the ceiling, a shade, and a pool of light under it.
local function pendant(folder: Folder, x: number, z: number, shadeY: number)
	decor(
		folder,
		"PendantCord",
		x - 0.05,
		shadeY + 0.8,
		z - 0.05,
		x + 0.05,
		26,
		z + 0.05,
		Palette.Metal
	)
	decor(
		folder,
		"PendantShade",
		x - 0.8,
		shadeY,
		z - 0.8,
		x + 0.8,
		shadeY + 0.8,
		z + 0.8,
		Palette.Metal,
		Enum.Material.Metal
	)
	local glow = decor(
		folder,
		"PendantGlow",
		x - 0.5,
		shadeY - 0.06,
		z - 0.5,
		x + 0.5,
		shadeY,
		z + 0.5,
		Palette.Bulb,
		Enum.Material.Neon
	)
	glow.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Palette.Bulb
	light.Brightness = 1.1
	light.Range = 14
	light.Parent = glow
end

-- A small wall lamp on the wainscot, so the long walls hold their own warmth.
local function sconce(folder: Folder, x: number, z: number, facing: number)
	local depth = 0.35 * facing
	local body = decor(
		folder,
		"Sconce",
		math.min(x, x + depth),
		6.8,
		z - 0.5,
		math.max(x, x + depth),
		7.8,
		z + 0.5,
		Palette.Bulb,
		Enum.Material.Neon
	)
	body.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Palette.Bulb
	light.Brightness = 0.7
	light.Range = 15
	light.Parent = body
end

-- Somewhere to wait that looks like waiting was intended: a rug, two chairs at the television,
-- a low table and a floor lamp. It sits between the west shelf row (which ends at x = -18) and
-- the runner, so the way to the terminal stays open.
local function waitingCorner(folder: Folder)
	decor(
		folder,
		"WaitingRug",
		-17,
		0,
		3.5,
		-6,
		0.1,
		13,
		Color3.fromRGB(96, 58, 42),
		Enum.Material.Fabric
	).CastShadow =
		false
	Build.chair(
		folder,
		"WaitChair1",
		CFrame.lookAt(Vector3.new(-14.5, 0, 10.5), Vector3.new(-12.5, 0, 2.5))
	)
	Build.chair(
		folder,
		"WaitChair2",
		CFrame.lookAt(Vector3.new(-8.5, 0, 10.5), Vector3.new(-11, 0, 2.5))
	)
	Build.box(
		folder,
		"WaitTable",
		-12.3,
		0,
		9.6,
		-10.7,
		1.6,
		11.2,
		Palette.WoodDark,
		Enum.Material.Wood
	)
	local mug = Instance.new("Part")
	mug.Name = "WaitMug"
	mug.Shape = Enum.PartType.Cylinder
	mug.Anchored = true
	mug.CanCollide = false
	mug.CanQuery = false
	mug.Size = Vector3.new(0.5, 0.4, 0.4)
	mug.CFrame = CFrame.new(-11.4, 1.85, 10.4) * CFrame.Angles(0, 0, math.rad(90))
	mug.Color = Palette.Paper
	mug.Parent = folder
	-- Floor lamp on the rug's corner
	decor(folder, "LampPole", -16.3, 0, 4.4, -16.1, 6.4, 4.6, Palette.Metal, Enum.Material.Metal)
	local shade = decor(
		folder,
		"LampShade",
		-16.9,
		6.4,
		3.8,
		-15.5,
		7.6,
		5.2,
		Color3.fromRGB(214, 186, 140),
		Enum.Material.Fabric
	)
	shade.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Palette.Bulb
	light.Brightness = 1.2
	light.Range = 16
	light.Parent = shade
end

-- The corridor between the workstation and the hall: wainscot, two sconces and a notice, so the
-- first walk of the game is down a kept hallway rather than a grey chute.
local function corridorDressing(folder: Folder)
	decor(folder, "Wainscot", -3.5, 0, 21, -3.35, 4.5, 39, Palette.Wood, Enum.Material.Wood)
	decor(folder, "Wainscot", 3.35, 0, 21, 3.5, 4.5, 39, Palette.Wood, Enum.Material.Wood)
	sconce(folder, -3.35, 26, 1)
	sconce(folder, 3.35, 34, -1)
	local poster = decor(folder, "CorridorNotice", 3.45, 3.4, 28, 3.5, 7, 32, Palette.Paper)
	poster.CastShadow = false
	Build.label(poster, Enum.NormalId.Left, "ARCHIVE 03\nREGISTRY HALL\nAHEAD", Palette.Ink)
end

-- A lit box sign over the terminal, readable from the corridor door sixty studs away.
local function expeditionSign(folder: Folder)
	local box = decor(folder, "ExpeditionSign", -7, 9.4, -31.2, 7, 12.2, -30.6, Palette.Shadow)
	box.CastShadow = false
	local label = Build.label(box, Enum.NormalId.Back, "EXPEDITIONS", Palette.Crt)
	local gui = label.Parent :: SurfaceGui
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Color = Palette.Crt
	glow.Brightness = 1.2
	glow.Range = 14
	glow.Angle = 100
	glow.Parent = box
	-- Two wires to the ceiling, so it hangs rather than floats.
	for _, x in { -6, 6 } do
		decor(folder, "SignWire", x - 0.04, 12.2, -30.94, x + 0.04, 26, -30.86, Palette.Metal)
	end
end

local function hallDetails(folder: Folder)
	-- Personnel board on the south wall of the hall, filled in by each client with their own face.
	local board = decor(
		folder,
		"PersonnelBoard",
		-30,
		5,
		19.2,
		-8,
		15,
		19.5,
		Palette.WoodDark,
		Enum.Material.Wood
	)
	board:AddTag("PersonnelBoard")

	-- Coffee machine beside reception: something to do with your hands while you wait.
	local machine =
		Build.box(folder, "CoffeeMachine", 19, 0, -2, 22, 7, 0, Palette.Metal, Enum.Material.Metal)
	Build.label(machine, Enum.NormalId.Back, "COFFEE", Palette.Crt)
	HubDressing.prompts.Coffee =
		Build.prompt(machine, "act_coffee", "hub_coffee", nil, Config.Puzzle.PromptDistance)

	-- A television left on, showing a looping notice. (Model replaces the blockout set below.)
	Build.box(folder, "TvStand", -16, 0, -1, -10, 3, 3, Palette.WoodDark, Enum.Material.Wood)
	Build.box(folder, "TvSet", -15.4, 3, -0.4, -10.6, 7, 2.6, Palette.Metal)
	local screen = decor(folder, "HallTv", -15, 3.5, 2.6, -11, 6.6, 2.72, Palette.Shadow)
	screen:AddTag("HallTv")
	local glow = Instance.new("PointLight")
	glow.Color = Palette.Crt
	glow.Brightness = 0.8
	glow.Range = 12
	glow.Parent = screen

	-- Signs
	local function sign(
		a: number,
		b: number,
		c: number,
		d: number,
		e: number,
		f: number,
		face: Enum.NormalId,
		text: string
	)
		local plate = decor(folder, "Sign", a, b, c, d, e, f, Palette.Paper)
		plate.CastShadow = false
		Build.label(plate, face, text, Palette.Ink)
	end
	sign(-3, 9.6, 19.3, 3, 11, 19.5, Enum.NormalId.Front, "WORKSTATIONS")
	sign(39.2, 9.6, -9, 39.4, 11, -3, Enum.NormalId.Left, "TAPE ROOM")
	sign(39.2, 9.6, 11, 39.4, 11, 17, Enum.NormalId.Left, "PERSONNEL")
	expeditionSign(folder)
end

-- The archive looks in use: stacked boxes, a tape cart, a ladder, a desk someone just left.
local function archiveClutter(folder: Folder)
	for index, spot in { { -14, -16 }, { -9, 10 }, { 12, -22 }, { 13, 8 }, { 8, -12 } } do
		local x, z = spot[1], spot[2]
		local height = 2 * (index % 3 + 1)
		local box = Build.box(
			folder,
			"Box",
			x,
			0,
			z,
			x + 2.6,
			height,
			z + 2.1,
			Color3.fromRGB(122, 98, 68),
			Enum.Material.Cardboard
		)
		box.Transparency = 1
		local boxes = Props.place(
			folder,
			"Boxes",
			CFrame.new(x + 1.3, 0, z + 1.05) * CFrame.Angles(0, index * 0.5, 0),
			Vector3.new(2.4, height / 2, 2.2)
		)
		-- The generated texture came out pink and a texture ignores Color, so these go plain card.
		boxes.TextureID = ""
		boxes.Color = Color3.fromRGB(122, 98, 68)
		boxes.Material = Enum.Material.Cardboard
	end
	-- A tape cart mid-aisle
	Build.box(
		folder,
		"CartBase",
		-18,
		1.4,
		-8,
		-14.4,
		1.7,
		-4.8,
		Palette.Metal,
		Enum.Material.Metal
	)
	Build.box(folder, "CartTop", -18, 3.8, -8, -14.4, 4.1, -4.8, Palette.Metal, Enum.Material.Metal)
	for index = 0, 5 do
		local x = -17.8 + index * 0.55
		decor(folder, "CartTape", x, 1.7, -7.8, x + 0.42, 3.2, -5, Palette.Ink)
		decor(folder, "CartTape", x, 4.1, -7.8, x + 0.42, 5.6, -5, Palette.Paper)
	end
	-- A ladder leaning on the west face of the shelves, whose units start at x = 17.5.
	local lean = math.rad(8)
	local footX = 14.6
	for side = 0, 1 do
		local z = -28 + side * 2
		local rail = decor(
			folder,
			"LadderRail",
			0,
			0,
			z,
			0.3,
			20,
			z + 0.3,
			Palette.Metal,
			Enum.Material.Metal
		)
		rail.CFrame = CFrame.new(footX + math.sin(lean) * 10, math.cos(lean) * 10, z + 0.15)
			* CFrame.Angles(0, 0, -lean)
	end
	for rung = 1, 11 do
		local y = rung * 1.65
		local x = footX + y * math.tan(lean)
		decor(
			folder,
			"LadderRung",
			x - 0.1,
			y,
			-28,
			x + 0.1,
			y + 0.2,
			-25.7,
			Palette.Metal,
			Enum.Material.Metal
		)
	end
	-- Door frames. They reach 0.15 into each opening to cover the wall's cut edge: a frame that only
	-- touches it would share a plane with the wall and flicker.
	local wood, grain = Palette.WoodDark, Enum.Material.Wood
	for _, door in { { 40, 3, 8 }, { 20, 4, 9 } } do
		local z, half, top = door[1], door[2], door[3]
		decor(
			folder,
			"DoorFrame",
			-half - 0.5,
			0,
			z - 0.7,
			-half + 0.15,
			top + 0.5,
			z + 0.7,
			wood,
			grain
		)
		decor(
			folder,
			"DoorFrame",
			half - 0.15,
			0,
			z - 0.7,
			half + 0.5,
			top + 0.5,
			z + 0.7,
			wood,
			grain
		)
		decor(
			folder,
			"DoorFrame",
			-half + 0.15,
			top - 0.15,
			z - 0.7,
			half - 0.15,
			top + 0.5,
			z + 0.7,
			wood,
			grain
		)
	end
	for _, door in { { -10, -2 }, { 10, 18 } } do
		local a, b = door[1], door[2]
		decor(folder, "DoorFrame", 39.3, 0, a - 0.5, 40.7, 9.5, a + 0.15, wood, grain)
		decor(folder, "DoorFrame", 39.3, 0, b - 0.15, 40.7, 9.5, b + 0.5, wood, grain)
		decor(folder, "DoorFrame", 39.3, 8.85, a + 0.15, 40.7, 9.5, b - 0.15, wood, grain)
	end
	-- Wainscoting and a stripe of carpet that points at the terminal.
	decor(
		folder,
		"Runner",
		-3,
		0,
		-30,
		3,
		0.1,
		19.5,
		Color3.fromRGB(58, 34, 34),
		Enum.Material.Fabric
	).CastShadow =
		false
	decor(folder, "Wainscot", -39.5, 0, 3, -39.2, 4.5, 19.5, Palette.Wood, Enum.Material.Wood)
	decor(folder, "Wainscot", -39.5, 0, -39.5, -39.2, 4.5, -7, Palette.Wood, Enum.Material.Wood)
	decor(folder, "Wainscot", 39.2, 0, -39.5, 39.5, 4.5, -11, Palette.Wood, Enum.Material.Wood)
end

function HubDressing.start()
	local map = Workspace:WaitForChild("Map")
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	lockerRoom(folder)
	hallDetails(folder)
	archiveClutter(folder)
	wayfinding(folder)
	waitingCorner(folder)
	corridorDressing(folder)
	-- Hall sconces on the wainscot (west face points east, east face points west).
	for _, z in { -30, -20, 8 } do
		sconce(folder, -39.2, z, 1)
	end
	for _, z in { -34, -16 } do
		sconce(folder, 39.2, z, -1)
	end
	-- Pendants over the reception counter.
	pendant(folder, 8, -1, 8.5)
	pendant(folder, 14, -1, 8.5)
	-- Plants: by the coffee machine, at the hall entrance, and a tall one by the terminal.
	plant(folder, 18.5, 3.5)
	plant(folder, -6, 17.5)
	plant(folder, 7, -35, true)
	local map2 = map
	local desk = map2:FindFirstChild("Desk") :: BasePart?
	if desk then
		desk.Transparency = 1
		Props.place(
			folder,
			"Desk",
			CFrame.new(0, 0, 45) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(1.43, 1.02, 1)
		)
	end
	-- The lamp's light stays on the old glowing box; the box itself gives way to the lamp model.
	local lampBox = map2:FindFirstChild("DeskLamp") :: BasePart?
	if lampBox then
		lampBox.Transparency = 1
		Props.place(
			folder,
			"DeskLamp",
			CFrame.new(-0.6, 3.2, 44.1) * CFrame.Angles(0, math.rad(-120), 0),
			1.1
		)
	end
	local bell = map2:FindFirstChild("ReceptionBell") :: BasePart?
	if bell then
		bell.Transparency = 1
		Props.place(folder, "Bell", CFrame.new(bell.Position.X, 3.8, bell.Position.Z))
	end
	-- The hall television stands on the floor, in its own cabinet.
	for _, name in { "TvStand", "TvSet" } do
		local old = folder:FindFirstChild(name) :: BasePart?
		if old then
			old.Transparency = 1
			old.CanCollide = false
		end
	end
	Props.place(folder, "Crt", CFrame.new(-13, 0, 1) * CFrame.Angles(0, math.pi, 0), 1.1)
	local screen = folder:FindFirstChild("HallTv") :: BasePart?
	if screen then
		screen.Size = Vector3.new(2.5, 1.75, 0.1)
		screen.Position = Vector3.new(-13.1, 3.2, 1.95)
	end
	-- Blockouts that stay, invisible, for collision and prompts; the models take their place.
	local function hide(parent: Instance, name: string)
		local part = parent:FindFirstChild(name) :: BasePart?
		if part then
			part.Transparency = 1
			part.CastShadow = false
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceGui") then
					child.Enabled = false
				end
			end
		end
	end
	local facingHall = CFrame.Angles(0, math.pi, 0)
	-- Reception keeps its veneer box; a dark laminate top makes it read as a counter.
	decor(folder, "CounterTop", 4.7, 3.6, -3.3, 17.3, 3.8, 1.3, Color3.fromRGB(46, 36, 30))
	hide(folder, "CoffeeMachine")
	Props.place(
		folder,
		"CoffeeMachine",
		CFrame.new(20.5, 0, -1) * facingHall,
		Vector3.new(1.21, 1.24, 0.83)
	)
	local coffeeSign = decor(folder, "CoffeeSign", 19.4, 7.1, -0.9, 21.6, 7.9, -0.8, Palette.Shadow)
	Build.label(coffeeSign, Enum.NormalId.Back, "COFFEE", Palette.Crt)
	-- The expedition terminal is an old set on a desk, with the sign on its screen.
	hide(map, "Terminal")
	Props.place(folder, "Desk", CFrame.new(0, 0, -32) * facingHall, Vector3.new(1.43, 1.02, 1))
	Props.place(folder, "Crt", CFrame.new(0, 3.2, -32) * facingHall)
	local terminalScreen =
		decor(folder, "TerminalScreen", -1.25, 5.3, -31.2, 1.05, 6.9, -31.1, Palette.Shadow)
	local screenText = Build.label(terminalScreen, Enum.NormalId.Back, "ARCHIVE 03", Palette.Crt)
	local screenGui = screenText.Parent :: SurfaceGui
	screenGui.LightInfluence = 0
	local screenGlow = Instance.new("PointLight")
	screenGlow.Color = Palette.Crt
	screenGlow.Brightness = 1.4
	screenGlow.Range = 10
	screenGlow.Parent = terminalScreen
	hide(map, "ArchiveTerminal")
	Props.place(folder, "Crt", CFrame.new(57.5, 0, -5) * CFrame.Angles(0, math.pi / 2, 0), 1.2)
	folder.Parent = map
	Surfaces.apply(map)
end

return HubDressing
