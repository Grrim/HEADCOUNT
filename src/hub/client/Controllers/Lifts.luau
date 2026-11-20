--!strict
-- The signs over the two lifts, in this player's language: the solo lift shows your deepest
-- return from the shift, the crew lift who is aboard and when it leaves. Above them, the records
-- board's headings, and this player's own line lit up if they made the list. The servers only set
-- numbers and names (HubLifts, HubRecords); the words are written here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
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

local AMBER = Color3.fromRGB(240, 186, 92)
local NOTES = { loading = "records_loading", empty = "records_empty", offline = "records_offline" }

local function renderRecords(board: Instance)
	local gui = board:FindFirstChild("RecordsGui")
	if not gui then
		return
	end
	local function text(name: string): TextLabel?
		local found = gui:FindFirstChild(name)
		return if found and found:IsA("TextLabel") then found else nil
	end
	local title, columns, note = text("RecordsTitle"), text("RecordsColumns"), text("RecordsNote")
	if title then
		title.Text = Strings.get("records_title")
	end
	if columns then
		columns.Text = Strings.get("records_columns")
	end
	local state = board:GetAttribute("State")
	if note then
		local key = if typeof(state) == "string" then NOTES[state] else nil
		note.Text = if key then Strings.get(key) else ""
	end
	for _, row in gui:GetChildren() do
		if row:IsA("TextLabel") and string.sub(row.Name, 1, 3) == "Row" then
			row.TextColor3 = if row:GetAttribute("UserId") == player.UserId
				then Palette.Paper
				else AMBER
		end
	end
end

-- The rows change once a minute at most; a check every second is plenty and never misses a row
-- that arrived after the board.
local function watchRecords(board: Instance)
	while board.Parent do
		renderRecords(board)
		task.wait(1)
	end
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
	task.spawn(function()
		local records = map:WaitForChild("RecordsBoard", 60)
		if records then
			watchRecords(records)
		end
	end)
	if crew then
		renderCrew(crew)
		crew.AttributeChanged:Connect(function()
			renderCrew(crew)
		end)
	end
end

return Lifts
