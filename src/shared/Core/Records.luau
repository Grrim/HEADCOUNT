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

return Records
