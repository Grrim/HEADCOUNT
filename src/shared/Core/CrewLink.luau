--!strict
-- One crew lift shared by every lobby server (docs/09_GDD_V2.md §7), as plain data. A ticket is
-- kept in MemoryStore by HubLifts: the reserved shift server the crew will meet on, when it
-- leaves, and how many seats each lobby server holds for the riders in its own cabin.
--
--   * the first rider in an empty cabin joins the oldest open ticket with room, else opens one
--   * a lobby holds as many seats as it has riders, never more than the ticket has free
--   * full, it closes at once; "Leave now" from any lobby on it closes it too
--   * the first lobby to see the time run out closes it, so lobbies whose clocks differ a little
--     still leave within a second of each other
--   * once closed nothing changes on it, and every lobby sends its riders to the ticket's
--     reserved server, together
--
-- Times are Unix seconds (os.time).
local CrewLink = {}

export type Ticket = {
	id: string,
	created: number,
	departAt: number,
	closed: boolean,
	seats: { [string]: number },
}

-- How long a ticket stays in the store after it leaves, so slow lobbies still see it leave.
CrewLink.LINGER = 30

function CrewLink.total(ticket: Ticket): number
	local sum = 0
	for _, count in ticket.seats do
		sum += count
	end
	return sum
end

function CrewLink.due(ticket: Ticket, now: number): boolean
	return ticket.closed or now >= ticket.departAt
end

function CrewLink.secondsLeft(ticket: Ticket, now: number): number
	return if ticket.closed then 0 else math.max(0, ticket.departAt - now)
end

-- Worth joining: open, not leaving within `margin` seconds, and a seat left.
function CrewLink.joinable(ticket: Ticket, now: number, capacity: number, margin: number): boolean
	return not ticket.closed
		and ticket.departAt - now >= margin
		and CrewLink.total(ticket) < capacity
end

function CrewLink.close(ticket: Ticket, now: number)
	ticket.closed = true
	ticket.departAt = math.min(ticket.departAt, now)
end

-- Holds `wanted` seats for this lobby, as many as are free; a closed ticket changes no more.
-- A full ticket closes at once. Returns the seats this lobby holds afterwards.
function CrewLink.setSeats(
	ticket: Ticket,
	lobby: string,
	wanted: number,
	now: number,
	capacity: number
): number
	if ticket.closed then
		return ticket.seats[lobby] or 0
	end
	local others = CrewLink.total(ticket) - (ticket.seats[lobby] or 0)
	local granted = math.clamp(math.floor(wanted), 0, math.max(0, capacity - others))
	ticket.seats[lobby] = if granted > 0 then granted else nil
	if CrewLink.total(ticket) >= capacity then
		CrewLink.close(ticket, now)
	end
	return granted
end

function CrewLink.open(
	id: string,
	lobby: string,
	wanted: number,
	now: number,
	wait: number,
	capacity: number
): (Ticket, number)
	local ticket: Ticket =
		{ id = id, created = now, departAt = now + wait, closed = false, seats = {} }
	local granted = CrewLink.setSeats(ticket, lobby, wanted, now, capacity)
	return ticket, granted
end

function CrewLink.goNow(ticket: Ticket, now: number)
	if not ticket.closed then
		CrewLink.close(ticket, now)
	end
end

-- Is this lobby the only one holding seats on the ticket?
function CrewLink.alone(ticket: Ticket, lobby: string): boolean
	for other in ticket.seats do
		if other ~= lobby then
			return false
		end
	end
	return true
end

-- How long the store should keep the ticket from now on.
function CrewLink.ttl(ticket: Ticket, now: number): number
	return math.max(0, ticket.departAt - now) + CrewLink.LINGER
end

-- The MemoryStore key: oldest first when listed in ascending order.
function CrewLink.key(ticket: Ticket): string
	return string.format("%012d_%s", ticket.created, ticket.id)
end

-- Keys after this one belong to tickets opened recently enough to still take riders: anything
-- opened `wait - margin` seconds ago or earlier is leaving or gone.
function CrewLink.freshAfter(now: number, wait: number, margin: number): string
	return string.format("%012d", now - (wait - margin) - 1)
end

-- A ticket from the store, or nil when it is not one.
function CrewLink.read(raw: any): Ticket?
	if typeof(raw) ~= "table" then
		return nil
	end
	if
		typeof(raw.id) ~= "string"
		or typeof(raw.created) ~= "number"
		or typeof(raw.departAt) ~= "number"
		or typeof(raw.seats) ~= "table"
	then
		return nil
	end
	local seats: { [string]: number } = {}
	for lobby, count in raw.seats do
		if typeof(lobby) == "string" and typeof(count) == "number" and count > 0 then
			seats[lobby] = math.floor(count)
		end
	end
	return {
		id = raw.id,
		created = raw.created,
		departAt = raw.departAt,
		closed = raw.closed == true,
		seats = seats,
	}
end

return CrewLink
