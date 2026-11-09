--!strict
-- The minimal mission HUD: one objective, radio subtitles, documents, and pings when someone calls.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Hud = {}

-- A guess that came to nothing gets one dry click, so a wrong answer is heard as well as read.
local WRONG_ANSWERS = { seat_empty = true, hook_empty = true, code_wrong = true, reel_wrong = true }

local gui: ScreenGui
local objectiveCard: Frame
local objectiveLabel: TextLabel
local detailLabel: TextLabel
local stepLabel: TextLabel
local subtitleLabel: TextLabel
local docPanel: Frame
local docTitle: TextLabel
local docBody: TextLabel
local commPanel: Frame
local subtitleToken = 0
local lastPhase = ""
local cinema = false

function Hud.subtitle(text: string, seconds: number?)
	subtitleToken += 1
	local token = subtitleToken
	subtitleLabel.Text = text
	subtitleLabel.TextTransparency = 0
	subtitleLabel.Visible = true
	task.delay(seconds or math.max(4, #text / 14), function()
		if token == subtitleToken then
			TweenService:Create(subtitleLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

local function applyVisibility()
	objectiveCard.Visible = not LensView.raised and not cinema
end

local function hidePanel()
	docPanel.Visible = false
	ContextActionService:UnbindAction("CloseDoc")
end

local function showPanel(title: string, body: string, color: Color3?)
	docTitle.Text = title
	docBody.Text = body
	docBody.TextColor3 = color or Palette.Ink
	docPanel.Visible = true
	-- A controller has no cursor to reach the X with. B only closes the page while one is open;
	-- the rest of the time it stays a radio call.
	ContextActionService:BindActionAtPriority("CloseDoc", function(_, state)
		if state == Enum.UserInputState.Begin then
			hidePanel()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
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
	board.Size = UDim2.fromOffset(160, 40)
	board.AlwaysOnTop = true
	board.MaxDistance = 200
	board.Parent = holder
	local label = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.Crt,
		TextStrokeTransparency = 0.5,
	}, board)
	TweenService:Create(
		label,
		TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 3),
		{
			TextTransparency = 1,
		}
	):Play()
	task.delay(4.2, function()
		holder:Destroy()
	end)
end

local function sendComm(kind: number)
	Net.get("QuickComm"):FireServer(kind)
end

local function buildGui()
	gui = Ui.screen("MissionHud", 2)
	-- The objective sits on a case-file card: a red rule, a small heading, the order itself.
	objectiveCard = Ui.frame({
		Position = UDim2.new(0, 20, 0, 50),
		Size = UDim2.new(0.42, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(8, 10, 12),
		BackgroundTransparency = 0.35,
	}, gui)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }, objectiveCard)
	Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, objectiveCard)
	-- The rule hangs on the card's left edge; the text stacks in a body beside it.
	Ui.frame({
		Name = "Rule",
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Palette.Rec,
	}, objectiveCard)
	local body = Ui.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, objectiveCard)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 24),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
	}, body)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}, body)
	Ui.text({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = Palette.Rec,
		Text = Strings.get("hud_objective"),
	}, body)
	objectiveLabel = Ui.text({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 18,
		Text = "",
	}, body)
	detailLabel = Ui.text({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		TextColor3 = Palette.Crt,
		Text = "",
	}, body)
	-- The concrete next move, worked out by the notebook from what this player knows.
	stepLabel = Ui.text({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		TextColor3 = Palette.Crt,
		Text = "",
		Visible = false,
	}, body)
	subtitleLabel = Ui.caption({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.86),
		TextSize = 19,
		Text = "",
		ZIndex = 5,
	}, gui, 820)

	docPanel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.new(0.56, 0, 0.5, 0),
		BackgroundColor3 = Palette.Paper,
		Visible = false,
		ZIndex = 10,
	}, gui)
	Ui.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(320, 220), MaxSize = Vector2.new(620, 420) },
		docPanel
	)
	docTitle = Ui.text({
		Position = UDim2.fromScale(0.06, 0.07),
		Size = UDim2.fromScale(0.88, 0.16),
		TextSize = 21,
		TextColor3 = Palette.Ink,
		ZIndex = 11,
		Text = "",
	}, docPanel)
	docBody = Ui.text({
		Position = UDim2.fromScale(0.06, 0.26),
		Size = UDim2.fromScale(0.88, 0.5),
		TextSize = 18,
		TextColor3 = Palette.Ink,
		ZIndex = 11,
		Text = "",
	}, docPanel)
	Ui.button("X", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.97, 0, 0.96, 0),
		Size = UDim2.fromOffset(64, 44),
		ZIndex = 11,
		-- Modal releases the cursor from first-person lock, or the click can never reach the X.
		Modal = true,
	}, docPanel, hidePanel)

	-- Touch players get the four radio calls behind one button.
	commPanel = Ui.frame({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.34, 0),
		Size = UDim2.fromOffset(120, 200),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	for kind = 1, 4 do
		Ui.button(
			Strings.get(`comm_{kind}`),
			{
				Position = UDim2.fromOffset(0, (kind - 1) * 50),
				Size = UDim2.fromOffset(120, 44),
				TextSize = 16,
			},
			commPanel,
			function()
				sendComm(kind)
				commPanel.Visible = false
			end
		)
	end
end

local function flare()
	objectiveCard.BackgroundTransparency = 0
	TweenService:Create(
		objectiveCard,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad),
		{ BackgroundTransparency = 0.35 }
	):Play()
end

function Hud.setStep(text: string)
	if text == "" then
		stepLabel.Text = ""
		stepLabel.Visible = false
		return
	end
	local line = `> {text}`
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
		hidePanel()
	end
	applyVisibility()
end

function Hud.init()
	buildGui()
end

function Hud.start()
	-- The viewfinder owns the screen: the objective steps aside while the camera is up.
	LensView.onChanged(function()
		applyVisibility()
	end)
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		local objective = Strings.get(state.objective)
		if objective ~= objectiveLabel.Text then
			objectiveLabel.Text = objective
			-- A new order arrives with a brief flare of the card.
			flare()
		end
		objectiveLabel.TextColor3 = if state.phase == "Climax" then Palette.Rec else Palette.Paper
		local details = {}
		-- Tags only matter while the coats still hold reels.
		if state.phase == "Protocol" and #state.tags > 0 then
			table.insert(details, Strings.get("tags_label", table.concat(state.tags, ", ")))
		end
		if state.phase == "Protocol" and state.reels > 0 then
			table.insert(details, Strings.get("reels_label", state.reels))
		end
		detailLabel.Text = table.concat(details, "   ")
		detailLabel.Visible = detailLabel.Text ~= ""
		if state.phase ~= lastPhase then
			lastPhase = state.phase
			AudioDirector.play("Radio", 0.35)
		end
	end)
	Net.get("Notify").OnClientEvent:Connect(function(key: string, ...)
		if WRONG_ANSWERS[key] then
			AudioDirector.play("Wrong", 0.6)
		end
		Hud.subtitle(Strings.get(key, ...))
	end)
	Net.get("DocShown").OnClientEvent:Connect(function(docId: string)
		showPanel(Strings.get(`{docId}_title`), Strings.get(`{docId}_body`))
	end)
	Net.get("RegisterShown").OnClientEvent:Connect(function(names: { string })
		Hud.showRegister(names)
		task.delay(6, Hud.subtitle, Strings.get("register_note"))
	end)
	Net.get("CommShown").OnClientEvent
		:Connect(function(name: string, kind: number, position: Vector3)
			AudioDirector.play("Radio", 0.4)
			local text = Strings.get(`comm_{kind}`)
			Hud.subtitle(`{name}: {text}`, 3)
			pingAt(position, text)
		end)
	Net.get("KnockHeard").OnClientEvent:Connect(function(position: Vector3)
		AudioDirector.playAt("Knock", position, 1, 90)
		if Players.LocalPlayer:GetAttribute("OffFrame") ~= true then
			pingAt(position, "...")
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
		end, {}, Strings.get("btn_radio"), 5)
	end
end

return Hud
