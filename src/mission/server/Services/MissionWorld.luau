--!strict
-- Builds Mission 001 from Core/Layout. Greybox by design: art replaces it after the slice is tested.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local LightingApply = require(ReplicatedStorage.Shared.World.LightingApply)
local MissionAnnex = require(script.Parent.MissionAnnex)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Puzzle = require(ReplicatedStorage.Shared.Core.Puzzle)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local MissionWorld = {}

MissionWorld.map = nil :: Folder?
MissionWorld.seatPrompts = {} :: { [number]: ProximityPrompt }
MissionWorld.seatParts = {} :: { [number]: Part }
MissionWorld.hookPrompts = {} :: { [number]: ProximityPrompt }
MissionWorld.plugs = {} :: { [number]: Part } -- by door side
MissionWorld.prompts = {} :: { [string]: ProximityPrompt }
MissionWorld.film = nil :: Frame?
MissionWorld.filmDoors = {} :: { [number]: Frame }
MissionWorld.beam = nil :: Beam?
MissionWorld.hallLights = {} :: { Light }

local PD = Config.Puzzle.PromptDistance

local emergencyLights: { Light } = {}
local mainsBrightness: { [Light]: number } = {}

local function structure(map: Folder)
	local C, F, W = Palette.Ceiling, Enum.Material.Fabric, Palette.Wall
	local carpet, wood = Palette.Carpet, Enum.Material.Wood

	-- Hall
	local H = Layout.HALL
	Build.box(map, "HallFloor", H.minX, -1, H.minZ, H.maxX, 0, H.maxZ, carpet, F)
	Build.box(map, "HallCeiling", H.minX, H.height, H.minZ, H.maxX, H.height + 1, H.maxZ, C)
	-- Raised doors are cut to the ground: the stage and corridor floors fill the bottom, and a sill
	-- left in the wall would share a plane with them and flicker underfoot.
	Build.wallZ(map, "HallWest", H.minX, H.minZ, H.maxZ, 0, H.height, {
		{ -13, -5, 0, 10 },
		{ -38, -30, 0, 12 },
	})
	Build.wallZ(map, "HallEast", H.maxX, H.minZ, H.maxZ, 0, H.height, { { 20, 28, 0, 10 } })
	local X = Layout.DOOR_OFFSET_X
	Build.wallX(map, "StageBack", H.minZ, H.minX, H.maxX, 0, H.height, {
		{ -X - 4, -X + 4, 0, 12 },
		{ X - 4, X + 4, 0, 12 },
	}, Palette.WallDark)
	Build.wallX(map, "HallSouth", H.maxZ, H.minX, H.maxX, 0, H.height, {
		{ -5, 5, 0, 10 },
		{ -14, 14, 16, 21 },
	})
	local glass = Build.box(
		map,
		"BoothGlass",
		-14,
		16,
		43.8,
		14,
		21,
		44.2,
		Palette.Shadow,
		Enum.Material.Glass
	)
	glass.Transparency = 0.75
	glass.CastShadow = false

	-- Plugs: they look like wall. Only the framed one stops colliding.
	for side = -1, 1, 2 do
		local center = side * X
		local plug = Build.box(
			map,
			"StageBack",
			center - 4,
			3,
			H.minZ - 0.5,
			center + 4,
			12,
			H.minZ + 0.5,
			Palette.WallDark
		)
		MissionWorld.plugs[side] = plug
	end

	-- Stage
	local S = Layout.STAGE
	Build.box(map, "Stage", H.minX, 0, S.minZ, H.maxX, S.height, S.maxZ, Palette.WoodDark, wood)
	Build.ramp(map, "StageSteps", -6, 6, 0, -17, S.height, S.maxZ, Palette.WoodDark, wood)
	Build.box(
		map,
		"StageSkirt",
		H.minX,
		0,
		S.maxZ - 0.2,
		-6,
		S.height + 0.3,
		S.maxZ + 0.2,
		Palette.Wood,
		wood
	)
	Build.box(
		map,
		"StageSkirt",
		6,
		0,
		S.maxZ - 0.2,
		H.maxX,
		S.height + 0.3,
		S.maxZ + 0.2,
		Palette.Wood,
		wood
	)

	-- Foyer
	local Fy = Layout.FOYER
	Build.box(
		map,
		"FoyerFloor",
		Fy.minX,
		-1,
		Fy.minZ,
		Fy.maxX,
		0,
		Fy.maxZ,
		Color3.fromRGB(112, 104, 92),
		Enum.Material.Marble
	)
	Build.wallZ(map, "FoyerWest", Fy.minX, Fy.minZ, Fy.maxZ, 0, 25, {})
	Build.wallZ(map, "FoyerEast", Fy.maxX, Fy.minZ, Fy.maxZ, 0, Fy.height, { { 54, 66, 0, 9 } })
	Build.wallX(map, "FoyerSouth", Fy.maxZ, Fy.minX, -24, 0, 25, {})
	Build.wallX(map, "FoyerSouth", Fy.maxZ, -24, Fy.maxX, 0, Fy.height, {})
	-- The ceiling butts against the booth's south wall and the ramp's side wall, which both start at
	-- this height. East of the booth a short piece closes the gap the wall does not cover.
	Build.box(map, "FoyerCeiling", -23.5, Fy.height, 56.5, Fy.maxX, Fy.height + 1, Fy.maxZ, C)
	Build.box(map, "FoyerCeiling", 20, Fy.height, 56, Fy.maxX, Fy.height + 1, 56.5, C)
	Build.wallZ(map, "RampSide", -24, 56, 72, 0, 25, {})
	Build.wallZ(map, "RampSideHigh", -24, 72, 76, Fy.height, 25, {})
	Build.ramp(map, "BoothRamp", Fy.minX, -24, 0, 73, 14, 56, carpet, F)

	-- Booth
	local B = Layout.BOOTH
	Build.box(
		map,
		"BoothFloor",
		B.minX,
		B.floorY - 1,
		B.minZ,
		Fy.maxX,
		B.floorY,
		B.maxZ,
		Palette.Metal
	)
	Build.box(map, "BoothCeiling", B.minX, 24, B.minZ, B.maxX, 25, B.maxZ, C)
	Build.box(map, "RampRoof", B.minX, 25, B.maxZ, -24, 26, Fy.maxZ, C)
	Build.wallX(map, "BoothSouth", B.maxZ, -24, B.maxX, B.floorY, 24, {})
	Build.wallZ(map, "BoothEast", B.maxX, B.minZ, B.maxZ, B.floorY, 24, {})

	-- Coat room
	local K = Layout.COATS
	Build.box(
		map,
		"CoatFloor",
		K.minX,
		-1,
		K.minZ,
		K.maxX,
		0,
		K.maxZ,
		Palette.WallDark,
		Enum.Material.Concrete
	)
	Build.box(map, "CoatCeiling", K.minX, K.height, K.minZ, K.maxX, K.height + 1, K.maxZ, C)
	Build.wallZ(map, "CoatEast", K.maxX, K.minZ, K.maxZ, 0, K.height, {})
	Build.wallX(map, "CoatNorth", K.minZ, K.minX, K.maxX, 0, K.height, {})
	Build.wallX(map, "CoatSouth", K.maxZ, K.minX, K.maxX, 0, K.height, {})

	-- Curtain corridor: a raised north end meets the stage wing door.
	local R = Layout.CORRIDOR
	Build.box(map, "CorridorFloor", R.minX, -1, R.minZ, R.maxX, 0, R.maxZ, carpet, F)
	Build.box(map, "CorridorRaised", R.minX, 0, R.minZ, H.minX, 3, -30, carpet, F)
	Build.ramp(map, "CorridorRamp", R.minX, H.minX - 0.5, 0, -22, 3, -30, carpet, F)
	Build.box(map, "CorridorCeiling", R.minX, R.height, R.minZ, H.minX, R.height + 1, R.maxZ, C)
	Build.wallZ(map, "CorridorWest", R.minX, R.minZ, R.maxZ, 0, R.height, { { -14, -8, 0, 9 } })
	Build.wallX(map, "CorridorNorth", R.minZ, R.minX, H.minX, 0, R.height, {})
	Build.wallX(map, "CorridorSouth", R.maxZ, R.minX, H.minX, 0, R.height, {})
	local z = R.minZ + 3
	while z < R.maxZ do
		local fold = Build.box(
			map,
			"Curtain",
			R.minX + 0.5,
			0,
			z,
			R.minX + 1.4,
			R.height,
			z + 2,
			Palette.Curtain,
			F
		)
		fold.CanCollide = false
		z += 4
	end

	-- Archive, behind the hidden door
	local A = Layout.ARCHIVE
	Build.box(
		map,
		"ArchiveFloor",
		A.minX,
		A.floorY - 1,
		A.minZ,
		A.maxX,
		A.floorY,
		A.maxZ,
		carpet,
		F
	)
	Build.box(
		map,
		"ArchiveCeiling",
		A.minX,
		A.floorY + A.height,
		A.minZ,
		A.maxX,
		A.floorY + A.height + 1,
		A.maxZ,
		C
	)
	Build.wallZ(map, "ArchiveWest", A.minX, A.minZ, A.maxZ, A.floorY, A.floorY + A.height, {}, W)
	Build.wallZ(map, "ArchiveEast", A.maxX, A.minZ, A.maxZ, A.floorY, A.floorY + A.height, {}, W)
	Build.wallX(map, "ArchiveNorth", A.minZ, A.minX, A.maxX, A.floorY, A.floorY + A.height, {}, W)
	for _, sx in { -24, -12, 8, 20 } do
		Build.shelf(map, sx, -60, sx + 4, -46, A.floorY, 10)
	end
end

local function lights(map: Folder)
	-- Foyer: the calmest, brightest room in the mission.
	Build.panel(map, -8, 13.9, 62, 8, 3, 3, 40, nil, true)
	Build.panel(map, 14, 13.9, 68, 8, 3, 2.4, 34)
	-- Hall: rows of dim panels, one of them slightly off in colour.
	for _, z in { -6, 18, 38 } do
		for _, x in { -24, 24 } do
			local off = z == 18 and x == 24
			local tint = if off then Color3.fromRGB(196, 214, 228) else nil
			local panel = Build.panel(map, x, 23.9, z, 10, 3, 1.15, 50, tint)
			local light = panel:FindFirstChildOfClass("SpotLight")
			if light then
				table.insert(MissionWorld.hallLights, light)
			end
		end
	end
	-- The warm pool on the desk is the room's one point of interest.
	local pool =
		Build.box(map, "DeskLight", -1, 23.6, -33, 1, 23.9, -31, Palette.Bulb, Enum.Material.Neon)
	pool.CanCollide = false
	pool.CastShadow = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 42
	spot.Brightness = 9
	spot.Range = 28
	spot.Color = Palette.Bulb
	spot.Shadows = true
	spot.Parent = pool
	table.insert(MissionWorld.hallLights, spot)
	-- Others
	Build.panel(map, 40, 13.9, 60, 6, 3, 2.2, 30)
	Build.panel(map, -43, 12.9, -12, 4, 2, 1.8, 24)
	Build.panel(map, -43, 12.9, -36, 4, 2, 1.2, 20, Palette.Bulb)
	local bulb =
		Build.box(map, "BoothBulb", -1, 23.4, 49, 1, 23.9, 51, Palette.Bulb, Enum.Material.Neon)
	bulb.CanCollide = false
	-- A spot, not a point light: a point light without shadows would leak through the floor.
	local bulbLight = Instance.new("SpotLight")
	bulbLight.Face = Enum.NormalId.Bottom
	bulbLight.Angle = 120
	bulbLight.Color = Palette.Bulb
	bulbLight.Brightness = 3
	bulbLight.Range = 11
	bulbLight.Parent = bulb
	Build.panel(map, 0, 14.9, -60, 3, 2, 3.5, 26, Palette.Bulb, true)
end

local function seating(map: Folder)
	local hall = Instance.new("Folder")
	hall.Name = "Seats"
	for id = 1, Seats.TOTAL do
		local x, z = Seats.position(id)
		local seat = Build.chair(hall, `Seat{id}`, CFrame.new(x, 0, z))
		seat:SetAttribute("SeatId", id)
		MissionWorld.seatParts[id] = seat
		MissionWorld.seatPrompts[id] = Build.prompt(
			seat,
			"act_check_seat",
			"obj_seat",
			Seats.label(id),
			Config.Puzzle.SeatPromptDistance
		)
	end
	hall.Parent = map
	-- Row letters on both walls, so a voice can say "row C" and be understood.
	for row = 1, Seats.ROWS do
		local _, z = Seats.position(Seats.id(row, 1))
		for side = -1, 1, 2 do
			-- No wall to hang on where a door is, frame included; the far wall still has the letter.
			local door = if side < 0 then { -13, -5 } else { 20, 28 }
			if z + 1 <= door[1] - 0.5 or z - 1 >= door[2] + 0.5 then
				local x = side * (Layout.HALL.maxX - 0.7)
				local plate =
					Build.box(map, "RowSign", x - 0.1, 6, z - 1, x + 0.1, 8, z + 1, Palette.Paper)
				plate.CanCollide = false
				local face = if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left
				Build.label(plate, face, Seats.rowLetter(row), Palette.Ink)
			end
		end
	end
end

local function coats(map: Folder)
	local rack = Instance.new("Folder")
	rack.Name = "Coats"
	local perRow = 10
	for hook = 1, Puzzle.HOOK_COUNT do
		local col = (hook - 1) % perRow
		local row = (hook - 1) // perRow
		local z = Layout.COATS.minZ + 3 + col * 2.4
		local y = 2 + row * 2.6
		local coat = Build.box(
			rack,
			`Coat{hook}`,
			50.5,
			y - 1.1,
			z - 0.9,
			51.4,
			y + 1.1,
			z + 0.9,
			Palette.Suit,
			Enum.Material.Fabric
		)
		coat.CanCollide = false
		Build.label(coat, Enum.NormalId.Left, tostring(hook), Palette.Paper)
		MissionWorld.hookPrompts[hook] =
			Build.prompt(coat, "act_take_coat", "obj_hook", tostring(hook), 11)
	end
	rack.Parent = map
end

local function setPieces(map: Folder)
	-- Stage desk and bell
	local D = Layout.DESK
	Build.box(
		map,
		"Desk",
		D.x - 5,
		D.y,
		D.z - 2,
		D.x + 5,
		D.y + 3.2,
		D.z + 2,
		Palette.Wood,
		Enum.Material.Wood
	)
	local bell = Instance.new("Part")
	bell.Name = "Bell"
	bell.Shape = Enum.PartType.Ball
	bell.Anchored = true
	bell.Size = Vector3.new(0.9, 0.9, 0.9)
	bell.Position = Vector3.new(Layout.BELL.x, Layout.BELL.y, Layout.BELL.z)
	bell.Color = Palette.Bulb
	bell.Material = Enum.Material.Metal
	bell.Parent = map
	local bellPrompt =
		Build.prompt(bell, "act_ring_bell", "obj_bell_name", nil, PD, Config.Puzzle.BellHoldSeconds)
	bellPrompt.Enabled = false
	MissionWorld.prompts.Bell = bellPrompt
	MissionWorld.bell = bell

	-- Screen and the film it shows
	local screen = Build.box(map, "Screen", -14, 8, -39.4, 14, 22, -39.2, Palette.Paper)
	screen.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(560, 280)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.LightInfluence = 0
	local film = Instance.new("Frame")
	film.Name = "Film"
	film.Size = UDim2.fromScale(1, 1)
	film.BackgroundColor3 = Palette.Bulb
	film.BackgroundTransparency = 0.25
	film.BorderSizePixel = 0
	film.Visible = false
	film.Parent = gui
	-- The film draws the stage's back wall with a door on one side of the screen.
	for side = -1, 1, 2 do
		local door = Instance.new("Frame")
		door.AnchorPoint = Vector2.new(0.5, 1)
		door.Position = UDim2.fromScale(0.5 + side * 0.36, 0.95)
		door.Size = UDim2.fromScale(0.14, 0.62)
		door.BackgroundColor3 = Palette.Ink
		door.BorderSizePixel = 0
		door.Visible = false
		door.Parent = film
		MissionWorld.filmDoors[side] = door
	end
	-- A row of heads along the bottom: the film shows the audience this hall is supposed to hold.
	for index = 0, 13 do
		local head = Instance.new("Frame")
		head.AnchorPoint = Vector2.new(0.5, 1)
		head.Position = UDim2.fromScale(0.06 + index * 0.068, 1)
		head.Size = UDim2.fromOffset(26, 34)
		head.BackgroundColor3 = Palette.Ink
		head.BorderSizePixel = 0
		head.Parent = film
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = head
	end
	gui.Parent = screen
	MissionWorld.film = film

	-- Projector
	local P = Layout.PROJECTOR
	local projector = Build.box(
		map,
		"Projector",
		P.x - 2,
		P.y,
		P.z - 1.5,
		P.x + 2,
		P.y + 4,
		P.z + 1.5,
		Palette.Metal,
		Enum.Material.Metal
	)
	local from = Instance.new("Attachment")
	from.WorldPosition = Vector3.new(P.x, P.y + 2.5, P.z - 1.6)
	from.Parent = projector
	local to = Instance.new("Attachment")
	to.WorldPosition = Vector3.new(0, 15, -39)
	to.Parent = screen
	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Width0 = 1
	beam.Width1 = 26
	beam.LightEmission = 0.6
	beam.Color = ColorSequence.new(Palette.Bulb)
	beam.Transparency = NumberSequence.new(0.9)
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Parent = projector
	MissionWorld.beam = beam

	-- Foyer dressing and documents
	Build.box(
		map,
		"Bench",
		Layout.BENCH.x - 5,
		0,
		Layout.BENCH.z - 1,
		Layout.BENCH.x + 5,
		1.8,
		Layout.BENCH.z + 1,
		Palette.Wood,
		Enum.Material.Wood
	)
	local counter =
		Build.box(map, "TicketDesk", 12, 0, 46, 26, 3.4, 49, Palette.Wood, Enum.Material.Wood)
	local listDoc = Build.box(map, "DocList", 16, 3.4, 47, 17.4, 3.5, 48.2, Palette.Paper)
	listDoc.CanCollide = false
	MissionWorld.prompts.DocList = Build.prompt(listDoc, "act_read", "obj_document", nil, PD)
	counter.CastShadow = true

	local wronaDoc = Build.box(map, "DocWrona", 6, 17.2, 47, 7.4, 17.3, 48.2, Palette.Paper)
	wronaDoc.CanCollide = false
	Build.box(map, "BoothTable", 4, 14, 45.5, 10, 17.2, 49.5, Palette.WoodDark, Enum.Material.Wood)
	MissionWorld.prompts.DocWrona = Build.prompt(wronaDoc, "act_read", "obj_document", nil, PD)

	local R = Layout.REGISTER
	Build.box(
		map,
		"RegisterDesk",
		R.x - 3,
		R.y,
		R.z - 1.5,
		R.x + 3,
		R.y + 3.2,
		R.z + 1.5,
		Palette.Wood,
		Enum.Material.Wood
	)
	local register = Build.box(
		map,
		"Register",
		R.x - 1,
		R.y + 3.2,
		R.z - 0.8,
		R.x + 1,
		R.y + 3.5,
		R.z + 0.8,
		Palette.Paper
	)
	register.CanCollide = false
	local registerPrompt = Build.prompt(register, "act_read_register", "obj_register_name", nil, PD)
	registerPrompt.Enabled = false
	MissionWorld.prompts.Register = registerPrompt

	-- Leader mark: a strip of white tape on the floor, the way back for anyone cut out.
	local mark = Layout.SPLICE_MARK
	local strip = Build.box(
		map,
		"LeaderMark",
		mark.x - 3,
		0,
		mark.z - 3,
		mark.x + 3,
		0.1,
		mark.z + 3,
		Palette.Paper
	)
	strip.CanCollide = false
	strip.Transparency = 0.35
end

local function spawnPoint(map: Folder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Size = Vector3.new(12, 0.2, 6)
	spawn.Position = Vector3.new(Layout.SPAWN.x, 0.1, Layout.SPAWN.z)
	spawn.Orientation = Vector3.new(0, 0, 0)
	spawn.Parent = map
end

-- Some takes turn whole rows of chairs to face the wrong way.
function MissionWorld.applyTake(reverseEveryNthRow: number?)
	if not reverseEveryNthRow then
		return
	end
	for id, seat in MissionWorld.seatParts do
		local row = Seats.fromId(id)
		if row % reverseEveryNthRow == 0 then
			local x, z = Seats.position(id)
			local pivot = CFrame.new(x, 0, z)
			local turned = pivot * CFrame.Angles(0, math.pi, 0)
			for _, part in
				{ seat, seat:FindFirstChild("Back") :: Part, seat:FindFirstChild("Legs") :: Part }
			do
				part.CFrame = turned * pivot:ToObjectSpace(part.CFrame)
			end
		end
	end
end

function MissionWorld.showFilm(doorSide: number)
	local film = MissionWorld.film
	if film then
		film.Visible = true
	end
	MissionWorld.filmDoors[doorSide].Visible = true
	if MissionWorld.beam then
		MissionWorld.beam.Enabled = true
		local id = Sounds.Projector
		if id ~= 0 then
			local sound = Instance.new("Sound")
			sound.Name = "ProjectorRun"
			sound.SoundId = `rbxassetid://{id}`
			sound.Looped = true
			sound.Volume = 0.4
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 6
			sound.RollOffMaxDistance = 60
			sound.Parent = MissionWorld.beam.Parent
			sound:Play()
		end
	end
end

-- A night of weak bulbs: every light in the building, but not the emergency lamps, burns lower.
-- Called once at the start, before the mains ever go, so the dimmed level is what they restore.
function MissionWorld.dimLights(scale: number)
	local map = MissionWorld.map :: Folder
	for _, item in map:GetDescendants() do
		if item:IsA("Light") and not table.find(emergencyLights, item) then
			item.Brightness *= scale
		end
	end
end

-- When the mains go, everything on them goes, and only the red emergency lamps are left.
function MissionWorld.setMains(on: boolean)
	local map = MissionWorld.map :: Folder
	for _, item in map:GetDescendants() do
		if item:IsA("Light") and not table.find(emergencyLights, item) then
			local parent = item.Parent
			if parent and parent.Name ~= "EmergencyLamp" then
				if not mainsBrightness[item] then
					mainsBrightness[item] = item.Brightness
				end
				item.Brightness = if on then mainsBrightness[item] else 0
				if parent:IsA("BasePart") and parent.Name == "LightPanel" then
					parent.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
					if on then
						local stored = parent:GetAttribute("OnColor")
						if typeof(stored) == "Color3" then
							parent.Color = stored
						end
					else
						parent:SetAttribute("OnColor", parent.Color)
						parent.Color = Palette.Ceiling
					end
				end
			end
		end
	end
	for _, light in emergencyLights do
		light.Enabled = not on
	end
end

-- The small green EXIT over the hall doors becomes a wide red NO EXIT that stutters on, so the
-- change reads from the stage, the far end of the hall.
function MissionWorld.sealExit(plate: BasePart, label: TextLabel)
	local bottom = plate.Position.Y - plate.Size.Y / 2
	plate.Size = Vector3.new(10, 2.6, plate.Size.Z)
	plate.Position = Vector3.new(plate.Position.X, bottom + 1.3, plate.Position.Z)
	plate.Color = Color3.fromRGB(120, 12, 14)
	label.TextColor3 = Color3.fromRGB(255, 225, 215)
	local gui = label:FindFirstAncestorOfClass("SurfaceGui")
	if gui then
		-- The letters carry their own light, so the dim hall cannot swallow them.
		gui.LightInfluence = 0
	end
	local glow = Instance.new("SurfaceLight")
	glow.Face = if gui then gui.Face else Enum.NormalId.Front
	glow.Color = Color3.fromRGB(255, 40, 30)
	glow.Range = 18
	glow.Angle = 120
	glow.Brightness = 0
	glow.Parent = plate
	task.spawn(function()
		for _, on in { true, false, true, false, false, true } do
			plate.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			glow.Brightness = if on then 2 else 0
			label.TextTransparency = if on then 0 else 0.7
			task.wait(0.12)
		end
	end)
end

function MissionWorld.setClimaxLighting()
	for _, light in MissionWorld.hallLights do
		light.Brightness *= 0.55
	end
	-- The foyer clock has said 18:04 all evening. Now the meeting has everyone on its list, it moves.
	for _, item in (MissionWorld.map :: Folder):GetDescendants() do
		if item:IsA("TextLabel") then
			if item.Text == "18:04" then
				item.Text = "18:05"
			elseif item.Text == "EXIT" then
				item.Text = "NO EXIT"
				local plate = item:FindFirstAncestorWhichIsA("BasePart")
				if plate then
					MissionWorld.sealExit(plate, item)
				end
			end
		end
	end
end

function MissionWorld.init()
	LightingApply.apply()
	local base = Workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace
	MissionWorld.map = map
	structure(map)
	lights(map)
	seating(map)
	coats(map)
	setPieces(map)
	emergencyLights = MissionAnnex.build(map, MissionWorld.prompts)
	spawnPoint(map)
end

return MissionWorld
