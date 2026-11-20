--!strict
-- UsherView (shared with Mission 001) tells the mission's OffFrameView who cut the player. On a
-- shift the server says so itself (the CutBy attribute, shown by ShiftHud), so this only listens.
local OffFrameView = {}

function OffFrameView.setCause(_cause: string) end

return OffFrameView
