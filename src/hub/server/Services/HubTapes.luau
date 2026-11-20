--!strict
-- The tape shelf behind the locker room's television (docs/09_GDD_V2.md §5): every player in this
-- lobby with shift tapes in their Archive, and the tapes themselves, for anyone to watch.
--
-- Each player's saved shift wallet (DataStore Shift_v1, written only by the shift place) is read
-- once on join, without its lock. That one read also gives the depth record the lift signs show.
-- The list sent to a viewer holds only what a tape is (stars, floor, who shot it); the camera
-- path, the heavy part, is sent only for the tape someone presses play on.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)

local HubTapes = {}

local shelves: { [Player]: { Wallet.Tape } } = {}
local dataRemote: RemoteEvent
local limit = RateLimit.new(2, 6)

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
	shelves[player] = data.tapes
	player:SetAttribute("ShiftTapes", #data.tapes)
end

-- Everyone here with tapes, the viewer first, then by name; tapes without their paths.
local function summaries(viewer: Player): { any }
	local owners = {}
	for player, tapes in shelves do
		if player.Parent and #tapes > 0 then
			table.insert(owners, player)
		end
	end
	table.sort(owners, function(a, b)
		if (a == viewer) ~= (b == viewer) then
			return a == viewer
		end
		return a.DisplayName < b.DisplayName
	end)
	local list = {}
	for _, owner in owners do
		local tapes = {}
		for index, tape in shelves[owner] do
			table.insert(tapes, {
				index = index,
				stars = tape.stars,
				depth = tape.depth,
				rarity = tape.rarity,
				by = tape.by,
				at = tape.at,
			})
		end
		table.insert(list, { userId = owner.UserId, name = owner.DisplayName, tapes = tapes })
	end
	return list
end

local function onRequest(player: Player, action: unknown, userId: unknown, index: unknown)
	if not limit:allow(player, os.clock()) then
		return
	end
	if action == "list" then
		dataRemote:FireClient(player, "list", summaries(player))
	elseif action == "get" and typeof(userId) == "number" and typeof(index) == "number" then
		local owner = Players:GetPlayerByUserId(userId)
		local tapes = owner and shelves[owner]
		local tape = tapes and tapes[index]
		if tape then
			dataRemote:FireClient(player, "tape", userId, index, tape)
		end
	end
end

function HubTapes.init()
	dataRemote = Net.get("TapeShelfData")
	Net.get("TapeShelf").OnServerEvent:Connect(onRequest)
end

function HubTapes.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(readRecord, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(readRecord, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		shelves[player] = nil
		limit:forget(player)
	end)
end

return HubTapes
