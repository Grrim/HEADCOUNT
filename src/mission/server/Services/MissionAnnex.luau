--!strict
-- The rooms past the hall: the director's office with the old recorder, the stairs and basement
-- with the breaker, and the reel table in the booth. Called by MissionWorld while it builds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.World.Build)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local MissionAnnex = {}

local PD = Config.Puzzle.PromptDistance

local function office(map: Folder, prompts: { [string]: ProximityPrompt })
	local O = Layout.OFFICE
	local F = Enum.Material.Fabric
	Build.box(
		map,
		"OfficeFloor",
		O.minX,
		-1,
		O.minZ,
		O.maxX,
		0,
		O.maxZ,
		Palette.WoodDark,
		Enum.Material.WoodPlanks
	)
	Build.box(
		map,
		"OfficeCeiling",
		O.minX,
		O.height,
		O.minZ,
		O.maxX,
		O.height + 1,
		O.maxZ,
		Palette.Ceiling
	)
	Build.wallZ(map, "OfficeEast", O.maxX, O.minZ, O.maxZ, 0, O.height, {})
	Build.wallX(map, "OfficeNorth", O.minZ, O.minX, O.maxX, 0, O.height, {})
	Build.wallX(map, "OfficeSouth", O.maxZ, O.minX, O.maxX, 0, O.height, {})
	Build.box(map, "OfficeRug", 44, 0, 16, 56, 0.1, 30, Color3.fromRGB(70, 28, 30), F).CanCollide =
		false

	-- The director's desk faces the door, the way such desks always did.
	Build.box(map, "DirectorDesk", 50, 0, 18, 54, 3.2, 28, Palette.Wood, Enum.Material.Wood)
	Build.chair(map, "DirectorChair", CFrame.new(56, 0, 23) * CFrame.Angles(0, math.rad(90), 0)).CanCollide =
		true
	-- Units stick out 0.5 past these bounds, so this keeps them off the east and south walls.
	for z = 13, 27, 7 do
		Build.shelf(map, 57.6, z, 59, z + 6, 0, 10)
	end

	-- The recorder: its tape names the order of the reels, at the usual price of watching.
	local recorder =
		Build.box(map, "Recorder", 50.6, 3.2, 21, 53, 4.4, 24, Palette.Metal, Enum.Material.Metal)
	local spoolA = Build.box(map, "Spool", 51, 4.4, 21.5, 52.6, 4.5, 22.4, Palette.Ink)
	spoolA.CanCollide = false
	local spoolB = Build.box(map, "Spool", 51, 4.4, 22.8, 52.6, 4.5, 23.7, Palette.Ink)
	spoolB.CanCollide = false
	prompts.Recorder = Build.prompt(recorder, "act_play_recorder", "obj_recorder", nil, PD)

	local doc = Build.box(map, "DocOffice", 50.8, 3.2, 25, 52.4, 3.28, 27, Palette.Paper)
	doc.CanCollide = false
	prompts.DocOffice = Build.prompt(doc, "act_read", "obj_document", nil, PD)

	local lamp =
		Build.box(map, "OfficeLamp", 51, 3.2, 18.6, 52, 5.8, 19.6, Palette.Bulb, Enum.Material.Neon)
	lamp.CanCollide = false
	lamp.CastShadow = false
	local glow = Instance.new("PointLight")
	glow.Color = Palette.Bulb
	glow.Brightness = 2
	glow.Range = 24
	glow.Shadows = true
	glow.Parent = lamp
end

local function basement(map: Folder, prompts: { [string]: ProximityPrompt })
	local B = Layout.BASEMENT
	local concrete = Enum.Material.Concrete
	local grey = Palette.WallDark
	-- Landing off the curtain corridor
	Build.box(map, "LandingFloor", -66, -1, -18, -48, 0, -8, grey, concrete)
	Build.box(map, "LandingCeiling", -66, 10, -18, -48, 11, 14, Palette.Ceiling)
	Build.wallX(map, "LandingNorth", -18, -66, -48, 0, 10, {}, grey, concrete)
	Build.wallX(map, "LandingSouth", -8, -60, -48, 0, 10, {}, grey, concrete)
	-- Stairs as a ramp, then the room
	Build.ramp(map, "BasementRamp", -66, -60, 0, -8, B.floorY, B.minZ, grey, concrete)
	Build.wallZ(map, "StairWest", -66, -18, B.minZ, B.floorY, 10, {}, grey, concrete)
	Build.wallZ(map, "StairEast", -60, -8, B.minZ, B.floorY, 10, {}, grey, concrete)
	Build.box(
		map,
		"BasementFloor",
		B.minX,
		B.floorY - 1,
		B.minZ,
		B.maxX,
		B.floorY,
		B.maxZ,
		grey,
		concrete
	)
	Build.box(
		map,
		"BasementCeiling",
		B.minX,
		B.floorY + B.height,
		B.minZ,
		B.maxX,
		B.floorY + B.height + 1,
		B.maxZ,
		Palette.Ceiling
	)
	Build.wallX(map, "BasementNorth", B.minZ, B.minX, B.maxX, B.floorY, B.floorY + B.height, {
		{ -66, -60, B.floorY, B.floorY + B.height },
	}, grey, concrete)
	Build.wallX(
		map,
		"BasementSouth",
		B.maxZ,
		B.minX,
		B.maxX,
		B.floorY,
		B.floorY + B.height,
		{},
		grey,
		concrete
	)
	Build.wallZ(
		map,
		"BasementWest",
		B.minX,
		B.minZ,
		B.maxZ,
		B.floorY,
		B.floorY + B.height,
		{},
		grey,
		concrete
	)
	Build.wallZ(
		map,
		"BasementEast",
		B.maxX,
		B.minZ,
		B.maxZ,
		B.floorY,
		B.floorY + B.height,
		{},
		grey,
		concrete
	)

	-- Boiler, pipes and a stack of the chairs that were not needed.
	local boiler = Build.box(
		map,
		"Boiler",
		-85,
		B.floorY,
		24,
		-77,
		B.floorY + 8,
		30,
		Palette.Metal,
		Enum.Material.CorrodedMetal
	)
	boiler.CastShadow = true
	for index = 0, 3 do
		local z = B.minZ + 4 + index * 7
		local pipe = Build.box(
			map,
			"Pipe",
			B.minX,
			B.floorY + 8.4,
			z,
			B.maxX,
			B.floorY + 9,
			z + 0.6,
			Palette.Metal,
			Enum.Material.Metal
		)
		pipe.CanCollide = false
	end
	for index = 0, 5 do
		local x = -58 + index * 0.4
		local z = 36 + (index % 3) * 2.8
		Build.chair(
			map,
			"SpareChair",
			CFrame.new(x - index * 2.8, B.floorY, z) * CFrame.Angles(0, index * 1.1, 0)
		)
	end

	-- The breaker, in the far corner. Its prompt opens a keypad on the client.
	local panel = Build.box(
		map,
		"BreakerPanel",
		-74,
		B.floorY + 2.5,
		B.maxZ - 1.2,
		-68,
		B.floorY + 7.5,
		B.maxZ - 0.5,
		Palette.Metal,
		Enum.Material.Metal
	)
	Build.label(panel, Enum.NormalId.Front, "MAIN", Palette.Paper)
	local prompt = Build.prompt(panel, "act_keypad", "obj_breaker", nil, PD)
	prompt:AddTag("BreakerPrompt")
	prompts.Breaker = prompt

	local doc = Build.box(
		map,
		"DocBasement",
		-66,
		B.floorY + 4,
		B.maxZ - 0.6,
		-63.5,
		B.floorY + 7,
		B.maxZ - 0.5,
		Palette.Paper
	)
	doc.CanCollide = false
	Build.label(doc, Enum.NormalId.Front, "!", Palette.Rec)
	prompts.DocBasement = Build.prompt(doc, "act_read", "obj_document", nil, PD)

	Build.panel(map, -71, B.floorY + B.height - 0.1, B.maxZ - 6, 3, 1.5, 2, 26, nil, true)
	Build.panel(map, -63, 9.9, -13, 3, 1.5, 1.4, 20)
end

local function reels(map: Folder, prompts: { [string]: ProximityPrompt })
	-- Three cans on a table by the projector, loaded one at a time, in the order the tape gives.
	-- Clear of the projector, whose model reaches x = -1.9.
	Build.box(map, "ReelTable", -9.5, 14, 45.6, -2.5, 17, 49, Palette.WoodDark, Enum.Material.Wood)
	for index, letter in { "A", "B", "C" } do
		local x = -9.1 + (index - 1) * 2.2
		local can = Build.box(
			map,
			`Reel{letter}`,
			x,
			17,
			46.4,
			x + 1.8,
			17.5,
			48.2,
			Palette.Metal,
			Enum.Material.Metal
		)
		can.CanCollide = false
		Build.label(can, Enum.NormalId.Top, letter, Palette.Paper)
		local prompt = Build.prompt(can, "act_load_reel", "obj_reel", letter, 8)
		prompts[`Reel{letter}`] = prompt
	end
end

-- Dim red lamps that only come on when the mains go. Returned to MissionWorld to switch.
local function emergency(map: Folder): { Light }
	local lights: { Light } = {}
	local spots = {
		{ -30, 22, 44 - 1 },
		{ 30, 22, 44 - 1 },
		{ -37, 16, 8 },
		{ 37, 16, 8 },
		{ -20, 20, -24.5 },
		{ 20, 20, -24.5 },
		{ -30, 12, 60 },
		{ 40, 12, 72 },
		{ -44, 11, -20 },
		{ -63, 9, -13 },
		{ -75, -4, 28 },
	}
	for _, spot in spots do
		local lamp = Build.box(
			map,
			"EmergencyLamp",
			spot[1] - 0.6,
			spot[2],
			spot[3] - 0.3,
			spot[1] + 0.6,
			spot[2] + 0.5,
			spot[3] + 0.3,
			Palette.Rec
		)
		lamp.CanCollide = false
		lamp.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = Palette.Rec
		light.Brightness = 1.2
		light.Range = 34
		light.Enabled = false
		light.Parent = lamp
		table.insert(lights, light)
	end
	return lights
end

function MissionAnnex.build(map: Folder, prompts: { [string]: ProximityPrompt }): { Light }
	office(map, prompts)
	basement(map, prompts)
	reels(map, prompts)
	return emergency(map)
end

return MissionAnnex
