--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local EntryCurtain = require(ReplicatedStorage.ClientCommon.EntryCurtain)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Loader = require(ReplicatedStorage.ClientCommon.Loader)
local PromptText = require(ReplicatedStorage.ClientCommon.PromptText)
local PromptUi = require(ReplicatedStorage.ClientCommon.PromptUi)
local Props = require(ReplicatedStorage.Shared.World.Props)
local RoomTone = require(ReplicatedStorage.ClientCommon.RoomTone)
local Vignette = require(ReplicatedStorage.ClientCommon.Vignette)

print("[Headcount] Hub client build 0.1")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

EntryCurtain.show()
Props.preload()
AudioDirector.start()
PromptText.start()
PromptUi.start()
Vignette.start()
LensView.init(nil) -- the hub's lens is purely local: nothing here is decided by it
Loader.run(script.Parent.Controllers)
RoomTone.start({ "Creak", "Drip" })
