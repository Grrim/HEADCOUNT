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
		-- After any move, even an unsignalled pull, he waits this long before he may reach.
		arrivalGrace = 1.2,
		-- Exposure drains at this rate while nobody frames him, so a few honest looks over the
		-- mission never add up to a registration; only a long stare does.
		exposureDecay = 0.4,
		-- Extra reach time for a player caught watching a tape: they must stop it and look up.
		WatchingReachBonus = 1.2,
		StepSeconds = 0.25,
		AnchorHeight = 8,
		ClimaxScale = 0.45,
		WakeAfterSeconds = 360,
		WakeAfterReplays = 2,
		-- After the power cut wakes him on a first visit, the first move comes no sooner than this.
		WakeGraceSeconds = 28,
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
	-- The shift prototype (docs/09_GDD_V2.md, §2). Starting values, to be tuned on playtests.
	Shift = {
		RideSeconds = 12,
		ReturnSeconds = 8,
		DoorCloseSeconds = 4,
		DoorOpenSeconds = 1.5,
		-- The Registrar sleeps this long after the doors open, so the floor can be looked at first.
		WakeFirstFloor = 25,
		WakeDeeper = 12,
		-- Each floor down he jumps this much more often (0.15 = 15% shorter waits per floor).
		HastePerFloor = 0.15,
		-- Alone, he waits this much longer between jumps.
		SoloSlower = 1.25,
		RecordSeconds = 10,
		-- Battery recharge per second while lowered, and the multiplier inside the lift.
		Recharge = 1,
		LiftRecharge = 3,
		-- An empty battery comes back only once it holds this share of its capacity.
		BatteryResume = 0.2,
		RescueSeconds = 3,
		SelfReturnAfter = 30,
		AllCutGrace = 75,
		-- What a five-star shot of each kind of anomaly is worth, before the floor's multiplier.
		-- "legendary" is the Extra, filmed until it is gone: the best shot in the game.
		Values = { common = 10, rare = 25, epic = 60, legendary = 90 },
		-- Height of the point the lens has to hold, above the floor.
		TargetHeight = 3.5,

		-- Tapes: the first viewing on a floor is free, every later one pulls the Registrar a node
		-- closer to the viewer. Someone watching a tape gets this much longer before he reaches.
		PlaybackReachBonus = 2,
		-- Code doors: wrong codes in a row before the keypad jams, and for how long.
		CodeTries = 3,
		CodeJamSeconds = 8,
		-- How close the lens has to be for a tape to show a door's code.
		CodeReadRange = 40,

		-- The Extra (docs/09_GDD_V2.md §2.3): from this floor down, waking this long after the
		-- doors open. When the team rides on with it still unfilmed, it boards with this chance.
		ExtraFromDepth = 2,
		ExtraWake = 20,
		ExtraBoardChance = 0.5,
		Extra = {
			speed = 9,
			lureDistance = 22,
			lureSeconds = 35,
			touchRadius = 3.2,
			revealRange = 20,
			revealSeconds = 2,
			revealDecay = 0.5,
			graceAfterCut = 15,
		},

		-- The Usher walks the dark floors and sees only torchlight.
		UsherFromDepth = 3,
		UsherWake = 30,

		-- The saved wallet: how long a lock lasts without a refresh, and how often it is refreshed.
		LockTtl = 150,
		AutosaveSeconds = 45,
	},
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
