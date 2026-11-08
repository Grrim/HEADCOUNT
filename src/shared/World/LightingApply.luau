--!strict
-- Applies the base lighting preset. Runs on the server so every client starts identical.
local Lighting = game:GetService("Lighting")
local Config = require("../Config/Lighting")

local LightingApply = {}

local function assign(instance: Instance, values: { [string]: any })
	for key, value in values do
		(instance :: any)[key] = value
	end
end

-- `preset` names an override table in the config ("Hub"); the mission passes nothing and gets the
-- base look. Overrides are shallow per section, so a preset only lists what it changes.
function LightingApply.apply(preset: string?)
	local over = if preset then (Config :: any)[preset] or {} else {}
	assign(Lighting, Config.Base)
	assign(Lighting, over.Base or {})
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	assign(atmosphere, Config.Atmosphere)
	assign(atmosphere, over.Atmosphere or {})
	atmosphere.Parent = Lighting
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "WorldGrade"
	assign(correction, Config.World)
	assign(correction, over.World or {})
	correction.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "WorldBloom"
	assign(bloom, Config.Bloom)
	assign(bloom, over.Bloom or {})
	bloom.Parent = Lighting
end

return LightingApply
