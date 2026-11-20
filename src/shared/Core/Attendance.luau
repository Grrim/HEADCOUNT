--!strict
-- The attendance card (docs/09_GDD_V2.md §4, "seria logowań z kosmetykiem w dniu 7"): every day a
-- player works a shift is stamped. Days in a row climb the card; a missed day starts it over.
-- Each stamp pays a little more, and the seventh pays a viewfinder frame only the card gives,
-- then a new card begins. Days are UTC (Core/Quests.day).
local Attendance = {}

Attendance.LENGTH = 7
Attendance.FRAME = "punchcard"

export type Stamp = { frames: number, frame: string? }

Attendance.STAMPS = {
	{ frames = 20 },
	{ frames = 30 },
	{ frames = 40 },
	{ frames = 50 },
	{ frames = 60 },
	{ frames = 80 },
	{ frames = 100, frame = Attendance.FRAME },
} :: { Stamp }

-- A player's card: the last day stamped and how many days in a row that makes.
export type Card = { day: number, streak: number }

function Attendance.fresh(): Card
	return { day = 0, streak = 0 }
end

-- Stamps today, unless it already is. Returns the stamp it earned (nil when already stamped) and
-- which square of the card it filled (1 to 7).
function Attendance.stamp(card: Card, today: number): (Stamp?, number)
	if card.day == today then
		return nil, ((card.streak - 1) % Attendance.LENGTH) + 1
	end
	card.streak = if card.day == today - 1 then card.streak + 1 else 1
	card.day = today
	local square = ((card.streak - 1) % Attendance.LENGTH) + 1
	return Attendance.STAMPS[square], square
end

-- How many squares of the current card are filled, as seen on `today`: a card whose last stamp
-- is older than yesterday has lapsed.
function Attendance.filled(card: Card, today: number): number
	if card.streak == 0 or card.day < today - 1 then
		return 0
	end
	return ((card.streak - 1) % Attendance.LENGTH) + 1
end

return Attendance
