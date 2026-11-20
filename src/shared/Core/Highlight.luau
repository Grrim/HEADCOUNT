--!strict
-- The shift tape (docs/09_GDD_V2.md §7): the shift's best shot, cut down to the stretch that held
-- its subject longest, and kept as plain numbers so it can be played back anywhere, long after the
-- floor it was shot on is gone. A tape is the floor's seed and depth plus a camera path; the
-- floor and its figures are rebuilt from those (World/FloorBuild, World/Figures).
local Framing = require("./Framing")

local Highlight = {}

-- How long the shift tape runs.
Highlight.SECONDS = 8
-- The most samples a packed path may hold (13 s at 10 Hz).
Highlight.MAX_SAMPLES = 130

export type Sample = { number }

-- The stretch of at most `seconds` that frames the target in the most samples (the earliest of
-- equals). Returns the first and last sample index.
function Highlight.window(
	samples: { Sample },
	target: { x: number, y: number, z: number },
	hz: number,
	seconds: number,
	cosHalfFov: number,
	range: number
): (number, number)
	local count = #samples
	local length = math.max(1, math.min(count, math.floor(seconds * hz)))
	local framed = {}
	for index, s in samples do
		framed[index] = if Framing.isFramed(
				s[1],
				s[2],
				s[3],
				s[4],
				s[5],
				s[6],
				target.x,
				target.y,
				target.z,
				cosHalfFov,
				range
			)
			then 1
			else 0
	end
	local sum = 0
	for index = 1, length do
		sum += framed[index] or 0
	end
	local best, bestFirst = sum, 1
	for first = 2, count - length + 1 do
		sum += framed[first + length - 1] - framed[first - 1]
		if sum > best then
			best, bestFirst = sum, first
		end
	end
	return bestFirst, math.min(count, bestFirst + length - 1)
end

local function round(value: number, step: number): number
	return math.floor(value / step + 0.5) * step
end

-- A path as one flat list, positions to a tenth of a stud and directions to a hundredth: small
-- enough to keep five in a saved wallet.
function Highlight.pack(samples: { Sample }, first: number?, last: number?): { number }
	local flat = {}
	for index = first or 1, math.min(last or #samples, (first or 1) + Highlight.MAX_SAMPLES - 1) do
		local s = samples[index]
		table.insert(flat, round(s[1], 0.1))
		table.insert(flat, round(s[2], 0.1))
		table.insert(flat, round(s[3], 0.1))
		table.insert(flat, round(s[4], 0.01))
		table.insert(flat, round(s[5], 0.01))
		table.insert(flat, round(s[6], 0.01))
	end
	return flat
end

-- Back to samples, or nil for anything that is not a packed path.
function Highlight.unpack(flat: any): { Sample }?
	if typeof(flat) ~= "table" or #flat == 0 or #flat % 6 ~= 0 then
		return nil
	end
	if #flat / 6 > Highlight.MAX_SAMPLES then
		return nil
	end
	local samples: { Sample } = {}
	for index = 1, #flat, 6 do
		local sample = {}
		for offset = 0, 5 do
			local value = flat[index + offset]
			if typeof(value) ~= "number" or value ~= value or math.abs(value) > 1e5 then
				return nil
			end
			sample[offset + 1] = value
		end
		table.insert(samples, sample)
	end
	return samples
end

return Highlight
