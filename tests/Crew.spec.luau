--!strict
-- The crew lift in the lobby: who is aboard, when it leaves.
local Crew = require("../src/shared/Core/Crew")

return {
	["the first one in starts the clock and it leaves when the wait is over"] = function()
		local crew = Crew.new(4, 30)
		assert(Crew.secondsLeft(crew, 0) == nil and not Crew.due(crew, 0))
		Crew.sync(crew, { 7 }, 100)
		assert(Crew.secondsLeft(crew, 110) == 20 and not Crew.due(crew, 110))
		Crew.sync(crew, { 7, 8 }, 120)
		assert(Crew.secondsLeft(crew, 120) == 10, "a newcomer restarted the clock")
		assert(Crew.due(crew, 130))
		local members = Crew.take(crew)
		assert(#members == 2 and members[1] == 7 and members[2] == 8)
		assert(#crew.members == 0 and crew.since == nil)
	end,

	["a full lift leaves at once and turns the fifth away"] = function()
		local crew = Crew.new(4, 30)
		local left = Crew.sync(crew, { 5, 4, 3, 2, 1 }, 0)
		assert(#crew.members == 4 and #left == 1 and left[1] == 5)
		assert(Crew.due(crew, 0))
	end,

	["stepping out takes you off, and an empty lift stops the clock"] = function()
		local crew = Crew.new(4, 30)
		Crew.sync(crew, { 1, 2 }, 0)
		Crew.sync(crew, { 2 }, 5)
		assert(#crew.members == 1 and crew.members[1] == 2)
		Crew.sync(crew, {}, 6)
		assert(crew.since == nil and not Crew.due(crew, 100))
		Crew.sync(crew, { 3 }, 200)
		assert(Crew.secondsLeft(crew, 200) == 30, "the clock kept running while empty")
	end,

	["only someone aboard can send it now"] = function()
		local crew = Crew.new(4, 30)
		Crew.sync(crew, { 1 }, 0)
		assert(not Crew.go(crew, 9) and not Crew.due(crew, 1))
		assert(Crew.go(crew, 1) and Crew.due(crew, 1))
		Crew.sync(crew, { 1, 2 }, 2)
		assert(Crew.due(crew, 2), "a newcomer cancelled GO")
		Crew.sync(crew, { 2 }, 3)
		assert(not Crew.due(crew, 3), "GO outlived the rider who pressed it")
	end,
}
