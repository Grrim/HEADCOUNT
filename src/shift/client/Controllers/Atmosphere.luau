--!strict
-- How the shift sounds and feels between the rooms: the ride, the silence before he moves, the
-- bell on arrival, and the grey-blue world of anyone cut out of frame.
--
-- Every ride stages one harmless omen (docs/09_GDD_V2.md §2.8): the light stutters, something
-- walks across the roof of the cabin, or the indicator shows a floor that does not exist.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Atmosphere = {}

local player = Players.LocalPlayer
local controllers: { [string]: any }
local riding = false
local rideStarted = 0
local random = Random.new()
local flashFrame: Frame

-- The motor of the cabin. Not "Hum": that one is the building, and its silence is the warning.
local RIDE_LOOP = "Projector"

local function flash(color: Color3)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 0.55
	flashFrame.Visible = true
	local fade = Ui.tween(flashFrame, TweenInfo.new(0.9), { BackgroundTransparency = 1 })
	fade.Completed:Once(function()
		flashFrame.Visible = false
	end)
end

local function liftPart(name: string): Instance?
	local map = Workspace:FindFirstChild("Map")
	local lift = map and map:FindFirstChild("Lift")
	return lift and lift:FindFirstChild(name)
end

local function flicker()
	local lamp = liftPart("LiftLamp")
	local light = lamp and lamp:FindFirstChildOfClass("PointLight")
	if not light then
		return
	end
	for _ = 1, 6 do
		light.Enabled = false
		task.wait(random:NextNumber(0.05, 0.15))
		light.Enabled = true
		task.wait(random:NextNumber(0.05, 0.3))
	end
end

local function stepsOnRoof()
	for index = 1, 5 do
		AudioDirector.playAt("Step", Vector3.new(-4 + index * 1.6, 11.5, -6), 0.9)
		task.wait(0.55)
	end
end

local function wrongFloor()
	local sign = liftPart("Indicator")
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if not label then
		return
	end
	local real = label.Text
	label.Text = "-13    PERSONS: ?"
	task.wait(0.8)
	-- The server may have moved the indicator on meanwhile; only undo our own change.
	if label.Text == "-13    PERSONS: ?" then
		label.Text = real
	end
end

local OMENS = { flicker, stepsOnRoof, wrongFloor }

local function startRide(seconds: number)
	riding = true
	rideStarted = os.clock()
	AudioDirector.setLoop(RIDE_LOOP, true, 0.3, 0.55)
	task.delay(random:NextNumber(2, math.max(2.5, seconds - 3)), function()
		if riding then
			OMENS[random:NextInteger(1, #OMENS)]()
		end
	end)
end

local function endRide()
	if not riding then
		return
	end
	riding = false
	AudioDirector.setLoop(RIDE_LOOP, false)
	AudioDirector.play("Bell", 0.6)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
	end
end

local function applyCut(cut: boolean)
	controllers.Audience.offFrame = cut
	local grade = Lighting:FindFirstChild("CutGrade") :: ColorCorrectionEffect?
	if not grade then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "CutGrade"
		made.Saturation = -0.85
		made.TintColor = Color3.fromRGB(190, 210, 255)
		made.Brightness = -0.03
		made.Parent = Lighting
		grade = made
	end
	(grade :: ColorCorrectionEffect).Enabled = cut
end

function Atmosphere.init(all: { [string]: any })
	controllers = all
end

function Atmosphere.start()
	local lastPhase = ""
	Net.get("ShiftState").OnClientEvent:Connect(function(state)
		local phase = state.phase
		if phase ~= lastPhase then
			if phase == "ride" then
				startRide(12)
			elseif phase == "return" then
				startRide(8)
			elseif riding then
				endRide()
			end
			lastPhase = phase
		end
	end)

	flashFrame = Ui.frame(
		{ Size = UDim2.fromScale(1, 1), Visible = false },
		Ui.screen("ShiftFlash", 30, true)
	)
	Net.get("RegistrarEvent").OnClientEvent:Connect(function(kind: string, id: number?)
		if kind == "preJump" then
			AudioDirector.silence(2.5)
		elseif kind == "exposure" and typeof(id) == "number" then
			-- Watching him too long registers you: the lens says how close that is.
			LensView.setWarning(id)
		elseif kind == "reach" and id == player.UserId then
			AudioDirector.play("Reach", 0.9)
			controllers.ShiftHud.toast(
				"It's reaching for you! Raise the camera (Q) and film it!",
				Ui.C.Danger
			)
			flash(Ui.C.Danger)
		elseif kind == "cut" then
			AudioDirector.play("Cut", 0.8)
			if id == player.UserId then
				flash(Color3.new(1, 1, 1))
			end
		end
	end)

	player:GetAttributeChangedSignal("OffFrame"):Connect(function()
		applyCut(player:GetAttribute("OffFrame") == true)
	end)
	applyCut(player:GetAttribute("OffFrame") == true)

	-- The cabin shudders while it moves.
	RunService.RenderStepped:Connect(function()
		if not riding then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local t = os.clock() - rideStarted
			humanoid.CameraOffset = Vector3.new(math.sin(t * 23) * 0.03, math.sin(t * 31) * 0.05, 0)
		end
	end)
end

return Atmosphere
