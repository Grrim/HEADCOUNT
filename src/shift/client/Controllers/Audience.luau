--!strict
-- RegistrarView (shared with Mission 001) asks the Audience controller whether the climax is on
-- or the local player is cut out of frame. A shift has no audience; this answers for it.
local Audience = {}

Audience.climax = false
Audience.offFrame = false

function Audience.refresh() end

return Audience
