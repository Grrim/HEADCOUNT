--!strict
-- Playing a shift tape (docs/09_GDD_V2.md §7) on the pay screen. A tape is a floor's seed and depth
-- and a camera path (Core/Highlight); the floor, gone since the lift left it, is rebuilt here from
-- those (World/FloorBuild) with every figure the lens saw on it (World/Figures), inside a
-- ViewportFrame, and the path is flown again and again in the tape's look.
--
-- A viewport has no lamps and no shadows, so the copy is lit evenly: it reads as footage, not as
-- the floor itself, which is the point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Figures = require(ReplicatedStorage.Shared.World.Figures)
local FloorBuild = require(ReplicatedStorage.Shared.World.FloorBuild)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local Highlight = require(ReplicatedStorage.Shared.Core.Highlight)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Tape = require(ReplicatedStorage.Shared.Core.Tape)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local ShiftTapeView = {}

local RARITY_LABELS = {
	common = "COMMON",
	rare = "RARE",
	epic = "EPIC",
	legendary = "LEGENDARY",
}

local function stars(count: number): string
	return string.rep("★", count) .. string.rep("☆", 5 - count)
end

-- Fills `screen` (a Frame) with a playing copy of the tape. Returns a function that stops it, or
-- nil when the tape can not be played.
function ShiftTapeView.play(screen: Frame, tape: any): (() -> ())?
	local track = if typeof(tape) == "table" then Highlight.unpack(tape.track) else nil
	if
		not track
		or typeof(tape.seed) ~= "number"
		or typeof(tape.depth) ~= "number"
		or typeof(tape.hz) ~= "number"
	then
		return nil
	end
	screen:ClearAllChildren()

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.new(0, 0, 0)
	viewport.Ambient = Color3.fromRGB(150, 146, 136)
	viewport.LightColor = Color3.fromRGB(210, 204, 190)
	viewport.LightDirection = Vector3.new(-0.3, -1, -0.2)
	viewport.Parent = screen
	local camera = Instance.new("Camera")
	camera.FieldOfView = Config.Lens.Fov
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- The floor as it was, and everything the lens showed on it.
	local floor = FloorGen.generate(tape.seed, tape.depth)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	FloorBuild.build(floor, tape.seed).Parent = world
	local watchers: { { model: Model, base: CFrame } } = {}
	for _, spot in floor.spots do
		local model, base =
			Figures.anomaly(spot.kind, Vector3.new(spot.x, 0, spot.z), tape.seed + spot.id)
		model.Parent = world
		if spot.kind == "watcher" then
			table.insert(watchers, { model = model, base = base })
		end
	end

	-- The tape's own marks: what it is, who shot it, and where it is up to.
	for line = 0, 44 do
		Ui.frame({
			Position = UDim2.fromScale(0, line / 45),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.82,
			ZIndex = 2,
		}, screen)
	end
	Ui.mono({
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 18),
		FontFace = Ui.Fonts.MonoBold,
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		Text = `▶ PLAY   FLOOR -{tape.depth}`,
		ZIndex = 3,
	}, screen)
	Ui.mono({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = 13,
		TextColor3 = Palette.Crt,
		TextStrokeTransparency = 0.4,
		Text = `{stars(tape.stars or 0)}  {RARITY_LABELS[tape.rarity] or ""}  ·  {tape.by or "?"}`,
		ZIndex = 3,
	}, screen)
	local band = Ui.frame({
		Size = UDim2.new(1, 0, 0.04, 0),
		BackgroundColor3 = Palette.Paper,
		BackgroundTransparency = 0.88,
		ZIndex = 2,
	}, screen)

	local duration = Tape.duration(track, tape.hz)
	local elapsed = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		elapsed = (elapsed + dt) % math.max(duration, 0.1)
		local s = Tape.sampleAt(track, elapsed, tape.hz)
		local position = Vector3.new(s[1], s[2], s[3])
		camera.CFrame = CFrame.lookAt(position, position + Vector3.new(s[4], s[5], s[6]))
		band.Position = UDim2.fromScale(0, (elapsed * 0.27) % 1)
		-- Watchers turn to the lens here too.
		for _, watcher in watchers do
			local spot = watcher.base.Position
			local look = Vector3.new(position.X, spot.Y, position.Z)
			if (look - spot).Magnitude > 0.5 then
				watcher.model:PivotTo(CFrame.lookAt(spot, look))
			end
		end
	end)
	local function stop()
		connection:Disconnect()
	end
	screen.Destroying:Connect(stop)
	viewport.Destroying:Connect(stop)
	return stop
end

return ShiftTapeView
