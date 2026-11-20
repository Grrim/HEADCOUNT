--!strict
-- UsherView (shared with Mission 001) reports what happened through the mission's Hud. On a
-- shift the same line goes to ShiftHud's notice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Hud = {}

local controllers: { [string]: any }

function Hud.result(text: string, kind: string?)
	controllers.ShiftHud.toast(text, if kind == "bad" then Ui.C.Danger else nil)
end

function Hud.init(all: { [string]: any })
	controllers = all
end

return Hud
