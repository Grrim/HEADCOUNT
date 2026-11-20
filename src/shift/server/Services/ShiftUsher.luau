--!strict
-- The Usher on the dark floors (from -3, docs/09_GDD_V2.md §2.3). The same rules as in Mission 001
-- (mission/server/Services/UsherAi): he sees nothing but torchlight, a lit torch near him and in
-- his sight draws him in, and if he reaches whoever holds it they are cut out of frame. Walk dark
-- past him and he lets you by. Here he wanders the floor's graph instead of a fixed round, and he
-- never comes into the lift. Like the Registrar he is an invisible anchor; UsherView draws him.
--
-- The flashlight lives here as well: it has to be a real light on the server for him to see it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local Graph = require(ReplicatedStorage.Shared.Core.Graph)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local ShiftUsher = {}

local CFG = Config.Shift
local STEP = 0.1
local WALK_SPEED = 5
local HUNT_SPEED = 11
local NOTICE_RANGE = 16
local TOUCH_RANGE = 2.2
local CATCH_RANGE = 3
local NOTICE_BEFORE_CATCH = 0.9
local GIVE_UP_AFTER = 2.5

local services: { [string]: any }
local anchor: Part
local eventRemote: RemoteEvent
local lightLimit = RateLimit.new(Config.Rates.Flashlight[1], Config.Rates.Flashlight[2])
local random = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local graph: Graph.Graph = {}
local running = false
local activeAt = 0
local position = Vector3.zero
local fromNode = ""
local toNode = ""

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function torchOn(player: Player): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	return light ~= nil and light:IsA("SpotLight") and light.Enabled
end

local function toggleLight(player: Player)
	if not lightLimit:allow(player, os.clock()) then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local light = head:FindFirstChild("Flashlight")
	if light and light:IsA("SpotLight") then
		light.Enabled = not light.Enabled
		return
	end
	local created = Instance.new("SpotLight")
	created.Name = "Flashlight"
	created.Face = Enum.NormalId.Front
	created.Angle = 50
	created.Range = 40
	created.Brightness = 2.2
	created.Shadows = true
	created.Color = Color3.fromRGB(255, 236, 200)
	created.Parent = head
end

local function canSee(from: Vector3, to: Vector3): boolean
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return true
	end
	rayParams.FilterDescendantsInstances = { map }
	return Workspace:Raycast(from, to - from, rayParams) == nil
end

-- Room for his body to take the next step: shelves, desks and door frames stop him.
local function canStep(from: Vector3, to: Vector3): boolean
	local map = Workspace:FindFirstChild("Map")
	local offset = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if not map or offset.Magnitude < 1e-3 then
		return true
	end
	rayParams.FilterDescendantsInstances = { map }
	local reach = offset.Unit * (offset.Magnitude + 0.4)
	return Workspace:Spherecast(from + Vector3.new(0, 1.5, 0), 0.9, reach, rayParams) == nil
end

local function stepToward(from: Vector3, goal: Vector3, distance: number): (Vector3, boolean)
	local offset = goal - from
	if offset.Magnitude <= distance then
		return goal, true
	end
	return from + offset.Unit * distance, false
end

local function nodePosition(name: string): Vector3
	local node = graph[name]
	return Vector3.new(node.x, 0, node.z)
end

-- His round: on to a neighbour, rarely straight back the way he came.
local function nextNode(current: string, previous: string): string
	local edges = table.clone(graph[current].edges)
	table.sort(edges)
	if #edges == 0 then
		return current
	end
	local choices = {}
	for _, edge in edges do
		if edge ~= previous then
			table.insert(choices, edge)
		end
	end
	if #choices == 0 then
		return edges[1]
	end
	return choices[random:NextInteger(1, #choices)]
end

local function send(kind: string, id: number?)
	eventRemote:FireAllClients(kind, id)
end

local function setActive(on: boolean)
	anchor:SetAttribute("Active", on)
	anchor:SetAttribute("Hunting", false)
	if not on then
		anchor.Position = Vector3.new(0, -200, 0)
	end
end

function ShiftUsher.stop()
	running = false
	setActive(false)
end

function ShiftUsher.setFloor(floor: FloorGen.Floor, depth: number)
	ShiftUsher.stop()
	if depth < CFG.UsherFromDepth then
		return
	end
	graph = FloorGen.openGraph(floor)
	local start = `r{floor.start}`
	local registrarNode = FloorGen.registrarStart(floor)
	local options = {}
	for name in graph do
		if string.sub(name, 1, 1) == "r" and name ~= start and name ~= registrarNode then
			table.insert(options, name)
		end
	end
	table.sort(options)
	if #options == 0 then
		return
	end
	fromNode = options[random:NextInteger(1, #options)]
	toNode = nextNode(fromNode, "")
	position = nodePosition(fromNode)
	activeAt = os.clock() + CFG.RideSeconds + CFG.DoorOpenSeconds + CFG.UsherWake
	running = true
end

function ShiftUsher.init(all: { [string]: any })
	services = all
	eventRemote = Net.get("UsherEvent")
	Net.get("FlashlightToggle").OnServerEvent:Connect(toggleLight)
	Players.PlayerRemoving:Connect(function(player)
		lightLimit:forget(player)
	end)
	anchor = Instance.new("Part")
	anchor.Name = "UsherAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = Vector3.new(0, -200, 0)
	anchor:SetAttribute("Active", false)
	anchor:SetAttribute("Hunting", false)
	anchor.Parent = Workspace
end

function ShiftUsher.start()
	local target: Player? = nil
	local lastSeen = 0
	local noticedAt = 0
	local punchAt = 0
	-- Where he walked while chasing, so he goes back to his round the way he came.
	local trail: { Vector3 } = {}
	while true do
		task.wait(STEP)
		local now = os.clock()
		local paused = RunService:IsStudio() and Workspace:GetAttribute("DevPauseRegistrar") == true
		if not running or now < activeAt or paused then
			if anchor:GetAttribute("Active") == true and not running then
				setActive(false)
			end
			target = nil
			trail = {}
			continue
		end
		if anchor:GetAttribute("Active") ~= true then
			setActive(true)
		end
		local chest = position + Vector3.new(0, 4.5, 0)

		-- Who is lit, near and in sight, and not in the lift. The nearest one draws him.
		local best, bestDistance = nil, math.huge
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if
				root
				and player:GetAttribute("OffFrame") ~= true
				and not services.ShiftWorld.inLift(root.Position)
			then
				local distance = (root.Position - chest).Magnitude
				local noticed = distance < TOUCH_RANGE
					or (
						torchOn(player)
						and distance < NOTICE_RANGE
						and canSee(chest, root.Position)
					)
				if noticed and distance < bestDistance then
					best, bestDistance = player, distance
				end
			end
		end
		if best then
			if target ~= best then
				if not target then
					table.insert(trail, position)
				end
				target = best
				noticedAt = now
				anchor:SetAttribute("Hunting", true)
				send("noticed", best.UserId)
			end
			lastSeen = now
		end

		local hunted = target
		local huntedRoot = hunted and rootOf(hunted)
		if
			hunted
			and (
				now - lastSeen > GIVE_UP_AFTER
				or not hunted.Parent
				or not huntedRoot
				or services.ShiftWorld.inLift(huntedRoot.Position)
			)
		then
			target = nil
			hunted = nil
			anchor:SetAttribute("Hunting", false)
			send("lost")
		end

		if hunted and huntedRoot then
			local goal = Vector3.new(huntedRoot.Position.X, 0, huntedRoot.Position.Z)
			local sees = canSee(chest, huntedRoot.Position)
			if sees then
				local nextPosition = stepToward(position, goal, HUNT_SPEED * STEP)
				if canStep(position, nextPosition) then
					position = nextPosition
				end
				if #trail == 0 or (position - trail[#trail]).Magnitude > 1 then
					table.insert(trail, position)
				end
			end
			local close = (huntedRoot.Position - (position + Vector3.new(0, 3, 0))).Magnitude
				< CATCH_RANGE
			if close and sees and now - noticedAt >= NOTICE_BEFORE_CATCH then
				send("caught", hunted.UserId)
				services.ShiftOffFrame.cut(hunted, "usher")
				target = nil
				anchor:SetAttribute("Hunting", false)
			end
		elseif #trail > 0 then
			local arrived
			position, arrived = stepToward(position, trail[#trail], WALK_SPEED * STEP)
			if arrived then
				table.remove(trail)
			end
		else
			local arrived
			position, arrived = stepToward(position, nodePosition(toNode), WALK_SPEED * STEP)
			if arrived then
				local previous = fromNode
				fromNode = toNode
				toNode = nextNode(fromNode, previous)
			end
		end

		if now >= punchAt then
			punchAt = now + random:NextNumber(4, 7.5)
			send("punch")
		end
		anchor.Position = position + Vector3.new(0, 0.5, 0)
	end
end

return ShiftUsher
