--!strict
-- Sends a party to one reserved server, retries failures, and remembers where each player went so
-- a disconnected player can return to the same expedition.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Net = require(ReplicatedStorage.Shared.Net)
local Party = require(ReplicatedStorage.Shared.Core.Party)
local Places = require(ReplicatedStorage.Shared.Config.Places)
local PlayerData = require(ServerScriptService.Common.PlayerData)

local Teleports = {}

local REJOIN_MAP = "ActiveExpedition"
local statusRemote: RemoteEvent
local retries: { [Player]: number } = {}

local function rejoinMap(): MemoryStoreHashMap?
	local ok, map = pcall(function()
		return MemoryStoreService:GetHashMap(REJOIN_MAP)
	end)
	return if ok then map else nil
end

local function remember(player: Player, serverId: string, placeId: number)
	local map = rejoinMap()
	if map then
		local ok, err = pcall(function()
			map:SetAsync(
				tostring(player.UserId),
				{ serverId = serverId, placeId = placeId },
				Config.Party.RejoinTtlSeconds
			)
		end)
		if not ok then
			-- Losing this only loses the "return to expedition" offer, never the teleport.
			warn(`[Teleports] could not store rejoin: {err}`)
		end
	end
end

function Teleports.forget(player: Player)
	local map = rejoinMap()
	if map then
		pcall(function()
			map:RemoveAsync(tostring(player.UserId))
		end)
	end
end

local function membersOf(party: Party.Party): { Player }
	local members = {}
	for _, userId in party.members do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			table.insert(members, member)
		end
	end
	return members
end

-- Returns true once the engine accepted the teleport; false after every attempt failed.
function Teleports.launch(party: Party.Party): boolean
	local members = membersOf(party)
	local placeId = Places.MISSIONS[party.missionId]
	if not placeId or placeId == 0 or RunService:IsStudio() then
		for _, member in members do
			statusRemote:FireClient(member, "error", "err_not_published")
		end
		return false
	end
	for _, member in members do
		statusRemote:FireClient(member, "teleporting")
	end
	PlayerData.saveAll(8)

	local serverId = HttpService:GenerateGUID(false)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = serverId
	options:SetTeleportData({
		v = 1,
		mission = party.missionId,
		seed = Random.new():NextInteger(1, 2 ^ 30),
	})
	for _, member in members do
		task.spawn(remember, member, serverId, placeId)
	end
	for attempt = 1, Config.Party.TeleportRetries do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, members, options)
		end)
		if ok then
			return true
		end
		warn(`[Teleports] attempt {attempt} failed: {err}`)
		task.wait(3 ^ (attempt - 1))
	end
	for _, member in members do
		statusRemote:FireClient(member, "error", "err_teleport_failed")
		task.spawn(Teleports.forget, member)
	end
	return false
end

function Teleports.rejoin(player: Player)
	local map = rejoinMap()
	if not map then
		return
	end
	local ok, entry = pcall(function()
		return map:GetAsync(tostring(player.UserId))
	end)
	if not ok or typeof(entry) ~= "table" then
		return
	end
	statusRemote:FireClient(player, "teleporting")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = entry.serverId
	-- Lets the mission tell a returning player from a fresh party. If the old server already shut
	-- down, the same id opens an empty one, and the mission sends the player straight back.
	options:SetTeleportData({ v = 1, rejoin = true })
	local sent, err = pcall(function()
		TeleportService:TeleportAsync(entry.placeId, { player }, options)
	end)
	if not sent then
		warn(`[Teleports] rejoin failed: {err}`)
		statusRemote:FireClient(player, "error", "err_teleport_failed")
	end
end

local function offerRejoin(player: Player)
	local map = rejoinMap()
	if not map or RunService:IsStudio() then
		return
	end
	local ok, entry = pcall(function()
		return map:GetAsync(tostring(player.UserId))
	end)
	if ok and typeof(entry) == "table" then
		statusRemote:FireClient(player, "rejoinOffer")
	end
end

function Teleports.init()
	statusRemote = Net.get("TeleportStatus")
end

function Teleports.start()
	-- The engine hands back options that reach the same destination, which keeps a party together.
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		local count = (retries[player] or 0) + 1
		retries[player] = count
		warn(`[Teleports] init failed for {player.Name} ({result}): {message}`)
		if count > Config.Party.TeleportRetries then
			retries[player] = nil
			statusRemote:FireClient(player, "error", "err_teleport_failed")
			return
		end
		task.wait(3 ^ (count - 1))
		pcall(function()
			TeleportService:TeleportAsync(placeId, { player }, options)
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(offerRejoin, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(offerRejoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		retries[player] = nil
	end)
end

return Teleports
