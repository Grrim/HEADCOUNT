--!strict
-- The shift prototype (docs/09_GDD_V2.md, docs/11_PROTOTYP.md): a lift, floors built from rooms,
-- footage for money. Lens is shared with Mission 001 and mapped in by shift.project.json; it joins
-- the other services here so the loader treats it like one of them.
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ServerScriptService.Common.Loader)

print("[Headcount] Shift prototype server 0.1")
local services = script.Parent:WaitForChild("Services")
script.Parent:WaitForChild("Lens").Parent = services
Loader.run(services)
