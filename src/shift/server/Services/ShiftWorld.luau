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
local FloorBuild = require(ReplicatedStorage.Shared.World.FloorBuild)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local LightingApply = require(ReplicatedStorage.Shared.World.LightingApply)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

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
local liftLight: PointLight
local doorProgress = 1

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

	-- The leaves never block a lens or a sight line: with the doors almost shut, the Registrar in
	-- the doorway would otherwise drop out of frame and hold them open for good.
	local function leaf(name: string): Part
		local part =
			Build.box(lift, name, 0, 0, 0, 3.2, DOOR_HEIGHT, 0.4, metal, Enum.Material.Metal)
		part.CanQuery = false
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
