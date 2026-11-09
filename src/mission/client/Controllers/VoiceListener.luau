--!strict
-- The building listens in the silence. With voice chat on, this measures how loud the player's
-- own microphone is, and only while the hum has dropped out (the warning that the Registrar is
-- about to move). Speaking up then tells the server, which may pull him towards the speaker.
-- Only a loudness level is read, never the audio itself, and nothing at all without voice chat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Net = require(ReplicatedStorage.Shared.Net)

local VoiceListener = {}

-- RMS level that counts as speaking up rather than breathing, and for how long.
local THRESHOLD = 0.12
local SUSTAIN = 0.35
local COOLDOWN = 4

local analyzer: AudioAnalyzer? = nil
local availableListeners: { () -> () } = {}

function VoiceListener.available(): boolean
	return analyzer ~= nil
end

function VoiceListener.onAvailable(listener: () -> ())
	table.insert(availableListeners, listener)
	if analyzer then
		task.spawn(listener)
	end
end

-- The engine gives each player an AudioDeviceInput once the new voice audio is on for the game.
local function attach(): boolean
	local input = Players.LocalPlayer:FindFirstChildOfClass("AudioDeviceInput")
	if not input then
		return false
	end
	local ok = pcall(function()
		local made = Instance.new("AudioAnalyzer")
		made.Name = "SilenceListener"
		made.Parent = input
		local wire = Instance.new("Wire")
		wire.SourceInstance = input
		wire.TargetInstance = made
		wire.Parent = made
		analyzer = made
	end)
	return ok and analyzer ~= nil
end

function VoiceListener.start()
	-- Voice may be switched on a while after joining, or not at all.
	local deadline = os.clock() + 60
	while not attach() do
		if os.clock() > deadline then
			return
		end
		task.wait(2)
	end
	for _, listener in availableListeners do
		task.spawn(listener)
	end
	local remote = Net.get("VoiceNoise")
	local loud = 0
	local lastSent = -math.huge
	local step = 0.1
	while true do
		task.wait(step)
		local current = analyzer
		local level = 0
		if current then
			local ok, value = pcall(function()
				return current.RmsLevel
			end)
			level = if ok and typeof(value) == "number" then value else 0
		end
		if AudioDirector.isSilent() and level > THRESHOLD then
			loud += step
		else
			loud = 0
		end
		if loud >= SUSTAIN and os.clock() - lastSent > COOLDOWN then
			lastSent = os.clock()
			loud = 0
			remote:FireServer()
		end
	end
end

return VoiceListener
