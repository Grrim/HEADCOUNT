--!strict
-- Sound as a rule of the game. A hum is always present, so its absence is an event:
--   Normal   ambient at its usual level
--   Silence  ambient drops out just before the Registrar cuts closer, then creeps back
--   Absolute nothing at all, for rooms that should feel wrong
-- A missing sound never breaks anything: every call is a no-op without an asset id.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local AudioDirector = {}

local AMBIENT_LEVEL = 0.32
local HUM_LEVEL = 0.22

local group: SoundGroup? = nil
local loops: { [string]: Sound } = {}
local fading: Tween? = nil
local absolute = false

local function assetFor(name: string): string?
	local id = Sounds[name]
	if id and id ~= 0 then
		return `rbxassetid://{id}`
	end
	return nil
end

local function ambientGroup(): SoundGroup
	if not group then
		local created = Instance.new("SoundGroup")
		created.Name = "Ambient"
		created.Volume = 1
		created.Parent = SoundService
		group = created
	end
	return group :: SoundGroup
end

local function fadeAmbient(volume: number, seconds: number)
	if fading then
		fading:Cancel()
	end
	local tween = TweenService:Create(
		ambientGroup(),
		TweenInfo.new(seconds, Enum.EasingStyle.Sine),
		{ Volume = volume }
	)
	fading = tween
	tween:Play()
end

local function startLoop(name: string, volume: number, soundGroup: SoundGroup?): Sound?
	local asset = assetFor(name)
	if not asset then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = asset
	sound.Looped = true
	sound.Volume = volume
	sound.SoundGroup = soundGroup
	sound.Parent = SoundService
	sound:Play()
	loops[name] = sound
	return sound
end

function AudioDirector.start()
	local group0 = ambientGroup()
	startLoop("Ambient", AMBIENT_LEVEL, group0)
	startLoop("Hum", HUM_LEVEL, group0)
	local assets = {}
	for name in Sounds do
		local asset = assetFor(name)
		if asset then
			local preload = Instance.new("Sound")
			preload.SoundId = asset
			table.insert(assets, preload)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
	end)
end

function AudioDirector.play(name: string, volume: number?, pitch: number?)
	local asset = assetFor(name)
	if not asset then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = asset
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(30, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- A sound placed in the world, so direction and distance do the work.
function AudioDirector.playAt(
	name: string,
	position: Vector3,
	volume: number?,
	range: number?,
	muffled: boolean?
)
	local asset = assetFor(name)
	if not asset then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = Workspace
	local sound = Instance.new("Sound")
	sound.SoundId = asset
	sound.Volume = volume or 0.8
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = range or 120
	sound.Parent = holder
	if muffled then
		-- Through a wall the top end disappears: this is what makes a sound feel like "next door".
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -30
		eq.MidGain = -12
		eq.LowGain = 0
		eq.Parent = sound
	end
	sound:Play()
	task.delay(15, function()
		holder:Destroy()
	end)
end

-- Continuous device sounds: the tape motor, the audience breathing behind the lens.
function AudioDirector.setLoop(name: string, on: boolean, volume: number?, pitch: number?)
	local sound = loops[name]
	if on and not sound then
		sound = startLoop(name, volume or 0.4) :: Sound
	end
	if not sound then
		return
	end
	if pitch then
		sound.PlaybackSpeed = pitch
	end
	if on then
		sound.Volume = volume or sound.Volume
		if not sound.IsPlaying then
			sound:Play()
		end
	else
		sound:Stop()
	end
end

-- The warning before a jump. Ambient falls away fast and takes a while to return.
function AudioDirector.silence(holdSeconds: number)
	if absolute then
		return
	end
	fadeAmbient(0, 0.35)
	task.delay(holdSeconds, function()
		if not absolute then
			fadeAmbient(1, 3)
		end
	end)
end

function AudioDirector.isSilent(): boolean
	return absolute or ambientGroup().Volume < 0.5
end

function AudioDirector.setAbsolute(on: boolean)
	if on == absolute then
		return
	end
	absolute = on
	fadeAmbient(if on then 0 else 1, if on then 0.8 else 2)
end

function AudioDirector.setReverb(reverb: Enum.ReverbType)
	SoundService.AmbientReverb = reverb
end

return AudioDirector
