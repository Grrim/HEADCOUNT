--!strict
-- The parts of the lobby that are about you: your photograph already on the personnel board with a
-- hire date before you were born, a locker with your name on it, and a television that knows.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local StaffRoom = {}

local COLUMNS, ROWS = 6, 3

local function surface(part: BasePart, face: Enum.NormalId, canvas: Vector2): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvas
	gui.LightInfluence = 0.7
	gui.Parent = part
	return gui
end

local function buildBoard(board: BasePart)
	local player = Players.LocalPlayer
	local gui = surface(board, Enum.NormalId.Front, Vector2.new(880, 400))
	local ownSlot = 8 + (player.UserId % 4)
	for index = 1, COLUMNS * ROWS do
		local col = (index - 1) % COLUMNS
		local row = (index - 1) // COLUMNS
		local card = Ui.frame({
			Position = UDim2.fromOffset(16 + col * 144, 12 + row * 130),
			Size = UDim2.fromOffset(130, 120),
			BackgroundColor3 = Palette.Paper,
		}, gui)
		local photo = Ui.frame({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(62, 80),
			BackgroundColor3 = Palette.WallDark,
		}, card)
		if index == ownSlot then
			-- The player's real avatar face: the one card that is not anonymous.
			Ui.make("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Crop,
				Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
			}, photo)
			Ui.text({
				Position = UDim2.fromOffset(74, 8),
				Size = UDim2.fromOffset(54, 80),
				TextSize = 11,
				TextColor3 = Palette.Ink,
				Text = player.DisplayName,
			}, card)
			Ui.text({
				Position = UDim2.fromOffset(8, 92),
				Size = UDim2.fromOffset(118, 24),
				TextSize = 12,
				TextColor3 = Palette.Rec,
				Text = "03.03.1979",
			}, card)
		else
			Ui.frame({
				Position = UDim2.fromOffset(6, 24),
				Size = UDim2.fromOffset(50, 11),
				BackgroundColor3 = Palette.Ink,
			}, photo)
			Ui.frame({
				Position = UDim2.fromOffset(74, 14),
				Size = UDim2.fromOffset(48, 8),
				BackgroundColor3 = Palette.Ink,
			}, card)
			Ui.frame({
				Position = UDim2.fromOffset(74, 30),
				Size = UDim2.fromOffset(34, 8),
				BackgroundColor3 = Palette.Ink,
			}, card)
		end
	end
end

local function buildLockerName()
	local player = Players.LocalPlayer
	for _, locker in CollectionService:GetTagged("StaffLocker") do
		if locker:GetAttribute("LockerIndex") == 7 then
			local gui = surface(locker :: BasePart, Enum.NormalId.Front, Vector2.new(120, 460))
			Ui.frame({
				Position = UDim2.fromOffset(14, 60),
				Size = UDim2.fromOffset(92, 34),
				BackgroundColor3 = Palette.Paper,
			}, gui)
			Ui.text({
				Position = UDim2.fromOffset(16, 62),
				Size = UDim2.fromOffset(88, 30),
				TextSize = 13,
				TextColor3 = Palette.Ink,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Text = player.DisplayName,
			}, gui)
		end
	end
end

-- Loops a few lines of a notice. One of them is addressed to whoever is watching.
local function runTv(screen: BasePart)
	local gui = surface(screen, Enum.NormalId.Back, Vector2.new(320, 240))
	Ui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.Ink }, gui)
	local label = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		TextSize = 26,
		TextColor3 = Palette.Crt,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	}, gui)
	local lines = { "tv_1", "tv_2", "tv_3" }
	local index = 0
	task.spawn(function()
		while true do
			index = index % #lines + 1
			label.Text = Strings.get(lines[index], Players.LocalPlayer.DisplayName)
			task.wait(5)
		end
	end)
end

function StaffRoom.start()
	local map = Workspace:WaitForChild("Map")
	map:WaitForChild("Dressing", 20)
	task.wait(0.5)
	for _, board in CollectionService:GetTagged("PersonnelBoard") do
		buildBoard(board :: BasePart)
	end
	buildLockerName()
	for _, screen in CollectionService:GetTagged("HallTv") do
		runTv(screen :: BasePart)
	end
	local machine = map:FindFirstChild("CoffeeMachine", true)
	local prompt = machine and machine:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function()
			AudioDirector.play("RecStart", 0.5, 0.7)
		end)
	end
end

return StaffRoom
