--!strict
-- The figures only a lens shows, built the same way wherever they are needed: on a live floor
-- (the shift's Anomalies controller) and in the copy of a floor a shift tape plays back in
-- (ShiftTapeView). The seed fixes which way each one faces and who sits there.
--
--   sitter    (common)  someone on a chair, eyes barred, looking away
--   standing  (rare)    someone standing too still, facing the wall
--   watcher   (epic)    someone on a chair who turns to face the lens, wherever it is, and the
--                       only one with no bar over its eyes
local Build = require("./Build")
local Palette = require("../Config/Palette")
local Props = require("./Props")

local Figures = {}

local function inert(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local SUITS = {
	Palette.Suit,
	Color3.fromRGB(64, 48, 40),
	Color3.fromRGB(34, 40, 58),
}
local HAIR = {
	Color3.fromRGB(30, 24, 20),
	Color3.fromRGB(70, 66, 62),
	Color3.fromRGB(96, 92, 88),
}

-- Someone standing too still: a suit a size too big, hands at the sides, eyes barred like every
-- one of them. Built along -Z, the way it faces.
local function standing(model: Model, base: CFrame, random: Random)
	local suit = SUITS[random:NextInteger(1, #SUITS)]
	local hair = HAIR[random:NextInteger(1, #HAIR)]
	local function piece(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
		local part = Instance.new("Part")
		part.Size = size
		part.CFrame = base * offset
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		if shape then
			part.Shape = shape
		end
		part.Parent = model
		return part
	end
	local trousers = suit:Lerp(Color3.new(0, 0, 0), 0.25)
	for _, side in { -1, 1 } do
		piece(Vector3.new(0.72, 0.34, 1.1), CFrame.new(side * 0.42, 0.17, -0.12), Palette.Ink)
		piece(Vector3.new(0.68, 2.95, 0.74), CFrame.new(side * 0.42, 1.8, 0), trousers)
		-- Arms hang straight; the hands stop too low.
		piece(Vector3.new(0.56, 2.6, 0.62), CFrame.new(side * 1.3, 4.5, 0), suit)
		piece(Vector3.new(0.44, 0.7, 0.42), CFrame.new(side * 1.3, 2.86, -0.02), Palette.Skin)
	end
	piece(Vector3.new(2.05, 2.75, 1.02), CFrame.new(0, 4.6, 0), suit)
	piece(Vector3.new(0.62, 1.05, 0.06), CFrame.new(0, 5.4, -0.53), Palette.Paper)
	piece(Vector3.new(0.18, 0.95, 0.06), CFrame.new(0, 5.35, -0.56), Palette.Ink)
	piece(Vector3.new(0.46, 0.42, 0.46), CFrame.new(0, 6.15, 0), Palette.Skin)
	piece(Vector3.new(1.25, 1.3, 1.25), CFrame.new(0, 6.95, 0), Palette.Skin, Enum.PartType.Ball)
	local cap = piece(Vector3.new(1.32, 0.9, 1.36), CFrame.new(0, 7.3, 0.08), hair)
	cap.Material = Enum.Material.Fabric
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = cap
	piece(Vector3.new(1.24, 0.22, 0.08), CFrame.new(0, 7.02, -0.6), Palette.Ink)
end

-- The watcher is the one who looks back: no bar over its eyes, only two pale points where the
-- others are censored. `parts` is what Props.sitter built: body, bar, hair.
local function uncensor(model: Model, parts: { BasePart })
	local bar = parts[2]
	bar.Transparency = 1
	for _, side in { -0.24, 0.24 } do
		local eye = Instance.new("Part")
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.16, 0.16, 0.16)
		eye.CFrame = bar.CFrame * CFrame.new(side, 0, -0.02)
		eye.Color = Palette.Paper
		eye.Material = Enum.Material.Neon
		eye.Parent = model
	end
end

-- A figure of this kind at this spot (its feet at the spot's height), and the CFrame it stands
-- on. Nothing in it collides, can be clicked or touched.
function Figures.anomaly(kind: string, position: Vector3, seed: number): (Model, CFrame)
	local random = Random.new(seed)
	local yaw = random:NextNumber(0, math.pi * 2)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = "Anomaly"
	if kind == "standing" then
		standing(model, base, random)
	else
		Build.chair(model, "Chair", base)
		local parts = Props.sitter(model, base, random:NextInteger(1, 3))
		if kind == "watcher" then
			uncensor(model, parts)
		end
	end
	inert(model)
	model.WorldPivot = base
	return model, base
end

return Figures
