--!strict
-- Deterministic generator (MINSTD). The server and tests get identical sequences from one seed,
-- which makes a puzzle reproducible from a bug report.
local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

local MODULUS = 2147483647

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % MODULUS
	if state == 0 then
		state = 1
	end
	return setmetatable({ state = state }, Rng)
end

function Rng.next(self: Rng): number
	self.state = (self.state * 48271) % MODULUS
	return self.state
end

-- Inclusive on both ends.
function Rng.int(self: Rng, low: number, high: number): number
	return low + self:next() % (high - low + 1)
end

return Rng
