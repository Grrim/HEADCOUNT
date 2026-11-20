--!strict
-- Rank: a curve that starts quick and ends long, deeper floors as it rises, rewards once.
local Rank = require("../src/shared/Core/Rank")
local Wallet = require("../src/shared/Core/Wallet")

return {
	["the curve: rank 2 at 100, rank 10 at 4500, never past 50"] = function()
		assert(Rank.of(0) == 1 and Rank.of(99) == 1 and Rank.of(100) == 2)
		assert(Rank.of(4499) == 9 and Rank.of(4500) == 10)
		assert(Rank.of(1e9) == Rank.MAX)
		local rank, into, need = Rank.progress(150)
		assert(rank == 2 and into == 50 and need == 200)
		local top, _, left = Rank.progress(1e9)
		assert(top == 50 and left == 0)
	end,

	["each floor opens at its rank, and rank 10 reaches the bottom"] = function()
		assert(Rank.depthLimit(1) == 2 and Rank.depthLimit(2) == 2)
		assert(Rank.depthLimit(3) == 3 and Rank.depthLimit(6) == 4 and Rank.depthLimit(10) == 5)
		assert(Rank.depthLimit(50) == 5)
		assert(Rank.forDepth(3) == 3 and Rank.forDepth(5) == 10 and Rank.forDepth(1) == 1)
		assert(Rank.forDepth(9) == nil)
	end,

	["rising several ranks at once pays each reward once"] = function()
		local data = Wallet.default()
		local before, after, rewards = Wallet.rankXp(data, Rank.xpFor(16))
		assert(before == 1 and after == 16)
		assert(#rewards == 3, `{#rewards} rewards`)
		assert(data.titles.Clerk and data.titles["Field Recorder"] and data.cosmetics.brass)
		local _, _, again = Wallet.rankXp(data, 0)
		assert(#again == 0)
		assert(Wallet.ownsFrame(data, "brass"))
	end,

	["wallets from before ranks start at what they earned"] = function()
		local old = Wallet.migrate({ data = { frames = 10, earned = 5000 } }).data
		assert(old.rankXp == 5000 and Rank.of(old.rankXp) == 10)
		local kept = Wallet.migrate({ data = { earned = 5000, rankXp = 120 } }).data
		assert(kept.rankXp == 120)
		local ranked = Wallet.migrate({
			data = { titles = { Clerk = true }, cosmetics = { black = true } },
		}).data
		assert(ranked.titles.Clerk and ranked.cosmetics.black, "rank rewards were dropped on load")
	end,
}
