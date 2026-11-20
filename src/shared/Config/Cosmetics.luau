--!strict
-- Viewfinder frame colours: visible only to their owner, no effect on play. Free ones are open to
-- all; the rest come from achievements, never from paying for an advantage.
--
-- PassFrames come from the Biuro Pass (Config/Pass) and are kept in the shift's saved wallet, so
-- they are chosen on the shift's pay screen, not at the lobby locker.
return {
	PassFrames = {
		{ id = "bureau", name = "Bureau Grey", color = Color3.fromRGB(150, 156, 160) },
		{ id = "tapehead", name = "Tape Head", color = Color3.fromRGB(120, 92, 70) },
		{ id = "deep", name = "Deep", color = Color3.fromRGB(70, 40, 120) },
		{ id = "ledger", name = "Ledger Green", color = Color3.fromRGB(46, 120, 84) },
		{ id = "sodium", name = "Sodium", color = Color3.fromRGB(255, 150, 40) },
		{ id = "curtain", name = "Curtain", color = Color3.fromRGB(150, 30, 46) },
		{ id = "static", name = "Static", color = Color3.fromRGB(200, 210, 220) },
		{ id = "jutrzenka", name = "Jutrzenka", color = Color3.fromRGB(240, 200, 120) },
		{ id = "neon", name = "Exit Sign", color = Color3.fromRGB(60, 255, 120) },
		{ id = "minus13", name = "-13", color = Color3.fromRGB(255, 40, 40) },
		{ id = "gold", name = "Commendation Gold", color = Color3.fromRGB(230, 190, 60) },
	},
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
