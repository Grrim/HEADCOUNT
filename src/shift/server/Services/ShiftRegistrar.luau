--!strict
-- The Registrar on a shift: the same rules as in Mission 001 (Core/Registrar), on the graph of the
-- floor the lift opened onto. He never enters the lift, but he can stand in its doorway, and the
-- doors only close while someone holds him in frame (ShiftSession.closeDoors).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local Graph = require(ReplicatedStorage.Shared.Core.Graph)
local Net = require(ReplicatedStorage.Shared.Net)
local Registrar = require(ReplicatedStorage.Shared.Core.Registrar)

local ShiftRegistrar = {}

local CFG = Config.Registrar
local SHIFT = Config.Shift
local RULES: Registrar.Config = {
	jumpInterval = CFG.jumpInterval,
	silenceLead = CFG.silenceLead,
	registerTime = CFG.registerTime,
	contactRadius = CFG.contactRadius,
	reachTime = CFG.reachTime,
	graceAfterCut = CFG.graceAfterCut,
	arrivalGrace = CFG.arrivalGrace,
	exposureDecay = CFG.exposureDecay,
}

local services: { [string]: any }
local eventRemote: RemoteEvent
local anchor: Part
local graph: Graph.Graph = {}
local state: Registrar.State? = nil
local running = false
local wakeAt = 0
local depth = 1
local lobbyNode = ""
local framedNow = false

local function placeAnchor(nodeName: string)
	local node = graph[nodeName]
	anchor.Position = Vector3.new(node.x, node.y + CFG.AnchorHeight, node.z)
	anchor:SetAttribute("Node", nodeName)
end

local function send(kind: string, id: number?)
	eventRemote:FireAllClients(kind, id)
end

local function scale(): number
	local players = #Players:GetPlayers()
	local haste = 1 / (1 + SHIFT.HastePerFloor * (depth - 1))
	return haste * (if players <= 1 then SHIFT.SoloSlower else 1)
end

function ShiftRegistrar.setFloor(floor: FloorGen.Floor, floorDepth: number)
	graph = FloorGen.graph(floor)
	depth = floorDepth
	lobbyNode = `r{floor.start}`
	local current = Registrar.new(FloorGen.registrarStart(floor), RULES)
	current.dormant = true
	state = current
	placeAnchor(current.node)
	anchor:SetAttribute("Awake", false)
	-- A first shift gives a new player longer to look round before he wakes.
	local sleep = if services.ShiftSession.guided
		then SHIFT.WakeFirstFloor * 1.6
		elseif floorDepth <= 1 then SHIFT.WakeFirstFloor
		else SHIFT.WakeDeeper
	-- Counted from the doors opening, which comes after the ride.
	wakeAt = os.clock() + SHIFT.RideSeconds + SHIFT.DoorOpenSeconds + sleep
	running = true
end

function ShiftRegistrar.stop()
	running = false
	state = nil
	framedNow = false
	anchor:SetAttribute("Awake", false)
	anchor.Position = Vector3.new(0, -100, 0)
end

-- The rule of every tape (Core/Registrar.onReplay): watching one pulls him one node toward the
-- viewer. ShiftTapes leaves the first viewing on each floor free. Asleep, he does not hear it.
function ShiftRegistrar.onReplay(player: Player)
	local current = state
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not running or not current or not root then
		return
	end
	local p = root.Position
	local event = Registrar.onReplay(current, graph, p.X, 0, p.Z, RULES)
	if event and event.node then
		placeAnchor(event.node)
		send("jump")
	end
end

-- True while he stands in the lift's doorway room and nobody has him in frame.
function ShiftRegistrar.blocksDoor(): boolean
	local current = state
	return running
		and current ~= nil
		and not current.dormant
		and current.node == lobbyNode
		and not framedNow
end

local function framers(): { Player }
	local list = {}
	for _, player in services.Lens.framers(anchor.Position) do
		if services.ShiftSession.lensWorks(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function gatherPlayers(): { Registrar.PlayerInput }
	local list: { Registrar.PlayerInput } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local p = root.Position
			-- Inside the lift nobody can be reached: to him they are already gone.
			local safe = services.ShiftWorld.inLift(p)
			table.insert(list, {
				id = player.UserId,
				x = p.X,
				y = p.Y,
				z = p.Z,
				cut = player:GetAttribute("OffFrame") == true or safe,
				sees = services.Lens.clearLine(p + Vector3.new(0, 1.5, 0), anchor.Position),
				-- Someone stuck watching a tape gets longer to look up and frame him.
				reachBonus = if services.ShiftTapes.isPlaying(player)
					then SHIFT.PlaybackReachBonus
					else 0,
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
			send(kind)
		elseif event.id == services.ShiftTripod.ID then
			-- The tripod's own exposure is nobody's business.
			continue
		elseif
			kind == "preJump"
			or kind == "reach"
			or kind == "reachCancelled"
			or kind == "registered"
		then
			send(kind, event.id)
		elseif kind == "cut" then
			send("cut", event.id)
			local player = Players:GetPlayerByUserId(event.id :: number)
			if player then
				services.ShiftOffFrame.cut(player)
			end
		end
	end
end

function ShiftRegistrar.init(all: { [string]: any })
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
	anchor:SetAttribute("Awake", false)
	anchor.Parent = Workspace
end

function ShiftRegistrar.start()
	local nextFalseSilence = os.clock() + CFG.FalseSilenceCheckEvery
	local random = Random.new()
	while true do
		task.wait(CFG.StepSeconds)
		local current = state
		if not running or not current then
			continue
		end
		if current.dormant then
			-- Studio only: walk a floor without being hunted.
			local paused = RunService:IsStudio()
				and Workspace:GetAttribute("DevPauseRegistrar") == true
			if os.clock() >= wakeAt and not paused then
				current.dormant = false
				anchor:SetAttribute("Awake", true)
				services.ShiftSession.broadcast("Something on this floor is awake.")
				services.ShiftSession.onAwake()
			end
			continue
		end
		local watching = framers()
		-- A tripod that frames him holds him as a raised lens would.
		local tripod = services.ShiftTripod.frames(anchor.Position)
		framedNow = #watching > 0 or tripod
		local framedBy = {}
		if tripod then
			table.insert(framedBy, services.ShiftTripod.ID)
		end
		for _, player in watching do
			table.insert(framedBy, player.UserId)
			local exposure = current.exposure[player.UserId] or 0
			eventRemote:FireClient(player, "exposure", math.min(exposure / RULES.registerTime, 1))
		end
		apply(
			Registrar.step(
				current,
				RULES,
				graph,
				CFG.StepSeconds,
				framedBy,
				gatherPlayers(),
				scale()
			)
		)

		if os.clock() >= nextFalseSilence then
			nextFalseSilence = os.clock() + CFG.FalseSilenceCheckEvery
			if random:NextNumber() < CFG.FalseSilenceChance then
				send("preJump")
			end
		end
	end
end

return ShiftRegistrar
