--!strict
-- The mission's answers. Lives on the server: the client learns a target only when a recording
-- actually framed it, and a digit of the code only if that digit was dealt to that player.
local Rng = require("./Rng")
local Seats = require("./Seats")

local Puzzle = {}

Puzzle.TARGET_COUNT = 3
Puzzle.HOOK_COUNT = 40
Puzzle.CODE_LENGTH = 3

export type Target = { seatId: number, label: string, hook: number, reel: string }
export type Puzzle = {
	targets: { Target },
	doorSide: number,
	code: { number },
	reelOrder: { string },
}

local REELS = { "A", "B", "C" }

function Puzzle.generate(seed: number): Puzzle
	local rng = Rng.new(seed)
	local targets: { Target } = {}
	local usedHooks: { [number]: boolean } = {}
	-- One target per band of rows, so a single sweep of the hall cannot find all three by accident.
	local band = Seats.ROWS // Puzzle.TARGET_COUNT
	for index = 1, Puzzle.TARGET_COUNT do
		local row = rng:int((index - 1) * band + 1, index * band)
		local col = rng:int(1, Seats.COLS)
		local seatId = Seats.id(row, col)
		local hook = rng:int(1, Puzzle.HOOK_COUNT)
		while usedHooks[hook] do
			hook = hook % Puzzle.HOOK_COUNT + 1
		end
		usedHooks[hook] = true
		table.insert(targets, {
			seatId = seatId,
			label = Seats.label(seatId),
			hook = hook,
			reel = REELS[index],
		})
	end
	local doorSide = if rng:int(0, 1) == 0 then -1 else 1
	local code = {}
	for index = 1, Puzzle.CODE_LENGTH do
		code[index] = rng:int(0, 9)
	end
	-- Never the obvious A-B-C: if the order were the alphabet, nobody would need the tape.
	local orders = { { "C", "A", "B" }, { "B", "C", "A" }, { "A", "C", "B" }, { "C", "B", "A" } }
	return {
		targets = targets,
		doorSide = doorSide,
		code = code,
		reelOrder = orders[rng:int(1, #orders)],
	}
end

function Puzzle.targetAtSeat(puzzle: Puzzle, seatId: number): Target?
	for _, target in puzzle.targets do
		if target.seatId == seatId then
			return target
		end
	end
	return nil
end

function Puzzle.targetAtHook(puzzle: Puzzle, hook: number): Target?
	for _, target in puzzle.targets do
		if target.hook == hook then
			return target
		end
	end
	return nil
end

-- Deals each digit position to one player, so a team has to read them out to each other.
-- A solo player gets every position. Returns { [userId] = { [position] = digit } }.
function Puzzle.dealCode(code: { number }, userIds: { number }): { [number]: { [number]: number } }
	local sorted = table.clone(userIds)
	table.sort(sorted)
	local hands: { [number]: { [number]: number } } = {}
	for _, userId in sorted do
		hands[userId] = {}
	end
	if #sorted == 0 then
		return hands
	end
	for position, digit in code do
		hands[sorted[(position - 1) % #sorted + 1]][position] = digit
	end
	return hands
end

function Puzzle.codeMatches(code: { number }, entry: unknown): boolean
	if typeof(entry) ~= "table" then
		return false
	end
	local digits = entry :: { unknown }
	if #digits ~= #code then
		return false
	end
	for index, digit in code do
		if digits[index] ~= digit then
			return false
		end
	end
	return true
end

-- Follows reels being loaded one by one. A wrong reel empties the projector.
-- Returns the new number loaded, and whether this one was a mistake.
function Puzzle.loadReel(order: { string }, loaded: number, reel: string): (number, boolean)
	if order[loaded + 1] == reel then
		return loaded + 1, false
	end
	return 0, true
end

return Puzzle
