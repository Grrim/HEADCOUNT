--!strict
-- Live events: tonight's modifier and the anomaly of the week.
local FloorGen = require("../src/shared/Core/FloorGen")
local Nights = require("../src/shared/Core/Nights")
local Wallet = require("../src/shared/Core/Wallet")

return {
	["every day has one of the four nights, the same for everyone"] = function()
		local seen = {}
		for day = 20000, 20100 do
			local night = Nights.tonight(day)
			assert(Nights.byId(night.id) == night and Nights.tonight(day) == night)
			seen[night.id] = true
		end
		for _, night in Nights.ALL do
			assert(seen[night.id], `{night.id} never came up in 100 days`)
		end
		assert(Nights.byId("nonsense") == Nights.STANDARD)
	end,

	["the weekly anomaly shows on many floors, never in the lobby or a vault"] = function()
		local found = 0
		for seed = 1, 100 do
			local depth = 2 + seed % 3
			local plain = FloorGen.generate(seed, depth)
			local floor = FloorGen.generate(seed, depth, false, "watcher")
			for index, spot in plain.spots do
				assert(floor.spots[index].x == spot.x, "the weekly anomaly moved the others")
			end
			for _, spot in floor.spots do
				if spot.weekly then
					found += 1
					assert(spot.kind == "watcher" and spot.rarity == "epic")
					assert(spot.room ~= floor.start)
					assert(not floor.vault or spot.room ~= floor.vault.room)
				end
			end
		end
		assert(found > 40 and found < 80, `{found} weekly anomalies in 100 floors`)
	end,

	["the weekly bonus pays once a week"] = function()
		local data = Wallet.default()
		assert(Wallet.weeklyFound(data, 2900, 100) and data.frames == 100)
		assert(not Wallet.weeklyFound(data, 2900, 100) and data.frames == 100)
		assert(Wallet.weeklyFound(data, 2901, 100) and data.frames == 200)
		assert(Wallet.migrate({ data = data }).data.weeklyWeek == 2901)
		assert(
			Nights.weekly(2900).kind ~= Nights.weekly(2901).kind,
			"the same anomaly two weeks running"
		)
	end,
}
