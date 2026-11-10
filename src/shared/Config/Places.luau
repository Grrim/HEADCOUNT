--!strict
-- Fill in after the experience is published (Creator Hub > Places). 0 means "not published":
-- the hub then reports that teleporting is unavailable instead of failing silently.
return {
	-- Test experience, universe 10775647200, first published 2026-11-10.
	HUB = 77620606106061,
	MISSIONS = {
		M001 = 102362153460645,
	} :: { [string]: number },
}
