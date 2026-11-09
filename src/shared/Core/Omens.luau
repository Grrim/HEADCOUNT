--!strict
-- Small wrong things, chosen per player. Two players get different orders and different targets, so
-- comparing notes really does turn up disagreements. Only the choice lives here; the staging is on
-- the client, because each player's copy of an omen is their own.
local Rng = require("./Rng")
local Seats = require("./Seats")

local Omens = {}

export type Omen = { kind: string, at: number, seatId: number? }

-- Everything the director knows how to stage, with the seconds of play before it may happen.
local KINDS = {
	{ kind = "steps_behind", earliest = 70 },
	{ kind = "chair_turned", earliest = 110 },
	{ kind = "panel_out", earliest = 150 },
	{ kind = "aisle_chair", earliest = 200 },
	{ kind = "knock_wall", earliest = 240 },
	{ kind = "corridor_figure", earliest = 280 },
	{ kind = "double", earliest = 310 },
	{ kind = "bell_rings", earliest = 330 },
	{ kind = "whisper_name", earliest = 230 },
	{ kind = "lens_face", earliest = 340 },
	{ kind = "row_turned", earliest = 390 },
	{ kind = "blackout", earliest = 430 },
	{ kind = "steps_behind", earliest = 450 },
	{ kind = "double", earliest = 480 },
	{ kind = "panel_out", earliest = 520 },
}

function Omens.schedule(seed: number, userId: number): { Omen }
	local rng = Rng.new(seed + userId * 7919)
	local omens: { Omen } = {}
	for _, entry in KINDS do
		local omen: Omen = { kind = entry.kind, at = entry.earliest + rng:int(0, 45) }
		if entry.kind == "chair_turned" then
			omen.seatId = rng:int(1, Seats.TOTAL)
		elseif entry.kind == "row_turned" then
			omen.seatId = Seats.id(rng:int(2, Seats.ROWS), 1)
		end
		table.insert(omens, omen)
	end
	table.sort(omens, function(a, b)
		return a.at < b.at
	end)
	return omens
end

return Omens
