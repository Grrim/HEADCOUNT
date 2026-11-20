--!strict
-- Leaving the shift for the lobby (docs/09_GDD_V2.md §11.3): the wallet is saved and its lock
-- given back first, then the teleport, so the lobby and the next shift never race on the record.
-- A teleport that fails for good takes the lock back and the player carries on here.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Places = require(ReplicatedStorage.Shared.Config.Places)

local ShiftTravel = {}

local services: { [string]: any }
local leaving: { [Player]: boolean } = {}
local failures: { [Player]: number } = {}

-- The lobby offers to send a disconnected player back to their shift. Leaving on purpose is
-- not a disconnect, so the offer goes.
local function forgetRejoin(player: Player)
	pcall(function()
		MemoryStoreService:GetHashMap("ActiveExpedition"):RemoveAsync(tostring(player.UserId))
	end)
end

function ShiftTravel.isLeaving(player: Player): boolean
	return leaving[player] == true
end

local function stay(player: Player, line: string)
	leaving[player] = nil
	failures[player] = nil
	services.ShiftBank.resume(player)
	services.ShiftSession.tell(player, line)
end

function ShiftTravel.toLobby(player: Player)
	if leaving[player] then
		return
	end
	if Places.HUB == 0 or RunService:IsStudio() then
		services.ShiftSession.tell(
			player,
			"The way back to the lobby works only in the published game."
		)
		return
	end
	leaving[player] = true
	services.ShiftSession.tell(player, "Saving, then back to the lobby...")
	-- Never leave with the wallet unsaved: the lock would hold the next server back for minutes.
	if not services.ShiftBank.release(player) then
		task.wait(2)
		if not services.ShiftBank.release(player) then
			leaving[player] = nil
			services.ShiftSession.tell(
				player,
				"Couldn't save your frames. Staying here; try again."
			)
			return
		end
	end
	forgetRejoin(player)
	for attempt = 1, Config.Party.TeleportRetries do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(Places.HUB, { player })
		end)
		if ok then
			-- Accepted, but if they are somehow still here later, give them their wallet back.
			task.delay(25, function()
				if player.Parent and leaving[player] then
					stay(player, "Couldn't reach the lobby. Try again in a moment.")
				end
			end)
			return
		end
		warn(`[ShiftTravel] teleport to the lobby failed ({attempt}): {err}`)
		task.wait(3 ^ (attempt - 1))
	end
	stay(player, "Couldn't reach the lobby. Try again in a moment.")
end

function ShiftTravel.init(all: { [string]: any })
	services = all
end

function ShiftTravel.start()
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		if not leaving[player] then
			return
		end
		local count = (failures[player] or 0) + 1
		failures[player] = count
		warn(`[ShiftTravel] init failed for {player.Name} ({result}): {message}`)
		if count > Config.Party.TeleportRetries then
			stay(player, "Couldn't reach the lobby. Try again in a moment.")
			return
		end
		task.wait(3 ^ (count - 1))
		pcall(function()
			TeleportService:TeleportAsync(placeId, { player }, options)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		leaving[player] = nil
		failures[player] = nil
	end)
end

return ShiftTravel
