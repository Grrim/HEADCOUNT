--!strict
-- Builds every wall poster with real Roblox instances from Lune's reflection database, so a
-- wrong class, property or enum name fails here rather than in Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

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
}

local function loadPosters(): any
	local env: { [string]: any } = setmetatable({}, { __index = _G }) :: any
	for _, name in GLOBALS do
		env[name] = (roblox :: any)[name]
	end
	local function load(path: string): any
		return (luau.load(fs.readFile(path), { debugName = path, environment = env }) :: any)()
	end
	local palette = load("src/shared/Config/Palette.luau")
	env.require = function(_)
		return palette
	end
	return load("src/shared/World/Posters.luau")
end

return {
	["every poster builds and faces the way it is hung"] = function()
		local Posters = loadPosters()
		local normal = roblox.Vector3.new(-1, 0, 0)
		for _, kind in Posters.KINDS do
			local part =
				Posters.hang(roblox.Instance.new("Folder"), kind, roblox.Vector3.zero, normal, 3, 2)
			assert(part:FindFirstChildOfClass("SurfaceGui"), `{kind} has no picture`)
			assert(#part:GetDescendants() > 8, `{kind} is nearly empty`)
			local look = part.CFrame.LookVector
			assert(look:Dot(normal) > 0.99, `{kind} faces the wall`)
		end
	end,
}
