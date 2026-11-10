--!strict
-- The body knows he is near before the eyes do. Once the Registrar is awake, the closer he stands
-- the faster the heart and the darker the edges of the picture; when he cuts to a new place, the
-- lights around him stutter. Nothing here is a rule of the game, only the feeling of one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Dread = {}

-- Distance at which the heart starts to race, and at which it is as fast as it gets.
local FAR = 62
local NEAR = 12
local FLICKER_RADIUS = 48

local controllers: { [string]: any }
local anchor: BasePart? = nil
local edge: Frame
local edges: { Frame } = {}
local intensity = 0
local ended = false

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function measure(): number
	local current = anchor
	local root = localRoot()
	if ended or not current or not root or current:GetAttribute("Awake") ~= true then
		return 0
	end
	if Players.LocalPlayer:GetAttribute("OffFrame") == true then
		return 0
	end
	local offset = current.Position - root.Position
	-- He hangs well above the floor; what matters is how far across the room he is.
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	return math.clamp((FAR - distance) / (FAR - NEAR), 0, 1)
end

local function buildGui()
	local gui = Ui.screen("Dread", 1, true)
	-- A deep red rim that closes in with every beat.
	edge = Ui.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 0, 0),
		BackgroundTransparency = 1,
		Active = false,
	}, gui)
	Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.7, 0.75),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, edge)
	-- A second sheet turned a quarter, so the rim closes in from above and below too.
	local across = edge:Clone()
	across.Parent = gui
	local turn = across:FindFirstChildOfClass("UIGradient") :: UIGradient
	turn.Rotation = 90
	edges = { edge, across }
end

local function heartLoop()
	while true do
		local level = intensity
		if level < 0.12 or controllers.Playback.active() then
			task.wait(0.4)
		else
			local interval = lerp(1.15, 0.42, level)
			AudioDirector.play("Heartbeat", lerp(0.18, 0.5, level), 0.55)
			task.wait(0.16)
			AudioDirector.play("Heartbeat", lerp(0.12, 0.38, level), 0.5)
			task.wait(math.max(0.1, interval - 0.16))
		end
	end
end

-- The lights near his new place blink, as if the power stumbled when he arrived.
local function flickerNear(position: Vector3)
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local touched: { { light: Light, brightness: number, dim: number? } } = {}
	for _, item in map:GetDescendants() do
		-- Lights already mid-flicker, or switched off, are not touched twice.
		local busy = item:GetAttribute("FlickerBase") ~= nil
		if item:IsA("Light") and item.Enabled and item.Brightness > 0 and not busy then
			local parent = item.Parent
			if parent and parent:IsA("BasePart") then
				if (parent.Position - position).Magnitude < FLICKER_RADIUS then
					table.insert(touched, { light = item, brightness = item.Brightness })
					-- The true level, for anything else that dims this light meanwhile (blackout).
					item:SetAttribute("FlickerBase", item.Brightness)
				end
			end
		end
	end
	if #touched == 0 then
		return
	end
	task.spawn(function()
		local random = Random.new()
		-- If the server changes a light meanwhile (the mains going out), its value wins: a light
		-- that no longer shows what this loop last set is left alone.
		local function ours(entry: any, value: number): boolean
			return math.abs(entry.light.Brightness - value) < 1e-3
		end
		for _ = 1, 4 do
			for _, entry in touched do
				if ours(entry, entry.brightness) then
					entry.dim = entry.brightness * random:NextNumber(0, 0.25)
					entry.light.Brightness = entry.dim
				else
					entry.dim = nil
				end
			end
			task.wait(random:NextNumber(0.04, 0.1))
			for _, entry in touched do
				if entry.dim and ours(entry, entry.dim) then
					entry.light.Brightness = entry.brightness
				end
			end
			task.wait(random:NextNumber(0.05, 0.16))
		end
		for _, entry in touched do
			entry.light:SetAttribute("FlickerBase", nil)
		end
	end)
end

function Dread.init(all: { [string]: any })
	controllers = all
	buildGui()
end

function Dread.start()
	anchor = Workspace:WaitForChild("RegistrarAnchor", 30) :: BasePart?
	Net.get("RegistrarEvent").OnClientEvent:Connect(function(kind: string)
		if kind == "jump" and anchor then
			task.defer(flickerNear, (anchor :: BasePart).Position)
		end
	end)
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		ended = state.phase == "Done" or state.phase == "Failed"
	end)
	task.spawn(heartLoop)
	local beat = 0
	RunService.RenderStepped:Connect(function(dt)
		-- Eases towards the measured level, so a jump is felt over a second, not in one frame.
		intensity += (measure() - intensity) * math.min(1, dt * 1.5)
		beat += dt * lerp(0.9, 2.4, intensity) * math.pi * 2
		local pulse = 0.75 + 0.25 * math.sin(beat)
		local hidden = intensity < 0.05 or controllers.Playback.active()
		local alpha = if hidden then 1 else 1 - 0.55 * intensity * pulse
		for _, sheet in edges do
			sheet.BackgroundTransparency = alpha
		end
	end)
end

return Dread
