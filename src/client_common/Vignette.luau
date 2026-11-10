--!strict
-- A soft dark edge round the picture, under every HUD. It pulls the eye to the middle of the
-- frame and makes even a lit room feel closed in. Four gradients, no texture to load.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Vignette = {}

local EDGE = 0.22
local DARKEST = 0.35

local function edge(gui: ScreenGui, rotation: number, position: UDim2, size: UDim2, anchor: Vector2)
	local frame = Ui.frame({
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Active = false,
	}, gui)
	Ui.make("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, DARKEST),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, frame)
end

function Vignette.start()
	local gui = Ui.screen("Vignette", 0, true)
	edge(gui, 90, UDim2.fromScale(0, 0), UDim2.fromScale(1, EDGE), Vector2.zero)
	edge(gui, -90, UDim2.fromScale(0, 1), UDim2.fromScale(1, EDGE), Vector2.new(0, 1))
	edge(gui, 0, UDim2.fromScale(0, 0), UDim2.fromScale(EDGE, 1), Vector2.zero)
	edge(gui, 180, UDim2.fromScale(1, 0), UDim2.fromScale(EDGE, 1), Vector2.new(1, 0))
end

return Vignette
