--!strict
-- Turns the Registrar's events and the player's location into the audio rules from the GDD.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Silence = {}

local controllers: { [string]: any }
local flashFrame: Frame
local blackout = false

-- A single frame of colour across the whole picture.
local function flash(color: Color3, startTransparency: number, seconds: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = startTransparency
	flashFrame.Visible = true
	local tween =
		TweenService:Create(flashFrame, TweenInfo.new(seconds), { BackgroundTransparency = 1 })
	tween.Completed:Once(function()
		flashFrame.Visible = false
	end)
	tween:Play()
end

local function reverbFor(position: Vector3): (Enum.ReverbType, boolean)
	if position.Y < -1 then
		return Enum.ReverbType.Cave, false
	end
	if position.Z < Layout.ARCHIVE.maxZ and math.abs(position.X) < Layout.ARCHIVE.maxX then
		return Enum.ReverbType.NoReverb, true -- the one room with no ambient at all
	end
	local hall = Layout.HALL
	if position.Z < hall.maxZ and position.X > hall.minX and position.X < hall.maxX then
		return Enum.ReverbType.Auditorium, false
	end
	if position.X > Layout.COATS.minX then
		return Enum.ReverbType.Room, false
	end
	return Enum.ReverbType.Hallway, false
end

function Silence.init(all: { [string]: any })
	controllers = all
	flashFrame = Ui.frame({ Size = UDim2.fromScale(1, 1), Visible = false }, Ui.screen("Flash", 30))
end

function Silence.start()
	Net.get("RegistrarEvent").OnClientEvent:Connect(function(kind: string, id: number?)
		if kind == "exposure" then
			LensView.setWarning(id :: number)
		elseif kind == "preJump" then
			AudioDirector.silence(Config.Registrar.silenceLead + 1.2)
		elseif kind == "reach" and id == Players.LocalPlayer.UserId then
			AudioDirector.play("Reach", 0.9)
			controllers.Hud.subtitle(Strings.get("reach_warning"), 2)
			flash(Palette.Rec, 0.55, 0.9)
		elseif kind == "cut" then
			AudioDirector.play("Cut", 0.9)
			if id == Players.LocalPlayer.UserId then
				flash(Color3.new(1, 1, 1), 0, 0.5)
			end
		end
	end)
	-- With the mains gone, the hum everyone had stopped noticing is gone too.
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		blackout = state.phase == "Power"
	end)
	-- Behind the lens you can hear them breathing.
	LensView.onChanged(function(raised)
		AudioDirector.setLoop("Crowd", raised, 0.35)
	end)
	task.spawn(function()
		while true do
			task.wait(0.8)
			local camera = Workspace.CurrentCamera
			if camera and not controllers.Playback.active() then
				local reverb, absolute = reverbFor(camera.CFrame.Position)
				AudioDirector.setReverb(reverb)
				AudioDirector.setAbsolute(absolute or blackout)
			end
		end
	end)
end

return Silence
