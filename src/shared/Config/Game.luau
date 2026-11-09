--!strict
-- Every gameplay tunable. A balance pass is an edit to this file, never to a service.
return {
	Lens = {
		Fov = 52,
		NormalFov = 70,
		-- Half-angle of the cone that counts as "in frame": narrower than the screen on purpose,
		-- so the subject has to be in the picture, not in its corner.
		FramingHalfAngle = 24,
		FramingRange = 110,
		ReportHz = 5,
		StaleAfter = 1,
		MaxCameraDistanceFromHead = 14,
	},
	Tape = {
		PerPlayer = 3,
		MaxSeconds = 12,
		MinSeconds = 1,
		SampleHz = 10,
		MaxSamples = 130,
		MaxSpeed = 60,
		MaxStartDistance = 16,
		TargetRange = 90,
		GhostHz = 4,
		RegistrarStart = 45,
		RegistrarStep = 13,
		RegistrarMinimum = 5,
		MaxPlaySeconds = 20,
	},
	Registrar = {
		jumpInterval = 16,
		silenceLead = 2,
		registerTime = 6,
		contactRadius = 11,
		reachTime = 1.5,
		graceAfterCut = 22,
		StepSeconds = 0.25,
		AnchorHeight = 8,
		ClimaxScale = 0.45,
		WakeAfterSeconds = 360,
		WakeAfterReplays = 2,
		FalseSilenceChance = 0.12,
		FalseSilenceCheckEvery = 30,
		-- Seconds between two pulls by the same player's voice.
		VoiceCooldown = 8,
	},
	OffFrame = {
		RescueSeconds = 3,
		SelfReturnAfter = 30,
		SpliceRadius = 7,
		-- Must exceed SelfReturnAfter plus the walk back, or solo players can never recover.
		AllCutGrace = 75,
	},
	Puzzle = {
		WrongGuessesPerStep = 2,
		BellHoldSeconds = 3,
		PromptDistance = 7,
		SeatPromptDistance = 5.5,
		DoorCloseUpRadius = 7,
	},
	RoomTone = { MinGap = 22, MaxGap = 55, Volume = 0.45 },
	Session = {
		WaitForPartySeconds = 25,
		DevStartDelay = 2,
		EndTapeSeconds = 40,
		AutosaveSeconds = 180,
	},
	Party = {
		CountdownSeconds = 5,
		TeleportRetries = 3,
		RejoinTtlSeconds = 1800,
	},
	Rates = {
		-- { per second, burst }
		Lens = { 12, 16 },
		Record = { 1, 3 },
		Play = { 1, 2 },
		Comms = { 1, 3 },
		Flashlight = { 3, 4 },
		Party = { 5, 8 },
		Prompt = { 3, 5 },
	},
}
