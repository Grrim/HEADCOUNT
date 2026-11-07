--!strict
-- Watching a tape. The main camera flies the recorded path through the live world, with the
-- layer's state swapped: this is why nothing here needs a screen capture. Your body stays behind,
-- standing still and undefended, which is the price of looking.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Grades = require(ReplicatedStorage.Shared.Config.Lighting)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Tape = require(ReplicatedStorage.Shared.Core.Tape)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Playback = {}

local controllers: { [string]: any }
local gui: ScreenGui
local infoLabel: TextLabel
local captionLabel: TextLabel
local band: Frame
local grade: ColorCorrectionEffect
local connection: RBXScriptConnection? = nil
local ghostFolder: Folder? = nil
local isActive = false

local function setControls(enabled: boolean)
	local player = Players.LocalPlayer
	local ok, err = pcall(function()
		local playerModule = require(
			player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
		) :: any
		local controls = playerModule:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
	if not ok then
		warn(`[Playback] controls: {err}`)
	end
end

local function buildGui()
	gui = Ui.screen("Playback", 4)
	gui.Enabled = false
	-- Bars that crop the picture to 4:3, whatever the shape of the device.
	Ui.frame({
		Size = UDim2.new(0.125, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
	}, gui)
	Ui.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.125, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
	}, gui)
	Ui.text({
		Position = UDim2.fromScale(0.15, 0.06),
		Size = UDim2.fromOffset(240, 30),
		TextSize = 24,
		Text = "▶ " .. Strings.get("play"),
	}, gui)
	infoLabel = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.85, 0.06),
		Size = UDim2.fromOffset(240, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, gui)
	Ui.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromOffset(420, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextTransparency = 0.3,
		Text = Strings.get("press_to_stop"),
	}, gui)
	-- At the top, on its own backing: the radio talks over every viewing, and this line is the clue.
	captionLabel = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.new(0.7, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		Text = "",
		Visible = false,
	}, gui)
	-- A tracking band rolling down the picture: only ever seen on a tape, where it makes sense.
	band = Ui.frame({
		Position = UDim2.fromScale(0.125, 0),
		Size = UDim2.new(0.75, 0, 0.03, 0),
		BackgroundColor3 = Palette.Paper,
		BackgroundTransparency = 0.88,
	}, gui)
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "TapeGrade"
	grade.Enabled = false
	for key, value in Grades.Playback do
		(grade :: any)[key] = value
	end
	grade.Parent = Lighting
end

local function buildGhosts(ghosts: { any }): { { model: Part, track: { { number } } } }
	local folder = Instance.new("Folder")
	folder.Name = "TapeGhosts"
	local result = {}
	for _, ghost in ghosts do
		if #ghost.track > 0 then
			local body = Instance.new("Part")
			body.Anchored = true
			body.CanCollide = false
			body.CanQuery = false
			body.Size = Vector3.new(2.2, 5.4, 1.1)
			body.Color = Palette.Suit
			body.Material = Enum.Material.SmoothPlastic
			body.Transparency = 0.25
			body.Parent = folder
			table.insert(result, { model = body, track = ghost.track })
		end
	end
	folder.Parent = Workspace
	ghostFolder = folder
	return result
end

function Playback.active(): boolean
	return isActive
end

function Playback.stop()
	if not isActive then
		return
	end
	isActive = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	gui.Enabled = false
	grade.Enabled = false
	controllers.Hud.setCinema(false)
	if ghostFolder then
		ghostFolder:Destroy()
		ghostFolder = nil
	end
	controllers.Audience.setPlayback(false)
	controllers.RegistrarView.setOverride(nil)
	AudioDirector.setLoop("TapeMotor", false)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = Config.Lens.NormalFov
	end
	LensView.setLocked(false)
	setControls(true)
	Net.get("PlayEnded"):FireServer()
end

local function start(clip: any)
	if isActive then
		return
	end
	isActive = true
	LensView.setLocked(true)
	setControls(false)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Lens.Fov
	gui.Enabled = true
	grade.Enabled = true
	controllers.Hud.setCinema(true)
	infoLabel.Text = Strings.get("play_count", clip.viewings)
	captionLabel.Text = if clip.archiveOrder
		then Strings.get("archive_order", clip.archiveOrder)
		else ""
	captionLabel.Visible = clip.archiveOrder ~= nil
	AudioDirector.setLoop("TapeMotor", true, 0.35, 0.92)
	controllers.Audience.setPlayback(true, clip.seats)
	local ghosts = buildGhosts(clip.ghosts)

	local track = clip.track
	local hz = clip.hz
	local duration = Tape.duration(track, hz)
	local elapsed = 0
	local midpoint = Tape.sampleAt(track, duration / 2, hz)
	local distance = clip.registrarDistance
	if distance then
		-- He stands in the middle of the shot, a little nearer every time this tape is watched.
		local look = Vector3.new(midpoint[4], 0, midpoint[6])
		if look.Magnitude > 0.01 then
			local place = Vector3.new(midpoint[1], midpoint[2] - 4.5, midpoint[3])
				+ look.Unit * distance
			controllers.RegistrarView.setOverride(CFrame.new(place))
		end
	end

	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			Playback.stop()
			return
		end
		local s = Tape.sampleAt(track, elapsed, hz)
		local position = Vector3.new(s[1], s[2], s[3])
		camera.CFrame = CFrame.lookAt(position, position + Vector3.new(s[4], s[5], s[6]))
		band.Position = UDim2.fromScale(0.125, (elapsed * 0.27) % 1)
		for _, ghost in ghosts do
			local index = math.clamp(math.floor(elapsed * Config.Tape.GhostHz) + 1, 1, #ghost.track)
			local g = ghost.track[index]
			local p = Vector3.new(g[1], g[2], g[3])
			ghost.model.CFrame = CFrame.lookAt(p, p + Vector3.new(g[4], 0, g[5]))
		end
	end)
end

function Playback.init(all: { [string]: any })
	controllers = all
	buildGui()
	Net.get("TapePlay").OnClientEvent:Connect(start)
end

return Playback
