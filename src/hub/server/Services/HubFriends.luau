--!strict
-- The friends board: you and your friends who have come back up from the shift, ranked like the
-- all-time board, with this week's floor beside it (Core/Records.friendsBoard). Every player sees
-- their own list on the same board, so the rows are sent to each client and drawn there (Lifts).
--
-- Looking up every friend's score one by one would spend the DataStore budget fast, so instead
-- this reads the top of the all-time and weekly lists a few pages deep every few minutes, once for
-- the whole server, and matches each player's friends against it. A friend below that depth is
-- not listed; for a young game that is nobody.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Records = require(ReplicatedStorage.Shared.Core.Records)

local HubFriends = {}

local SCAN_EVERY = 300
local PAGE_SIZE = 100
local PAGES = 5
local MAX_FRIENDS = 200
local WIDTH = 44

local remote: RemoteEvent
local scores: { all: { [number]: number }, week: { [number]: number } } = { all = {}, week = {} }
local scanned = false
local offline = false
local friends: { [Player]: { [number]: string } } = {}

-- The top of one ordered list, a few pages deep, as UserId -> score. Nil when it can't be read.
local function scan(storeName: string): { [number]: number }?
	local result: { [number]: number } = {}
	local ok, err = pcall(function()
		local pages = DataStoreService:GetOrderedDataStore(storeName)
			:GetSortedAsync(false, PAGE_SIZE)
		for page = 1, PAGES do
			for _, entry in pages:GetCurrentPage() do
				local id = tonumber(entry.key)
				if id and typeof(entry.value) == "number" then
					result[id] = entry.value
				end
			end
			if pages.IsFinished or page == PAGES then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn(`[HubFriends] could not read {storeName}: {err}`)
		return nil
	end
	return result
end

-- This player and their friends, by UserId, with the names to show.
local function loadFriends(player: Player)
	local names: { [number]: string } = { [player.UserId] = player.DisplayName }
	local ok, err = pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		local count = 0
		while true do
			for _, item in pages:GetCurrentPage() do
				if typeof(item.Id) == "number" then
					names[item.Id] = if typeof(item.DisplayName) == "string"
						then item.DisplayName
						else tostring(item.Username)
					count += 1
				end
			end
			if pages.IsFinished or count >= MAX_FRIENDS then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn(`[HubFriends] could not read {player.Name}'s friends: {err}`)
	end
	if player.Parent then
		friends[player] = names
	end
end

local function push(player: Player)
	local names = friends[player]
	if not names then
		return
	end
	local state = if offline then "offline" elseif not scanned then "loading" else "ok"
	local rows = {}
	if scanned then
		for _, row in Records.friendsBoard(scores.all, scores.week, names) do
			table.insert(rows, { id = row.id, text = Records.friendLine(row, WIDTH) })
		end
		if #rows == 0 then
			state = "empty"
		end
	end
	remote:FireClient(player, { state = state, rows = rows })
end

function HubFriends.init()
	remote = Net.get("FriendsBoard")
end

function HubFriends.start()
	local function onJoin(player: Player)
		task.spawn(function()
			loadFriends(player)
			push(player)
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		friends[player] = nil
	end)
	while true do
		local all = scan(Records.STORE)
		local week = scan(Records.weeklyStore(Records.week(os.time())))
		if all and week then
			scores = { all = all, week = week }
			scanned = true
			offline = false
		elseif not scanned then
			offline = true
		end
		for _, player in Players:GetPlayers() do
			push(player)
		end
		task.wait(SCAN_EVERY)
	end
end

return HubFriends
