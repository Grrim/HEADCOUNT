--!strict
-- Runs Core/Registrar on a fixed step and turns its events into the world. The figure itself is
-- drawn by each client: here it is only an invisible anchor part.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Registrar = require(ReplicatedStorage.Shared.Core.Registrar)
local Take = require(ReplicatedStorage.Shared.Core.Take)

local RegistrarAi = {}

local CFG = Config.Registrar
local RULES: Registrar.Config = {
	jumpInterval = CFG.jumpInterval,
	silenceLead = CFG.silenceLead,
	registerTime = CFG.registerTime,
	contactRadius = CFG.contactRadius,
	reachTime = CFG.reachTime,
	graceAfterCut = CFG.graceAfterCut,
}

local services: { [string]: any }
local eventRemote: RemoteEvent
local anchor: Part
local state: Registrar.State? = nil
local running = false
local climax = false
local beganAt = 0
local spoken = false

local function placeAnchor(nodeName: string)
	local node = Layout.NODES[nodeName]
	anchor.Position = Vector3.new(node.x, node.y + CFG.AnchorHeight, node.z)
	anchor:SetAttribute("Node", nodeName)
end

-- How much of the base interval he waits between jumps right now.
local function currentScale(): number
	local take = services.Session.take
	return take.jumpScale
		* Take.partyScale(services.Session.playerCount)
		* (if climax then CFG.ClimaxScale else 1)
end

local function send(kind: string, id: number?)
	eventRemote:FireAllClients(kind, id)
end

local function wake()
	-- Studio only: lets a test walk the whole mission without being hunted.
	if RunService:IsStudio() and Workspace:GetAttribute("DevPauseRegistrar") == true then
		return
	end
	if state and state.dormant then
		state.dormant = false
		state.timer = RULES.jumpInterval
		anchor:SetAttribute("Awake", true)
		if not spoken then
			spoken = true
			services.Session.notify("radio_wake")
		end
	end
end

function RegistrarAi.wake()
	wake()
end

function RegistrarAi.onSessionBegin()
	local take = services.Session.take
	state = Registrar.new(take.registrarStart, RULES)
	local current = state :: Registrar.State
	-- The first take gives the team time to learn the lens before anything hunts them.
	current.dormant = take.number == 1
	anchor:SetAttribute("Awake", not current.dormant)
	placeAnchor(current.node)
	beganAt = os.clock()
	running = true
end

function RegistrarAi.stop()
	running = false
end

function RegistrarAi.setClimax()
	climax = true
	wake()
	if state and not state.dormant then
		Registrar.hasten(state, RULES, currentScale())
	end
	anchor:SetAttribute("Climax", true)
end

-- A mistake on the team's part pulls him one node toward whoever made it.
function RegistrarAi.proceduralError(player: Player)
	wake()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not state or not root then
		return
	end
	local p = root.Position
	local event = Registrar.onReplay(state, Layout.NODES, p.X, p.Y, p.Z)
	if event and event.node then
		placeAnchor(event.node)
		send("jump")
	end
end

function RegistrarAi.onReplay(player: Player, totalReplays: number)
	if totalReplays >= CFG.WakeAfterReplays then
		wake()
	end
	if totalReplays == CFG.WakeAfterReplays then
		services.Session.notifyOne(player, "radio_replay")
	end
	if not state or Registrar.replaySteps(totalReplays) == 0 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local p = root.Position
	local event = Registrar.onReplay(state, Layout.NODES, p.X, p.Y, p.Z)
	if event and event.node then
		placeAnchor(event.node)
		send("jump")
	end
end

local function gatherPlayers(): { Registrar.PlayerInput }
	local list: { Registrar.PlayerInput } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local p = root.Position
			table.insert(list, {
				id = player.UserId,
				x = p.X,
				y = p.Y,
				z = p.Z,
				cut = player:GetAttribute("OffFrame") == true,
			})
		end
	end
	return list
end

local function apply(events: { Registrar.Event })
	for _, event in events do
		local kind = event.kind
		if kind == "jump" or kind == "retreat" then
			placeAnchor(event.node :: string)
			send(if kind == "jump" then "jump" else "retreat")
		elseif kind == "preJump" then
			send("preJump")
		elseif kind == "reach" or kind == "reachCancelled" or kind == "registered" then
			send(kind, event.id)
			if kind == "registered" then
				local player = Players:GetPlayerByUserId(event.id :: number)
				if player then
					services.Session.notifyOne(player, "radio_register")
				end
			end
		elseif kind == "cut" then
			send("cut", event.id)
			local player = Players:GetPlayerByUserId(event.id :: number)
			if player then
				services.OffFrame.cut(player)
			end
		end
	end
end

function RegistrarAi.init(all: { [string]: any })
	services = all
	eventRemote = Net.get("RegistrarEvent")
	anchor = Instance.new("Part")
	anchor.Name = "RegistrarAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.Position = Vector3.new(0, -100, 0)
	anchor.Parent = Workspace
end

function RegistrarAi.start()
	local nextFalseSilence = os.clock() + CFG.FalseSilenceCheckEvery
	local random = Random.new()
	while true do
		task.wait(CFG.StepSeconds)
		local current = state
		if not running or not current then
			continue
		end
		if current.dormant and os.clock() - beganAt >= CFG.WakeAfterSeconds then
			wake()
		end
		if current.dormant then
			continue
		end
		local framers = services.Lens.framers(anchor.Position)
		local framedBy = {}
		for _, player in framers do
			table.insert(framedBy, player.UserId)
			local exposure = current.exposure[player.UserId] or 0
			eventRemote:FireClient(player, "exposure", math.min(exposure / RULES.registerTime, 1))
		end
		local players = gatherPlayers()
		apply(
			Registrar.step(
				current,
				RULES,
				Layout.NODES,
				CFG.StepSeconds,
				framedBy,
				players,
				currentScale()
			)
		)

		-- Now and then silence means nothing, so the team can never fully trust it.
		if os.clock() >= nextFalseSilence then
			nextFalseSilence = os.clock() + CFG.FalseSilenceCheckEvery
			if random:NextNumber() < CFG.FalseSilenceChance then
				send("preJump")
			end
		end
	end
end

return RegistrarAi
