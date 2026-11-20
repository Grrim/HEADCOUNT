--!strict
-- Daily tasks (docs/09_GDD_V2.md §4, §5): three a day, the same three for everyone, so "did you do
-- today's?" is a thing to ask. One easy, one medium, one hard, drawn from the date (UTC), each
-- paying Frames the moment it is done. Every task can be done alone: none needs a teammate.
--
-- Progress is counted from what happens on a shift ("events"): a task either adds up what it
-- counts (`sum`) or keeps the best single value (`max`, such as the deepest floor come back from).
local Rng = require("./Rng")

local Quests = {}

Quests.DAY = 86400

export type Quest = {
	id: string,
	tier: number,
	event: string,
	mode: string,
	target: number,
	reward: number,
	text: string,
}

-- What a shift reports: film (a shot that improved on the team's best), film_rare (the same, rare
-- or better), five_stars, door (a code door opened), extra (the Extra filmed until gone),
-- tape_watch (a tape played on a floor), return_depth (the floor a lift ride came back from),
-- shift_done (a shift come back with the quota met), banked (footage brought back up).
Quests.POOL = {
	{
		id = "film4",
		tier = 1,
		event = "film",
		mode = "sum",
		target = 4,
		reward = 40,
		text = "Film 4 anomalies",
	},
	{
		id = "bank60",
		tier = 1,
		event = "banked",
		mode = "sum",
		target = 60,
		reward = 40,
		text = "Bring back 60 footage",
	},
	{
		id = "watch1",
		tier = 1,
		event = "tape_watch",
		mode = "sum",
		target = 1,
		reward = 40,
		text = "Watch a tape on a floor",
	},
	{
		id = "back2",
		tier = 1,
		event = "return_depth",
		mode = "max",
		target = 2,
		reward = 40,
		text = "Come back up from floor -2",
	},
	{
		id = "rare3",
		tier = 2,
		event = "film_rare",
		mode = "sum",
		target = 3,
		reward = 80,
		text = "Film 3 rare or better anomalies",
	},
	{
		id = "five1",
		tier = 2,
		event = "five_stars",
		mode = "sum",
		target = 1,
		reward = 80,
		text = "Get a five-star shot",
	},
	{
		id = "back3",
		tier = 2,
		event = "return_depth",
		mode = "max",
		target = 3,
		reward = 80,
		text = "Come back up from floor -3",
	},
	{
		id = "quota2",
		tier = 2,
		event = "shift_done",
		mode = "sum",
		target = 2,
		reward = 80,
		text = "Finish 2 shifts with the quota",
	},
	{
		id = "door1",
		tier = 2,
		event = "door",
		mode = "sum",
		target = 1,
		reward = 80,
		text = "Open a code door",
	},
	{
		id = "extra1",
		tier = 3,
		event = "extra",
		mode = "sum",
		target = 1,
		reward = 150,
		text = "Film the Extra until it is gone",
	},
	{
		id = "back5",
		tier = 3,
		event = "return_depth",
		mode = "max",
		target = 5,
		reward = 150,
		text = "Come back up from floor -5",
	},
	{
		id = "bank400",
		tier = 3,
		event = "banked",
		mode = "sum",
		target = 400,
		reward = 150,
		text = "Bring back 400 footage",
	},
	{
		id = "five5",
		tier = 3,
		event = "five_stars",
		mode = "sum",
		target = 5,
		reward = 150,
		text = "Get 5 five-star shots",
	},
} :: { Quest }

local byId: { [string]: Quest } = {}
for _, quest in Quests.POOL do
	byId[quest.id] = quest
end

function Quests.get(id: string): Quest?
	return byId[id]
end

function Quests.day(now: number): number
	return math.floor(now / Quests.DAY)
end

-- Seconds until the day's tasks change.
function Quests.secondsLeft(now: number): number
	return (Quests.day(now) + 1) * Quests.DAY - math.floor(now)
end

-- The day's three tasks, easiest first: the same for everyone on that day.
function Quests.today(day: number): { Quest }
	local rng = Rng.new(day * 7919 + 13)
	local picked = {}
	for tier = 1, 3 do
		local options = {}
		for _, quest in Quests.POOL do
			if quest.tier == tier then
				table.insert(options, quest)
			end
		end
		table.insert(picked, options[rng:int(1, #options)])
	end
	return picked
end

-- A player's tasks for a day: how far each has got, and which are done.
export type Progress = { day: number, counts: { [string]: number }, done: { [string]: boolean } }

function Quests.fresh(day: number): Progress
	return { day = day, counts = {}, done = {} }
end

-- Counts an event towards the day's tasks, starting the day afresh when it has changed. Returns
-- the tasks this finished.
function Quests.record(progress: Progress, day: number, event: string, amount: number): { Quest }
	if progress.day ~= day then
		progress.day = day
		progress.counts = {}
		progress.done = {}
	end
	local finished = {}
	if amount <= 0 then
		return finished
	end
	for _, quest in Quests.today(day) do
		if quest.event == event and not progress.done[quest.id] then
			local before = progress.counts[quest.id] or 0
			local now = if quest.mode == "max" then math.max(before, amount) else before + amount
			progress.counts[quest.id] = math.min(now, quest.target)
			if now >= quest.target then
				progress.done[quest.id] = true
				table.insert(finished, quest)
			end
		end
	end
	return finished
end

-- The day's tasks with this player's progress, for a screen.
function Quests.view(progress: Progress, day: number): { any }
	local current = progress.day == day
	local list = {}
	for _, quest in Quests.today(day) do
		table.insert(list, {
			id = quest.id,
			text = quest.text,
			target = quest.target,
			reward = quest.reward,
			count = if current then progress.counts[quest.id] or 0 else 0,
			done = current and progress.done[quest.id] == true,
		})
	end
	return list
end

return Quests
