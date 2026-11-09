--!strict
-- The sound bank. 0 means "no asset": playback fails inert, gameplay never depends on a sound.
-- These are TEMPORARY stand-ins from the Creator Store, so the systems can be heard in a playtest.
-- Each one loads in Studio and has a measured length, but nobody has judged how they sound yet.
-- Release needs a coherent, purpose-made set: see docs/05_STATUS.md.
return {
	Ambient = 136271631723876, -- "Fluorescent Light Hum"
	Hum = 9112889082, -- "Transformer Hum 1", 36 s
	Step = 122104581168480, -- single footstep
	LensUp = 74763356170409, -- "camcorder_open", 0.65 s
	RecStart = 9119716019, -- "Switch Cassette Deck Dbx Buttons Clicks 7", 0.34 s
	TapeMotor = 9113678091, -- "Camera Motor Wind 7", 50 s
	Crowd = 9112844097, -- quiet crowd room tone
	RegistrarJump = 9125484526, -- deep hit, reverberant
	Reach = 79337190843902, -- horror drum hit
	-- Stand-in: the drum hit pitched down and played twice reads as a heartbeat. Replace with a real one.
	Heartbeat = 79337190843902,
	Cut = 9125484526,
	Knock = 9120918417, -- knock on a wooden door
	Radio = 9118026602, -- "Radio Static 1", 2.7 s
	Bell = 9114059243, -- desk bell
	Projector = 5270218400, -- "Film Projector sound short", 10 s
	Creak = 9114496277, -- floor creaks, reverberant room
	Drip = 9120533892, -- drip into a tin bucket
	ChairFold = 9114514078, -- folding chairs in a wooden room
	Paper = 9118835414, -- pages turned
	Wrong = 9120089728, -- "Toggle Switches Moviola Editing Machine 17", 0.36 s
	Music = 9043359270, -- "DARK DRONE 06", 69 s
	-- Picked 2026-11-07 by search and measured length only; nobody has listened yet. Spare for the
	-- lobby if the piano is wrong: 139053896078359 "Eerie Music Box", 83 s.
	LobbyMusic = 71416456879020, -- "Dark Ambient Piano", 171 s
	MissionBed = 99895453377463, -- "Existential Dread (Deep Dark Ambient Drone)", 238 s
} :: { [string]: number }
