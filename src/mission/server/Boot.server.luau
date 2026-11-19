--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ServerScriptService.Common.Loader)
local PlayerData = require(ServerScriptService.Common.PlayerData)
local Teaser = require(script.Parent.Teaser)

-- Studio-only film set for the teaser (docs/10_TEST_FILMIKIEM.md): the map, no mission.
if Teaser.enabled() then
	print("[Headcount] Teaser film set (Studio only)")
	Teaser.run(script.Parent.Services)
	return
end

print("[Headcount] Mission server build 0.1")
PlayerData.start()
Loader.run(script.Parent.Services)
