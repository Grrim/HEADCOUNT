--!strict
-- A "take" is a recognisably different version of the mission, chosen by prior completions.
local Take = {}

export type Take = {
	number: number,
	briefKey: string,
	registrarStart: string,
	jumpScale: number,
	reverseEveryNthRow: number?,
	liveLensHidesAudience: boolean,
}

function Take.forCompletions(completions: number): Take
	local number = math.max(0, math.floor(completions)) + 1
	if number == 1 then
		return {
			number = 1,
			briefKey = "brief_take1",
			registrarStart = "archive",
			jumpScale = 1,
			reverseEveryNthRow = nil,
			liveLensHidesAudience = false,
		}
	elseif number == 2 then
		return {
			number = 2,
			briefKey = "brief_take2",
			registrarStart = "stage",
			jumpScale = 0.85,
			reverseEveryNthRow = 4,
			liveLensHidesAudience = false,
		}
	end
	return {
		number = number,
		briefKey = "brief_take3",
		registrarStart = "aisleRear",
		jumpScale = 0.7,
		reverseEveryNthRow = 4,
		liveLensHidesAudience = true,
	}
end

-- The Registrar's pace also depends on team size: a solo player cannot watch and walk at once.
function Take.partyScale(playerCount: number): number
	if playerCount <= 1 then
		return 1.5
	elseif playerCount == 2 then
		return 1.15
	end
	return 1
end

return Take
