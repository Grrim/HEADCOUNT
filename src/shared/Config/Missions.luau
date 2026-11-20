--!strict
-- The mission catalogue. Adding a mission is a data edit here plus a new place.
-- `open` entries need no unlock in the player's progress.
return {
	{
		id = "SHIFT",
		titleKey = "shift_title",
		summaryKey = "shift_summary",
		metaKey = "shift_meta",
		available = true,
		open = true,
	},
	{
		id = "M001",
		titleKey = "m001_title",
		summaryKey = "m001_summary",
		metaKey = "m001_meta",
		available = true,
	},
	{ id = "M002", titleKey = "m002_title", summaryKey = "m002_summary", available = false },
}
