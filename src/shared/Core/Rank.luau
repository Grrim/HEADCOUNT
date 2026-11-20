--!strict
-- Rank (docs/09_GDD_V2.md §5, "stopień służbowy"): 1 to 50, earned with the same experience as the
-- Biuro Pass (footage brought back, quotas met, daily tasks) but for good, never reset by a season.
-- Rank opens the deeper floors and pays titles and viewfinder frames along the way.
--
-- Reaching rank r takes 50 * r * (r - 1) experience in all: rank 2 at 100, rank 10 at 4500,
-- rank 50 at 122 500. A shift brings back 100 to 300 footage, so the first ranks come quickly and
-- the last ones take a long while.
local Rank = {}

Rank.MAX = 50
-- The deepest floor each rank may ride down to. A crew rides with the highest rank aboard.
Rank.DEPTHS = {
	{ rank = 1, depth = 2 },
	{ rank = 3, depth = 3 },
	{ rank = 6, depth = 4 },
	{ rank = 10, depth = 5 },
}

export type Reward = { title: string?, frame: string? }

Rank.REWARDS = {
	[1] = { title = "Probationer" },
	[5] = { title = "Clerk" },
	[10] = { title = "Field Recorder" },
	[15] = { frame = "brass" },
	[20] = { title = "Night Archivist" },
	[30] = { frame = "silver" },
	[35] = { title = "Head of Continuity" },
	[50] = { title = "Bureau Legend", frame = "black" },
} :: { [number]: Reward }

function Rank.xpFor(rank: number): number
	local r = math.clamp(math.floor(rank), 1, Rank.MAX)
	return 50 * r * (r - 1)
end

function Rank.of(xp: number): number
	local rank = 1
	while rank < Rank.MAX and xp >= Rank.xpFor(rank + 1) do
		rank += 1
	end
	return rank
end

-- The rank, the experience into it, and how much the next rank takes from it (0 at the top).
function Rank.progress(xp: number): (number, number, number)
	local rank = Rank.of(xp)
	if rank >= Rank.MAX then
		return rank, 0, 0
	end
	local base = Rank.xpFor(rank)
	return rank, xp - base, Rank.xpFor(rank + 1) - base
end

function Rank.depthLimit(rank: number): number
	local depth = 1
	for _, step in Rank.DEPTHS do
		if rank >= step.rank then
			depth = step.depth
		end
	end
	return depth
end

-- The rank that opens a floor, or nil when no rank does.
function Rank.forDepth(depth: number): number?
	for _, step in Rank.DEPTHS do
		if step.depth >= depth then
			return step.rank
		end
	end
	return nil
end

-- The rewards of every rank above `from` up to and including `to`.
function Rank.rewardsBetween(from: number, to: number): { Reward }
	local list = {}
	for rank = from + 1, to do
		local reward = Rank.REWARDS[rank]
		if reward then
			table.insert(list, reward)
		end
	end
	return list
end

return Rank
