--!strict
-- The night shift nobody hired. Through the lens the Registry Hall is staffed: clerks in suits,
-- collar and no head, walking the aisles between the shelves, pausing to file something, and one
-- behind the reception counter who always turns to face the camera. To the eye the hall is empty.
-- It is the game's first rule taught without a word (the lens shows what the eye does not), and it
-- gives the camera something to do while a team gathers. Local, cosmetic, cheap: five figures,
-- positions worked out from the clock, drawn only while the camera is up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Props = require(ReplicatedStorage.Shared.World.Props)

local Archivists = {}

-- The Registrar's own mesh, cut down to a man's height: the same kind of thing, smaller.
local HEIGHT = 5.6
local MESH_HEIGHT = 11.196
local WALK_SPEED = 3.2
local PAUSE = 2.5

type Walker = {
	body: BasePart,
	path: { Vector3 },
	-- Where along the loop it starts, so the clerks are never in step.
	phase: number,
	-- Which way it faces while it pauses at the end of the aisle (towards the shelves).
	file: { Vector3 },
}

local folder: Folder
local walkers: { Walker } = {}
local receptionist: BasePart

local function figure(): BasePart
	local model = Instance.new("Model")
	model.Name = "Archivist"
	local body = Props.place(model, "Registrar", CFrame.new(), HEIGHT / MESH_HEIGHT)
	body.CanQuery = false
	body.CanCollide = false
	body.CanTouch = false
	body.CastShadow = false
	model.Parent = folder
	return body
end

local function walker(path: { Vector3 }, phase: number, file: { Vector3 })
	table.insert(walkers, { body = figure(), path = path, phase = phase, file = file })
end

-- Back and forth between the two ends of its aisle, pausing at each end facing the shelf.
local function poseAt(w: Walker, t: number): CFrame
	local a, b = w.path[1], w.path[2]
	local leg = (b - a).Magnitude / WALK_SPEED
	local cycle = 2 * (leg + PAUSE)
	local c = (t + w.phase * cycle) % cycle
	if c < leg then
		local p = a:Lerp(b, c / leg)
		return CFrame.lookAt(p, Vector3.new(b.X, p.Y, b.Z))
	elseif c < leg + PAUSE then
		return CFrame.lookAt(b, Vector3.new(w.file[2].X, b.Y, w.file[2].Z))
	elseif c < 2 * leg + PAUSE then
		local p = b:Lerp(a, (c - leg - PAUSE) / leg)
		return CFrame.lookAt(p, Vector3.new(a.X, p.Y, a.Z))
	end
	return CFrame.lookAt(a, Vector3.new(w.file[1].X, a.Y, w.file[1].Z))
end

local function update()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local t = os.clock()
	local lift = CFrame.new(0, HEIGHT / 2, 0)
	for _, w in walkers do
		-- A slight sway from the hips as they walk.
		local sway = CFrame.Angles(0, 0, math.sin(t * 3.6 + w.phase * 10) * 0.025)
		w.body.CFrame = poseAt(w, t) * lift * sway
	end
	-- The one at reception never takes its eyes off you, though it has none.
	local desk = Vector3.new(11, 0, -5)
	local look = Vector3.new(camera.CFrame.Position.X, 0, camera.CFrame.Position.Z)
	receptionist.CFrame = CFrame.lookAt(desk, look) * lift
end

function Archivists.start()
	Workspace:WaitForChild("Map")
	folder = Instance.new("Folder")
	folder.Name = "Archivists"
	-- The aisles between the shelf rows (west x -28..-22, east 22..28), the cross aisle in front
	-- of the terminal, and the strip by the west wall.
	walker({ Vector3.new(-25, 0, -32), Vector3.new(-25, 0, 12) }, 0.1, {
		Vector3.new(-30, 0, -32),
		Vector3.new(-20, 0, 12),
	})
	walker({ Vector3.new(25, 0, 12), Vector3.new(25, 0, -32) }, 0.55, {
		Vector3.new(20, 0, 12),
		Vector3.new(30, 0, -32),
	})
	walker({ Vector3.new(-14, 0, -24), Vector3.new(14, 0, -24) }, 0.3, {
		Vector3.new(-14, 0, -40),
		Vector3.new(14, 0, -40),
	})
	walker({ Vector3.new(-36, 0, 14), Vector3.new(-36, 0, -36) }, 0.8, {
		Vector3.new(-40, 0, 14),
		Vector3.new(-40, 0, -36),
	})
	receptionist = figure()
	RunService.RenderStepped:Connect(function()
		if folder.Parent then
			update()
		end
	end)
	-- Only the lens sees them.
	LensView.onChanged(function(raised)
		folder.Parent = if raised then Workspace else nil
		if raised then
			update()
		end
	end)
end

return Archivists
