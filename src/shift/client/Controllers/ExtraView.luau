--!strict
-- The Extra as seen from here. To the eye it is the copy of a teammate the server walks around
-- (ShiftExtra). Through the lens, on a tape, or cut out of frame, that copy is not there: in its
-- place stands what it is, a figure in an usher's black suit, far too tall, whose head is out of
-- any frame taken from up close.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local ExtraView = {}

local SUIT = Color3.fromRGB(18, 18, 22)
local HEIGHT = 10.5

local controllers: { [string]: any }
local layer: Folder? = nil
local form: Model
local pieces: { { part: BasePart, offset: CFrame } } = {}
local hiddenFor: Model? = nil

local function piece(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Parent = form
	table.insert(pieces, { part = part, offset = offset })
end

-- Built standing on its feet at the origin, facing -Z.
local function build()
	form = Instance.new("Model")
	form.Name = "ExtraTrueForm"
	local leg = HEIGHT * 0.5
	piece(Vector3.new(0.5, leg, 0.6), CFrame.new(-0.35, leg / 2, 0), SUIT)
	piece(Vector3.new(0.5, leg, 0.6), CFrame.new(0.35, leg / 2, 0), SUIT)
	local torso = HEIGHT * 0.3
	piece(Vector3.new(1.5, torso, 0.7), CFrame.new(0, leg + torso / 2, 0), SUIT)
	-- Arms to below the knee, hanging a little forward.
	local arm = HEIGHT * 0.55
	for side = -1, 1, 2 do
		piece(
			Vector3.new(0.35, arm, 0.35),
			CFrame.new(side * 0.95, leg + torso - arm / 2, -0.15) * CFrame.Angles(math.rad(6), 0, 0),
			SUIT
		)
		piece(
			Vector3.new(0.3, 0.6, 0.18),
			CFrame.new(side * 0.95, leg + torso - arm - 0.2, -0.3),
			Palette.Skin
		)
	end
	-- A long neck and a small head, with the black bar every one of them wears over the eyes.
	local neck = HEIGHT * 0.12
	piece(Vector3.new(0.35, neck, 0.35), CFrame.new(0, leg + torso + neck / 2, 0), Palette.Skin)
	local headY = leg + torso + neck + 0.45
	piece(Vector3.new(0.9, 1, 0.9), CFrame.new(0, headY, 0), Palette.Skin, Enum.PartType.Ball)
	piece(Vector3.new(0.96, 0.22, 0.1), CFrame.new(0, headY + 0.08, -0.45), Palette.Ink)
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineColor = Palette.Paper
	glow.OutlineTransparency = 0.35
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = form
end

local function setHidden(model: Model, hidden: boolean)
	local value = if hidden then 1 else 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = value
		end
	end
end

local function trueSight(): boolean
	return LensView.raised or controllers.ShiftPlayback.active() or controllers.Audience.offFrame
end

local function update()
	local current = layer
	local disguise = current and current:FindFirstChild("Extra")
	if not disguise or not disguise:IsA("Model") then
		form.Parent = nil
		hiddenFor = nil
		return
	end
	local showTruth = trueSight()
	if showTruth and hiddenFor ~= disguise then
		setHidden(disguise, true)
		hiddenFor = disguise
	elseif not showTruth and hiddenFor == disguise then
		setHidden(disguise, false)
		hiddenFor = nil
	end
	if not showTruth then
		form.Parent = nil
		return
	end
	local pivot = disguise:GetPivot()
	local look = pivot.LookVector
	local feet = Vector3.new(pivot.Position.X, 0, pivot.Position.Z)
	local facing = CFrame.lookAt(feet, feet + Vector3.new(look.X, 0, look.Z))
	for _, item in pieces do
		item.part.CFrame = facing * item.offset
	end
	form.Parent = Workspace
end

function ExtraView.init(all: { [string]: any })
	controllers = all
	build()
end

function ExtraView.start()
	layer = Workspace:WaitForChild("ExtraLayer", 30) :: Folder?
	RunService.RenderStepped:Connect(update)
	Net.get("ExtraEvent").OnClientEvent:Connect(function(kind: string, arg: any)
		if kind == "turned" then
			-- Only its mark hears it: whoever it was pretending to be has stopped pretending.
			AudioDirector.play("Reach", 0.5, 0.8)
		elseif kind == "cut" and arg == Players.LocalPlayer.UserId then
			AudioDirector.play("Cut", 0.9)
		elseif kind == "revealed" and typeof(arg) == "Vector3" then
			AudioDirector.playAt("Wrong", arg, 0.9, 60)
			LensView.flash(0.8)
		end
	end)
end

return ExtraView
