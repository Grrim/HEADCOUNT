--!strict
-- One expedition from arrival to the teleport home: seed, take, flow, shared state, the ending.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Achievements = require(ReplicatedStorage.Shared.Core.Achievements)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Flow = require(ReplicatedStorage.Shared.Core.Flow)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerData = require(ServerScriptService.Common.PlayerData)
local Places = require(ReplicatedStorage.Shared.Config.Places)
local Puzzle = require(ReplicatedStorage.Shared.Core.Puzzle)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)
local Take = require(ReplicatedStorage.Shared.Core.Take)

local Session = {}

Session.flow = Flow.new()
Session.seed = 0
Session.puzzle = nil :: Puzzle.Puzzle?
Session.take = Take.forCompletions(0)
Session.tags = {} :: { number }
Session.startedAt = 0
Session.totalReplays = 0
Session.totalCuts = 0
Session.docsFound = 0
Session.playerCount = 1
-- Separate from the puzzle seed, which must never reach a client: it would give away the answers.
Session.omenSeed = Random.new():NextInteger(1, 2 ^ 30)

local services: { [string]: any }
local stateRemote: RemoteEvent
local notifyRemote: RemoteEvent
local endRemote: RemoteEvent
local begun = false
local finishing = false
local runDocs: { [number]: { [string]: boolean } } = {}
local everCut: { [number]: boolean } = {}

local function publicState(): { [string]: any }
	local flow = Session.flow
	local doorRevealed = flow.phase == "Door"
		or flow.phase == "Register"
		or flow.phase == "Climax"
		or flow.phase == "Done"
	return {
		phase = flow.phase,
		objective = Flow.objective(flow),
		reels = flow.reels,
		tags = Session.tags,
		takeNumber = Session.take.number,
		briefKey = Session.take.briefKey,
		reverseEveryNthRow = Session.take.reverseEveryNthRow,
		liveLensHidesAudience = Session.take.liveLensHidesAudience,
		omenSeed = Session.omenSeed,
		doorSide = if doorRevealed and Session.puzzle then Session.puzzle.doorSide else nil,
	}
end

function Session.broadcast()
	stateRemote:FireAllClients(publicState())
end

function Session.notify(key: string, ...: any)
	notifyRemote:FireAllClients(key, ...)
end

function Session.notifyOne(player: Player, key: string, ...: any)
	notifyRemote:FireClient(player, key, ...)
end

local function readJoin(player: Player): (number?, number)
	-- Teleport data is visible to the client, so only the seed is taken from it and only after a
	-- type check. Nothing that grants a reward depends on it.
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return nil, 1
	end
	local data = joinData.TeleportData
	local seed = if typeof(data) == "table" and typeof(data.seed) == "number"
		then data.seed
		else nil
	local members = joinData.Members
	return seed, if typeof(members) == "table" then math.clamp(#members, 1, 4) else 1
end

-- The dispatcher's voice paces the mission, and slowly stops making sense.
local function radioPacing()
	local saidHall, saidFilm, saidSeen, saidDoor, saidQuiet = false, false, false, false, false
	local enteredHallAt: number? = nil
	while not Flow.isOver(Session.flow) do
		task.wait(1)
		local anyoneInHall = false
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Z < 43 then
				anyoneInHall = true
			end
		end
		if anyoneInHall and not enteredHallAt then
			enteredHallAt = os.clock()
		end
		local phase = Session.flow.phase
		if enteredHallAt and not saidHall then
			saidHall = true
			Session.notify("radio_hall")
		elseif
			enteredHallAt
			and not saidFilm
			and Session.totalReplays == 0
			and os.clock() - enteredHallAt > 75
		then
			saidFilm = true
			Session.notify("radio_film")
		elseif not saidSeen and os.clock() - Session.startedAt > 300 and phase == "Protocol" then
			saidSeen = true
			Session.notify("radio_seen")
		elseif not saidDoor and phase == "Door" then
			saidDoor = true
			task.delay(8, Session.notify, "radio_door")
		elseif not saidQuiet and phase == "Register" then
			saidQuiet = true
			Session.notify("radio_quiet")
		end
	end
end

local function begin()
	if begun then
		return
	end
	begun = true
	local completions = 0
	for _, player in Players:GetPlayers() do
		local data = PlayerData.waitFor(player)
		if data then
			completions = math.max(completions, data.stats.completions)
		end
	end
	-- Studio has no saved progress, so later takes are reached with an attribute set before Play.
	local devCompletions = Workspace:GetAttribute("DevCompletions")
	if RunService:IsStudio() and typeof(devCompletions) == "number" then
		completions = devCompletions
	end
	Session.playerCount = math.max(1, #Players:GetPlayers())
	Session.take = Take.forCompletions(completions)
	services.MissionWorld.applyTake(Session.take.reverseEveryNthRow)
	Session.startedAt = os.clock()
	Flow.begin(Session.flow)
	Session.broadcast()
	services.RegistrarAi.onSessionBegin()
	Session.notify(Session.take.briefKey)
	task.delay(10, Session.notify, "radio_check")
	task.spawn(radioPacing)
	print(`[Session] begin seed={Session.seed} take={Session.take.number}`)
	if RunService:IsStudio() and Session.puzzle then
		-- Lets a developer verify the puzzle without watching tapes. Never runs in a live server.
		for _, target in Session.puzzle.targets do
			print(`[Session][studio] {target.reel}: seat {target.label} hook {target.hook}`)
		end
		local puzzle = Session.puzzle :: Puzzle.Puzzle
		print(
			`[Session][studio] code {table.concat(puzzle.code)} reels {table.concat(
				puzzle.reelOrder
			)} door {puzzle.doorSide}`
		)
	end
end

function Session.noteDoc(player: Player, docId: string)
	local docs = runDocs[player.UserId] or {}
	runDocs[player.UserId] = docs
	docs[docId] = true
end

function Session.noteCut(player: Player)
	everCut[player.UserId] = true
end

function Session.addReplay()
	Session.totalReplays += 1
	return Session.totalReplays
end

function Session.isClimaxOrLater(): boolean
	local phase = Session.flow.phase
	return phase == "Climax" or phase == "Done"
end

-- Clones each player's character into the audience, standing just behind an emptied seat in row C,
-- where the final tape will find them.
local function seatTheCast(): { { number } }
	local folder = Instance.new("Folder")
	folder.Name = "FinalCast"
	local spots: { { number } } = {}
	for index, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			character.Archivable = true
			local ok, clone = pcall(function()
				return character:Clone()
			end)
			character.Archivable = false
			if ok and clone then
				for _, item in clone:GetDescendants() do
					if item:IsA("LuaSourceContainer") then
						item:Destroy()
					elseif item:IsA("BasePart") then
						item.Anchored = true
						item.CanCollide = false
						item.CanQuery = false
					end
				end
				local x, z = Seats.position(Seats.castSeat(index))
				-- Facing the stage, which is where the final tape shoots from.
				clone:PivotTo(CFrame.new(x, 3.2, z + 2))
				clone.Parent = folder
				table.insert(spots, { x, z })
			end
		end
	end
	folder.Parent = Workspace
	return spots
end

function Session.finish(success: boolean)
	if finishing then
		return
	end
	finishing = true
	local duration = math.floor(os.clock() - Session.startedAt)
	services.RegistrarAi.stop()
	if success then
		seatTheCast()
	end
	for _, player in Players:GetPlayers() do
		PlayerData.mark(player, "flags", "m001_seen")
		if success then
			PlayerData.mark(player, "missions", "M002")
			PlayerData.mark(player, "flags", "m001_done")
			PlayerData.addStat(player, "completions", 1)
			PlayerData.recordTime(player, duration)
		end
	end
	local names = {}
	for _, player in Players:GetPlayers() do
		table.insert(names, player.DisplayName)
	end
	for _, player in Players:GetPlayers() do
		local docCount = 0
		for _ in runDocs[player.UserId] or {} do
			docCount += 1
		end
		local earned = Achievements.earned({
			success = success,
			replays = Session.totalReplays,
			playerReplays = Session.totalReplays,
			wasCut = everCut[player.UserId] == true,
			docsThisRun = docCount,
			take = Session.take.number,
			teamSize = #names,
			seconds = duration,
		})
		for _, id in earned do
			PlayerData.mark(player, "achievements", id)
		end
		endRemote:FireClient(player, {
			success = success,
			duration = duration,
			replays = Session.totalReplays,
			cuts = Session.totalCuts,
			docs = docCount,
			take = Session.take.number,
			names = names,
			earned = earned,
			-- The tape is dated one week from now, which is the hook into the next mission.
			futureDate = os.date("%d.%m.%Y", os.time() + 7 * 86400),
			canTeleport = Places.HUB ~= 0 and not RunService:IsStudio(),
		})
	end
	Session.broadcast()
	task.spawn(function()
		PlayerData.saveAll(10)
		-- The expedition is over, so the hub must stop offering a way back to it.
		pcall(function()
			local map = MemoryStoreService:GetHashMap("ActiveExpedition")
			for _, player in Players:GetPlayers() do
				map:RemoveAsync(tostring(player.UserId))
			end
		end)
		task.wait(Config.Session.EndTapeSeconds)
		if Places.HUB == 0 or RunService:IsStudio() then
			print("[Session] mission over; teleport home skipped (no hub place id or Studio)")
			return
		end
		for attempt = 1, Config.Party.TeleportRetries do
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(Places.HUB, Players:GetPlayers())
			end)
			if ok then
				return
			end
			warn(`[Session] teleport home failed ({attempt}): {err}`)
			task.wait(3 ^ attempt)
		end
	end)
end

function Session.init(all: { [string]: any })
	services = all
	stateRemote = Net.get("SessionState")
	notifyRemote = Net.get("Notify")
	endRemote = Net.get("EndMission")
end

function Session.start()
	local expected = 1
	local function onJoin(player: Player)
		local seed, members = readJoin(player)
		if not Session.puzzle then
			Session.seed = seed or Random.new():NextInteger(1, 2 ^ 30)
			Session.puzzle = Puzzle.generate(Session.seed)
			expected = members
		end
		stateRemote:FireClient(player, publicState())
		services.Tapes.sendList(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			services.OffFrame.checkEveryoneCut()
		end)
	end)

	while #Players:GetPlayers() == 0 do
		task.wait(0.2)
	end
	-- A reserved server waits briefly for the whole party; anything else starts straight away.
	local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	if isReserved then
		local deadline = os.clock() + Config.Session.WaitForPartySeconds
		while #Players:GetPlayers() < expected and os.clock() < deadline do
			task.wait(0.25)
		end
	else
		task.wait(Config.Session.DevStartDelay)
	end
	begin()
end

return Session
