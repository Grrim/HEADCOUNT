--!strict
-- The locker room's television (docs/09_GDD_V2.md §5): every shift tape kept by anyone in this
-- lobby, yours first, to watch on the panel the TV opens. The list arrives without the camera
-- paths; a tape's path is asked for when it is played, and kept for the rest of the visit.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Panels = require(ReplicatedStorage.ClientCommon.Panels)
local Strings = require(ReplicatedStorage.Shared.Strings)
local TapeView = require(ReplicatedStorage.ClientCommon.TapeView)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local TapeShelf = {}

local panel: Frame
local screen: Frame
local listFrame: ScrollingFrame
local note: TextLabel
local cache: { [string]: any } = {}
local waitingFor: string? = nil

local function keyOf(userId: number, index: number): string
	return `{userId}:{index}`
end

local function stars(count: number): string
	return string.rep("★", count) .. string.rep("☆", 5 - count)
end

local function close()
	panel.Visible = false
	-- Clearing the screen destroys the playing copy of the floor and stops it.
	screen:ClearAllChildren()
	waitingFor = nil
end

local function play(userId: number, index: number)
	local key = keyOf(userId, index)
	local tape = cache[key]
	if tape then
		waitingFor = nil
		note.Text = ""
		TapeView.play(screen, tape)
		return
	end
	waitingFor = key
	note.Text = Strings.get("tv_loading")
	Net.get("TapeShelf"):FireServer("get", userId, index)
end

local function showList(owners: { any })
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #owners == 0 then
		note.Text = Strings.get("tv_empty")
		return
	end
	note.Text = ""
	local order = 0
	local first: (() -> ())? = nil
	for _, owner in owners do
		order += 1
		Ui.eyebrow(string.upper(tostring(owner.name)), { LayoutOrder = order }, listFrame)
		for _, tape in owner.tapes do
			order += 1
			local userId, index = owner.userId, tape.index
			Ui.quiet(
				`{stars(tape.stars or 0)}  -{tape.depth}  {tape.by or ""}`,
				{ Size = UDim2.new(1, -8, 0, 26), LayoutOrder = order },
				listFrame,
				function()
					play(userId, index)
				end
			)
			first = first or function()
				play(userId, index)
			end
		end
	end
	-- Start on the first tape (the viewer's own, if they have any).
	if first then
		first()
	end
end

local function open()
	panel.Visible = true
	Ui.open(panel)
	note.Text = Strings.get("tv_loading")
	Net.get("TapeShelf"):FireServer("list")
end

function TapeShelf.init()
	local gui = Ui.screen("TapeShelf", 6)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 360),
		BackgroundTransparency = 0.06,
		Visible = false,
	}, gui)
	Ui.pad(panel, 16, 14)
	-- Fits a small screen: the panel shrinks with it, never past it.
	local camera = Workspace.CurrentCamera
	if camera and camera.ViewportSize.X < 860 then
		Ui.make("UIScale", { Scale = math.max(0.5, (camera.ViewportSize.X - 40) / 820) }, panel)
	end
	Ui.eyebrow(Strings.get("tv_title"), { Size = UDim2.new(1, 0, 0, 16) }, panel)
	screen = Ui.frame({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.fromOffset(512, 288),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
	}, panel)
	note = Ui.text({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.fromOffset(512, 288),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Text = "",
		ZIndex = 5,
	}, panel)
	listFrame = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(528, 26),
		Size = UDim2.new(1, -528, 0, 250),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel)
	Ui.list(listFrame, 4)
	Ui.quiet(Strings.get("tv_close"), {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(1, -528, 0, 30),
		Modal = true,
	}, panel, close)
	Panels.watch(panel, close)
end

function TapeShelf.start()
	Net.get("TapeShelfData").OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == "list" and panel.Visible then
			showList(if typeof(a) == "table" then a else {})
		elseif kind == "tape" and typeof(a) == "number" and typeof(b) == "number" then
			local key = keyOf(a, b)
			cache[key] = c
			if waitingFor == key and panel.Visible then
				play(a, b)
			end
		end
	end)
	local function hook(tv: Instance)
		local prompt = tv:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(open)
		end
	end
	for _, tv in CollectionService:GetTagged("TapeShelfTv") do
		hook(tv)
	end
	CollectionService:GetInstanceAddedSignal("TapeShelfTv"):Connect(hook)
end

return TapeShelf
