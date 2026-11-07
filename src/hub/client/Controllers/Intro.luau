--!strict
-- The first minutes: a room, a chair, a camera, and someone in the chair who is only there through
-- the lens. Doors, sitters and the hidden room are local to this client, because each player is
-- on their own timeline here. Nothing in this file can grant progress beyond its own intro flag.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Build = require(ReplicatedStorage.Shared.World.Build)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Framing = require(ReplicatedStorage.Shared.Core.Framing)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Props = require(ReplicatedStorage.Shared.World.Props)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Intro = {}

local layer: Folder
local sitter: Model
local gui: ScreenGui
local hintLabel: TextLabel
local raises = 0
local hasCamera = false
local screenLabel: TextLabel? = nil
local introComplete = false

local function hint(text: string)
	hintLabel.Text = text
end

local function ghostPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, ball: boolean?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if ball then
		p.Shape = Enum.PartType.Ball
	end
	p.Parent = parent
	return p
end

local function buildSitter(parent: Instance, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Sitter"
	Props.sitter(model, cf, 4)
	model.Parent = parent
	return model
end

local function openDoor()
	for _, door in CollectionService:GetTagged("IntroDoor") do
		local part = door :: BasePart
		part.CanCollide = false
		part.Transparency = 1
	end
end

local function enableLens()
	if hasCamera then
		return
	end
	hasCamera = true
	Input.bind(
		"Lens",
		function()
			LensView.toggle()
		end,
		{ Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2, Enum.KeyCode.Q },
		Strings.get("btn_lens"),
		1
	)
end

local function completeIntro(silently: boolean)
	if introComplete then
		return
	end
	introComplete = true
	enableLens()
	openDoor()
	hint("")
	if not silently then
		hint(Strings.get("intro_door"))
		task.delay(6, hint, "")
		Net.get("IntroAction"):FireServer("done")
	end
	for _, camera in CollectionService:GetTagged("IntroCamera") do
		local part = camera :: BasePart
		part.Transparency = 1
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end
end

local function onLens(raised: boolean)
	layer.Parent = if raised then Workspace else nil
	if not raised then
		if raises == 1 and not introComplete then
			hint(Strings.get("intro_again"))
		end
		return
	end
	raises += 1
	if raises == 1 and not introComplete then
		hint("")
	elseif raises == 2 and not introComplete then
		-- The chair is empty now. The figure is behind where the player is standing.
		sitter:PivotTo(CFrame.new(6, 0, 56) * CFrame.Angles(0, math.rad(200), 0))
		AudioDirector.play("Reach", 0.4)
		task.delay(1.4, completeIntro, false)
	end
end

local function setupCamera()
	for _, camera in CollectionService:GetTagged("IntroCamera") do
		local part = camera :: BasePart
		local prompt = Build.prompt(part, "act_take_camera", "obj_camera", nil, 8)
		task.defer(function()
			prompt.ActionText = Strings.get("act_take_camera")
			prompt.ObjectText = Strings.get("obj_camera")
		end)
		prompt.Triggered:Connect(function()
			part.Transparency = 1
			prompt.Enabled = false
			enableLens()
			hint(Strings.get("intro_raise"))
			AudioDirector.play("LensUp", 0.5)
		end)
	end
end

-- A wall in the hall that has a door in it, but only behind the lens.
local function setupHiddenDoor()
	local door = Instance.new("Model")
	door.Name = "SecretDoor"
	ghostPart(door, Vector3.new(0.2, 8.2, 6.6), CFrame.new(-39.3, 4.1, -2), Palette.Wood)
	ghostPart(door, Vector3.new(0.3, 0.5, 0.5), CFrame.new(-39.2, 3.6, -4.2), Palette.Bulb)
	door.Parent = layer
	local cos = math.cos(math.rad(Config.Lens.FramingHalfAngle))
	RunService.Heartbeat:Connect(function()
		local plug = CollectionService:GetTagged("SecretPlug")[1] :: BasePart?
		local camera = Workspace.CurrentCamera
		if not plug or not camera then
			return
		end
		local p, l = camera.CFrame.Position, camera.CFrame.LookVector
		local framed = LensView.raised
			and Framing.isFramed(p.X, p.Y, p.Z, l.X, l.Y, l.Z, -40, 4, -2, cos, 60)
		plug.CanCollide = not framed
	end)
end

-- The one visible way the lobby remembers Mission 001: chairs that were not here before,
-- facing the terminal, with people in them through the lens.
local function applyMemory(flags: { [string]: boolean })
	if flags.introDone then
		completeIntro(true)
	end
	if screenLabel then
		screenLabel.Text = Strings.get(if flags.m001_done then "intro_after" else "intro_hello")
	end
	if flags.m001_done and not Workspace:FindFirstChild("MemoryChairs") then
		local folder = Instance.new("Folder")
		folder.Name = "MemoryChairs"
		for index = 0, 7 do
			local cf = CFrame.new(-12.5 + index * 3.5, 0, -22)
			Build.chair(folder, "Chair", cf).CanCollide = false
			buildSitter(layer, cf)
		end
		folder.Parent = Workspace
	end
end

function Intro.init()
	layer = Instance.new("Folder")
	layer.Name = "LensLayer"
	sitter = buildSitter(layer, CFrame.new(-7, 0, 52) * CFrame.Angles(0, math.rad(40), 0))
	gui = Ui.screen("Intro", 2)
	hintLabel = Ui.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.new(0.6, 0, 0, 60),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextStrokeTransparency = 0.4,
		Text = "",
	}, gui)
end

function Intro.start()
	local map = Workspace:WaitForChild("Map")
	local screen = map:WaitForChild("IntroScreen") :: BasePart
	screenLabel = Build.label(screen, Enum.NormalId.Back, Strings.get("intro_hello"), Palette.Crt)
	LensView.onChanged(onLens)
	setupCamera()
	setupHiddenDoor()
	hint(Strings.get("intro_folder"))
	task.delay(6, function()
		if not hasCamera then
			hint(Strings.get("intro_camera"))
		end
	end)
	Net.get("DocsState").OnClientEvent:Connect(function(state)
		applyMemory(state.flags)
	end)
end

return Intro
