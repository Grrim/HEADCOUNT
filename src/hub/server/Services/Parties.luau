--!strict
-- Expedition parties on this hub server: every request validated, the state pushed to everyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Net = require(ReplicatedStorage.Shared.Net)
local Party = require(ReplicatedStorage.Shared.Core.Party)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService.Common.PlayerData)

local Parties = {}

local registry = Party.newRegistry()
local limit = RateLimit.new(Config.Rates.Party[1], Config.Rates.Party[2])
local stateRemote: RemoteEvent
local statusRemote: RemoteEvent
local services: { [string]: any }
local countdownRuns: { [Party.Party]: number } = setmetatable({}, { __mode = "k" }) :: any

local function missionById(id: string): any
	for _, mission in Missions do
		if mission.id == id then
			return mission
		end
	end
	return nil
end

local function snapshot(): { any }
	local list = {}
	for _, party in registry.parties do
		local members = {}
		for _, userId in party.members do
			local player = Players:GetPlayerByUserId(userId)
			table.insert(members, {
				userId = userId,
				name = if player then player.DisplayName else "?",
				ready = party.ready[userId] == true,
				leader = party.leader == userId,
			})
		end
		table.insert(list, {
			id = party.id,
			missionId = party.missionId,
			starting = party.starting,
			members = members,
		})
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

function Parties.broadcast()
	stateRemote:FireAllClients(snapshot())
end

local function fail(player: Player, reason: string?)
	statusRemote:FireClient(player, "error", `err_{reason or "bad_target"}`)
end

-- Countdown, then launch. Anything that clears `starting` (leave, unready, abort) cancels it.
local function runCountdown(party: Party.Party)
	-- A quick abort and restart must not leave two countdowns racing to launch the same party.
	local run = (countdownRuns[party] or 0) + 1
	countdownRuns[party] = run
	party.starting = true
	Parties.broadcast()
	for remaining = Config.Party.CountdownSeconds, 1, -1 do
		for _, userId in party.members do
			local member = Players:GetPlayerByUserId(userId)
			if member then
				statusRemote:FireClient(member, "countdown", remaining)
			end
		end
		task.wait(1)
		if countdownRuns[party] ~= run then
			return
		end
		if not party.starting or registry.parties[party.id] ~= party then
			for _, userId in party.members do
				local member = Players:GetPlayerByUserId(userId)
				if member then
					statusRemote:FireClient(member, "aborted")
				end
			end
			Parties.broadcast()
			return
		end
	end
	local ok = services.Teleports.launch(party)
	if not ok then
		party.starting = false
		Parties.broadcast()
	end
end

local ACTIONS: { [string]: (Player, any) -> () } = {
	create = function(player, missionId)
		if typeof(missionId) ~= "string" then
			return
		end
		local mission = missionById(missionId)
		local data = PlayerData.get(player)
		if not mission or not mission.available or not (data and data.missions[missionId]) then
			fail(player, "mission_locked")
			return
		end
		local _, reason = Party.create(registry, player.UserId, missionId)
		if reason then
			fail(player, reason)
		end
	end,
	join = function(player, partyId)
		if typeof(partyId) ~= "number" then
			return
		end
		local ok, reason = Party.join(registry, player.UserId, partyId)
		if not ok then
			fail(player, reason)
		end
	end,
	leave = function(player)
		Party.leave(registry, player.UserId)
	end,
	ready = function(player, value)
		if typeof(value) == "boolean" then
			Party.setReady(registry, player.UserId, value)
		end
	end,
	kick = function(player, targetId)
		if typeof(targetId) ~= "number" then
			return
		end
		local ok, reason = Party.kick(registry, player.UserId, targetId)
		if not ok then
			fail(player, reason)
		end
	end,
	abort = function(player)
		local party = Party.of(registry, player.UserId)
		if party then
			party.starting = false
		end
	end,
	start = function(player)
		local ok, reason = Party.canStart(registry, player.UserId)
		if not ok then
			fail(player, reason)
			return
		end
		task.spawn(runCountdown, Party.of(registry, player.UserId) :: Party.Party)
	end,
	-- Coming back to an expedition still running after a disconnect.
	rejoinYes = function(player)
		services.Teleports.rejoin(player)
	end,
	rejoinNo = function(player)
		services.Teleports.forget(player)
	end,
}

function Parties.init(all: { [string]: any })
	services = all
	stateRemote = Net.get("PartyState")
	statusRemote = Net.get("TeleportStatus")
end

function Parties.start()
	Net.get("PartyAction").OnServerEvent
		:Connect(function(player: Player, action: unknown, arg: unknown)
			if typeof(action) ~= "string" or not limit:allow(player, os.clock()) then
				return
			end
			local handler = ACTIONS[action]
			if handler then
				handler(player, arg)
				Parties.broadcast()
			end
		end)
	Players.PlayerAdded:Connect(function(player)
		stateRemote:FireClient(player, snapshot())
	end)
	Players.PlayerRemoving:Connect(function(player)
		Party.leave(registry, player.UserId)
		limit:forget(player)
		Parties.broadcast()
	end)
end

return Parties
