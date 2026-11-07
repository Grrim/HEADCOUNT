--!strict
-- Covers the first seconds after joining, while the world streams in and its lighting settles
-- (playtests showed about ten seconds of near-black, blurred picture). Black with a line of text is
-- also simply a better opening than a half-lit room.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(script.Parent.Ui)

local EntryCurtain = {}

local MINIMUM_SECONDS = 9
local MAXIMUM_SECONDS = 20
local FADE_SECONDS = 1.8

function EntryCurtain.show()
	local gui = Ui.screen("EntryCurtain", 100)
	local cover =
		Ui.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0) }, gui)
	local label = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0, 40),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("hub_loading"),
	}, cover)
	task.spawn(function()
		local started = os.clock()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		Workspace:WaitForChild("Map", MAXIMUM_SECONDS)
		while
			os.clock() - started < MINIMUM_SECONDS
			or (ContentProvider.RequestQueueSize > 0 and os.clock() - started < MAXIMUM_SECONDS)
		do
			task.wait(0.2)
		end
		TweenService:Create(cover, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 1 })
			:Play()
		TweenService:Create(label, TweenInfo.new(FADE_SECONDS / 2), { TextTransparency = 1 }):Play()
		task.wait(FADE_SECONDS)
		gui:Destroy()
	end)
end

return EntryCurtain
