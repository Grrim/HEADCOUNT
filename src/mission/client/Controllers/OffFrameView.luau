--!strict
-- Both sides of being cut out: from inside, a cold world where the truth is always visible and
-- nothing can be touched; from outside, a teammate only a lens can find.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Grades = require(ReplicatedStorage.Shared.Config.Lighting)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local OffFrameView = {}

local controllers: { [string]: any }
local localPlayer = Players.LocalPlayer
local grade: ColorCorrectionEffect
local gui: ScreenGui
local returnLabel: TextLabel
local cutSince = 0

local function setSelfCut(cut: boolean)
	grade.Enabled = cut
	gui.Enabled = cut
	ProximityPromptService.Enabled = not cut
	controllers.Audience.offFrame = cut
	controllers.Audience.refresh()
	if cut then
		cutSince = os.clock()
		LensView.setRaised(false)
		LensView.setLocked(true)
		if controllers.Playback.active() then
			controllers.Playback.stop()
			LensView.setLocked(true)
		end
		Input.bind("Knock", function()
			Net.get("Knock"):FireServer()
			AudioDirector.play("Knock", 0.7)
		end, { Enum.KeyCode.K, Enum.KeyCode.ButtonX }, Strings.get("btn_knock"), 1)
	else
		LensView.setLocked(false)
		Input.unbind("Knock")
	end
end

-- Other players' bodies: invisible to the eye, faint through a lens.
local function updateOthers()
	local lensUp = LensView.raised
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer and other.Character then
			local cut = other:GetAttribute("OffFrame") == true
			local modifier = 0
			if cut then
				modifier = if lensUp then 0.35 else 1
			end
			for _, item in other.Character:GetDescendants() do
				if item:IsA("BasePart") or item:IsA("Decal") then
					(item :: any).LocalTransparencyModifier = modifier
				end
			end
		end
	end
end

function OffFrameView.init(all: { [string]: any })
	controllers = all
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "OffFrameGrade"
	grade.Enabled = false
	for key, value in Grades.OffFrame do
		(grade :: any)[key] = value
	end
	grade.Parent = Lighting
	gui = Ui.screen("OffFrame", 3)
	gui.Enabled = false
	Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromOffset(520, 36),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.Paper,
		Text = Strings.get("offframe_title"),
	}, gui)
	Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.new(0.6, 0, 0, 70),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("offframe_help"),
	}, gui)
	returnLabel = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.new(0.6, 0, 0, 30),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.Crt,
		-- Sits over whatever the player faces, posters included.
		TextStrokeTransparency = 0.2,
		Visible = false,
		Text = Strings.get("offframe_return"),
	}, gui)
end

function OffFrameView.start()
	localPlayer:GetAttributeChangedSignal("OffFrame"):Connect(function()
		setSelfCut(localPlayer:GetAttribute("OffFrame") == true)
	end)
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.2 then
			return
		end
		accumulated = 0
		updateOthers()
		if gui.Enabled then
			returnLabel.Visible = os.clock() - cutSince >= Config.OffFrame.SelfReturnAfter
		end
	end)
end

return OffFrameView
