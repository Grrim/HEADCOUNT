--!strict
-- The Stand-in (Mission 002): a player's own movement and button presses, played back a fixed
-- number of seconds late. Pure data, so the server can drive it and the tests can check it.
--   record(t, x, y, z, yaw)    a sample of where the player was at time t
--   act(t, name)               a button the player pressed at time t
--   at(now)                    where the stand-in is: the player's position at now - delay
--   actions(from, to)          presses the stand-in makes in (from, to], i.e. the player's
--                              presses in (from - delay, to - delay]
--   catches(now, x, z)         true when the stand-in steps where the player stands now
-- `now` is the present: the newest sample's time or later. Recording trims history relative to
-- the newest sample, so asking about an older moment can find nothing.
local StandIn = {}

export type Sample = { t: number, x: number, y: number, z: number, yaw: number }
export type Action = { t: number, name: string }
export type Buffer = {
	delay: number,
	-- How long history is kept beyond the delay, in seconds.
	keep: number,
	samples: { Sample },
	actions: { Action },
}

function StandIn.new(delay: number, keep: number?): Buffer
	return { delay = delay, keep = keep or 5, samples = {}, actions = {} }
end

-- Samples must arrive in time order; anything out of order is ignored rather than trusted.
function StandIn.record(buffer: Buffer, t: number, x: number, y: number, z: number, yaw: number)
	local last = buffer.samples[#buffer.samples]
	if last and t <= last.t then
		return
	end
	table.insert(buffer.samples, { t = t, x = x, y = y, z = z, yaw = yaw })
	StandIn.trim(buffer, t)
end

function StandIn.act(buffer: Buffer, t: number, name: string)
	table.insert(buffer.actions, { t = t, name = name })
end

-- Drops what the stand-in has already walked past, keeping one sample before the cut so that
-- interpolation still has a left neighbour.
function StandIn.trim(buffer: Buffer, now: number)
	local cutoff = now - buffer.delay - buffer.keep
	local samples = buffer.samples
	local drop = 0
	for index = 1, #samples - 1 do
		if samples[index + 1].t <= cutoff then
			drop = index
		else
			break
		end
	end
	if drop > 0 then
		table.move(samples, drop + 1, #samples, 1)
		for index = #samples - drop + 1, #samples do
			samples[index] = nil
		end
	end
	local actions = buffer.actions
	while actions[1] and actions[1].t <= cutoff do
		table.remove(actions, 1)
	end
end

-- Where the stand-in is at `now`, or nil before the player has been around for `delay` seconds.
function StandIn.at(buffer: Buffer, now: number): Sample?
	local t = now - buffer.delay
	local samples = buffer.samples
	if #samples == 0 or t < samples[1].t then
		return nil
	end
	for index = #samples, 1, -1 do
		local a = samples[index]
		if a.t <= t then
			local b = samples[index + 1]
			if not b then
				return { t = t, x = a.x, y = a.y, z = a.z, yaw = a.yaw }
			end
			local f = (t - a.t) / (b.t - a.t)
			return {
				t = t,
				x = a.x + (b.x - a.x) * f,
				y = a.y + (b.y - a.y) * f,
				z = a.z + (b.z - a.z) * f,
				-- Turns snap at the halfway point: a body does not blend between two headings.
				yaw = if f < 0.5 then a.yaw else b.yaw,
			}
		end
	end
	return nil
end

-- The presses the stand-in repeats in the window (from, to].
function StandIn.actions(buffer: Buffer, from: number, to: number): { string }
	local names = {}
	local lo, hi = from - buffer.delay, to - buffer.delay
	for _, action in buffer.actions do
		if action.t > lo and action.t <= hi then
			table.insert(names, action.name)
		end
	end
	return names
end

-- True when the stand-in is within `radius` of where the player stands now. It only counts once
-- the stand-in exists, and never at the very start, when the past is the present.
function StandIn.catches(buffer: Buffer, now: number, x: number, z: number, radius: number): boolean
	local ghost = StandIn.at(buffer, now)
	if not ghost then
		return false
	end
	local dx, dz = ghost.x - x, ghost.z - z
	return dx * dx + dz * dz <= radius * radius
end

return StandIn
