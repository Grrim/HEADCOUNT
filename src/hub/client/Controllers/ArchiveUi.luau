--!strict
-- Reading what you have recovered. Empty slots stay visible: a missing page is its own hook.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Panels = require(ReplicatedStorage.ClientCommon.Panels)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local ArchiveUi = {}

local ALL_DOCS = {
	"doc_rules",
	"doc_list",
	"doc_bench",
	"doc_wrona",
	"doc_office",
	"doc_basement",
	"doc_register",
	"doc_secret",
}

local panel: Frame
local listFrame: Frame
local bodyTitle: TextLabel
local bodyText: TextLabel
local known: { [string]: boolean } = {}

local function showDoc(docId: string)
	bodyTitle.Text = Strings.get(`{docId}_title`)
	bodyText.Text = Strings.get(`{docId}_body`)
	AudioDirector.play("Paper", 0.5)
end

local function renderList()
	listFrame:ClearAllChildren()
	for index, docId in ALL_DOCS do
		local y = (index - 1) * 48
		if known[docId] then
			Ui.button(
				Strings.get(`{docId}_title`),
				{
					Position = UDim2.new(0, 0, 0, y),
					Size = UDim2.new(1, -6, 0, 44),
					TextSize = 13,
				},
				listFrame,
				function()
					showDoc(docId)
				end
			)
		else
			Ui.text({
				Position = UDim2.new(0, 4, 0, y),
				Size = UDim2.new(1, -6, 0, 44),
				TextSize = 14,
				TextColor3 = Palette.WallDark,
				TextYAlignment = Enum.TextYAlignment.Center,
				Text = Strings.get("hub_docs_empty"),
			}, listFrame)
		end
	end
end

function ArchiveUi.init()
	local gui = Ui.screen("ArchiveUi", 5)
	panel = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.7, 0, 0.74, 0),
		BackgroundColor3 = Color3.fromRGB(10, 14, 10),
		BorderSizePixel = 2,
		BorderColor3 = Palette.Crt,
		Visible = false,
	}, gui)
	Ui.make("UISizeConstraint", {
		MinSize = Vector2.new(360, 280),
		MaxSize = Vector2.new(760, 520),
	}, panel)
	Ui.text({
		Position = UDim2.new(0, 16, 0, 12),
		Size = UDim2.new(1, -120, 0, 26),
		TextSize = 19,
		TextColor3 = Palette.Crt,
		Text = Strings.get("hub_docs_title"),
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
	listFrame = Ui.frame({
		Position = UDim2.new(0, 16, 0, 52),
		Size = UDim2.new(0.42, -16, 1, -64),
		BackgroundTransparency = 1,
	}, panel)
	bodyTitle = Ui.text({
		Position = UDim2.new(0.44, 8, 0, 52),
		Size = UDim2.new(0.56, -24, 0, 50),
		TextSize = 17,
		Text = "",
	}, panel)
	bodyText = Ui.text({
		Position = UDim2.new(0.44, 8, 0, 106),
		Size = UDim2.new(0.56, -24, 1, -118),
		TextSize = 16,
		Text = "",
	}, panel)
	Panels.watch(panel)
end

function ArchiveUi.start()
	Net.get("DocsState").OnClientEvent:Connect(function(state)
		known = state.docs
		renderList()
	end)
	Net.get("DocShown").OnClientEvent:Connect(function(docId: string)
		panel.Visible = true
		showDoc(docId)
	end)
	renderList()
	local map = Workspace:WaitForChild("Map")
	local archive = map:WaitForChild("ArchiveTerminal")
	local prompt = archive:WaitForChild("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function()
		panel.Visible = true
	end)
	local bell = map:WaitForChild("ReceptionBell")
	local bellPrompt = bell:WaitForChild("ProximityPrompt") :: ProximityPrompt
	bellPrompt.Triggered:Connect(function()
		AudioDirector.playAt("Bell", (bell :: BasePart).Position, 0.8)
	end)
end

return ArchiveUi
