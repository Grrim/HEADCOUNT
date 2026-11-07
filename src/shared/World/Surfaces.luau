--!strict
-- Turns the blockout's flat colours into real surfaces, in one pass over the map. World code keeps
-- describing parts by palette colour; this decides what those colours are made of, so a material
-- can change here without touching any level code.
local Palette = require("../Config/Palette")

local Surfaces = {}

type Rule = { material: Enum.Material, variant: string, tint: Color3 }

local RULES: { [string]: Rule } = {
	[tostring(Palette.Carpet)] = {
		material = Enum.Material.Carpet,
		variant = "PK_Carpet",
		tint = Color3.fromRGB(92, 82, 78),
	},
	[tostring(Palette.Wall)] = {
		material = Enum.Material.Plaster,
		variant = "PK_Wallpaper",
		tint = Color3.fromRGB(186, 184, 172),
	},
	[tostring(Palette.WallDark)] = {
		material = Enum.Material.Plaster,
		variant = "PK_Wallpaper",
		tint = Color3.fromRGB(150, 146, 134),
	},
	[tostring(Palette.Ceiling)] = {
		material = Enum.Material.Plaster,
		variant = "PK_CeilingTile",
		tint = Color3.fromRGB(150, 152, 154),
	},
	[tostring(Palette.Wood)] = {
		material = Enum.Material.Wood,
		variant = "PK_Veneer",
		tint = Color3.fromRGB(150, 150, 142),
	},
	[tostring(Palette.WoodDark)] = {
		material = Enum.Material.Wood,
		variant = "PK_Veneer",
		tint = Color3.fromRGB(140, 120, 110),
	},
}

local NAMED: { [string]: Rule } = {
	FoyerFloor = {
		material = Enum.Material.Marble,
		variant = "PK_Terrazzo",
		tint = Color3.fromRGB(205, 196, 182),
	},
}

function Surfaces.apply(root: Instance)
	for _, part in root:GetDescendants() do
		if part:IsA("Part") and part.Material ~= Enum.Material.Neon then
			local rule = NAMED[part.Name] or RULES[tostring(part.Color)]
			-- Concrete stays concrete: the basement should feel unfinished.
			if rule and part.Material ~= Enum.Material.Concrete then
				part.Material = rule.material
				part.MaterialVariant = rule.variant
				part.Color = rule.tint
			end
		end
	end
end

return Surfaces
