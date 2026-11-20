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

local Figures = require(ReplicatedStorage.Shared.World.Figures)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local Anomalies = {}

type Figure = { marker: BasePart, model: Model, kind: string, base: CFrame, stars: TextLabel }

local controllers: { [string]: any }
local layer: Folder
local figures: { [BasePart]: Figure } = {}

local function build(marker: BasePart)
	local kind = marker:GetAttribute("Kind")
	local seed = marker:GetAttribute("Seed")
	local model, base = Figures.anomaly(
		if typeof(kind) == "string" then kind else "sitter",
		marker.Position,
		if typeof(seed) == "number" then seed else 1
	)

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
