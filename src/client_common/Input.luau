--!strict
-- One binding covers keyboard, mouse and gamepad through ContextActionService. On a touch screen
-- the game draws its own buttons instead of the engine's grey circles: a thumb cluster on the
-- right, sized for a thumb, clear of the jump button, and lit to show what is on (camera raised,
-- tape running). Mouse and keyboard players never see them.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Input = {}

Input.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Slot centres, measured in points from the bottom-right corner of the safe area, and button size.
-- The engine's jump button on a phone covers roughly x -95..-25, y -90..-20; nothing goes there.
-- Slot 1 is the thumb's resting place and the biggest target: the camera.
type Slot = { x: number, y: number, size: number }
local PHONE: { Slot } = {
	{ x = -156, y = -66, size = 78 }, -- camera
	{ x = -62, y = -152, size = 64 }, -- record
	{ x = -150, y = -160, size = 56 }, -- play
	{ x = -238, y = -48, size = 50 }, -- light
	{ x = -236, y = -122, size = 50 }, -- radio
}
local TABLET: { Slot } = {
	{ x = -246, y = -120, size = 92 },
	{ x = -120, y = -262, size = 76 },
	{ x = -236, y = -238, size = 66 },
	{ x = -340, y = -96, size = 60 },
	{ x = -340, y = -186, size = 60 },
}

local INK = Color3.fromRGB(9, 10, 11)
local PAPER = Color3.fromRGB(232, 226, 210)
local ACCENT = Color3.fromRGB(182, 214, 150)
local REC = Color3.fromRGB(217, 52, 43)
local LABEL_FONT = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

type Pad = {
	button: TextButton,
	stroke: UIStroke,
	dot: Frame?,
	scale: UIScale,
	slot: number,
	state: string,
}

local gui: ScreenGui? = nil
local pads: { [string]: Pad } = {}
-- Which binding currently owns each slot, newest last; an older one shows again on unbind.
local slotOwners: { [number]: { string } } = {}

local function layout(): { Slot }
	local camera = Workspace.CurrentCamera
	local short = if camera then math.min(camera.ViewportSize.X, camera.ViewportSize.Y) else 400
	return if short > 600 then TABLET else PHONE
end

local function touchGui(): ScreenGui
	if gui then
		return gui
	end
	local made = Instance.new("ScreenGui")
	made.Name = "TouchControls"
	made.ResetOnSpawn = false
	made.IgnoreGuiInset = true
	made.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	made.DisplayOrder = 8
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = made
	return made
end

local function place(pad: Pad)
	local slot = layout()[pad.slot] or PHONE[1]
	pad.button.AnchorPoint = Vector2.new(0.5, 0.5)
	pad.button.Position = UDim2.new(1, slot.x, 1, slot.y)
	pad.button.Size = UDim2.fromOffset(slot.size, slot.size)
	pad.button.TextSize = if slot.size >= 70 then 15 else 13
end

local function paint(pad: Pad)
	local state = pad.state
	local fill, text, line, alpha = INK, PAPER, PAPER, 0.35
	if state == "active" then
		fill, text, line, alpha = ACCENT, INK, ACCENT, 0.05
	elseif state == "danger" then
		fill, text, line, alpha = REC, PAPER, REC, 0.05
	elseif state == "disabled" then
		alpha = 0.7
	end
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
	TweenService:Create(pad.button, info, {
		BackgroundColor3 = fill,
		BackgroundTransparency = alpha,
		TextColor3 = text,
		TextTransparency = if state == "disabled" then 0.5 else 0,
	}):Play()
	TweenService:Create(pad.stroke, info, {
		Color = line,
		Transparency = if state == "idle" then 0.55 else 0.1,
	}):Play()
	if pad.dot then
		pad.dot.BackgroundColor3 = if state == "danger" then PAPER else REC
	end
end

local function refreshSlot(slot: number)
	local owners = slotOwners[slot]
	if not owners then
		return
	end
	local top = owners[#owners]
	for _, name in owners do
		local pad = pads[name]
		if pad then
			pad.button.Visible = name == top
		end
	end
end

local function makePad(name: string, title: string, slot: number, onPress: () -> ())
	local parent = touchGui()
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.FontFace = LABEL_FONT
	button.Text = title
	button.TextColor3 = PAPER
	button.BackgroundColor3 = INK
	button.BackgroundTransparency = 0.35
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = PAPER
	stroke.Transparency = 0.55
	stroke.Thickness = 1.5
	stroke.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local dot: Frame? = nil
	if name == "Record" then
		-- The red dot every camcorder has on its record button.
		local made = Instance.new("Frame")
		made.AnchorPoint = Vector2.new(0.5, 0.5)
		made.Position = UDim2.fromScale(0.5, 0.24)
		made.Size = UDim2.fromOffset(9, 9)
		made.BackgroundColor3 = REC
		made.BorderSizePixel = 0
		made.Parent = button
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = made
		dot = made
	end
	local pad: Pad = {
		button = button,
		stroke = stroke,
		dot = dot,
		scale = scale,
		slot = slot,
		state = "idle",
	}
	pads[name] = pad
	place(pad)
	paint(pad)
	-- Fires on touch-down, not release: a camera has to come up the instant the thumb lands.
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			scale.Scale = 0.9
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
			onPress()
		end
	end)
	slotOwners[slot] = slotOwners[slot] or {}
	table.insert(slotOwners[slot], name)
	refreshSlot(slot)
end

function Input.bind(
	name: string,
	onPress: () -> (),
	keys: { Enum.KeyCode | Enum.UserInputType },
	touchTitle: string?,
	touchSlot: number?
)
	local function handler(_, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			onPress()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	if #keys > 0 then
		ContextActionService:BindAction(name, handler, false, table.unpack(keys))
	end
	if touchTitle and Input.isTouch then
		Input.unbindTouch(name)
		makePad(name, touchTitle, touchSlot or 5, onPress)
	end
end

function Input.unbindTouch(name: string)
	local pad = pads[name]
	if not pad then
		return
	end
	pads[name] = nil
	local owners = slotOwners[pad.slot]
	if owners then
		local index = table.find(owners, name)
		if index then
			table.remove(owners, index)
		end
		refreshSlot(pad.slot)
	end
	pad.button:Destroy()
end

function Input.unbind(name: string)
	ContextActionService:UnbindAction(name)
	Input.unbindTouch(name)
end

-- "idle", "active" (accent fill), "danger" (red fill) or "disabled". No-op off touch.
function Input.setState(name: string, state: string)
	local pad = pads[name]
	if pad and pad.state ~= state then
		pad.state = state
		paint(pad)
	end
end

-- Hides every touch button, for cinematic moments that own the screen.
function Input.setTouchVisible(visible: boolean)
	if gui then
		gui.Enabled = visible
	end
end

-- Re-lay the cluster when a tablet rotates or a window is resized.
task.defer(function()
	local camera = Workspace.CurrentCamera
	if camera and Input.isTouch then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			for _, pad in pads do
				place(pad)
			end
		end)
	end
end)

return Input
