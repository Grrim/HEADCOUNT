--!strict
-- The lobby's notebook: where each room is, what a mission asks of you, the controls and the
-- brightness. Opens with J or L1, or the corner tag on a phone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Journal = require(ReplicatedStorage.ClientCommon.Journal)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Strings = require(ReplicatedStorage.Shared.Strings)

local HelpPanel = {}

local CONTROLS = {
	{ "E", "X", "ctl_interact" },
	{ "Q / RMB", "L2", "ctl_lens" },
	{ "J", "L1", "ctl_notes" },
}

local function render(api: Journal.Api)
	api.heading(Strings.get("notes_where"))
	api.line(Strings.get("notes_hub_terminal"), Palette.Crt)
	api.line(Strings.get("notes_hub_tapes"))
	api.line(Strings.get("notes_hub_personnel"))
	api.line(Strings.get("notes_hub_tip"), Palette.WallDark)
	api.heading(Strings.get("notes_controls"))
	api.controls(CONTROLS)
	api.heading(Strings.get("notes_settings"))
	api.brightness()
end

function HelpPanel.init()
	Journal.setup({
		titleKey = "notes_hub_title",
		tagKey = "notes_hub_tag",
		touchKey = "btn_help",
		render = render,
	})
end

return HelpPanel
