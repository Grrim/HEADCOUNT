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
}
