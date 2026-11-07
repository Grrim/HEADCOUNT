--!strict
-- Token bucket keyed by anything. Time is passed in, which makes the rule testable.
local RateLimit = {}
RateLimit.__index = RateLimit

export type RateLimit = typeof(setmetatable(
	{} :: { rate: number, burst: number, buckets: { [any]: { tokens: number, at: number } } },
	RateLimit
))

function RateLimit.new(ratePerSecond: number, burst: number): RateLimit
	return setmetatable({ rate = ratePerSecond, burst = burst, buckets = {} }, RateLimit)
end

function RateLimit.allow(self: RateLimit, key: any, now: number): boolean
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.burst, at = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.at) * self.rate)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimit.forget(self: RateLimit, key: any)
	self.buckets[key] = nil
end

return RateLimit
