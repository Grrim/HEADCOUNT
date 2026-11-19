--!strict
-- Runs one shift after another: the lift buttons, the rides, the quota, the pay, and each player's
-- battery, tapes, money and upgrades. Money and upgrades live in memory for this server only:
-- the prototype tests whether the loop is fun before anything is saved.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Game)
local FloorGen = require(ReplicatedStorage.Shared.Core.FloorGen)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Shift = require(ReplicatedStorage.Shared.Core.Shift)
local Upgrades = require(ReplicatedStorage.Shared.Core.Upgrades)

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
	money: number,
	levels: { [string]: number },
	battery: number,
	empty: boolean,
	tapes: number,
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
local noticeId = 0

local function kitOf(player: Player): Kit
	local kit = kits[player]
	if not kit then
		kit = { money = 0, levels = {}, battery = 30, empty = false, tapes = 3 }
		kits[player] = kit
	end
	return kit :: Kit
end

function ShiftSession.kit(player: Player): Kit
	return kitOf(player)
end

local function depthText(depth: number): string
	return if depth == 0 then "0" else `-{depth}`
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
	local capacity = Upgrades.value(kit.levels, "battery")
	player:SetAttribute("Battery", math.floor(kit.battery / capacity * 100 + 0.5) / 100)
	player:SetAttribute("BatteryEmpty", kit.empty)
	player:SetAttribute("TapesLeft", kit.tapes)
	player:SetAttribute("TapesMax", Upgrades.value(kit.levels, "tapes"))
end

local function refill(player: Player)
	local kit = kitOf(player)
	kit.battery = Upgrades.value(kit.levels, "battery")
	kit.empty = false
	kit.tapes = Upgrades.value(kit.levels, "tapes")
	refreshKitAttributes(player)
end

function ShiftSession.useTape(player: Player): boolean
	local kit = kitOf(player)
	if kit.tapes <= 0 then
		return false
	end
	kit.tapes -= 1
	refreshKitAttributes(player)
	return true
end

function ShiftSession.lensWorks(player: Player): boolean
	return not kitOf(player).empty and player:GetAttribute("OffFrame") ~= true
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

local function ride(down: boolean)
	local shift = ShiftSession.shift
	local world = services.ShiftWorld
	services.ShiftRegistrar.stop()
	bringEveryoneIn()
	for _, player in Players:GetPlayers() do
		refill(player)
	end
	world.clearFloor()
	clearAnomalies()
	ShiftSession.broadcast()
	local seconds = if down then CFG.RideSeconds else CFG.ReturnSeconds
	if down then
		local floor = FloorGen.generate(seed, shift.depth)
		ShiftSession.floor = floor
		world.buildFloor(floor, seed)
		placeAnomalies(floor)
		services.ShiftRegistrar.setFloor(floor, shift.depth)
	else
		ShiftSession.floor = nil
	end
	task.wait(seconds)
end

local function sendResult(player: Player)
	local shift = ShiftSession.shift
	local kit = kitOf(player)
	local upgrades = {}
	for _, upgrade in Upgrades.LIST do
		table.insert(upgrades, {
			id = upgrade.id,
			name = upgrade.name,
			level = Upgrades.level(kit.levels, upgrade.id),
			maxLevel = #upgrade.values,
			value = Upgrades.value(kit.levels, upgrade.id),
			cost = Upgrades.nextCost(kit.levels, upgrade.id),
		})
	end
	resultRemote:FireClient(player, {
		result = shift.result,
		banked = shift.banked,
		quota = shift.quota,
		met = shift.banked >= shift.quota,
		payout = Shift.payout(shift),
		deepest = shift.deepest,
		money = kit.money,
		upgrades = upgrades,
	})
end

local function payEveryone()
	local payout = Shift.payout(ShiftSession.shift)
	for _, player in Players:GetPlayers() do
		local kit = kitOf(player)
		kit.money += payout
		sendResult(player)
	end
end

local function newShift()
	seed = Random.new():NextInteger(1, 1000000)
	ShiftSession.shift = Shift.new(Shift.quotaFor(#Players:GetPlayers()))
	ShiftSession.floor = nil
	clearAnomalies()
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
	updateIndicator()
	ShiftSession.broadcast(`Floor {depthText(shift.depth)}. Footage pays x{Shift.multiplier(shift.depth)}.`)
	moveDoors(0, CFG.DoorOpenSeconds)
end

local function onDown(player: Player)
	local shift = ShiftSession.shift
	if ShiftSession.busy or player:GetAttribute("OffFrame") == true then
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
	ShiftSession.busy = true
	if shift.phase == "floor" and not closeDoors() then
		ShiftSession.busy = false
		return
	end
	Shift.descend(shift)
	ride(true)
	arrive()
	ShiftSession.busy = false
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
	ShiftSession.busy = true
	if not closeDoors() then
		ShiftSession.busy = false
		return
	end
	Shift.ascend(shift)
	ride(false)
	Shift.finish(shift)
	updateIndicator()
	ShiftSession.broadcast("Back at the Bureau.")
	payEveryone()
	ShiftSession.busy = false
end

-- Called by ShiftOffFrame when nobody is left in frame and no way back remains.
function ShiftSession.onEveryoneCut()
	local shift = ShiftSession.shift
	if shift.phase ~= "floor" or ShiftSession.busy then
		return
	end
	ShiftSession.busy = true
	Shift.fail(shift)
	services.ShiftRegistrar.stop()
	services.ShiftWorld.setDoors(1)
	ShiftSession.broadcast("Everyone was cut out of frame. The Bureau pays a quarter.")
	bringEveryoneIn()
	services.ShiftWorld.clearFloor()
	clearAnomalies()
	payEveryone()
	ShiftSession.busy = false
end

function ShiftSession.addFootage(_player: Player, gain: number): number
	local added = Shift.addFootage(ShiftSession.shift, gain)
	if added > 0 then
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
		local kit = kitOf(player)
		local ok, money = Upgrades.buy(kit.levels, kit.money, arg)
		if ok then
			kit.money = money
			refill(player)
		end
		sendResult(player)
	elseif action == "next" then
		if phase == "over" and not ShiftSession.busy then
			newShift()
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
	Players.PlayerAdded:Connect(function(player)
		refill(player)
		task.defer(function()
			stateRemote:FireClient(player, snapshot())
		end)
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
	while true do
		task.wait(step)
		for _, player in Players:GetPlayers() do
			local kit = kitOf(player)
			local capacity = Upgrades.value(kit.levels, "battery")
			if services.Lens.isRaised(player) and not kit.empty then
				kit.battery = math.max(0, kit.battery - step)
				if kit.battery <= 0 then
					kit.empty = true
				end
			else
				local rate = CFG.Recharge * (if ShiftSession.inLift(player) then CFG.LiftRecharge else 1)
				kit.battery = math.min(capacity, kit.battery + step * rate)
				if kit.empty and kit.battery >= capacity * CFG.BatteryResume then
					kit.empty = false
				end
			end
			refreshKitAttributes(player)
		end
		local persons = countInLift()
		if persons ~= lastPersons then
			lastPersons = persons
			updateIndicator()
		end
	end
end

return ShiftSession
