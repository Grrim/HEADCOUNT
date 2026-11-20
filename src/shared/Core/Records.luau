--!strict
-- The lobby's records board, as numbers. An OrderedDataStore keeps one integer per player, so the
-- two things the board ranks by are packed into it: the deepest floor they came back up from,
-- and, to break the many ties at the bottom floor, every Frame they ever earned on a shift.
--
--   score = deepest * SPAN + min(earned, SPAN - 1)
--
-- Both only ever grow, so a score can only go up, and a save keeps the larger of the two.
local Records = {}

Records.SPAN = 10_000_000
Records.SHOWN = 10
Records.STORE = "ShiftRecords_v1"

-- Weekly boards: a week starts on Monday 00:00 UTC. The Unix epoch was a Thursday, so the first
-- Monday came four days later. Each week has a store of its own and starts empty.
Records.WEEK = 7 * 86400
local FIRST_MONDAY = 4 * 86400

function Records.week(now: number): number
	return (math.floor(now) - FIRST_MONDAY) // Records.WEEK
end

-- When this week's board starts over (Unix time).
function Records.weekEnds(week: number): number
	return FIRST_MONDAY + (week + 1) * Records.WEEK
end

function Records.weeklyStore(week: number): string
	return `ShiftRecords_w{week}`
end

-- What a place on a finished week's board pays, and the commendation that goes with it. Frames
-- only: a place on the board is earned by playing and buys nothing a player could not earn.
Records.PAY = { 500, 300, 200, 100, 100, 100, 100, 100, 100, 100 }
Records.HONOURS = { "gold", "silver", "bronze" }

function Records.reward(place: number): number
	return Records.PAY[place] or 0
end

function Records.honour(place: number): string?
	if place < 1 or place > #Records.PAY then
		return nil
	end
	return Records.HONOURS[place] or "top10"
end

-- "3d 4h", "5h 12m", "9m": how long until the weekly board starts over.
function Records.untilReset(now: number): string
	local left = math.max(0, Records.weekEnds(Records.week(now)) - math.floor(now))
	local days, hours, minutes = left // 86400, (left % 86400) // 3600, (left % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{math.max(1, minutes)}m`
end

function Records.score(deepest: number, earned: number): number
	local depth = math.max(0, math.floor(deepest))
	local frames = math.clamp(math.floor(earned), 0, Records.SPAN - 1)
	return depth * Records.SPAN + frames
end

-- Back from a stored score to (deepest, earned). Anything malformed reads as nothing.
function Records.decode(score: any): (number, number)
	if typeof(score) ~= "number" or score ~= score or score < 0 then
		return 0, 0
	end
	local whole = math.floor(score)
	return whole // Records.SPAN, whole % Records.SPAN
end

-- The UpdateAsync transform: never lower a stored score.
function Records.best(stored: any, score: number): number
	local current = if typeof(stored) == "number" and stored == stored then stored else 0
	return math.max(current, score)
end

-- One line of the board: rank, a name cut to fit, the depth, the Frames.
function Records.line(rank: number, name: string, score: number, width: number): string
	local deepest, earned = Records.decode(score)
	local right = `-{deepest}  {earned}`
	local left = `{rank}. `
	local room = math.max(1, width - #left - #right - 1)
	local length = utf8.len(name) or #name
	local shown = name
	if length > room then
		-- Cut on a character boundary: display names may hold more than ASCII.
		local cut = utf8.offset(name, room + 1) or (#name + 1)
		shown = string.sub(name, 1, cut - 1)
		length = room
	end
	local gap = math.max(1, width - #left - length - #right)
	return left .. shown .. string.rep(" ", gap) .. right
end

-- The friends board: this player and those of their friends who have a score, ranked like the
-- all-time board (ties by this week's score, then by id so the order never wobbles). `names`
-- holds the friends and the player themself; only scores found in the scanned top of each board
-- are known.
export type FriendRow = { rank: number, id: number, name: string, all: number, week: number }

function Records.friendsBoard(
	all: { [number]: number },
	week: { [number]: number },
	names: { [number]: string }
): { FriendRow }
	local rows: { FriendRow } = {}
	for id, name in names do
		local allScore = all[id] or 0
		local weekScore = week[id] or 0
		if allScore > 0 or weekScore > 0 then
			table.insert(rows, { rank = 0, id = id, name = name, all = allScore, week = weekScore })
		end
	end
	table.sort(rows, function(a, b)
		if a.all ~= b.all then
			return a.all > b.all
		elseif a.week ~= b.week then
			return a.week > b.week
		end
		return a.id < b.id
	end)
	while #rows > Records.SHOWN do
		table.remove(rows)
	end
	for index, row in rows do
		row.rank = index
	end
	return rows
end

-- A friends board line: like `line`, with this week's depth after the all-time standing.
function Records.friendLine(row: FriendRow, width: number): string
	local weekDeepest = Records.decode(row.week)
	local tail = if row.week > 0 then `  W -{weekDeepest}` else "  W --"
	local base = Records.line(row.rank, row.name, row.all, width - #tail)
	return base .. tail
end

return Records
