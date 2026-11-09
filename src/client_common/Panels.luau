--!strict
-- Controller support for any pop-up panel. A gamepad has no cursor, so while a panel is open its
-- first button is selected for the D-pad, and B closes it. Mouse and touch are left alone.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Panels = {}

local count = 0
-- The button a panel would rather start on (its main action), when it has one.
local preferredFor: { [GuiObject]: () -> GuiObject? } = {}

local function firstButton(root: Instance): GuiButton?
	for _, item in root:GetDescendants() do
		if item:IsA("GuiButton") and item.Visible and item.Selectable then
			return item
		end
	end
	return nil
end

-- Selects the panel's first button again, for a panel that rebuilds its contents while open.
function Panels.reselect(panel: GuiObject)
	if not panel.Visible or not UserInputService.GamepadEnabled then
		return
	end
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(panel) then
		return
	end
	local prefer = preferredFor[panel]
	local wanted = prefer and prefer()
	if wanted and wanted.Parent and wanted:IsDescendantOf(panel) then
		GuiService.SelectedObject = wanted
	else
		GuiService.SelectedObject = firstButton(panel)
	end
end

-- preferred names the button to land on: a panel that rebuilds itself would otherwise send the
-- selection back to its first button (often Close) every time it redraws.
function Panels.watch(panel: GuiObject, close: (() -> ())?, preferred: (() -> GuiObject?)?)
	if preferred then
		preferredFor[panel] = preferred
	end
	count += 1
	local action = `ClosePanel{count}`
	local function onVisible()
		if panel.Visible then
			ContextActionService:BindActionAtPriority(action, function(_, state)
				if state == Enum.UserInputState.Begin and panel.Visible then
					if close then
						close()
					else
						panel.Visible = false
					end
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.ButtonB)
			-- Rendering may finish a frame later; select once the buttons exist.
			task.defer(Panels.reselect, panel)
		else
			ContextActionService:UnbindAction(action)
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(panel) then
				GuiService.SelectedObject = nil
			end
		end
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(onVisible)
	onVisible()
end

return Panels
