--!strict
-- Being cut out instead of dying: only a lens can see you, a teammate can film you back, and you
-- can always walk back to the leader mark. If everyone is out, the tape ends.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Flow = require(ReplicatedStorage.Shared.Core.Flow)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local PlayerData = require(ServerScriptService.Common.PlayerData)

local OffFrame = {}

local CFG = Config.OffFrame
local services: { [string]: any }
local cutAt: { [Player]: number } = {}
local rescue: { [Player]: number } = {}
local allCutSince: number? = nil

local function setFlag(player: Player, value: boolean)
	player:SetAttribute("OffFrame", value)
	local character = player.Character
	if character then
		character:SetAttribute("OffFrame", value)
	end
end

-- Everyone out of frame does not end the tape at once: the way back has to stay reachable, or a
-- solo player's first mistake would end the mission with the return mark never in play.
function OffFrame.checkEveryoneCut()
	local session = services.Session
	if Flow.isOver(session.flow) or session.flow.phase == "Waiting" then
		if allCutSince then
			Workspace:SetAttribute("TapeEndsAt", nil)
		end
		allCutSince = nil
		return
	end
	local anyone = false
	for _, player in Players:GetPlayers() do
		anyone = true
		if player:GetAttribute("OffFrame") ~= true then
			if allCutSince then
				Workspace:SetAttribute("TapeEndsAt", nil)
			end
			allCutSince = nil
			return
		end
	end
	if not anyone then
		return
	end
	local now = os.clock()
	if not allCutSince then
		allCutSince = now
		-- Clients count down to the server's clock, so every screen shows the same seconds.
		Workspace:SetAttribute("TapeEndsAt", Workspace:GetServerTimeNow() + CFG.AllCutGrace)
		session.notify("tape_running_out")
	elseif now - allCutSince >= CFG.AllCutGrace and Flow.everyoneCut(session.flow) then
		session.finish(false)
	end
end

function OffFrame.cut(player: Player)
	if player:GetAttribute("OffFrame") == true then
		return
	end
	setFlag(player, true)
	cutAt[player] = os.clock()
	player:SetAttribute("SelfReturnAt", Workspace:GetServerTimeNow() + CFG.SelfReturnAfter)
	rescue[player] = 0
	services.Lens.clear(player)
	services.Session.totalCuts += 1
	services.Session.noteCut(player)
	PlayerData.addStat(player, "cuts", 1)
	services.Session.notify("cut_someone", player.DisplayName)
	OffFrame.checkEveryoneCut()
end

function OffFrame.restore(player: Player)
	setFlag(player, false)
	cutAt[player] = nil
	rescue[player] = nil
	services.Session.notify("restored", player.DisplayName)
end

function OffFrame.init(all: { [string]: any })
	services = all
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			-- Respawning must not silently bring anyone back.
			character:SetAttribute("OffFrame", player:GetAttribute("OffFrame") == true)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cutAt[player] = nil
		rescue[player] = nil
	end)
end

function OffFrame.start()
	local step = 0.25
	local mark = Layout.SPLICE_MARK
	local markPosition = Vector3.new(mark.x, mark.y, mark.z)
	while true do
		task.wait(step)
		OffFrame.checkEveryoneCut()
		for player, at in cutAt do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			if #services.Lens.framers(root.Position) > 0 then
				rescue[player] = (rescue[player] or 0) + step
				root.Parent:SetAttribute("RescueProgress", rescue[player] / CFG.RescueSeconds)
				if rescue[player] >= CFG.RescueSeconds then
					OffFrame.restore(player)
				end
			elseif
				os.clock() - at >= CFG.SelfReturnAfter
				and (root.Position - markPosition).Magnitude <= CFG.SpliceRadius
			then
				OffFrame.restore(player)
			end
		end
	end
end

return OffFrame
