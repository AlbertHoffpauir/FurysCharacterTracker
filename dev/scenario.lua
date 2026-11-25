-- Game mode: what happens while you play. Run after login on the made-up character.
local CT = FurysCharacterTracker
local function Problem(fmt, ...)
    local text = "PLAY: " .. string.format(fmt, ...)
    if not PROBLEMS[text] then PROBLEMS[text] = true; PROBLEMS[#PROBLEMS + 1] = text end
end
local function Check(ok, fmt, ...) if not ok then Problem(fmt, ...) end end
local function P(fmt, ...) UI_OUT[#UI_OUT + 1] = string.format(fmt, ...) end
local id = GAME.id
local function C() return CT.sv.characters[id] end
local function Calls(fn) local before = CALLS; fn(); return CALLS - before end

Check(C() ~= nil, "the character was not read at login")
P("login read: %d game calls", CALLS)

-- One rank up reads the skills again, and nothing else.
CALLED = {}
local n = Calls(function() Fire(EVENT_SKILL_RANK_UPDATE, 2, 1, 5); Advance(3500) end)
P("a rank up: %d game calls", n)
Check(n > 0 and n < 3000, "a rank up cost %d game calls", n)
Check(not CALLED.GetRecipeInfo and not CALLED.GetNextCompletedQuestId and not CALLED.IsSmithingStyleKnown, "a rank up re-read recipes, quests or styles")

-- Twenty recipes learned in a row: one read, 3 seconds after the last.
CALLED = {}
for i = 1, 20 do Fire(EVENT_RECIPE_LEARNED, 1, i); Advance(200) end
Check(not CALLED.GetRecipeInfo, "recipes were read before the events settled")
Advance(3200)
Check((CALLED.GetNumRecipeLists or 0) == 1, "recipes read %s times after 20 events", tostring(CALLED.GetNumRecipeLists))

-- Nothing is read in combat; it happens once the fight is over.
GAME.combat = true
CALLED = {}
Fire(EVENT_RIDING_SKILL_IMPROVEMENT); Advance(10000)
Check(not CALLED.GetRidingStats, "riding was read in combat")
GAME.combat = false
Advance(3100)
Check((CALLED.GetRidingStats or 0) == 1, "riding was not read after combat")

-- Writs: Smith is told apart by what it asks you to make (no English in the quest), Enchanter by
-- its English name, Alchemy is complete. Handing one in marks it done at once.
local D = CT.Daily
local world = CT.view.world
Check(D.State(C(), CRAFTING_TYPE_BLACKSMITHING, world) == D.STARTED, "smith writ state %s", tostring(D.State(C(), CRAFTING_TYPE_BLACKSMITHING, world)))
Check(D.State(C(), CRAFTING_TYPE_ENCHANTING, world) == D.DELIVER, "enchanter writ not at deliver")
Check(D.State(C(), CRAFTING_TYPE_ALCHEMY, world) == D.DELIVER, "alchemy writ (complete, German) not at deliver")
Check(CT.sv.writQuestIds[5368] == CRAFTING_TYPE_BLACKSMITHING, "the smith writ's quest id was not learned")
-- The smith writ is crafted: its steps no longer name a craft, and nothing says "deliver" in English.
GAME.journal[3].craft, GAME.journal[3].conditions = nil, { "Liefert die Waren ab" }
Fire(EVENT_QUEST_ADVANCED, 3); Advance(500)
Check(D.State(C(), CRAFTING_TYPE_BLACKSMITHING, world) == D.DELIVER, "a German smith writ was not seen as ready to hand in")
GAME.journal[3] = nil
Fire(EVENT_QUEST_REMOVED, true, 3, "Schmiedeschrieb", 1, 1, 5368); Advance(500)
Check(D.State(C(), CRAFTING_TYPE_BLACKSMITHING, world) == D.DONE, "handing in the smith writ did not mark it done")
-- An abandoned writ goes back to not taken.
GAME.journal[5] = nil
Fire(EVENT_QUEST_REMOVED, false, 5, "Enchanter Writ", 1, 1, 5400); Advance(500)
Check(D.State(C(), CRAFTING_TYPE_ENCHANTING, world) == D.NONE, "an abandoned writ still shows")
-- Done lasts until the daily reset, then it is a new day.
local reset = D.LastReset(world, GetTimeStamp()) + 86400
Check(D.State(C(), CRAFTING_TYPE_BLACKSMITHING, world, reset - 60) == D.DONE, "done writ gone before the reset")
Check(D.State(C(), CRAFTING_TYPE_BLACKSMITHING, world, reset + 60) == D.NONE, "done writ still done after the reset")

-- Who needs me: the hand-in, the research slots, the bag.
local texts = {}
for _, row in ipairs(CT.Needs.Rows()) do if row.id == id then texts[#texts + 1] = row.text end end
P("needs: %s", table.concat(texts, " | "))
Check(#texts >= 3, "who needs me lists %d things for the test character", #texts)

-- A trial quest finished shows on the Daily tab for a week.
Fire(EVENT_QUEST_COMPLETE, "Assaulting the Citadel^n", 50, 0, 0, 0, QUEST_TYPE_RAID, 0)
local trials = CT.Board.Cell(CT.Trackers.Column("trials"), CT.Roster:Entry(id))
P("trials cell: %s  ·  %s", trials.text, (CT.Board.Tip(CT.Trackers.Column("trials"), CT.Roster:Entry(id)):gsub("\n", " / ")))
Check(trials.text ~= "-", "a finished trial does not show")

-- A companion out: its level and rapport are saved for the account.
GAME.activeCompanion = 2
Fire(EVENT_ACTIVE_COMPANION_STATE_CHANGED, 1, 2); Advance(3500)
local saved = (CT.sv.account.companions or {})["Mirri"] or (CT.sv.account.companions or {})["Mirri Elendis"]
P("companion saved: %s", tostring(saved))
Check(saved ~= nil, "the active companion's level was not saved")

-- Worn gear changes are read; a bag slot change does not read gear.
CALLED = {}
Fire(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, BAG_BACKPACK, 5); Advance(3500)
P("gear cell: %s", CT.Board.Cell(CT.Trackers.Column("wearing"), CT.Roster:Entry(id)).text)

-- Leaving: time played is saved on the way out.
GAME.played = GAME.played + 7200
Fire(EVENT_PLAYER_DEACTIVATED)
Check(C().playedHours == 102, "hours played after logout: %s", tostring(C().playedHours))

-- History: one line per day; a second read the same day replaces it.
local history = CT.sv.history[id]
Check(#history == 1, "history has %d lines after one day", #history)
NOW = NOW + 86400 * 8; BASE_NOW = BASE_NOW + 86400 * 8
GAME.money = GAME.money + 5000
SLASH_COMMANDS["/fct"]("scan")
Check(#CT.sv.history[id] == 2, "history has %d lines after a read 8 days later", #CT.sv.history[id])
local gold7 = CT.Board.Cell(CT.Trackers.Column("delta.gold.7"), CT.Roster:Entry(id))
P("gold 7d: %s  ·  hours 7d: %s  ·  tip: %s", gold7.text, CT.Board.Cell(CT.Trackers.Column("delta.playedHours.7"), CT.Roster:Entry(id)).text,
  (CT.Board.Tip(CT.Trackers.Column("delta.gold.7"), CT.Roster:Entry(id)) or ""):gsub("\n", " / "))
Check(gold7.text == "+5,000", "gold over 7 days shows %s", gold7.text)

-- Skill data not ready at login (the game is still building it): nothing saved is wiped.
local before = C().skillPoints
GAME.skillsReady = false
SLASH_COMMANDS["/fct"]("scan")
Check(C().skillPoints == before, "skill points went from %s to %s while the skill data was not ready", tostring(before), tostring(C().skillPoints))
Check(C().classLines and #C().classLines > 0, "class lines were wiped while the skill data was not ready")
GAME.skillsReady = true

-- Export: a reload is asked for first; the rows have no tabs or line breaks inside a cell.
Click(CT.Window.footer.export)
Check(DIALOG_SHOWN and DIALOG_SHOWN.name == "FURYSCHARACTERTRACKER_EXPORT", "Export to Excel did not ask first")
DIALOGS.FURYSCHARACTERTRACKER_EXPORT.buttons[1].callback()
Check(RELOADS == 1 and CT.sv.exportPending, "the export did not reload")
-- /fct export asks too: nothing reloads the UI without a warning and a way to cancel.
DIALOG_SHOWN = nil
SLASH_COMMANDS["/fct"]("export")
Check(RELOADS == 1, "/fct export reloaded the UI without asking")
Check(DIALOG_SHOWN and DIALOG_SHOWN.name == "FURYSCHARACTERTRACKER_EXPORT", "/fct export did not ask first")
local width
for i, row in ipairs(CT.sv.exportRows) do
    local _, tabs = row:gsub("\t", "")
    width = width or tabs
    Check(tabs == width, "export row %d has %d cells, the header has %d", i, tabs + 1, width + 1)
    Check(not row:find("\n"), "export row %d has a line break", i)
end
P("export: %d rows of %d cells", #CT.sv.exportRows, (width or 0) + 1)
P("export header: %s", (CT.sv.exportRows[1]:gsub("\t", " | ")))

UICheck()
