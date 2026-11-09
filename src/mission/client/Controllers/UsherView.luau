--!strict
-- The Usher as seen from here: a doorman in a peaked cap, one of the audience by the black bar
-- across his eyes, walking his round with a ticket punch. Unlit, so in the power cut he is only
-- there where a torch or a red emergency lamp finds him; the camera, as always, shows him anyway.
-- When he has seen a light, two points shine out from under the bar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Props = require(ReplicatedStorage.Shared.World.Props)
local Strings = require(ReplicatedStorage.Shared.Strings)

local UsherView = {}

-- Height of the suit mesh to the collar; the head sits on top.
local BODY = 5.4
local COAT = Color3.fromRGB(46, 30, 34)

local controllers: { [string]: any }
local anchor: BasePart? = nil
local model: Model
local pieces: { { part: BasePart, offset: CFrame } } = {}
local eyes: { Part } = {}
local outline: Highlight
local facing = CFrame.new()
local heading = 0
local lastPosition: Vector3? = nil
local stepClock = 0
local bob = 0
local movingUntil = 0

local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = model
	table.insert(pieces, { part = p, offset = offset })
	return p
end

local function build()
	model = Instance.new("Model")
	model.Name = "Usher"
	local body = Props.place(model, "Registrar", CFrame.new(), BODY / 11.196)
	body.CanQuery = false
	body.Color = COAT
	table.insert(pieces, { part = body, offset = CFrame.new(0, BODY / 2, 0) })
	local headY = BODY + 0.75
	local head = piece(Vector3.new(1.25, 1.4, 1.25), CFrame.new(0, headY, 0), Palette.Skin)
	head.Shape = Enum.PartType.Ball
	piece(Vector3.new(1.32, 0.3, 0.12), CFrame.new(0, headY + 0.1, -0.6), Palette.Ink)
	-- A doorman's cap: crown and peak.
	local crown = piece(
		Vector3.new(0.5, 1.45, 1.45),
		CFrame.new(0, headY + 0.75, 0.05) * CFrame.Angles(0, 0, math.rad(90)),
		COAT
	)
	crown.Shape = Enum.PartType.Cylinder
	piece(Vector3.new(1.2, 0.08, 0.5), CFrame.new(0, headY + 0.52, -0.75), Palette.Ink)
	piece(
		Vector3.new(1.47, 0.12, 1.47),
		CFrame.new(0, headY + 0.98, 0.05),
		Palette.Bulb,
		Enum.Material.Metal
	)
	-- The ticket punch, held out in front.
	piece(
		Vector3.new(0.35, 0.5, 0.9),
		CFrame.new(0.9, BODY * 0.55, -0.9),
		Palette.Metal,
		Enum.Material.Metal
	)
	-- Eyes under the bar, dark until he has seen a light.
	for side = -1, 1, 2 do
		local eye = piece(
			Vector3.new(0.14, 0.14, 0.06),
			CFrame.new(side * 0.25, headY + 0.1, -0.68),
			Palette.Paper,
			Enum.Material.Neon
		)
		eye.CastShadow = false
		eye.Transparency = 1
		table.insert(eyes, eye)
	end
	outline = Instance.new("Highlight")
	outline.FillTransparency = 0.85
	outline.FillColor = Palette.Paper
	outline.OutlineColor = Palette.Paper
	outline.OutlineTransparency = 0.2
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Enabled = false
	outline.Parent = model
end

local function setEyes(lit: boolean)
	for _, eye in eyes do
		eye.Transparency = if lit then 0 else 1
	end
end

local function update(dt: number)
	local current = anchor
	if not current or current:GetAttribute("Active") ~= true then
		model.Parent = nil
		lastPosition = nil
		return
	end
	model.Parent = Workspace
	local feet = current.Position - Vector3.new(0, 0.5, 0)
	local previous = lastPosition
	local moved = if previous then (feet - previous).Magnitude else 0
	lastPosition = feet
	local camera = Workspace.CurrentCamera
	-- He faces the way he walks, but turns in jerks of fifteen degrees, never smoothly.
	if previous and moved > 0.01 then
		local step = feet - previous
		if Vector3.new(step.X, 0, step.Z).Magnitude > 0.001 then
			local yaw = math.atan2(-step.X, -step.Z)
			heading = math.floor(yaw / math.rad(15) + 0.5) * math.rad(15)
		end
	end
	facing = CFrame.new(feet) * CFrame.Angles(0, heading, 0)
	-- A stiff walk: the whole body dips with each step. The anchor only moves ten times a second,
	-- so "walking" lasts a moment past each move rather than only on the frames it jumps.
	if moved > 0.01 then
		movingUntil = os.clock() + 0.25
	end
	if os.clock() < movingUntil then
		bob += dt * 7
		stepClock -= dt
		if stepClock <= 0 then
			stepClock = if current:GetAttribute("Hunting") == true then 0.3 else 0.6
			AudioDirector.playAt("Step", feet, 0.55, 45)
		end
	end
	local dip = CFrame.new(0, -math.abs(math.sin(bob)) * 0.15, 0)
	for _, item in pieces do
		item.part.CFrame = facing * dip * item.offset
	end
	local hunting = current:GetAttribute("Hunting") == true
	setEyes(hunting)
	-- The lens finds him in any dark.
	outline.Enabled = LensView.raised
	if camera then
		outline.OutlineTransparency = if hunting then 0 else 0.3
		outline.OutlineColor = if hunting then Palette.Rec else Palette.Paper
	end
end

function UsherView.init(all: { [string]: any })
	controllers = all
	build()
end

function UsherView.start()
	anchor = Workspace:WaitForChild("UsherAnchor", 30) :: BasePart?
	RunService.RenderStepped:Connect(update)
	Net.get("UsherEvent").OnClientEvent:Connect(function(kind: string, id: number?)
		local current = anchor
		if not current then
			return
		end
		if kind == "punch" then
			-- Two dry clicks of the ticket punch, somewhere in the dark.
			AudioDirector.playAt("Wrong", current.Position, 0.7, 70)
			task.delay(0.18, function()
				AudioDirector.playAt("Wrong", current.Position, 0.6, 70)
			end)
		elseif kind == "noticed" and id == Players.LocalPlayer.UserId then
			AudioDirector.play("Reach", 0.7, 1.15)
			controllers.Hud.subtitle(Strings.get("usher_noticed"), 3)
		end
	end)
end

return UsherView
