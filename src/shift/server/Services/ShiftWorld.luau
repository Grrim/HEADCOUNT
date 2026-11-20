--!strict
-- Builds the lift (once) and each floor (on every ride) from Core/FloorGen.
--
-- The lift is the one safe place in the game and a scene of its own (docs/09_GDD_V2.md §2.8): a
-- panelled Bureau cabin with a brass handrail, a control panel whose floor lamps follow the depth,
-- the PERSONS sign over the doors, the Bureau's notices on the walls, and on every landing a steel
-- portal with the depth over it. Its lamp grows dimmer and warmer the deeper it goes.
--
-- The lift never moves. It sits south of z = 0 and opens north into the start room; a ride clears
-- the floor outside the closed doors and builds the next one in its place.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local FloorBuild = require(ReplicatedStorage.Shared.World.FloorBuild)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local LightingApply = require(ReplicatedStorage.Shared.World.LightingApply)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Posters = require(ReplicatedStorage.Shared.World.Posters)

local ShiftWorld = {}

local ROOM_HEIGHT = 12
local DOOR_HEIGHT = 9

-- The cabin's inside: x -6..6, z -12..-0.5, floor at 0, ceiling at 10.
local LIFT = { minX = -6, maxX = 6, minZ = -12, maxZ = -0.5, height = 10 }

ShiftWorld.map = nil :: Folder?
ShiftWorld.floorFolder = nil :: Folder?
ShiftWorld.upPrompt = nil :: ProximityPrompt?
ShiftWorld.downPrompt = nil :: ProximityPrompt?
ShiftWorld.spawnCFrame = CFrame.new(0, 3, -7)

local doorLeft: Part
local doorRight: Part
local indicator: TextLabel
local outsideIndicator: TextLabel
local liftLight: PointLight
local floorLamps: { [string]: BasePart } = {}
local doorProgress = 1

local rgb = Color3.fromRGB
local BRASS = Palette.Brass
local STEEL = Palette.Steel
local VENEER = Palette.Veneer
local LIT = Palette.LampLit
local UNLIT = rgb(70, 64, 56)
-- The floors on the control panel, top to bottom.
local PANEL_FLOORS = { "0", "-1", "-2", "-3", "-4", "-5" }

local function lookFor(depth: number): FloorBuild.Look
	return FloorBuild.look(depth)
end

-- Behind the door leaves (they sit at z -1.2..-0.8), so nobody in the doorway counts as aboard.
ShiftWorld.INSIDE_MAX_Z = -1.3

function ShiftWorld.inLift(position: Vector3): boolean
	return position.X >= LIFT.minX
		and position.X <= LIFT.maxX
		and position.Z >= LIFT.minZ
		and position.Z <= ShiftWorld.INSIDE_MAX_Z
		and position.Y < LIFT.height + 2
end

-- 0 is open, 1 is shut. The two leaves slide into the front wall.
function ShiftWorld.setDoors(progress: number)
	doorProgress = math.clamp(progress, 0, 1)
	local offset = 1.6 + (1 - doorProgress) * 3.2
	doorLeft.CFrame = CFrame.new(-offset, DOOR_HEIGHT / 2, -1)
	doorRight.CFrame = CFrame.new(offset, DOOR_HEIGHT / 2, -1)
end

function ShiftWorld.doors(): number
	return doorProgress
end

function ShiftWorld.setIndicator(depthText: string, persons: number)
	indicator.Text = `{depthText}    PERSONS: {persons}`
	outsideIndicator.Text = depthText
	for name, lamp in floorLamps do
		local on = name == depthText
		lamp.Color = if on then LIT else UNLIT
		lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

function ShiftWorld.setLiftLight(on: boolean)
	liftLight.Enabled = on
end

-- One line of glowing text on one face of a part.
local function signText(
	part: BasePart,
	face: Enum.NormalId,
	color: Color3,
	font: Enum.Font
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.Font = font
	label.TextScaled = true
	label.Text = ""
	label.Parent = gui
	return label
end

-- Panelling on the cabin's inside: a steel kick plate, veneer to shoulder height and a brass
-- frieze. Each layer on the side walls starts where the same layer on the back wall ends, and the
-- front wall's where the side walls' end, so every corner meets at an edge.
local function panelling(lift: Folder)
	local layers: { { any } } = {
		{ "KickPlate", 0, 0.6, 0.15, STEEL, Enum.Material.Metal },
		{ "Veneer", 0.6, 7, 0.12, VENEER, Enum.Material.Wood },
		{ "Frieze", 7, 7.25, 0.16, BRASS, Enum.Material.Metal },
	}
	local inX, back, front = LIFT.maxX, LIFT.minZ, LIFT.maxZ
	for _, layer in layers do
		local name, y0, y1, t, color, material =
			layer[1], layer[2], layer[3], layer[4], layer[5], layer[6]
		local parts = {
			Build.decor(lift, name, -inX, y0, back, inX, y1, back + t, color, material),
			Build.decor(lift, name, -inX, y0, back + t, -inX + t, y1, front, color, material),
			Build.decor(lift, name, inX - t, y0, back + t, inX, y1, front, color, material),
			-- Either side of the door portal, on the front wall.
			Build.decor(lift, name, -inX + t, y0, front - t, -3.9, y1, front, color, material),
			Build.decor(lift, name, 3.9, y0, front - t, inX - t, y1, front, color, material),
		}
		if name == "Veneer" then
			for _, part in parts do
				part.MaterialVariant = "PK_Veneer"
			end
		end
	end
end

-- A brass rail at hip height, on two posts from the wall at `wallX`.
local function handrail(lift: Folder, x: number, z0: number, z1: number, wallX: number)
	local y = 3.3
	Build.piece(
		lift,
		"Handrail",
		CFrame.new(x, y, (z0 + z1) / 2) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(z1 - z0, 0.2, 0.2),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for _, z in { z0 + 0.4, z1 - 0.4 } do
		Build.decor(
			lift,
			"HandrailPost",
			math.min(x, wallX),
			y - 0.06,
			z - 0.06,
			math.max(x, wallX),
			y + 0.06,
			z + 0.06,
			BRASS,
			Enum.Material.Metal
		)
	end
end

-- A Bureau notice in a brass frame on the west wall's veneer, its face looking into the cabin.
local function notice(lift: Folder, z: number, y: number, text: string)
	local wall = -LIFT.maxX + 0.12
	Build.decor(
		lift,
		"NoticeFrame",
		wall,
		y - 0.9,
		z - 1.3,
		wall + 0.08,
		y + 0.9,
		z + 1.3,
		BRASS,
		Enum.Material.Metal
	)
	local paper = Build.decor(
		lift,
		"Notice",
		wall,
		y - 0.8,
		z - 1.2,
		wall + 0.12,
		y + 0.8,
		z + 1.2,
		Palette.Paper
	)
	local label = Build.label(paper, Enum.NormalId.Right, text, Palette.Ink)
	label.Font = Enum.Font.SpecialElite
	label.TextWrapped = true
	label.Size = UDim2.fromScale(0.86, 0.8)
	label.Position = UDim2.fromScale(0.07, 0.1)
end

local function buildLift(map: Folder)
	local lift = Instance.new("Folder")
	lift.Name = "Lift"
	lift.Parent = map
	local metal = Palette.Metal
	Build.box(lift, "LiftFloor", -7, -1, -13, 7, 0, 0, rgb(46, 46, 48), Enum.Material.DiamondPlate)
	Build.box(lift, "LiftCeiling", -7, LIFT.height, -13, 7, LIFT.height + 1, 0, Palette.Ceiling)
	Build.wallZ(lift, "LiftWest", -6.5, -13, 0, 0, LIFT.height, {}, metal, Enum.Material.Metal)
	Build.wallZ(lift, "LiftEast", 6.5, -13, 0, 0, LIFT.height, {}, metal, Enum.Material.Metal)
	-- Between the side walls, so the corners meet at edges instead of sharing their outer faces.
	Build.box(lift, "LiftBack", -6, 0, -13, 6, LIFT.height, -12, metal, Enum.Material.Metal)
	-- The front wall is also the start room's south wall: room height, with the doorway.
	Build.wallX(
		lift,
		"LiftFront",
		0,
		-7,
		7,
		0,
		ROOM_HEIGHT,
		{ { -3, 3, 0, DOOR_HEIGHT } },
		metal,
		Enum.Material.Metal
	)
	panelling(lift)

	-- The door portal, through the front wall and proud of it on the landing (World/FloorBuild
	-- clads the wall round it), its jambs reaching into the opening to cover the wall's cut edge.
	Build.decor(lift, "Portal", -3.9, 0, -0.75, -2.85, 9.6, 0.9, STEEL, Enum.Material.Metal)
	Build.decor(lift, "Portal", 2.85, 0, -0.75, 3.9, 9.6, 0.9, STEEL, Enum.Material.Metal)
	Build.decor(lift, "Portal", -2.85, 8.85, -0.75, 2.85, 9.6, 0.9, STEEL, Enum.Material.Metal)
	Build.decor(lift, "Threshold", -2.85, 0, -0.75, 2.85, 0.09, 0.9, BRASS, Enum.Material.Metal)

	-- The leaves never block a lens or a sight line: with the doors almost shut, the Registrar in
	-- the doorway would otherwise drop out of frame and hold them open for good.
	local function leaf(name: string): Part
		local part =
			Build.box(lift, name, 0, 0, 0, 3.2, DOOR_HEIGHT, 0.4, STEEL, Enum.Material.Metal)
		part.CanQuery = false
		return part
	end
	doorLeft = leaf("DoorLeft")
	doorRight = leaf("DoorRight")

	-- The ceiling: a lit diffuser in a steel frame, and a vent over the back wall.
	Build.decor(
		lift,
		"CeilingFrame",
		-3.4,
		LIFT.height - 0.25,
		-9.4,
		3.4,
		LIFT.height,
		-3.6,
		STEEL,
		Enum.Material.Metal
	)
	local lamp = Build.decor(
		lift,
		"LiftLamp",
		-3,
		LIFT.height - 0.3,
		-9,
		3,
		LIFT.height - 0.25,
		-4,
		Palette.Bulb,
		Enum.Material.Neon
	)
	liftLight = Instance.new("PointLight")
	liftLight.Color = Palette.Bulb
	liftLight.Brightness = 1.3
	liftLight.Range = 16
	liftLight.Parent = lamp
	Build.decor(
		lift,
		"Vent",
		-1.2,
		LIFT.height - 0.06,
		-11.4,
		1.2,
		LIFT.height,
		-10.4,
		Palette.Shadow
	)
	for slat = 0, 3 do
		local z = -11.3 + slat * 0.26
		Build.decor(
			lift,
			"VentSlat",
			-1.1,
			LIFT.height - 0.1,
			z,
			1.1,
			LIFT.height - 0.06,
			z + 0.1,
			STEEL,
			Enum.Material.Metal
		)
	end

	-- The PERSONS sign over the doors, inside, in a brass bezel.
	Build.decor(lift, "IndicatorBezel", -3.3, 9, -1.3, 3.3, 10, -1.15, BRASS, Enum.Material.Metal)
	local sign = Build.box(lift, "Indicator", -3, 9.1, -1.4, 3, 9.9, -1.2, Palette.Ink)
	sign.CanCollide = false
	indicator = signText(sign, Enum.NormalId.Front, Palette.Rec, Enum.Font.Code)

	-- Over the portal on the landing, the depth alone; and a call button nobody here has pressed.
	Build.decor(lift, "LandingBezel", -1.8, 10, 0.6, 1.8, 11.4, 0.75, STEEL, Enum.Material.Metal)
	local outside =
		Build.decor(lift, "LandingIndicator", -1.5, 10.2, 0.75, 1.5, 11.2, 0.85, Palette.Ink)
	outsideIndicator = signText(outside, Enum.NormalId.Back, LIT, Enum.Font.Code)
	Build.decor(lift, "CallPlate", 4.5, 3.6, 0.6, 5.3, 5.2, 0.75, STEEL, Enum.Material.Metal)
	Build.decor(lift, "CallButton", 4.7, 4.2, 0.75, 5.1, 4.6, 0.85, Palette.Rec, Enum.Material.Neon)

	-- The control panel by the doors on the east wall: a brass plate, a lamp for each floor, and
	-- the two buttons that matter.
	local plate =
		Build.decor(lift, "ControlPanel", 5.7, 2.4, -5.4, 6, 7, -2.6, BRASS, Enum.Material.Metal)
	local engraved = signText(plate, Enum.NormalId.Left, Palette.Ink, Enum.Font.SpecialElite)
	engraved.Size = UDim2.fromScale(1, 0.1)
	engraved.Position = UDim2.fromScale(0, 0.03)
	engraved.Text = "BUREAU LIFT 2"
	for index, name in PANEL_FLOORS do
		local row = math.floor((index - 1) / 2)
		local column = (index - 1) % 2
		local y = 6.2 - row * 0.5
		local z = -4.8 + column * 1.3
		floorLamps[name] = Build.decor(
			lift,
			`FloorLamp{name}`,
			5.62,
			y - 0.17,
			z - 0.17,
			5.7,
			y + 0.17,
			z + 0.17,
			UNLIT
		)
		local tag = Build.decor(
			lift,
			"FloorTag",
			5.66,
			y - 0.15,
			z + 0.22,
			5.7,
			y + 0.15,
			z + 0.72,
			Palette.Ink
		)
		signText(tag, Enum.NormalId.Left, BRASS, Enum.Font.Code).Text = name
	end

	local function button(name: string, y: number, color: Color3, action: string): ProximityPrompt
		local part =
			Build.box(lift, name, 5.5, y - 0.3, -4.3, 5.7, y + 0.3, -3.7, color, Enum.Material.Neon)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action
		prompt.ObjectText = "Lift"
		prompt.MaxActivationDistance = 8
		prompt.HoldDuration = 0.4
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		return prompt
	end
	ShiftWorld.upPrompt = button("ButtonUp", 4.6, Palette.Crt, "Go up: end the shift")
	ShiftWorld.downPrompt = button("ButtonDown", 3.6, Palette.Rec, "Go down")
	for _, label in { { 4.6, "UP" }, { 3.6, "DOWN" } } do
		local y = label[1] :: number
		local tag =
			Build.decor(lift, "ButtonTag", 5.66, y - 0.18, -3.5, 5.7, y + 0.18, -2.8, Palette.Ink)
		signText(tag, Enum.NormalId.Left, Palette.Paper, Enum.Font.Code).Text = label[2] :: string
	end

	handrail(lift, -5.5, -11.5, -1.4, -5.88)
	handrail(lift, 5.5, -11.5, -5.8, 5.88)
	Build.piece(
		lift,
		"Handrail",
		CFrame.new(0, 3.3, -11.38),
		Vector3.new(10.4, 0.2, 0.2),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	-- The Bureau's notices: what the cabin holds, and what to do when the count is wrong.
	notice(lift, -8.4, 5.2, "CAPACITY: 4 PERSONS\nTHE BUREAU IS NOT RESPONSIBLE FOR WHAT GETS OFF")
	notice(
		lift,
		-4.6,
		5.2,
		"IF THE COUNT IS WRONG, FILM THE CABIN.\nDO NOT TOUCH WHAT SHOULD NOT BE HERE."
	)
	Posters.hang(lift, "headcount", Vector3.new(-2.6, 5.4, LIFT.minZ + 0.12), Vector3.zAxis, 2.6, 0)
	Posters.hang(lift, "safety", Vector3.new(2.6, 5.4, LIFT.minZ + 0.12), Vector3.zAxis, 2.6, 0)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LiftSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, -7)
	spawn.Parent = lift

	ShiftWorld.setDoors(1)
end

function ShiftWorld.clearFloor()
	local folder = ShiftWorld.floorFolder
	if folder then
		folder:Destroy()
	end
	ShiftWorld.floorFolder = nil
end

function ShiftWorld.buildFloor(floor: FloorGen.Floor, seed: number)
	ShiftWorld.clearFloor()
	local folder = FloorBuild.build(floor, seed)
	folder.Parent = ShiftWorld.map
	ShiftWorld.floorFolder = folder
	ShiftWorld.applyDepth(floor.depth)
end

-- The air and grade of a depth (World/FloorLooks): each floor down is darker and stranger.
function ShiftWorld.applyDepth(depth: number)
	local look = lookFor(depth)
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	Lighting.ExposureCompensation = look.exposure
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = look.density
		atmosphere.Haze = look.haze
		atmosphere.Color = look.air
		atmosphere.Decay = look.decay
	end
	local grade = Lighting:FindFirstChild("WorldGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		grade.TintColor = look.tint
		grade.Saturation = look.saturation
		grade.Contrast = look.contrast
	end
	-- The cabin's own lamp: dimmer and warmer the deeper it goes.
	local down = math.clamp((depth - 1) / 4, 0, 1)
	liftLight.Color = Palette.Bulb:Lerp(rgb(255, 136, 104), down)
	liftLight.Brightness = 1.3 - 0.45 * down
end

function ShiftWorld.init()
	LightingApply.apply()
	local base = Workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace
	ShiftWorld.map = map
	buildLift(map)
	ShiftWorld.setIndicator("0", 0)
end

return ShiftWorld
