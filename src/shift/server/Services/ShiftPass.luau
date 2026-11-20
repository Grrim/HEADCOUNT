--!strict
-- The Biuro Pass on a shift (Core/Pass, Config/Pass): experience from footage brought back, quotas
-- met and daily tasks; every tier reached pays its free reward, and its premium one for a player
-- who owns the season's Game Pass (checked on join and after a purchase in game, and paying the
-- tiers reached before buying). What a player wears from it, a viewfinder frame and a title, is
-- set here too, and shown to them (FrameId) and to the team (Title).
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pass = require(ReplicatedStorage.Shared.Core.Pass)
local PassConfig = require(ReplicatedStorage.Shared.Config.Pass)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)

local ShiftPass = {}

ShiftPass.XP = PassConfig.Xp

local services: { [string]: any }
local premium: { [Player]: boolean } = {}

local function publish(player: Player)
	if not player.Parent then
		return
	end
	local data = services.ShiftBank.data(player)
	player:SetAttribute("FrameId", data.frame or "paper")
	player:SetAttribute("Title", data.title or "")
	local season = Pass.current(os.time())
	if season then
		local view = Pass.view(data.pass, season, os.time(), premium[player] == true)
		player:SetAttribute("Pass", HttpService:JSONEncode(view))
	else
		player:SetAttribute("Pass", "")
	end
end
ShiftPass.publish = publish

local function announce(player: Player, rewards: { Pass.Reward })
	if #rewards == 0 then
		return
	end
	local parts = {}
	for _, reward in rewards do
		table.insert(parts, Pass.describe(reward))
	end
	services.ShiftSession.tell(player, `Biuro Pass: {table.concat(parts, ", ")}.`)
end

-- Experience earned on a shift. Pays any tiers it reaches.
function ShiftPass.xp(player: Player, amount: number)
	local season = Pass.current(os.time())
	if not season or amount <= 0 or not player.Parent then
		return
	end
	local bank = services.ShiftBank
	local due = Wallet.passXp(bank.data(player), season, amount, premium[player] == true)
	if #due > 0 then
		bank.changed(player)
		announce(player, due)
	else
		bank.touch(player)
	end
	publish(player)
end

-- Whether this player owns the running season's Game Pass; pays the premium tiers they reached
-- before buying it.
local function checkPremium(player: Player)
	local season = Pass.current(os.time())
	if not season or season.gamePassId == 0 then
		premium[player] = false
		publish(player)
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, season.gamePassId)
	end)
	if not player.Parent then
		return
	end
	premium[player] = ok and owns == true
	if premium[player] then
		local data = services.ShiftBank.data(player)
		local due = Pass.collect(data.pass, season, true)
		if #due > 0 then
			Wallet.grant(data, due)
			services.ShiftBank.changed(player)
			announce(player, due)
		end
	end
	publish(player)
end

-- Wears a viewfinder frame or a title the player owns ("" takes the title off).
function ShiftPass.wear(player: Player, kind: unknown, id: unknown)
	if typeof(id) ~= "string" then
		return
	end
	local data = services.ShiftBank.data(player)
	if kind == "frame" and Wallet.ownsFrame(data, id) then
		data.frame = id
	elseif kind == "title" and (id == "" or data.titles[id]) then
		data.title = if id == "" then nil else id
	else
		return
	end
	services.ShiftBank.changed(player)
	publish(player)
end

function ShiftPass.init(all: { [string]: any })
	services = all
	-- The wallet arrives after the player: check the pass once it has.
	services.ShiftBank.onLoaded(function(player)
		task.spawn(checkPremium, player)
	end)
end

function ShiftPass.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player, gamePassId, purchased)
			local season = Pass.current(os.time())
			if purchased and season and gamePassId == season.gamePassId then
				task.spawn(checkPremium, player)
			end
		end
	)
	Players.PlayerAdded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		premium[player] = nil
	end)
end

return ShiftPass
