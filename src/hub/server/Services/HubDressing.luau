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
	Build.panel(folder, 49, 10.9, 16, 6, 2, 1.6, 22)
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
		Build.box(folder, "CoffeeMachine", 12, 0, -2, 15, 7, 0, Palette.Metal, Enum.Material.Metal)
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
	sign(-4, 7.2, -30.9, 4, 8.4, -30.7, Enum.NormalId.Back, "EXPEDITIONS")
end

-- The archive looks in use: stacked boxes, a tape cart, a ladder, a desk someone just left.
local function archiveClutter(folder: Folder)
	for index, spot in { { -14, -16 }, { -9, 10 }, { 12, -22 }, { 16, 8 }, { 8, -12 } } do
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
		Props.place(
			folder,
			"Boxes",
			CFrame.new(x + 1.3, 0, z + 1.05) * CFrame.Angles(0, index * 0.5, 0),
			Vector3.new(2.4, height / 2, 2.2)
		)
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
	-- A ladder against the shelves
	for side = 0, 1 do
		local rail = decor(
			folder,
			"LadderRail",
			17 + side * 2,
			0,
			-24,
			17.3 + side * 2,
			20,
			-23.7,
			Palette.Metal,
			Enum.Material.Metal
		)
		rail.CFrame *= CFrame.Angles(math.rad(-8), 0, 0)
	end
	for rung = 1, 11 do
		decor(
			folder,
			"LadderRung",
			17,
			rung * 1.65,
			-23.95 + rung * 0.23,
			19.3,
			rung * 1.65 + 0.2,
			-23.75 + rung * 0.23,
			Palette.Metal,
			Enum.Material.Metal
		)
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
	decor(folder, "CounterTop", -8.3, 3.6, -3.3, 8.3, 3.8, 1.3, Color3.fromRGB(46, 36, 30))
	hide(folder, "CoffeeMachine")
	Props.place(
		folder,
		"CoffeeMachine",
		CFrame.new(13.5, 0, -1) * facingHall,
		Vector3.new(1.21, 1.24, 0.83)
	)
	local coffeeSign = decor(folder, "CoffeeSign", 12.4, 7.1, -0.9, 14.6, 7.9, -0.8, Palette.Shadow)
	Build.label(coffeeSign, Enum.NormalId.Back, "COFFEE", Palette.Crt)
	-- The expedition terminal is an old set on a desk, with the sign on its screen.
	hide(map, "Terminal")
	Props.place(folder, "Desk", CFrame.new(0, 0, -32) * facingHall, Vector3.new(1.43, 1.02, 1))
	Props.place(folder, "Crt", CFrame.new(0, 3.2, -32) * facingHall)
	local terminalScreen =
		decor(folder, "TerminalScreen", -1.25, 5.3, -31.2, 1.05, 6.9, -31.1, Palette.Shadow)
	Build.label(terminalScreen, Enum.NormalId.Back, "ARCHIVE 03", Palette.Crt)
	hide(map, "ArchiveTerminal")
	Props.place(folder, "Crt", CFrame.new(57.5, 0, -5) * CFrame.Angles(0, math.pi / 2, 0), 1.2)
	folder.Parent = map
	Surfaces.apply(map)
end

return HubDressing
