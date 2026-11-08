--!strict
-- Starting values from the GDD. Tune these on screen, not in code.
return {
	Base = {
		Brightness = 1.2,
		ClockTime = 0,
		GlobalShadows = true,
		-- Lower than the GDD start: under Future the lamps carry the rooms, and the space between
		-- them should fall away into blue-black rather than sit at one even grey.
		Ambient = Color3.fromRGB(32, 36, 44),
		OutdoorAmbient = Color3.fromRGB(10, 12, 16),
		EnvironmentDiffuseScale = 0.15,
		EnvironmentSpecularScale = 0.3,
		ExposureCompensation = 0.25,
	},
	Atmosphere = {
		Density = 0.32,
		Offset = 0,
		Haze = 1.5,
		Glare = 0,
		Color = Color3.fromRGB(40, 52, 58),
		Decay = Color3.fromRGB(12, 16, 20),
	},
	World = {
		Contrast = 0.16,
		Saturation = -0.06,
		Brightness = 0,
		TintColor = Color3.fromRGB(240, 248, 250),
	},
	-- Enough for neon signs, the REC light and lamp bulbs to bloom; walls stay below the threshold.
	Bloom = { Intensity = 0.7, Size = 24, Threshold = 1.15 },
	Lens = {
		Contrast = 0.18,
		Saturation = -0.45,
		Brightness = 0.04,
		TintColor = Color3.fromRGB(214, 232, 240),
	},
	Playback = {
		Contrast = 0.25,
		Saturation = -0.6,
		Brightness = 0.06,
		TintColor = Color3.fromRGB(232, 226, 208),
	},
	OffFrame = {
		Contrast = 0.1,
		Saturation = -0.9,
		Brightness = -0.02,
		TintColor = Color3.fromRGB(170, 200, 255),
	},
	-- The hub is home base, not a horror set. Warmer, brighter and clearer than the mission:
	-- a staffed archive on a late shift, with the dread saved for the other place.
	Hub = {
		Base = {
			Brightness = 1.7,
			Ambient = Color3.fromRGB(62, 58, 50),
			OutdoorAmbient = Color3.fromRGB(24, 22, 20),
			ExposureCompensation = 0.4,
		},
		Atmosphere = {
			Density = 0.18,
			Haze = 0.9,
			Color = Color3.fromRGB(74, 66, 52),
			Decay = Color3.fromRGB(34, 28, 22),
		},
		World = {
			Contrast = 0.1,
			Saturation = 0.06,
			TintColor = Color3.fromRGB(255, 246, 230),
		},
	},
}
