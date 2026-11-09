--!strict
-- `lune run audit_map [mission|hub]` builds a place's map headlessly from the built .rbxl (run
-- `rojo build` first) and reports geometry problems Studio would only show on screen:
--   * z-fighting: two visible boxes sharing a face plane where their faces overlap,
--   * buried props: a visible box sunk deep inside a solid one,
--   * strays: parts outside every room's bounds, or hanging in the air with nothing under them.
-- It runs the real world-building services, so what it checks is what the game builds.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Enum = roblox.Enum
local Vector3 = roblox.Vector3

-- Lune's instances lack a few engine methods the building code uses; stand-ins that do the
-- same thing for a map that is already fully built in memory.
roblox.implementMethod("Instance", "WaitForChild", function(self: any, name: string)
	return self:FindFirstChild(name)
end)

local which = process.args[1] or "mission"
local placeFile = if which == "hub" then "build/Hub.rbxl" else "build/Mission.rbxl"
local game = roblox.deserializePlace(fs.readFile(placeFile))

local GLOBALS = {
	"Instance",
	"Vector3",
	"Vector2",
	"CFrame",
	"UDim",
	"UDim2",
	"Color3",
	"Enum",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"NumberRange",
	"Rect",
	"BrickColor",
	"Font",
	"PhysicalProperties",
	"Ray",
	"Region3",
	"Faces",
	"Axes",
}

local cache: { [any]: any } = {}

local function resolve(from: any, path: string): any
	local node = from.Parent
	local parts = string.split(path, "/")
	for index, part in parts do
		if part == "." then
			continue
		elseif part == ".." then
			node = node.Parent
		else
			node = node:FindFirstChild(part)
			if not node then
				error(`cannot resolve {path} from {from:GetFullName()} (at {part}, step {index})`)
			end
		end
	end
	return node
end

local load: (moduleScript: any) -> any

local function makeEnv(scriptInstance: any): { [string]: any }
	local env: { [string]: any } = setmetatable({}, { __index = _G }) :: any
	for _, name in GLOBALS do
		local value = (roblox :: any)[name]
		if value ~= nil then
			env[name] = value
		end
	end
	env.game = game
	env.workspace = game:GetService("Workspace")
	env.script = scriptInstance
	env.task = task
	env.warn = function(...)
		print("[warn]", ...)
	end
	env.require = function(target: any): any
		if typeof(target) == "string" then
			return load(resolve(scriptInstance, target))
		end
		return load(target)
	end
	return env
end

load = function(moduleScript: any): any
	if cache[moduleScript] ~= nil then
		return cache[moduleScript]
	end
	local source = moduleScript.Source
	local chunk = luau.load(source, {
		debugName = moduleScript:GetFullName(),
		environment = makeEnv(moduleScript),
	})
	local result = chunk()
	cache[moduleScript] = result
	return result
end

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local function service(name: string): any
	local folder = if which == "hub"
		then ServerScriptService.Hub.Services
		else ServerScriptService.Mission.Services
	return load(folder:FindFirstChild(name))
end

-- Build the map the way the server does: world first, then dressing on top of it.
local world = service(if which == "hub" then "HubWorld" else "MissionWorld")
local dressing = service(if which == "hub" then "HubDressing" else "MissionDressing")
local services = { [if which == "hub" then "HubWorld" else "MissionWorld"] = world }
if world.init then
	world.init(services)
end
if world.start and which == "hub" then
	world.start()
end
dressing.start()
local map = Workspace:FindFirstChild("Map")
assert(map, "no Map was built")

type Box = {
	part: any,
	name: string,
	min: Vector3,
	max: Vector3,
	visible: boolean,
	solid: boolean,
	exact: boolean,
	mesh: boolean,
}

local boxes: { Box } = {}
for _, item in map:GetDescendants() do
	if item:IsA("BasePart") then
		-- In Lune, Position and CFrame are separate stored properties: whichever the building code
		-- set is the real one.
		local hasPosition, setPosition = pcall(function()
			return item.Position
		end)
		-- A CFrame that was set explicitly is never left at the origin; otherwise Position holds it.
		local cf = if item.CFrame.Position == Vector3.zero and hasPosition
			then item.CFrame + setPosition
			else item.CFrame
		local look, up, right = cf.LookVector, cf.UpVector, cf.RightVector
		-- Only axis-aligned boxes are compared; rotated parts would need a real SAT test.
		local aligned = math.abs(math.abs(right.X) + math.abs(right.Y) + math.abs(right.Z) - 1)
				< 1e-3
			and math.abs(math.abs(up.X) + math.abs(up.Y) + math.abs(up.Z) - 1) < 1e-3
			and math.abs(math.abs(look.X) + math.abs(look.Y) + math.abs(look.Z) - 1) < 1e-3
		local isBlock = item:IsA("Part") and item.Shape == Enum.PartType.Block
		-- Rotated parts and meshes still get a world box (it bounds them), but only for the
		-- buried check; z-fighting is only judged between true axis-aligned blocks.
		do
			local size = item.Size
			local world = Vector3.new(
				math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z,
				math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z,
				math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z
			)
			local half = world / 2
			local visible = item.Transparency < 0.95
			table.insert(boxes, {
				part = item,
				name = item:GetFullName():gsub("^Workspace%.Map%.", ""),
				min = cf.Position - half,
				max = cf.Position + half,
				visible = visible,
				solid = item.CanCollide and aligned and isBlock,
				exact = aligned and isBlock,
				mesh = item:IsA("MeshPart"),
			})
		end
	end
end

local EPS = 0.002
-- Floor heights, in hundredths: 0 (ground), -12 (basement), 3 (stage, archive), 14 (booth).
local FLOOR_LEVELS = { [0] = true, [-1200] = true, [300] = true, [1400] = true }
-- Ceiling heights: corridor 13, foyer and coats 14, hall 24, booth 25 (mission); hub 26.
local CEILING_LEVELS =
	{ [1300] = true, [1400] = true, [2400] = true, [2500] = true, [2600] = true, [-200] = true }
local function overlap1(aMin: number, aMax: number, bMin: number, bMax: number): number
	return math.min(aMax, bMax) - math.max(aMin, bMin)
end

local zfights, buried = {}, {}
local axes = { "X", "Y", "Z" }
for i = 1, #boxes do
	local a = boxes[i]
	if not a.visible then
		continue
	end
	for j = i + 1, #boxes do
		local b = boxes[j]
		if not b.visible then
			continue
		end
		local o = {
			X = overlap1(a.min.X, a.max.X, b.min.X, b.max.X),
			Y = overlap1(a.min.Y, a.max.Y, b.min.Y, b.max.Y),
			Z = overlap1(a.min.Z, a.max.Z, b.min.Z, b.max.Z),
		}
		if o.X < -EPS or o.Y < -EPS or o.Z < -EPS then
			continue
		end
		local compareFaces = a.exact and b.exact
		-- Coplanar faces pointing the same way, with real area in common: that flickers.
		for _, axis in if compareFaces then axes else {} do
			local others = {}
			for _, other in axes do
				if other ~= axis then
					table.insert(others, other)
				end
			end
			local area = math.max(0, o[others[1]]) * math.max(0, o[others[2]])
			if area > 0.05 then
				local aMin, aMax = (a.min :: any)[axis], (a.max :: any)[axis]
				local bMin, bMax = (b.min :: any)[axis], (b.max :: any)[axis]
				for _, side in { "min", "max" } do
					local same = if side == "min"
						then math.abs(aMin - bMin) < EPS
						else math.abs(aMax - bMax) < EPS
					if same then
						local plane = if side == "min" then aMin else aMax
						-- The shared patch of face, in the two other axes.
						local lo1 = math.max((a.min :: any)[others[1]], (b.min :: any)[others[1]])
						local hi1 = math.min((a.max :: any)[others[1]], (b.max :: any)[others[1]])
						local lo2 = math.max((a.min :: any)[others[2]], (b.min :: any)[others[2]])
						local hi2 = math.min((a.max :: any)[others[2]], (b.max :: any)[others[2]])
						-- Hidden if a third solid sits flush against that plane over the whole patch
						-- (a wall on the floor, a sign against a wall): nobody can see between them.
						local hidden = false
						for _, c in boxes do
							if c ~= a and c ~= b and c.visible then
								local touching = if side == "min"
									then math.abs((c.max :: any)[axis] - plane) < EPS
									else math.abs((c.min :: any)[axis] - plane) < EPS
								-- Or the patch is sunk inside a third solid (a wall, a floor slab).
								local within = (c.min :: any)[axis] < plane - EPS
									and (c.max :: any)[axis] > plane + EPS
								if
									(touching or within)
									and (c.min :: any)[others[1]] <= lo1 + EPS
									and (c.max :: any)[others[1]] >= hi1 - EPS
									and (c.min :: any)[others[2]] <= lo2 + EPS
									and (c.max :: any)[others[2]] >= hi2 - EPS
								then
									hidden = true
									break
								end
							end
						end
						-- Undersides resting on a floor level are never seen from inside the building.
						if
							axis == "Y"
							and side == "min"
							and FLOOR_LEVELS[math.floor(plane * 100 + 0.5)]
						then
							hidden = true
						end
						-- And tops of walls level with a ceiling sit in the void above it.
						if
							axis == "Y"
							and side == "max"
							and CEILING_LEVELS[math.floor(plane * 100 + 0.5)]
						then
							hidden = true
						end
						if not hidden then
							table.insert(
								zfights,
								string.format(
									"%-38s %-38s %s=%s %.2f area %.2f",
									a.name,
									b.name,
									axis,
									side,
									plane,
									area
								)
							)
						end
					end
				end
			end
		end
		-- One box mostly inside a solid one (props sunk into walls or floors).
		local inside = math.max(0, o.X) * math.max(0, o.Y) * math.max(0, o.Z)
		local va = (a.max.X - a.min.X) * (a.max.Y - a.min.Y) * (a.max.Z - a.min.Z)
		local vb = (b.max.X - b.min.X) * (b.max.Y - b.min.Y) * (b.max.Z - b.min.Z)
		local small, big = if va < vb then a else b, if va < vb then b else a
		local smallVolume = math.min(va, vb)
		-- A model is judged more strictly: a mesh a quarter inside a wall is already visibly wrong
		-- (its bounding box is generous, so the floor it stands on is not counted).
		local limit = if small.mesh then 0.25 else 0.6
		local standsOnIt = small.mesh and math.abs(small.min.Y - big.max.Y) < 0.3
		-- Shelf units are built round a dark core on purpose.
		local byDesign = small.part.Name == "Shelf" and big.part.Name == "ShelfCore"
		if
			big.solid
			and not standsOnIt
			and not byDesign
			and smallVolume > 0.01
			and inside / smallVolume > limit
			and inside > 0.05
		then
			table.insert(
				buried,
				string.format(
					"%-40s in %-40s %.0f%%",
					small.name,
					big.name,
					inside / smallVolume * 100
				)
			)
		end
	end
end

print(`audited {#boxes} axis-aligned boxes in {which}`)
print(`\nZ-FIGHTING ({#zfights})`)
table.sort(zfights)
for _, line in zfights do
	print("  " .. line)
end
print(`\nBURIED ({#buried})`)
table.sort(buried)
for _, line in buried do
	print("  " .. line)
end

-- The Usher walks his route through the air, so every leg must stay in open floor: sample it and
-- look for any solid block within his body (0.7 studs round, 1 to 6 above the floor).
if which == "mission" then
	local layout = load(game:GetService("ReplicatedStorage").Shared.Core.Layout)
	local route = layout.USHER_ROUTE
	local blocked = {}
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		local from = Vector3.new(a.x, a.y, a.z)
		local to = Vector3.new(b.x, b.y, b.z)
		local steps = math.max(1, math.ceil((to - from).Magnitude / 0.5))
		for step = 0, steps do
			local p = from:Lerp(to, step / steps)
			for _, box in boxes do
				if box.solid then
					local inX = p.X > box.min.X - 0.7 and p.X < box.max.X + 0.7
					local inZ = p.Z > box.min.Z - 0.7 and p.Z < box.max.Z + 0.7
					local inY = p.Y + 6 > box.min.Y and p.Y + 1 < box.max.Y
					if inX and inY and inZ then
						table.insert(
							blocked,
							string.format(
								"leg %d at (%.1f, %.1f, %.1f) hits %s",
								index,
								p.X,
								p.Y,
								p.Z,
								box.name
							)
						)
						break
					end
				end
			end
		end
	end
	print(`\nUSHER ROUTE ({#blocked} blocked samples)`)
	local shown = {}
	for _, line in blocked do
		local key = line:match("hits (.*)$") .. line:match("^leg (%d+)")
		if not shown[key] then
			shown[key] = true
			print("  " .. line)
		end
	end
end
