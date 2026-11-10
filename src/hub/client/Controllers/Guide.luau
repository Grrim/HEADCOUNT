--!strict
-- The lobby's one voice for "what now": the same case-file objective card, key-cap chip and
-- distance marker the mission uses, so the first minute teaches the look of the whole game.
--   take    take the camera from the desk         (marker on the camcorder)
--   raise   [Q] raise the camera
--   again   [Q] lower it and raise it again
--   go      sign up for an expedition             (marker on the terminal)
--   chosen  PLAY SOLO, or an expedition with friends; meanwhile, look around through the lens
-- Intro.luau decides the step; this file only draws it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Guide = {}

local METRES_PER_STUD = 0.28

local gui: ScreenGui
local card: Frame
local titleLabel: TextLabel
local stepLabel: TextLabel
local chip: Frame
local keyLabel: TextLabel
local chipText: TextLabel
local marker: Frame
local markerName: TextLabel
local markerDistance: TextLabel
local target: BasePart? = nil
local current = ""

type Step = {
	title: string,
	line: string?,
	key: string?,
	chip: string?,
	target: (() -> BasePart?)?,
	targetName: string?,
}

local function tagged(tag: string): () -> BasePart?
	return function()
		local found = CollectionService:GetTagged(tag)[1]
		return if found and found:IsA("BasePart") then found else nil
	end
end

local function lensKey(): string
	local device = Ui.device()
	return if device == "touch"
		then Strings.get("btn_lens")
		elseif device == "gamepad" then "L2"
		else "Q"
end

local STEPS: { [string]: Step } = {
	take = {
		title = "guide_take",
		target = tagged("IntroCamera"),
		targetName = "obj_camera",
	},
	raise = { title = "guide_raise", key = "lens", chip = "guide_raise_chip" },
	look = { title = "guide_look", key = "lens", chip = "guide_lower_chip" },
	again = { title = "guide_raise", key = "lens", chip = "guide_again_chip" },
	go = {
		title = "guide_go",
		line = "guide_go_line",
		target = tagged("ExpeditionTerminal"),
		targetName = "guide_terminal",
	},
	chosen = { title = "guide_chosen", line = "guide_chosen_line" },
}

local function showChip(step: Step)
	if not step.chip then
		chip.Visible = false
		return
	end
	keyLabel.Text = lensKey()
	chipText.Text = Strings.get(step.chip)
	chip.Visible = true
	chip.Position = UDim2.new(0.5, 0, 1, 40)
	Ui.tween(chip, Ui.Motion.Base, { Position = UDim2.new(0.5, 0, 1, -14) })
end

function Guide.set(id: string)
	if id == current then
		return
	end
	current = id
	local step = STEPS[id]
	if not step then
		card.Visible = false
		chip.Visible = false
		target = nil
		return
	end
	titleLabel.Text = Strings.get(step.title)
	stepLabel.Text = if step.line then "›  " .. Strings.get(step.line) else ""
	stepLabel.Visible = step.line ~= nil
	card.Visible = not LensView.raised
	-- A new order arrives with a brief flare of the card.
	card.BackgroundTransparency = 0
	Ui.tween(card, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.25 })
	showChip(step)
	target = if step.target then step.target() else nil
	markerName.Text = if step.targetName then Strings.get(step.targetName) else ""
end

function Guide.init()
	gui = Ui.screen("HubGuide", 2)
	card = Ui.frame({
		Name = "Objective",
		Position = UDim2.fromOffset(16, if Ui.compact() then 52 else 64),
		Size = UDim2.new(if Ui.compact() then 0.44 else 0.34, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.C.Ink,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, gui)
	Ui.make(
		"UISizeConstraint",
		{ MaxSize = Vector2.new(440, math.huge), MinSize = Vector2.new(250, 0) },
		card
	)
	Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.75, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, card)
	Ui.frame({ Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Ui.C.Danger }, card)
	local body = Ui.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, card)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 28),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
	}, body)
	Ui.list(body, 4)
	Ui.eyebrow(Strings.get("guide_eyebrow"), { LayoutOrder = 1, TextColor3 = Ui.C.Danger }, body)
	titleLabel = Ui.display({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = if Ui.compact() then 18 else 21,
		Text = "",
	}, body)
	stepLabel = Ui.text({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = if Ui.compact() then 14 else 16,
		TextColor3 = Ui.C.Accent,
		Text = "",
	}, body)

	chip = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 40),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Ui.C.Ink,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, gui)
	Ui.stroke(chip, Ui.C.Accent, 0.6)
	Ui.pad(chip, 10, 8)
	Ui.list(chip, 10, true).VerticalAlignment = Enum.VerticalAlignment.Center
	keyLabel = Ui.keycap("Q", { LayoutOrder = 1, BackgroundColor3 = Ui.C.Accent }, chip)
	chipText = Ui.text({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Ui.Fonts.BodyBold,
		TextSize = if Ui.compact() then 15 else 17,
		TextWrapped = false,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	}, chip)

	local markerGui = Ui.screen("HubMarker", 1, true)
	marker = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(160, 60),
		BackgroundTransparency = 1,
		Visible = false,
	}, markerGui)
	local diamond = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(12, 12),
		Rotation = 45,
		BackgroundColor3 = Ui.C.Accent,
	}, marker)
	Ui.stroke(diamond, Ui.C.Ink, 0.3, 1.5)
	markerName = Ui.text({
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Ui.Fonts.BodyBold,
		TextSize = 14,
		TextColor3 = Ui.C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.45,
		TextWrapped = false,
		Text = "",
	}, marker)
	markerDistance = Ui.mono({
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.45,
		Text = "",
	}, marker)
end

function Guide.start()
	-- The viewfinder takes the top of the screen; the chip at the bottom carries the instruction.
	LensView.onChanged(function(raised)
		if current ~= "" and STEPS[current] then
			card.Visible = not raised
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local goal = target
		local panelOpen = false
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		local terminalGui = playerGui and playerGui:FindFirstChild("Terminal")
		local panel = terminalGui and terminalGui:FindFirstChildWhichIsA("Frame")
		panelOpen = panel ~= nil and panel.Visible
		if
			not goal
			or not goal.Parent
			or not camera
			or not root
			or LensView.raised
			or panelOpen
		then
			marker.Visible = false
			return
		end
		local position = goal.Position
		local distance = (position - root.Position).Magnitude
		if distance < 7 then
			marker.Visible = false
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(position + Vector3.new(0, 1.2, 0))
		local size = camera.ViewportSize
		local margin = 64
		local x, y = point.X, point.Y
		if not onScreen or point.Z < 0 then
			local flat = camera.CFrame:PointToObjectSpace(position)
			local direction = Vector2.new(flat.X, -flat.Y)
			if direction.Magnitude < 0.001 then
				direction = Vector2.new(0, 1)
			end
			direction = direction.Unit
			local centre = size / 2
			local reach = math.min(
				(centre.X - margin) / math.max(math.abs(direction.X), 0.001),
				(centre.Y - margin) / math.max(math.abs(direction.Y), 0.001)
			)
			x, y = centre.X + direction.X * reach, centre.Y + direction.Y * reach
		else
			x = math.clamp(x, margin, size.X - margin)
			y = math.clamp(y, margin, size.Y - margin)
		end
		marker.Visible = true
		marker.Position = UDim2.fromOffset(x, y - 10)
		markerDistance.Text = string.format("%d m", math.floor(distance * METRES_PER_STUD + 0.5))
	end)
end

return Guide
