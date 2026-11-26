-- Game mode only: opens every window for every account and checks that what is on the controls is
-- what Core/Board.lua and Core/Pages.lua said should be there. Also clicks through the menus,
-- sorting, notes, copy windows, the Start here switches and the settings page.
local CT = FurysCharacterTracker
UI_OUT = {}
local function P(fmt, ...) UI_OUT[#UI_OUT + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt end
local function Problem(fmt, ...)
    local text = "UI: " .. string.format(fmt, ...)
    if not PROBLEMS[text] then PROBLEMS[text] = true; PROBLEMS[#PROBLEMS + 1] = text end
end
local function Flat(text) return (tostring(text or ""):gsub("\n", " / ")) end
local function Tip(control)
    TIP = false
    local enter = control.handlers.OnMouseEnter
    if enter then enter(control) end
    local text = TIP or nil
    local exit = control.handlers.OnMouseExit
    if exit then exit(control) end
    return text
end
function Click(control, button)
    local up = control.handlers.OnMouseUp
    if up then return up(control, button or MOUSE_BUTTON_INDEX_LEFT, true) end
    local clicked = control.handlers.OnClicked
    if clicked then return clicked(control, button or MOUSE_BUTTON_INDEX_LEFT) end
    Problem("nothing happens on a click of %s", control.__name)
end
function MenuLabels()
    local labels = {}
    for i, item in ipairs(MENU) do labels[i] = item.label end
    return table.concat(labels, " | ")
end
function MenuPick(label)
    for _, item in ipairs(MENU) do
        if item.label:find(label, 1, true) then return item.fn() end
    end
    Problem("no menu item %s in: %s", label, MenuLabels())
end
local function Same(what, shown, expected)
    if shown ~= expected then Problem("%s shows [%s], expected [%s]", what, Flat(shown), Flat(expected)) end
end
local function NoIcon(text) return (tostring(text):gsub("^|t[^|]*|t ", "")) end

function CheckBoard(viewId)
    local win = CT.Window
    win:Show(viewId)
    local snap = CT.Board.Snapshot(viewId, true)
    local where = CT.ViewLabel() .. " " .. viewId
    Same(where .. " summary", FurysCharacterTracker_WindowSummary.text, snap.summary)
    local x = 6
    for i, label in ipairs(win.headers) do
        local column = snap.columns[i]
        if (column == nil) ~= label.hidden then Problem("%s header %d hidden=%s", where, i, tostring(label.hidden)) end
        if column then
            Same(where .. " header " .. i, (label.text:gsub(" |t.*$", "")), column.title)
            Same(where .. " header tip " .. i, Tip(label), column.head)
            x = x + column.width + 6
        end
    end
    if x - 6 > 1368 then Problem("%s is %d px wide, the row has 1368", where, x - 6) end
    local rows = FurysCharacterTracker_WindowList.rows or {}
    if #rows ~= #snap.rows + #snap.unread then Problem("%s has %d rows, expected %d", where, #rows, #snap.rows + #snap.unread) end
    for r, row in ipairs(snap.rows) do
        local control = rows[r]
        for i, cell in ipairs(row.cells) do
            local shown = control.cells[i]
            local what = string.format("%s row %d (%s) cell %d (%s)", where, r, row.name, i, snap.columns[i].key)
            Same(what, NoIcon(shown.label.text), cell.text)
            Same(what .. " tip", Tip(shown.label), cell.tip)
            if shown.tile.hidden == cell.maxed then Problem("%s tile hidden=%s but maxed=%s", what, tostring(shown.tile.hidden), tostring(cell.maxed)) end
            if shown.bar.hidden ~= (cell.pct == nil) then Problem("%s bar hidden=%s but pct=%s", what, tostring(shown.bar.hidden), tostring(cell.pct)) end
        end
        for i = #row.cells + 1, #control.cells do
            if not control.cells[i].label.hidden then Problem("%s row %d has a stray cell %d", where, r, i) end
        end
    end
    for r, info in ipairs(snap.unread) do
        local control = rows[#snap.rows + r]
        Same(where .. " unread " .. r, control.cells[1].label.text, info.name)
        Same(where .. " unread tip " .. r, Tip(control.cells[1].label), info.tip)
        Same(where .. " unread text " .. r, control.cells[3].label.text, CT.TEXT.UNREAD)
    end
    for i, text in ipairs(snap.totals) do
        Same(where .. " total " .. i, FurysCharacterTracker_WindowTotals.cells[i].label.text, text)
    end
end

local function Labels(prefix, title)
    local names = {}
    for name, c in pairs(CONTROLS) do
        if name:sub(1, #prefix) == prefix and c.text ~= "" and not c.hidden then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        local na, nb = tonumber(a:match("(%d+)$")), tonumber(b:match("(%d+)$"))
        if na and nb and a:gsub("%d+$", "") == b:gsub("%d+$", "") then return na < nb end
        return a < b
    end)
    P("  [%s]", title)
    for _, name in ipairs(names) do P("    %s = %s", name:sub(#prefix + 1), Flat(CONTROLS[name].text)) end
end

function UICheck()
    local alertResearch, alertRiding = CT.sv.alertResearch, CT.sv.alertRiding   -- put back at the end
    local win = CT.Window
    for _, account in ipairs(CT.Accounts()) do
        CT.SetView(account)
        P("=== account %s", CT.ViewLabel(account))
        for _, view in ipairs(CT.VIEWS) do CheckBoard(view.id) end
        win:Show("overview")
        Labels("FurysCharacterTracker_Window", "board")
        CT.Brag:Show()
        Labels("FurysCharacterTracker_Brag", "brag")
        local card = CT.Pages.Brag()
        Same("brag title", FurysCharacterTracker_BragTitle.text, card.title)
        for i, tile in ipairs(card.tiles) do Same("brag tile " .. i, CT.Brag.tiles[i].value.text, tile.value) end
        CT.Brag:Hide()
        CT.Timers:Show()
        P("  [timers] %s", FurysCharacterTracker_TimersSummary.text)
        for r, row in ipairs(FurysCharacterTracker_TimersList.rows or {}) do
            local c = row.children
            P("    %s | %s | %s | %s | %s | %s", c.Name.text, c.Craft.text, c.Item.text, c.Trait.text, c.Left.text, c.Ends.text)
        end
        CT.Timers:Hide()
        for _, e in ipairs(CT.Roster:List()) do
            CT.Details:Show(e.id)
            Same("details title", FurysCharacterTracker_DetailsTitle.text, e.name)
            local shownLabels, expected = 0, 0
            for _, label in ipairs(CT.Details.labels) do if not label.hidden then shownLabels = shownLabels + 1 end end
            for _, section in ipairs(CT.Pages.Details(e)) do expected = expected + 1 + 2 * #(section.items or {}) + #(section.lines or {}) end
            if shownLabels ~= expected then Problem("details of %s shows %d labels, expected %d", e.name, shownLabels, expected) end
        end
        CT.Details:Hide()
    end
    CT.SetView(CT.home)

    -- Sorting: three clicks on a column title go sorted, reversed, back to your own order.
    win:Show("overview")
    local own = CT.Board.Snapshot("overview").rows
    local header = win.headers[5]
    Click(header); CheckBoard("overview")
    local sorted = CT.Board.Snapshot("overview")
    if not sorted.sortKey then Problem("a click on a column title did not sort") end
    Click(win.headers[5]); CheckBoard("overview")
    Click(win.headers[5]); CheckBoard("overview")
    local back = CT.Board.Snapshot("overview")
    if back.sortKey then Problem("the third click did not go back to your own order") end
    for r, row in ipairs(own) do if back.rows[r].id ~= row.id then Problem("own order changed after sorting") break end end

    -- Row menu: move, note, copy, remove, show removed.
    local rows = FurysCharacterTracker_WindowList.rows or {}
    if rows[1] and #own >= 2 then
        local first, second = own[1], own[2]
        Click(rows[1].cells[3].label, MOUSE_BUTTON_INDEX_RIGHT)
        P("  [row menu] %s", MenuLabels())
        MenuPick("Move down")
        local moved = CT.Board.Snapshot("overview").rows
        if moved[1].id ~= second.id or moved[2].id ~= first.id then Problem("Move down did not swap the first two rows") end
        Click(FurysCharacterTracker_WindowList.rows[2].cells[3].label, MOUSE_BUTTON_INDEX_RIGHT)
        MenuPick("Move to the top")
        if CT.Board.Snapshot("overview").rows[1].id ~= first.id then Problem("Move to the top did not") end

        Click(FurysCharacterTracker_WindowList.rows[1].cells[3].label, MOUSE_BUTTON_INDEX_RIGHT)
        MenuPick("note")
        if FurysCharacterTracker_Text.hidden then Problem("the note window did not open") end
        P("  [note window] %s  ·  %s", FurysCharacterTracker_TextTitle.text, FurysCharacterTracker_TextHint.text)
        FurysCharacterTracker_TextEditBox.text = "  healer for  \n trials  "
        Click(CT.TextWindow.save)
        Same("saved note", CT.Roster:Entry(first.id).m.note, "healer for trials")
        if not FurysCharacterTracker_Text.hidden then Problem("the note window stayed open after Save") end
        CheckBoard("sets")
        win:Show("overview")

        Click(FurysCharacterTracker_WindowList.rows[1].cells[3].label, MOUSE_BUTTON_INDEX_RIGHT)
        MenuPick("for Discord")
        P("  [copy one] %s", Flat(FurysCharacterTracker_TextEditBox.text))
        if not FurysCharacterTracker_TextEditBox.selected then Problem("the copy text was not selected") end
        CT.TextWindow:Hide()
        Click(win.footer.copy)
        P("  [copy tab] %s  ·  %s", FurysCharacterTracker_TextHint.text, Flat(FurysCharacterTracker_TextEditBox.text))
        CT.TextWindow:Hide()

        Click(FurysCharacterTracker_WindowList.rows[1].cells[3].label, MOUSE_BUTTON_INDEX_RIGHT)
        MenuPick("Remove")
        if #CT.Board.Snapshot("overview").rows ~= #own - 1 then Problem("Remove did not take the row off") end
        if win.footer.removed.hidden then Problem("Show removed is hidden while a character is removed") end
        Click(win.footer.removed)
        if #CT.Board.Snapshot("overview").rows ~= #own then Problem("Show removed did not bring the row back") end
        if not win.footer.removed.hidden then Problem("Show removed is still there with nothing removed") end
        CT.Roster:SetManual(first.id, "note", "")
    end

    -- Picks: a click on a pick cell opens its dropdown.
    win:Show("sets")
    rows = FurysCharacterTracker_WindowList.rows or {}
    for i, column in ipairs(CT.Board.Snapshot("sets").columns) do
        if rows[1] and column.pick then
            ClearMenu()
            Click(rows[1].cells[i].label)
            P("  [pick menu %s] %s", column.key, MenuLabels())
            if #MENU == 0 then Problem("no dropdown for the pick column %s", column.key) end
        end
    end

    -- Every footer button and the buttons at the top have a hover text.
    for id, button in pairs(win.footer) do
        if not Tip(button) then Problem("footer button %s has no hover text", id) end
    end
    for _, name in ipairs({ "FurysCharacterTracker_WindowStartHere", "FurysCharacterTracker_WindowSettings", "FurysCharacterTracker_WindowAccount" }) do
        if not Tip(CONTROLS[name]) then Problem("%s has no hover text", name) end
    end
    for i, tab in ipairs(win.tabs) do
        if not Tip(tab.label) then Problem("tab %d has no hover text", i) end
        Click(tab.label)
        if CT.Prefs().lastView ~= tab.view.id then Problem("a click on tab %s did not open it", tab.view.id) end
    end
    Click(win.accountButton)
    P("  [account menu] %s", MenuLabels())

    -- Start here: the switches flip when clicked.
    CT.Details:ShowStart()
    Labels("FurysCharacterTracker_Details", "start here")
    local flipped = 0
    for _, label in ipairs(CT.Details.labels) do
        if not label.hidden and label.text:find("Research finished", 1, true) and label.handlers.OnMouseUp then
            local before = CT.sv.alertResearch
            Click(label)
            if CT.sv.alertResearch == before then Problem("the Start here switch did not flip") end
            Click(CT.Details.labels[1].handlers.OnMouseUp and CT.Details.labels[1] or label)
            flipped = flipped + 1
            break
        end
    end
    if flipped == 0 then Problem("no switch found on the Start here page") end
    CT.sv.alertResearch = alertResearch
    CT.Details:Hide()

    -- Settings page: every control has a name, checkboxes read and write.
    for i, option in ipairs(LAM_OPTIONS) do
        if option.type == "checkbox" then
            local before = option.getFunc()
            option.setFunc(not before)
            if option.getFunc() == before then Problem("settings checkbox %s does not change", option.name) end
            option.setFunc(before)
        end
        if (option.type == "checkbox" or option.type == "button") and not option.tooltip then Problem("settings %s has no hover text", option.name) end
        P("  [settings] %s %s", option.type, Flat(option.name or option.text))
    end
    CT.Settings:Open()
    for _, window in ipairs(CT.Windows()) do
        if not window[1].hidden then Problem("%s stayed open over the settings page", window[1].__name) end
    end

    -- Slash commands.
    for _, command in ipairs({ "", "brag", "timers", "todo", "unread", "research", "start", "ids", "scan", "alerts on", "alerts off", "nonsense", "class", "wallet" }) do
        SLASH_COMMANDS["/fct"](command)
    end
    for _, window in ipairs(CT.Windows()) do
        if not window[1].hidden then SCENE_MANAGER:HideTopLevel(window[1]) end
    end
    CT.sv.alertResearch, CT.sv.alertRiding = alertResearch, alertRiding
end

-- Every tab as one line per character, in the layout the 1.4.1 dump used, for compare.py.
function FCT_BoardLines()
    local out = {}
    local function Add(fmt, ...) out[#out + 1] = string.format(fmt, ...) end
    for _, account in ipairs(CT.Accounts()) do
        CT.SetView(account)
        Add("=== account %s", CT.ViewLabel(account))
        for _, view in ipairs(CT.VIEWS) do
            local snap = CT.Board.Snapshot(view.id)
            Add("--- view %s (%s)", snap.id, snap.title)
            Add("  summary: %s", snap.summary)
            local titles = {}
            for i, column in ipairs(snap.columns) do titles[i] = column.title end
            Add("  head: %s", table.concat(titles, " | "))
            for r, row in ipairs(snap.rows) do
                local cells = {}
                for i, cell in ipairs(row.cells) do cells[i] = (cell.maxed and "*" or "") .. cell.text end
                Add("  row %d: %s", r, table.concat(cells, " | "))
            end
            Add("  totals: %s", table.concat(snap.totals, " | "))
        end
    end
    CT.SetView(CT.home)
    return table.concat(out, "\n") .. "\n"
end
