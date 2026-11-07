--!strict
-- Places the models from Shared/Models, by the centre of their base on the floor. Models carry their
-- mesh ids in .rbxmx files because a script cannot set a MeshId; they only get cloned from here.
-- All generated assets are stand-ins: see docs/06_ASSETS.md.
local Palette = require("../Config/Palette")

local Props = {}

local models = script.Parent.Parent:WaitForChild("Models")

-- Client only. Without this the audience shows up untextured the first time the lens goes up.
function Props.preload()
	task.spawn(function()
		game:GetService("ContentProvider"):PreloadAsync(models:GetChildren())
	end)
end

-- scale is one number, or a Vector3 to stretch a prop to fit a space.
function Props.place(
	parent: Instance,
	name: string,
	floor: CFrame,
	scale: (number | Vector3)?
): MeshPart
	local template = models:WaitForChild(name) :: MeshPart
	local part = template:Clone()
	local factor = if typeof(scale) == "Vector3"
		then scale
		elseif typeof(scale) == "number" then Vector3.one * scale
		else Vector3.one
	part.Size = template.Size * factor
	part.CFrame = floor * CFrame.new(0, part.Size.Y / 2, 0)
	part.Parent = parent
	return part
end

local SITTERS = { "Sitter", "SitterBrown", "SitterNavy" }
local HAIR = {
	Color3.fromRGB(30, 24, 20),
	Color3.fromRGB(58, 44, 32),
	Color3.fromRGB(70, 66, 62),
	Color3.fromRGB(96, 92, 88),
	Color3.fromRGB(18, 18, 20),
}

-- The mesh is 2 studs tall: lap at 0.65, head centred at 1.75, radius 0.29 (measured with raycasts).
-- At this scale the lap meets the chair's seat and shoulders fit the 3.5 stud seat spacing.
local SCALE = 2.4
local LIFT = 0.2

-- Someone on a chair: body mesh, hair, and the black bar across the eyes. The bar is on the front,
-- so from behind they are rows of suits; from the stage, every one of them has been censored.
-- `floor` is the chair's place on the floor, looking the way the sitter looks.
function Props.sitter(parent: Instance, floor: CFrame, index: number?): { BasePart }
	local which = index or 1
	local place = floor * CFrame.new(0, LIFT, -0.3)
	local body = Props.place(parent, SITTERS[which % #SITTERS + 1], place, SCALE)
	body.CastShadow = false

	local function extra(size: Vector3, offset: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = place * offset
		p.Color = color
		p.Parent = parent
		return p
	end

	local bar = extra(Vector3.new(1.25, 0.24, 0.08), CFrame.new(0, 4.25, -0.64), Palette.Ink)
	-- A flattened cap, up and back on the head: the face and the bar stay visible from the stage,
	-- the nape from the back of the hall.
	local hair = extra(
		Vector3.new(1.46, 1.05, 1.5),
		CFrame.new(0, 4.52, 0.14),
		HAIR[(which * 3) % #HAIR + 1]
	)
	hair.Material = Enum.Material.Fabric
	local cap = Instance.new("SpecialMesh")
	cap.MeshType = Enum.MeshType.Sphere
	cap.Parent = hair
	return { body, bar, hair }
end

return Props
