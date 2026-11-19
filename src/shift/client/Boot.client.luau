--!strict
-- The shift prototype's client. RegistrarView is Mission 001's controller, mapped in by
-- shift.project.json and moved into Controllers here so it loads with the rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Loader = require(ReplicatedStorage.ClientCommon.Loader)
local Net = require(ReplicatedStorage.Shared.Net)
local Props = require(ReplicatedStorage.Shared.World.Props)

print("[Headcount] Shift prototype client 0.1")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			return
		end
		task.wait(1)
	end
end)

Props.preload()
AudioDirector.start()
LensView.init(Net.get("LensState"))
local controllers = script.Parent:WaitForChild("Controllers")
script.Parent:WaitForChild("RegistrarView").Parent = controllers
Loader.run(controllers)
