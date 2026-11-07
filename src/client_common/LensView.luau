--!strict
-- The camcorder's viewfinder, shared by the hub tutorial and the missions. It owns the on-screen
-- frame, the colour grade, the field of view and the report to the server. What the lens reveals
-- is built by whoever subscribes to onChanged.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(script.Parent.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Grades = require(ReplicatedStorage.Shared.Config.Lighting)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(script.Parent.Ui)

local LensView = {}

LensView.raised = false

local listeners: { (raised: boolean) -> () } = {}
local locked = false
local gui: ScreenGui
local statusLabel: TextLabel
local tapesLabel: TextLabel
local timeLabel: TextLabel
local recordingSince: number? = nil
local grade: ColorCorrectionEffect
local reportRemote: RemoteEvent? = nil
local frameParts: { Frame } = {}
local warningLabel: TextLabel
local warningBar: Frame
local warningAt = 0
local interferenceBars: { Frame } = {}
local interference = 0

local function corner(root: Instance, anchor: Vector2, position: UDim2)
	local arm, thick = 0.07, 2
	table.insert(
		frameParts,
		Ui.frame({
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.new(arm, 0, 0, thick),
			BackgroundColor3 = Palette.Paper,
		}, root)
	)
	table.insert(
		frameParts,
		Ui.frame({
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.new(0, thick, arm * 1.6, 0),
			BackgroundColor3 = Palette.Paper,
		}, root)
	)
end

local function buildGui()
	gui = Ui.screen("Viewfinder", 3)
	gui.Enabled = false
	local inset = 0.05
	corner(gui, Vector2.new(0, 0), UDim2.fromScale(inset, inset * 1.4))
	corner(gui, Vector2.new(1, 0), UDim2.fromScale(1 - inset, inset * 1.4))
	corner(gui, Vector2.new(0, 1), UDim2.fromScale(inset, 1 - inset * 1.4))
	corner(gui, Vector2.new(1, 1), UDim2.fromScale(1 - inset, 1 - inset * 1.4))
	statusLabel = Ui.text({
		Position = UDim2.fromScale(inset + 0.015, inset * 1.4 + 0.02),
		Size = UDim2.fromOffset(200, 28),
		TextSize = 22,
		Text = Strings.get("standby"),
	}, gui)
	timeLabel = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1 - inset - 0.015, inset * 1.4 + 0.02),
		Size = UDim2.fromOffset(180, 28),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "00:00:00",
	}, gui)
	tapesLabel = Ui.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(inset + 0.015, 1 - inset * 1.4 - 0.02),
		Size = UDim2.fromOffset(220, 26),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "",
	}, gui)
	-- A small centre mark, because the framing cone is what actually counts.
	Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 1),
		BackgroundColor3 = Palette.Paper,
		BackgroundTransparency = 0.4,
	}, gui)
	Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1, 26),
		BackgroundColor3 = Palette.Paper,
		BackgroundTransparency = 0.4,
	}, gui)
end

-- The viewfinder's own warning that the thing in frame is noticing back.
local function buildWarnings()
	warningLabel = Ui.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromOffset(320, 24),
		TextSize = 18,
		TextColor3 = Palette.Rec,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Text = Strings.get("lens_registering"),
	}, gui)
	warningBar = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.865),
		Size = UDim2.fromOffset(0, 5),
		BackgroundColor3 = Palette.Rec,
		Visible = false,
	}, gui)
	for _ = 1, 5 do
		table.insert(
			interferenceBars,
			Ui.frame({
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = Palette.Paper,
				BackgroundTransparency = 1,
				ZIndex = 0,
			}, gui)
		)
	end
end

function LensView.setWarning(fraction: number)
	warningAt = os.clock()
	warningLabel.Visible = true
	warningBar.Visible = true
	warningBar.Size = UDim2.fromOffset(320 * fraction, 5)
end

-- 0 to 1. The closer he is, the less the tape holds together.
function LensView.setInterference(amount: number)
	interference = amount
end

local function applyFrameColor()
	local id = Players.LocalPlayer:GetAttribute("FrameId")
	for _, frame in Cosmetics.Frames do
		if frame.id == id then
			for _, part in frameParts do
				part.BackgroundColor3 = frame.color
			end
		end
	end
end

local function tweenGrade(values: { [string]: any }, seconds: number)
	TweenService:Create(grade, TweenInfo.new(seconds), values):Play()
end

local function applyView()
	local camera = Workspace.CurrentCamera
	local raised = LensView.raised
	gui.Enabled = raised
	if raised then
		tweenGrade(Grades.Lens, 0.08)
	else
		tweenGrade({
			Contrast = 0,
			Saturation = 0,
			Brightness = 0,
			TintColor = Color3.new(1, 1, 1),
		}, 0.08)
	end
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.12), {
			FieldOfView = if raised then Config.Lens.Fov else Config.Lens.NormalFov,
		}):Play()
	end
end

function LensView.onChanged(callback: (raised: boolean) -> ())
	table.insert(listeners, callback)
end

function LensView.setRaised(raised: boolean)
	if locked and raised then
		return
	end
	if raised == LensView.raised then
		return
	end
	LensView.raised = raised
	applyView()
	AudioDirector.play("LensUp", 0.5, if raised then 1 else 0.85)
	if reportRemote and not raised then
		reportRemote:FireServer(false)
	end
	if not raised then
		LensView.setRecording(false)
	end
	for _, callback in listeners do
		task.spawn(callback, raised)
	end
end

function LensView.toggle()
	LensView.setRaised(not LensView.raised)
end

-- Locked while something else owns the camera, such as a tape playing.
function LensView.setLocked(value: boolean)
	locked = value
	if value then
		LensView.setRaised(false)
	end
end

function LensView.setTapes(left: number)
	tapesLabel.Text = Strings.get("tapes_left", left)
end

function LensView.setRecording(on: boolean)
	recordingSince = if on then os.clock() else nil
	statusLabel.Text = Strings.get(if on then "rec" else "standby")
	statusLabel.TextColor3 = if on then Palette.Rec else Palette.Paper
	AudioDirector.setLoop("TapeMotor", on, 0.3, 1)
end

function LensView.init(reportsToServer: RemoteEvent?)
	reportRemote = reportsToServer
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LensGrade"
	grade.Parent = Lighting
	buildGui()
	buildWarnings()
	applyFrameColor()
	Players.LocalPlayer:GetAttributeChangedSignal("FrameId"):Connect(applyFrameColor)

	local lastReport = 0
	local interval = 1 / Config.Lens.ReportHz
	RunService.RenderStepped:Connect(function()
		if not LensView.raised then
			return
		end
		local now = os.clock()
		if warningLabel.Visible and now - warningAt > 0.7 then
			warningLabel.Visible = false
			warningBar.Visible = false
		end
		for _, bar in interferenceBars do
			if interference > 0.05 and math.random() < interference then
				bar.Position = UDim2.fromScale(0, math.random())
				bar.BackgroundTransparency = 1 - interference * 0.7
			else
				bar.BackgroundTransparency = 1
			end
		end
		if recordingSince then
			local elapsed = now - recordingSince
			timeLabel.Text = string.format("00:%02d:%02d", elapsed // 1, (elapsed % 1 * 25) // 1)
			statusLabel.Visible = now % 1 < 0.6
		else
			statusLabel.Visible = true
			timeLabel.Text = os.date("%H:%M:%S") :: string
		end
		if reportRemote and now - lastReport >= interval then
			lastReport = now
			local camera = Workspace.CurrentCamera
			if camera then
				reportRemote:FireServer(true, camera.CFrame)
			end
		end
	end)
end

return LensView
