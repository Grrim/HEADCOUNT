--!strict
-- A quiet marker for the next step's target: a small diamond with a distance, pinned to the thing
-- itself when it is on screen and to the screen's edge when it is not. It is not a permanent
-- compass. It shows for a few seconds when the step changes, comes back when the player has been
-- on one step for a while, and stays away while the camera is raised (the lens is for looking).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(ReplicatedStorage.ClientCommon.Ui)

local Waypoint = {}

-- Seconds the marker shows after a new step, and how long a step may run before it returns.
local SHOW_SECONDS = 9
local STUCK_AFTER = 50
-- Studs: one stud is about 0.28 m on the default avatar scale, close enough for "how far".
local METRES_PER_STUD = 0.28

local controllers: { [string]: any }
local gui: ScreenGui
local marker: Frame
local diamond: Frame
local distanceLabel: TextLabel
local nameLabel: TextLabel
local target: Vector3? = nil
local targetName = ""
local stepId = ""
local stepSince = 0
local showUntil = 0
local override: Vector3? = nil
local overrideName = ""

-- The prompt whose object is named by this key (and suffix, for numbered coats).
local function promptPosition(objectKey: string, suffix: string?): Vector3?
	for _, item in Workspace:GetDescendants() do
		if item:IsA("ProximityPrompt") and item:GetAttribute("ObjectKey") == objectKey then
			if suffix == nil or item:GetAttribute("ObjectSuffix") == suffix then
				local parent = item.Parent
				if parent and parent:IsA("BasePart") and item.Enabled then
					return parent.Position
				elseif parent and parent:IsA("Attachment") then
					return parent.WorldPosition
				end
			end
		end
	end
	return nil
end

local function seatPosition(label: string): Vector3?
	for id = 1, Seats.TOTAL do
		if Seats.label(id) == label then
			local x, z = Seats.position(id)
			return Vector3.new(x, 3, z)
		end
	end
	return nil
end

-- Where a step points, and what to call it. Steps about the camera itself point nowhere.
local function resolve(step: any): (Vector3?, string)
	if not step then
		return nil, ""
	end
	local key = step.key
	local first = step.args and step.args[1]
	if key == "step_coat" and first then
		local hook = tostring(first):match("^(%d+)")
		return promptPosition("obj_hook", hook), Strings.get("wp_coat", hook or "")
	elseif key == "step_seat" and first then
		local label = tostring(first):match("^([%a]%-%d+)")
		return if label then seatPosition(label) else nil, Strings.get("wp_seat", label or "")
	elseif key == "step_no_tape" then
		return promptPosition("obj_tape_box"), Strings.get("obj_tape_box")
	elseif key == "step_code_enter" then
		return promptPosition("obj_breaker"), Strings.get("obj_breaker")
	elseif key == "step_code_find" then
		return promptPosition("obj_bell_name"), Strings.get("wp_stage")
	elseif key == "step_order_find" then
		return promptPosition("obj_recorder"), Strings.get("obj_recorder")
	elseif key == "step_order_load" then
		return promptPosition("obj_reel"), Strings.get("obj_projector_name")
	elseif key == "step_register" then
		return promptPosition("obj_register_name"), Strings.get("obj_register_name")
	elseif key == "step_bell" then
		return promptPosition("obj_bell_name"), Strings.get("obj_bell_name")
	end
	return nil, ""
end

function Waypoint.setStep(step: any?)
	local id = if step then step.key .. "|" .. table.concat(step.args or {}, "|") else ""
	if id == stepId then
		return
	end
	stepId = id
	stepSince = os.clock()
	target, targetName = resolve(step)
	showUntil = if target then os.clock() + SHOW_SECONDS else 0
end

-- A fixed target that wins over the step (the leader mark for a player out of frame).
function Waypoint.setOverride(position: Vector3?, name: string?)
	override = position
	overrideName = name or ""
end

-- Shows the marker again now, for the notebook's "where?" or a radio nudge.
function Waypoint.ping()
	if target then
		showUntil = os.clock() + SHOW_SECONDS
	end
end

function Waypoint.init(all: { [string]: any })
	controllers = all
	gui = Ui.screen("Waypoint", 1, true)
	marker = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(120, 60),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	diamond = Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(12, 12),
		Rotation = 45,
		BackgroundColor3 = Ui.C.Accent,
		BackgroundTransparency = 0.1,
	}, marker)
	Ui.stroke(diamond, Ui.C.Ink, 0.3, 1.5)
	nameLabel = Ui.text({
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Ui.Fonts.BodyBold,
		TextSize = 14,
		TextColor3 = Ui.C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.45,
		TextWrapped = false,
		Text = "",
	}, marker)
	distanceLabel = Ui.mono({
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = Ui.C.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.45,
		Text = "",
	}, marker)
end

function Waypoint.start()
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = os.clock()
		local busy = LensView.raised or (controllers.Playback and controllers.Playback.active())
		if busy and now < showUntil then
			-- A step that changed during a tape (the usual case: the tape found the seat) keeps
			-- its few seconds for when the picture is the player's again.
			showUntil = math.max(showUntil, now + SHOW_SECONDS)
			stepSince += dt
		end
		if
			target
			and stepId ~= ""
			and now - stepSince > STUCK_AFTER
			and now > showUntil + STUCK_AFTER
		then
			-- Stuck for a while: show the way once more, then let the room have the screen back.
			showUntil = now + SHOW_SECONDS
		end
		local goal = override or (if now < showUntil then target else nil)
		if not goal or not camera or not root or busy then
			marker.Visible = false
			return
		end
		local name = if override then overrideName else targetName
		local distance = (goal - root.Position).Magnitude
		if distance < 8 then
			-- Close enough to see it; the prompt takes over.
			marker.Visible = false
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(goal)
		local size = camera.ViewportSize
		local x, y = point.X, point.Y
		local margin = 64
		if not onScreen or point.Z < 0 then
			-- Behind or beside the camera: pin it to the edge in the target's direction.
			local flat = camera.CFrame:PointToObjectSpace(goal)
			local direction = Vector2.new(flat.X, -flat.Y)
			if direction.Magnitude < 0.001 then
				direction = Vector2.new(0, 1)
			end
			direction = direction.Unit
			local centre = size / 2
			local reach = math.min(
				(centre.X - margin) / math.max(math.abs(direction.X), 0.001),
				(centre.Y - margin) / math.max(math.abs(direction.Y), 0.001)
			)
			x, y = centre.X + direction.X * reach, centre.Y + direction.Y * reach
		else
			x = math.clamp(x, margin, size.X - margin)
			y = math.clamp(y, margin, size.Y - margin)
		end
		-- Fades in over its first half second and out over its last second.
		local alpha = if override then 0 else math.clamp(1 - (showUntil - now), 0, 1)
		alpha = math.max(alpha, math.clamp(1 - (now - (showUntil - SHOW_SECONDS)) * 2, 0, 1))
		marker.Visible = true
		marker.Position = UDim2.fromOffset(x, y - 10)
		diamond.BackgroundTransparency = 0.1 + 0.9 * alpha
		nameLabel.TextTransparency = alpha
		nameLabel.TextStrokeTransparency = 0.45 + 0.55 * alpha
		distanceLabel.TextTransparency = alpha
		distanceLabel.TextStrokeTransparency = 0.45 + 0.55 * alpha
		nameLabel.Text = name
		distanceLabel.Text = string.format("%d m", math.floor(distance * METRES_PER_STUD + 0.5))
	end)
end

return Waypoint
