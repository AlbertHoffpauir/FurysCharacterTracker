-- This addon's tiles in Fury's Command Center (an optional addon): daily crafting writs still
-- open on your characters, and the account's daily endeavors still to do. The Command Center
-- counts them every few seconds and shows them on its strip and on this addon's card.
-- Without the Command Center installed, nothing here runs.
local CT = FurysCharacterTracker
if not FurysCommandCenter then return end
local CC = FurysCommandCenter
local U = CT.Util
local Daily = CT.Daily
local ADDON = CT.Theme.MENU_NAME

local RECENT_DAYS = 14   -- a craft counts for a character when it did that writ in the last two weeks

local function Plural(n, one, many) return n == 1 and one or many end

------------------------------------------------------------------------------
-- D2a: writs open today. A character's writs count for the crafts it did in the last two weeks
-- (the same rule the Daily tab uses), and only on the account you are logged in on.
------------------------------------------------------------------------------
local function OpenWrits()
    local list, total = {}, 0
    if not CT.sv then return list, total end
    local now = GetTimeStamp()
    local world = CT.home and CT.home.world
    local since = now - RECENT_DAYS * 86400
    for _, e in ipairs(CT.Roster:List(nil, nil, CT.sv)) do
        local open = {}
        for _, def in ipairs(Daily.CRAFTS) do
            local entry = (e.c.writs or {})[def.craft]
            if entry and (entry.at or 0) >= since and Daily.State(e.c, def.craft, world, now) ~= Daily.DONE then
                open[#open + 1] = def.short
            end
        end
        if #open > 0 then
            list[#list + 1] = { name = e.name, crafts = open }
            total = total + #open
        end
    end
    return list, total
end

CC:RegisterTile({
    id = "FurysCharacterTracker.writs",
    addon = ADDON,
    name = "Writs open today",
    glyph = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds",
    essential = true,
    order = 10,
    count = function() return select(2, OpenWrits()), "warn" end,
    line = function()
        local list, total = OpenWrits()
        if total == 0 then return "All writs done today" end
        return string.format("%d %s open on %d %s", total, Plural(total, "writ", "writs"), #list, Plural(#list, "character", "characters"))
    end,
    tip = function()
        local list = OpenWrits()
        if #list == 0 then return "Daily crafting writs not done yet today, for the crafts each character did in the last two weeks. None right now." end
        local lines = { "Writs not done yet today:" }
        for _, row in ipairs(list) do lines[#lines + 1] = row.name .. ": " .. table.concat(row.crafts, ", ") end
        lines[#lines + 1] = "Click to open the Daily tab."
        return table.concat(lines, "\n")
    end,
    open = function() CT.Window:Show("daily") end,
})

------------------------------------------------------------------------------
-- D2b: the account's daily endeavors still to do today
------------------------------------------------------------------------------
-- done, total, or nil when never read / reset since the last read.
local function Endeavors()
    local saved = CT.sv and (CT.sv.account or {}).challenges
    if not saved then return nil end
    local p = U.Split(saved.daily or "", ";")
    local done, total, resetAt = tonumber(p[1]), tonumber(p[2]), tonumber(p[3]) or 0
    if not total or total == 0 then return nil end
    if resetAt > 0 and resetAt <= GetTimeStamp() then return nil end
    return done, total
end

CC:RegisterTile({
    id = "FurysCharacterTracker.dailies",
    addon = ADDON,
    name = "Daily endeavors left",
    glyph = "EsoUI/Art/MainMenu/menuBar_journal_up.dds",
    essential = true,
    order = 20,
    count = function()
        local done, total = Endeavors()
        if not done then return 0 end
        return total - done, "warn"
    end,
    line = function()
        local done, total = Endeavors()
        if not done then return "Daily endeavors not read yet today" end
        if done >= total then return string.format("All %d daily endeavors done", total) end
        return string.format("%d of %d daily endeavors left", total - done, total)
    end,
    tip = "The account's daily endeavors (Challenges) not finished yet today. Click to open the Daily tab.",
    open = function() CT.Window:Show("daily") end,
})
