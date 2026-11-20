--!strict
-- Daily tasks on a shift (Core/Quests): the other services report what a player did, this counts it
-- in their wallet, pays a task the moment it is done and says so, and keeps the player's own view
-- of today's tasks (the Quests attribute, as JSON) up to date for the HUD.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage.Shared.Core.Quests)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)

local ShiftQuests = {}

local services: { [string]: any }

local function publish(player: Player)
	if not player.Parent then
		return
	end
	local data = services.ShiftBank.data(player)
	local view = Quests.view(data.quests, Quests.day(os.time()))
	player:SetAttribute("Quests", HttpService:JSONEncode(view))
end

-- Something counted towards today's tasks happened (`amount` defaults to 1).
function ShiftQuests.event(player: Player, event: string, amount: number?)
	if not player.Parent then
		return
	end
	local bank = services.ShiftBank
	local finished = Wallet.questEvent(bank.data(player), os.time(), event, amount or 1)
	if #finished > 0 then
		bank.changed(player)
		for _, quest in finished do
			services.ShiftSession.tell(
				player,
				`Daily task done: {quest.text}. +{quest.reward} frames.`
			)
		end
	else
		-- Progress alone waits for the next regular save.
		bank.touch(player)
	end
	publish(player)
end

function ShiftQuests.init(all: { [string]: any })
	services = all
	services.ShiftBank.onLoaded(publish)
end

function ShiftQuests.start()
	Players.PlayerAdded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	-- A new day brings new tasks even to a player who stays on through midnight.
	while true do
		task.wait(Quests.secondsLeft(os.time()) + 2)
		for _, player in Players:GetPlayers() do
			publish(player)
		end
	end
end

return ShiftQuests
