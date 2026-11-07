--!strict
-- Small geometry helpers shared by both places. Every part is anchored.
local Palette = require("../Config/Palette")
local Props = require("./Props")
local WallSpans = require("../Core/WallSpans")

local Build = {}

function Build.box(
	parent: Instance,
	name: string,
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	part.Position = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- A walkable plate rising from (y0, z0) to (y1, z1) along Z. Its top surface passes through both.
function Build.ramp(
	parent: Instance,
	name: string,
	minX: number,
	maxX: number,
	y0: number,
	z0: number,
	y1: number,
	z1: number,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	local midX = (minX + maxX) / 2
	local startPoint = Vector3.new(midX, y0, z0)
	local endPoint = Vector3.new(midX, y1, z1)
	part.Size = Vector3.new(maxX - minX, 1, (endPoint - startPoint).Magnitude)
	part.CFrame = CFrame.lookAt((startPoint + endPoint) / 2, endPoint) * CFrame.new(0, -0.5, 0)
	part.Color = color
	part.Material = material or Enum.Material.Fabric
	part.Parent = parent
	return part
end

local THICKNESS = 0.5

-- A wall in the XY plane at a fixed z, with openings { fromX, toX, bottom, top }.
-- Anything else is filled in, so a door is simply the absence of wall.
function Build.wallX(
	parent: Instance,
	name: string,
	z: number,
	minX: number,
	maxX: number,
	bottom: number,
	top: number,
	openings: { { number } },
	color: Color3?,
	material: Enum.Material?
)
	local tint = color or Palette.Wall
	local minZ, maxZ = z - THICKNESS, z + THICKNESS
	for _, rect in WallSpans.solve(minX, maxX, bottom, top, openings) do
		Build.box(
			parent,
			name,
			rect.fromA,
			rect.bottom,
			minZ,
			rect.toA,
			rect.top,
			maxZ,
			tint,
			material
		)
	end
end

-- A wall in the ZY plane at a fixed x, with openings { fromZ, toZ, bottom, top }.
function Build.wallZ(
	parent: Instance,
	name: string,
	x: number,
	minZ: number,
	maxZ: number,
	bottom: number,
	top: number,
	openings: { { number } },
	color: Color3?,
	material: Enum.Material?
)
	local tint = color or Palette.Wall
	local minX, maxX = x - THICKNESS, x + THICKNESS
	for _, rect in WallSpans.solve(minZ, maxZ, bottom, top, openings) do
		Build.box(
			parent,
			name,
			minX,
			rect.bottom,
			rect.fromA,
			maxX,
			rect.top,
			rect.toA,
			tint,
			material
		)
	end
end

-- A ceiling panel that actually lights the room below it.
function Build.panel(
	parent: Instance,
	x: number,
	y: number,
	z: number,
	width: number,
	depth: number,
	brightness: number,
	range: number,
	color: Color3?,
	shadows: boolean?
): Part
	local tint = color or Palette.Fluorescent
	local panel = Build.box(
		parent,
		"LightPanel",
		x - width / 2,
		y - 0.2,
		z - depth / 2,
		x + width / 2,
		y,
		z + depth / 2,
		tint,
		Enum.Material.Neon
	)
	panel.CanCollide = false
	panel.CastShadow = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 150
	light.Brightness = brightness
	light.Range = range
	light.Color = tint
	light.Shadows = shadows == true
	light.Parent = panel
	return panel
end

-- Prompts carry string keys; each client fills in its own language (client_common/PromptText).
function Build.prompt(
	parent: Instance,
	actionKey: string,
	objectKey: string,
	objectSuffix: string?,
	distance: number,
	hold: number?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt:SetAttribute("ActionKey", actionKey)
	prompt:SetAttribute("ObjectKey", objectKey)
	prompt:SetAttribute("ObjectSuffix", objectSuffix or "")
	prompt.ActionText = ""
	prompt.ObjectText = objectSuffix or ""
	prompt.MaxActivationDistance = distance
	prompt.HoldDuration = hold or 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function Build.label(part: BasePart, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return label
end

-- A seat: the visible chair is a mesh, with an invisible pad for collision and prompts and an
-- invisible plate behind it to carry the seat number. cf faces the way a sitter would look.
function Build.chair(parent: Instance, name: string, cf: CFrame): Part
	local seat = Instance.new("Part")
	seat.Name = name
	seat.Anchored = true
	seat.Transparency = 1
	seat.Size = Vector3.new(2.4, 0.4, 2.2)
	seat.CFrame = cf * CFrame.new(0, 1.45, 0)
	seat.Parent = parent
	local back = Instance.new("Part")
	back.Name = "Back"
	back.Anchored = true
	back.CanCollide = false
	back.CanQuery = false
	back.CanTouch = false
	back.Transparency = 1
	back.Size = Vector3.new(1.6, 1.2, 0.1)
	back.CFrame = cf * CFrame.new(0, 2.35, 1.05)
	back.Parent = seat
	-- The mesh is 2 tall with its seat at 1.1, so this puts the seat at 1.65.
	local legs = Props.place(seat, "Chair", cf, 1.5)
	legs.Name = "Legs"
	return seat
end

-- Shelving along its longer side: a dark core with archive units facing out on both sides.
function Build.shelf(
	parent: Instance,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	floorY: number,
	height: number
)
	Build.box(
		parent,
		"ShelfCore",
		minX + 0.3,
		floorY,
		minZ + 0.3,
		maxX - 0.3,
		floorY + height,
		maxZ - 0.3,
		Palette.Shadow
	)
	local alongX = (maxX - minX) > (maxZ - minZ)
	local length = if alongX then maxX - minX else maxZ - minZ
	local unitWidth = 5.4
	local unitHeight = 7.04
	local units = math.max(1, math.floor(length / unitWidth))
	local levels = math.max(1, math.floor(height / unitHeight))
	local widthScale = length / units / 4.4938
	local heightScale = height / levels / 5.6332
	local scale = Vector3.new(widthScale, heightScale, 0.6)
	local midX, midZ = (minX + maxX) / 2, (minZ + maxZ) / 2
	for side = -1, 1, 2 do
		for unit = 0, units - 1 do
			local along = (unit + 0.5) * length / units - length / 2
			for level = 0, levels - 1 do
				local y = floorY + level * height / levels
				local floor
				if alongX then
					local z = if side < 0 then minZ + 0.2 else maxZ - 0.2
					floor = CFrame.new(midX + along, y, z)
						* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0)
				else
					local x = if side < 0 then minX + 0.2 else maxX - 0.2
					floor = CFrame.new(x, y, midZ + along)
						* CFrame.Angles(0, if side < 0 then math.pi / 2 else -math.pi / 2, 0)
				end
				Props.place(parent, "Shelf", floor, scale)
			end
		end
	end
end

return Build
