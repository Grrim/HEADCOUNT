--!strict
-- Both sides of being cut out: from inside, a cold world where the truth is always visible and
-- nothing can be touched; from outside, a teammate only a lens can find.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Grades = require(ReplicatedStorage.Shared.Config.Lighting)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local OffFrameView = {}

local controllers: { [string]: any }
local localPlayer = Players.LocalPlayer
local grade: ColorCorrectionEffect
local gui: ScreenGui

local function setSelfCut(cut: boolean)
	grade.Enabled = cut
	gui.Enabled = cut
	ProximityPromptService.Enabled = not cut
	controllers.Audience.offFrame = cut
	controllers.Audience.refresh()
	if cut then
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

local causeLabel: TextLabel
local rescueLabel: TextLabel
local rescueBar: Frame
local returnTitle: TextLabel
local returnBody: TextLabel
local endLabel: TextLabel
local cause = "registrar"

-- What took the player out, set by whoever saw it happen. Read when the screen is drawn.
function OffFrameView.setCause(kind: string)
	cause = kind
	if causeLabel then
		causeLabel.Text = Strings.get(`offframe_cause_{cause}`)
	end
end

local function row(parent: Instance, order: number, number: string): (TextLabel, TextLabel)
	local holder = Ui.frame({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, parent)
	Ui.mono({
		Size = UDim2.fromOffset(28, 22),
		TextSize = 15,
		FontFace = Ui.Fonts.MonoBold,
		TextColor3 = Ui.C.Accent,
		Text = number,
	}, holder)
	local title = Ui.text({
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -30, 0, 22),
		FontFace = Ui.Fonts.BodyBold,
		TextSize = 17,
		Text = "",
	}, holder)
	local body = Ui.text({
		Position = UDim2.fromOffset(30, 24),
		Size = UDim2.new(1, -30, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		TextColor3 = Ui.C.Muted,
		Text = "",
	}, holder)
	return title, body
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
	-- A card at the top of the picture: what happened, then the two ways back. The world stays
	-- visible and walkable underneath, because walking back is one of the answers.
	local frame = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.C.Ink,
		BackgroundTransparency = 0.2,
	}, gui)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }, frame)
	Ui.stroke(frame, Ui.C.Line, 0.8)
	Ui.ticks(frame, Ui.C.Danger, 10, -1)
	-- The text stacks inside its own holder: a list layout would also stack the corner ticks.
	local card = Ui.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, frame)
	Ui.pad(card, 20, 16)
	Ui.list(card, 10)
	Ui.eyebrow(Strings.get("offframe_eyebrow"), { LayoutOrder = 1, TextColor3 = Ui.C.Danger }, card)
	Ui.display({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 32,
		Text = Strings.get("offframe_title"),
	}, card)
	causeLabel = Ui.text({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		TextColor3 = Ui.C.Text,
		Text = Strings.get(`offframe_cause_{cause}`),
	}, card)
	local rescueTitle, rescueBody = row(card, 4, "1")
	rescueTitle.Text = Strings.get("offframe_way_film")
	rescueBody.Text = Strings.get("offframe_way_film_body")
	returnTitle, returnBody = row(card, 5, "2")
	returnTitle.Text = Strings.get("offframe_way_walk")
	-- Filled while a teammate holds the lens on this player.
	local rescue = Ui.frame({
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Visible = false,
	}, card)
	rescueLabel = Ui.mono({
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		FontFace = Ui.Fonts.MonoBold,
		TextColor3 = Ui.C.Accent,
		Text = Ui.spaced(Strings.get("offframe_being_filmed")),
	}, rescue)
	local track = Ui.frame({
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Ui.C.Accent,
		BackgroundTransparency = 0.75,
	}, rescue)
	rescueBar = Ui.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.C.Accent }, track)
	endLabel = Ui.mono({
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		FontFace = Ui.Fonts.MonoBold,
		TextColor3 = Ui.C.Danger,
		Visible = false,
		Text = "",
	}, card)
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	local returnAt = localPlayer:GetAttribute("SelfReturnAt")
	local wait = if typeof(returnAt) == "number" then returnAt - now else 0
	if wait > 0 then
		returnBody.Text = Strings.get("offframe_way_walk_wait", clock(wait))
		returnBody.TextColor3 = Ui.C.Muted
	else
		returnBody.Text = Strings.get("offframe_way_walk_open")
		returnBody.TextColor3 = Ui.C.Accent
	end
	if controllers.Waypoint then
		local mark = Layout.SPLICE_MARK
		controllers.Waypoint.setOverride(
			if wait <= 0 then Vector3.new(mark.x, mark.y, mark.z) else nil,
			Strings.get("leader_mark")
		)
	end
	local character = localPlayer.Character
	local progress = character and character:GetAttribute("RescueProgress")
	local filming = typeof(progress) == "number" and progress > 0 and progress < 1
	rescueLabel.Parent.Visible = filming
	rescueBar.Size = UDim2.fromScale(if filming then progress :: number else 0, 1)
	local endsAt = Workspace:GetAttribute("TapeEndsAt")
	endLabel.Visible = typeof(endsAt) == "number"
	if endLabel.Visible then
		endLabel.Text =
			Ui.spaced(Strings.get("offframe_tape_ends", clock((endsAt :: number) - now)))
	end
end

function OffFrameView.start()
	localPlayer:GetAttributeChangedSignal("OffFrame"):Connect(function()
		local cut = localPlayer:GetAttribute("OffFrame") == true
		setSelfCut(cut)
		if not cut then
			cause = "registrar"
			if controllers.Waypoint then
				controllers.Waypoint.setOverride(nil)
			end
		end
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
			refresh()
		end
	end)
end

return OffFrameView
