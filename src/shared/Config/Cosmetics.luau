--!strict
-- Viewfinder frame colours: visible only to their owner, no effect on play. Free ones are open to
-- all; the rest come from achievements, never from paying for an advantage.
return {
	Frames = {
		{ id = "paper", color = Color3.fromRGB(214, 206, 186), nameKey = "frame_paper" },
		{ id = "crt", color = Color3.fromRGB(182, 214, 150), nameKey = "frame_crt" },
		{ id = "amber", color = Color3.fromRGB(255, 176, 74), nameKey = "frame_amber" },
		{
			id = "red",
			color = Color3.fromRGB(217, 52, 43),
			nameKey = "frame_red",
			requires = "second_take",
		},
		{
			id = "white",
			color = Color3.fromRGB(240, 240, 240),
			nameKey = "frame_white",
			requires = "never_cut",
		},
	},
}
