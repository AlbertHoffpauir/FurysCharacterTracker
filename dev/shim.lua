-- The offline viewer's stand-in for the game: the few game functions the addon's shared files
-- (the ones whose first line is "-- shared") use while drawing. Nothing here reads the game.
VIEWER_NOW = nil   -- tests set a fixed time; the viewer uses the clock
function GetTimeStamp() return VIEWER_NOW or os.time() end
function zo_round(n) return math.floor(n + 0.5) end
function zo_strformat(_, text) return (tostring(text or ""):gsub("%^.*$", "")) end
zo_strlower = string.lower
function ZO_CommaDelimitNumber(n)
    local digits = string.format("%d", math.floor((n or 0) + 0.5))
    local sign = ""
    if digits:sub(1, 1) == "-" then sign, digits = "-", digits:sub(2) end
    local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return sign .. (out:gsub("^,", ""))
end
CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_ENCHANTING, CRAFTING_TYPE_ALCHEMY = 1, 2, 3, 4
CRAFTING_TYPE_PROVISIONING, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING = 5, 6, 7
CHAT_ROUTER = { AddSystemMessage = function() end }
unpack = unpack or table.unpack

-- Saved files ---------------------------------------------------------------------------------
-- A saved file is Lua that sets FuryCT_SV. It is run with nothing in reach but an empty table, so
-- whatever a file holds, all it can do is fill that table.
local runChunk = loadstring or load
function FCT_ReadSaved(text)
    local box = {}
    local chunk
    if setfenv then
        chunk = runChunk(text, "saved")
        if chunk then setfenv(chunk, box) end
    else
        chunk = runChunk(text, "saved", "t", box)
    end
    if not chunk then return false end
    chunk()
    return type(box.FuryCT_SV) == "table" and box.FuryCT_SV or false
end

local function NewestRead(data)
    local newest = (type(data.account) == "table" and data.account.lastScan) or 0
    for _, c in pairs(type(data.characters) == "table" and data.characters or {}) do
        if type(c) == "table" and (c.lastScan or 0) > newest then newest = c.lastScan end
    end
    return newest
end

-- Adds one saved file to what the viewer shows. The same account in two files (the live and
-- liveeu folders): the copy that was read from the game last wins.
function FCT_AddSaved(text)
    local saved = FCT_ReadSaved(text)
    if not saved then return false end
    FuryCT_SV = FuryCT_SV or {}
    for world, accounts in pairs(saved) do
        if type(accounts) == "table" then
            FuryCT_SV[world] = FuryCT_SV[world] or {}
            for account, profile in pairs(accounts) do
                local data = type(profile) == "table" and profile["$AccountWide"]
                local have = FuryCT_SV[world][account]
                if type(data) == "table" and (not have or NewestRead(data) > NewestRead(have["$AccountWide"])) then
                    FuryCT_SV[world][account] = profile
                end
            end
        end
    end
    return true
end

-- Text for the page -----------------------------------------------------------------------------
-- Tables as JSON, the way the page's JavaScript reads them. A table with [1] is a list.
local escapes = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function Quote(text)
    return '"' .. text:gsub('[%c"\\]', function(ch) return escapes[ch] or string.format("\\u%04x", ch:byte()) end) .. '"'
end
local function Json(value, out)
    local kind = type(value)
    if kind == "string" then
        out[#out + 1] = Quote(value)
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            out[#out + 1] = "null"
        elseif value == math.floor(value) then
            out[#out + 1] = string.format("%d", value)
        else
            out[#out + 1] = string.format("%.6f", value)
        end
    elseif kind == "boolean" then
        out[#out + 1] = value and "true" or "false"
    elseif kind == "table" then
        if value[1] ~= nil or next(value) == nil then
            out[#out + 1] = "["
            for index = 1, #value do
                if index > 1 then out[#out + 1] = "," end
                Json(value[index], out)
            end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local first = true
            for key, item in pairs(value) do
                if type(item) ~= "function" then
                    if not first then out[#out + 1] = "," end
                    first = false
                    out[#out + 1] = Quote(tostring(key))
                    out[#out + 1] = ":"
                    Json(item, out)
                end
            end
            out[#out + 1] = "}"
        end
    else
        out[#out + 1] = "null"
    end
end
function FCT_Json(value)
    local out = {}
    Json(value, out)
    return table.concat(out)
end
