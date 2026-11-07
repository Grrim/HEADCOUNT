--!strict
-- A tape is data, never pixels: a camera path plus the state of the world when it was shot.
-- Playback renders the live world along that path.
local Framing = require("./Framing")

local Tape = {}

export type Sample = { number } -- { x, y, z, lx, ly, lz }
export type Limits = {
	maxSamples: number,
	sampleHz: number,
	maxSpeed: number,
	maxStartDistance: number,
}

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value :: number) < 1e6
end

-- Everything here came from a client, so it is treated as hostile: wrong shapes are refused,
-- teleporting camera paths are refused, and a path must begin near the player who shot it.
function Tape.sanitize(
	raw: unknown,
	limits: Limits,
	startX: number,
	startY: number,
	startZ: number
): ({ Sample }?, string?)
	if typeof(raw) ~= "table" then
		return nil, "not_table"
	end
	local list = raw :: { unknown }
	local count = #list
	if count < 2 then
		return nil, "too_short"
	end
	if count > limits.maxSamples then
		return nil, "too_long"
	end
	local clean: { Sample } = table.create(count)
	local maxStep = limits.maxSpeed / limits.sampleHz
	for index = 1, count do
		local entry = list[index]
		if typeof(entry) ~= "table" then
			return nil, "bad_sample"
		end
		local values = entry :: { unknown }
		for field = 1, 6 do
			if not isFiniteNumber(values[field]) then
				return nil, "bad_number"
			end
		end
		local x, y, z = values[1] :: number, values[2] :: number, values[3] :: number
		local lx, ly, lz = values[4] :: number, values[5] :: number, values[6] :: number
		local length = math.sqrt(lx * lx + ly * ly + lz * lz)
		if length < 0.5 or length > 1.5 then
			return nil, "bad_look"
		end
		if index == 1 then
			local dx, dy, dz = x - startX, y - startY, z - startZ
			if math.sqrt(dx * dx + dy * dy + dz * dz) > limits.maxStartDistance then
				return nil, "far_start"
			end
		else
			local previous = clean[index - 1]
			local dx, dy, dz = x - previous[1], y - previous[2], z - previous[3]
			if math.sqrt(dx * dx + dy * dy + dz * dz) > maxStep then
				return nil, "too_fast"
			end
		end
		clean[index] = { x, y, z, lx / length, ly / length, lz / length }
	end
	return clean, nil
end

-- Camera position and look at time t, blended between samples. Past the end it holds the last frame.
function Tape.sampleAt(track: { Sample }, t: number, hz: number): Sample
	local position = math.max(t, 0) * hz + 1
	local index = math.floor(position)
	if index >= #track then
		return track[#track]
	end
	local alpha = position - index
	local a, b = track[index], track[index + 1]
	local out = table.create(6)
	for field = 1, 6 do
		out[field] = a[field] + (b[field] - a[field]) * alpha
	end
	return out
end

function Tape.duration(track: { Sample }, hz: number): number
	return (#track - 1) / hz
end

-- Which world points does any frame of this tape contain? The server uses this so a player only
-- learns the turned-around attendees they actually filmed.
function Tape.framedPoints(
	track: { Sample },
	points: { { number } },
	cosHalfFov: number,
	maxDistance: number
): { number }
	local found: { number } = {}
	for pointIndex, point in points do
		for _, sample in track do
			if
				Framing.isFramed(
					sample[1],
					sample[2],
					sample[3],
					sample[4],
					sample[5],
					sample[6],
					point[1],
					point[2],
					point[3],
					cosHalfFov,
					maxDistance
				)
			then
				table.insert(found, pointIndex)
				break
			end
		end
	end
	return found
end

-- How far in front of the lens the Registrar stands on this replay of a tape. He is absent on the
-- first viewing, then each viewing brings him closer until he fills the frame.
function Tape.registrarDistance(
	replays: number,
	start: number,
	step: number,
	minimum: number
): number?
	if replays <= 1 then
		return nil
	end
	return math.max(minimum, start - (replays - 2) * step)
end

return Tape
