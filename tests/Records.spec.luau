--!strict
-- The records board: deeper always ranks higher, Frames break ties, a score never goes down.
local Records = require("../src/shared/Core/Records")
local Wallet = require("../src/shared/Core/Wallet")

return {
	["a deeper return outranks any amount of Frames"] = function()
		assert(Records.score(3, 0) > Records.score(2, 9_999_999))
		assert(Records.score(5, 120) > Records.score(5, 119))
	end,

	["a score reads back as the depth and the Frames it was made of"] = function()
		local deepest, earned = Records.decode(Records.score(4, 1234))
		assert(deepest == 4 and earned == 1234)
		local d, e = Records.decode("junk")
		assert(d == 0 and e == 0)
		d, e = Records.decode(-5)
		assert(d == 0 and e == 0)
	end,

	["a save never lowers a stored score"] = function()
		assert(Records.best(500, 300) == 500)
		assert(Records.best(nil, 300) == 300)
		assert(Records.best(0 / 0, 7) == 7)
	end,

	["a board line keeps its width and cuts long names on a character"] = function()
		local line = Records.line(1, "Ann", Records.score(5, 900), 24)
		assert(#line == 24, `line was {#line} wide: {line}`)
		assert(string.sub(line, 1, 6) == "1. Ann" and string.sub(line, -7) == "-5  900")
		local long = Records.line(10, "Żółwik_Nieskończenie_Długi", Records.score(2, 5), 24)
		assert(utf8.len(long) == 24, `long line was {utf8.len(long)} characters`)
		assert(utf8.len(long) ~= nil, "a name was cut inside a character")
	end,

	["the wallet counts every Frame ever earned, spending or not"] = function()
		local data = Wallet.default()
		Wallet.recordShift(data, 120, 2, true)
		data.frames -= 100
		Wallet.recordShift(data, 30, 1, false)
		assert(data.earned == 150 and data.frames == 50)
		assert(Wallet.migrate({ data = { earned = 77 } }).data.earned == 77)
	end,

	["weeks start on Monday 00:00 UTC"] = function()
		-- 2026-11-16 was a Monday; 2026-11-22 a Sunday.
		local monday = 1_794_787_200
		assert(Records.week(monday) == Records.week(monday + 6 * 86400 + 86399))
		assert(Records.week(monday) == Records.week(monday - 1) + 1)
		assert(Records.weekEnds(Records.week(monday)) == monday + 7 * 86400)
		assert(
			Records.weeklyStore(Records.week(monday))
				~= Records.weeklyStore(Records.week(monday - 1))
		)
		assert(Records.untilReset(monday) == "7d 0h")
		assert(Records.untilReset(monday + 7 * 86400 - 3700) == "1h 1m")
		assert(Records.untilReset(monday + 7 * 86400 - 30) == "1m")
	end,

	["a new week starts the weekly standing from nothing"] = function()
		local data = Wallet.default()
		Wallet.recordShift(data, 100, 4, true, 10)
		Wallet.recordShift(data, 50, 2, true, 10)
		assert(data.weekDeepest == 4 and data.weekEarned == 150)
		Wallet.recordShift(data, 20, 1, true, 11)
		assert(data.week == 11 and data.weekDeepest == 1 and data.weekEarned == 20)
		assert(data.deepest == 4 and data.earned == 170, "a new week touched the all-time standing")
		Wallet.recordShift(data, 5, 5, false, 11)
		assert(data.weekDeepest == 1, "a shift that never came back up set a weekly depth")
	end,

	["frames earned before the saved wallet arrived are added, this week's too"] = function()
		local saved = Wallet.default()
		Wallet.recordShift(saved, 300, 3, true, 9)
		local early = Wallet.default()
		Wallet.recordShift(early, 40, 2, true, 10)
		local merged = Wallet.merge(saved, early)
		assert(merged.frames == 340 and merged.earned == 340 and merged.deepest == 3)
		assert(merged.week == 10 and merged.weekEarned == 40 and merged.weekDeepest == 2)
		local same = Wallet.default()
		Wallet.recordShift(same, 10, 4, true, 10)
		Wallet.merge(merged, same)
		assert(merged.weekEarned == 50 and merged.weekDeepest == 4)
		local untouched = Wallet.merge(merged, Wallet.default())
		assert(
			untouched.week == 10 and untouched.weekEarned == 50,
			"an empty early wallet reset the week"
		)
	end,

	["the top of a finished week is paid, the rest of the top ten a little"] = function()
		assert(Records.reward(1) == 500 and Records.reward(3) == 200 and Records.reward(10) == 100)
		assert(Records.reward(11) == 0 and Records.reward(0) == 0)
		assert(Records.honour(1) == "gold" and Records.honour(3) == "bronze")
		assert(Records.honour(7) == "top10" and Records.honour(11) == nil)
	end,

	["a finished week is paid once, and only weeks that are over"] = function()
		local data = Wallet.default()
		data.rewardedWeek = 40
		local weeks = Wallet.weeksToClaim(data, 42)
		assert(#weeks == 1 and weeks[1] == 41, "the running week was offered")
		assert(Wallet.claimWeek(data, 41, Records.reward(2), Records.honour(2)) == 300)
		assert(data.frames == 300 and data.earned == 300 and data.honours.silver == 1)
		assert(Wallet.claimWeek(data, 41, 300, "silver") == 0, "a week was paid twice")
		assert(#Wallet.weeksToClaim(data, 42) == 0)
		assert(Wallet.claimWeek(data, 39, 500, "gold") == 0, "an older week was paid after a newer")
	end,

	["someone back after a long break can still collect the last few weeks"] = function()
		local data = Wallet.default()
		local weeks = Wallet.weeksToClaim(data, 2900)
		assert(#weeks == Wallet.CLAIM_WEEKS and weeks[1] == 2900 - Wallet.CLAIM_WEEKS)
		assert(weeks[#weeks] == 2899)
		assert(Wallet.claimWeek(data, 2897, 0, nil) == 0 and data.rewardedWeek == 2897)
		local saved = Wallet.migrate({ data = data }).data
		assert(saved.rewardedWeek == 2897)
	end,

	["commendations survive a save and junk does not"] = function()
		local data = Wallet.migrate({
			data = { honours = { gold = 2, top10 = 5, platinum = 9, silver = -1 } },
		}).data
		assert(data.honours.gold == 2 and data.honours.top10 == 5)
		assert(data.honours.platinum == nil and data.honours.silver == nil)
	end,
}
