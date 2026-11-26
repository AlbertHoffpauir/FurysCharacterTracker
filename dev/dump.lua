-- Writes out everything the addon's shared files say should be on screen, for every account in the
-- saved data: every tab with every cell and hover text, the brag card, research timers, who needs
-- me, details pages, Copy for Discord texts and the export rows. The game build (Lua 5.1) and the
-- offline viewer (Fengari, Lua 5.3) run this same file, and the two outputs must be the same text.
local function Ser(value, indent, out)
    local kind = type(value)
    if kind == "table" then
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) == "number"
        end)
        for _, key in ipairs(keys) do
            local item = value[key]
            if type(item) == "table" then
                out[#out + 1] = indent .. tostring(key) .. ":"
                Ser(item, indent .. "  ", out)
            elseif type(item) ~= "function" then
                out[#out + 1] = indent .. tostring(key) .. " = " .. Ser(item)
            end
        end
    elseif kind == "number" then
        if value == math.floor(value) then return string.format("%d", value) end
        return string.format("%.4f", value)
    elseif kind == "string" then
        return (value:gsub("\n", " / "))
    else
        return tostring(value)
    end
end

function FCT_Dump(withStart)
    local CT = FurysCharacterTracker
    local out = {}
    local function P(text) out[#out + 1] = text end
    local function Block(title, value)
        P(title)
        Ser(value, "    ", out)
    end
    local now = GetTimeStamp()
    for _, account in ipairs(CT.Accounts()) do
        CT.SetView(account)
        P("=== account " .. CT.ViewLabel(account))
        for _, view in ipairs(CT.VIEWS) do
            Block("--- view " .. view.id, CT.Board.Snapshot(view.id, true))
            local text, note = CT.Pages.DiscordTable(view.id)
            Block("  discord " .. view.id, { text = text, note = note })
        end
        Block("--- brag", CT.Pages.Brag())
        local rows = CT.Research.Rows(CT.Data(), now)
        local lines = {}
        for i, row in ipairs(rows) do lines[i] = CT.Pages.TimerRow(row, now) end
        Block("--- timers", { summary = CT.Pages.TimersSummary(rows), rows = rows, lines = lines })
        for _, e in ipairs(CT.Roster:List()) do
            local title, subtitle = CT.Pages.DetailsHeader(e)
            Block("--- details " .. e.name, { title = title, subtitle = subtitle, sections = CT.Pages.Details(e) })
            local text, note = CT.Pages.DiscordCharacter(e)
            Block("  discord " .. e.name, { text = text, note = note })
        end
        Block("--- export", CT.Roster:ExportRows())
    end
    if withStart then
        local title, subtitle = CT.Pages.StartHeader()
        Block("--- start", { title = title, subtitle = subtitle, sections = CT.Pages.Start() })
    end
    return table.concat(out, "\n") .. "\n"
end
