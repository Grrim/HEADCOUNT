--!strict
-- The ending, and the whole point of the mission. A last tape nobody recorded: the hall, shot from
-- the stage, with your team standing among the audience, dated next week. Then a flash of a place
-- you have never been. Then the report, as if nothing happened.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Build = require(ReplicatedStorage.Shared.World.Build)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local EndTape = {}

local controllers: { [string]: any }

local function formatTime(seconds: number): string
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function setControls(enabled: boolean)
	pcall(function()
		local module =
			Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
		local controls = (require(module :: ModuleScript) :: any):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

-- The next mission's bus, for a few seconds. Built only here, nowhere in the level. It lives in a
-- ViewportFrame because the shot is too short for the engine to light a new place in the world:
-- out there it renders as black with white bars, while a viewport has its own light at once.
local function buildBus(gui: ScreenGui): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "NextTape"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.new(0, 0, 0)
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 0
	viewport.Ambient = Color3.fromRGB(74, 80, 76)
	viewport.LightColor = Palette.Fluorescent
	viewport.LightDirection = Vector3.new(0.2, -1, -0.35)
	local folder = Instance.new("Folder")
	local floorY = 0
	Build.box(
		folder,
		"Floor",
		-4,
		floorY - 1,
		-40,
		4,
		floorY,
		4,
		Palette.Carpet,
		Enum.Material.Fabric
	)
	Build.box(folder, "Roof", -4, floorY + 8, -40, 4, floorY + 9, 4, Palette.Ceiling)
	Build.box(folder, "WallL", -5, floorY, -40, -4, floorY + 8, 4, Palette.Shadow)
	Build.box(folder, "WallR", 4, floorY, -40, 5, floorY + 8, 4, Palette.Shadow)
	Build.box(folder, "WallEnd", -4, floorY, -41, 4, floorY + 8, -40, Palette.Shadow)
	for row = 0, 9 do
		local z = -row * 4
		for _, x in { -2.9, 2.9 } do
			Build.chair(folder, "Seat", CFrame.new(x, floorY, z))
		end
		if row % 3 == 0 then
			Build.panel(folder, 0, floorY + 7.9, z, 1, 3, 1, 14, Palette.Fluorescent)
		end
	end
	-- Someone is standing at the far end, far too tall for the ceiling.
	local figure = Build.box(folder, "Figure", -1, floorY, -37, 1, floorY + 8, -36, Palette.Ink)
	figure.CanCollide = false
	folder.Parent = viewport
	local shot = Instance.new("Camera")
	shot.FieldOfView = 50
	shot.CFrame = CFrame.lookAt(Vector3.new(0, floorY + 5, 2), Vector3.new(0, floorY + 4, -36))
	shot.Parent = viewport
	viewport.CurrentCamera = shot
	viewport.Parent = gui
	return viewport
end

local function report(result: any)
	local gui = Ui.screen("EndReport", 20)
	local back =
		Ui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0) }, gui)
	local earnedNames = {}
	for _, id in result.earned or {} do
		table.insert(earnedNames, Strings.get(`ach_{id}`))
	end
	local lines = {
		Strings.get("report_take", result.take),
		Strings.get("report_time", formatTime(result.duration)),
		Strings.get("report_replays", result.replays),
		Strings.get("report_cuts", result.cuts),
		Strings.get("report_docs", result.docs),
		if #earnedNames > 0
			then Strings.get("report_earned", table.concat(earnedNames, ", "))
			else "",
		"",
		Strings.get(if result.canTeleport then "report_return" else "report_return_studio"),
	}
	Ui.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(600, 48),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if result.success then Palette.Paper else Palette.Rec,
		Text = Strings.get(if result.success then "end_success" else "end_failed"),
	}, back)
	Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.7, 0, 0.4, 0),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = table.concat(lines, "\n"),
	}, back)
end

local function play(result: any)
	if controllers.Playback.active() then
		controllers.Playback.stop()
	end
	LensView.setLocked(true)
	setControls(false)
	controllers.Hud.setCinema(true)
	controllers.Audience.ended = true
	controllers.Audience.refresh()

	if not result.success then
		task.wait(1.5)
		report(result)
		return
	end

	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 50
	local gui = Ui.screen("FinalTape", 15)
	local cover = Ui.frame(
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 5 },
		gui
	)
	Ui.frame({ Size = UDim2.new(0.125, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0) }, gui)
	Ui.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.125, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
	}, gui)
	Ui.text({
		Position = UDim2.fromScale(0.15, 0.06),
		Size = UDim2.fromOffset(500, 30),
		TextSize = 22,
		Text = "▶ " .. Strings.get("final_date", result.futureDate),
	}, gui)
	Ui.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.15, 0.94),
		Size = UDim2.fromOffset(500, 30),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = Strings.get("final_attendees", #result.names),
	}, gui)

	-- The bell, then silence, then the picture fades up on the audience from the stage.
	AudioDirector.play("Bell", 0.9)
	AudioDirector.setAbsolute(true)
	task.wait(1.4)
	AudioDirector.setLoop("TapeMotor", true, 0.3, 0.9)
	AudioDirector.setLoop("Music", true, 0.22)
	TweenService:Create(cover, TweenInfo.new(1.6), { BackgroundTransparency = 1 }):Play()
	local startCf = CFrame.lookAt(Vector3.new(0, 8.5, -21), Vector3.new(0, 4, -3))
	local endCf = CFrame.lookAt(Vector3.new(0, 7, -14.5), Vector3.new(4, 4, -3))
	local elapsed = 0
	local duration = 11
	local connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		camera.CFrame = startCf:Lerp(endCf, math.min(elapsed / duration, 1))
	end)
	task.wait(duration)
	connection:Disconnect()

	-- A hard cut to somewhere new, and the music does not come along.
	AudioDirector.setLoop("Music", false)
	cover.BackgroundTransparency = 0
	task.wait(0.5)
	local bus = buildBus(gui)
	cover.BackgroundTransparency = 1
	task.wait(3)
	cover.BackgroundTransparency = 0
	bus:Destroy()
	AudioDirector.setLoop("TapeMotor", false)
	task.wait(1.6)
	gui:Destroy()
	report(result)
end

function EndTape.init(all: { [string]: any })
	controllers = all
end

function EndTape.start()
	Net.get("EndMission").OnClientEvent:Connect(function(result)
		task.spawn(play, result)
	end)
end

return EndTape
