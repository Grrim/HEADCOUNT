--!strict
-- After every shift, each player's standing for the lobby's records board (Core/Records): one
-- score per player in an OrderedDataStore, only ever raised. Only a wallet this server really
-- owns is submitted: a player on a fresh, unsaved wallet has no standing to report.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Records = require(ReplicatedStorage.Shared.Core.Records)

local ShiftRecords = {}

local STORE_NAME = "ShiftRecords_v1"

local services: { [string]: any }
local store: OrderedDataStore? = nil
local storeChecked = false

local function getStore(): OrderedDataStore?
	if storeChecked then
		return store
	end
	storeChecked = true
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[ShiftRecords] no records store: {result}`)
	end
	return store
end

function ShiftRecords.submit(player: Player)
	if not services.ShiftBank.saving(player) then
		return
	end
	local data = services.ShiftBank.data(player)
	local score = Records.score(data.deepest, data.earned)
	if score <= 0 then
		return
	end
	local ordered = getStore()
	if not ordered then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ordered:UpdateAsync(tostring(player.UserId), function(stored)
				return Records.best(stored, score)
			end)
		end)
		if not ok then
			warn(`[ShiftRecords] could not save {player.Name}'s standing: {err}`)
		end
	end)
end

function ShiftRecords.init(all: { [string]: any })
	services = all
end

return ShiftRecords
