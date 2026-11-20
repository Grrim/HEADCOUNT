--!strict
-- The shift (docs/09_GDD_V2.md, docs/11_PROTOTYP.md): a lift, floors built from rooms, footage
-- for money, the Extra, code doors read off tapes, the Usher on dark floors, a saved wallet. Lens is shared with Mission 001 and mapped in by shift.project.json; it joins
-- the other services here so the loader treats it like one of them.
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ServerScriptService.Common.Loader)

print("[Headcount] Shift server 0.2 (alpha)")
local services = script.Parent:WaitForChild("Services")
script.Parent:WaitForChild("Lens").Parent = services
Loader.run(services)
