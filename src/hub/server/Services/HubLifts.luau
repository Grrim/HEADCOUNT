--!strict
-- The Bureau's two lifts down to the shift (docs/09_GDD_V2.md §3, §7), behind the hall's east wall.
--
--   SOLO   step in, press the button, and you go down alone.
--   CREW   whoever stands in the cabin is aboard. One crew lift is shared by every lobby server
--          (Core/CrewLink, kept in MemoryStore): riders here hold seats on a ticket that riders in
--          other lobbies hold seats on too. It leaves 30 s after it opened, at once when four are
--          aboard, or when someone aboard presses the button in any lobby; then every lobby sends
--          its riders to the ticket's reserved server, and they meet there.
--
-- Holding a ticket, a lobby leaves on the last departure time it knows even if MemoryStore stops
-- answering, so one failed request never splits a crew. Without a ticket and after a few failed
-- requests in a row, the crew lift works as it did alone (Core/Crew, this cabin's riders only)
-- until the cabin empties and it tries the shared lift again. Studio always works alone.
--
-- Both lifts send their riders through Teleports.launch, the same reserved-server teleport the
-- terminal uses. Anyone already in a terminal party is left out: they go with their party.
--
-- The depth record on the solo lift's sign comes from HubTapes, which reads each player's shift
-- record once.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Crew = require(ReplicatedStorage.Shared.Core.Crew)
local CrewLink = require(ReplicatedStorage.Shared.Core.CrewLink)
local Net = require(ReplicatedStorage.Shared.Net)
local Party = require(ReplicatedStorage.Shared.Core.Party)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local HubLifts = {}

local CREW_WAIT = Config.Party.CrewLiftSeconds
local CAPACITY = Party.MAX_MEMBERS
local SHIFT = "SHIFT"
-- v2: tickets carry `closed`; servers on the first version would strip it.
local MAP_NAME = "CrewLifts_v2"
-- A shared lift leaving sooner than this is not offered to a newly filled cabin.
local JOIN_MARGIN = 5
-- Longest a ticket may need to stay in the store after any write.
local TICKET_TTL = CREW_WAIT + CrewLink.LINGER
-- Failed requests in a row, with no ticket held, before this lobby goes alone.
local FAILURES_BEFORE_ALONE = 3
-- How often a lobby alone on its own ticket looks for an older one to merge into.
local MERGE_EVERY = 3
-- Studio is no place to hold seats that live servers would count.
local SHARED = not RunService:IsStudio()
-- This lobby's name on a ticket. Studio has no JobId.
local LOBBY = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local services: { [string]: any }
local statusRemote: RemoteEvent
local crew = Crew.new(CAPACITY, CREW_WAIT)
local limit = RateLimit.new(1, 2)
-- Riders whose teleport is under way: nothing sends them again until it is over.
local launching: { [number]: boolean } = {}
-- Riders whose trip failed: they do not board again until they step out of the cabin, so a failed
-- teleport is not retried every few seconds.
local refused: { [number]: boolean } = {}
-- Party members told once, while they stand in the crew cabin, why it will not take them.
local told: { [number]: boolean } = {}

-- This lobby's place on the shared lift: the ticket's key, its last known state, the seats held
-- here, and a "Leave now" waiting for the next write.
type Link = {
	key: string?,
	ticket: CrewLink.Ticket?,
	granted: number,
	alone: boolean,
	failures: number,
	goPending: boolean,
	mergedAt: number,
}
local link: Link = {
	key = nil,
	ticket = nil,
	granted = 0,
	alone = not SHARED,
	failures = 0,
	goPending = false,
	mergedAt = 0,
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function inside(box: any, position: Vector3): boolean
	return position.X >= box.minX
		and position.X <= box.maxX
		and position.Z >= box.minZ
		and position.Z <= box.maxZ
		and position.Y < 12
end

-- A party the teleport understands: everyone ready, already starting.
local function partyOf(members: { number }): Party.Party
	local ready = {}
	for _, id in members do
		ready[id] = true
	end
	return {
		id = 0,
		missionId = SHIFT,
		leader = members[1],
		members = members,
		ready = ready,
		starting = true,
	}
end

local function send(members: { number }, serverId: string?, crewSize: number?)
	for _, id in members do
		launching[id] = true
	end
	task.spawn(function()
		local ok = services.Teleports.launch(partyOf(members), serverId, crewSize)
		if not ok then
			task.wait(3)
			for _, id in members do
				launching[id] = nil
				refused[id] = true
			end
		end
	end)
end

local function forgetLink()
	link.key = nil
	link.ticket = nil
	link.granted = 0
end

local function sortedMap(): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(MAP_NAME)
end

-- One UpdateAsync on a ticket. `change` edits it and says whether to write; it may run more than
-- once, so it must set everything it reports from scratch. The ticket as it stands afterwards
-- comes back, or nil when it is gone.
local function update(
	map: MemoryStoreSortedMap,
	key: string,
	change: (CrewLink.Ticket) -> boolean
): CrewLink.Ticket?
	local result: CrewLink.Ticket? = nil
	map:UpdateAsync(key, function(raw)
		local ticket = CrewLink.read(raw)
		result = ticket
		if not ticket or not change(ticket) then
			return nil
		end
		return ticket
	end, TICKET_TTL)
	return result
end

-- Tickets opened recently enough to take riders, oldest first, optionally only those older than
-- `below`. Bounds are tables on current engines and plain keys on older ones.
local function recentTickets(map: MemoryStoreSortedMap, now: number, below: string?): { any }
	local lower = CrewLink.freshAfter(now, CREW_WAIT, JOIN_MARGIN)
	local ok, items = pcall(function()
		return map:GetRangeAsync(
			Enum.SortDirection.Ascending,
			20,
			{ key = lower },
			if below then { key = below } else nil
		)
	end)
	if ok then
		return items
	end
	return (map :: any):GetRangeAsync(Enum.SortDirection.Ascending, 20, lower, below)
end

-- Takes seats on the oldest open ticket with room (older than `below`, if given). Returns its key,
-- the ticket and the seats granted, or nil.
local function joinOpen(
	map: MemoryStoreSortedMap,
	now: number,
	wanted: number,
	below: string?
): (string?, CrewLink.Ticket?, number)
	for _, item in recentTickets(map, now, below) do
		local listed = CrewLink.read(item.value)
		if
			item.key ~= link.key
			and listed
			and CrewLink.joinable(listed, now, CAPACITY, JOIN_MARGIN)
		then
			local granted = 0
			local ticket = update(map, item.key, function(stored)
				granted = 0
				if not CrewLink.joinable(stored, now, CAPACITY, JOIN_MARGIN) then
					return false
				end
				granted = CrewLink.setSeats(stored, LOBBY, wanted, now, CAPACITY)
				return granted > 0
			end)
			if ticket and granted > 0 and ticket.seats[LOBBY] == granted then
				return item.key, ticket, granted
			end
		end
	end
	return nil, nil, 0
end

-- Holds as many seats as this cabin has riders: on the ticket already joined, else on the
-- oldest open one with room, else on a new one.
local function holdSeats(map: MemoryStoreSortedMap, wanted: number)
	local now = os.time()
	local held = link.ticket
	-- Riders boarding a cabin that had emptied: only stay on its ticket if it would still be
	-- offered to them.
	if held and link.granted == 0 and wanted > 0 then
		if not CrewLink.joinable(held, now, CAPACITY, JOIN_MARGIN) then
			forgetLink()
		end
	end
	local key = link.key
	if key then
		local granted = 0
		local pending = link.goPending
		local ticket = update(map, key, function(stored)
			granted = stored.seats[LOBBY] or 0
			if stored.closed then
				return false
			end
			if now >= stored.departAt or pending then
				-- The first lobby to see the time run out (or to press GO) closes it for all.
				CrewLink.close(stored, now)
				return true
			end
			granted = CrewLink.setSeats(stored, LOBBY, wanted, now, CAPACITY)
			return true
		end)
		if not ticket then
			forgetLink()
			return
		end
		link.ticket = ticket
		link.granted = granted
		if pending then
			link.goPending = false
		end
		-- Alone on a ticket opened at the same moment as another lobby's: move to the older one.
		if
			wanted > 0
			and not ticket.closed
			and CrewLink.alone(ticket, LOBBY)
			and os.clock() - link.mergedAt >= MERGE_EVERY
		then
			link.mergedAt = os.clock()
			local otherKey, other, otherGranted = joinOpen(map, now, wanted, key)
			if otherKey and other then
				pcall(update, map, key, function(stored)
					CrewLink.setSeats(stored, LOBBY, 0, now, CAPACITY)
					return true
				end)
				link.key, link.ticket, link.granted = otherKey, other, otherGranted
			end
		end
		return
	end
	if wanted == 0 then
		return
	end
	local joinedKey, joined, joinedGranted = joinOpen(map, now, wanted, nil)
	if joinedKey and joined then
		link.key, link.ticket, link.granted = joinedKey, joined, joinedGranted
		return
	end
	local ticket, granted =
		CrewLink.open(HttpService:GenerateGUID(false), LOBBY, wanted, now, CREW_WAIT, CAPACITY)
	map:SetAsync(CrewLink.key(ticket), ticket, CrewLink.ttl(ticket, now))
	link.key, link.ticket, link.granted = CrewLink.key(ticket), ticket, granted
end

-- The first riders in the cabin, as many as hold seats.
local function seated(): { number }
	local riders = {}
	for index = 1, math.min(link.granted, #crew.members) do
		table.insert(riders, crew.members[index])
	end
	return riders
end

local function onSolo(player: Player)
	if not limit:allow(player, os.clock()) or launching[player.UserId] then
		return
	end
	local root = rootOf(player)
	if not root or not inside(services.HubWorld.soloCabin, root.Position) then
		return
	end
	if services.Parties.inParty(player) then
		statusRemote:FireClient(player, "error", "err_in_party")
		return
	end
	send({ player.UserId })
end

local function onGoNow(player: Player)
	if not limit:allow(player, os.clock()) then
		return
	end
	if link.alone then
		Crew.go(crew, player.UserId)
	elseif table.find(crew.members, player.UserId) then
		-- Written with the next update, also when the ticket is still being joined or opened.
		link.goPending = true
	end
end

-- Once a second: keep this cabin's seats on the shared lift right, and when it leaves, send the
-- riders who hold them.
local function linkLoop()
	while true do
		task.wait(1)
		if not SHARED then
			continue
		end
		if #crew.members == 0 and not link.key then
			-- An empty cabin is the moment to try the shared lift again.
			link.alone = false
			link.failures = 0
			link.goPending = false
			crew.now = false
		end
		if link.alone then
			continue
		end
		local ok, err = pcall(holdSeats, sortedMap(), #crew.members)
		if ok then
			link.failures = 0
		else
			link.failures += 1
			warn(`[HubLifts] shared crew lift request failed ({link.failures}): {err}`)
			if link.failures >= FAILURES_BEFORE_ALONE and not link.key then
				warn("[HubLifts] shared crew lift unavailable; this lobby's crew lift goes alone")
				link.alone = true
			end
		end
		-- Leaves on the last departure it knows, even when this second's request failed.
		local ticket = link.ticket
		if ticket and link.key and CrewLink.due(ticket, os.time()) then
			local riders = seated()
			if #riders > 0 then
				send(riders, ticket.id, CrewLink.total(ticket))
			end
			forgetLink()
		end
	end
end

function HubLifts.init(all: { [string]: any })
	services = all
	statusRemote = Net.get("TeleportStatus")
	-- A teleport that was accepted and then failed for good: let the rider try again.
	services.Teleports.onGaveUp(function(player: Player)
		launching[player.UserId] = nil
		refused[player.UserId] = true
	end)
	-- A lobby shutting down gives its seats back, so other lobbies' crews do not wait for riders
	-- who will never come.
	game:BindToClose(function()
		local key = link.key
		if not key or not SHARED then
			return
		end
		pcall(update, sortedMap(), key, function(stored)
			CrewLink.setSeats(stored, LOBBY, 0, os.time(), CAPACITY)
			return not stored.closed
		end)
	end)
end

function HubLifts.start()
	local world = services.HubWorld
	world.prompts.SoloLift.Triggered:Connect(onSolo)
	world.prompts.CrewLift.Triggered:Connect(onGoNow)
	local map = Workspace:WaitForChild("Map")
	local crewSign = map:WaitForChild("CrewLiftSign") :: BasePart

	Players.PlayerRemoving:Connect(function(player)
		launching[player.UserId] = nil
		refused[player.UserId] = nil
		told[player.UserId] = nil
		limit:forget(player)
	end)
	task.spawn(linkLoop)

	while true do
		task.wait(0.25)
		local now = os.clock()
		local aboard = {}
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			local id = player.UserId
			local here = root ~= nil and inside(world.crewCabin, root.Position)
			if not here then
				refused[id] = nil
				told[id] = nil
			elseif services.Parties.inParty(player) then
				if not told[id] then
					told[id] = true
					statusRemote:FireClient(player, "error", "err_in_party")
				end
			elseif not launching[id] and not refused[id] then
				table.insert(aboard, id)
			end
		end
		Crew.sync(crew, aboard, now)
		if link.alone and Crew.due(crew, now) then
			send(Crew.take(crew))
		end
		-- Every client writes the sign in its own language from these: on the shared lift, the
		-- whole crew across lobbies and the shared departure.
		local ticket = link.ticket
		if ticket and not link.alone then
			crewSign:SetAttribute("Aboard", CrewLink.total(ticket))
			crewSign:SetAttribute("LeavesIn", CrewLink.secondsLeft(ticket, os.time()))
		else
			crewSign:SetAttribute("Aboard", #crew.members)
			local left = Crew.secondsLeft(crew, now)
			crewSign:SetAttribute("LeavesIn", if left then math.ceil(left) else -1)
		end
	end
end

return HubLifts
