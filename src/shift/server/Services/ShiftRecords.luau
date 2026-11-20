--!strict
-- After every shift, each player's standing for the lobby's records boards (Core/Records): one
-- score per player in an OrderedDataStore for all time and one in this week's store, each only
-- ever raised. Only a wallet this server really owns is submitted: a player on a fresh, unsaved
-- wallet has no standing to report.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Records = require(ReplicatedStorage.Shared.Core.Records)

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

function ShiftRecords.init(all: { [string]: any })
	services = all
end

return ShiftRecords
