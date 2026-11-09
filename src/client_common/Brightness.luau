--!strict
-- A player-side brightness setting. Screens and rooms differ, and a horror game that is too dark
-- to read is not frightening, only tiring. The choice follows the player across the teleport.
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local Brightness = {}

local LEVELS = { -0.06, 0, 0.05, 0.1, 0.16, 0.22 }
local DEFAULT = 2
local SETTING = "HeadcountBrightness"

local index = DEFAULT
local effect: ColorCorrectionEffect? = nil

local function apply()
	if not effect then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "PlayerBrightness"
		made.Parent = Lighting
		effect = made
	end
	local level = LEVELS[index]
	local target = effect :: ColorCorrectionEffect
	target.Brightness = level
	-- Lifting the blacks alone washes the picture out; a touch of contrast keeps it firm.
	target.Contrast = level * 0.4
end

function Brightness.start()
	local ok, saved = pcall(function()
		return TeleportService:GetTeleportSetting(SETTING)
	end)
	if ok and typeof(saved) == "number" and LEVELS[saved] then
		index = saved
	end
	apply()
end

function Brightness.change(delta: number)
	index = math.clamp(index + delta, 1, #LEVELS)
	apply()
	pcall(function()
		TeleportService:SetTeleportSetting(SETTING, index)
	end)
end

-- A row of blocks, one lit per level: readable at a glance on any screen.
function Brightness.meter(): string
	local parts = {}
	for level = 1, #LEVELS do
		table.insert(parts, if level <= index then "#" else "-")
	end
	return "[" .. table.concat(parts) .. "]"
end

return Brightness
