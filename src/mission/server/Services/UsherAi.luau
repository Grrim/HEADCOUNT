--!strict
-- The Usher. While the mains are out, someone in a doorman's coat walks the building on a fixed
-- round with a ticket punch, through the dark hall, the stairs and the storage aisles. He cannot
-- see people, only light: a lit flashlight near him draws him in, and if he reaches whoever holds
-- it, they are cut from the frame. A dark torch lets him pass close by. Like the Registrar, he
-- is only an invisible anchor here; each client draws him.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Net = require(ReplicatedStorage.Shared.Net)

local UsherAi = {}

local STEP = 0.1
local WALK_SPEED = 5
local HUNT_SPEED = 11.5
-- A lit torch within this distance and in his line of sight draws him.
local NOTICE_RANGE = 16
-- Anyone who walks into him is found, light or not.
local TOUCH_RANGE = 2.2
-- Reaching a hunted player within this distance cuts them.
local CATCH_RANGE = 3
-- Being found is never the same moment as being caught: after he notices someone he turns to
-- them (the eyes light, a punch sounds) and only then can he take them. Enough to back off.
local NOTICE_BEFORE_CATCH = 0.9
-- How long he keeps after a light that went out before going back to his round.
local GIVE_UP_AFTER = 2.5
-- Grace after the mains go, so nobody is caught before they know he exists.
local START_DELAY = 30

local services: { [string]: any }
local anchor: Part
local eventRemote: RemoteEvent
local route: { Vector3 } = {}
local active = false
local activeSince = 0

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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- Clear sight between his chest and the player's, through the building only (not people).
local function canSee(from: Vector3, to: Vector3): boolean
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return true
	end
	rayParams.FilterDescendantsInstances = { map }
	local hit = Workspace:Raycast(from, to - from, rayParams)
	return hit == nil
end

-- Room for his body to take the next step: a ball at knee height, so seat rows, crates, door
-- frames and the stair wedge stop him even where his eyes see over them.
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

-- The floor he walks on and the player's are the same storey.
local function sameFloor(root: BasePart, floorY: number): boolean
	return math.abs(root.Position.Y - 3 - floorY) < 4
end

local function send(kind: string, id: number?)
	eventRemote:FireAllClients(kind, id)
end

local function setActive(on: boolean)
	if active == on then
		return
	end
	active = on
	activeSince = os.clock()
	anchor:SetAttribute("Active", on)
	anchor:SetAttribute("Hunting", false)
	if not on then
		anchor.Position = Vector3.new(0, -200, 0)
	end
end

function UsherAi.init(all: { [string]: any })
	services = all
	eventRemote = Net.get("UsherEvent")
	for _, point in Layout.USHER_ROUTE do
		table.insert(route, Vector3.new(point.x, point.y, point.z))
	end
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

-- Walks `position` toward `goal` by at most `distance`; returns the new position and whether it
-- arrived.
local function stepToward(position: Vector3, goal: Vector3, distance: number): (Vector3, boolean)
	local offset = goal - position
	local length = offset.Magnitude
	if length <= distance then
		return goal, true
	end
	return position + offset.Unit * distance, false
end

function UsherAi.start()
	local position = route[1]
	local index = 2
	local direction = 1
	local target: Player? = nil
	local lastSeen = 0
	-- Where he walked while chasing, so he can go back to his round the way he came and never
	-- through a wall.
	local trail: { Vector3 } = {}
	local punchAt = 0
	local noticedAt = 0
	while true do
		task.wait(STEP)
		local session = services.Session
		-- A first visit has enough to learn with the Registrar alone; the Usher walks the dark only
		-- for teams who have closed the meeting before.
		local shouldRun = session.flow.phase == "Power" and session.take.number >= 2
		setActive(shouldRun)
		if not active then
			target = nil
			trail = {}
			position = route[1]
			index, direction = 2, 1
			continue
		end
		local now = os.clock()
		local awake = now - activeSince >= START_DELAY
		local chest = position + Vector3.new(0, 4.5, 0)

		-- Who is lit, near and in sight. The nearest one draws him.
		if awake then
			local best, bestDistance = nil, math.huge
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root and player:GetAttribute("OffFrame") ~= true then
					local distance = (root.Position - chest).Magnitude
					local lit = torchOn(player)
					-- Only on his own floor: a light seen down a stairwell is not his to follow.
					local noticed = sameFloor(root, position.Y)
						and (
							distance < TOUCH_RANGE
							or (lit and distance < NOTICE_RANGE and canSee(chest, root.Position))
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
		end

		local hunted = target
		if hunted and (now - lastSeen > GIVE_UP_AFTER or not hunted.Parent) then
			target = nil
			hunted = nil
			anchor:SetAttribute("Hunting", false)
			send("lost")
		end

		if hunted then
			local root = rootOf(hunted)
			if root then
				local goal = Vector3.new(root.Position.X, position.Y, root.Position.Z)
				-- He only closes in while he can see them, and never changes floors: a shelf or a
				-- wall between them stops him dead, which is the one way to break off a chase.
				local sees = canSee(chest, root.Position)
				if sameFloor(root, position.Y) and sees then
					local nextPosition = stepToward(position, goal, HUNT_SPEED * STEP)
					if canStep(position, nextPosition) then
						position = nextPosition
					end
					if (position - trail[#trail]).Magnitude > 1 then
						table.insert(trail, position)
					end
				end
				-- Never through a wall or a shelf: he has to be able to see who he takes.
				local close = (root.Position - (position + Vector3.new(0, 3, 0))).Magnitude
					< CATCH_RANGE
				if close and sees and now - noticedAt >= NOTICE_BEFORE_CATCH then
					send("caught", hunted.UserId)
					services.OffFrame.cut(hunted)
					target = nil
					anchor:SetAttribute("Hunting", false)
				end
			end
		elseif #trail > 0 then
			local arrived
			position, arrived = stepToward(position, trail[#trail], WALK_SPEED * STEP)
			if arrived then
				table.remove(trail)
			end
		else
			local arrived
			position, arrived = stepToward(position, route[index], WALK_SPEED * STEP)
			if arrived then
				if index + direction < 1 or index + direction > #route then
					direction = -direction
				end
				index += direction
			end
		end

		-- The ticket punch, now and then: the sound that says he is somewhere near.
		if now >= punchAt then
			punchAt = now + math.random(40, 75) / 10
			send("punch")
		end
		anchor.Position = position + Vector3.new(0, 0.5, 0)
	end
end

return UsherAi
