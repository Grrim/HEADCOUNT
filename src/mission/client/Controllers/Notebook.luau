--!strict
-- The field notebook and the "next" line on the objective card. Both come from what this player
-- actually knows: their own tapes, the cards they have read, what the team has called out. When a
-- player stays on one step for too long, the radio spells it out once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioDirector = require(ReplicatedStorage.ClientCommon.AudioDirector)
local Config = require(ReplicatedStorage.Shared.Config.Game)
local Guide = require(ReplicatedStorage.Shared.Core.Guide)
local Journal = require(ReplicatedStorage.ClientCommon.Journal)
local LensView = require(ReplicatedStorage.ClientCommon.LensView)
local Net = require(ReplicatedStorage.Shared.Net)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Puzzle = require(ReplicatedStorage.Shared.Core.Puzzle)
local Seats = require(ReplicatedStorage.Shared.Core.Seats)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Notebook = {}

local CONTROLS = {
	{ "E", "X", "ctl_interact" },
	{ "Q / RMB", "L2", "ctl_lens" },
	{ "R", "R2", "ctl_rec" },
	{ "T", "Y", "ctl_play" },
	{ "F", "D-pad up", "ctl_light" },
	{ "1-4", "D-pad, B", "ctl_radio" },
	{ "K", "X", "ctl_knock" },
	{ "J", "L1", "ctl_notes" },
	{ "X", "B", "ctl_close" },
}

local controllers: { [string]: any }
local state: any = nil
local ended = false
local tapesLeft = Config.Tape.PerPlayer
local tapesSaved = 0
local latestId: number? = nil
local watched: { [number]: boolean } = {}
-- Tape id -> rows where someone turned round on it (empty: nobody did).
local tapeRows: { [number]: { string } } = {}
local seenSeats: { [string]: boolean } = {}
local foundSeats: { [string]: number } = {}
local foundOrder: { string } = {}
local reelsFound: { { any } } = {}
local searched: { [number]: boolean } = {}
local dealt = 0
local seenCode: { [number]: number } = {}
local order: string? = nil
local docs: { string } = {}
local docSet: { [string]: boolean } = {}
local registerNames: { string }? = nil
local current: Guide.Step? = nil
local currentText = ""
local stepId = ""
local stepSince = 0
local nudged: { [string]: boolean } = {}
-- Rules of the place, in the order the player ran into them. The first is known from the start.
local rules: { string } = { "rule_tape" }
local ruleSet: { [string]: boolean } = { rule_tape = true }

local function rowsOf(seatIds: { number }): { string }
	local set: { [string]: boolean } = {}
	for _, seatId in seatIds do
		local row = Seats.fromId(seatId)
		set[Seats.rowLetter(row)] = true
	end
	local rows = {}
	for row in set do
		table.insert(rows, row)
	end
	table.sort(rows)
	return rows
end

local function pendingRows(): { string }
	local set: { [string]: boolean } = {}
	for label in seenSeats do
		if not foundSeats[label] then
			set[label:sub(1, 1)] = true
		end
	end
	local rows = {}
	for row in set do
		table.insert(rows, row)
	end
	table.sort(rows)
	return rows
end

local function pendingTags(): { number }
	local tags = {}
	for _, tag in (state and state.tags or {}) :: { number } do
		if not searched[tag] then
			table.insert(tags, tag)
		end
	end
	return tags
end

local function facts(): Guide.Facts
	return {
		phase = if state then state.phase else "Waiting",
		pendingTags = pendingTags(),
		pendingRows = pendingRows(),
		reels = if state then state.reels else 0,
		tapesSaved = tapesSaved,
		latestWatched = latestId == nil or watched[latestId] == true,
		tapesLeft = tapesLeft,
		code = seenCode,
		codeLength = Puzzle.CODE_LENGTH,
		dealt = dealt,
		order = order,
		doorSide = if state then state.doorSide else nil,
	}
end

local function textOf(key: string, args: { any }): string
	return Strings.get(key, table.unpack(args))
end

local function update()
	local step = if ended then nil else Guide.step(facts(), Strings.get)
	current = step
	currentText = if step then textOf(step.key, step.args) else ""
	controllers.Hud.setStep(currentText)
	local id = Guide.id(step)
	if id ~= stepId then
		stepId = id
		stepSince = os.clock()
	end
	Journal.refresh()
end

local function render(api: Journal.Api)
	api.heading(Strings.get("hud_objective"))
	api.line(if state then Strings.get(state.objective) else Strings.get("obj_waiting"))
	if state and state.condition and state.condition ~= "standard" then
		api.line(
			Strings.get("notes_tonight", Strings.get(`condname_{state.condition}`)),
			Palette.Rec
		)
		api.line(Strings.get(`conddesc_{state.condition}`), Palette.WallDark)
	end
	if currentText ~= "" then
		api.heading(Strings.get("hud_next"))
		api.line(currentText, Palette.Crt)
	end

	api.heading(Strings.get("notes_clues"))
	api.line(Strings.get("notes_tapes", tapesLeft))
	local logged = controllers.OmenDirector.loggedCount()
	if logged > 0 then
		api.line(Strings.get("notes_anomalies", logged), Palette.Crt)
	end
	local any = false
	for id = 1, tapesSaved do
		local rows = tapeRows[id]
		if rows then
			any = true
			if #rows > 0 then
				api.line(Strings.get("notes_tape_rows", id, table.concat(rows, ", ")))
			else
				api.line(Strings.get("notes_tape_none", id), Palette.WallDark)
			end
		end
	end
	for _, label in foundOrder do
		any = true
		api.line(Strings.get("notes_seat", label, foundSeats[label]))
	end
	for _, reel in reelsFound do
		any = true
		api.line(Strings.get("notes_reel", reel[1], reel[2]))
	end
	if next(seenCode) ~= nil then
		any = true
		api.line(Strings.get("notes_code", Guide.codeText(seenCode, Puzzle.CODE_LENGTH)))
	end
	if order then
		any = true
		api.line(Strings.get("notes_order", order))
	end
	if state and state.doorSide then
		any = true
		api.line(Strings.get("notes_door", Strings.get(Guide.sideKey(state.doorSide))))
	end
	if not any then
		api.line(Strings.get("notes_none"), Palette.WallDark)
	end

	api.heading(Strings.get("notes_rules"))
	for _, rule in rules do
		api.line(`- {Strings.get(rule)}`)
	end

	if #docs > 0 or registerNames then
		api.heading(Strings.get("notes_docs"))
		for _, docId in docs do
			api.button(`  {Strings.get(`{docId}_title`)}`, function()
				Journal.close()
				controllers.Hud.showDoc(docId)
			end)
		end
		local names = registerNames
		if names then
			api.button(`  {Strings.get("register_title")}`, function()
				Journal.close()
				controllers.Hud.showRegister(names)
			end)
		end
	end

	api.heading(Strings.get("notes_controls"))
	api.controls(CONTROLS)
	api.heading(Strings.get("notes_settings"))
	api.brightness()
end

local function learn(rule: string)
	if ruleSet[rule] then
		return
	end
	ruleSet[rule] = true
	table.insert(rules, rule)
	Journal.ping()
	Journal.refresh()
end

local function isCut(): boolean
	return Players.LocalPlayer:GetAttribute("OffFrame") == true
end

local function syncTag()
	Journal.setTagVisible(not ended and not LensView.raised and not controllers.Playback.active())
end

-- Once per step, after the step's own patience runs out, the radio says it plainly.
local function nudgeLoop()
	while true do
		task.wait(2)
		local step = current
		if
			step
			and not nudged[stepId]
			and os.clock() - stepSince >= step.nudgeAfter
			and not controllers.Playback.active()
			and not Journal.isOpen()
			and not isCut()
		then
			nudged[stepId] = true
			AudioDirector.play("Radio", 0.35)
			controllers.Hud.subtitle(textOf(step.nudge, step.nudgeArgs), 8)
		end
	end
end

function Notebook.init(all: { [string]: any })
	controllers = all
	Journal.setup({
		titleKey = "notes_title",
		tagKey = "notes_tag",
		touchKey = "btn_notes",
		render = render,
		canOpen = function()
			return not ended and not controllers.Playback.active()
		end,
	})
end

function Notebook.start()
	Net.get("SessionState").OnClientEvent:Connect(function(newState)
		state = newState
		if newState.phase == "Done" or newState.phase == "Failed" then
			ended = true
			Journal.close()
			syncTag()
		end
		update()
	end)
	Net.get("TapeList").OnClientEvent:Connect(function(list)
		tapesLeft = list.left
		tapesSaved = list.count
		latestId = list.latestId
		update()
	end)
	Net.get("TapePlay").OnClientEvent:Connect(function(clip)
		Journal.close()
		syncTag()
		if clip.archiveOrder then
			order = clip.archiveOrder
		elseif clip.id > 0 then
			watched[clip.id] = true
			tapeRows[clip.id] = rowsOf(clip.seats)
			for _, seatId in clip.seats do
				seenSeats[Seats.label(seatId)] = true
			end
		end
		update()
	end)
	controllers.Playback.onStopped(function(clip)
		syncTag()
		-- Say what the tape showed while it is still fresh, so nobody has to rewatch it.
		if clip then
			Journal.ping()
			learn("rule_replay")
		end
		if clip and clip.id > 0 and state and state.phase == "Protocol" then
			local rows = rowsOf(clip.seats)
			if #rows > 0 then
				controllers.Hud.subtitle(Strings.get("playback_rows", table.concat(rows, ", ")), 6)
			else
				controllers.Hud.subtitle(Strings.get("playback_none"), 6)
			end
		end
	end)
	Net.get("Notify").OnClientEvent:Connect(function(key: string, a: any, b: any)
		if key == "seat_found" and typeof(b) == "string" then
			if not foundSeats[b] then
				table.insert(foundOrder, b)
			end
			foundSeats[b] = a
			-- A teammate found it: it is no longer a lead on anyone's tape.
			seenSeats[b] = true
		elseif key == "hook_found" and typeof(b) == "number" then
			searched[b] = true
			table.insert(reelsFound, { a, b })
		else
			return
		end
		Journal.ping()
		update()
	end)
	Net.get("CodeDigits").OnClientEvent:Connect(function(hand: { [string]: number })
		dealt = 0
		for _ in hand do
			dealt += 1
		end
		-- A changed team reshuffles the cards: keep only what still matches this hand.
		for position, digit in seenCode do
			if hand[tostring(position)] ~= digit then
				seenCode[position] = nil
			end
		end
		update()
	end)
	controllers.CodeCards.onSeen(function(position: number, digit: number)
		if seenCode[position] ~= digit then
			seenCode[position] = digit
			Journal.ping()
			update()
		end
	end)
	Net.get("DocShown").OnClientEvent:Connect(function(docId: string)
		-- The register has its own entry, with the names written in.
		if not docSet[docId] and docId ~= "doc_register" then
			docSet[docId] = true
			table.insert(docs, docId)
			Journal.ping()
			Journal.refresh()
		end
	end)
	Net.get("RegisterShown").OnClientEvent:Connect(function(names: { string })
		registerNames = names
		Journal.ping()
		Journal.refresh()
	end)
	Net.get("EndMission").OnClientEvent:Connect(function()
		ended = true
		Journal.close()
		syncTag()
		update()
	end)
	-- What the Registrar does is learned by meeting it, and written down the first time.
	Net.get("RegistrarEvent").OnClientEvent:Connect(function(kind: string)
		if kind == "preJump" or kind == "jump" then
			learn("rule_silence")
			if controllers.VoiceListener.available() then
				learn("rule_voice")
			end
		elseif kind == "exposure" then
			learn("rule_exposure")
		elseif kind == "reach" then
			learn("rule_reach")
		elseif kind == "cut" then
			learn("rule_cut")
		end
	end)
	controllers.OmenDirector.onLogged(function()
		learn("rule_anomaly")
		Journal.ping()
		Journal.refresh()
	end)
	controllers.VoiceListener.onAvailable(function()
		-- Only worth knowing for someone the building can hear.
		if ruleSet.rule_silence then
			learn("rule_voice")
		end
	end)
	LensView.onChanged(syncTag)
	syncTag()
	update()
	nudgeLoop()
end

return Notebook
