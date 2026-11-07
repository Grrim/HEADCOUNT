--!strict
-- The 192 who never left. They exist only on this client and only behind the lens: the empty hall
-- to the eye, the full hall through the viewfinder. Also owns the other things only a lens shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Props = require(ReplicatedStorage.Shared.World.Props)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)

local Audience = {}

Audience.climax = false
Audience.playback = false
Audience.offFrame = false
Audience.ended = false

local layer: Folder
local figures: { [number]: { parts: { BasePart }, base: { CFrame }, pivot: CFrame } } = {}
local turned: { [number]: boolean } = {}
local benchFigure: Model
local benchRaises = 0
local hiddenDoor: Model? = nil
local liveLensHides = false
local shown = true
local risen: { [number]: boolean } = {}
local rising = false

-- In the climax they stand, row by row, starting from the back.
local function startRising(placeRow: (number) -> ())
	if rising then
		return
	end
	rising = true
	task.spawn(function()
		for row = Seats.ROWS, 1, -1 do
			task.wait(5)
			risen[row] = true
			placeRow(row)
			-- Sixteen seats tipping up at once, from somewhere behind you.
			local _, z = Seats.position(Seats.id(row, 1))
			AudioDirector.playAt("ChairFold", Vector3.new(0, 3, z), 0.9, 120)
		end
	end)
end
local reversedRows: number? = nil

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Torso, head and the black bar across the eyes. The bar is on the front, so from behind they are
-- only rows of grey suits. From the stage, every one of them has been censored.
local function buildAudience()
	for id = 1, Seats.TOTAL do
		local x, z = Seats.position(id)
		local pivot = CFrame.new(x, 0, z)
		local parts = Props.sitter(layer, pivot, id)
		local base = {}
		for index, item in parts do
			base[index] = item.CFrame
		end
		figures[id] = { parts = parts, base = base, pivot = pivot }
	end
end

local function placeFigure(id: number)
	local figure = figures[id]
	local row = Seats.fromId(id)
	local reversed = reversedRows ~= nil and row % (reversedRows :: number) == 0
	local flip = reversed ~= (turned[id] == true)
	local rotation = if flip then figure.pivot * CFrame.Angles(0, math.pi, 0) else figure.pivot
	local lift = if risen[row] then CFrame.new(0, 2.3, 0) else CFrame.new()
	for index, item in figure.parts do
		item.CFrame = lift * rotation * figure.pivot:ToObjectSpace(figure.base[index])
	end
end

local function buildBench()
	benchFigure = Instance.new("Model")
	benchFigure.Name = "BenchFigure"
	local cf = CFrame.new(Layout.BENCH.x, 0, Layout.BENCH.z)
	Props.sitter(benchFigure, cf, 7)
	benchFigure.Parent = layer
end

local function buildHiddenDoor(side: number)
	if hiddenDoor then
		return
	end
	local model = Instance.new("Model")
	model.Name = "HiddenDoor"
	local x = side * Layout.DOOR_OFFSET_X
	local z = Layout.DOOR_Z + 0.65
	local cf = CFrame.new(x, 7.5, z)
	part(model, Vector3.new(8, 9, 0.2), cf, Palette.Ink)
	part(
		model,
		Vector3.new(6.6, 8.3, 0.25),
		cf * CFrame.new(0, -0.3, 0.05),
		Palette.Wood,
		Enum.Material.Wood
	)
	part(
		model,
		Vector3.new(0.5, 0.5, 0.4),
		cf * CFrame.new(2.6, -0.6, 0.2),
		Palette.Bulb,
		Enum.Material.Metal
	)
	model.Parent = layer
	hiddenDoor = model
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = if shown then 0 else 1
		end
	end
end

local function layerVisible(): boolean
	if Audience.climax or Audience.playback or Audience.offFrame or Audience.ended then
		return true
	end
	return LensView.raised and not liveLensHides
end

-- Stays parented and is hidden per part: parenting hundreds of parts forces the renderer to redo
-- its lighting, which turned the whole screen black for a moment exactly when the lens came up.
function Audience.refresh()
	local visible = layerVisible()
	if visible == shown then
		return
	end
	shown = visible
	local modifier = if visible then 0 else 1
	for _, item in layer:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = modifier
		end
	end
end

-- The final tape keeps a seat free for each member of the team. Call after the last refresh.
function Audience.vacateForCast(teamSize: number)
	for index = 1, teamSize do
		local figure = figures[Seats.castSeat(index)]
		if figure then
			for _, item in figure.parts do
				item.LocalTransparencyModifier = 1
			end
		end
	end
end

function Audience.setPlayback(on: boolean, seats: { number }?)
	Audience.playback = on
	local changed = {}
	for id in turned do
		table.insert(changed, id)
	end
	turned = {}
	if on and seats then
		for _, id in seats do
			if figures[id] then
				turned[id] = true
				table.insert(changed, id)
			end
		end
	end
	for _, id in changed do
		placeFigure(id)
	end
	Audience.refresh()
end

function Audience.init()
	layer = Instance.new("Folder")
	layer.Name = "LensLayer"
	buildAudience()
	buildBench()
	layer.Parent = Workspace
	Audience.refresh()
	LensView.onChanged(function(raised)
		Audience.refresh()
		-- The first look shows someone on the bench. The next look, they have moved closer.
		if raised then
			benchRaises += 1
			if benchRaises == 2 then
				benchFigure:PivotTo(CFrame.new(Layout.BENCH.x + 10, 0, Layout.BENCH.z + 6))
			elseif benchRaises == 3 then
				benchFigure:PivotTo(CFrame.new(0, -500, 0))
			end
		end
	end)
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		local wasReversed = reversedRows
		reversedRows = state.reverseEveryNthRow
		liveLensHides = state.liveLensHidesAudience == true
		if reversedRows ~= wasReversed then
			for id in figures do
				placeFigure(id)
			end
		end
		if state.doorSide then
			buildHiddenDoor(state.doorSide)
		end
		Audience.climax = state.phase == "Climax" or state.phase == "Done"
		if state.phase == "Climax" then
			startRising(function(row)
				for col = 1, Seats.COLS do
					placeFigure(Seats.id(row, col))
				end
			end)
		end
		Audience.refresh()
	end)
end

return Audience
