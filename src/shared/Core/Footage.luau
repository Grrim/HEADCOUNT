--!strict
-- How good a shot is, judged from the camera path alone (the server never sees pixels). For each
-- subject the path ever framed, stars come from holding it, getting close and keeping it central:
--
--   1 star   framed for at least 1 s
--   +1       framed for at least 2.5 s
--   +1       came within 25 studs while framing it
--   +1       came within 12 studs while framing it
--   +1       held it dead centre at least once
--
-- A shot is worth the subject's value times stars / 5. The team keeps its best shot of each
-- subject, so filming the same thing twice only pays the improvement.
local Framing = require("./Framing")

local Footage = {}

Footage.HOLD_SECONDS = 6
Footage.CENTRE_COS = math.cos(math.rad(8))

export type Target = { id: number, x: number, y: number, z: number, value: number }
export type Shot = {
	id: number,
	stars: number,
	value: number,
	seconds: number,
	distance: number,
}
-- Optional line-of-sight test; true means something solid stood between the lens and the subject.
export type Blocked = (sample: { number }, target: Target) -> boolean

function Footage.score(
	samples: { { number } },
	targets: { Target },
	sampleHz: number,
	cosHalfFov: number,
	range: number,
	blocked: Blocked?
): { Shot }
	local shots: { Shot } = {}
	for _, target in targets do
		local framed = 0
		local nearest = math.huge
		local centred = false
		for _, sample in samples do
			local x, y, z = sample[1], sample[2], sample[3]
			local lx, ly, lz = sample[4], sample[5], sample[6]
			if
				Framing.isFramed(x, y, z, lx, ly, lz, target.x, target.y, target.z, cosHalfFov, range)
				and not (blocked and blocked(sample, target))
			then
				framed += 1
				local dx, dy, dz = target.x - x, target.y - y, target.z - z
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				nearest = math.min(nearest, distance)
				if distance > 0.001 and (dx * lx + dy * ly + dz * lz) / distance >= Footage.CENTRE_COS then
					centred = true
				end
			end
		end
		local seconds = math.min(framed / sampleHz, Footage.HOLD_SECONDS)
		if seconds >= 1 then
			local stars = 1
			if seconds >= 2.5 then
				stars += 1
			end
			if nearest <= 25 then
				stars += 1
			end
			if nearest <= 12 then
				stars += 1
			end
			if centred then
				stars += 1
			end
			table.insert(shots, {
				id = target.id,
				stars = stars,
				value = math.floor(target.value * stars / 5 + 0.5),
				seconds = seconds,
				distance = nearest,
			})
		end
	end
	table.sort(shots, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.id < b.id
	end)
	return shots
end

-- Keeps the best value per subject in `best` and returns what these shots add over it, with the
-- shots that improved on something.
function Footage.improve(best: { [number]: number }, shots: { Shot }): (number, { Shot })
	local gain = 0
	local improved: { Shot } = {}
	for _, shot in shots do
		local previous = best[shot.id] or 0
		if shot.value > previous then
			gain += shot.value - previous
			best[shot.id] = shot.value
			table.insert(improved, shot)
		end
	end
	return gain, improved
end

return Footage
