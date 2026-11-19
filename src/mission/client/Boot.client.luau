--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Affordance = require(ReplicatedStorage.ClientCommon.Affordance)
local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Brightness = require(ReplicatedStorage.ClientCommon.Brightness)
local EntryCurtain = require(ReplicatedStorage.ClientCommon.EntryCurtain)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Loader = require(ReplicatedStorage.ClientCommon.Loader)
local Net = require(ReplicatedStorage.Shared.Net)
local PromptText = require(ReplicatedStorage.ClientCommon.PromptText)
local PromptUi = require(ReplicatedStorage.ClientCommon.PromptUi)
local Props = require(ReplicatedStorage.Shared.World.Props)
local RoomTone = require(ReplicatedStorage.ClientCommon.RoomTone)
local Teaser = require(script.Parent.Teaser)
local Vignette = require(ReplicatedStorage.ClientCommon.Vignette)

-- Studio-only teaser (docs/10_TEST_FILMIKIEM.md): the real lens and Registrar, nothing else.
if Teaser.enabled() then
	print("[Headcount] Teaser (Studio only)")
	AudioDirector.start()
	LensView.init(nil)
	Teaser.run(script.Parent.Controllers.RegistrarView)
	return
end

print("[Headcount] Mission client build 0.1")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
task.spawn(function()
	-- Being cut out replaces dying, so a self-inflicted reset must not exist. SetCore can fail
	-- briefly on join, hence the retry.
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

EntryCurtain.show()
Props.preload()
AudioDirector.start()
Brightness.start()
PromptText.start()
PromptUi.start()
Affordance.start()
Vignette.start()
LensView.init(Net.get("LensState"))
Loader.run(script.Parent.Controllers)
RoomTone.start({ "Creak", "Creak", "Drip", "ChairFold" })
