--!strict
-- Wall posters drawn entirely from UI shapes and type, so they need no uploaded images. They copy
-- the look of a 1980s community centre: flat colour, one big shape, heavy lettering, paper gone
-- yellow at the edges. A few of them are not quite right, which is the point.
local Palette = require("../Config/Palette")

local Posters = {}

local CANVAS = Vector2.new(300, 420)
local CREAM = Color3.fromRGB(226, 214, 186)
local RED = Color3.fromRGB(184, 46, 38)
local INK = Color3.fromRGB(24, 22, 22)
local NAVY = Color3.fromRGB(28, 40, 66)
local MUSTARD = Color3.fromRGB(206, 160, 52)

local function make(className: string, props: { [string]: any }, parent: Instance): any
	local item: any = Instance.new(className)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function block(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	rot: number?
): Frame
	return make("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rot or 0,
	}, parent)
end

local function disc(parent: Instance, x: number, y: number, size: number, color: Color3): Frame
	local frame = block(parent, x, y, size, size, color)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	return frame
end

local function words(
	parent: Instance,
	text: string,
	y: number,
	height: number,
	color: Color3,
	font: Enum.Font,
	x: number?,
	width: number?,
	align: Enum.TextXAlignment?
): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x or 18, y),
		Size = UDim2.fromOffset(width or (CANVAS.X - 36), height),
		Font = font,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = align or Enum.TextXAlignment.Center,
	}, parent)
end

-- Old paper: darker, warmer edges and a faint stain.
local function age(sheet: Frame)
	local wear = block(sheet, 0, 0, CANVAS.X, CANVAS.Y, Color3.fromRGB(120, 92, 52))
	wear.ZIndex = 20
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.12, 0.92),
			NumberSequenceKeypoint.new(0.88, 0.92),
			NumberSequenceKeypoint.new(1, 0.5),
		}),
		Rotation = 90,
	}, wear)
	local stain = disc(sheet, 196, 300, 90, Color3.fromRGB(150, 118, 70))
	stain.BackgroundTransparency = 0.95
	stain.ZIndex = 21
end

local DESIGNS: { [string]: (sheet: Frame) -> () } = {}

-- The meeting itself, announced in red and black.
DESIGNS.meeting = function(sheet)
	sheet.BackgroundColor3 = CREAM
	disc(sheet, 60, 40, 180, RED)
	block(sheet, 0, 150, CANVAS.X, 10, INK)
	words(sheet, "GENERAL", 178, 54, INK, Enum.Font.Oswald)
	words(sheet, "MEETING", 228, 64, INK, Enum.Font.Oswald)
	words(sheet, "12.11  18:00", 300, 34, RED, Enum.Font.Oswald)
	words(sheet, "ATTENDANCE IS COMPULSORY", 350, 24, INK, Enum.Font.SpecialElite)
	words(sheet, '"JUTRZENKA" COMMUNITY CENTRE', 380, 18, INK, Enum.Font.SpecialElite)
end

-- The cinema bill: an audience in rows, every face censored.
DESIGNS.cinema = function(sheet)
	sheet.BackgroundColor3 = NAVY
	words(sheet, "CINEMA", 22, 40, MUSTARD, Enum.Font.Oswald)
	words(sheet, "THE FILM OF THE YEAR", 64, 26, CREAM, Enum.Font.Oswald)
	for row = 0, 3 do
		for col = 0, 4 do
			local x = 34 + col * 48 + (row % 2) * 12
			local y = 120 + row * 52
			disc(sheet, x, y, 30, CREAM)
			block(sheet, x + 2, y + 10, 26, 6, INK)
			block(sheet, x - 4, y + 30, 38, 18, CREAM)
		end
	end
	block(sheet, 18, 340, CANVAS.X - 36, 4, MUSTARD)
	words(sheet, "EVERY SEAT TAKEN", 352, 30, CREAM, Enum.Font.Oswald)
	words(sheet, "NO ONE LEAVES DURING THE SCREENING", 388, 18, MUSTARD, Enum.Font.SpecialElite)
end

-- A safety notice in warning stripes.
DESIGNS.safety = function(sheet)
	sheet.BackgroundColor3 = CREAM
	sheet.ClipsDescendants = true
	for index = -4, 10 do
		block(sheet, index * 46, -60, 22, 260, RED, 35)
	end
	block(sheet, 0, 150, CANVAS.X, CANVAS.Y - 150, CREAM)
	words(sheet, "NOTICE", 168, 50, RED, Enum.Font.Oswald)
	words(sheet, "DO NOT LOOK", 228, 40, INK, Enum.Font.Oswald)
	words(sheet, "BEHIND YOU", 268, 40, INK, Enum.Font.Oswald)
	words(sheet, "DURING THE MEETING", 314, 28, INK, Enum.Font.Oswald)
	words(sheet, "THE MANAGEMENT", 372, 20, RED, Enum.Font.SpecialElite)
end

-- The choir: a rising sun of rays, the house's name, and a number that is too exact.
DESIGNS.choir = function(sheet)
	sheet.BackgroundColor3 = MUSTARD
	sheet.ClipsDescendants = true
	local cx, cy = CANVAS.X / 2, 210
	for index = 0, 11 do
		local ray = block(sheet, cx - 8, cy - 230, 16, 460, CREAM, index * 15)
		ray.BackgroundTransparency = 0.35
	end
	disc(sheet, cx - 70, cy - 70, 140, RED)
	block(sheet, 0, cy, CANVAS.X, CANVAS.Y - cy, NAVY)
	words(sheet, "JUTRZENKA", 236, 50, CREAM, Enum.Font.Oswald)
	words(sheet, "CHOIR", 288, 40, MUSTARD, Enum.Font.Oswald)
	words(sheet, "192 VOICES", 340, 30, CREAM, Enum.Font.Oswald)
	words(sheet, "ALL OF THEM STILL HERE", 382, 18, MUSTARD, Enum.Font.SpecialElite)
end

-- A missing-person notice. The photograph is only a tall shape whose neck leaves the frame.
DESIGNS.missing = function(sheet)
	sheet.BackgroundColor3 = Color3.fromRGB(232, 228, 216)
	words(sheet, "HAVE YOU SEEN", 20, 40, INK, Enum.Font.Oswald)
	words(sheet, "THIS MAN?", 60, 44, RED, Enum.Font.Oswald)
	local photo = block(sheet, 50, 120, 200, 200, Color3.fromRGB(170, 168, 160))
	photo.ClipsDescendants = true
	-- Shoulders with rounded tops, and a neck far too long that leaves the top of the picture.
	local shoulders = block(photo, 40, 128, 120, 90, INK)
	make("UICorner", { CornerRadius = UDim.new(0.22, 0) }, shoulders)
	block(photo, 93, -10, 14, 150, INK)
	-- An old print: the edges of the photograph darken.
	local shade = block(photo, 0, 0, 200, 200, INK)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.25, 1),
			NumberSequenceKeypoint.new(0.75, 1),
			NumberSequenceKeypoint.new(1, 0.55),
		}),
	}, shade)
	words(sheet, "TALL. GREY SUIT. NO FACE ON RECORD.", 330, 26, INK, Enum.Font.SpecialElite)
	words(sheet, "IF SEEN: DO NOT LOOK FOR LONG", 366, 22, RED, Enum.Font.SpecialElite)
	words(sheet, "REPORT TO THE REGISTRY", 392, 18, INK, Enum.Font.SpecialElite)
end

-- We count on you: twelve rows of sixteen, one square filled in by hand.
DESIGNS.headcount = function(sheet)
	sheet.BackgroundColor3 = CREAM
	words(sheet, "WE COUNT", 20, 46, INK, Enum.Font.Oswald)
	words(sheet, "ON YOU", 64, 46, RED, Enum.Font.Oswald)
	for row = 0, 11 do
		for col = 0, 15 do
			local square = block(sheet, 30 + col * 15, 128 + row * 15, 11, 11, INK)
			square.BackgroundTransparency = 0.7
		end
	end
	block(sheet, 30 + 9 * 15, 128 + 2 * 15, 11, 11, RED)
	words(sheet, "192 + 1", 322, 44, INK, Enum.Font.Oswald)
	words(sheet, "EVERY ONE OF US IS ON THE LIST", 376, 20, RED, Enum.Font.SpecialElite)
end

Posters.KINDS = { "meeting", "cinema", "safety", "choir", "missing", "headcount" }

-- Hangs one poster. `centre` is the middle of its face and `normal` the way it faces, out of the
-- wall into the room. Height follows from the canvas shape. `tilt` in degrees, for a crooked one.
function Posters.hang(
	parent: Instance,
	kind: string,
	centre: Vector3,
	normal: Vector3,
	width: number,
	tilt: number?
): Part
	local height = width * CANVAS.Y / CANVAS.X
	local part = Instance.new("Part")
	part.Name = `Poster_{kind}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = Vector3.new(width, height, 0.06)
	part.Color = CREAM
	part.Material = Enum.Material.Fabric
	-- Front (the face with the picture) looks along the normal; the back sits 0.04 off the wall.
	local origin = centre + normal.Unit * 0.07
	part.CFrame = CFrame.lookAt(origin, origin + normal) * CFrame.Angles(0, 0, math.rad(tilt or 0))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = CANVAS
	-- Later shapes draw over earlier ones, the way the designs are written.
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Lit like the room: a poster in the dark is dark.
	gui.LightInfluence = 1
	gui.Brightness = 1.4
	gui.MaxDistance = 90
	gui.Parent = part
	local sheet = make("Frame", {
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CREAM,
	}, gui)
	local design = DESIGNS[kind] or DESIGNS.meeting
	design(sheet)
	age(sheet)
	-- A sliver of tape at the top corners.
	for _, x in { 8, CANVAS.X - 48 } do
		local tape = block(sheet, x, -6, 40, 18, Palette.Paper, if x < 50 then -12 else 12)
		tape.BackgroundTransparency = 0.25
		tape.ZIndex = 30
	end
	part.Parent = parent
	return part
end

return Posters
