--!strict
-- Prompts are created on the server with string keys. Each client fills in its own language.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Strings = require(ReplicatedStorage.Shared.Strings)

local PromptText = {}

local function apply(prompt: ProximityPrompt)
	local actionKey = prompt:GetAttribute("ActionKey")
	if typeof(actionKey) == "string" then
		prompt.ActionText = Strings.get(actionKey)
	end
	local objectKey = prompt:GetAttribute("ObjectKey")
	if typeof(objectKey) == "string" then
		local suffix = prompt:GetAttribute("ObjectSuffix")
		local name = Strings.get(objectKey)
		prompt.ObjectText = if typeof(suffix) == "string" and suffix ~= ""
			then `{name} {suffix}`
			else name
	end
end

function PromptText.start()
	for _, item in Workspace:GetDescendants() do
		if item:IsA("ProximityPrompt") then
			apply(item)
		end
	end
	Workspace.DescendantAdded:Connect(function(item)
		if item:IsA("ProximityPrompt") then
			task.defer(apply, item)
		end
	end)
end

return PromptText
