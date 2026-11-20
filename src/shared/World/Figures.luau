--!strict
-- The figures only a lens shows, built the same way wherever they are needed: on a live floor
-- (the shift's Anomalies controller) and in the copy of a floor a shift tape plays back in
-- (ShiftTapeView). The seed fixes which way each one faces and who sits there.
--
--   sitter    (common)  someone on a chair, eyes barred, looking away
--   standing  (rare)    someone standing too still, facing the wall
--   watcher   (epic)    someone on a chair who turns to face the lens, wherever it is
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

local function standing(model: Model, base: CFrame)
	local function piece(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Size = size
		part.CFrame = base * offset
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		if shape then
			part.Shape = shape
		end
		part.Parent = model
	end
	piece(Vector3.new(0.7, 3, 0.8), CFrame.new(-0.45, 1.5, 0), Palette.Suit)
	piece(Vector3.new(0.7, 3, 0.8), CFrame.new(0.45, 1.5, 0), Palette.Suit)
	piece(Vector3.new(2, 2.8, 1), CFrame.new(0, 4.4, 0), Palette.Suit)
	piece(Vector3.new(0.6, 2.6, 0.6), CFrame.new(-1.3, 4.2, 0), Palette.Suit)
	piece(Vector3.new(0.6, 2.6, 0.6), CFrame.new(1.3, 4.2, 0), Palette.Suit)
	piece(Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 6.5, 0), Palette.Skin, Enum.PartType.Ball)
	piece(Vector3.new(1.3, 0.24, 0.1), CFrame.new(0, 6.6, -0.62), Palette.Ink)
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
		standing(model, base)
	else
		Build.chair(model, "Chair", base)
		Props.sitter(model, base, random:NextInteger(1, 3))
	end
	inert(model)
	model.WorldPivot = base
	return model, base
end

return Figures
