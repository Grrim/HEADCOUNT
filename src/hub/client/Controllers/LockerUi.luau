--!strict
-- The player's own locker: viewfinder colour, service record and commendations.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Achievements = require(ReplicatedStorage.Shared.Core.Achievements)
local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Panels = require(ReplicatedStorage.ClientCommon.Panels)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local LockerUi = {}

local panel: Frame
local framesRow: Frame
local recordLabel: TextLabel
local achievementsLabel: TextLabel
local profile: any = nil

local function render()
	if not profile then
		return
	end
	framesRow:ClearAllChildren()
	for index, frame in Cosmetics.Frames do
		local unlocked = not frame.requires or profile.achievements[frame.requires] == true
		local selected = profile.prefs.frame == frame.id
			or (not profile.prefs.frame and frame.id == "paper")
		local label = if unlocked then Strings.get(frame.nameKey) else Strings.get("frame_locked")
		Ui.button(
			if selected then `[{label}]` else label,
			{
				Position = UDim2.fromOffset((index - 1) * 124, 0),
				Size = UDim2.fromOffset(118, 44),
				TextSize = 13,
				TextColor3 = if unlocked then frame.color else Palette.WallDark,
				BorderColor3 = if unlocked then frame.color else Palette.WallDark,
			},
			framesRow,
			function()
				if unlocked then
					AudioDirector.play("LensUp", 0.4)
					Net.get("LockerAction"):FireServer("frame", frame.id)
				end
			end
		)
	end
	local stats = profile.stats
	recordLabel.Text = Strings.get("record_line", stats.completions, stats.replays, stats.cuts)
	local lines = {}
	for _, id in Achievements.ALL do
		local mark = if profile.achievements[id] then "[x]" else "[ ]"
		table.insert(lines, `{mark} {Strings.get(`ach_{id}`)}`)
	end
	achievementsLabel.Text = table.concat(lines, string.char(10))
end

function LockerUi.init()
	local gui = Ui.screen("LockerUi", 5)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.72, 0, 0.8, 0),
		BackgroundColor3 = Color3.fromRGB(16, 18, 20),
		BorderSizePixel = 2,
		BorderColor3 = Palette.Metal,
		Visible = false,
	}, gui)
	Ui.make("UISizeConstraint", {
		MinSize = Vector2.new(360, 320),
		MaxSize = Vector2.new(700, 560),
	}, panel)
	Ui.text({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -120, 0, 26),
		TextSize = 19,
		Text = Strings.get("locker_title"),
	}, panel)
	Ui.button(
		Strings.get("hub_close"),
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(92, 34),
			TextSize = 14,
			Modal = true,
		},
		panel,
		function()
			panel.Visible = false
		end
	)
	Ui.text({
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 22),
		TextSize = 15,
		Text = Strings.get("locker_frames"),
	}, panel)
	local scroller = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 0, 58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(630, 0),
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
	}, panel)
	framesRow = Ui.frame({ Size = UDim2.fromOffset(630, 44), BackgroundTransparency = 1 }, scroller)
	recordLabel = Ui.text({
		Position = UDim2.fromOffset(16, 142),
		Size = UDim2.new(1, -32, 0, 24),
		TextSize = 15,
		TextColor3 = Palette.Crt,
		Text = "",
	}, panel)
	achievementsLabel = Ui.text({
		Position = UDim2.fromOffset(16, 172),
		Size = UDim2.new(1, -32, 1, -184),
		TextSize = 15,
		Text = "",
	}, panel)
	Panels.watch(panel)
end

function LockerUi.start()
	Net.get("DocsState").OnClientEvent:Connect(function(state)
		profile = state
		render()
	end)
	Workspace:WaitForChild("Map"):WaitForChild("Dressing", 20)
	task.wait(0.5)
	for _, locker in CollectionService:GetTagged("StaffLocker") do
		local prompt = locker:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function()
				render()
				panel.Visible = true
			end)
		end
	end
end

return LockerUi
