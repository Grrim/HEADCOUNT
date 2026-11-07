--!strict
-- One binding covers keyboard, mouse, gamepad and an on-screen touch button.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Input = {}

-- The right side of the screen, above the jump button; clear of the thumbstick on the left.
local TOUCH_SLOTS = {
	UDim2.new(1, -190, 1, -190),
	UDim2.new(1, -120, 1, -220),
	UDim2.new(1, -60, 1, -190),
	UDim2.new(1, -190, 1, -120),
	UDim2.new(1, -250, 1, -150),
}

Input.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

function Input.bind(
	name: string,
	onPress: () -> (),
	keys: { Enum.KeyCode | Enum.UserInputType },
	touchTitle: string?,
	touchSlot: number?
)
	local function handler(_, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			onPress()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindAction(name, handler, touchTitle ~= nil, table.unpack(keys))
	if touchTitle then
		ContextActionService:SetTitle(name, touchTitle)
		if touchSlot then
			ContextActionService:SetPosition(name, TOUCH_SLOTS[touchSlot])
		end
	end
end

function Input.unbind(name: string)
	ContextActionService:UnbindAction(name)
end

return Input
