--!strict
-- Is a world point inside a camera's view cone? Plain numbers so the rule can be tested headless.
local Framing = {}

-- (lx, ly, lz) must be a unit look vector.
function Framing.isFramed(
	cx: number,
	cy: number,
	cz: number,
	lx: number,
	ly: number,
	lz: number,
	tx: number,
	ty: number,
	tz: number,
	cosHalfFov: number,
	maxDistance: number
): boolean
	local dx, dy, dz = tx - cx, ty - cy, tz - cz
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	if distance > maxDistance then
		return false
	end
	if distance < 0.001 then
		return true
	end
	local dot = (dx * lx + dy * ly + dz * lz) / distance
	return dot >= cosHalfFov
end

return Framing
