--!strict
-- Archive 03: the starting room, a corridor, the Registry Hall, the tape room and a room with no
-- door. Greybox, built from code like the mission.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local LightingApply = require(ReplicatedStorage.Shared.World.LightingApply)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local HubWorld = {}

HubWorld.prompts = {} :: { [string]: ProximityPrompt }

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
	Build.panel(map, 0, 9.9, 54, 3, 2, 0.9, 16)
	Build.panel(map, 0, 8.9, 30, 3, 2, 1.8, 22)
	for _, z in { -28, -6, 12 } do
		Build.panel(map, 0, 25.9, z, 16, 3, 2.4, 52)
	end
	Build.panel(map, 50, 10.9, -6, 6, 3, 2.2, 26)
	Build.panel(map, -50, 8.9, -2, 3, 2, 1.6, 20, Palette.Bulb, true)
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
	local chair =
		Build.chair(map, "IntroChair", CFrame.new(-7, 0, 52) * CFrame.Angles(0, math.rad(40), 0))
	chair.CanCollide = true

	-- Registry Hall: reception with a bell to ring while waiting.
	Build.box(map, "Reception", -8, 0, -3, 8, 3.6, 1, Palette.Wood, Enum.Material.Wood)
	local bell = Instance.new("Part")
	bell.Name = "ReceptionBell"
	bell.Shape = Enum.PartType.Ball
	bell.Anchored = true
	bell.Size = Vector3.new(0.9, 0.9, 0.9)
	bell.Position = Vector3.new(3, 4, -1)
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
	LightingApply.apply()
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
