--!strict
-- The hall's seating grid as plain numbers. Rows A-L run from the stage to the back of the hall.
local Seats = {}

Seats.ROWS = 12
Seats.COLS = 16
Seats.TOTAL = Seats.ROWS * Seats.COLS
Seats.SPACING_X = 3.5
Seats.SPACING_Z = 5
Seats.AISLE_HALF_WIDTH = 3
Seats.FIRST_ROW_Z = -14

local LETTERS = "ABCDEFGHIJKL"

function Seats.id(row: number, col: number): number
	return (row - 1) * Seats.COLS + col
end

-- The seat left empty for each member of the team on the final tape: row C, near the aisle.
function Seats.castSeat(index: number): number
	return Seats.id(3, 6 + index * 2)
end

function Seats.fromId(id: number): (number, number)
	local zeroBased = id - 1
	return zeroBased // Seats.COLS + 1, zeroBased % Seats.COLS + 1
end

function Seats.isValidId(id: number): boolean
	return id >= 1 and id <= Seats.TOTAL and id % 1 == 0
end

function Seats.rowLetter(row: number): string
	return LETTERS:sub(row, row)
end

function Seats.label(id: number): string
	local row, col = Seats.fromId(id)
	return string.format("%s-%02d", Seats.rowLetter(row), col)
end

-- Centre of a seat on the floor plane. Columns 1-8 sit west of the aisle, 9-16 east of it.
function Seats.position(id: number): (number, number)
	local row, col = Seats.fromId(id)
	local half = Seats.COLS / 2
	local offset = (col - half - 0.5) * Seats.SPACING_X
	local side = if col <= half then -1 else 1
	return offset + side * Seats.AISLE_HALF_WIDTH, Seats.FIRST_ROW_Z + (row - 1) * Seats.SPACING_Z
end

return Seats
