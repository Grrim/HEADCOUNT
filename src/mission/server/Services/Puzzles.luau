--!strict
-- The authoritative mission puzzles. Each prompt checks the flow before anything happens, so a
-- client that triggers things out of order simply gets nowhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local Flow = require(ReplicatedStorage.Shared.Core.Flow)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerData = require(ServerScriptService.Common.PlayerData)
local Puzzle = require(ReplicatedStorage.Shared.Core.Puzzle)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local Puzzles = {}

local services: { [string]: any }
local limit = RateLimit.new(Config.Rates.Prompt[1], Config.Rates.Prompt[2])
local wrongGuesses = 0
local tagsFound: { [number]: boolean } = {} -- by hook
local reelsLoaded = 0
local docRemote: RemoteEvent
local digitsRemote: RemoteEvent
local doorOpenForever = false

local function allowed(player: Player, prompt: ProximityPrompt): boolean
	if player:GetAttribute("OffFrame") == true or not limit:allow(player, os.clock()) then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local part = prompt.Parent :: BasePart
	if not root then
		return false
	end
	-- Generous slack: the engine has already checked range against the client's own position.
	return (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 8
end

local function wrong(player: Player, key: string)
	services.Session.notifyOne(player, key)
	wrongGuesses += 1
	if wrongGuesses >= Config.Puzzle.WrongGuessesPerStep then
		wrongGuesses = 0
		services.Session.notify("procedural_error")
		services.RegistrarAi.proceduralError(player)
	end
end

-- Hands every present player their share of the code. Called again when the team changes, so a
-- digit never leaves with the player who held it.
local function dealDigits()
	local session = services.Session
	if session.flow.phase ~= "Power" or not session.puzzle then
		return
	end
	local ids = {}
	for _, player in Players:GetPlayers() do
		table.insert(ids, player.UserId)
	end
	local hands = Puzzle.dealCode(session.puzzle.code, ids)
	for _, player in Players:GetPlayers() do
		local hand = {}
		for position, digit in hands[player.UserId] or {} do
			hand[tostring(position)] = digit
		end
		digitsRemote:FireClient(player, hand)
	end
end

local function onSeat(player: Player, seatId: number, prompt: ProximityPrompt)
	if not allowed(player, prompt) then
		return
	end
	local session = services.Session
	if session.flow.phase ~= "Protocol" then
		session.notifyOne(player, "seat_empty")
		return
	end
	local target = Puzzle.targetAtSeat(session.puzzle, seatId)
	if not target then
		wrong(player, "seat_empty")
		return
	end
	prompt.Enabled = false
	tagsFound[target.hook] = true
	table.insert(session.tags, target.hook)
	session.notify("seat_found", target.hook, target.label)
	session.broadcast()
end

local function onHook(player: Player, hook: number, prompt: ProximityPrompt)
	if not allowed(player, prompt) then
		return
	end
	local session = services.Session
	local target = Puzzle.targetAtHook(session.puzzle, hook)
	-- The right hook without its tag is still an empty pocket: no guessing past the tape.
	if session.flow.phase ~= "Protocol" or not target or not tagsFound[hook] then
		wrong(player, "hook_empty")
		return
	end
	prompt.Enabled = false
	Flow.reelFound(session.flow)
	session.notify("hook_found", target.reel, hook)
	session.broadcast()
	if session.flow.phase == "Power" then
		-- The moment the last reel leaves the coat, the building goes out.
		services.MissionWorld.setMains(false)
		services.RegistrarAi.wake()
		dealDigits()
		task.delay(2.5, session.notify, "radio_power")
		task.delay(9, session.notify, "radio_power_cards")
	end
end

local function onCode(player: Player, entry: unknown)
	local session = services.Session
	if not limit:allow(player, os.clock()) or player:GetAttribute("OffFrame") == true then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local panel = services.MissionWorld.prompts.Breaker.Parent :: BasePart
	if not root or (root.Position - panel.Position).Magnitude > 22 then
		return
	end
	if session.flow.phase ~= "Power" then
		return
	end
	if not Puzzle.codeMatches(session.puzzle.code, entry) then
		wrong(player, "code_wrong")
		return
	end
	Flow.powerRestored(session.flow)
	services.MissionWorld.prompts.Breaker.Enabled = false
	services.MissionWorld.setMains(true)
	session.notify("code_right")
	session.broadcast()
end

local function onReel(player: Player, letter: string, prompt: ProximityPrompt)
	if not allowed(player, prompt) then
		return
	end
	local session = services.Session
	if session.flow.phase ~= "Projector" then
		session.notifyOne(player, if session.flow.reels < 3 then "need_reels" else "need_power")
		return
	end
	local loaded, mistake = Puzzle.loadReel(session.puzzle.reelOrder, reelsLoaded, letter)
	reelsLoaded = loaded
	local world = services.MissionWorld
	if mistake then
		for _, name in { "A", "B", "C" } do
			world.prompts[`Reel{name}`].Enabled = true
		end
		wrong(player, "reel_wrong")
		return
	end
	prompt.Enabled = false
	session.notify("reel_loaded", letter, loaded)
	if loaded >= #session.puzzle.reelOrder and Flow.filmPlayed(session.flow) then
		world.showFilm(session.puzzle.doorSide)
		session.notify("film_started")
		session.broadcast()
	end
end

local function showDoc(player: Player, docId: string)
	if PlayerData.mark(player, "docs", docId) then
		services.Session.docsFound += 1
	end
	services.Session.noteDoc(player, docId)
	docRemote:FireClient(player, docId)
end
Puzzles.showDoc = showDoc

local function onRegister(player: Player, prompt: ProximityPrompt)
	if not allowed(player, prompt) then
		return
	end
	local session = services.Session
	if not Flow.registerRead(session.flow) then
		return
	end
	prompt.Enabled = false
	showDoc(player, "doc_register")
	local names = {}
	for _, other in Players:GetPlayers() do
		table.insert(names, other.DisplayName)
		PlayerData.mark(other, "docs", "doc_register")
		session.noteDoc(other, "doc_register")
	end
	Net.get("RegisterShown"):FireAllClients(names)
	doorOpenForever = true
	services.MissionWorld.plugs[session.puzzle.doorSide].CanCollide = false
	services.MissionWorld.prompts.Bell.Enabled = true
	services.MissionWorld.setClimaxLighting()
	services.RegistrarAi.setClimax()
	session.broadcast()
end

local function onBell(player: Player, prompt: ProximityPrompt)
	if not allowed(player, prompt) then
		return
	end
	local session = services.Session
	if Flow.bellRung(session.flow) then
		prompt.Enabled = false
		session.finish(true)
	end
end

-- The door exists only while a lens holds it. Runs on a short loop so it answers quickly.
local function doorLoop()
	local session = services.Session
	local lens = services.Lens
	local step = 0.2
	local grace = 0
	while true do
		task.wait(step)
		if doorOpenForever then
			return
		end
		local phase = session.flow.phase
		if (phase == "Door" or phase == "Register") and session.puzzle then
			local side = session.puzzle.doorSide
			local plug = services.MissionWorld.plugs[side]
			local doorPoint = Vector3.new(side * Layout.DOOR_OFFSET_X, 7, Layout.DOOR_Z + 0.6)
			local fromInside = Vector3.new(side * Layout.DOOR_OFFSET_X, 7, Layout.DOOR_Z - 0.6)
			local held = #lens.framers(doorPoint) > 0 or #lens.framers(fromInside) > 0
			if not held then
				for _, player in Players:GetPlayers() do
					if lens.holdsCloseUp(player, doorPoint, Config.Puzzle.DoorCloseUpRadius) then
						held = true
						break
					end
				end
			end
			if held then
				grace = 1.2
			else
				grace = math.max(0, grace - step)
			end
			local open = grace > 0
			if plug.CanCollide == open then
				plug.CanCollide = not open
			end
			if phase == "Door" then
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character
						and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and root.Position.Z < Layout.DOOR_Z - 1 then
						Flow.doorPassed(session.flow)
						services.MissionWorld.prompts.Register.Enabled = true
						session.broadcast()
						break
					end
				end
			end
		end
	end
end

function Puzzles.init(all: { [string]: any })
	services = all
	docRemote = Net.get("DocShown")
	digitsRemote = Net.get("CodeDigits")
	Net.get("CodeEntry").OnServerEvent:Connect(onCode)
end

function Puzzles.start()
	local world = services.MissionWorld
	for seatId, prompt in world.seatPrompts do
		prompt.Triggered:Connect(function(player)
			onSeat(player, seatId, prompt)
		end)
	end
	for hook, prompt in world.hookPrompts do
		prompt.Triggered:Connect(function(player)
			onHook(player, hook, prompt)
		end)
	end
	for _, letter in { "A", "B", "C" } do
		local prompt = world.prompts[`Reel{letter}`]
		prompt.Triggered:Connect(function(player)
			onReel(player, letter, prompt)
		end)
	end
	world.prompts.Register.Triggered:Connect(function(player)
		onRegister(player, world.prompts.Register)
	end)
	world.prompts.Bell.Triggered:Connect(function(player)
		onBell(player, world.prompts.Bell)
	end)
	world.prompts.Recorder.Triggered:Connect(function(player)
		if allowed(player, world.prompts.Recorder) then
			services.Tapes.playArchive(player)
		end
	end)
	for promptName, docId in
		{
			DocList = "doc_list",
			DocWrona = "doc_wrona",
			DocOffice = "doc_office",
			DocBasement = "doc_basement",
		}
	do
		local prompt = world.prompts[promptName]
		prompt.Triggered:Connect(function(player)
			if allowed(player, prompt) then
				showDoc(player, docId)
			end
		end)
	end
	Players.PlayerAdded:Connect(function()
		task.defer(dealDigits)
	end)
	Players.PlayerRemoving:Connect(function(player)
		limit:forget(player)
		task.defer(dealDigits)
	end)
	task.spawn(doorLoop)
end

return Puzzles
