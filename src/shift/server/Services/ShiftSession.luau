--!strict
-- Runs one shift after another: the lift buttons, the rides, the quota, the pay, each player's
-- battery, tapes and camera, and what the team can see of each other. Frames and upgrades are
-- saved per player by ShiftBank.
--
-- A camera belongs to whoever holds it. When its owner is cut out of frame it falls where they
-- stood, with the footage it holds (Core/Shift carries footage per camera); anyone can pick it up
-- and bring it back in the lift. The lift hands everyone a fresh camera on every ride, and a
-- camera left on a floor is gone with that floor.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Shift = require(ReplicatedStorage.Shared.Core.Shift)
local Upgrades = require(ReplicatedStorage.Shared.Core.Upgrades)
local Wallet = require(ReplicatedStorage.Shared.Core.Wallet)

local ShiftSession = {}

local CFG = Config.Shift

type Anomaly = {
	id: number,
	position: Vector3,
	rarity: string,
	kind: string,
	value: number,
}

type Kit = {
	battery: number,
	empty: boolean,
	tapes: number,
	hasCamera: boolean,
}

local ROOM_NAMES = {
	lobby = "the lift lobby",
	hall = "the hall",
	office = "an office",
	storage = "storage",
	cloakroom = "the cloakroom",
	corridor = "a curtained corridor",
}

local services: { [string]: any }
local stateRemote: RemoteEvent
local resultRemote: RemoteEvent
local actionLimit = RateLimit.new(3, 5)

ShiftSession.shift = Shift.new(Shift.quotaFor(1)) :: Shift.State
ShiftSession.floor = nil :: FloorGen.Floor?
ShiftSession.anomalies = {} :: { Anomaly }
-- The team's best value per anomaly on this floor; filming one again pays only the improvement.
ShiftSession.best = {} :: { [number]: number }
ShiftSession.busy = false

local kits: { [Player]: Kit } = {}
local seed = 0
local anomalyFolder: Folder
local cameraFolder: Folder
local noticeId = 0
local shiftStarted = 0

local function kitOf(player: Player): Kit
	local kit = kits[player]
	if not kit then
		kit = { battery = 30, empty = false, tapes = 3, hasCamera = true }
		kits[player] = kit
	end
	return kit :: Kit
end

local function levelsOf(player: Player): { [string]: number }
	return services.ShiftBank.data(player).levels
end

local function depthText(depth: number): string
	return if depth == 0 then "0" else `-{depth}`
end

-- Custom events for the funnel (docs/09_GDD_V2.md §11.2). Roblox takes at most three custom
-- fields, as strings, under the CustomField01..03 keys. Analytics must never break a shift.
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function track(player: Player, name: string, value: number, fields: { string }?)
	local custom = {}
	for index, field in fields or {} do
		if FIELD_KEYS[index] then
			custom[FIELD_KEYS[index]] = field
		end
	end
	local ok, err = pcall(function()
		(AnalyticsService :: any):LogCustomEvent(player, name, value, custom)
	end)
	if not ok then
		warn(`[ShiftSession] analytics {name}: {err}`)
	end
end

local function snapshot(notice: string?): { [string]: any }
	local shift = ShiftSession.shift
	if notice then
		noticeId += 1
	end
	return {
		phase = shift.phase,
		depth = shift.depth,
		quota = shift.quota,
		banked = shift.banked,
		carried = shift.carried,
		multiplier = Shift.multiplier(math.max(1, shift.depth)),
		nextMultiplier = Shift.multiplier(shift.depth + 1),
		canDescend = Shift.canDescend(shift),
		maxDepth = Shift.MAX_DEPTH,
		notice = notice,
		noticeId = noticeId,
	}
end

function ShiftSession.broadcast(notice: string?)
	stateRemote:FireAllClients(snapshot(notice))
end

function ShiftSession.tell(player: Player, notice: string)
	stateRemote:FireClient(player, snapshot(notice))
end

local function refreshKitAttributes(player: Player)
	local kit = kitOf(player)
	local levels = levelsOf(player)
	local capacity = Upgrades.value(levels, "battery")
	player:SetAttribute("Battery", math.floor(kit.battery / capacity * 100 + 0.5) / 100)
	player:SetAttribute("BatteryEmpty", kit.empty)
	player:SetAttribute("TapesLeft", kit.tapes)
	player:SetAttribute("TapesMax", Upgrades.value(levels, "tapes"))
	player:SetAttribute("HasCamera", kit.hasCamera)
	player:SetAttribute("Carrying", Shift.carriedOf(ShiftSession.shift, player.UserId))
end

local function refill(player: Player)
	local kit = kitOf(player)
	local levels = levelsOf(player)
	kit.battery = Upgrades.value(levels, "battery")
	kit.empty = false
	kit.tapes = Upgrades.value(levels, "tapes")
	kit.hasCamera = true
	refreshKitAttributes(player)
end

function ShiftSession.useTape(player: Player): boolean
	local kit = kitOf(player)
	if kit.tapes <= 0 or not kit.hasCamera then
		return false
	end
	kit.tapes -= 1
	refreshKitAttributes(player)
	return true
end

function ShiftSession.hasCamera(player: Player): boolean
	return kitOf(player).hasCamera
end

function ShiftSession.lensWorks(player: Player): boolean
	local kit = kitOf(player)
	return kit.hasCamera and not kit.empty and player:GetAttribute("OffFrame") ~= true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function ShiftSession.inLift(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and services.ShiftWorld.inLift(root.Position)
end

local function countInLift(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if ShiftSession.inLift(player) then
			count += 1
		end
	end
	-- Whatever rode along counts too: the sign shows who is really in the cabin.
	if services.ShiftExtra.inCabin() then
		count += 1
	end
	return count
end

local function everyoneAboard(): boolean
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("OffFrame") ~= true and not ShiftSession.inLift(player) then
			return false
		end
	end
	return true
end

local function clearAnomalies()
	anomalyFolder:ClearAllChildren()
	ShiftSession.anomalies = {}
	ShiftSession.best = {}
end

-- Each anomaly is an invisible marker; clients draw the figure only through the lens.
local function placeAnomalies(floor: FloorGen.Floor)
	clearAnomalies()
	for _, spot in floor.spots do
		local value = (CFG.Values :: any)[spot.rarity] or CFG.Values.common
		local position = Vector3.new(spot.x, CFG.TargetHeight, spot.z)
		table.insert(ShiftSession.anomalies, {
			id = spot.id,
			position = position,
			rarity = spot.rarity,
			kind = spot.kind,
			value = value,
		})
		local marker = Instance.new("Part")
		marker.Name = `Anomaly{spot.id}`
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Transparency = 1
		marker.Size = Vector3.new(1, 1, 1)
		marker.Position = Vector3.new(spot.x, 0, spot.z)
		marker:SetAttribute("Id", spot.id)
		marker:SetAttribute("Kind", spot.kind)
		marker:SetAttribute("Rarity", spot.rarity)
		marker:SetAttribute("Seed", seed + spot.id)
		marker.Parent = anomalyFolder
	end
end

function ShiftSession.markFilmed(id: number, stars: number)
	local marker = anomalyFolder:FindFirstChild(`Anomaly{id}`)
	if marker then
		marker:SetAttribute("Stars", math.max(stars, marker:GetAttribute("Stars") or 0))
	end
end

-- The Archive keeps each player's best shot of each kind; a new entry is worth saying.
function ShiftSession.archive(player: Player, kind: string, stars: number)
	local data = services.ShiftBank.data(player)
	local isNew = data.archive[kind] == nil
	if Wallet.archive(data, kind, stars) then
		services.ShiftBank.changed(player)
		if isNew then
			local found, total = Wallet.archiveCount(data)
			ShiftSession.tell(player, `New in your Archive ({found}/{total}).`)
		end
	end
end

local function updateIndicator()
	services.ShiftWorld.setIndicator(depthText(ShiftSession.shift.depth), countInLift())
end

local function moveDoors(to: number, seconds: number)
	local world = services.ShiftWorld
	local from = world.doors()
	local steps = math.max(1, math.floor(seconds / 0.05))
	for step = 1, steps do
		world.setDoors(from + (to - from) * step / steps)
		task.wait(0.05)
	end
end

-- Closing waits while the Registrar stands in the doorway and nobody films him: hold him in frame
-- and the doors can shut. Returns false if someone stepped out before they closed.
local function closeDoors(): boolean
	local world = services.ShiftWorld
	local warned = false
	local rate = 0.05 / CFG.DoorCloseSeconds
	while world.doors() < 1 do
		if services.ShiftRegistrar.blocksDoor() then
			if not warned then
				warned = true
				ShiftSession.broadcast("It's in the doorway. Film it so the doors can close!")
			end
		else
			world.setDoors(world.doors() + rate)
		end
		task.wait(0.05)
		if not everyoneAboard() then
			moveDoors(0, 0.6)
			ShiftSession.broadcast("Someone stepped out. Everyone back in the lift.")
			return false
		end
	end
	return true
end

local function bringEveryoneIn()
	services.ShiftOffFrame.restoreAll()
	for index, player in Players:GetPlayers() do
		if not ShiftSession.inLift(player) then
			local character = player.Character
			if character then
				local offset = Vector3.new(((index - 1) % 3 - 1) * 3, 0, 0)
				character:PivotTo(services.ShiftWorld.spawnCFrame + offset)
			end
		end
	end
end

-- Cameras left lying on a floor go with it. Returns how much footage they held.
local function clearCameras(): number
	local lost = 0
	for _, camera in cameraFolder:GetChildren() do
		local held = camera:GetAttribute("Footage")
		if typeof(held) == "number" then
			lost += held
		end
	end
	cameraFolder:ClearAllChildren()
	return lost
end

local function onPickUp(picker: Player, camera: BasePart)
	if camera.Parent ~= cameraFolder or picker:GetAttribute("OffFrame") == true then
		return
	end
	local shift = ShiftSession.shift
	local held = camera:GetAttribute("Footage")
	local amount = if typeof(held) == "number" then held else 0
	if not Shift.pickUp(shift, picker.UserId, amount) then
		return
	end
	local owner = camera:GetAttribute("Owner")
	camera:Destroy()
	local kit = kitOf(picker)
	if not kit.hasCamera then
		-- A camera for a player who has none: theirs or a teammate's, it films the same.
		kit.hasCamera = true
		kit.battery = Upgrades.value(levelsOf(picker), "battery") * 0.5
		kit.empty = false
	end
	refreshKitAttributes(picker)
	local whose = if owner == picker.DisplayName then "their own" else `{owner}'s`
	ShiftSession.broadcast(
		if amount > 0
			then `{picker.DisplayName} picked up {whose} camera (+{amount} footage).`
			else `{picker.DisplayName} picked up {whose} camera.`
	)
end

-- The owner was cut: their camera falls where they stood, with everything it holds.
local function dropCamera(player: Player)
	local shift = ShiftSession.shift
	local kit = kitOf(player)
	if shift.phase ~= "floor" or not kit.hasCamera then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local amount = Shift.drop(shift, player.UserId)
	kit.hasCamera = false
	refreshKitAttributes(player)

	local at = root.Position
	local camera = Instance.new("Part")
	camera.Name = "DroppedCamera"
	camera.Anchored = true
	camera.CanCollide = false
	camera.CanQuery = false
	camera.CanTouch = false
	camera.Size = Vector3.new(1.4, 0.9, 2)
	camera.Color = Palette.Ink
	camera.Material = Enum.Material.SmoothPlastic
	camera.CFrame = CFrame.new(at.X, 0.45, at.Z) * CFrame.Angles(0, math.rad(at.X * 37 % 360), 0)
	camera:SetAttribute("Footage", amount)
	camera:SetAttribute("Owner", player.DisplayName)
	local lamp = Instance.new("PointLight")
	lamp.Color = Palette.Rec
	lamp.Range = 6
	lamp.Brightness = 1.4
	lamp.Parent = camera
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if amount > 0 then `Pick up (+{amount} footage)` else "Pick up"
	prompt.ObjectText = `{player.DisplayName}'s camera`
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.Parent = camera
	prompt.Triggered:Connect(function(picker)
		onPickUp(picker, camera)
	end)
	camera.Parent = cameraFolder
	ShiftSession.broadcast()
end

-- ShiftOffFrame calls this for every cut, whoever did it.
function ShiftSession.onCut(player: Player, cause: string)
	track(player, "ShiftCut", ShiftSession.shift.depth, { cause })
	services.ShiftTapes.cancel(player)
	dropCamera(player)
end

-- Who is where, for the team list: the Extra can wear your face, never your position.
local function whereOf(player: Player): string
	if player:GetAttribute("OffFrame") == true then
		return "cut out of frame"
	end
	local root = rootOf(player)
	if not root then
		return "?"
	end
	if services.ShiftWorld.inLift(root.Position) then
		return "in the lift"
	end
	local floor = ShiftSession.floor
	if not floor then
		return "in the lift"
	end
	local room = FloorGen.roomAt(floor, root.Position.X, root.Position.Z)
	if not room then
		return "in the lift"
	end
	local kind = floor.rooms[room].kind
	return `{ROOM_NAMES[kind] or kind} (room {room})`
end

local function ride(down: boolean)
	local shift = ShiftSession.shift
	local world = services.ShiftWorld
	services.ShiftRegistrar.stop()
	services.ShiftUsher.stop()
	if down then
		services.ShiftExtra.depart()
	else
		services.ShiftExtra.stop()
	end
	bringEveryoneIn()
	for _, player in Players:GetPlayers() do
		refill(player)
	end
	local lost = clearCameras()
	services.ShiftTapes.clearFloor()
	world.clearFloor()
	clearAnomalies()
	ShiftSession.broadcast(
		if lost > 0 then `{lost} footage stayed behind on a dropped camera.` else nil
	)
	updateIndicator()
	local seconds = if down then CFG.RideSeconds else CFG.ReturnSeconds
	if down then
		local floor = FloorGen.generate(seed, shift.depth)
		ShiftSession.floor = floor
		world.buildFloor(floor, seed)
		services.ShiftDoors.build(floor)
		placeAnomalies(floor)
		services.ShiftRegistrar.setFloor(floor, shift.depth)
		services.ShiftExtra.setFloor(floor, shift.depth)
		services.ShiftUsher.setFloor(floor, shift.depth)
	else
		ShiftSession.floor = nil
	end
	task.wait(seconds)
end

local function sendResult(player: Player)
	local shift = ShiftSession.shift
	local data = services.ShiftBank.data(player)
	local upgrades = {}
	for _, upgrade in Upgrades.LIST do
		table.insert(upgrades, {
			id = upgrade.id,
			name = upgrade.name,
			level = Upgrades.level(data.levels, upgrade.id),
			maxLevel = #upgrade.values,
			value = Upgrades.value(data.levels, upgrade.id),
			cost = Upgrades.nextCost(data.levels, upgrade.id),
		})
	end
	local archive = {}
	for _, kind in Wallet.KINDS do
		table.insert(archive, { kind = kind, stars = data.archive[kind] or 0 })
	end
	resultRemote:FireClient(player, {
		result = shift.result,
		banked = shift.banked,
		quota = shift.quota,
		met = shift.banked >= shift.quota,
		payout = Shift.payout(shift),
		deepest = shift.deepest,
		record = data.deepest,
		money = data.frames,
		upgrades = upgrades,
		archive = archive,
		saved = services.ShiftBank.saving(player),
	})
end

local function payEveryone()
	local shift = ShiftSession.shift
	local payout = Shift.payout(shift)
	local returned = shift.result == "returned"
	for _, player in Players:GetPlayers() do
		Wallet.recordShift(services.ShiftBank.data(player), payout, shift.deepest, returned)
		services.ShiftBank.changed(player)
		track(player, "ShiftEnd", math.floor(os.clock() - shiftStarted), {
			`{shift.result}`,
			`depth {shift.deepest}`,
			`players {#Players:GetPlayers()}`,
		})
		sendResult(player)
	end
end

local function newShift()
	seed = Random.new():NextInteger(1, 1000000)
	shiftStarted = os.clock()
	ShiftSession.shift = Shift.new(Shift.quotaFor(#Players:GetPlayers()))
	ShiftSession.floor = nil
	clearAnomalies()
	clearCameras()
	services.ShiftTapes.clearFloor()
	services.ShiftExtra.stop()
	services.ShiftUsher.stop()
	services.ShiftWorld.clearFloor()
	services.ShiftWorld.setDoors(1)
	services.ShiftWorld.applyDepth(1)
	for _, player in Players:GetPlayers() do
		refill(player)
	end
	updateIndicator()
	ShiftSession.broadcast("New shift. Press DOWN in the lift to start.")
end

local function arrive()
	local shift = ShiftSession.shift
	Shift.arrive(shift)
	services.ShiftExtra.arrived()
	updateIndicator()
	local line = `Floor {depthText(shift.depth)}. Footage pays x{Shift.multiplier(shift.depth)}.`
	local floor = ShiftSession.floor
	if floor and floor.vault then
		line ..= " There's a code door somewhere."
	end
	ShiftSession.broadcast(line)
	moveDoors(0, CFG.DoorOpenSeconds)
end

-- Runs a lift sequence with the lift marked busy. An error must never leave it busy for good, or
-- nobody could ever ride again.
local function whileBusy(work: () -> ())
	ShiftSession.busy = true
	local ok, err = xpcall(work, debug.traceback)
	ShiftSession.busy = false
	if not ok then
		warn(`[ShiftSession] lift sequence failed: {err}`)
	end
end

local function onDown(player: Player)
	local shift = ShiftSession.shift
	if ShiftSession.busy or player:GetAttribute("OffFrame") == true then
		return
	end
	if shift.phase == "over" then
		-- Whoever closed the pay screen gets it back.
		ShiftSession.tell(player, "The shift is over. Press NEXT SHIFT on the pay screen.")
		sendResult(player)
		return
	end
	if not Shift.canDescend(shift) then
		ShiftSession.tell(player, "This is the bottom floor. The only way is up.")
		return
	end
	if not everyoneAboard() then
		ShiftSession.tell(player, "Everyone has to be in the lift.")
		return
	end
	whileBusy(function()
		if shift.phase == "floor" and not closeDoors() then
			return
		end
		Shift.descend(shift)
		track(player, "ShiftDescend", shift.depth)
		ride(true)
		arrive()
	end)
end

local function onUp(player: Player)
	local shift = ShiftSession.shift
	if ShiftSession.busy or player:GetAttribute("OffFrame") == true then
		return
	end
	if shift.phase ~= "floor" then
		ShiftSession.tell(player, "The lift only goes up from a floor.")
		return
	end
	if not everyoneAboard() then
		ShiftSession.tell(player, "Everyone has to be in the lift.")
		return
	end
	whileBusy(function()
		if not closeDoors() then
			return
		end
		Shift.ascend(shift)
		ride(false)
		Shift.finish(shift)
		updateIndicator()
		ShiftSession.broadcast("Back at the Bureau.")
		payEveryone()
	end)
end

-- Called by ShiftOffFrame when nobody is left in frame and no way back remains.
function ShiftSession.onEveryoneCut()
	local shift = ShiftSession.shift
	if shift.phase ~= "floor" or ShiftSession.busy then
		return
	end
	whileBusy(function()
		Shift.fail(shift)
		services.ShiftRegistrar.stop()
		services.ShiftExtra.stop()
		services.ShiftUsher.stop()
		services.ShiftWorld.setDoors(1)
		ShiftSession.broadcast("Everyone was cut out of frame. The Bureau pays a quarter.")
		bringEveryoneIn()
		clearCameras()
		services.ShiftTapes.clearFloor()
		services.ShiftWorld.clearFloor()
		clearAnomalies()
		payEveryone()
	end)
end

-- Footage from a tape, onto the camera of whoever shot it.
function ShiftSession.addFootage(player: Player, gain: number): number
	local added = Shift.addFootage(ShiftSession.shift, gain, player.UserId)
	if added > 0 then
		refreshKitAttributes(player)
		ShiftSession.broadcast()
	end
	return added
end

-- Footage of whatever rode in the lift, which counts during the ride.
function ShiftSession.addRideFootage(player: Player, gain: number): number
	local added = Shift.addRideFootage(ShiftSession.shift, gain, player.UserId)
	if added > 0 then
		refreshKitAttributes(player)
		ShiftSession.broadcast()
	end
	return added
end

local function onAction(player: Player, action: unknown, arg: unknown)
	if not actionLimit:allow(player, os.clock()) then
		return
	end
	local phase = ShiftSession.shift.phase
	if action == "buy" and typeof(arg) == "string" then
		if phase ~= "over" and phase ~= "ready" then
			return
		end
		if not services.ShiftBank.loaded(player) then
			ShiftSession.tell(player, "Your wallet is still loading.")
			return
		end
		local data = services.ShiftBank.data(player)
		local ok, money = Upgrades.buy(data.levels, data.frames, arg)
		if ok then
			data.frames = money
			services.ShiftBank.changed(player)
			refill(player)
			track(player, "UpgradeBought", Upgrades.level(data.levels, arg), { arg })
		end
		sendResult(player)
	elseif action == "next" then
		if phase == "over" and not ShiftSession.busy then
			newShift()
		end
	elseif action == "hello" then
		-- The client is listening now; anything sent before this may have reached only one of its
		-- controllers.
		stateRemote:FireClient(player, snapshot())
		if phase == "over" then
			sendResult(player)
		end
	end
end

function ShiftSession.init(all: { [string]: any })
	services = all
	stateRemote = Net.get("ShiftState")
	resultRemote = Net.get("ShiftResult")
	Net.get("ShiftAction").OnServerEvent:Connect(onAction)
	anomalyFolder = Instance.new("Folder")
	anomalyFolder.Name = "Anomalies"
	anomalyFolder.Parent = Workspace
	cameraFolder = Instance.new("Folder")
	cameraFolder.Name = "DroppedCameras"
	cameraFolder.Parent = Workspace
	Players.PlayerAdded:Connect(function(player)
		refill(player)
	end)
	-- Upgrades bought in an earlier session arrive with the wallet.
	services.ShiftBank.onLoaded(function(player)
		if player.Parent then
			refill(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		kits[player] = nil
		actionLimit:forget(player)
	end)
end

function ShiftSession.start()
	local world = services.ShiftWorld
	world.downPrompt.Triggered:Connect(onDown)
	world.upPrompt.Triggered:Connect(onUp)
	newShift()

	-- Batteries drain while a lens is up and charge while it is down, faster in the lift.
	local step = 0.25
	local lastPersons = -1
	local whereClock = 0
	while true do
		task.wait(step)
		for _, player in Players:GetPlayers() do
			local kit = kitOf(player)
			local capacity = Upgrades.value(levelsOf(player), "battery")
			if services.Lens.isRaised(player) and not kit.empty then
				kit.battery = math.max(0, kit.battery - step)
				if kit.battery <= 0 then
					kit.empty = true
				end
			else
				local rate = CFG.Recharge
					* (if ShiftSession.inLift(player) then CFG.LiftRecharge else 1)
				kit.battery = math.min(capacity, kit.battery + step * rate)
				if kit.empty and kit.battery >= capacity * CFG.BatteryResume then
					kit.empty = false
				end
			end
			refreshKitAttributes(player)
		end
		whereClock += step
		if whereClock >= 0.5 then
			whereClock = 0
			for _, player in Players:GetPlayers() do
				player:SetAttribute("Where", whereOf(player))
			end
		end
		local persons = countInLift()
		if persons ~= lastPersons then
			lastPersons = persons
			updateIndicator()
		end
	end
end

return ShiftSession
