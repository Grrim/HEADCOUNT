--!strict
-- The look of a home-video tape laid over a ScreenGui: fine scanlines, a picture that never quite
-- holds its brightness, and the ragged head-switching band at the bottom edge. Drawn only while
-- its gui is enabled, from plain frames, so there is nothing to upload.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Vhs = {}

local LINES = 120

export type Options = {
	-- 0 to 1: how hard the tape shows its age.
	strength: number,
	-- Sits under the gui's own text, above the picture.
	zIndex: number?,
	-- Blur in the distance while shown, like a cheap lens hunting for focus.
	focusBlur: number?,
}

local blurOwners: { [ScreenGui]: number } = {}
local dof: DepthOfFieldEffect? = nil

local function updateFocus()
	local strongest = 0
	for gui, amount in blurOwners do
		if gui.Enabled and gui.Parent then
			strongest = math.max(strongest, amount)
		end
	end
	if strongest > 0 and not dof then
		local made = Instance.new("DepthOfFieldEffect")
		made.Name = "TapeFocus"
		made.FocusDistance = 18
		made.InFocusRadius = 26
		made.NearIntensity = 0
		made.Parent = Lighting
		dof = made
	end
	local effect = dof
	if effect then
		effect.Enabled = strongest > 0
		effect.FarIntensity = strongest
	end
end

function Vhs.apply(gui: ScreenGui, options: Options)
	local strength = math.clamp(options.strength, 0, 1)
	local z = options.zIndex or 1
	local layer = Instance.new("Frame")
	layer.Name = "Vhs"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = z
	layer.Active = false
	layer.Parent = gui
	for index = 0, LINES - 1 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 1 - 0.16 * strength
		line.Position = UDim2.fromScale(0, index / LINES)
		line.Size = UDim2.new(1, 0, 0, 1)
		line.ZIndex = z
		line.Parent = layer
	end
	-- The whole picture breathes a little lighter and darker, never steady.
	local flicker = Instance.new("Frame")
	flicker.BorderSizePixel = 0
	flicker.BackgroundColor3 = Color3.new(1, 1, 1)
	flicker.BackgroundTransparency = 1
	flicker.Size = UDim2.fromScale(1, 1)
	flicker.ZIndex = z
	flicker.Parent = layer
	-- Head-switching noise: a torn strip along the bottom that jitters sideways.
	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.BackgroundColor3 = Color3.fromRGB(200, 200, 190)
	band.BackgroundTransparency = 1 - 0.35 * strength
	band.AnchorPoint = Vector2.new(0, 1)
	band.Size = UDim2.new(1.1, 0, 0.018, 0)
	band.ZIndex = z
	band.Parent = layer
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.35, 0.8),
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	gradient.Parent = band

	if options.focusBlur then
		blurOwners[gui] = options.focusBlur
		gui:GetPropertyChangedSignal("Enabled"):Connect(updateFocus)
		updateFocus()
	end

	local random = Random.new()
	local cooldown = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not gui.Parent then
			connection:Disconnect()
			return
		end
		if not gui.Enabled then
			return
		end
		cooldown -= dt
		if cooldown > 0 then
			return
		end
		-- Twelve updates a second: tape noise looks wrong when it is smooth.
		cooldown = 1 / 12
		flicker.BackgroundTransparency = 1 - random:NextNumber(0, 0.035) * strength
		band.Position = UDim2.new(random:NextNumber(-0.08, 0), 0, 1, 0)
		gradient.Offset = Vector2.new(random:NextNumber(-0.2, 0.2), 0)
	end)
end

return Vhs
