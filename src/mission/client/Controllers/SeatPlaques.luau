--!strict
-- Seat numbers near the camera only: 192 always-on SurfaceGuis would cost more than they give.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)

local SeatPlaques = {}

local RANGE = 11
local active: { [number]: SurfaceGui } = {}

local function make(id: number, back: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(120, 120)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.06)
	label.Size = UDim2.fromScale(0.5, 0.2)
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = Palette.Paper
	label.TextTransparency = 0.15
	label.Text = Seats.label(id)
	label.Parent = gui
	gui.Parent = back
	return gui
end

function SeatPlaques.start()
	local map = Workspace:WaitForChild("Map")
	local folder = map:WaitForChild("Seats")
	while true do
		task.wait(0.4)
		local camera = Workspace.CurrentCamera
		if camera then
			local position = camera.CFrame.Position
			for id = 1, Seats.TOTAL do
				local x, z = Seats.position(id)
				local dx, dz = x - position.X, z - position.Z
				local near = dx * dx + dz * dz <= RANGE * RANGE
				if near and not active[id] then
					local seat = folder:FindFirstChild(`Seat{id}`)
					local back = seat and seat:FindFirstChild("Back") :: BasePart?
					if back then
						active[id] = make(id, back)
					end
				elseif not near and active[id] then
					active[id]:Destroy()
					active[id] = nil
				end
			end
		end
	end
end

return SeatPlaques
