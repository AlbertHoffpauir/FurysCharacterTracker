-- shared
-- "Who needs me": one list of what your characters are waiting on you for. Each file in Trackers/
-- can add to it with a `needs` function: function(e, now, world) -> { { text =, detail =, order = } }.
local CT = FurysCharacterTracker
local Needs = {}
CT.Needs = Needs

-- Rows for the account on the board, in your board order, most pressing thing first per character:
--   { name =, id =, text =, detail =, first = true on a character's first row }
function Needs.Rows(now)
    now = now or GetTimeStamp()
    local world = CT.view and CT.view.world or ""
    local rows, characters = {}, 0
    for _, e in ipairs(CT.Roster:List()) do
        local items = {}
        for _, tracker in ipairs(CT.Trackers.list) do
            for _, item in ipairs(tracker.needs and tracker.needs(e, now, world) or {}) do
                item.index = #items + 1
                items[#items + 1] = item
            end
        end
        table.sort(items, function(a, b)
            if (a.order or 9) ~= (b.order or 9) then return (a.order or 9) < (b.order or 9) end
            return a.index < b.index
        end)
        if #items > 0 then characters = characters + 1 end
        for index, item in ipairs(items) do
            rows[#rows + 1] = { name = e.name, id = e.id, text = item.text, detail = item.detail or "", first = index == 1 }
        end
    end
    return rows, characters
end

-- The line above the list.
function Needs.Summary(rows, characters)
    local U = CT.Util
    if #rows == 0 then
        return "Nothing is waiting on you. Writs count for the crafts a character did in the last two weeks."
    end
    local text = string.format("%s on %s", U.Count(#rows, "thing"), U.Count(characters, "character"))
    if not CT.IsHome() then text = text .. "  ·  as saved at that account's last logout" end
    return text
end
