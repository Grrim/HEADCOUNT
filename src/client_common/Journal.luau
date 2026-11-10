--!strict
-- A notebook the player can open at any time: what to do, what they have found, how the controls
-- work, and how bright the picture is. One panel for both places; each fills it with its own pages.
-- J or L1 opens it, B or the close button shuts it, and a corner tag says it exists.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Brightness = require(ReplicatedStorage.ClientCommon.Brightness)
local Input = require(ReplicatedStorage.ClientCommon.Input)
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
local tagStroke: UIStroke
local options: Options? = nil
local isOpen = false
local tagWanted = true
local tagText = ""
local pingToken = 0

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
			Ui.eyebrow(text, {
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, 0, 0, 30),
				TextYAlignment = Enum.TextYAlignment.Bottom,
				TextColor3 = Ui.C.Danger,
			}, list)
		end,
		line = function(text: string, color: Color3?)
			Ui.text({
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 16,
				LineHeight = 1.1,
				TextColor3 = color or Ui.C.Text,
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
				api.line(Strings.get("ctl_touch"), Ui.C.Accent)
				return
			end
			for _, entry in entries do
				local key = if usingGamepad() then entry[2] else entry[1]
				local row = Ui.frame({
					LayoutOrder = nextOrder(),
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
				}, list)
				Ui.list(row, 10, true).VerticalAlignment = Enum.VerticalAlignment.Center
				Ui.keycap(tostring(key), { LayoutOrder = 1 }, row)
				Ui.text({
					LayoutOrder = 2,
					Size = UDim2.new(1, -90, 0, 22),
					TextSize = 15,
					TextColor3 = Ui.C.Muted,
					TextYAlignment = Enum.TextYAlignment.Center,
					Text = Strings.get(entry[3]),
				}, row)
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
				TextColor3 = Ui.C.Accent,
				FontFace = Ui.Fonts.MonoBold,
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
	-- Reading the notebook clears the mark.
	pingToken += 1
	tag.Text = tagText
	tag.TextColor3 = Ui.C.Text
	tagStroke.Color = Ui.C.Text
	Ui.open(panel)
	tag.Visible = false
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

-- Something new was written down: the corner tag turns red and gains a mark for a few seconds.
function Journal.ping()
	if not tag or isOpen then
		return
	end
	pingToken += 1
	local token = pingToken
	tag.Text = `{tagText}  +`
	tag.TextColor3 = Ui.C.Danger
	tagStroke.Color = Ui.C.Danger
	-- A small nudge so the eye goes to the corner once.
	local scale = tag:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 1.12
		Ui.tween(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 })
	end
	task.delay(6, function()
		if token == pingToken then
			tag.Text = tagText
			tag.TextColor3 = Ui.C.Text
			tagStroke.Color = Ui.C.Text
		end
	end)
end

function Journal.setup(opts: Options)
	options = opts
	gui = Ui.screen("Journal", 8)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.62, 0, 0.78, 0),
		BackgroundColor3 = Ui.C.Surface,
		BackgroundTransparency = 0.03,
		Visible = false,
	}, gui)
	Ui.ticks(panel, Ui.C.Line, 12, -1)
	Ui.make("UISizeConstraint", {
		MinSize = Vector2.new(320, 260),
		MaxSize = Vector2.new(640, 560),
	}, panel)
	Ui.stroke(panel, Ui.C.Line, 0.8)
	-- A red margin rule, like the case files the objective card is cut from.
	Ui.frame({ Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Ui.C.Danger }, panel)
	titleLabel = Ui.display({
		Position = UDim2.new(0, 20, 0, 12),
		Size = UDim2.new(1, -130, 0, 28),
		TextSize = 24,
		Text = Strings.get(opts.titleKey),
	}, panel)
	-- Modal frees the cursor from first-person lock while the notebook is open.
	closeButton = Ui.quiet(Strings.get("hub_close") .. "  ×", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(104, 34),
		Modal = true,
	}, panel, Journal.close)
	Ui.frame({
		Position = UDim2.new(0, 20, 0, 46),
		Size = UDim2.new(1, -36, 0, 1),
		BackgroundColor3 = Ui.C.Line,
		BackgroundTransparency = 0.82,
	}, panel)
	list = Ui.make("ScrollingFrame", {
		Position = UDim2.new(0, 20, 0, 52),
		Size = UDim2.new(1, -30, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.C.Muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, panel)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, list)
	Ui.make("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 10) }, list)

	local keyName = if Input.isTouch then nil else Journal.keyName("J", "L1")
	tagText = if keyName then Strings.get(opts.tagKey, keyName) else Strings.get(opts.touchKey)
	tag = Ui.button(tagText, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 52),
		Size = UDim2.fromOffset(if keyName then 128 else 104, 30),
		TextSize = 14,
		FontFace = Ui.Fonts.MonoBold,
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Ui.C.Ink,
		BorderColor3 = Ui.C.Text,
		TextColor3 = Ui.C.Text,
	}, gui, Journal.toggle)
	tagStroke = tag:FindFirstChildOfClass("UIStroke") :: UIStroke
	Input.bind("Journal", Journal.toggle, { Enum.KeyCode.J, Enum.KeyCode.ButtonL1 })
	titleLabel.Text = Strings.get(opts.titleKey)
end

return Journal
