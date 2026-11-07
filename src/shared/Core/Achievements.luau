--!strict
-- Which achievements a finished expedition earns. Pure, so every rule can be pinned by a test.
local Achievements = {}

export type Result = {
	success: boolean,
	replays: number,
	playerReplays: number,
	wasCut: boolean,
	docsThisRun: number,
	take: number,
	teamSize: number,
	seconds: number,
}

Achievements.ALL = {
	"first_meeting",
	"no_second_viewing",
	"never_cut",
	"paperwork",
	"second_take",
	"third_take",
	"alone",
	"full_team",
	"quick_meeting",
}

Achievements.TOTAL_DOCS_IN_MISSION = 6
Achievements.QUICK_SECONDS = 720

function Achievements.earned(result: Result): { string }
	local earned: { string } = {}
	if not result.success then
		return earned
	end
	table.insert(earned, "first_meeting")
	-- One team-wide viewing is the minimum the puzzle allows; more than that was a choice.
	if result.replays <= 2 then
		table.insert(earned, "no_second_viewing")
	end
	if not result.wasCut then
		table.insert(earned, "never_cut")
	end
	if result.docsThisRun >= Achievements.TOTAL_DOCS_IN_MISSION then
		table.insert(earned, "paperwork")
	end
	if result.take >= 2 then
		table.insert(earned, "second_take")
	end
	if result.take >= 3 then
		table.insert(earned, "third_take")
	end
	if result.teamSize == 1 then
		table.insert(earned, "alone")
	elseif result.teamSize >= 4 then
		table.insert(earned, "full_team")
	end
	if result.seconds <= Achievements.QUICK_SECONDS then
		table.insert(earned, "quick_meeting")
	end
	return earned
end

return Achievements
