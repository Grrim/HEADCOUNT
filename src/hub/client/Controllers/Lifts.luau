--!strict
-- The signs over the two lifts, in this player's language: the solo lift shows your deepest
-- return from the shift, the crew lift who is aboard and when it leaves. The server only sets
-- numbers (HubLifts); the words are written here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Strings = require(ReplicatedStorage.Shared.Strings)

local Lifts = {}

local player = Players.LocalPlayer

local function labelOf(sign: Instance): TextLabel?
	local gui = sign:FindFirstChild("SignGui")
	local label = gui and gui:FindFirstChild("SignText")
	return if label and label:IsA("TextLabel") then label else nil
end

local function renderSolo(sign: Instance)
	local label = labelOf(sign)
	if not label then
		return
	end
	local deepest = player:GetAttribute("ShiftDeepest")
	local record = if typeof(deepest) == "number" and deepest > 0 then `-{deepest}` else "—"
	label.Text = `{Strings.get("lift_solo")}\n{Strings.get("lift_record", record)}`
end

local function renderCrew(sign: Instance)
	local label = labelOf(sign)
	if not label then
		return
	end
	local aboard = sign:GetAttribute("Aboard")
	local leavesIn = sign:GetAttribute("LeavesIn")
	local line = if typeof(aboard) == "number"
			and aboard > 0
			and typeof(leavesIn) == "number"
			and leavesIn >= 0
		then Strings.get("lift_crew_wait", aboard, leavesIn)
		else Strings.get("lift_crew_idle")
	label.Text = `{Strings.get("lift_crew")}\n{line}`
end

function Lifts.start()
	local map = Workspace:WaitForChild("Map")
	local solo = map:WaitForChild("SoloLiftSign", 30)
	local crew = map:WaitForChild("CrewLiftSign", 30)
	if solo then
		renderSolo(solo)
		player:GetAttributeChangedSignal("ShiftDeepest"):Connect(function()
			renderSolo(solo)
		end)
	end
	if crew then
		renderCrew(crew)
		crew.AttributeChanged:Connect(function()
			renderCrew(crew)
		end)
	end
end

return Lifts
