--!strict
-- The mission HUD. Four things, each in its own place and voice, so the player never has to work
-- out which is which:
--   objective   top left: what we are doing (case-file card) and the next concrete move
--   radio       bottom centre, amber RADIO tag: the dispatcher, one line at a time, queued
--   result      just under the centre: what an action did ("Reel A found", "Nothing here")
--   documents   a typed sheet of paper in the middle of the screen
-- Pings from teammates float in the world where they were called.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Hud = {}

-- A guess that came to nothing gets one dry click and a muted line, so a wrong answer is heard
-- as well as read and never looks like progress.
local WRONG_ANSWERS = {
	seat_empty = true,
	hook_empty = true,
	code_wrong = true,
	reel_wrong = true,
	need_reels = true,
	need_power = true,
	tape_still_left = true,
	tape_too_short = true,
}
-- Real progress: a bright line and a rising click.
local PROGRESS = {
	seat_found = true,
	hook_found = true,
	reel_loaded = true,
	code_right = true,
	tape_refilled = true,
	restored = true,
}

local CHAPTERS = {
	Protocol = { "I", "chapter_Protocol" },
	Power = { "II", "chapter_Power" },
	Projector = { "III", "chapter_Projector" },
	Door = { "IV", "chapter_Door" },
	Register = { "IV", "chapter_Door" },
	Climax = { "V", "chapter_Climax" },
}

local controllers: { [string]: any }
local gui: ScreenGui
local objectiveCard: Frame
local chapterLabel: TextLabel
local objectiveLabel: TextLabel
local stepLabel: TextLabel
local reelRow: Frame
local reelPips: { Frame } = {}
local subtitleLabel: TextLabel
local resultLabel: TextLabel
local resultToken = 0
local docShade: Frame
local docSheet: Frame
local docTitle: TextLabel
local docBody: TextLabel
local docOpenedAt: Vector3? = nil
local commPanel: Frame
local lastPhase = ""
local teamStrip: Frame
local cinema = false
local cardRestAt = 0

-- Radio lines queue rather than cut each other off; a line never shows for less than its time.
type Line = { text: string, seconds: number }
local radioQueue: { Line } = {}
local radioBusy = false
local subtitleUntil = 0

-- Player names and story text go into rich text, so anything that looks like a tag is escaped.
local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- The dispatcher speaks behind an amber RADIO tag, so a voice on the radio never reads like the
-- player's own thought, and a teammate's call reads as theirs.
local function styled(text: string): (string, boolean)
	local rest = text:match("^RADIO: (.*)$")
	if rest then
		return `<font color="#E8B25C" face="RobotoMono" weight="bold">RADIO</font>   {escape(rest)}`,
			true
	end
	return escape(text), false
end

local function showLine(line: Line)
	local text, isRadio = styled(line.text)
	subtitleLabel.Text = text
	subtitleLabel.TextTransparency = 0
	subtitleUntil = os.clock() + line.seconds
	if isRadio then
		AudioDirector.play("Radio", 0.12, 1.15)
	end
	task.wait(line.seconds)
	if os.clock() >= subtitleUntil - 0.05 and #radioQueue == 0 then
		Ui.tween(subtitleLabel, TweenInfo.new(0.5), { TextTransparency = 1 })
	end
end

local function pumpRadio()
	if radioBusy then
		return
	end
	radioBusy = true
	while #radioQueue > 0 do
		showLine(table.remove(radioQueue, 1) :: Line)
	end
	radioBusy = false
end

function Hud.subtitle(text: string, seconds: number?)
	local duration = seconds or math.clamp(#text / 15, 3.5, 9)
	-- An identical line already waiting adds nothing.
	for _, waiting in radioQueue do
		if waiting.text == text then
			return
		end
	end
	-- Never let the queue run far behind the game: old lines give way.
	while #radioQueue >= 2 do
		table.remove(radioQueue, 1)
	end
	table.insert(radioQueue, { text = text, seconds = duration })
	task.spawn(pumpRadio)
end

-- True while a line is on screen and not yet fading out.
function Hud.isSpeaking(): boolean
	return subtitleLabel.Visible
		and subtitleLabel.Text ~= ""
		and subtitleLabel.TextTransparency < 0.5
end

-- What an action just did. kind: "good", "bad" or "info".
function Hud.result(text: string, kind: string?)
	resultToken += 1
	local token = resultToken
	local color = if kind == "good"
		then Ui.C.Accent
		elseif kind == "bad" then Ui.C.Muted
		else Ui.C.Text
	local mark = if kind == "good" then "✓  " elseif kind == "bad" then "×  " else ""
	resultLabel.Text = mark .. text
	resultLabel.TextColor3 = color
	resultLabel.TextTransparency = 0
	local scale = resultLabel:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = if kind == "good" then 1.1 else 1.03
	Ui.tween(scale, Ui.Motion.Base, { Scale = 1 })
	if kind == "bad" then
		-- A small shake of the head.
		resultLabel.Position = UDim2.new(0.5, 8, 0.62, 0)
		Ui.tween(
			resultLabel,
			TweenInfo.new(0.35, Enum.EasingStyle.Elastic),
			{ Position = UDim2.fromScale(0.5, 0.62) }
		)
	end
	task.delay(math.max(2.4, #text / 16), function()
		if token == resultToken then
			Ui.tween(resultLabel, Ui.Motion.Slow, { TextTransparency = 1 })
		end
	end)
end

local function applyVisibility()
	-- Out of frame, the cut screen takes the top of the picture and says what to do instead.
	local cut = Players.LocalPlayer:GetAttribute("OffFrame") == true
	objectiveCard.Visible = not LensView.raised and not cinema and not cut
	Input.setTouchVisible(not cinema)
end

local function hideDoc()
	if not docShade.Visible then
		return
	end
	docOpenedAt = nil
	ContextActionService:UnbindAction("CloseDoc")
	local fade = Ui.tween(docShade, Ui.Motion.Quick, { BackgroundTransparency = 1 })
	Ui.tween(docSheet, Ui.Motion.Quick, { Position = UDim2.fromScale(0.5, 0.56) })
	fade.Completed:Once(function()
		if docOpenedAt == nil then
			docShade.Visible = false
		end
	end)
end

local function showPanel(title: string, body: string)
	docTitle.Text = title
	docBody.Text = body
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	docOpenedAt = if root then root.Position else Vector3.zero
	docShade.Visible = true
	docShade.BackgroundTransparency = 1
	Ui.tween(docShade, Ui.Motion.Base, { BackgroundTransparency = 0.45 })
	-- The sheet is slid up into view and lands slightly askew, like paper put down on a desk.
	docSheet.Position = UDim2.fromScale(0.5, 0.58)
	docSheet.Rotation = -2.5
	Ui.tween(docSheet, Ui.Motion.Base, { Position = UDim2.fromScale(0.5, 0.5), Rotation = -0.8 })
	-- A controller has no cursor; B closes the page while one is open and is a radio call the
	-- rest of the time. Backspace and X do the same on a keyboard.
	ContextActionService:BindActionAtPriority(
		"CloseDoc",
		function(_, state)
			if state == Enum.UserInputState.Begin then
				hideDoc()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.Backspace,
		Enum.KeyCode.X
	)
	AudioDirector.play("Paper", 0.5)
end

local function pingAt(position: Vector3, text: string)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position + Vector3.new(0, 4, 0)
	holder.Parent = Workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(180, 54)
	board.AlwaysOnTop = true
	board.MaxDistance = 200
	board.Parent = holder
	local marker = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(12, 12),
		Rotation = 45,
		BackgroundColor3 = Ui.C.Radio,
	}, board)
	local label = Ui.text({
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = Ui.Fonts.BodyBold,
		TextSize = 18,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.C.Radio,
		TextStrokeTransparency = 0.4,
	}, board)
	local info = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 3)
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	TweenService:Create(marker, info, { BackgroundTransparency = 1 }):Play()
	task.delay(4.2, function()
		holder:Destroy()
	end)
end

local function sendComm(kind: number)
	Net.get("QuickComm"):FireServer(kind)
end

local function buildObjective()
	local compact = Ui.compact()
	-- The objective sits on a case-file card: a red rule, the chapter, the order, the next move.
	objectiveCard = Ui.frame({
		Name = "Objective",
		Position = UDim2.fromOffset(16, if compact then 52 else 64),
		Size = UDim2.new(if compact then 0.44 else 0.36, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.C.Ink,
		BackgroundTransparency = 0.25,
	}, gui)
	Ui.make(
		"UISizeConstraint",
		{ MaxSize = Vector2.new(460, math.huge), MinSize = Vector2.new(250, 0) },
		objectiveCard
	)
	Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.75, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, objectiveCard)
	Ui.frame({
		Name = "Rule",
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Ui.C.Danger,
	}, objectiveCard)
	local body = Ui.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, objectiveCard)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 28),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
	}, body)
	Ui.list(body, 4)
	chapterLabel = Ui.eyebrow(Strings.get("hud_objective"), {
		LayoutOrder = 1,
		TextColor3 = Ui.C.Danger,
		TextSize = if compact then 11 else 12,
	}, body)
	objectiveLabel = Ui.display({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = if compact then 18 else 21,
		LineHeight = 1.05,
		Text = "",
	}, body)
	-- The concrete next move, worked out by the notebook from what this player knows.
	stepLabel = Ui.text({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = if compact then 14 else 16,
		TextColor3 = Ui.C.Accent,
		Text = "",
		Visible = false,
	}, body)
	-- Three reel pips while the reels are still being found: the whole goal of part one at a glance.
	reelRow = Ui.frame({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Visible = false,
	}, body)
	Ui.list(reelRow, 6, true).VerticalAlignment = Enum.VerticalAlignment.Center
	Ui.mono({
		LayoutOrder = 0,
		Size = UDim2.fromOffset(52, 20),
		TextSize = 12,
		FontFace = Ui.Fonts.MonoBold,
		TextColor3 = Ui.C.Muted,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = Ui.spaced("REELS"),
	}, reelRow)
	for index = 1, 3 do
		local pip = Ui.frame({
			LayoutOrder = index,
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Ui.C.Accent,
			BackgroundTransparency = 1,
		}, reelRow)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pip)
		Ui.stroke(pip, Ui.C.Accent, 0.2, 1.5)
		table.insert(reelPips, pip)
	end
end

local function buildDocument()
	-- A dimmed room behind a sheet of typed paper.
	docShade = Ui.frame({
		Name = "Document",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	}, gui)
	docSheet = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0.8, 0),
		BackgroundColor3 = Ui.C.Paper,
		ZIndex = 11,
	}, docShade)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(560, 440) }, docSheet)
	-- Paper darkens towards its edges.
	Ui.make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(246, 240, 228)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 192, 164)),
		}),
		Rotation = 70,
	}, docSheet)
	Ui.pad(docSheet, 30, 24)
	local stamp = Ui.mono({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(150, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		FontFace = Ui.Fonts.MonoBold,
		TextColor3 = Ui.C.Danger,
		TextXAlignment = Enum.TextXAlignment.Right,
		Rotation = 3,
		Text = Ui.spaced("ARCHIVE 03 · COPY"),
		ZIndex = 12,
	}, docSheet)
	stamp.TextTransparency = 0.2
	docTitle = Ui.text({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = Ui.Fonts.Type,
		TextSize = 24,
		TextColor3 = Ui.C.PaperInk,
		ZIndex = 12,
		Text = "",
	}, docSheet)
	Ui.frame({
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Ui.C.PaperInk,
		BackgroundTransparency = 0.7,
		ZIndex = 12,
	}, docSheet)
	docBody = Ui.text({
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -128),
		FontFace = Ui.Fonts.Type,
		TextSize = 19,
		LineHeight = 1.25,
		TextColor3 = Ui.C.PaperInk,
		ZIndex = 12,
		Text = "",
	}, docSheet)
	Ui.make("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 13 }, docBody)
	docBody.TextScaled = true
	local close = Ui.button("CLOSE", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(120, 40),
		BackgroundColor3 = Ui.C.PaperInk,
		TextColor3 = Ui.C.Paper,
		BorderColor3 = Ui.C.PaperInk,
		ZIndex = 12,
		-- Modal releases the cursor from first-person lock, or the click can never reach it.
		Modal = true,
	}, docSheet, hideDoc)
	close.FontFace = Ui.Fonts.MonoBold
	if Ui.device() == "keyboard" then
		Ui.mono({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, -130, 0, 40),
			TextSize = 13,
			TextColor3 = Ui.C.PaperInk,
			TextTransparency = 0.45,
			TextYAlignment = Enum.TextYAlignment.Center,
			Text = "[X] close",
			ZIndex = 12,
		}, docSheet)
	end
end

-- Who else is on the tape: one line per teammate, a dot that turns red with OUT OF FRAME when
-- they need filming back. Only drawn with company; a solo player has nobody to track.
local function refreshTeam()
	for _, child in teamStrip:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local others = {}
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			table.insert(others, player)
		end
	end
	teamStrip.Visible = #others > 0 and objectiveCard.Visible
	for index, player in others do
		local cut = player:GetAttribute("OffFrame") == true
		Ui.text({
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 18),
			FontFace = Ui.Fonts.BodyBold,
			TextSize = 14,
			RichText = true,
			TextColor3 = if cut then Ui.C.Danger else Ui.C.Muted,
			TextStrokeTransparency = 0.6,
			Text = if cut
				then `● {escape(player.DisplayName)}  <font face="RobotoMono">{Strings.get(
					"team_out"
				)}</font>`
				else `● {escape(player.DisplayName)}`,
		}, teamStrip)
	end
end

local function buildGui()
	gui = Ui.screen("MissionHud", 2)
	buildObjective()
	teamStrip = Ui.frame({
		Name = "Team",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 22, 0, 0),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	Ui.list(teamStrip, 2)
	subtitleLabel = Ui.caption({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		TextSize = if Ui.compact() then 16 else 19,
		RichText = true,
		Text = "",
		ZIndex = 5,
	}, gui, 820)
	resultLabel = Ui.caption({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		FontFace = Ui.Fonts.BodyBold,
		TextSize = if Ui.compact() then 17 else 20,
		Text = "",
		ZIndex = 6,
	}, gui, 560)
	Ui.make("UIScale", {}, resultLabel)
	buildDocument()

	-- Touch players get the four radio calls next to the radio button.
	commPanel = Ui.frame({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -270, 1, -86),
		Size = UDim2.fromOffset(132, 4 * 50),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
	}, gui)
	Ui.list(commPanel, 6)
	for kind = 1, 4 do
		Ui.button(
			Strings.get(`comm_{kind}`),
			{
				LayoutOrder = kind,
				Size = UDim2.new(1, 0, 0, 44),
				TextSize = 16,
				ZIndex = 9,
			},
			commPanel,
			function()
				sendComm(kind)
				commPanel.Visible = false
				Input.setState("CommPanel", "idle")
			end
		)
	end
end

-- A new order arrives with a brief flare of the card; after a while the card settles back so it
-- never competes with the room.
local function flare()
	objectiveCard.BackgroundTransparency = 0
	Ui.tween(
		objectiveCard,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad),
		{ BackgroundTransparency = 0.25 }
	)
	local scale = objectiveCard:FindFirstChildOfClass("UIScale")
		or Ui.make("UIScale", {}, objectiveCard)
	scale.Scale = 1.03
	Ui.tween(scale, Ui.Motion.Base, { Scale = 1 })
	cardRestAt = os.clock() + 14
end

function Hud.setStep(text: string, step: any?)
	if controllers.Waypoint then
		controllers.Waypoint.setStep(step)
	end
	if text == "" then
		stepLabel.Text = ""
		stepLabel.Visible = false
		return
	end
	local line = `›  {text}`
	if line ~= stepLabel.Text then
		stepLabel.Text = line
		stepLabel.Visible = true
		flare()
	end
end

-- Reopened from the notebook: the same page the player first read.
function Hud.showDoc(docId: string)
	showPanel(Strings.get(`{docId}_title`), Strings.get(`{docId}_body`))
end

local function registerLines(names: { string }): string
	local lines = { "...", "190. Kowal, J.", "191. Nowina, A.", "192. Sadek, R." }
	for index, name in names do
		table.insert(lines, `{192 + index}. {name}`)
	end
	return table.concat(lines, "\n")
end

function Hud.showRegister(names: { string })
	showPanel(Strings.get("register_title"), registerLines(names))
end

-- Tapes and the ending own the whole picture.
function Hud.setCinema(on: boolean)
	cinema = on
	if on then
		-- A tape takes the whole picture: a document left open must not sit on top of it.
		hideDoc()
		commPanel.Visible = false
	end
	applyVisibility()
end

function Hud.init(all: { [string]: any })
	controllers = all
	buildGui()
end

function Hud.start()
	-- The team strip follows the objective card down the screen.
	local function placeTeam()
		local card = objectiveCard.AbsolutePosition.Y - gui.AbsolutePosition.Y
		teamStrip.Position = UDim2.fromOffset(22, card + objectiveCard.AbsoluteSize.Y + 8)
		teamStrip.Visible = teamStrip.Visible and objectiveCard.Visible
	end
	objectiveCard:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTeam)
	objectiveCard:GetPropertyChangedSignal("Visible"):Connect(function()
		refreshTeam()
		placeTeam()
	end)
	local function watch(player: Player)
		player:GetAttributeChangedSignal("OffFrame"):Connect(refreshTeam)
		refreshTeam()
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshTeam)
	end)
	-- The viewfinder owns the screen: the objective steps aside while the camera is up.
	LensView.onChanged(function()
		applyVisibility()
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("OffFrame"):Connect(applyVisibility)
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		local objective = Strings.get(state.objective)
		local chapter = CHAPTERS[state.phase]
		chapterLabel.Text = if chapter
			then Ui.spaced(`PART {chapter[1]}  ·  {Strings.get(chapter[2])}`)
			else Ui.spaced(Strings.get("hud_objective"))
		if objective ~= objectiveLabel.Text then
			objectiveLabel.Text = objective
			flare()
		end
		objectiveLabel.TextColor3 = if state.phase == "Climax" then Ui.C.Danger else Ui.C.Text
		reelRow.Visible = state.phase == "Protocol"
		for index, pip in reelPips do
			local filled = index <= state.reels
			if filled and pip.BackgroundTransparency > 0.5 then
				pip.Size = UDim2.fromOffset(20, 20)
				Ui.tween(
					pip,
					TweenInfo.new(0.4, Enum.EasingStyle.Back),
					{ Size = UDim2.fromOffset(14, 14) }
				)
			end
			pip.BackgroundTransparency = if filled then 0 else 1
		end
		if state.phase ~= lastPhase then
			lastPhase = state.phase
			AudioDirector.play("Radio", 0.3)
		end
	end)
	Net.get("Notify").OnClientEvent:Connect(function(key: string, ...)
		local first = ...
		-- The player who was cut has their own screen saying so; "film them back" is for others.
		if key == "cut_someone" and first == Players.LocalPlayer.DisplayName then
			return
		end
		local text = Strings.get(key, ...)
		if WRONG_ANSWERS[key] then
			AudioDirector.play("Wrong", 0.6)
			Hud.result(text, "bad")
		elseif PROGRESS[key] then
			AudioDirector.play("RecStart", 0.45, 1.25)
			Hud.result(text, "good")
		elseif key == "tape_saved" then
			-- The viewfinder stamps a saved tape itself; only say it here if the camera is down.
			if not LensView.raised then
				Hud.result(text, "good")
			end
		elseif text:sub(1, 6) == "RADIO:" then
			Hud.subtitle(text)
		else
			Hud.result(text, "info")
		end
	end)
	Net.get("DocShown").OnClientEvent:Connect(function(docId: string)
		showPanel(Strings.get(`{docId}_title`), Strings.get(`{docId}_body`))
	end)
	Net.get("RegisterShown").OnClientEvent:Connect(function(names: { string })
		Hud.showRegister(names)
		task.delay(6, Hud.result, Strings.get("register_note"), "info")
	end)
	Net.get("CommShown").OnClientEvent
		:Connect(function(name: string, kind: number, position: Vector3)
			AudioDirector.play("Radio", 0.4)
			local text = Strings.get(`comm_{kind}`)
			Hud.subtitle(`{name}: {text}`, 3)
			pingAt(position, `{name}: {text}`)
		end)
	Net.get("KnockHeard").OnClientEvent:Connect(function(position: Vector3)
		AudioDirector.playAt("Knock", position, 1, 90)
		if Players.LocalPlayer:GetAttribute("OffFrame") ~= true then
			pingAt(position, "...")
		end
	end)

	-- A document closes itself when the player walks away from where it was read.
	RunService.Heartbeat:Connect(function()
		if docOpenedAt and docShade.Visible then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - docOpenedAt).Magnitude > 9 then
				hideDoc()
			end
		end
		-- A card left alone for a while quietens down.
		if cardRestAt > 0 and os.clock() > cardRestAt then
			cardRestAt = 0
			Ui.tween(objectiveCard, Ui.Motion.Slow, { BackgroundTransparency = 0.55 })
		end
	end)

	Input.bind("Comm1", function()
		sendComm(1)
	end, { Enum.KeyCode.One, Enum.KeyCode.DPadLeft })
	Input.bind("Comm2", function()
		sendComm(2)
	end, { Enum.KeyCode.Two, Enum.KeyCode.DPadRight })
	Input.bind("Comm3", function()
		sendComm(3)
	end, { Enum.KeyCode.Three, Enum.KeyCode.DPadDown })
	Input.bind("Comm4", function()
		sendComm(4)
	end, { Enum.KeyCode.Four, Enum.KeyCode.ButtonB })
	if Input.isTouch then
		Input.bind("CommPanel", function()
			commPanel.Visible = not commPanel.Visible
			Input.setState("CommPanel", if commPanel.Visible then "active" else "idle")
		end, {}, Strings.get("btn_radio"), 5)
	end
end

return Hud
