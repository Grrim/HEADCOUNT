--!strict
-- Daily tasks on a shift (Core/Quests): the other services report what a player did, this counts it
-- in their wallet, pays a task the moment it is done and says so, and keeps the player's own view
-- of today's tasks (the Quests attribute, as JSON) up to date for the HUD.
--
-- It also keeps the attendance card (Core/Attendance): a player's day is stamped when their saved
-- wallet loads on a shift, and again at a shift's end for anyone who played on past midnight.
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
			services.ShiftPass.xp(player, services.ShiftPass.XP.task[quest.tier] or 0)
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

-- Stamps today on the player's attendance card (once a day) and says what it paid.
function ShiftQuests.attend(player: Player)
	local bank = services.ShiftBank
	if not player.Parent or not bank.loaded(player) then
		return
	end
	local stamp, square = Wallet.attend(bank.data(player), Quests.day(os.time()))
	if not stamp then
		return
	end
	bank.changed(player)
	local line = `Attendance, day {square} of 7: +{stamp.frames} frames.`
	if stamp.frame then
		line ..= ` The card is full: the "Punch Card" viewfinder is yours.`
	end
	-- A player who has just joined may not be listening yet.
	task.delay(4, function()
		if player.Parent then
			services.ShiftSession.tell(player, line)
		end
	end)
end

function ShiftQuests.init(all: { [string]: any })
	services = all
	services.ShiftBank.onLoaded(publish)
	services.ShiftBank.onLoaded(ShiftQuests.attend)
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
