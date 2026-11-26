-- The offline viewer's Lua side. The page asks for what to draw with FCT_Api("board", "overview")
-- and gets JSON back. Everything it hands out comes from the addon's own files (Core/Board.lua,
-- Core/Pages.lua and the files in Trackers/), so the page shows what the game shows.
local CT = FurysCharacterTracker
local accounts = {}
local api = {}

-- Details and Start here pages mix lists with named fields; the page wants plain objects.
local function Page(title, subtitle, sections)
    local out = { title = title, subtitle = subtitle, sections = {} }
    for s, section in ipairs(sections) do
        local items, lines = {}, {}
        for i, item in ipairs(section.items or {}) do
            items[i] = { key = item[1], value = tostring(item[2] or ""), done = item.done == true, dim = item.dim == true }
        end
        for i, line in ipairs(section.lines or {}) do
            if type(line) ~= "table" then line = { line } end
            lines[i] = { text = line[1], bold = line.bold == true, gold = line.gold == true, url = line.url and CT.toolsUrl or nil }
        end
        out.sections[s] = { title = section.title, items = items, lines = lines }
    end
    return out
end

-- Called once, after the saved files are in.
function api.boot()
    CT.UpgradeAll()
    accounts = CT.Accounts()
    CT.view = accounts[1]
    local labels, views = {}, {}
    for i, account in ipairs(accounts) do labels[i] = CT.ViewLabel(account) end
    for i, view in ipairs(CT.VIEWS) do views[i] = { id = view.id, title = view.title, tip = view.tip or "" } end
    local X = CT.TEXT
    return { version = CT.version, accounts = labels, views = views, legend = X.LEGEND, unread = X.UNREAD, footer = X.FOOTER,
             startTip = X.START_TIP, accountTip = X.ACCOUNT_TIP, toolsUrl = CT.toolsUrl }
end

function api.account(index)
    CT.SetView(accounts[tonumber(index)])
    return true
end

function api.board(viewId)
    local snap = CT.Board.Snapshot(viewId, true)
    CT.Prefs().lastView = snap.id
    snap.label = CT.ViewLabel()
    return snap
end

function api.sort(viewId, key)
    CT.Board.ClickSort(CT.Board.View(viewId), CT.Trackers.Column(key))
    return true
end

function api.details(id)
    local e = CT.Roster:Entry(id)
    if not e then return false end
    local title, subtitle = CT.Pages.DetailsHeader(e)
    return Page(title, subtitle, CT.Pages.Details(e))
end

function api.start()
    local title, subtitle = CT.Pages.StartHeader()
    return Page(title, subtitle, CT.Pages.Start())
end

function api.brag()
    return CT.Pages.Brag()
end

function api.timers()
    local now = GetTimeStamp()
    local rows, lines = CT.Research.Rows(CT.Data(), now), {}
    for i, row in ipairs(rows) do lines[i] = CT.Pages.TimerRow(row, now) end
    return { label = CT.ViewLabel(), summary = CT.Pages.TimersSummary(rows), rows = lines }
end

function api.discord(viewId)
    local text, note = CT.Pages.DiscordTable(viewId)
    return { text = text, note = note }
end

function api.discordCharacter(id)
    local e = CT.Roster:Entry(id)
    if not e then return false end
    local text, note = CT.Pages.DiscordCharacter(e)
    return { text = text, note = note }
end

-- The rows of the Excel file: the same columns the game's own export writes.
function api.export()
    return { label = CT.ViewLabel(), rows = CT.Roster:ExportRows() }
end

function FCT_Api(name, a, b)
    return FCT_Json(api[name](a, b))
end
