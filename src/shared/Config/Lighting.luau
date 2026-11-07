--!strict
-- Starting values from the GDD. Tune these on screen, not in code.
return {
	Base = {
		Brightness = 1.2,
		ClockTime = 0,
		GlobalShadows = true,
		Ambient = Color3.fromRGB(40, 46, 52),
		OutdoorAmbient = Color3.fromRGB(10, 12, 16),
		EnvironmentDiffuseScale = 0.15,
		EnvironmentSpecularScale = 0.3,
		ExposureCompensation = 0,
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
		Contrast = 0.08,
		Saturation = -0.12,
		Brightness = 0,
		TintColor = Color3.fromRGB(245, 250, 245),
	},
	Bloom = { Intensity = 0.35, Size = 18, Threshold = 1.6 },
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
}
