--!strict
-- The anomalies on a floor, drawn only through the lens (and for anyone cut out of frame, who sees
-- what the lens sees). The server places invisible markers in Workspace.Anomalies; each client
-- builds its own figure for each one. Filmed anomalies carry their best stars above them.
--
--   sitter    (common)  someone on a chair, eyes barred, looking away
--   standing  (rare)    someone standing too still, facing the wall
--   watcher   (epic)    someone on a chair who turns to face the lens, wherever it is
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.World.Build)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Props = require(ReplicatedStorage.Shared.World.Props)

local Anomalies = {}

type Figure = { marker: BasePart, model: Model, kind: string, base: CFrame, stars: TextLabel }

local controllers: { [string]: any }
local layer: Folder
local figures: { [BasePart]: Figure } = {}

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

local function build(marker: BasePart)
	local kind = marker:GetAttribute("Kind")
	local seed = marker:GetAttribute("Seed")
	local random = Random.new(if typeof(seed) == "number" then seed else 1)
	local yaw = random:NextNumber(0, math.pi * 2)
	local base = CFrame.new(marker.Position) * CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = "Anomaly"
	if kind == "standing" then
		standing(model, base)
	else
		Build.chair(model, "Chair", base)
		Props.sitter(model, base, random:NextInteger(1, 3))
	end
	inert(model)

	local tag = Instance.new("Part")
	tag.Name = "Tag"
	tag.Transparency = 1
	tag.Size = Vector3.new(0.2, 0.2, 0.2)
	tag.CFrame = CFrame.new(marker.Position + Vector3.new(0, 8, 0))
	tag.Anchored = true
	tag.CanCollide = false
	tag.CanQuery = false
	tag.Parent = model
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(120, 30)
	board.LightInfluence = 0
	board.Parent = tag
	local stars = Instance.new("TextLabel")
	stars.Size = UDim2.fromScale(1, 1)
	stars.BackgroundTransparency = 1
	stars.TextColor3 = Palette.Crt
	stars.TextStrokeTransparency = 0.4
	stars.Font = Enum.Font.Code
	stars.TextScaled = true
	stars.Text = ""
	stars.Parent = board

	-- Turning a watcher pivots about the spot it stands on.
	model.WorldPivot = base
	model.Parent = layer
	local figure: Figure = {
		marker = marker,
		model = model,
		kind = if typeof(kind) == "string" then kind else "sitter",
		base = base,
		stars = stars,
	}
	figures[marker] = figure

	local function showStars()
		local value = marker:GetAttribute("Stars")
		if typeof(value) == "number" and value > 0 then
			stars.Text = string.rep("*", value) .. string.rep(".", 5 - value)
		end
	end
	marker:GetAttributeChangedSignal("Stars"):Connect(showStars)
	showStars()
end

local function remove(marker: Instance)
	local figure = figures[marker :: BasePart]
	if figure then
		figure.model:Destroy()
		figures[marker :: BasePart] = nil
	end
end

local function visible(): boolean
	return LensView.raised or controllers.Audience.offFrame or controllers.ShiftPlayback.active()
end

function Anomalies.init(all: { [string]: any })
	controllers = all
	layer = Instance.new("Folder")
	layer.Name = "AnomalyLayer"
end

function Anomalies.start()
	local folder = Workspace:WaitForChild("Anomalies")
	folder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			-- Attributes arrive with the part, but give them a frame to be safe.
			task.defer(build, child)
		end
	end)
	folder.ChildRemoved:Connect(remove)
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			build(child)
		end
	end

	RunService.RenderStepped:Connect(function()
		local show = visible()
		layer.Parent = if show then Workspace else nil
		if not show then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		-- Watchers turn on the spot to face whoever is filming.
		for _, figure in figures do
			if figure.kind == "watcher" then
				local position = figure.base.Position
				local look =
					Vector3.new(camera.CFrame.Position.X, position.Y, camera.CFrame.Position.Z)
				if (look - position).Magnitude > 0.5 then
					-- A chair and its sitter look along -Z of their CFrame, so this faces the lens.
					figure.model:PivotTo(CFrame.lookAt(position, look))
				end
			end
		end
	end)
end

return Anomalies
