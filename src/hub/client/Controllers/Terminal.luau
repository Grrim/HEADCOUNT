--!strict
-- The expedition terminal: mission choice, parties, ready state, invites, the preparation screen
-- and the loading screen. All of it only asks; the server decides.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TeleportService = game:GetService("TeleportService")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Panels = require(ReplicatedStorage.ClientCommon.Panels)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Terminal = {}

local localPlayer = Players.LocalPlayer
local action: RemoteEvent
local gui: ScreenGui
local panel: Frame
local content: ScrollingFrame
local errorLabel: TextLabel
local prep: Frame
local prepList: TextLabel
local prepCount: TextLabel
local prepAbort: TextButton
local rejoinPanel: Frame
local parties: { any } = {}
-- The action a gamepad should land on after each redraw: SOLO, READY or BEGIN.
local mainButton: TextButton? = nil

local function myParty(): any
	for _, party in parties do
		for _, member in party.members do
			if member.userId == localPlayer.UserId then
				return party
			end
		end
	end
	return nil
end

local function missionTitle(id: string): string
	for _, mission in Missions do
		if mission.id == id then
			return Strings.get(mission.titleKey)
		end
	end
	return id
end

local function send(name: string, arg: any?)
	errorLabel.Text = ""
	AudioDirector.play("RecStart", 0.4)
	action:FireServer(name, arg)
end

local function row(y: number, height: number): Frame
	return Ui.frame({
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	}, content)
end

local function heading(y: number, text: string, color: Color3?)
	Ui.eyebrow(text, {
		Position = UDim2.new(0, 0, 0, y + 6),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 12,
		TextColor3 = color or Ui.C.Accent,
	}, content)
end

local function renderMyParty(party: any)
	heading(0, missionTitle(party.missionId))
	local y = 32
	local amLeader = false
	for _, member in party.members do
		if member.userId == localPlayer.UserId and member.leader then
			amLeader = true
		end
	end
	local amReady = false
	for _, member in party.members do
		if member.userId == localPlayer.UserId then
			amReady = member.ready
		end
		local line = row(y, 40)
		local suffix = if member.leader then ` {Strings.get("hub_leader")}` else ""
		local mark = if member.ready then "[x] " else "[ ] "
		Ui.text({
			Size = UDim2.new(0.68, 0, 1, 0),
			Text = mark .. member.name .. suffix,
			TextColor3 = if member.ready then Palette.Crt else Palette.Paper,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, line)
		if amLeader and member.userId ~= localPlayer.UserId then
			Ui.button(
				Strings.get("hub_kick"),
				{
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0.3, 0, 0, 36),
					TextSize = 15,
				},
				line,
				function()
					send("kick", member.userId)
				end
			)
		end
		y += 42
	end
	y += 8
	local actions = row(y, 44)
	local entries = {
		{
			Strings.get(if amReady then "hub_not_ready" else "hub_ready"),
			function()
				send("ready", not amReady)
			end,
		},
		{
			Strings.get("hub_invite"),
			function()
				task.spawn(function()
					local ok, can = pcall(function()
						return SocialService:CanSendGameInviteAsync(localPlayer)
					end)
					if ok and can then
						pcall(function()
							SocialService:PromptGameInvite(localPlayer)
						end)
					end
				end)
			end,
		},
		{
			Strings.get("hub_leave"),
			function()
				send("leave")
			end,
		},
	}
	for index, entry in entries do
		-- Ready is what everyone in a party has to press; the other two are secondary.
		local make = if index == 1 and not amReady then Ui.primary else Ui.button
		local button = make(entry[1], {
			Position = UDim2.new((index - 1) / 3, 2, 0, 0),
			Size = UDim2.new(1 / 3, -4, 1, 0),
			TextSize = 15,
		}, actions, entry[2])
		if index == 1 then
			mainButton = button
		end
	end
	if amLeader then
		local begin = Ui.primary(
			Strings.get("hub_start"),
			{
				Position = UDim2.new(0, 2, 0, y + 52),
				Size = UDim2.new(1, -4, 0, 46),
				TextSize = 20,
				TextColor3 = Palette.Paper,
			},
			content,
			function()
				send("start")
			end,
			Palette.Rec
		)
		-- Once everyone is ready, the lead's next press is BEGIN.
		if amReady then
			mainButton = begin
		end
	end
end

local function renderLobby()
	local y = 0
	for _, mission in Missions do
		-- Each mission is a case file: number, title, one line of summary and, before anyone
		-- commits, who it is for and how long it takes. The two ways in sit beside it, the
		-- one-press SOLO filled so it is read first.
		local available = mission.available
		local height = if available then 112 else 66
		local card = row(y, height)
		card.BackgroundColor3 = if available then Ui.C.AccentDeep else Ui.C.Ink
		card.BackgroundTransparency = if available then 0.35 else 0.6
		Ui.stroke(
			card,
			if available then Ui.C.Accent else Ui.C.Faint,
			if available then 0.6 else 0.8
		)
		local textWidth = if available then 0.58 else 1
		local info = Ui.frame({
			Size = UDim2.new(textWidth, 0, 1, 0),
			BackgroundTransparency = 1,
		}, card)
		Ui.pad(info, 12, 10)
		Ui.list(info, 3)
		Ui.display({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 22,
			TextColor3 = if available then Ui.C.Text else Ui.C.Faint,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Text = Strings.get(mission.titleKey),
		}, info)
		Ui.text({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 14,
			TextColor3 = if available then Ui.C.Muted else Ui.C.Faint,
			Text = Strings.get(mission.summaryKey),
		}, info)
		if mission.metaKey then
			Ui.mono({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 16),
				TextSize = 12,
				TextColor3 = Ui.C.Accent,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
				Text = Strings.get(mission.metaKey),
			}, info)
		end
		if available then
			-- Alone, one press is enough. With friends, an expedition they can join.
			local solo = Ui.primary(
				Strings.get("hub_solo"),
				{
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -10, 0, 10),
					Size = UDim2.new(0.38, -10, 0, 50),
					TextSize = 19,
				},
				card,
				function()
					send("solo", mission.id)
				end
			)
			mainButton = mainButton or solo
			Ui.button(
				Strings.get("hub_create"),
				{
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -10, 1, -10),
					Size = UDim2.new(0.38, -10, 0, 36),
					TextSize = 13,
				},
				card,
				function()
					send("create", mission.id)
				end
			)
		end
		y += height + 8
	end
	y += 4
	heading(y, Strings.get("hub_open_list"))
	y += 30
	if #parties == 0 then
		Ui.text({
			Position = UDim2.new(0, 0, 0, y),
			Size = UDim2.new(1, 0, 0, 24),
			Text = Strings.get("hub_none_open"),
			TextSize = 15,
		}, content)
		y += 26
	end
	for _, party in parties do
		local line = row(y, 42)
		Ui.text({
			Size = UDim2.new(0.68, 0, 1, 0),
			Text = `{missionTitle(party.missionId)}  ({#party.members}/4)  {party.members[1].name}`,
			TextSize = 15,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, line)
		Ui.button(
			Strings.get("hub_join"),
			{
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.3, 0, 0, 38),
				TextSize = 15,
			},
			line,
			function()
				send("join", party.id)
			end
		)
		y += 44
	end
	-- What to do here, for anyone who has never seen this screen.
	Ui.text({
		Position = UDim2.new(0, 0, 0, y + 14),
		Size = UDim2.new(1, 0, 0, 40),
		Text = Strings.get("hub_help"),
		TextSize = 14,
		TextColor3 = Palette.Crt,
		TextTransparency = 0.35,
	}, content)
end

local function render()
	content:ClearAllChildren()
	mainButton = nil
	local party = myParty()
	if party then
		renderMyParty(party)
		prepList.Text = ""
		for _, member in party.members do
			prepList.Text ..= member.name .. "\n"
		end
		prep.Visible = party.starting
	else
		renderLobby()
		prep.Visible = false
	end
	Panels.reselect(panel)
end

local function buildGui()
	gui = Ui.screen("Terminal", 5)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.9, 0),
		BackgroundColor3 = Color3.fromRGB(10, 14, 10),
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	Ui.make("UISizeConstraint", {
		MaxSize = Vector2.new(680, 500),
	}, panel)
	Ui.ticks(panel, Palette.Crt, 12, -4)
	-- A sharp border and a soft second one outside it: the phosphor bleeding past the glass.
	Ui.make("UIStroke", { Color = Palette.Crt, Thickness = 2 }, panel)
	local glow = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
		BackgroundTransparency = 1,
		ZIndex = 0,
	}, panel)
	Ui.make("UIStroke", { Color = Palette.Crt, Thickness = 6, Transparency = 0.85 }, glow)
	Ui.frame({
		Position = UDim2.new(0, 16, 0, 40),
		Size = UDim2.new(1, -32, 0, 1),
		BackgroundColor3 = Palette.Crt,
		BackgroundTransparency = 0.6,
	}, panel)
	Ui.display({
		Position = UDim2.new(0, 16, 0, 9),
		Size = UDim2.new(1, -130, 0, 28),
		Text = Strings.get("hub_title"),
		TextSize = 22,
		TextColor3 = Palette.Crt,
	}, panel)
	-- Modal releases the cursor from first-person lock while the panel is open.
	Ui.quiet(
		Strings.get("hub_close") .. "  ×",
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 5),
			Size = UDim2.fromOffset(104, 32),
			Modal = true,
		},
		panel,
		function()
			panel.Visible = false
		end
	)
	errorLabel = Ui.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 40),
		TextSize = 14,
		TextColor3 = Palette.Rec,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "",
	}, panel)
	-- Scrolls on a short phone screen instead of cutting the open expeditions off.
	content = Ui.make("ScrollingFrame", {
		Position = UDim2.new(0, 16, 0, 50),
		Size = UDim2.new(1, -24, 1, -96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.Crt,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, panel)

	-- Preparation screen
	prep = Ui.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
		ZIndex = 20,
	}, gui)
	Ui.display({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.new(0.8, 0, 0, 40),
		FontFace = Ui.Fonts.DisplayBold,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("hub_preparing"),
		ZIndex = 21,
	}, prep)
	prepList = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.new(0.6, 0, 0, 130),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 21,
	}, prep)
	prepCount = Ui.mono({
		FontFace = Ui.Fonts.MonoBold,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(0.8, 0, 0, 40),
		TextSize = 22,
		TextColor3 = Palette.Rec,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 21,
	}, prep)
	prepAbort = Ui.button(
		Strings.get("hub_abort"),
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.7),
			Size = UDim2.fromOffset(190, 50),
			Modal = true,
			ZIndex = 21,
		},
		prep,
		function()
			send("abort")
		end
	)

	-- Offer to return to a running expedition
	rejoinPanel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 170),
		BackgroundColor3 = Color3.fromRGB(10, 14, 10),
		BorderSizePixel = 2,
		BorderColor3 = Palette.Crt,
		Visible = false,
		ZIndex = 30,
	}, gui)
	Ui.text({
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(1, -32, 0, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("hub_rejoin"),
		ZIndex = 31,
	}, rejoinPanel)
	Ui.button(
		Strings.get("hub_rejoin_yes"),
		{
			Position = UDim2.new(0, 16, 1, -66),
			Size = UDim2.new(0.5, -22, 0, 50),
			Modal = true,
			ZIndex = 31,
		},
		rejoinPanel,
		function()
			rejoinPanel.Visible = false
			send("rejoinYes")
		end
	)
	Ui.button(
		Strings.get("hub_rejoin_no"),
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 1, -66),
			Size = UDim2.new(0.5, -22, 0, 50),
			ZIndex = 31,
		},
		rejoinPanel,
		function()
			rejoinPanel.Visible = false
			send("rejoinNo")
		end
	)
end

local function setLoadingGui()
	-- Shown by the engine across the teleport, in place of the default screen.
	local loading = Instance.new("ScreenGui")
	loading.Name = "Rewinding"
	loading.IgnoreGuiInset = true
	Ui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0) }, loading)
	Ui.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 40),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("hub_loading"),
	}, loading.Frame)
	pcall(function()
		TeleportService:SetTeleportGui(loading)
	end)
end

function Terminal.init()
	action = Net.get("PartyAction")
	buildGui()
	Panels.watch(panel, nil, function()
		return mainButton
	end)
	Panels.watch(rejoinPanel, function()
		rejoinPanel.Visible = false
	end)
	setLoadingGui()
end

function Terminal.start()
	for _, terminal in CollectionService:GetTagged("ExpeditionTerminal") do
		local prompt = terminal:WaitForChild("ProximityPrompt", 10) :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function()
				render()
				Ui.open(panel)
			end)
		end
	end
	Net.get("PartyState").OnClientEvent:Connect(function(state)
		parties = state
		render()
	end)
	Net.get("TeleportStatus").OnClientEvent:Connect(function(stage: string, value: any)
		if stage == "countdown" then
			prepCount.Text = Strings.get("hub_starting_in", value)
			prepAbort.Visible = true
		elseif stage == "aborted" then
			prep.Visible = false
		elseif stage == "teleporting" then
			prep.Visible = true
			prepCount.Text = Strings.get("hub_loading")
			prepAbort.Visible = false
		elseif stage == "error" then
			prep.Visible = false
			errorLabel.Text = Strings.get(value)
			panel.Visible = true
		elseif stage == "rejoinOffer" then
			rejoinPanel.Visible = true
		end
	end)
end

return Terminal
