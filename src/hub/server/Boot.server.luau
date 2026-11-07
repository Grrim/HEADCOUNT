--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ServerScriptService.Common.Loader)
local PlayerData = require(ServerScriptService.Common.PlayerData)

print("[Headcount] Hub server build 0.1")
PlayerData.start()
Loader.run(script.Parent.Services)
