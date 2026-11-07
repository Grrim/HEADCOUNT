--!strict
-- Quick radio calls, knocks from out of frame, and the flashlight. Each is one validated request.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local Comms = {}

local commLimit = RateLimit.new(Config.Rates.Comms[1], Config.Rates.Comms[2])
local lightLimit = RateLimit.new(Config.Rates.Flashlight[1], Config.Rates.Flashlight[2])

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function toggleLight(player: Player)
	if not lightLimit:allow(player, os.clock()) then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local light = head:FindFirstChild("Flashlight") :: SpotLight?
	if light then
		light.Enabled = not light.Enabled
	else
		local created = Instance.new("SpotLight")
		created.Name = "Flashlight"
		created.Face = Enum.NormalId.Front
		created.Angle = 46
		created.Range = 42
		created.Brightness = 2.2
		created.Shadows = true
		created.Color = Color3.fromRGB(255, 240, 214)
		created.Parent = head
	end
end

function Comms.init()
	Net.get("QuickComm").OnServerEvent:Connect(function(player: Player, kind: unknown)
		if typeof(kind) ~= "number" or kind % 1 ~= 0 or kind < 1 or kind > 4 then
			return
		end
		if not commLimit:allow(player, os.clock()) then
			return
		end
		local position = rootPosition(player)
		if position then
			Net.get("CommShown"):FireAllClients(player.DisplayName, kind, position)
		end
	end)
	Net.get("Knock").OnServerEvent:Connect(function(player: Player)
		if player:GetAttribute("OffFrame") ~= true or not commLimit:allow(player, os.clock()) then
			return
		end
		local position = rootPosition(player)
		if position then
			Net.get("KnockHeard"):FireAllClients(position)
		end
	end)
	Net.get("FlashlightToggle").OnServerEvent:Connect(toggleLight)
	Players.PlayerRemoving:Connect(function(player)
		commLimit:forget(player)
		lightLimit:forget(player)
	end)
end

return Comms
