--!strict
-- Camera upgrades bought with Frames between shifts. Each has a few levels and a hard cap: an
-- upgrade changes how a shift plays, it never makes a player safe. Level 1 is what everyone has.
--
-- The tripod (docs/09_GDD_V2.md §5) starts at nothing: its first level is bought. Set down, it
-- holds whatever it frames for that many seconds, once a floor. It is the solo player's way to
-- keep the Registrar still with nobody else to film him, so alone it costs less (§7, §13).
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
} :: { Upgrade }

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
