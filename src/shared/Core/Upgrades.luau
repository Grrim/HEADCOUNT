--!strict
-- Camera upgrades bought with Frames between shifts. Each has a few levels and a hard cap: an
-- upgrade changes how a shift plays, it never makes a player safe. Level 1 is what everyone has.
local Upgrades = {}

export type Upgrade = { id: string, name: string, values: { number }, costs: { number } }

Upgrades.LIST = {
	{ id = "battery", name = "Battery", values = { 30, 40, 52, 66 }, costs = { 60, 140, 260 } },
	{ id = "tapes", name = "Tapes", values = { 3, 4, 5, 6 }, costs = { 80, 180, 320 } },
}

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

-- The price of the next level, or nil at the top (or for an unknown id).
function Upgrades.nextCost(levels: { [string]: number }, id: string): number?
	local upgrade = find(id)
	if not upgrade then
		return nil
	end
	return upgrade.costs[Upgrades.level(levels, id)]
end

-- Buys one level if it exists and is affordable. Returns whether it did and the money left.
function Upgrades.buy(levels: { [string]: number }, money: number, id: string): (boolean, number)
	local cost = Upgrades.nextCost(levels, id)
	if cost == nil or money < cost then
		return false, money
	end
	levels[id] = Upgrades.level(levels, id) + 1
	return true, money - cost
end

return Upgrades
