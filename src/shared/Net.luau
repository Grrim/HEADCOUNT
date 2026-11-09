--!strict
-- Every remote in the game, declared once. A typo errors loudly instead of failing silently.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- mission, client to server
	"LensState",
	"RecordStart",
	"RecordStop",
	"PlayTape",
	"PlayEnded",
	"QuickComm",
	"Knock",
	"FlashlightToggle",
	"CodeEntry",
	"VoiceNoise",
	-- mission, server to client
	"SessionState",
	"Notify",
	"RegistrarEvent",
	"TapeList",
	"TapePlay",
	"CommShown",
	"KnockHeard",
	"DocShown",
	"RegisterShown",
	"EndMission",
	"CodeDigits",
	-- hub
	"PartyAction",
	"PartyState",
	"TeleportStatus",
	"IntroAction",
	"DocsState",
	"LockerAction",
}

local known: { [string]: boolean } = {}
for _, name in NAMES do
	known[name] = true
end

local Net = {}

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = created
		end
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Net.get(name: string): RemoteEvent
	assert(known[name], `unknown remote: {name}`)
	return folder():WaitForChild(name) :: RemoteEvent
end

return Net
