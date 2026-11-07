--!strict
-- Stages the small wrong things from Core/Omens. They are local, so each player's hall drifts in
-- its own way, and each waits until its target is out of view: nobody ever sees a change happen,
-- only that something is different now.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Build = require(ReplicatedStorage.Shared.World.Build)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Omens = require(ReplicatedStorage.Shared.Core.Omens)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)

local OmenDirector = {}

local localPlayer = Players.LocalPlayer
local map: Instance
local controllers: { [string]: any }
local schedule: { Omens.Omen }? = nil
local elapsed = 0
local running = false
local pathMemory: { CFrame } = {}

local function cameraPosition(): Vector3
	return (Workspace.CurrentCamera :: Camera).CFrame.Position
end

-- Well outside the frame, even allowing for a quick glance to the side.
local function isOutOfView(position: Vector3): boolean
	local camera = Workspace.CurrentCamera :: Camera
	local offset = position - camera.CFrame.Position
	if offset.Magnitude < 1 then
		return false
	end
	return camera.CFrame.LookVector:Dot(offset.Unit) < 0.25
end

local function inHall(): boolean
	local p = cameraPosition()
	local h = Layout.HALL
	return p.X > h.minX and p.X < h.maxX and p.Z > h.minZ and p.Z < h.maxZ and p.Y < 12
end

local function turnSeat(id: number)
	local seat = map:FindFirstChild("Seats") and (map :: any).Seats:FindFirstChild(`Seat{id}`)
	if not seat then
		return
	end
	local x, z = Seats.position(id)
	local pivot = CFrame.new(x, 0, z)
	local turned = pivot * CFrame.Angles(0, math.pi, 0)
	for _, part in { seat, seat:FindFirstChild("Back"), seat:FindFirstChild("Legs") } do
		if part then
			part.CFrame = turned * pivot:ToObjectSpace(part.CFrame)
		end
	end
end

-- Footfalls that keep pace behind the player and stop when they turn round.
local function stepsBehind(): boolean
	local camera = Workspace.CurrentCamera :: Camera
	task.spawn(function()
		for index = 1, 5 do
			local look = camera.CFrame.LookVector
			local behind = camera.CFrame.Position
				- Vector3.new(look.X, 0, look.Z).Unit * (11 - index)
			if not isOutOfView(behind) then
				return
			end
			AudioDirector.playAt("Step", behind - Vector3.new(0, 4, 0), 0.5, 40)
			task.wait(0.62)
		end
	end)
	return true
end

local function panelOut(): boolean
	local nearest: BasePart? = nil
	local best = math.huge
	for _, item in map:GetChildren() do
		if item.Name == "LightPanel" and item:IsA("BasePart") then
			local distance = (item.Position - cameraPosition()).Magnitude
			if distance < best and distance < 60 then
				nearest, best = item, distance
			end
		end
	end
	if not nearest then
		return false
	end
	local panel = nearest :: BasePart
	local light = panel:FindFirstChildOfClass("SpotLight")
	if not light then
		return false
	end
	local baseColor = panel.Color
	local baseBrightness = light.Brightness
	local function set(on: boolean)
		panel.Color = if on then baseColor else Palette.Ceiling
		panel.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		light.Brightness = if on then baseBrightness else 0
	end
	task.spawn(function()
		for _ = 1, 3 do
			set(false)
			task.wait(0.07)
			set(true)
			task.wait(0.11)
		end
		set(false)
		task.wait(5)
		set(true)
	end)
	return true
end

local function aisleChair(): boolean
	if not inHall() then
		return false
	end
	-- One empty chair in the middle of the aisle, turned to face whoever is standing there.
	local position = cameraPosition()
	local z = math.clamp(position.Z - 14, Seats.FIRST_ROW_Z, Layout.HALL.maxZ - 8)
	local spot = Vector3.new(0, 0, z)
	if not isOutOfView(spot + Vector3.new(0, 3, 0)) then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = "AisleChair"
	local chair =
		Build.chair(folder, "Chair", CFrame.lookAt(spot, Vector3.new(position.X, 0, position.Z)))
	chair.CanCollide = false
	folder.Parent = Workspace
	task.delay(70, function()
		if isOutOfView(spot + Vector3.new(0, 3, 0)) then
			folder:Destroy()
		else
			task.wait(15)
			folder:Destroy()
		end
	end)
	return true
end

local function knockWall(): boolean
	local camera = Workspace.CurrentCamera :: Camera
	local p = camera.CFrame.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	local right = camera.CFrame.RightVector
	local hit = Workspace:Raycast(p, Vector3.new(right.X, 0, right.Z).Unit * 60, params)
	if not hit then
		return false
	end
	AudioDirector.playAt("Knock", hit.Position, 0.9, 70)
	return true
end

local function corridorFigure(): boolean
	local h = Layout.HALL
	local p = cameraPosition()
	local inCorridor = p.X < h.minX
	if not inCorridor and not inHall() then
		return false
	end
	-- At the far end of the corridor, visible with the naked eye, gone once looked at for long.
	local spot = if inCorridor
		then Vector3.new(-43.5, if p.Z < -30 then 0 else 3, if p.Z < -24 then -6 else -41)
		else Vector3.new(-37.5, 0, -9)
	if not isOutOfView(spot + Vector3.new(0, 5, 0)) then
		return false
	end
	local figure = Instance.new("Part")
	figure.Name = "Figure"
	figure.Anchored = true
	figure.CanCollide = false
	figure.CanQuery = false
	figure.Size = Vector3.new(2, 11, 0.9)
	figure.Position = spot + Vector3.new(0, 5.5, 0)
	figure.Color = Palette.Ink
	figure.Parent = Workspace
	task.spawn(function()
		local deadline = os.clock() + 40
		local seenFor = 0
		while os.clock() < deadline do
			task.wait(0.1)
			if not isOutOfView(figure.Position) then
				seenFor += 0.1
				if seenFor >= 1.1 then
					break
				end
			end
		end
		figure:Destroy()
	end)
	return true
end

local function bellRings(): boolean
	local bell = map:FindFirstChild("Bell") :: BasePart?
	if not bell or inHall() and (bell.Position - cameraPosition()).Magnitude < 25 then
		return false
	end
	AudioDirector.playAt("Bell", bell.Position, 0.8, 180)
	return true
end

local function rowTurned(firstSeat: number): boolean
	local row = Seats.fromId(firstSeat)
	local _, z = Seats.position(firstSeat)
	if not isOutOfView(Vector3.new(0, 3, z)) and inHall() then
		return false
	end
	for col = 1, Seats.COLS do
		turnSeat(Seats.id(row, col))
	end
	return true
end

-- Keeps a short memory of where the player has walked, for the double.
local function rememberPath()
	local interval = 0.5
	while true do
		task.wait(interval)
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(pathMemory, root.CFrame)
			if #pathMemory > 180 then
				table.remove(pathMemory, 1)
			end
		end
	end
end

-- Someone wearing you walks the route you took a minute ago, and stops existing if you look too
-- long. Glides on purpose: it does not quite know how you walk yet.
local function theDouble(): boolean
	local character = localPlayer.Character
	if not character or #pathMemory < 70 then
		return false
	end
	local start = #pathMemory - 60
	local steps = 24
	local first = pathMemory[start]
	if not isOutOfView(first.Position) or (first.Position - cameraPosition()).Magnitude < 16 then
		return false
	end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	if not clone then
		return false
	end
	for _, item in clone:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("Light") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.LocalTransparencyModifier = 0
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	clone.Name = "Double"
	clone:PivotTo(first)
	clone.Parent = Workspace
	task.spawn(function()
		local seenFor = 0
		for index = 0, steps do
			local from = pathMemory[start + index]
			local to = pathMemory[start + index + 1]
			if not from or not to then
				break
			end
			local progress = 0
			while progress < 0.5 do
				progress += RunService.Heartbeat:Wait()
				clone:PivotTo(from:Lerp(to, math.min(progress / 0.5, 1)))
				if not isOutOfView(clone:GetPivot().Position) then
					seenFor += 1 / 60
				end
			end
			if seenFor >= 1.4 then
				break
			end
		end
		clone:Destroy()
	end)
	return true
end

local function stage(omen: Omens.Omen): boolean
	local kind = omen.kind
	if kind == "steps_behind" then
		return stepsBehind()
	elseif kind == "panel_out" then
		return panelOut()
	elseif kind == "aisle_chair" then
		return aisleChair()
	elseif kind == "knock_wall" then
		return knockWall()
	elseif kind == "corridor_figure" then
		return corridorFigure()
	elseif kind == "bell_rings" then
		return bellRings()
	elseif kind == "double" then
		return theDouble()
	elseif kind == "chair_turned" then
		local id = omen.seatId :: number
		local x, z = Seats.position(id)
		if not isOutOfView(Vector3.new(x, 3, z)) then
			return false
		end
		turnSeat(id)
		return true
	elseif kind == "row_turned" then
		return rowTurned(omen.seatId :: number)
	end
	return true
end

function OmenDirector.init(all: { [string]: any })
	controllers = all
end

-- The projected film never holds steady.
local function flickerFilm()
	local screen = map:WaitForChild("Screen", 20)
	local gui = screen and screen:FindFirstChildOfClass("SurfaceGui")
	local film = gui and gui:FindFirstChild("Film") :: Frame?
	if not film then
		return
	end
	local random = Random.new()
	while true do
		task.wait(0.09)
		if film.Visible then
			film.BackgroundTransparency = random:NextNumber(0.12, 0.38)
		end
	end
end

function OmenDirector.start()
	map = Workspace:WaitForChild("Map")
	task.spawn(flickerFilm)
	task.spawn(rememberPath)
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		if state.omenSeed and not schedule then
			schedule = Omens.schedule(state.omenSeed, localPlayer.UserId)
		end
		running = state.phase ~= "Waiting" and state.phase ~= "Done" and state.phase ~= "Failed"
	end)
	local step = 0.5
	while true do
		task.wait(step)
		local list = schedule
		if running and list and not controllers.Playback.active() then
			-- Studio only: compresses the schedule so a test does not take ten minutes.
			local speed = Workspace:GetAttribute("DevOmenSpeed")
			elapsed += step * (if RunService:IsStudio() and typeof(speed) == "number"
				then speed
				else 1)
			-- An omen that cannot play right now must not hold up the ones behind it.
			for index, omen in list do
				if elapsed < omen.at then
					break
				end
				local ok, staged = pcall(stage, omen)
				if not ok then
					warn(`[OmenDirector] {omen.kind}: {staged}`)
				end
				if not ok or staged then
					print(`[Omen] {omen.kind} at {math.floor(elapsed)}`)
					table.remove(list, index)
					break
				end
			end
		end
	end
end

return OmenDirector
