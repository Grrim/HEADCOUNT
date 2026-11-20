--!strict
-- The Biuro Pass: tiers from experience, free rewards for everyone, premium ones for owners (also
-- for tiers reached before buying), cosmetics only on the paid track.
local Pass = require("../src/shared/Core/Pass")
local PassConfig = require("../src/shared/Config/Pass")
local Wallet = require("../src/shared/Core/Wallet")

local SEASON = PassConfig.Seasons[1]

return {
	["the season runs between its dates, and only then"] = function()
		assert(Pass.current(SEASON.starts) == SEASON and Pass.current(SEASON.ends - 1) == SEASON)
		assert(Pass.current(SEASON.starts - 1) == nil and Pass.current(SEASON.ends) == nil)
	end,

	["the paid track never pays Frames"] = function()
		for _, season in PassConfig.Seasons do
			for tier, reward in season.premium do
				assert(
					reward.frames == nil,
					`premium tier {tier} pays Frames: an advantage for Robux`
				)
			end
		end
	end,

	["each tier reached pays once, and premium also pays the tiers before buying"] = function()
		local data = Wallet.default()
		local due = Wallet.passXp(data, SEASON, 250, false)
		assert(Pass.tier(SEASON, data.pass.xp) == 2 and #due == 2 and data.frames == 50)
		assert(#Wallet.passXp(data, SEASON, 0, false) == 0, "a tier was paid twice")
		-- Bought now: the premium reward of tier 2 arrives with the next collect.
		local late = Pass.collect(data.pass, SEASON, true)
		Wallet.grant(data, late)
		assert(
			#late == 1 and data.cosmetics.ledger,
			"the premium tier reached earlier was not paid"
		)
		assert(#Pass.collect(data.pass, SEASON, true) == 0)
	end,

	["experience stops at the top tier"] = function()
		local data = Wallet.default()
		Wallet.passXp(data, SEASON, 1e6, true)
		assert(Pass.tier(SEASON, data.pass.xp) == SEASON.tiers and data.cosmetics.gold)
		assert(data.titles["Keeper of Tape Zero"] and data.titles["Night Porter"])
	end,

	["a new season starts over, and what was unlocked stays"] = function()
		local data = Wallet.default()
		Wallet.passXp(data, SEASON, 1000, false)
		local next: Pass.Season = table.clone(SEASON)
		next.id = "S2"
		Wallet.passXp(data, next, 10, false)
		assert(data.pass.season == "S2" and data.pass.xp == 10 and data.pass.freePaid == 0)
		assert(data.cosmetics.bureau, "a season's cosmetic was taken back")
	end,

	["only owned frames and titles can be worn, and junk is dropped"] = function()
		local stored = Wallet.migrate({
			data = {
				cosmetics = { gold = true, hacked = true },
				titles = { ["Night Porter"] = true, ["God"] = true },
				frame = "hacked",
				title = "Night Porter",
				pass = { season = "S1", xp = 340, freePaid = 3, premiumPaid = -2 },
			},
		}).data
		assert(stored.cosmetics.gold and stored.cosmetics.hacked == nil)
		assert(stored.titles["Night Porter"] and stored.titles["God"] == nil)
		assert(stored.frame == nil and stored.title == "Night Porter")
		assert(stored.pass.xp == 340 and stored.pass.premiumPaid == 0)
		assert(Wallet.ownsFrame(stored, "paper") and not Wallet.ownsFrame(stored, "neon"))
	end,

	["the screen shows what comes next on each track"] = function()
		local view = Pass.view(Pass.fresh("S1"), SEASON, SEASON.starts, false)
		assert(view.tier == 0 and view.nextFree.tier == 1 and view.nextPremium.tier == 2)
		assert(view.forSale == (SEASON.gamePassId ~= 0) and view.daysLeft == 42)
	end,
}
