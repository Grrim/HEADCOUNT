--!strict
-- The sound bank. 0 means "no asset": playback fails inert, gameplay never depends on a sound.
-- These are TEMPORARY stand-ins from the Creator Store, so the systems can be heard in a playtest.
-- Release needs a coherent, purpose-made set: see docs/05_STATUS.md.
return {
	Ambient = 136271631723876, -- "Fluorescent Light Hum"
	Hum = 0,
	Step = 122104581168480, -- single footstep
	LensUp = 129182368246762, -- walkie-talkie beep, standing in for a camera click
	RecStart = 129182368246762,
	TapeMotor = 9113391927, -- servo motor run
	Crowd = 9112844097, -- quiet crowd room tone
	RegistrarJump = 9125484526, -- deep hit, reverberant
	Reach = 79337190843902, -- horror drum hit
	Cut = 9125484526,
	Knock = 9120918417, -- knock on a wooden door
	Radio = 129182368246762,
	Bell = 9114059243, -- desk bell
	Projector = 9113391927, -- stand-in: servo motor
	Creak = 9114496277, -- floor creaks, reverberant room
	Drip = 9120533892, -- drip into a tin bucket
	ChairFold = 9114514078, -- folding chairs in a wooden room
	Paper = 9118835414, -- pages turned
	Wrong = 0,
	Music = 0,
} :: { [string]: number }
