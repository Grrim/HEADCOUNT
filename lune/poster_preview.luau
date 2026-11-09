-- `lune run poster_preview` writes work/posters_preview.html: the wall posters drawn from the
-- same instance tree the game builds, for checking a design without opening Studio.
-- Approximate: fonts are web stand-ins and TextScaled is guessed from the box height.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local env: { [string]: any } = setmetatable({}, { __index = _G }) :: any
for _, name in
	{
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
do
	env[name] = (roblox :: any)[name]
end
local function load(path: string): any
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local palette = load("src/shared/Config/Palette.luau")
env.require = function(_)
	return palette
end
local Posters = load("src/shared/World/Posters.luau")

local FONTS = {
	Oswald = "'Oswald', 'Arial Narrow', sans-serif-condensed, Impact, sans-serif",
	SpecialElite = "'Special Elite', 'Courier New', monospace",
}
local function rgb(c: any, alpha: number): string
	return string.format("rgba(%d,%d,%d,%.3f)", c.R * 255, c.G * 255, c.B * 255, 1 - alpha)
end
local function esc(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function node(item: any, parentW: number, parentH: number): string
	if not (item:IsA("Frame") or item:IsA("TextLabel")) then
		return ""
	end
	local w = item.Size.X.Scale * parentW + item.Size.X.Offset
	local h = item.Size.Y.Scale * parentH + item.Size.Y.Offset
	local x = item.Position.X.Scale * parentW + item.Position.X.Offset
	local y = item.Position.Y.Scale * parentH + item.Position.Y.Offset
	local style = { string.format("left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx", x, y, w, h) }
	if item.Rotation ~= 0 then
		table.insert(style, string.format("transform:rotate(%.1fdeg)", item.Rotation))
	end
	if item.BackgroundTransparency < 1 then
		table.insert(
			style,
			"background:" .. rgb(item.BackgroundColor3, item.BackgroundTransparency)
		)
	end
	if item.ClipsDescendants then
		table.insert(style, "overflow:hidden")
	end
	local corner = item:FindFirstChildOfClass("UICorner")
	if corner then
		table.insert(
			style,
			string.format(
				"border-radius:%.1fpx",
				corner.CornerRadius.Scale * math.min(w, h) + corner.CornerRadius.Offset
			)
		)
	end
	local gradient = item:FindFirstChildOfClass("UIGradient")
	if gradient and item.BackgroundTransparency < 1 then
		local stops = {}
		for _, k in gradient.Transparency.Keypoints do
			table.insert(
				stops,
				string.format("%s %.0f%%", rgb(item.BackgroundColor3, k.Value), k.Time * 100)
			)
		end
		table.insert(
			style,
			string.format(
				"background:linear-gradient(%ddeg,%s)",
				(gradient.Rotation + 90) % 360,
				table.concat(stops, ",")
			)
		)
	end
	local inner = ""
	if item:IsA("TextLabel") then
		local fontName = item.Font.Name
		table.insert(
			style,
			string.format(
				"color:%s;font-family:%s;font-size:%.0fpx;line-height:%.0fpx;text-align:%s",
				rgb(item.TextColor3, 0),
				FONTS[fontName] or "sans-serif",
				math.min(
					h * 0.86,
					w
						/ (
							math.max(1, utf8.len(item.Text) or #item.Text)
							* (if fontName == "SpecialElite" then 0.62 else 0.47)
						)
				),
				h,
				item.TextXAlignment.Name:lower()
			)
		)
		table.insert(
			style,
			"white-space:nowrap;display:flex;align-items:center;justify-content:center"
		)
		inner = esc(item.Text)
	end
	local children = {}
	for _, child in item:GetChildren() do
		table.insert(children, node(child, w, h))
	end
	return string.format(
		'<div style="position:absolute;%s">%s%s</div>',
		table.concat(style, ";"),
		inner,
		table.concat(children)
	)
end

local cards = {}
for _, kind in Posters.KINDS do
	local part = Posters.hang(
		roblox.Instance.new("Folder"),
		kind,
		roblox.Vector3.new(0, 0, 0),
		roblox.Vector3.new(1, 0, 0),
		3,
		0
	)
	local gui = part:FindFirstChildOfClass("SurfaceGui")
	local sheet = gui:FindFirstChildOfClass("Frame")
	local size = gui.CanvasSize
	table.insert(
		cards,
		string.format(
			'<figure><div class="poster" style="width:%dpx;height:%dpx">%s</div><figcaption>%s</figcaption></figure>',
			size.X,
			size.Y,
			node(sheet, size.X, size.Y),
			kind
		)
	)
end
local html = [[<!doctype html><html><head><meta charset="utf-8"><title>HEADCOUNT posters</title>
<link href="https://fonts.googleapis.com/css2?family=Oswald:wght@500&family=Special+Elite&display=swap" rel="stylesheet">
<style>body{background:#16181a;color:#ccc;font-family:sans-serif;margin:24px}main{display:flex;flex-wrap:wrap;gap:28px}
figure{margin:0}.poster{position:relative;overflow:hidden;box-shadow:0 8px 30px #000}figcaption{margin-top:8px;font-size:13px;opacity:.7}
.poster div{box-sizing:border-box}</style></head><body><h1 style="font-weight:500">HEADCOUNT: wall posters (generated preview)</h1>
<p style="opacity:.7">Built from the same UI tree as the game. Fonts and text fitting are approximations of Roblox Oswald / SpecialElite and TextScaled.</p><main>]] .. table.concat(
	cards
) .. "</main></body></html>"
fs.writeFile("work/posters_preview.html", html)
print("wrote work/posters_preview.html", #html)
