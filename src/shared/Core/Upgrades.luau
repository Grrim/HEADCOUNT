--!strict
-- Camera upgrades bought with Frames between shifts. Each has a few levels and a hard cap: an
-- upgrade changes how a shift plays, it never makes a player safe. Level 1 is what everyone has.
--
-- The tripod (docs/09_GDD_V2.md §5) starts at nothing: its first level is bought. Set down, it
-- holds whatever it frames for that many seconds, once a floor. It is the solo player's way to
-- keep the Registrar still with nobody else to film him, so alone it costs less (§7, §13).
--
-- Every other piece of kit pays for itself in some way, so none of them is simply better:
--   lens    zoom: shots rate as if taken closer, but the frame (what the lens holds still) narrows
--   night   night vision through the lens on dark floors, and the battery drains faster for it
--   torch   a longer, brighter beam, which the Usher also notices from farther away
local Upgrades = {}

export type Upgrade = {
	id: string,
	name: string,
	values: { number },
	costs: { number },
	soloCosts: { number }?,
}

Upgrades.LIST = {
	{ id = "battery", name = "Battery", values = { 30, 40, 52, 66 }, costs = { 60, 140, 260 } },
	{ id = "tapes", name = "Tapes", values = { 3, 4, 5, 6 }, costs = { 80, 180, 320 } },
	{
		id = "tripod",
		name = "Tripod",
		values = { 0, 12, 20, 30 },
		costs = { 120, 220, 380 },
		soloCosts = { 60, 140, 260 },
	},
	{ id = "lens", name = "Lens", values = { 1, 1.25, 1.5, 1.8 }, costs = { 100, 200, 340 } },
	{ id = "night", name = "Night vision", values = { 0, 1, 2, 3 }, costs = { 90, 180, 300 } },
	{ id = "torch", name = "Torch", values = { 40, 55, 70, 85 }, costs = { 50, 120, 220 } },
} :: { Upgrade }

-- How far the Usher notices a lit torch of this range (16 studs for the standard torch).
function Upgrades.torchNotice(range: number): number
	return 16 + math.max(0, range - 40) / 5
end

-- Battery drained per second of raised lens with this much night vision.
function Upgrades.drain(night: number): number
	return 1 + 0.1 * math.max(0, night)
end

-- The lens's framing half-angle at this zoom: a longer lens holds a narrower cone.
function Upgrades.halfAngle(base: number, zoom: number): number
	return base / math.max(1, zoom)
end

local function find(id: string): Upgrade?
	for _, upgrade in Upgrades.LIST do
		if upgrade.id == id then
			return upgrade
		end
	end
	return nil
end

function Upgrades.level(levels: { [string]: number }, id: string): number
	return levels[id] or 1
end

function Upgrades.value(levels: { [string]: number }, id: string): number
	local upgrade = find(id)
	assert(upgrade, `unknown upgrade {id}`)
	return upgrade.values[math.clamp(Upgrades.level(levels, id), 1, #upgrade.values)]
end

-- The price of the next level, or nil at the top (or for an unknown id). `solo` asks for the
-- price a player alone on the server pays.
function Upgrades.nextCost(levels: { [string]: number }, id: string, solo: boolean?): number?
	local upgrade = find(id)
	if not upgrade then
		return nil
	end
	local costs = if solo and upgrade.soloCosts then upgrade.soloCosts else upgrade.costs
	return costs[Upgrades.level(levels, id)]
end

-- Buys one level if it exists and is affordable. Returns whether it did and the money left.
function Upgrades.buy(
	levels: { [string]: number },
	money: number,
	id: string,
	solo: boolean?
): (boolean, number)
	local cost = Upgrades.nextCost(levels, id, solo)
	if cost == nil or money < cost then
		return false, money
	end
	levels[id] = Upgrades.level(levels, id) + 1
	return true, money - cost
end

return Upgrades
