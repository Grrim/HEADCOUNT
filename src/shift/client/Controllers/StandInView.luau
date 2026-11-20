--!strict
-- The Stand-ins as seen and heard from here (ShiftStandIn moves them). To the eye they are not
-- there: what gives one away is footsteps, the steps its player took half a minute ago, coming
-- along behind. Through the lens, on a tape or cut out of frame, each one shows: a pale copy of a
-- person, the only figure down here with nothing over its eyes, its head always turned to the lens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local StandInView = {}

local PALE = Color3.fromRGB(196, 200, 206)

type Figure = {
	model: Model,
	body: { { part: BasePart, offset: CFrame } },
	head: BasePart,
	lastPosition: Vector3?,
	stepClock: number,
}

local controllers: { [string]: any }
local figures: { [BasePart]: Figure } = {}

local function build(): Figure
	local model = Instance.new("Model")
	model.Name = "StandIn"
	local body: { { part: BasePart, offset: CFrame } } = {}
	local function piece(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0.25
		if shape then
			part.Shape = shape
		end
		part.Parent = model
		table.insert(body, { part = part, offset = offset })
		return part
	end
	-- Built around the root's height (3 studs up), like a player's own.
	piece(Vector3.new(0.8, 2, 0.8), CFrame.new(-0.45, -2, 0), PALE)
	piece(Vector3.new(0.8, 2, 0.8), CFrame.new(0.45, -2, 0), PALE)
	piece(Vector3.new(1.9, 2, 1), CFrame.new(0, 0, 0), PALE)
	piece(Vector3.new(0.7, 1.9, 0.7), CFrame.new(-1.3, 0.05, 0), PALE)
	piece(Vector3.new(0.7, 1.9, 0.7), CFrame.new(1.3, 0.05, 0), PALE)
	local head = Instance.new("Part")
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.CastShadow = false
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.25, 1.25, 1.25)
	head.Color = PALE
	head.Material = Enum.Material.SmoothPlastic
	head.Transparency = 0.15
	head.Parent = model
	-- Open eyes: two dark points where every other figure has a black bar.
	for side = -1, 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.16, 0.16, 0.16)
		eye.Color = Palette.Ink
		eye:SetAttribute("Side", side)
		eye.Parent = model
	end
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineColor = PALE
	glow.OutlineTransparency = 0.4
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
	return { model = model, body = body, head = head, lastPosition = nil, stepClock = 0 }
end

local function visible(): boolean
	return LensView.raised or controllers.Audience.offFrame or controllers.ShiftPlayback.active()
end

local function update(dt: number)
	local folder = Workspace:FindFirstChild("StandIns")
	local camera = Workspace.CurrentCamera
	if not folder or not camera then
		return
	end
	local show = visible()
	for anchor, figure in figures do
		if anchor.Parent ~= folder then
			figure.model:Destroy()
			figures[anchor] = nil
		end
	end
	for _, anchor in folder:GetChildren() do
		if not anchor:IsA("BasePart") then
			continue
		end
		local figure = figures[anchor]
		if not figure then
			figure = build()
			figures[anchor] = figure
		end
		local current = figure :: Figure
		local activeNow = anchor:GetAttribute("Active") == true
		if not activeNow then
			current.model.Parent = nil
			current.lastPosition = nil
			continue
		end
		local position = anchor.Position
		-- Its player's footsteps, half a minute late. Heard by anyone near, seen by nobody.
		local previous = current.lastPosition
		current.lastPosition = position
		if previous and (position - previous).Magnitude > 0.05 then
			current.stepClock -= dt
			if current.stepClock <= 0 then
				current.stepClock = 0.42
				AudioDirector.playAt("Step", position - Vector3.new(0, 3, 0), 0.6, 40)
			end
		end
		if not show then
			current.model.Parent = nil
			continue
		end
		local base = anchor.CFrame
		for _, item in current.body do
			item.part.CFrame = base * item.offset
		end
		-- The head turns to the lens, wherever the body is going.
		local headAt = base.Position + Vector3.new(0, 1.65, 0)
		local headCf = CFrame.lookAt(headAt, camera.CFrame.Position)
		current.head.CFrame = headCf
		for _, eye in current.model:GetChildren() do
			if eye.Name == "Eye" and eye:IsA("BasePart") then
				local side = eye:GetAttribute("Side")
				eye.CFrame = headCf
					* CFrame.new((if typeof(side) == "number" then side else 1) * 0.24, 0.12, -0.58)
			end
		end
		current.model.Parent = Workspace
	end
end

function StandInView.init(all: { [string]: any })
	controllers = all
end

function StandInView.start()
	RunService.RenderStepped:Connect(update)
end

return StandInView
