--!strict
-- A notebook the player can open at any time: what to do, what they have found, how the controls
-- work, and how bright the picture is. One panel for both places; each fills it with its own pages.
-- J or L1 opens it, B or the close button shuts it, and a corner tag says it exists.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Brightness = require(ReplicatedStorage.ClientCommon.Brightness)
local Input = require(ReplicatedStorage.ClientCommon.Input)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Journal = {}

export type Api = {
	heading: (text: string) -> (),
	line: (text: string, color: Color3?) -> (),
	button: (text: string, onClick: () -> ()) -> (),
	controls: (list: { { any } }) -> (),
	brightness: () -> (),
}

export type Options = {
	titleKey: string,
	tagKey: string,
	touchKey: string,
	render: (api: Api) -> (),
	-- Return false while something else owns the screen (a tape, the ending).
	canOpen: (() -> boolean)?,
}

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local list: ScrollingFrame
local closeButton: TextButton
local tag: TextButton
local options: Options? = nil
local isOpen = false
local tagWanted = true

local function usingGamepad(): boolean
	return UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
end

-- The key to name in a hint: whatever device is in the player's hands.
function Journal.keyName(pc: string, pad: string): string
	if usingGamepad() then
		return pad
	end
	return pc
end

local function render()
	local opts = options
	if not opts then
		return
	end
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local api: Api
	api = {
		heading = function(text: string)
			Ui.text({
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, 0, 0, 28),
				TextYAlignment = Enum.TextYAlignment.Bottom,
				TextSize = 14,
				TextColor3 = Palette.Rec,
				Text = text,
			}, list)
		end,
		line = function(text: string, color: Color3?)
			Ui.text({
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 16,
				TextColor3 = color or Palette.Paper,
				Text = text,
			}, list)
		end,
		button = function(text: string, onClick: () -> ())
			Ui.button(text, {
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, 0, 0, 34),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, list, onClick)
		end,
		-- Each entry is { pc key, gamepad key, action string key }.
		controls = function(entries: { { any } })
			if Input.isTouch then
				api.line(Strings.get("ctl_touch"), Palette.Crt)
				return
			end
			for _, entry in entries do
				local key = if usingGamepad() then entry[2] else entry[1]
				api.line(`{key}  {Strings.get(entry[3])}`, Palette.Crt)
			end
		end,
		brightness = function()
			local holder = Ui.frame({
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
			}, list)
			local meter = Ui.text({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -120, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextColor3 = Palette.Crt,
				Text = Brightness.meter(),
			}, holder)
			local function step(delta: number)
				Brightness.change(delta)
				meter.Text = Brightness.meter()
			end
			Ui.button("-", { Size = UDim2.fromOffset(52, 36), TextSize = 22 }, holder, function()
				step(-1)
			end)
			Ui.button(
				"+",
				{
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(52, 36),
					TextSize = 22,
				},
				holder,
				function()
					step(1)
				end
			)
		end,
	}
	opts.render(api)
end

function Journal.close()
	if not isOpen then
		return
	end
	isOpen = false
	panel.Visible = false
	ContextActionService:UnbindAction("CloseJournal")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = nil
	end
	Journal.setTagVisible(tagWanted)
end

function Journal.open()
	local opts = options
	if isOpen or not opts or (opts.canOpen and not opts.canOpen()) then
		return
	end
	isOpen = true
	render()
	panel.Visible = true
	tag.Visible = false
	AudioDirector.play("Paper", 0.4)
	ContextActionService:BindActionAtPriority("CloseJournal", function(_, state)
		if state == Enum.UserInputState.Begin then
			Journal.close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.ButtonB)
	if usingGamepad() then
		GuiService.SelectedObject = closeButton
	end
end

function Journal.toggle()
	if isOpen then
		Journal.close()
	else
		Journal.open()
	end
end

function Journal.isOpen(): boolean
	return isOpen
end

-- Redraws the pages if the notebook is open, so a clue found while reading appears at once.
function Journal.refresh()
	if isOpen then
		render()
	end
end

function Journal.setTagVisible(visible: boolean)
	tagWanted = visible
	if tag then
		tag.Visible = visible and not isOpen
	end
end

function Journal.setup(opts: Options)
	options = opts
	gui = Ui.screen("Journal", 8)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.62, 0, 0.78, 0),
		BackgroundColor3 = Color3.fromRGB(12, 13, 14),
		BackgroundTransparency = 0.04,
		Visible = false,
	}, gui)
	Ui.make("UISizeConstraint", {
		MinSize = Vector2.new(320, 260),
		MaxSize = Vector2.new(640, 560),
	}, panel)
	Ui.make("UIStroke", { Color = Palette.Paper, Thickness = 1, Transparency = 0.6 }, panel)
	-- A red margin rule, like the case files the objective card is cut from.
	Ui.frame({ Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Palette.Rec }, panel)
	titleLabel = Ui.text({
		Position = UDim2.new(0, 20, 0, 12),
		Size = UDim2.new(1, -130, 0, 26),
		TextSize = 19,
		Text = Strings.get(opts.titleKey),
	}, panel)
	-- Modal frees the cursor from first-person lock while the notebook is open.
	closeButton = Ui.button(Strings.get("hub_close"), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(96, 34),
		TextSize = 14,
		Modal = true,
	}, panel, Journal.close)
	Ui.frame({
		Position = UDim2.new(0, 20, 0, 46),
		Size = UDim2.new(1, -36, 0, 1),
		BackgroundColor3 = Palette.Paper,
		BackgroundTransparency = 0.7,
	}, panel)
	list = Ui.make("ScrollingFrame", {
		Position = UDim2.new(0, 20, 0, 52),
		Size = UDim2.new(1, -30, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Palette.Paper,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, panel)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, list)
	Ui.make("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 10) }, list)

	local keyName = if Input.isTouch then nil else Journal.keyName("J", "L1")
	tag = Ui.button(
		if keyName then Strings.get(opts.tagKey, keyName) else Strings.get(opts.touchKey),
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 52),
			Size = UDim2.fromOffset(if keyName then 128 else 104, 30),
			TextSize = 14,
			BackgroundTransparency = 0.35,
			BackgroundColor3 = Color3.fromRGB(8, 10, 12),
			BorderColor3 = Palette.Paper,
			TextColor3 = Palette.Paper,
		},
		gui,
		Journal.toggle
	)
	Input.bind("Journal", Journal.toggle, { Enum.KeyCode.J, Enum.KeyCode.ButtonL1 })
	titleLabel.Text = Strings.get(opts.titleKey)
end

return Journal
