--!strict
-- Builds the lift (once) and each floor (on every ride) from Core/FloorGen. Greybox by design: the
-- prototype tests whether the shift is fun, not how it looks.
--
-- The lift never moves. It sits south of z = 0 and opens north into the start room; a ride clears
-- the floor outside the closed doors and builds the next one in its place.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local LightingApply = require(ReplicatedStorage.Shared.World.LightingApply)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local ShiftWorld = {}

local CELL = FloorGen.CELL
local ROOM_HEIGHT = 12
local DOOR_HEIGHT = 9
local HALF_DOOR = FloorGen.DOOR_WIDTH / 2

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
local liftLight: PointLight
local doorProgress = 1

-- How each depth looks: carpet, walls, how bright the lamps are, and the air.
type Look = {
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

local function lookFor(depth: number): Look
	return LOOKS[math.clamp(depth, 1, #LOOKS)]
end

function ShiftWorld.inLift(position: Vector3): boolean
	return position.X >= LIFT.minX
		and position.X <= LIFT.maxX
		and position.Z >= LIFT.minZ
		and position.Z <= LIFT.maxZ + 0.5
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
end

function ShiftWorld.setLiftLight(on: boolean)
	liftLight.Enabled = on
end

local function buildLift(map: Folder)
	local lift = Instance.new("Folder")
	lift.Name = "Lift"
	lift.Parent = map
	local metal = Palette.Metal
	Build.box(lift, "LiftFloor", -7, -1, -13, 7, 0, 0, Palette.WoodDark, Enum.Material.Wood)
	Build.box(lift, "LiftCeiling", -7, LIFT.height, -13, 7, LIFT.height + 1, 0, Palette.Ceiling)
	Build.wallZ(lift, "LiftWest", -6.5, -13, 0, 0, LIFT.height, {}, metal, Enum.Material.Metal)
	Build.wallZ(lift, "LiftEast", 6.5, -13, 0, 0, LIFT.height, {}, metal, Enum.Material.Metal)
	Build.wallX(lift, "LiftBack", -12.5, -7, 7, 0, LIFT.height, {}, metal, Enum.Material.Metal)
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

	local function leaf(name: string): Part
		local part =
			Build.box(lift, name, 0, 0, 0, 3.2, DOOR_HEIGHT, 0.4, metal, Enum.Material.Metal)
		return part
	end
	doorLeft = leaf("DoorLeft")
	doorRight = leaf("DoorRight")

	local lamp =
		Build.box(lift, "LiftLamp", -2, LIFT.height - 0.2, -8, 2, LIFT.height, -5, Palette.Bulb)
	lamp.Material = Enum.Material.Neon
	lamp.CanCollide = false
	liftLight = Instance.new("PointLight")
	liftLight.Color = Palette.Bulb
	liftLight.Brightness = 1.2
	liftLight.Range = 16
	liftLight.Parent = lamp

	local sign = Build.box(lift, "Indicator", -3, 9.2, -1.4, 3, 10, -1.2, Palette.Ink)
	sign.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	indicator = Instance.new("TextLabel")
	indicator.Size = UDim2.fromScale(1, 1)
	indicator.BackgroundTransparency = 1
	indicator.TextColor3 = Palette.Rec
	indicator.Font = Enum.Font.Code
	indicator.TextScaled = true
	indicator.Text = ""
	indicator.Parent = gui

	local function button(name: string, y: number, color: Color3, action: string): ProximityPrompt
		local part =
			Build.box(lift, name, 5.6, y - 0.3, -4.3, 5.9, y + 0.3, -3.7, color, Enum.Material.Neon)
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
		for _, side in { -1, 1 } do
			local wx = x + side * (CELL / 2 - 1.2)
			Build.box(
				parent,
				"Curtain",
				wx - 0.4,
				0,
				z - 12,
				wx + 0.4,
				ROOM_HEIGHT,
				z + 12,
				Palette.Curtain,
				Enum.Material.Fabric
			)
		end
	end
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
	local folder = Instance.new("Folder")
	folder.Name = "Floor"
	local look = lookFor(floor.depth)
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

	folder.Parent = ShiftWorld.map
	ShiftWorld.floorFolder = folder
	ShiftWorld.applyDepth(floor.depth)
end

-- The air and grade of a depth: each floor down is darker and stranger.
function ShiftWorld.applyDepth(depth: number)
	local look = lookFor(depth)
	Lighting.Ambient = look.ambient
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = look.density
	end
	local grade = Lighting:FindFirstChild("WorldGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		grade.TintColor = look.tint
	end
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
