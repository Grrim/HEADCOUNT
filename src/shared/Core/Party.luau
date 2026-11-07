--!strict
-- Expedition parties, as plain data keyed by UserId. The Hub service owns one Registry.
local Party = {}

Party.MAX_MEMBERS = 4

export type Party = {
	id: number,
	missionId: string,
	leader: number,
	members: { number },
	ready: { [number]: boolean },
	starting: boolean,
}

export type Registry = {
	parties: { [number]: Party },
	byUser: { [number]: number },
	nextId: number,
}

function Party.newRegistry(): Registry
	return { parties = {}, byUser = {}, nextId = 1 }
end

function Party.of(registry: Registry, userId: number): Party?
	local id = registry.byUser[userId]
	return if id then registry.parties[id] else nil
end

function Party.create(registry: Registry, userId: number, missionId: string): (Party?, string?)
	if registry.byUser[userId] then
		return nil, "already_in_party"
	end
	local id = registry.nextId
	registry.nextId += 1
	local party: Party = {
		id = id,
		missionId = missionId,
		leader = userId,
		members = { userId },
		ready = {},
		starting = false,
	}
	registry.parties[id] = party
	registry.byUser[userId] = id
	return party, nil
end

function Party.join(registry: Registry, userId: number, partyId: number): (boolean, string?)
	if registry.byUser[userId] then
		return false, "already_in_party"
	end
	local party = registry.parties[partyId]
	if not party then
		return false, "no_such_party"
	end
	if party.starting then
		return false, "party_starting"
	end
	if #party.members >= Party.MAX_MEMBERS then
		return false, "party_full"
	end
	table.insert(party.members, userId)
	registry.byUser[userId] = partyId
	return true, nil
end

-- Leaving cancels a countdown, hands the lead to the next member and removes an empty party.
function Party.leave(registry: Registry, userId: number): Party?
	local party = Party.of(registry, userId)
	if not party then
		return nil
	end
	registry.byUser[userId] = nil
	party.ready[userId] = nil
	party.starting = false
	local index = table.find(party.members, userId)
	if index then
		table.remove(party.members, index)
	end
	if #party.members == 0 then
		registry.parties[party.id] = nil
		return nil
	end
	if party.leader == userId then
		party.leader = party.members[1]
	end
	return party
end

function Party.setReady(registry: Registry, userId: number, ready: boolean): boolean
	local party = Party.of(registry, userId)
	if not party then
		return false
	end
	party.ready[userId] = ready or nil
	if not ready then
		party.starting = false
	end
	return true
end

function Party.kick(registry: Registry, leaderId: number, targetId: number): (boolean, string?)
	local party = Party.of(registry, leaderId)
	if not party or party.leader ~= leaderId then
		return false, "not_leader"
	end
	if targetId == leaderId or not table.find(party.members, targetId) then
		return false, "bad_target"
	end
	Party.leave(registry, targetId)
	return true, nil
end

function Party.canStart(registry: Registry, userId: number): (boolean, string?)
	local party = Party.of(registry, userId)
	if not party then
		return false, "no_party"
	end
	if party.leader ~= userId then
		return false, "not_leader"
	end
	if party.starting then
		return false, "party_starting"
	end
	for _, member in party.members do
		if not party.ready[member] then
			return false, "not_all_ready"
		end
	end
	return true, nil
end

return Party
