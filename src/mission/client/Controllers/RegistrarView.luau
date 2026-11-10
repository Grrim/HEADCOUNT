--!strict
-- The Registrar as seen from here. His neck grows with the camera: wherever you tilt, the head
-- stays above the top of the frame. Nobody has seen his head, and the code makes sure of it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local RegistrarView = {}

local BODY_HEIGHT = 15
local MAX_NECK = 90

local model: Model
local neck: Part
local parts: { { part: Part, offset: CFrame } } = {}
local anchor: BasePart
local controllers: { [string]: any }
local override: CFrame? = nil
-- Stop-motion state: the last pose drawn, when, and the current jerk off true.
local lastPose = 0
local pose = CFrame.new()
local twitch = CFrame.new()
local nextTwitch = 0
local twitchRandom = Random.new()
-- The arm that reaches for whoever he is about to cut.
local arm: Part
local hand: Part
local fingers: { Part } = {}
local reachTarget: Player? = nil
local reachStart = 0

-- The parts of the right arm that hang at his side; they fold away while the long reaching arm
-- is out, so he never has three arms.
local rightArm: { Part } = {}

local SUIT = Color3.fromRGB(60, 62, 68)
local SUIT_DARK = Color3.fromRGB(36, 38, 42)
local SHIRT = Color3.fromRGB(196, 190, 172)
local TIE = Color3.fromRGB(58, 30, 30)
local HAND = Color3.fromRGB(198, 192, 178)

-- One piece of him, posed relative to the point between his feet (facing -Z, towards whoever
-- looks at him).
local function piece(
	shape: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p: Part = if shape == "Wedge"
		then Instance.new("WedgePart") :: any
		else Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = model
	table.insert(parts, { part = p, offset = offset })
	return p
end

-- A limb hung between two points: a box stretched from `a` to `b`.
local function bone(
	a: Vector3,
	b: Vector3,
	thickness: Vector2,
	color: Color3,
	material: Enum.Material
): Part
	local length = (b - a).Magnitude
	-- A near-vertical limb needs a sideways "up", or its roll would be undefined.
	local up = if math.abs((b - a).Unit.Y) > 0.7 then Vector3.zAxis else Vector3.yAxis
	local offset = CFrame.lookAt(a, b, up) * CFrame.new(0, 0, -length / 2)
	return piece("Block", Vector3.new(thickness.X, thickness.Y, length), offset, color, material)
end

-- The figure: 15 studs to the shoulders, built from plain parts so its proportions can be what a
-- person's are not. Narrow, sloping shoulders and a slight hunch; knees bent the wrong way; a
-- jacket a size too big; arms long enough that the hands hang below the knees, with pale fingers
-- longer than the palm. In the dark, through the grain of the lens, the silhouette is what reads.
local function buildBody()
	-- Plain cloth: the project overrides Fabric with its carpet texture, which sparkles on a suit.
	local fabric = Enum.Material.SmoothPlastic
	local skin = Enum.Material.SmoothPlastic
	-- Shoes, pointed a little inwards.
	for _, side in { -1, 1 } do
		piece(
			"Block",
			Vector3.new(0.75, 0.45, 1.7),
			CFrame.new(side * 0.5, 0.22, -0.25) * CFrame.Angles(0, math.rad(-side * 8), 0),
			SUIT_DARK,
			Enum.Material.SmoothPlastic
		)
		-- Shin leaning back and thigh leaning forward: the knee locks the wrong way.
		local ankle = Vector3.new(side * 0.5, 0.45, 0.1)
		local knee = Vector3.new(side * 0.42, 4.1, 0.55)
		local hip = Vector3.new(side * 0.55, 7.6, 0)
		bone(ankle, knee, Vector2.new(0.78, 0.82), SUIT, fabric)
		bone(knee, hip, Vector2.new(0.92, 0.98), SUIT, fabric)
	end
	-- Jacket: a long body, hem below the hips, a little wider at the chest than the waist.
	piece("Block", Vector3.new(2.25, 2.4, 1.25), CFrame.new(0, 8.4, 0), SUIT, fabric)
	local chest = piece(
		"Block",
		Vector3.new(2.45, 4.4, 1.3),
		CFrame.new(0, 11.7, -0.05) * CFrame.Angles(math.rad(6), 0, 0),
		SUIT,
		fabric
	)
	-- A faint cold light that travels with him: in the dark he is a presence on the seats
	-- around him before he is a shape. One light, no shadows, cheap on a phone.
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(196, 212, 228)
	glow.Brightness = 0.7
	glow.Range = 11
	glow.Shadows = false
	glow.Parent = chest
	-- Shoulders slope down steeply from the collar: two wedges.
	for _, side in { -1, 1 } do
		piece(
			"Wedge",
			Vector3.new(1.3, 0.9, 1.3),
			CFrame.new(side * 0.62, 14.35, -0.25) * CFrame.Angles(0, math.rad(-side * 90), 0),
			SUIT,
			fabric
		)
	end
	-- Shirt front, collar and tie, seen through the open jacket.
	piece(
		"Block",
		Vector3.new(0.7, 3.2, 0.1),
		CFrame.new(0, 12.6, -0.72) * CFrame.Angles(math.rad(6), 0, 0),
		SHIRT,
		skin
	)
	piece(
		"Block",
		Vector3.new(0.22, 2.9, 0.12),
		CFrame.new(0, 12.5, -0.79) * CFrame.Angles(math.rad(6), 0, 0),
		TIE,
		fabric
	)
	piece("Block", Vector3.new(1.1, 0.45, 1.0), CFrame.new(0, 14.75, -0.15), SHIRT, skin)
	-- Lapels, slightly darker than the jacket.
	for _, side in { -1, 1 } do
		piece(
			"Block",
			Vector3.new(0.4, 2.6, 0.08),
			CFrame.new(side * 0.55, 13.0, -0.76)
				* CFrame.Angles(math.rad(6), 0, math.rad(side * 12)),
			SUIT_DARK,
			fabric
		)
	end
	-- Arms: from the low shoulder to below the knee.
	for _, side in { -1, 1 } do
		local shoulder = Vector3.new(side * 1.35, 14.0, -0.1)
		local elbow = Vector3.new(side * 1.6, 9.4, 0.15)
		local wrist = Vector3.new(side * 1.5, 4.6, -0.2)
		local made = {
			bone(shoulder, elbow, Vector2.new(0.62, 0.66), SUIT, fabric),
			bone(elbow, wrist, Vector2.new(0.56, 0.6), SUIT, fabric),
		}
		-- A shirt cuff, then the hand: a narrow palm and four long fingers hanging straight down.
		table.insert(
			made,
			bone(wrist, wrist - Vector3.new(0, 0.3, 0), Vector2.new(0.6, 0.6), SHIRT, skin)
		)
		local palmTop = wrist - Vector3.new(0, 0.3, 0)
		local palmBottom = palmTop - Vector3.new(0, 1.1, 0)
		table.insert(made, bone(palmTop, palmBottom, Vector2.new(0.3, 0.7), HAND, skin))
		for finger = 1, 4 do
			local z = -0.24 + (finger - 1) * 0.16
			local root = palmBottom + Vector3.new(0, 0, z)
			local tip = root
				+ Vector3.new(side * 0.05, -1.55 + math.abs(finger - 2.5) * 0.18, z * 0.3)
			table.insert(made, bone(root, tip, Vector2.new(0.15, 0.15), HAND, skin))
		end
		if side == 1 then
			rightArm = made
		end
	end
end

local function build()
	model = Instance.new("Model")
	model.Name = "Registrar"
	buildBody()
	neck = Instance.new("Part")
	neck.Anchored = true
	neck.CanCollide = false
	neck.CanQuery = false
	neck.CanTouch = false
	neck.Size = Vector3.new(0.75, 4, 0.75)
	neck.Color = Palette.Skin
	neck.Material = Enum.Material.SmoothPlastic
	neck.Parent = model
	local function limb(size: Vector3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.Color = Palette.Skin
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 1
		p.Parent = model
		return p
	end
	arm = limb(Vector3.new(0.45, 0.45, 1))
	arm.Color = Palette.Suit
	hand = limb(Vector3.new(0.9, 0.25, 1))
	for _ = 1, 4 do
		table.insert(fingers, limb(Vector3.new(0.13, 0.13, 1.5)))
	end
end

local function hideArm()
	for _, part in rightArm do
		part.Transparency = 0
	end
	arm.Transparency = 1
	hand.Transparency = 1
	for _, finger in fingers do
		finger.Transparency = 1
	end
end

-- Over the reach window the arm unfolds from his shoulder towards the target's face, the long
-- fingers last. It never quite arrives: the cut happens first, or a lens stops it.
local function updateArm(at: CFrame, shoulderPoint: Vector3)
	-- Not on a tape (he is placed by the lens there), and never left hanging: a reach that got no
	-- answer (the mission ended mid-reach) folds away on its own.
	if override or os.clock() > reachStart + Config.Registrar.reachTime + 0.5 then
		reachTarget = nil
		hideArm()
		return
	end
	local target = reachTarget
	local character = target and target.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		hideArm()
		return
	end
	local progress = math.clamp((os.clock() - reachStart) / Config.Registrar.reachTime, 0, 1)
	progress = 1 - (1 - progress) ^ 3
	-- His right shoulder: `at` stands on the floor and faces the camera.
	local start = (at * CFrame.new(1.35, BODY_HEIGHT - 1.0, -0.1)).Position
	-- The arm that hung at his side is the one that reaches.
	for _, part in rightArm do
		part.Transparency = 1
	end
	if (start - shoulderPoint).Magnitude > 6 then
		start = shoulderPoint
	end
	local goal = head.Position
	-- A target far across the room is not his to reach from here.
	if (goal - shoulderPoint).Magnitude > 20 then
		hideArm()
		return
	end
	local tip = start:Lerp(goal, 0.92 * progress)
	local length = math.max(0.5, (tip - start).Magnitude)
	arm.Size = Vector3.new(0.45, 0.45, length)
	arm.CFrame = CFrame.lookAt(start, tip) * CFrame.new(0, 0, -length / 2)
	arm.Transparency = 0
	local palm = CFrame.lookAt(tip, goal)
	hand.CFrame = palm * CFrame.new(0, 0, -0.5)
	hand.Transparency = 0
	for index, finger in fingers do
		-- Spread, and curling in as they near.
		local spread = (index - 2.5) * 0.22
		local curl = math.rad(25) * progress
		finger.CFrame = palm
			* CFrame.new(spread, 0, -1)
			* CFrame.Angles(-curl, 0, 0)
			* CFrame.new(0, 0, -0.75)
		finger.Transparency = 0
	end
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
	local offset = feet - cameraCf.Position
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local nearness = math.clamp(1 - (distance - 6) / 40, 0, 1)
	-- Up close he moves wrong: the body only updates a few times a second, like stop-motion
	-- with frames missing, and every so often it jerks to a new angle.
	local now = os.clock()
	local frameRate = 30 - 22 * nearness
	if now - lastPose >= 1 / frameRate then
		lastPose = now
		if now >= nextTwitch then
			nextTwitch = now + twitchRandom:NextNumber(0.5, 2.2) * (1.3 - nearness)
			local strength = 0.05 + 0.2 * nearness
			twitch = CFrame.Angles(
				twitchRandom:NextNumber(-strength, strength) * 0.4,
				twitchRandom:NextNumber(-strength, strength),
				twitchRandom:NextNumber(-strength, strength) * 0.6
			)
		end
		-- He leans in over whoever is close, as if to read a name off them.
		local lean = CFrame.Angles(-math.rad(14) * nearness, 0, 0)
		pose = root * lean * twitch
	end
	for _, item in parts do
		item.part.CFrame = pose * item.offset
	end
	-- The neck starts where the leaning shoulders are and climbs out of the top of the frame:
	-- where its top edge crosses his position, plus a margin. That part stays smooth, so the head
	-- can never show between two stuttered frames.
	local shoulderPoint = (pose * CFrame.new(0, BODY_HEIGHT - 0.7, 0)).Position
	local pitch = math.asin(math.clamp(cameraCf.LookVector.Y, -1, 1))
	local topAngle = math.min(pitch + math.rad(camera.FieldOfView / 2), math.rad(85))
	-- Measured to the neck itself, which stands on the drawn (possibly stale) pose, not the feet.
	local toNeck = shoulderPoint - cameraCf.Position
	local neckDistance = Vector3.new(toNeck.X, 0, toNeck.Z).Magnitude
	local topOfFrame = cameraCf.Position.Y + math.tan(topAngle) * neckDistance
	local shoulders = shoulderPoint.Y
	local neckTop = math.clamp(topOfFrame + 4, shoulders + 3, shoulders + MAX_NECK)
	local length = neckTop - shoulders
	neck.Size = Vector3.new(0.75, length, 0.75)
	neck.CFrame = CFrame.new(shoulderPoint.X, shoulders + length / 2, shoulderPoint.Z)
	updateArm(pose, shoulderPoint)
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
	Net.get("RegistrarEvent").OnClientEvent:Connect(function(kind: string, id: number?)
		if kind == "reach" and id then
			reachTarget = Players:GetPlayerByUserId(id)
			reachStart = os.clock()
		elseif kind == "reachCancelled" or kind == "cut" or kind == "jump" or kind == "retreat" then
			reachTarget = nil
			hideArm()
		end
		if kind == "jump" or kind == "retreat" then
			AudioDirector.playAt("RegistrarJump", anchor.Position, 0.7)
		end
	end)
end

return RegistrarView
