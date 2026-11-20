--!strict
-- What a player needs on a shift, and nothing else: the floor and its multiplier, the quota, the
-- battery, short notices, the stars a shot earned, being cut out of frame, the team list, and the
-- pay screen with upgrades, the depth record and the Archive between shifts. Shift text is
-- English only and lives here, not in Strings.
--
-- The team list is the answer to the Extra: it can wear a teammate's face, but the list says
-- where that teammate really is.
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Nights = require(ReplicatedStorage.Shared.Core.Nights)
local TapeView = require(ReplicatedStorage.ClientCommon.TapeView)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local ShiftHud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local floorLabel: TextLabel
local quotaLabel: TextLabel
local quotaBanked: Frame
local quotaCarried: Frame
local batteryFill: Frame
local batteryLabel: TextLabel
local toastLabel: TextLabel
local cutLabel: TextLabel
local liftHint: TextLabel
-- A new player's radio line on their first shift; it stays until the next one replaces it.
local radioLabel: TextLabel
local carryLabel: TextLabel
-- Tonight's modifier and the week's anomaly (docs/09_GDD_V2.md §9).
local nightLabel: TextLabel
local teamList: Frame
local questList: Frame
local results: Frame
-- Beside the pay screen: the shift tape playing, and the tapes kept in the Archive.
local tapePanel: Frame
local tapeScreen: Frame
local lastNoticeId = 0
local state: { [string]: any } = { phase = "ready", depth = 0, quota = 40, banked = 0, carried = 0 }
local toastToken = 0

local KIND_NAMES = {
	sitter = "Sitter",
	standing = "Stander",
	watcher = "Watcher",
	extra = "The Extra",
}

local HONOUR_NAMES = {
	gold = "1st",
	silver = "2nd",
	bronze = "3rd",
	top10 = "Top 10",
}

local CUT_LINES = {
	registrar = "CUT OUT OF FRAME",
	extra = "IT WASN'T WHO YOU THOUGHT",
	usher = "THE USHER SAW YOUR LIGHT",
}

-- What a level of each upgrade means, in the words a player would use.
local function describe(upgrade: { [string]: any }): string
	local value = upgrade.value
	if upgrade.id == "tripod" then
		return if value > 0 then `{value} s` else "none"
	elseif upgrade.id == "lens" then
		return `x{value} zoom`
	elseif upgrade.id == "night" then
		return if value > 0 then `level {value}` else "none"
	elseif upgrade.id == "torch" then
		return `{value} studs`
	elseif upgrade.id == "battery" then
		return `{value} s`
	end
	return tostring(value)
end

-- A viewfinder frame's name and colour, from either list of frames.
local function frameInfo(id: string): (string, Color3)
	for _, frame in Cosmetics.PassFrames do
		if frame.id == id then
			return frame.name, frame.color
		end
	end
	for _, frame in Cosmetics.Frames do
		if frame.id == id then
			return string.upper(string.sub(frame.id, 1, 1)) .. string.sub(frame.id, 2), frame.color
		end
	end
	return id, Ui.C.Text
end

-- The next item after `current` in `list`, wrapping round.
local function after(list: { string }, current: string?): string?
	if #list == 0 then
		return nil
	end
	local at = if current then table.find(list, current) else nil
	return list[((at or 0) % #list) + 1]
end

local function stars(count: number): string
	return string.rep("★", count) .. string.rep("☆", 5 - count)
end

function ShiftHud.toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or Ui.C.Text
	toastLabel.TextTransparency = 0
	toastLabel.TextStrokeTransparency = 0.4
	task.delay(3.2, function()
		if token == toastToken then
			TweenService:Create(
				toastLabel,
				TweenInfo.new(0.4),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			):Play()
		end
	end)
end

local function depthText(depth: number): string
	return if depth == 0 then "THE BUREAU" else `FLOOR -{depth}`
end

local function render()
	local night = Nights.byId(state.night)
	nightLabel.Text = (if night.id == "standard" then "" else `TONIGHT: {night.name}. {night.text}`)
		.. (
			if typeof(state.weekly) == "string"
				then `{if night.id == "standard" then "" else "\n"}THIS WEEK: {state.weekly} (pays double)`
				else ""
		)
	local depth = state.depth or 0
	local multiplier = state.multiplier or 1
	floorLabel.Text = if depth == 0 then depthText(0) else `{depthText(depth)}   x{multiplier}`
	local quota = math.max(1, state.quota or 1)
	local banked = state.banked or 0
	local carried = state.carried or 0
	quotaLabel.Text = `QUOTA  {banked + carried} / {quota}`
		.. (if carried > 0 then `   ({carried} not yet in the lift)` else "")
	quotaBanked.Size = UDim2.fromScale(math.clamp(banked / quota, 0, 1), 1)
	quotaCarried.Position = UDim2.fromScale(math.clamp(banked / quota, 0, 1), 0)
	quotaCarried.Size =
		UDim2.fromScale(math.clamp(carried / quota, 0, 1 - math.clamp(banked / quota, 0, 1)), 1)
	quotaBanked.BackgroundColor3 = if banked + carried >= quota then Ui.C.Accent else Ui.C.Radio
end

local function inLift(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local p = root.Position
	-- Matches ShiftWorld.inLift on the server.
	return p.X >= -6 and p.X <= 6 and p.Z >= -12 and p.Z <= -1.3 and p.Y < 12
end

-- Tonight's modifier id, as the server set it for this shift.
function ShiftHud.night(): string
	return if typeof(state.night) == "string" then state.night else "standard"
end

function ShiftHud.phase(): string
	return state.phase or "ready"
end

local function closeTapes()
	tapePanel.Visible = false
	-- Alone, the pay screen stands in the middle; beside a tape panel, right of it.
	results.Position = UDim2.fromScale(0.5, 0.5)
	-- Clearing the screen destroys the playing copy and stops it.
	tapeScreen:ClearAllChildren()
end

local function closeResults()
	results.Visible = false
	closeTapes()
end

local function tapeLabel(tape: any): string
	return `{stars(tape.stars or 0)}  -{tape.depth}  {tape.by or ""}`
end

-- The tape panel: the shift's tape playing (if the shift had one), a button to keep it, and every
-- tape already kept, each one a button that plays it.
local function showTapes(data: { [string]: any })
	local shiftTape = data.tape
	local kept = if typeof(data.tapes) == "table" then data.tapes else {}
	if (typeof(shiftTape) ~= "table" and #kept == 0) or Ui.compact() then
		closeTapes()
		return
	end
	tapePanel.Visible = true
	results.Position = UDim2.fromScale(0.62, 0.5)
	local list = tapePanel:FindFirstChild("TapeList")
	if list then
		list:Destroy()
	end
	local holder = Ui.frame({
		Name = "TapeList",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, tapePanel)
	Ui.list(holder, 6)
	local function playTape(tape: any)
		TapeView.play(tapeScreen, tape)
	end
	if typeof(shiftTape) == "table" then
		playTape(shiftTape)
		Ui.primary(
			"SAVE TO ARCHIVE",
			{ Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1 },
			holder,
			function()
				Net.get("ShiftAction"):FireServer("savetape")
			end
		)
	else
		playTape(kept[1])
	end
	Ui.eyebrow(`ARCHIVE TAPES  {#kept}/5`, { LayoutOrder = 2 }, holder)
	for index, tape in kept do
		Ui.quiet(
			tapeLabel(tape),
			{ Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 2 + index },
			holder,
			function()
				playTape(tape)
			end
		)
	end
	if typeof(shiftTape) == "table" then
		Ui.quiet(
			"THIS SHIFT'S TAPE",
			{ Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 20 },
			holder,
			function()
				playTape(shiftTape)
			end
		)
	end
end

local function showResults(data: { [string]: any })
	results:ClearAllChildren()
	results.Visible = true
	showTapes(data)
	Ui.pad(results, 22, 18)
	Ui.list(results, 10)
	-- A modal button frees the mouse from first person while the panel is open.
	Ui.make("TextButton", {
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		LayoutOrder = 0,
	}, results)

	local returned = data.result == "returned"
	local title = if not returned
		then "CUT OUT OF FRAME"
		elseif data.met then "SHIFT COMPLETE"
		else "QUOTA MISSED"
	Ui.display({
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 30,
		Text = title,
		TextColor3 = if returned and data.met then Ui.C.Accent else Ui.C.Danger,
		LayoutOrder = 1,
	}, results)
	local record = data.record or 0
	local lines = {
		`Footage brought back: {data.banked} / quota {data.quota}`,
		if returned
			then `Deepest floor: -{data.deepest}   Deepest return: -{record}`
			else `Deepest floor: -{data.deepest} (only a ride back up counts)`,
		if returned and data.met
			then `Pay: {data.payout} frames`
			else `Pay: {data.payout} frames (the Bureau pays a quarter)`,
		`Your frames: {data.money}`
			.. (if data.saved then "" else "   (not saved: this server only)"),
	}
	-- Rank, for good (docs/09_GDD_V2.md §5), with how far the next one is.
	local rank = player:GetAttribute("Rank")
	if typeof(rank) == "number" then
		local into, need = player:GetAttribute("RankInto"), player:GetAttribute("RankNeed")
		table.insert(
			lines,
			if typeof(need) == "number" and need > 0
				then `Rank {rank}   {into}/{need} xp to rank {rank + 1}`
				else `Rank {rank}: the top of the Bureau.`
		)
	end
	for index, line in lines do
		Ui.text({
			Size = UDim2.new(1, 0, 0, 22),
			TextSize = 18,
			Text = line,
			LayoutOrder = 1 + index,
		}, results)
	end
	local archive = data.archive or {}
	local found = 0
	local parts = {}
	for _, entry in archive do
		if (entry.stars or 0) > 0 then
			found += 1
			table.insert(parts, `{KIND_NAMES[entry.kind] or entry.kind} {stars(entry.stars)}`)
		else
			table.insert(parts, "?")
		end
	end
	Ui.eyebrow(`ARCHIVE  {found}/{#archive}`, { LayoutOrder = 7 }, results)
	Ui.mono({
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Ui.C.Muted,
		Text = table.concat(parts, "   "),
		LayoutOrder = 8,
	}, results)
	-- Commendations for places on finished weeks' boards, best first.
	local honours = data.honours or {}
	local won = {}
	for _, kind in { "gold", "silver", "bronze", "top10" } do
		local count = honours[kind]
		if typeof(count) == "number" and count > 0 then
			table.insert(won, `{HONOUR_NAMES[kind]} x{count}`)
		end
	end
	if #won > 0 then
		Ui.mono({
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 13,
			TextColor3 = Ui.C.Accent,
			Text = `COMMENDATIONS  {table.concat(won, "   ")}`,
			LayoutOrder = 9,
		}, results)
	end
	-- The Biuro Pass: where the player stands this season, what comes next, the premium track.
	local passRaw = player:GetAttribute("Pass")
	local passOk, pass = pcall(function()
		return HttpService:JSONDecode(
			if typeof(passRaw) == "string" and passRaw ~= "" then passRaw else "null"
		)
	end)
	if passOk and typeof(pass) == "table" then
		Ui.eyebrow(
			`BIURO PASS  ·  {pass.name}  ·  {pass.daysLeft} DAYS LEFT`,
			{ LayoutOrder = 11 },
			results
		)
		local track = Ui.frame({
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = Ui.C.Raised,
			LayoutOrder = 12,
		}, results)
		local full = pass.tier >= pass.tiers
		Ui.frame({
			Size = UDim2.fromScale(
				if full then 1 else math.clamp(pass.xp / pass.xpPerTier, 0, 1),
				1
			),
			BackgroundColor3 = Ui.C.Accent,
		}, track)
		local passLines = {
			if full
				then `Tier {pass.tier}/{pass.tiers}: the whole track is yours.`
				else `Tier {pass.tier}/{pass.tiers}   {pass.xp}/{pass.xpPerTier} xp to the next`,
		}
		if pass.nextFree then
			table.insert(passLines, `Next free (tier {pass.nextFree.tier}): {pass.nextFree.text}`)
		end
		if pass.nextPremium then
			table.insert(
				passLines,
				`Next premium (tier {pass.nextPremium.tier}): {pass.nextPremium.text}`
					.. (if pass.premium then "" else "  [locked]")
			)
		end
		for index, line in passLines do
			Ui.mono({
				Size = UDim2.new(1, 0, 0, 16),
				TextSize = 12,
				TextColor3 = Ui.C.Muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = line,
				LayoutOrder = 12 + index,
			}, results)
		end
		if not pass.premium then
			if pass.forSale then
				Ui.button(
					"UNLOCK THE PREMIUM TRACK (cosmetics only)",
					{
						Size = UDim2.new(1, 0, 0, 30),
						TextSize = 14,
						LayoutOrder = 17,
					},
					results,
					function()
						MarketplaceService:PromptGamePassPurchase(player, pass.gamePassId)
					end
				)
			else
				Ui.mono({
					Size = UDim2.new(1, 0, 0, 16),
					TextSize = 12,
					TextColor3 = Ui.C.Faint,
					Text = "Premium track: coming soon.",
					LayoutOrder = 18,
				}, results)
			end
		end
	end

	-- What the player wears: each button moves on to the next one they own.
	local frames = if typeof(data.frames) == "table" then data.frames else { "paper" }
	local titles = if typeof(data.titles) == "table" then data.titles else {}
	local wearing = Ui.frame({
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = 19,
	}, results)
	local frameName, frameColor = frameInfo(data.frame or "paper")
	Ui.button(
		`VIEWFINDER: {frameName}  >`,
		{
			Size = UDim2.new(0.49, 0, 1, 0),
			TextSize = 13,
			TextColor3 = frameColor,
			BorderColor3 = frameColor,
		},
		wearing,
		function()
			local nextFrame = after(frames, data.frame or "paper")
			if nextFrame then
				Net.get("ShiftAction"):FireServer("wearframe", nextFrame)
			end
		end
	)
	local titleList = table.clone(titles)
	table.insert(titleList, 1, "")
	Ui.button(
		if data.title then `TITLE: {data.title}  >` else "TITLE: none  >",
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.49, 0, 1, 0),
			TextSize = 13,
			TextColor3 = if #titles > 0 then Ui.C.Text else Ui.C.Faint,
		},
		wearing,
		function()
			if #titles > 0 then
				Net.get("ShiftAction")
					:FireServer("weartitle", after(titleList, data.title or "") or "")
			end
		end
	)

	Ui.eyebrow("UPGRADES", { LayoutOrder = 29 }, results)
	if data.firstUpgrade then
		-- Straight after a first shift (docs/09_GDD_V2.md §3): the first upgrade, bought now.
		Ui.text({
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 15,
			TextColor3 = Ui.C.Accent,
			Text = "Your first upgrade: a bigger Battery keeps the lens up longer underground.",
			LayoutOrder = 30,
		}, results)
	end
	for index, upgrade in data.upgrades or {} do
		local row = Ui.frame({
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = 30 + index,
		}, results)
		Ui.text({
			Size = UDim2.new(0.62, 0, 1, 0),
			TextSize = 17,
			TextYAlignment = Enum.TextYAlignment.Center,
			Text = `{upgrade.name}  {describe(upgrade)}  (level {upgrade.level}/{upgrade.maxLevel})`,
		}, row)
		if upgrade.cost then
			local affordable = (data.money or 0) >= upgrade.cost
			Ui.button(
				`BUY  {upgrade.cost}`,
				{
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0.36, 0, 1, 0),
					TextColor3 = if affordable then Ui.C.Accent else Ui.C.Faint,
				},
				row,
				function()
					Net.get("ShiftAction"):FireServer("buy", upgrade.id)
				end
			)
		else
			Ui.mono({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.36, 0, 1, 0),
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Ui.C.Muted,
				Text = "MAX",
			}, row)
		end
	end
	Ui.primary(
		"NEXT SHIFT",
		{
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = 50,
		},
		results,
		function()
			closeResults()
			Net.get("ShiftAction"):FireServer("next")
		end
	)
	Ui.quiet(
		"BACK TO THE LOBBY",
		{ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 51 },
		results,
		function()
			Net.get("ShiftAction"):FireServer("lobby")
		end
	)
	Ui.quiet("CLOSE", { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 52 }, results, closeResults)
end

local function build()
	gui = Ui.screen("ShiftHud", 5)

	local top = Ui.frame({
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(340, 64),
		BackgroundTransparency = 0.35,
	}, gui)
	Ui.pad(top, 12, 8)
	floorLabel = Ui.display({
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 22,
		Text = "THE BUREAU",
	}, top)
	quotaLabel = Ui.mono({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = Ui.C.Muted,
		Text = "",
	}, top)
	local bar = Ui.frame({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Ui.C.Raised,
	}, top)
	quotaBanked = Ui.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.C.Radio }, bar)
	quotaCarried = Ui.frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.C.Radio,
		BackgroundTransparency = 0.6,
	}, bar)

	local battery = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(220, 22),
		BackgroundTransparency = 0.35,
	}, gui)
	Ui.pad(battery, 8, 4)
	local track = Ui.frame({
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.new(1, -70, 0, 6),
		BackgroundColor3 = Ui.C.Raised,
	}, battery)
	batteryFill = Ui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.C.Accent }, track)
	batteryLabel = Ui.mono({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(64, 14),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "BATTERY",
	}, battery)

	toastLabel = Ui.display({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.new(0.8, 0, 0, 34),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	}, gui)

	cutLabel = Ui.display({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(0.8, 0, 0, 60),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(170, 200, 255),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.4,
		Visible = false,
		Text = "",
	}, gui)

	radioLabel = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.new(0.7, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = Ui.C.Radio,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Text = "",
	}, gui)
	Ui.pad(radioLabel, 10, 6)

	liftHint = Ui.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.new(0.7, 0, 0, 24),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.5,
		Visible = false,
		Text = "",
	}, gui)

	results = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.08,
		Visible = false,
	}, gui)

	tapePanel = Ui.frame({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.62, -252, 0.5, 0),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.08,
		Visible = false,
	}, gui)
	Ui.pad(tapePanel, 12, 12)
	Ui.list(tapePanel, 8)
	Ui.eyebrow("SHIFT TAPE", { LayoutOrder = 1 }, tapePanel)
	tapeScreen = Ui.frame({
		Size = UDim2.fromOffset(336, 189),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		LayoutOrder = 2,
	}, tapePanel)
	-- A narrow screen has no room beside the pay screen: there the tape panel is left out
	-- (showTapes).

	carryLabel = Ui.mono({
		Position = UDim2.fromOffset(18, 86),
		Size = UDim2.fromOffset(340, 16),
		TextSize = 12,
		TextColor3 = Ui.C.Muted,
		TextStrokeTransparency = 0.6,
		Text = "",
	}, gui)

	nightLabel = Ui.mono({
		Position = UDim2.fromOffset(18, 104),
		Size = UDim2.fromOffset(420, 32),
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Ui.C.Radio,
		TextStrokeTransparency = 0.6,
		Text = "",
	}, gui)

	-- The right-hand column: the team, then today's tasks.
	local column = Ui.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, gui)
	Ui.list(column, 8)
	teamList = Ui.frame({
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.35,
		LayoutOrder = 1,
	}, column)
	Ui.pad(teamList, 10, 8)
	Ui.list(teamList, 2)
	questList = Ui.frame({
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.35,
		LayoutOrder = 2,
		Visible = false,
	}, column)
	Ui.pad(questList, 10, 8)
	Ui.list(questList, 2)
end

-- Today's tasks, from the Quests attribute the server keeps (ShiftQuests): done ones ticked, the
-- rest with how far they have got and what they pay.
local function renderQuests()
	for _, child in questList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local raw = player:GetAttribute("Quests")
	local ok, quests = pcall(function()
		return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "[]")
	end)
	if not ok or typeof(quests) ~= "table" or #quests == 0 then
		questList.Visible = false
		return
	end
	questList.Visible = true
	local left = math.max(0, 86400 - os.time() % 86400)
	Ui.eyebrow(
		`TODAY'S TASKS  ·  NEW IN {left // 3600}H {(left % 3600) // 60}M`,
		{ LayoutOrder = 0 },
		questList
	)
	for index, quest in quests do
		local done = quest.done == true
		Ui.mono({
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 12,
			TextColor3 = if done then Ui.C.Accent else Ui.C.Text,
			TextTransparency = if done then 0.35 else 0,
			Text = if done
				then `✓ {quest.text}`
				else `○ {quest.text}  {quest.count}/{quest.target}  +{quest.reward}`,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = index,
		}, questList)
	end
end

function ShiftHud.start()
	build()
	render()

	Net.get("ShiftState").OnClientEvent:Connect(function(incoming)
		local previousPhase = state.phase
		state = incoming
		render()
		if incoming.notice and incoming.noticeId ~= lastNoticeId then
			lastNoticeId = incoming.noticeId
			ShiftHud.toast(incoming.notice)
		end
		local phase = incoming.phase
		if phase ~= previousPhase and phase == "ride" then
			closeResults()
		end
	end)

	Net.get("ShiftResult").OnClientEvent:Connect(showResults)
	-- Listening now: ask for the current state instead of trusting what was sent before.
	Net.get("ShiftAction"):FireServer("hello")

	Net.get("FootageScored").OnClientEvent:Connect(function(data)
		if data.teammate then
			ShiftHud.toast(`{data.teammate} got footage: +{data.added}`, Ui.C.Muted)
			return
		end
		local shots = data.shots or {}
		if data.door then
			task.delay(3.4, function()
				ShiftHud.toast("That tape caught the code door. Watch it (T) to read the code.")
			end)
		end
		if #shots == 0 then
			if (data.best or 0) > 0 then
				ShiftHud.toast("Nothing better than what the team already has.", Ui.C.Muted)
			else
				ShiftHud.toast(
					"Nothing on that tape. Get it in frame, longer and closer.",
					Ui.C.Muted
				)
			end
			return
		end
		local first = shots[1]
		local rarity = string.upper(first.rarity or "common")
		ShiftHud.toast(`{stars(first.stars)}  {rarity}   +{data.added}`, Ui.C.Accent)
		LensView.stamp(`{stars(first.stars)}  +{data.added}`)
		AudioDirector.play("Paper", 0.5, 1.2)
	end)

	-- Where everyone really is, from the server's view of them, twice a second.
	task.spawn(function()
		while true do
			for _, child in teamList:GetChildren() do
				if child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			local players = Players:GetPlayers()
			teamList.Visible = #players > 0
			Ui.eyebrow("TEAM  ·  WHERE THEY REALLY ARE", { LayoutOrder = 0 }, teamList)
			for index, other in players do
				local where = other:GetAttribute("Where")
				local name = if other == player then "You" else other.DisplayName
				local otherRank = other:GetAttribute("Rank")
				if typeof(otherRank) == "number" then
					name ..= ` [R{otherRank}]`
				end
				-- A title from the Biuro Pass, worn by choice.
				local title = other:GetAttribute("Title")
				if typeof(title) == "string" and title ~= "" then
					name ..= ` ({title})`
				end
				Ui.mono({
					Size = UDim2.new(1, 0, 0, 16),
					TextSize = 12,
					TextColor3 = if other:GetAttribute("OffFrame") == true
						then Ui.C.Danger
						else Ui.C.Text,
					Text = `{name}: {if typeof(where) == "string" then where else "?"}`,
					LayoutOrder = index,
				}, teamList)
			end
			task.wait(0.5)
		end
	end)

	local function renderRadio()
		local line = player:GetAttribute("Hint")
		local shown = typeof(line) == "string" and line ~= ""
		radioLabel.Visible = shown
		if shown then
			radioLabel.Text = line
			AudioDirector.play("Paper", 0.35, 0.8)
		end
	end
	player:GetAttributeChangedSignal("Hint"):Connect(renderRadio)
	renderRadio()
	player:GetAttributeChangedSignal("Quests"):Connect(renderQuests)
	renderQuests()
	-- The countdown to new tasks, once a minute.
	task.spawn(function()
		while true do
			task.wait(60)
			renderQuests()
		end
	end)

	RunService.Heartbeat:Connect(function()
		local level = player:GetAttribute("Battery")
		local empty = player:GetAttribute("BatteryEmpty") == true
		if typeof(level) == "number" then
			batteryFill.Size = UDim2.fromScale(math.clamp(level, 0, 1), 1)
			batteryFill.BackgroundColor3 = if empty or level < 0.2 then Ui.C.Danger else Ui.C.Accent
			batteryLabel.Text = if empty then "FLAT" else `{math.floor(level * 100)}%`
		end

		local cut = player:GetAttribute("OffFrame") == true
		cutLabel.Visible = cut
		if cut then
			local progress = player:GetAttribute("RescueProgress")
			local selfReturn = player:GetAttribute("SelfReturnAvailable") == true
			local cause = player:GetAttribute("CutBy")
			local title = CUT_LINES[if typeof(cause) == "string" then cause else "registrar"]
				or CUT_LINES.registrar
			local line = `{title}\nA teammate can film you back (3 s).`
			if typeof(progress) == "number" and progress > 0 then
				line = `{title}\nBeing filmed back... {math.floor(progress * 100)}%`
			elseif selfReturn then
				line ..= "\nOr walk back into the lift after 30 s (once a shift)."
			end
			cutLabel.Text = line .. "\nYour camera fell where you were cut."
		end

		local carrying = player:GetAttribute("Carrying")
		if player:GetAttribute("HasCamera") == false then
			carryLabel.Text = "NO CAMERA: pick one up, or ride the lift for a new one"
			carryLabel.TextColor3 = Ui.C.Danger
		elseif typeof(carrying) == "number" and carrying > 0 then
			carryLabel.Text = `YOUR CAMERA HOLDS {carrying}  ·  drop it and it stays here`
			carryLabel.TextColor3 = Ui.C.Muted
		else
			carryLabel.Text = ""
		end

		local phase = state.phase
		local showHint = inLift() and (phase == "floor" or phase == "ready") and not cut
		liftHint.Visible = showHint
		if showHint then
			if phase == "ready" then
				liftHint.Text = "Press DOWN on the panel to start the shift."
			elseif state.canDescend then
				liftHint.Text =
					`DOWN: next floor pays x{state.nextMultiplier}.   UP: end the shift and get paid.`
			else
				liftHint.Text = "Bottom floor. UP ends the shift."
			end
		end
	end)
end

return ShiftHud
