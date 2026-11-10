--!strict
-- One visual language for "this can be used": a small soft diamond floating over every object
-- the player is meant to find and touch (documents, the recorder, the breaker, reels, the bell,
-- the terminal...). It shows from a few steps away, before the prompt itself appears, and goes
-- once the object has been used or switched off. Seats and coat hooks never get one: finding the
-- right seat or coat is the puzzle, and 232 markers would be noise.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Affordance = {}

local SHOW_WITHIN = 22
local SKIP_OBJECTS: { [string]: boolean } = { obj_seat = true, obj_hook = true }
local ACCENT = Color3.fromRGB(182, 214, 150)

type Entry = { prompt: ProximityPrompt, board: BillboardGui, dot: Frame, used: boolean }

local entries: { [ProximityPrompt]: Entry } = {}
local shownPrompts: { [ProximityPrompt]: boolean } = {}

local function adorneeOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent and (parent:IsA("BasePart") or parent:IsA("Attachment") or parent:IsA("Model")) then
		return parent
	end
	return nil
end

local function track(prompt: ProximityPrompt)
	if entries[prompt] or SKIP_OBJECTS[prompt:GetAttribute("ObjectKey") :: any] then
		return
	end
	local adornee = adorneeOf(prompt)
	if not adornee then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "Affordance"
	board.Adornee = adornee
	board.Size = UDim2.fromOffset(18, 18)
	board.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	board.AlwaysOnTop = false
	board.LightInfluence = 0
	board.MaxDistance = SHOW_WITHIN
	board.Enabled = false
	board.ResetOnSpawn = false
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(9, 9)
	dot.Rotation = 45
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = ACCENT
	dot.BackgroundTransparency = 0.25
	dot.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.5
	stroke.Parent = dot
	board.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local entry: Entry = { prompt = prompt, board = board, dot = dot, used = false }
	entries[prompt] = entry
	-- A document read or a reel loaded no longer calls for attention.
	prompt.Triggered:Connect(function()
		local action = prompt:GetAttribute("ActionKey")
		if action == "act_read" or action == "act_read_register" then
			entry.used = true
		end
	end)
	prompt.Destroying:Connect(function()
		board:Destroy()
		entries[prompt] = nil
	end)
end

function Affordance.start()
	for _, item in Workspace:GetDescendants() do
		if item:IsA("ProximityPrompt") then
			task.defer(track, item)
		end
	end
	Workspace.DescendantAdded:Connect(function(item)
		if item:IsA("ProximityPrompt") then
			task.defer(track, item)
		end
	end)
	-- The prompt card replaces the marker once it is up.
	ProximityPromptService.PromptShown:Connect(function(prompt)
		shownPrompts[prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		shownPrompts[prompt] = nil
	end)
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.25 then
			return
		end
		accumulated = 0
		local enabled = ProximityPromptService.Enabled
		for prompt, entry in entries do
			local show = enabled
				and prompt.Enabled
				and not entry.used
				and not shownPrompts[prompt]
				and prompt.Parent ~= nil
			if entry.board.Enabled ~= show then
				entry.board.Enabled = show
				if show then
					entry.dot.Size = UDim2.fromOffset(4, 4)
					TweenService:Create(
						entry.dot,
						TweenInfo.new(0.3, Enum.EasingStyle.Back),
						{ Size = UDim2.fromOffset(9, 9) }
					):Play()
				end
			end
			if show then
				-- A slow breath, so the eye catches it without it ever blinking for attention.
				entry.dot.BackgroundTransparency = 0.25
					+ 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 2.4))
			end
		end
	end)
end

return Affordance
