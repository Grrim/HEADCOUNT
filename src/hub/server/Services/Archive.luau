--!strict
-- Recovered documents and the lobby's memory of what the player has done.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local PlayerData = require(ServerScriptService.Common.PlayerData)

local Archive = {}

local services: { [string]: any }
local stateRemote: RemoteEvent
local limit = RateLimit.new(Config.Rates.Party[1], Config.Rates.Party[2])

local function send(player: Player)
	local data = PlayerData.waitFor(player)
	if data then
		-- Studio has no saved progress, so the lobby's memory is reached with an attribute.
		if RunService:IsStudio() and Workspace:GetAttribute("DevMissionDone") == true then
			PlayerData.mark(player, "flags", "m001_done")
			PlayerData.mark(player, "flags", "introDone")
		end
		stateRemote:FireClient(player, {
			docs = data.docs,
			flags = data.flags,
			prefs = data.prefs,
			stats = data.stats,
			achievements = data.achievements,
		})
	end
end

function Archive.init(all: { [string]: any })
	services = all
	stateRemote = Net.get("DocsState")
end

function Archive.start()
	Players.PlayerAdded:Connect(send)
	for _, player in Players:GetPlayers() do
		task.spawn(send, player)
	end
	-- The intro only ever sets its own one flag, so a forged request gains nothing.
	Net.get("IntroAction").OnServerEvent:Connect(function(player: Player, step: unknown)
		if step == "done" then
			PlayerData.mark(player, "flags", "introDone")
		end
	end)
	-- A frame colour is only accepted if it exists and this player has earned it.
	Net.get("LockerAction").OnServerEvent
		:Connect(function(player: Player, action: unknown, id: unknown)
			if
				action ~= "frame"
				or typeof(id) ~= "string"
				or not limit:allow(player, os.clock())
			then
				return
			end
			local data = PlayerData.get(player)
			if not data then
				return
			end
			for _, frame in Cosmetics.Frames do
				if frame.id == id and (not frame.requires or data.achievements[frame.requires]) then
					PlayerData.setPref(player, "frame", id)
					player:SetAttribute("FrameId", id)
					send(player)
					return
				end
			end
		end)
	local prompts = services.HubWorld.prompts
	local function grant(prompt: ProximityPrompt, docId: string)
		prompt.Triggered:Connect(function(player)
			PlayerData.mark(player, "docs", docId)
			send(player)
			Net.get("DocShown"):FireClient(player, docId)
		end)
	end
	grant(prompts.Rules, "doc_rules")
	grant(prompts.Secret, "doc_secret")
end

return Archive
