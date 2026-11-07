--!strict
-- Forty coats hang a hand apart, and the engine offers E for whichever one it likes best, which
-- is often the neighbour of the coat the player is looking at. A wrong coat is a mistake that
-- pulls the Registrar closer, so in the cloakroom only the coat nearest the centre of the view
-- keeps its range. The change is local: the server never touches MaxActivationDistance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Core.Layout)

local CoatAim = {}

local REACH = 11
-- Cosine of the widest angle off the view centre that still counts as looking at a coat.
local MIN_ALIGNMENT = math.cos(math.rad(25))

local function inCloakroom(position: Vector3): boolean
	local room = Layout.COATS
	return position.X > room.minX - 4
		and position.X < room.maxX
		and position.Z > room.minZ
		and position.Z < room.maxZ
end

function CoatAim.start()
	local map = Workspace:WaitForChild("Map")
	local rack = map:WaitForChild("Coats")
	local prompts: { ProximityPrompt } = {}
	for _, coat in rack:GetChildren() do
		local prompt = coat:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			table.insert(prompts, prompt)
		end
	end
	local current: ProximityPrompt? = nil
	local inside = false

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local origin = camera.CFrame.Position
		if not inCloakroom(origin) then
			if inside then
				-- Outside the room every coat goes back to its full range.
				inside = false
				current = nil
				for _, prompt in prompts do
					prompt.MaxActivationDistance = REACH
				end
			end
			return
		end
		local look = camera.CFrame.LookVector
		local best: ProximityPrompt? = nil
		local bestAlignment = MIN_ALIGNMENT
		for _, prompt in prompts do
			local coat = prompt.Parent :: BasePart
			local offset = coat.Position - origin
			local distance = offset.Magnitude
			if prompt.Enabled and distance <= REACH + 2 then
				local alignment = look:Dot(offset / distance)
				if alignment > bestAlignment then
					bestAlignment = alignment
					best = prompt
				end
			end
		end
		if inside and best == current then
			return
		end
		-- Looking at no coat in particular offers nothing rather than a guess.
		inside = true
		current = best
		for _, prompt in prompts do
			prompt.MaxActivationDistance = if prompt == best then REACH else 0
		end
	end)
end

return CoatAim
