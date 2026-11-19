--!strict
-- Studio-only film set for the 15-second teaser (docs/10_TEST_FILMIKIEM.md). When Workspace has the
-- attribute Teaser = true, Boot calls this instead of the mission: it builds the map and the stand-in
-- "friend", and nothing else runs (no mission flow, no Registrar AI, no saves). It never runs in a
-- live server, because it checks RunService:IsStudio() first.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local Teaser = {}

local FALLBACK_NAME = "Max"

function Teaser.enabled(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("Teaser") == true
end

local function description(userId: number): HumanoidDescription
	local ok, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if ok and result then
		return result
	end
	warn(`[Teaser] no avatar for {userId}, using the default one: {result}`)
	return Instance.new("HumanoidDescription")
end

local function displayName(userId: number): string
	local configured = Workspace:GetAttribute("TeaserFriendName")
	if typeof(configured) == "string" and configured ~= "" then
		return configured
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return if ok and typeof(result) == "string" then result else FALLBACK_NAME
end

-- The friend is built once on the server and handed to the client as a template; the client
-- clones it and moves its own copy, so every frame of the walk is driven by the film's clock.
local function buildFriend(userId: number)
	local model = Players:CreateHumanoidModelFromDescription(
		description(userId),
		Enum.HumanoidRigType.R15
	)
	for _, child in model:GetDescendants() do
		if child:IsA("BaseScript") then
			child:Destroy()
		end
	end
	model.Name = "TeaserFriend"
	model:SetAttribute("DisplayName", displayName(userId))
	model.Parent = ReplicatedStorage
end

function Teaser.run(services: Instance)
	local MissionWorld = require(services:WaitForChild("MissionWorld")) :: any
	local MissionDressing = require(services:WaitForChild("MissionDressing")) :: any
	MissionWorld.init()
	task.spawn(MissionDressing.start)

	-- RegistrarView on the client waits for these two; it is reused to draw the true form.
	Net.get("RegistrarEvent")
	local anchor = Instance.new("Part")
	anchor.Name = "RegistrarAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Position = Vector3.new(0, -500, 0)
	anchor:SetAttribute("Awake", false)
	anchor.Parent = Workspace

	local configured = Workspace:GetAttribute("TeaserFriendUserId")
	if typeof(configured) == "number" and configured > 0 then
		buildFriend(configured)
	else
		local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		buildFriend(first.UserId)
	end
end

return Teaser
