--!strict
-- The Bureau's two lifts down to the shift (docs/09_GDD_V2.md §3, §7), behind the hall's east wall.
--
--   SOLO   step in, press the button, and you go down alone.
--   CREW   whoever stands in the cabin is aboard (Core/Crew). It leaves 30 s after the first one
--          stepped in, at once when four are aboard, or when someone aboard presses the button.
--
-- Both send their riders through Teleports.launch, the same reserved-server teleport the terminal
-- uses, so a crew lands on one shift server together. Anyone already in a terminal party is left
-- out: they are going somewhere with their party.
--
-- This also reads each player's shift record (DataStore Shift_v1, written only by the shift
-- place) once, without its lock, to show the depth record over the lifts.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Crew = require(ReplicatedStorage.Shared.Core.Crew)
local Net = require(ReplicatedStorage.Shared.Net)
local Party = require(ReplicatedStorage.Shared.Core.Party)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)

local HubLifts = {}

local CREW_WAIT = Config.Party.CrewLiftSeconds
local SHIFT = "SHIFT"

local services: { [string]: any }
local statusRemote: RemoteEvent
local crew = Crew.new(Party.MAX_MEMBERS, CREW_WAIT)
local limit = RateLimit.new(1, 2)
-- Riders whose teleport is under way: nothing sends them again until it is over.
local launching: { [number]: boolean } = {}
-- Riders whose trip failed: they do not board again until they step out of the cabin, so a failed
-- teleport is not retried every few seconds.
local refused: { [number]: boolean } = {}
-- Party members told once, while they stand in the crew cabin, why it will not take them.
local told: { [number]: boolean } = {}

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

local function send(members: { number })
	for _, id in members do
		launching[id] = true
	end
	task.spawn(function()
		local ok = services.Teleports.launch(partyOf(members))
		if not ok then
			task.wait(3)
			for _, id in members do
				launching[id] = nil
				refused[id] = true
			end
		end
	end)
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
	if limit:allow(player, os.clock()) then
		Crew.go(crew, player.UserId)
	end
end

-- The depth record and frames from the shift place, read once, for the signs.
local function readRecord(player: Player)
	local ok, raw = pcall(function()
		return DataStoreService:GetDataStore("Shift_v1"):GetAsync(`u_{player.UserId}`)
	end)
	if not ok or not player.Parent then
		return
	end
	local data = Wallet.migrate(raw).data
	player:SetAttribute("ShiftDeepest", data.deepest)
	player:SetAttribute("ShiftFrames", data.frames)
end

function HubLifts.init(all: { [string]: any })
	services = all
	statusRemote = Net.get("TeleportStatus")
end

function HubLifts.start()
	local world = services.HubWorld
	world.prompts.SoloLift.Triggered:Connect(onSolo)
	world.prompts.CrewLift.Triggered:Connect(onGoNow)
	local map = Workspace:WaitForChild("Map")
	local crewSign = map:WaitForChild("CrewLiftSign") :: BasePart

	Players.PlayerAdded:Connect(function(player)
		task.spawn(readRecord, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(readRecord, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		launching[player.UserId] = nil
		refused[player.UserId] = nil
		told[player.UserId] = nil
		limit:forget(player)
	end)

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
		if Crew.due(crew, now) then
			send(Crew.take(crew))
		end
		-- Every client writes the sign in its own language from these.
		crewSign:SetAttribute("Aboard", #crew.members)
		local left = Crew.secondsLeft(crew, now)
		crewSign:SetAttribute("LeavesIn", if left then math.ceil(left) else -1)
	end
end

return HubLifts
