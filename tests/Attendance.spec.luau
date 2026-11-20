--!strict
-- The attendance card: one stamp a day, days in a row climb it, a missed day starts it over.
local Attendance = require("../src/shared/Core/Attendance")
local Wallet = require("../src/shared/Core/Wallet")

return {
	["a day is stamped once, and days in a row climb the card"] = function()
		local card = Attendance.fresh()
		local stamp, square = Attendance.stamp(card, 100)
		assert(stamp and stamp.frames == 20 and square == 1)
		local again = Attendance.stamp(card, 100)
		assert(again == nil, "a day was stamped twice")
		stamp, square = Attendance.stamp(card, 101)
		assert(stamp and stamp.frames == 30 and square == 2)
	end,

	["a missed day starts the card over"] = function()
		local card = Attendance.fresh()
		Attendance.stamp(card, 100)
		Attendance.stamp(card, 101)
		assert(Attendance.filled(card, 102) == 2 and Attendance.filled(card, 103) == 0)
		local _, square = Attendance.stamp(card, 103)
		assert(square == 1 and card.streak == 1)
	end,

	["the seventh day pays the card's frame, then a new card begins"] = function()
		local data = Wallet.default()
		for day = 1, 6 do
			Wallet.attend(data, 200 + day)
		end
		assert(not data.cosmetics.punchcard)
		local stamp, square = Wallet.attend(data, 207)
		assert(stamp and square == 7 and data.cosmetics.punchcard)
		assert(data.frames == 20 + 30 + 40 + 50 + 60 + 80 + 100)
		local _, nextSquare = Wallet.attend(data, 208)
		assert(nextSquare == 1, "the card did not start over after seven")
		assert(Wallet.ownsFrame(data, "punchcard"))
		local stored = Wallet.migrate({ data = data }).data
		assert(stored.attendance.day == 208 and stored.attendance.streak == 8)
		assert(stored.cosmetics.punchcard, "the card's frame was dropped on load")
	end,
}
