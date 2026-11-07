--!strict
-- Fill in after the experience is published (Creator Hub > Places). 0 means "not published":
-- the hub then reports that teleporting is unavailable instead of failing silently.
return {
	HUB = 0,
	MISSIONS = {
		M001 = 0,
	} :: { [string]: number },
}
