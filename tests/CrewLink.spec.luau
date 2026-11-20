--!strict
-- The crew lift shared between lobby servers.
local CrewLink = require("../src/shared/Core/CrewLink")

return {
	["two lobbies fill one lift, and a full lift leaves at once"] = function()
		local ticket, first = CrewLink.open("srv", "lobbyA", 2, 1000, 30, 4)
		assert(first == 2 and ticket.departAt == 1030 and not CrewLink.due(ticket, 1010))
		assert(CrewLink.joinable(ticket, 1010, 4, 5))
		local second = CrewLink.setSeats(ticket, "lobbyB", 3, 1012, 4)
		assert(second == 2, `granted {second}: only two seats were free`)
		assert(CrewLink.total(ticket) == 4 and CrewLink.due(ticket, 1012))
		assert(not CrewLink.joinable(ticket, 1012, 4, 5))
	end,

	["a lobby gives seats back as riders step out"] = function()
		local ticket = CrewLink.open("srv", "lobbyA", 3, 0, 30, 4)
		CrewLink.setSeats(ticket, "lobbyA", 1, 5, 4)
		assert(CrewLink.total(ticket) == 1)
		CrewLink.setSeats(ticket, "lobbyA", 0, 6, 4)
		assert(CrewLink.total(ticket) == 0 and ticket.seats.lobbyA == nil)
		assert(not CrewLink.due(ticket, 6), "an emptied lift left")
	end,

	["a lift about to leave is not offered to newcomers"] = function()
		local ticket = CrewLink.open("srv", "lobbyA", 1, 0, 30, 4)
		assert(CrewLink.joinable(ticket, 20, 4, 5))
		assert(not CrewLink.joinable(ticket, 26, 4, 5))
	end,

	["leave now sends the whole shared lift"] = function()
		local ticket = CrewLink.open("srv", "lobbyA", 1, 0, 30, 4)
		CrewLink.setSeats(ticket, "lobbyB", 1, 3, 4)
		CrewLink.goNow(ticket, 8)
		assert(CrewLink.due(ticket, 8) and CrewLink.secondsLeft(ticket, 8) == 0)
	end,

	["keys list the oldest ticket first, and junk is not a ticket"] = function()
		local old = CrewLink.open("b", "x", 1, 999, 30, 4)
		local new = CrewLink.open("a", "x", 1, 1000, 30, 4)
		assert(CrewLink.key(old) < CrewLink.key(new))
		assert(CrewLink.read(nil) == nil and CrewLink.read({ id = 1 }) == nil)
		local back =
			CrewLink.read({ id = "s", created = 1, departAt = 2, seats = { a = 2, b = -1 } })
		assert(back and back.seats.a == 2 and back.seats.b == nil)
	end,

	["a closed ticket takes no more seats and gives none back"] = function()
		local ticket = CrewLink.open("srv", "a", 2, 0, 30, 4)
		CrewLink.goNow(ticket, 5)
		assert(ticket.closed and CrewLink.due(ticket, 5))
		assert(CrewLink.setSeats(ticket, "b", 2, 6, 4) == 0, "a late lobby boarded a closed lift")
		assert(CrewLink.setSeats(ticket, "a", 0, 6, 4) == 2, "seats changed after it closed")
		assert(not CrewLink.joinable(ticket, 6, 4, 5))
	end,

	["a closed flag decides, whatever a lobby's clock says"] = function()
		local ticket = CrewLink.open("srv", "a", 4, 100, 30, 4)
		assert(ticket.closed, "a full lift stayed open")
		-- A lobby whose clock runs behind still sees it gone.
		assert(CrewLink.due(ticket, 90) and CrewLink.secondsLeft(ticket, 90) == 0)
		local stored =
			CrewLink.read({ id = "s", created = 1, departAt = 99, closed = true, seats = {} })
		assert(stored and stored.closed)
	end,

	["only recent tickets are listed, and a lone lobby knows it is alone"] = function()
		local now = 1000
		local bound = CrewLink.freshAfter(now, 30, 5)
		local recent = CrewLink.open("r", "a", 1, now - 20, 30, 4)
		local stale = CrewLink.open("s", "a", 1, now - 30, 30, 4)
		assert(CrewLink.key(recent) > bound and CrewLink.key(stale) < bound)
		assert(CrewLink.alone(recent, "a") and not CrewLink.alone(recent, "b"))
		CrewLink.setSeats(recent, "b", 1, now, 4)
		assert(not CrewLink.alone(recent, "a"))
		assert(CrewLink.ttl(recent, now) == 10 + CrewLink.LINGER)
	end,
}
