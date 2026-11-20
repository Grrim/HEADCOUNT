--!strict
-- The saved wallet: one server owns a record at a time, and a stale lock is taken over.
local Wallet = require("../src/shared/Core/Wallet")

local TTL = 120

return {
	["a free record is claimed, and a held one is refused until it goes stale"] = function()
		local record, ok = Wallet.claim(nil, "A", 100, TTL)
		assert(ok and record.lock and record.lock.id == "A")
		local _, other = Wallet.claim(record, "B", 150, TTL)
		assert(not other, "two servers held one record")
		local taken, stale = Wallet.claim(record, "B", 100 + TTL, TTL)
		assert(stale and taken.lock and taken.lock.id == "B")
		local _, again = Wallet.claim(taken, "B", 300, TTL)
		assert(again, "a server refused its own lock")
	end,

	["a save is written only by the server holding the lock"] = function()
		local record = Wallet.claim(nil, "A", 0, TTL)
		local data = Wallet.default()
		data.frames = 250
		local saved = Wallet.commit(record, data, "A", 10)
		assert(saved and saved.data.frames == 250 and saved.lock and saved.lock.at == 10)
		assert(Wallet.commit(saved, data, "B", 20) == nil, "a stranger overwrote the wallet")
		local released = Wallet.release(saved, data, "A", 30)
		assert(released and released.lock == nil and released.data.frames == 250)
		assert(Wallet.commit(released, data, "A", 40) == nil, "saved after letting go")
	end,

	["damaged or hostile data falls back to safe values"] = function()
		local record = Wallet.migrate({
			data = {
				frames = -50,
				deepest = 0 / 0,
				levels = { battery = 3, tapes = 999, [5] = 2 },
				archive = { sitter = 4, watcher = 9 },
			},
			lock = { id = 7 },
		})
		assert(record.data.frames == 0 and record.data.deepest == 0)
		assert(record.data.levels.battery == 3 and record.data.levels.tapes == nil)
		assert(record.data.archive.sitter == 4 and record.data.archive.watcher == nil)
		assert(record.lock == nil)
	end,

	["the depth record counts only a ride back up"] = function()
		local data = Wallet.default()
		Wallet.recordShift(data, 120, 4, false)
		assert(data.frames == 120 and data.deepest == 0 and data.shifts == 1)
		Wallet.recordShift(data, 30.7, 3, true)
		assert(data.frames == 150 and data.deepest == 3 and data.shifts == 2)
		Wallet.recordShift(data, 0, 2, true)
		assert(data.deepest == 3, "a shallower return lowered the record")
	end,

	["the Archive keeps the best shot of each kind"] = function()
		local data = Wallet.default()
		assert(Wallet.archive(data, "sitter", 2))
		assert(not Wallet.archive(data, "sitter", 2) and not Wallet.archive(data, "sitter", 1))
		assert(Wallet.archive(data, "sitter", 5) and data.archive.sitter == 5)
		assert(not Wallet.archive(data, "nobody", 5), "an unknown kind was archived")
		Wallet.archive(data, "extra", 5)
		local found, total = Wallet.archiveCount(data)
		assert(found == 2 and total == #Wallet.KINDS)
	end,
}
