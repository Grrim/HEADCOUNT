--!strict
-- Cut out of frame on a shift. A teammate brings you back by holding you in frame; once per shift
-- you can also walk yourself back to the lift after a while, which is what keeps solo play alive.
-- With nobody left in frame and no way back, the shift is lost.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Game)

local ShiftOffFrame = {}

local CFG = Config.Shift
local GHOST = 0.8

local services: { [string]: any }
local cutAt: { [Player]: number } = {}
local rescue: { [Player]: number } = {}
local selfReturned: { [Player]: boolean } = {}
local allCutSince: number? = nil

local function setLook(player: Player, cut: boolean)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("OffFrame", cut)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if cut then
				part:SetAttribute("SolidTransparency", part.Transparency)
				part.Transparency = math.max(part.Transparency, GHOST)
			else
				local solid = part:GetAttribute("SolidTransparency")
				if typeof(solid) == "number" then
					part.Transparency = solid
				end
			end
		end
	end
end

function ShiftOffFrame.cut(player: Player)
	if player:GetAttribute("OffFrame") == true then
		return
	end
	player:SetAttribute("OffFrame", true)
	player:SetAttribute("SelfReturnAvailable", not selfReturned[player])
	setLook(player, true)
	cutAt[player] = os.clock()
	rescue[player] = 0
	services.Lens.clear(player)
	services.ShiftSession.broadcast(`{player.DisplayName} was cut out of frame. Film them for 3 s!`)
end

function ShiftOffFrame.restore(player: Player)
	if player:GetAttribute("OffFrame") ~= true then
		return
	end
	player:SetAttribute("OffFrame", false)
	player:SetAttribute("RescueProgress", 0)
	setLook(player, false)
	cutAt[player] = nil
	rescue[player] = nil
end

-- At every departure everyone rides along, cut or not; the self-return resets with a new shift.
function ShiftOffFrame.restoreAll()
	for _, player in Players:GetPlayers() do
		ShiftOffFrame.restore(player)
	end
	allCutSince = nil
	if services.ShiftSession.shift.phase ~= "ride" then
		selfReturned = {}
	end
end

local function checkEveryoneCut()
	if services.ShiftSession.shift.phase ~= "floor" then
		allCutSince = nil
		return
	end
	local anyone = false
	local canReturn = false
	for _, player in Players:GetPlayers() do
		anyone = true
		if player:GetAttribute("OffFrame") ~= true then
			allCutSince = nil
			return
		end
		if not selfReturned[player] then
			canReturn = true
		end
	end
	if not anyone then
		return
	end
	allCutSince = allCutSince or os.clock()
	if not canReturn or os.clock() - (allCutSince :: number) >= CFG.AllCutGrace then
		allCutSince = nil
		services.ShiftSession.onEveryoneCut()
	end
end

function ShiftOffFrame.init(all: { [string]: any })
	services = all
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("OffFrame", false)
		player.CharacterAdded:Connect(function()
			if player:GetAttribute("OffFrame") == true then
				task.defer(setLook, player, true)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cutAt[player] = nil
		rescue[player] = nil
		selfReturned[player] = nil
	end)
end

function ShiftOffFrame.start()
	local step = 0.25
	while true do
		task.wait(step)
		checkEveryoneCut()
		for player, at in cutAt do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local filmed = false
			for _, framer in services.Lens.framers(root.Position) do
				if services.ShiftSession.lensWorks(framer) then
					filmed = true
				end
			end
			if filmed then
				rescue[player] = (rescue[player] or 0) + step
				player:SetAttribute("RescueProgress", rescue[player] / CFG.RescueSeconds)
				if rescue[player] >= CFG.RescueSeconds then
					ShiftOffFrame.restore(player)
					services.ShiftSession.broadcast(`{player.DisplayName} is back in frame.`)
				end
			elseif
				not selfReturned[player]
				and os.clock() - at >= CFG.SelfReturnAfter
				and services.ShiftWorld.inLift(root.Position)
			then
				selfReturned[player] = true
				ShiftOffFrame.restore(player)
				services.ShiftSession.tell(
					player,
					"You walked back into frame. That works once a shift."
				)
			end
		end
	end
end

return ShiftOffFrame
