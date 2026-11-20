--!strict
-- After every shift, each player's standing for the lobby's records boards (Core/Records): one
-- score per player in an OrderedDataStore for all time and one in this week's store, each only
-- ever raised. Only a wallet this server really owns is submitted: a player on a fresh, unsaved
-- wallet has no standing to report.
--
-- It also pays for places on finished weeks (Core/Records.reward). No server is sure to be up at
-- midnight on Monday, so a player collects when their saved wallet next loads on a shift: every
-- finished week not yet settled (the last few at most) is read once, and settled once.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Records = require(ReplicatedStorage.Shared.Core.Records)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)

local ShiftRecords = {}

local services: { [string]: any }

local function raise(storeName: string, player: Player, score: number)
	if score <= 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			DataStoreService:GetOrderedDataStore(storeName)
				:UpdateAsync(tostring(player.UserId), function(stored)
					return Records.best(stored, score)
				end)
		end)
		if not ok then
			warn(`[ShiftRecords] could not save {player.Name}'s standing in {storeName}: {err}`)
		end
	end)
end

function ShiftRecords.submit(player: Player)
	if not services.ShiftBank.saving(player) then
		return
	end
	local data = services.ShiftBank.data(player)
	raise(Records.STORE, player, Records.score(data.deepest, data.earned))
	local week = Records.week(os.time())
	if data.week == week then
		raise(Records.weeklyStore(week), player, Records.score(data.weekDeepest, data.weekEarned))
	end
end

-- This player's place on a finished week's board, or nil when off it. Errors propagate, so an
-- unreadable week stays unsettled and is tried again next time.
local function placeIn(week: number, userId: number): number?
	local entries = DataStoreService:GetOrderedDataStore(Records.weeklyStore(week))
		:GetSortedAsync(false, #Records.PAY)
		:GetCurrentPage()
	for index, entry in entries do
		if tonumber(entry.key) == userId then
			return index
		end
	end
	return nil
end

local function claim(player: Player)
	local bank = services.ShiftBank
	if not bank.saving(player) then
		return
	end
	local data = bank.data(player)
	local lines = {}
	for _, week in Wallet.weeksToClaim(data, Records.week(os.time())) do
		local ok, place = pcall(placeIn, week, player.UserId)
		if not ok then
			warn(`[ShiftRecords] could not read week {week} for {player.Name}: {place}`)
			break
		end
		if not player.Parent or bank.data(player) ~= data then
			return
		end
		local paid = Wallet.claimWeek(
			data,
			week,
			if place then Records.reward(place) else 0,
			if place then Records.honour(place) else nil
		)
		if place and paid > 0 then
			table.insert(lines, `#{place} on the weekly board: +{paid} frames.`)
		end
	end
	bank.changed(player)
	if #lines > 0 then
		-- A player who just joined may not be listening yet; the frames are theirs either way.
		task.delay(6, function()
			if player.Parent then
				services.ShiftSession.tell(
					player,
					`The Bureau commends you. {table.concat(lines, " ")}`
				)
			end
		end)
	end
end

function ShiftRecords.init(all: { [string]: any })
	services = all
	services.ShiftBank.onLoaded(function(player)
		task.spawn(claim, player)
	end)
end

return ShiftRecords
