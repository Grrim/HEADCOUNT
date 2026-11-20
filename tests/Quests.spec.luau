--!strict
-- Daily tasks: the same three for everyone on a day, counted from shift events, paid once.
local Quests = require("../src/shared/Core/Quests")
local Wallet = require("../src/shared/Core/Wallet")

local function find(list: { Quests.Quest }, event: string): Quests.Quest?
	for _, quest in list do
		if quest.event == event then
			return quest
		end
	end
	return nil
end

return {
	["a day has one easy, one medium and one hard task, the same for everyone"] = function()
		for day = 20000, 20060 do
			local today = Quests.today(day)
			assert(#today == 3 and today[1].tier == 1 and today[2].tier == 2 and today[3].tier == 3)
			assert(Quests.today(day)[2].id == today[2].id, "the same day drew different tasks")
		end
		local differs = false
		for day = 20000, 20010 do
			if Quests.today(day)[3].id ~= Quests.today(day + 1)[3].id then
				differs = true
			end
		end
		assert(differs, "every day had the same hard task")
	end,

	["a task adds up until it is done, and is paid once"] = function()
		local data = Wallet.default()
		-- Find a day whose easy task counts filmed anomalies.
		local day = 20000
		while Quests.today(day)[1].id ~= "film4" do
			day += 1
		end
		local now = day * Quests.DAY + 100
		for _ = 1, 3 do
			assert(#Wallet.questEvent(data, now, "film", 1) == 0)
		end
		local finished = Wallet.questEvent(data, now, "film", 1)
		assert(#finished == 1 and finished[1].id == "film4" and data.frames == 40)
		assert(data.earned == 40)
		assert(#Wallet.questEvent(data, now, "film", 5) == 0 and data.frames == 40, "paid twice")
	end,

	["a deepest-floor task keeps the best, not the sum"] = function()
		local day = 20000
		while not find(Quests.today(day), "return_depth") do
			day += 1
		end
		local quest = find(Quests.today(day), "return_depth") :: Quests.Quest
		local progress = Quests.fresh(day)
		Quests.record(progress, day, "return_depth", 1)
		Quests.record(progress, day, "return_depth", 1)
		assert((progress.counts[quest.id] or 0) == 1, "two shallow returns added up")
		local finished = Quests.record(progress, day, "return_depth", quest.target)
		assert(#finished == 1)
	end,

	["a new day starts the tasks afresh"] = function()
		local progress = Quests.fresh(5)
		progress.counts.film4 = 3
		progress.done.five1 = true
		Quests.record(progress, 6, "nothing", 1)
		assert(progress.day == 6 and next(progress.counts) == nil and next(progress.done) == nil)
		local view = Quests.view(Quests.fresh(5), 6)
		assert(#view == 3 and view[1].count == 0 and not view[1].done)
		assert(Quests.secondsLeft(6 * Quests.DAY + 10) == Quests.DAY - 10)
	end,

	["saved progress survives, junk does not, and early progress merges in"] = function()
		local stored = Wallet.migrate({
			data = {
				quests = {
					day = 7,
					counts = { film4 = 3, bogus = 9, back2 = 99 },
					done = { five1 = true, x = true },
				},
			},
		}).data
		assert(stored.quests.day == 7 and stored.quests.counts.film4 == 3)
		assert(stored.quests.counts.bogus == nil and stored.quests.counts.back2 == nil)
		assert(stored.quests.done.five1 and stored.quests.done.x == nil)
		local early = Wallet.default()
		early.quests = { day = 7, counts = { film4 = 4 }, done = { film4 = true } }
		local merged = Wallet.merge(stored, early)
		assert(
			merged.quests.counts.film4 == 4
				and merged.quests.done.film4
				and merged.quests.done.five1
		)
	end,
}
