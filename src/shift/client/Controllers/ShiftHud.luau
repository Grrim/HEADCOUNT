--!strict
-- What a player needs on a shift, and nothing else: the floor and its multiplier, the quota, the
-- battery, short notices, the stars a shot earned, being cut out of frame, and the pay screen with
-- upgrades between shifts. Prototype text is English only and lives here, not in Strings.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
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
local results: Frame
local lastNoticeId = 0
local state: { [string]: any } = { phase = "ready", depth = 0, quota = 40, banked = 0, carried = 0 }
local toastToken = 0

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
	return p.X >= -6 and p.X <= 6 and p.Z >= -12 and p.Z <= 0 and p.Y < 12
end

local function closeResults()
	results.Visible = false
end

local function showResults(data: { [string]: any })
	results:ClearAllChildren()
	results.Visible = true
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
	local lines = {
		`Footage brought back: {data.banked} / quota {data.quota}`,
		`Deepest floor: -{data.deepest}`,
		if returned and data.met
			then `Pay: {data.payout} frames`
			else `Pay: {data.payout} frames (the Bureau pays a quarter)`,
		`Your frames: {data.money}`,
	}
	for index, line in lines do
		Ui.text({
			Size = UDim2.new(1, 0, 0, 22),
			TextSize = 18,
			Text = line,
			LayoutOrder = 1 + index,
		}, results)
	end
	Ui.eyebrow("UPGRADES", { LayoutOrder = 10 }, results)
	for index, upgrade in data.upgrades or {} do
		local row = Ui.frame({
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = 10 + index,
		}, results)
		Ui.text({
			Size = UDim2.new(0.62, 0, 1, 0),
			TextSize = 17,
			TextYAlignment = Enum.TextYAlignment.Center,
			Text = `{upgrade.name}  {upgrade.value}  (level {upgrade.level}/{upgrade.maxLevel})`,
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
			Net.get("ShiftAction"):FireServer("next")
		end
	)
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
		Size = UDim2.fromOffset(460, 420),
		BackgroundTransparency = 0.08,
		Visible = false,
	}, gui)
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
		if phase ~= previousPhase and (phase == "ready" or phase == "ride") then
			closeResults()
		end
	end)

	Net.get("ShiftResult").OnClientEvent:Connect(showResults)

	Net.get("FootageScored").OnClientEvent:Connect(function(data)
		if data.teammate then
			ShiftHud.toast(`{data.teammate} got footage: +{data.added}`, Ui.C.Muted)
			return
		end
		local shots = data.shots or {}
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
			local line = "CUT OUT OF FRAME\nA teammate can film you back (3 s)."
			if typeof(progress) == "number" and progress > 0 then
				line = `CUT OUT OF FRAME\nBeing filmed back... {math.floor(progress * 100)}%`
			elseif selfReturn then
				line ..= "\nOr walk back into the lift after 30 s (once a shift)."
			end
			cutLabel.Text = line
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
