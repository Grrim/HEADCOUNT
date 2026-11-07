--!strict
-- The Registrar as seen from here. His neck grows with the camera: wherever you tilt, the head
-- stays above the top of the frame. Nobody has seen his head, and the code makes sure of it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Props = require(ReplicatedStorage.Shared.World.Props)

local RegistrarView = {}

local BODY_HEIGHT = 15
local MAX_NECK = 90

local model: Model
local neck: Part
local parts: { { part: Part, offset: CFrame } } = {}
local anchor: BasePart
local controllers: { [string]: any }
local override: CFrame? = nil

local function build()
	model = Instance.new("Model")
	model.Name = "Registrar"
	-- 15 studs to the shoulders. The mesh stops at the collar; the neck is what the code adds.
	local scale = BODY_HEIGHT / 11.196
	local body = Props.place(model, "Registrar", CFrame.new(), scale)
	body.CanQuery = false
	table.insert(parts, { part = body, offset = CFrame.new(0, BODY_HEIGHT / 2, 0) })
	neck = Instance.new("Part")
	neck.Anchored = true
	neck.CanCollide = false
	neck.CanQuery = false
	neck.CanTouch = false
	neck.Size = Vector3.new(0.75, 4, 0.75)
	neck.Color = Palette.Skin
	neck.Material = Enum.Material.SmoothPlastic
	neck.Parent = model
end

local function shouldShow(): boolean
	if override then
		return true
	end
	if anchor:GetAttribute("Awake") ~= true then
		return false
	end
	local audience = controllers.Audience
	return LensView.raised or audience.climax or audience.offFrame
end

local function update()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if not shouldShow() then
		model.Parent = nil
		LensView.setInterference(0)
		return
	end
	model.Parent = Workspace
	local cameraCf = camera.CFrame
	local gap = (anchor.Position - cameraCf.Position).Magnitude
	LensView.setInterference(if override then 0.5 else math.clamp(1 - gap / 45, 0, 0.9))
	local feet: Vector3
	if override then
		feet = (override :: CFrame).Position
	else
		feet = anchor.Position - Vector3.new(0, Config.Registrar.AnchorHeight, 0)
	end
	local flatTarget = Vector3.new(cameraCf.Position.X, feet.Y, cameraCf.Position.Z)
	local root = if (flatTarget - feet).Magnitude > 0.1
		then CFrame.lookAt(feet, flatTarget)
		else CFrame.new(feet)
	for _, item in parts do
		item.part.CFrame = root * item.offset
	end
	-- Where the top edge of the frame crosses his position, plus a margin.
	local offset = feet - cameraCf.Position
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local pitch = math.asin(math.clamp(cameraCf.LookVector.Y, -1, 1))
	local topAngle = math.min(pitch + math.rad(camera.FieldOfView / 2), math.rad(85))
	local topOfFrame = cameraCf.Position.Y + math.tan(topAngle) * distance
	local shoulders = feet.Y + BODY_HEIGHT - 0.7
	local neckTop = math.clamp(topOfFrame + 4, shoulders + 3, shoulders + MAX_NECK)
	local length = neckTop - shoulders
	neck.Size = Vector3.new(0.75, length, 0.75)
	neck.CFrame = CFrame.new(feet.X, shoulders + length / 2, feet.Z)
end

-- During playback he is placed relative to the lens, not the world.
function RegistrarView.setOverride(cf: CFrame?)
	override = cf
end

function RegistrarView.init(all: { [string]: any })
	controllers = all
	build()
end

function RegistrarView.start()
	anchor = Workspace:WaitForChild("RegistrarAnchor") :: BasePart
	RunService:BindToRenderStep("RegistrarView", Enum.RenderPriority.Camera.Value + 2, update)
	Net.get("RegistrarEvent").OnClientEvent:Connect(function(kind: string)
		if kind == "jump" or kind == "retreat" then
			AudioDirector.playAt("RegistrarJump", anchor.Position, 0.7)
		end
	end)
end

return RegistrarView
