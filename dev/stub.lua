NOW = 1795600000
LOG = {}            -- chat lines
CALLS = 0           -- game API calls made
PROBLEMS = {}       -- undocumented globals or control methods the addon touched
local function Problem(text) if not PROBLEMS[text] then PROBLEMS[text] = true; PROBLEMS[#PROBLEMS + 1] = text end end

-- Controls --------------------------------------------------------------------------------------
local Control = {}
CONTROLS = {}
-- Methods ESO adds in Lua on top of the documented control API.
local LUA_METHODS = { GetNamedChild = true, SetHandler = true, GetHandler = true }
local function NewControl(name)
    -- Windows start hidden (their XML says so); everything made inside them starts shown.
    local isWindow = name:match("^FurysCharacterTracker_%a+$") ~= nil
    return setmetatable({ __name = name, hidden = isWindow, text = "", children = {}, handlers = {}, w = 100, h = 30, scale = 1 }, Control)
end
local explicit = {
    IsHidden = function(self) return self.hidden end,
    SetHidden = function(self, h) self.hidden = h end,
    GetText = function(self) return self.text end,
    SetText = function(self, t) self.text = t end,
    GetName = function(self) return self.__name end,
    GetNamedChild = function(self, n)
        local c = self.children[n]
        if not c then c = NewControl((self.__name or "?") .. n); self.children[n] = c; CONTROLS[c.__name] = c end
        return c
    end,
    SetHandler = function(self, name, fn) self.handlers[name] = fn end,
    GetHandler = function(self, name) return self.handlers[name] end,
    GetLeft = function() return 10 end, GetTop = function() return 10 end,
    GetRight = function() return -400 end,   -- far left, so a title bar always has room for the Fury icons
    GetWidth = function(self) return self.w end, GetHeight = function(self) return self.h end,
    SetDimensions = function(self, w, h) self.w, self.h = w, h end,
    SetWidth = function(self, w) self.w = w end, SetHeight = function(self, h) self.h = h end,
    SetScale = function(self, s) self.scale = s end, GetScale = function(self) return self.scale end,
    SetEnabled = function(self, e) self.enabled = e end,
    SetAlpha = function(self, a) self.alpha = a end,
    SetColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
    SetFont = function(self, f) self.font = f end,
    WasTruncated = function() return false end,
    -- Text measured roughly: 8 px a letter, 20 px a line, wrapped at the control's width.
    GetTextWidth = function(self) return 8 * #tostring(self.text or "") end,
    GetTextHeight = function(self)
        local lines = 0
        for part in (tostring(self.text or "") .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(8 * #part / math.max(1, self.w))) end
        return 20 * lines
    end,
    SetMouseEnabled = function(self, on) self.mouse = on end,
    TakeFocus = function(self) FOCUS = self end,
    LoseFocus = function(self) if FOCUS == self then FOCUS = false end end,
    SelectAll = function(self) self.selected = true end,
}
FOCUS = false
Control.__index = function(self, key)
    if explicit[key] then return explicit[key] end
    if type(key) == "string" and key:match("^[A-Z]") then
        if not (PY_IS_METHOD(key) or LUA_METHODS[key]) then Problem("control method not in the API: " .. key) end
        return function() return nil end
    end
    return nil   -- a plain field the addon keeps on the control
end
function GetControl(name, suffix)
    if type(name) == "table" then name = name.__name end
    name = name .. (suffix or "")
    if not CONTROLS[name] then CONTROLS[name] = NewControl(name) end
    return CONTROLS[name]
end
GuiRoot = GetControl("GuiRoot"); GuiRoot.w, GuiRoot.h = 1920, 1080
InformationTooltip = GetControl("InformationTooltip")
TIP = false
function InitializeTooltip() end
function ClearTooltip() TIP = false end
function SetTooltipText(_, text) TIP = text end

WINDOW_MANAGER = {
    CreateControl = function(_, name, parent)
        if parent and name:find("$(parent)", 1, true) then name = name:gsub("%$%(parent%)", parent.__name) end
        return GetControl(name)
    end,
    CreateTopLevelWindow = function(_, name) return GetControl(name) end,
    CreateControlFromVirtual = function(_, name, parent, template)
        if parent and name:find("$(parent)", 1, true) then name = name:gsub("%$%(parent%)", parent.__name) end
        if not ESO_TEMPLATES[template] and not tostring(template):match("^FurysCharacterTracker_") then Problem("template not known to the harness: " .. tostring(template)) end
        return GetControl(name)
    end,
}

-- ESO UI Lua helpers the addon uses (from the game's own UI source, not the C API) ------------------
function zo_strformat(fmt, a) return (tostring(a or ""):gsub("%^.*$", "")) end
zo_strlower, zo_strupper = string.lower, string.upper
function zo_strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function zo_round(n) return math.floor(n + 0.5) end
zo_floor, zo_min, zo_max = math.floor, math.min, math.max
function zo_plainstrfind(s, f) return s:find(f, 1, true) ~= nil end
function zo_callLater(fn, ms) local id = "later" .. tostring(fn); EVENT_MANAGER:RegisterForUpdate(id, ms, function() EVENT_MANAGER:UnregisterForUpdate(id); fn() end) end
function ZO_CommaDelimitNumber(n)
    local s = tostring(math.floor((n or 0) + 0.5)); local sign = ""
    if s:sub(1, 1) == "-" then sign, s = "-", s:sub(2) end
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return sign .. (out:gsub("^,", ""))
end
function ZO_ClearTable(t) for k in pairs(t) do t[k] = nil end end
function ZO_CreateStringId(id, text) _G[id] = id; STRINGS = STRINGS or {}; STRINGS[id] = text end
ZO_ColorDef = {}
ZO_ColorDef.__index = ZO_ColorDef
function ZO_ColorDef:New(hex)
    local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    return setmetatable({ r = r, g = g, b = b, a = 1 }, ZO_ColorDef)
end
function ZO_ColorDef:UnpackRGB() return self.r, self.g, self.b end
function ZO_ColorDef:UnpackRGBA() return self.r, self.g, self.b, self.a end

-- Scroll lists: Commit calls the row setup for every entry, on its own control, and keeps them.
function ZO_ScrollList_AddDataType(list, typeId, template, height, setup) list.setup = setup; list.data = {} end
function ZO_ScrollList_Clear(list) list.data = {} end
function ZO_ScrollList_GetDataList(list) return list.data end
function ZO_ScrollList_CreateDataEntry(typeId, data) return { typeId = typeId, data = data } end
function ZO_ScrollList_Commit(list)
    list.rows = {}
    for i, entry in ipairs(list.data) do
        local row = GetControl(list.__name .. "Row" .. i)
        list.setup(row, entry.data)
        list.rows[i] = row
    end
end
function ZO_Scroll_ResetToTop() end
-- Templates from the game's own UI source that the windows are built from.
ESO_TEMPLATES = { ZO_DefaultButton = true, ZO_CloseButton = true, ZO_CheckButton = true, ZO_MultiLineEditBackdrop_Keyboard = true, ZO_DefaultEditMultiLineForBackdrop = true }
function ZO_ScrollList_RefreshVisible(list) ZO_ScrollList_Commit(list) end

-- Check boxes, the HUD scenes and their fragments (the Fury sidebar in the shared library).
function ZO_CheckButton_SetLabelText(check, text) check.label = text end
function ZO_CheckButton_SetToggleFunction(check, fn) check.toggle = fn end
function ZO_CheckButton_SetCheckState(check, on) check.checked = on end
ZO_HUDFadeSceneFragment = {}
ZO_HUDFadeSceneFragment.__index = ZO_HUDFadeSceneFragment
function ZO_HUDFadeSceneFragment:New(control) return setmetatable({ control = control, reasons = {} }, self) end
function ZO_HUDFadeSceneFragment:SetHiddenForReason(reason, hidden)
    self.reasons[reason] = hidden or nil
    self.control.hidden = next(self.reasons) ~= nil
end
local function StubScene()
    local scene = { fragments = {} }
    function scene:AddFragment(fragment) self.fragments[fragment] = true end
    function scene:RemoveFragment(fragment) self.fragments[fragment] = nil end
    return scene
end
HUD_SCENE = StubScene()
HUD_UI_SCENE = StubScene()
MOUSE_BUTTON_INDEX_RIGHT = 2

function ZO_PreHookHandler(control, name, fn)
    local old = control.handlers[name]
    control.handlers[name] = function(...) fn(...); if old then return old(...) end end
end

SHOWN = {}
SCENE_MANAGER = {
    RegisterTopLevel = function() end,
    ShowTopLevel = function(_, c) c.hidden = false; local h = c.handlers.OnShow; if h then h(c) end end,
    HideTopLevel = function(_, c) c.hidden = true; local h = c.handlers.OnHide; if h then h(c) end end,
    ToggleTopLevel = function(self, c) if c.hidden then self:ShowTopLevel(c) else self:HideTopLevel(c) end end,
}
CHAT_ROUTER = { AddSystemMessage = function(_, text) LOG[#LOG + 1] = text end }
SLASH_COMMANDS = {}
MENU = {}
function ClearMenu() MENU = {} end
function AddMenuItem(label, fn) MENU[#MENU + 1] = { label = label, fn = fn } end
function ShowMenu() end
DIALOGS, DIALOG_SHOWN = {}, false
GAMEPAD_DIALOGS = { BASIC = 1 }
ESO_Dialogs = DIALOGS
function ZO_Dialogs_RegisterCustomDialog(name, info) DIALOGS[name] = info end
function ZO_Dialogs_ShowDialog(name, data, params) DIALOG_SHOWN = { name = name, data = data, params = params } end
function ZO_Dialogs_ShowPlatformDialog(name, data, params) DIALOG_SHOWN = { name = name, data = data, params = params } end
RELOADS, URLS = 0, {}

LAM_PANEL, LAM_OPTIONS, LAM_OPENED = false, false, 0
LibAddonMenu2 = {
    RegisterAddonPanel = function(_, name, panel) LAM_PANEL = panel; return GetControl(name) end,
    RegisterOptionControls = function(_, name, options) LAM_OPTIONS = options end,
    OpenToPanel = function() LAM_OPENED = LAM_OPENED + 1 end,
}

-- Events and timers -----------------------------------------------------------------------------
EVENTS, UPDATES, FILTERS = {}, {}, {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, fn)
        if event == nil then error("RegisterForEvent with a nil event (" .. name .. ")", 2) end
        EVENTS[event] = EVENTS[event] or {}; EVENTS[event][name] = fn
    end,
    UnregisterForEvent = function(_, name, event) if EVENTS[event] then EVENTS[event][name] = nil end end,
    AddFilterForEvent = function(_, name, event, ...) FILTERS[name] = { event, ... } end,
    RegisterForUpdate = function(_, name, ms, fn) UPDATES[name] = { ms = ms, fn = fn, at = NOW_MS + ms } end,
    UnregisterForUpdate = function(_, name) UPDATES[name] = nil end,
}
NOW_MS = 0
function Fire(event, ...)
    local list = {}
    for name, fn in pairs(EVENTS[event] or {}) do list[#list + 1] = fn end
    for _, fn in ipairs(list) do fn(event, ...) end
    return #list
end
-- Let `ms` of game time pass, running timers that come due.
function Advance(ms)
    local target = NOW_MS + ms
    while true do
        local nextName, nextAt
        for name, u in pairs(UPDATES) do
            if u.at <= target and (not nextAt or u.at < nextAt) then nextName, nextAt = name, u.at end
        end
        if not nextName then break end
        NOW_MS = nextAt; NOW = BASE_NOW + math.floor(NOW_MS / 1000)
        local u = UPDATES[nextName]
        u.at = u.at + u.ms
        u.fn()
    end
    NOW_MS = target; NOW = BASE_NOW + math.floor(NOW_MS / 1000)
end
BASE_NOW = NOW

-- Saved variables ---------------------------------------------------------------------------------
local function Fill(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then target[k] = {}; Fill(target[k], v) else target[k] = v end
        elseif type(v) == "table" and type(target[k]) == "table" then
            Fill(target[k], v)
        end
    end
end
ZO_SavedVars = {
    NewAccountWide = function(_, name, version, namespace, defaults, profile, displayName)
        _G[name] = rawget(_G, name) or {}
        local root = _G[name]
        profile = profile or "Default"
        local who = displayName or HOME_ACCOUNT
        root[profile] = root[profile] or {}
        root[profile][who] = root[profile][who] or {}
        local acct = root[profile][who]
        acct["$AccountWide"] = acct["$AccountWide"] or { version = version }
        Fill(acct["$AccountWide"], defaults or {})
        return acct["$AccountWide"]
    end,
}

-- The game --------------------------------------------------------------------------------------
-- A made-up character, sized like a real one (4,095 recipes, 8,253 outfit styles, 2,500 quests done).
GAME = {
    name = "Test Hero^Mx", id = "8798292061234567", class = "Templar", classId = 6, race = "Breton", raceId = 1,
    alliance = 2, level = 50, played = 360000, combat = false, language = "en",
    lineRank = function(lineId) return (lineId * 7) % 51 end,
    skillsReady = true, unspent = 3,
    researchKnown = function(craft, line, trait) return (craft + line + trait) % 3 ~= 0 end,
    researchRemaining = function(craft, line, trait) return ((craft == 1 and line == 2 and trait == 3) or (craft == 7 and line == 1 and trait == 6)) and 7200 or 0 end,
    researchLines = { [1] = 14, [2] = 14, [6] = 6, [7] = 2 },
    recipeLists = 40, recipes = 4095, styles = 137, outfitStyles = 8253, sets = 700, questsDone = 2500,
    introDone = { [6626] = true, [7017] = true }, companions = 8, grimoires = 12,
    characters = { { "Test Hero^Mx", 1, 50, 6, 1, 2, "8798292061234567", 1 }, { "Second Alt^Fx", 2, 12, 2, 7, 1, "8798292061234568", 1 },
                   { "Third Alt^Mx", 1, 50, 117, 9, 3, "8798292061234569", 1 } },
    -- Writs: one told apart by what it asks you to make, one by its English name, one already made (complete),
    -- one in another language that says "deliver" in no way the addon could read.
    journal = { [3] = { id = 5368, name = "Schmiedeschrieb", type = "craft", daily = true, conditions = { "Stellt her: Rubeditaxt: 0 / 1" }, craft = 1 },
                [5] = { id = 5400, name = "Enchanter Writ", type = "craft", daily = true, conditions = { "Deliver Goods to Belkarth" } },
                [6] = { id = 5412, name = "Alchemistenschrieb", type = "craft", daily = true, conditions = { "Beutet aus" }, craft = 4, complete = true },
                [7] = { id = 4100, name = "The Jeweled Crown", type = "other", daily = false, conditions = { "Talk to someone" } } },
    cooldowns = { [11] = 43200, [12] = 0, [13] = 0 }, gear = true, bagUsed = 195,
    challenges = { { 0, 1, 1 }, { 0, 0, 3 }, { 0, 5, 5 }, { 1, 2, 10 }, { 1, 1, 1 }, { 2, 0, 1 } },
    money = 123456, ridingMs = 3600000, riding = { 60, 60, 30, 60, 40, 60 },
}
CALLED = {}
local function Api(name, fn)
    if not PY_IS_FUNC(name) then Problem("the harness stands in for a function that is not in the API documentation: " .. name) end
    rawset(_G, name, function(...) CALLS = CALLS + 1; CALLED[name] = (CALLED[name] or 0) + 1; return fn(...) end)
end
local LINE_IDS = { 24, 25, 26, 29, 30, 31, 32, 33, 34, 44, 45, 48, 55, 117, 118, 130, 50, 51, 72, 111, 157, 76, 77, 78, 79, 80, 81, 141 }
SKILL_TYPE_CLASS, SKILL_TYPE_WEAPON, SKILL_TYPE_ARMOR, SKILL_TYPE_WORLD, SKILL_TYPE_GUILD, SKILL_TYPE_AVA, SKILL_TYPE_RACIAL, SKILL_TYPE_TRADESKILL = 1, 2, 3, 4, 5, 6, 7, 8
-- Class lines: the Templar's own three, plus what subclassing shows: one line of another class in
-- use, one in training, one trained earlier and put away, and the rest never touched.
--                 id, classId, rank, isActive, isDiscovered, isInTraining, isClassMastery
local CLASS_LINES = { { 22, 6, 50, true, true, false, false }, { 27, 6, 50, true, true, false, false }, { 28, 6, 31, false, true, false, false },
                      { 35, 1, 12, true, true, false, false }, { 41, 2, 4, false, true, true, false }, { 38, 3, 9, false, true, false, false },
                      { 300, 6, 1, false, false, false, true }, { 301, 1, 1, false, false, false, true },   -- class mastery: own class (opened by a rank 50 line) and another class
                      { 36, 1, 1, false, false, false, false }, { 37, 1, 1, false, false, false, false }, { 127, 4, 1, false, false, false, false } }
Api("GetWorldName", function() return HOME_WORLD end)
Api("GetDisplayName", function() return HOME_ACCOUNT end)
Api("GetTimeStamp", function() return NOW end)
Api("GetUnitName", function() return GAME.name end)
Api("GetCurrentCharacterId", function() return GAME.id end)
Api("GetUnitClass", function() return GAME.class end)
Api("GetUnitClassId", function() return GAME.classId end)
Api("GetUnitRace", function() return GAME.race end)
Api("GetUnitRaceId", function() return GAME.raceId end)
Api("GetUnitAlliance", function() return GAME.alliance end)
Api("GetUnitGender", function() return 1 end)
Api("GetClassIndexById", function(id) return ({ [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [117] = 7 })[id] end)
Api("GetClassInfo", function(index) return index, "", "n", "p", "m", true, "/esoui/art/icons/class/class_" .. index .. ".dds" end)
Api("GetCollectibleCategoryType", function(id) return id > 9000 and COLLECTIBLE_CATEGORY_TYPE_COMPANION or COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE end)
-- Skyshards: 12 zones, 3 of them with something left to find.
SKYSHARD_DISCOVERY_STATUS_ACQUIRED = 3
local ZONES = { 3, 19, 20, 41, 57, 58, 92, 101, 103, 104, 108, 117 }
local function ShardGot(zoneId, index) return not ((zoneId == 41 and index > 13) or (zoneId == 104 and index == 2) or (zoneId == 117 and index > 6)) end
Api("GetNumSkyshards", function() return #ZONES * 16 end)
Api("GetSkyshardId", function(index) return index end)
Api("GetNumSkyshardsInZone", function() return 16 end)
Api("GetZoneSkyshardId", function(zoneId, index) return zoneId * 100 + index end)
Api("GetSkyshardDiscoveryStatus", function(id)
    if id <= #ZONES * 16 then
        local zone, index = ZONES[math.floor((id - 1) / 16) + 1], (id - 1) % 16 + 1
        return ShardGot(zone, index) and SKYSHARD_DISCOVERY_STATUS_ACQUIRED or 1
    end
    return ShardGot(math.floor(id / 100), id % 100) and SKYSHARD_DISCOVERY_STATUS_ACQUIRED or 1
end)
Api("GetNextZoneStoryZoneId", function(last)
    if last == nil then return ZONES[1] end
    for i, id in ipairs(ZONES) do if id == last then return ZONES[i + 1] end end
end)
Api("GetZoneNameById", function(id) return "Zone " .. id .. "^N" end)
Api("GetUnitAvARank", function() return GAME.avaRank or 23, 1 end)
-- Activity finder rewards, endeavors-style challenges.
LFG_COOLDOWN_DUNGEON_REWARD_GRANTED, LFG_COOLDOWN_BATTLEGROUND_REWARD_GRANTED, LFG_COOLDOWN_TRIBUTE_REWARD_GRANTED = 11, 12, 13
Api("GetLFGCooldownTimeRemainingSeconds", function(kind) return GAME.cooldowns[kind] or 0 end)
TIMED_ACTIVITY_TYPE_DAILY, TIMED_ACTIVITY_TYPE_WEEKLY, TIMED_ACTIVITY_TYPE_SEASONAL = 0, 1, 2
Api("IsTimedActivitySystemAvailable", function() return true end)
Api("GetNumTimedActivities", function() return #GAME.challenges end)
Api("GetTimedActivityType", function(i) return GAME.challenges[i][1] end)
Api("GetTimedActivityProgress", function(i) return GAME.challenges[i][2] end)
Api("GetTimedActivityMaxProgress", function(i) return GAME.challenges[i][3] end)
Api("GetTimedActivityTypeResetTimeS", function(kind) return BASE_NOW + (kind == TIMED_ACTIVITY_TYPE_DAILY and 30000 or 300000) end)
-- Weekly leaderboards: the trial of the week ranked, the group arena started, Maelstrom with a
-- score and no place, Vateshran not run, Archive solo ranked, a battleground score, a campaign tier.
Api("GetRaidOfTheWeekTimes", function() return 200000, 200000 end)
Api("GetNumRaidLeaderboards", function(category) return category == RAID_CATEGORY_TRIAL and 12 or 4, true end)
Api("GetRaidOfTheWeekLeaderboardInfo", function(category) return category == RAID_CATEGORY_TRIAL and "Sunspire^N" or "Blackrose Prison^N", 77 end)
Api("GetRaidOfTheWeekLeaderboardLocalPlayerInfo", function(category) if category == RAID_CATEGORY_TRIAL then return 42, 187654 end return 0, 0 end)
Api("GetPlayerRaidOfTheWeekParticipationInfo", function(category) return category == RAID_CATEGORY_TRIAL, category == RAID_CATEGORY_TRIAL end)
Api("GetPlayerRaidOfTheWeekProgressInfo", function(category) if category == RAID_CATEGORY_TRIAL then return false, true end return true, false end)
local CHALLENGES = { 21, 22, 23, 24 }
local CHALLENGE_NAMES = { [21] = "Dragonstar Arena^N", [22] = "Zone 677^N", [23] = "Zone 1227^N", [24] = "Blackrose Prison^N" }
Api("GetNextRaidLeaderboardId", function(_, last)
    if not last then return CHALLENGES[1] end
    for i, id in ipairs(CHALLENGES) do if id == last then return CHALLENGES[i + 1] end end
end)
Api("GetRaidLeaderboardName", function(id) return CHALLENGE_NAMES[id] end)
Api("GetRaidLeaderboardLocalPlayerInfo", function(id) if id == 22 then return 0, 512345 end if id == 23 then return 612, 88000 end return 0, 0 end)
Api("GetPlayerRaidParticipationInfo", function(id) return id == 22, id == 22 end)
Api("GetPlayerRaidProgressInfo", function(id) return false, id == 22 end)
Api("QueryRaidLeaderboardData", function() return LEADERBOARD_DATA_READY end)
Api("QueryEndlessDungeonLeaderboardData", function() return LEADERBOARD_DATA_RESPONSE_PENDING end)
Api("QueryBattlegroundLeaderboardData", function() return LEADERBOARD_DATA_READY end)
Api("GetEndlessDungeonOfTheWeekTimes", function() return 150000, 150000 end)
Api("GetEndlessDungeonOfTheWeekLeaderboardLocalPlayerInfo", function(groupType) if groupType == ENDLESS_DUNGEON_GROUP_TYPE_SOLO then return 7, 98765 end return 0, 0 end)
Api("GetPlayerEndlessDungeonOfTheWeekParticipationInfo", function(groupType) return groupType == ENDLESS_DUNGEON_GROUP_TYPE_SOLO, groupType == ENDLESS_DUNGEON_GROUP_TYPE_SOLO end)
Api("GetPlayerEndlessDungeonOfTheWeekProgressInfo", function(groupType) return false, groupType == ENDLESS_DUNGEON_GROUP_TYPE_SOLO end)
Api("GetNextBattlegroundLeaderboardType", function(last) if not last then return BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE end end)
Api("ShouldShowLeaderboardForBattlegroundLeaderboardType", function() return true end)
Api("GetBattlegroundLeaderboardLocalPlayerInfo", function() return 0, 1500 end)
Api("GetBattlegroundLeaderboardsSchedule", function() return 100000, 100000 end)
Api("GetAssignedCampaignId", function() return 102 end)
Api("GetSecondsUntilCampaignEnd", function() return 400000 end)
Api("GetPlayerCampaignRewardTierInfo", function() return 2, 12000, 50000 end)
Api("GetCampaignName", function() return "Gray Host^N" end)
-- Worn gear: five pieces of one set, two of another, a ring with no set, an empty off hand.
BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_WORN = 1, 2, 6, 0
EQUIP_SLOT_HEAD, EQUIP_SLOT_NECK, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND = 0, 1, 2, 3, 4, 5
EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_HAND = 6, 8, 9, 11, 12, 16
EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF = 20, 21
ITEM_TRAIT_TYPE_NONE = 0
local WORN = { [0] = { "Helm of the Test^n", 4, 13, "Order's Wrath", 5 }, [3] = { "Epaulets of the Test", 4, 13, "Order's Wrath", 5 },
               [2] = { "Jerkin of the Test", 5, 16, "Order's Wrath", 5 }, [16] = { "Gloves of the Test", 4, 13, "Order's Wrath", 5 },
               [6] = { "Sash of the Test", 4, 13, "Order's Wrath", 5 }, [8] = { "Breeches | odd; name", 3, 13, "Mother's Sorrow", 2 },
               [9] = { "Shoes of Sorrow", 3, 13, "Mother's Sorrow", 2 }, [11] = { "Plain Ring", 2, 0, nil, 0 },
               [4] = { "Lightning Staff", 5, 4, "Perfected Test Set", 2 }, [20] = { "Restoration Staff", 5, 2, "Perfected Test Set", 2 } }
Api("GetItemLink", function(bag, slot) return (bag == BAG_WORN and GAME.gear and WORN[slot]) and ("|H1:item:" .. slot .. "|h|h") or "" end)
local function Worn(link) return WORN[tonumber(link:match("item:(%d+)"))] end
Api("GetItemLinkName", function(link) return Worn(link)[1] end)
Api("GetItemLinkDisplayQuality", function(link) return Worn(link)[2] end)
Api("GetItemLinkTraitInfo", function(link) return Worn(link)[3], "" end)
Api("GetItemLinkSetInfo", function(link)
    local item = Worn(link)
    if not item[4] then return false, "", 0, 0, 0, 0, 0 end
    local perfected = item[4]:find("Perfected") and item[5] or 0
    return true, item[4] .. "^n", 5, item[5] - perfected, 5, 99, perfected
end)
Api("GetActiveCompanionLevelInfo", function() return GAME.companionLevel or 14, 1200 end)
Api("GetActiveCompanionRapport", function() return GAME.rapport or 2500 end)
Api("GetMaximumRapport", function() return 5000 end)
Api("GetAllianceName", function(a) return ({ "Aldmeri Dominion", "Ebonheart Pact", "Daggerfall Covenant" })[a] or "" end)
Api("GetClassName", function(_, id) return ({ [1] = "Dragonknight", [2] = "Sorcerer", [3] = "Nightblade", [4] = "Warden", [5] = "Necromancer", [6] = "Templar", [117] = "Arcanist" })[id] or "?" end)
Api("GetRaceName", function(_, id) return ({ "Breton", "Redguard", "Orc", "Dark Elf", "Nord", "Argonian", "High Elf", "Wood Elf", "Khajiit", "Imperial" })[id] or "?" end)
Api("GetUnitLevel", function() return GAME.level end)
Api("GetSecondsPlayed", function() return GAME.played end)
Api("IsUnitInCombat", function() return GAME.combat end)
Api("GetCVar", function(name) return name == "language.2" and GAME.language or "" end)
Api("GetNumSkillLines", function(skillType)
    if not GAME.skillsReady then return 0 end
    return (skillType == SKILL_TYPE_WEAPON and #LINE_IDS) or (skillType == SKILL_TYPE_CLASS and #CLASS_LINES) or 0
end)
Api("GetSkillLineId", function(skillType, index)
    if skillType == SKILL_TYPE_CLASS then return CLASS_LINES[index][1] end
    return LINE_IDS[index]
end)
Api("GetSkillLineNameById", function(id) return "Line " .. id .. "^n" end)
Api("GetSkillLineClassId", function(skillType, index) return CLASS_LINES[index][2] end)
Api("GetSkillLineDynamicInfo", function(skillType, index)
    if skillType == SKILL_TYPE_CLASS then
        local line = CLASS_LINES[index]
        return line[3], false, line[4], line[5], false, line[6], line[7]
    end
    local id = LINE_IDS[index]
    local rank = GAME.lineRank(id)
    return rank, false, true, rank > 0, false, false, false
end)
Api("GetAvailableSkillPoints", function() return GAME.unspent end)
local function Iter(count, make) return function() local i = 0; return function() i = i + 1; if i <= count then CALLS = CALLS + 1; return i, make(i) end end end end
SKILLS_DATA_MANAGER = { SkillTypeIterator = Iter(8, function(t)
    return { SkillLineIterator = Iter(6, function(l)
        return { SkillIterator = Iter(14, function(s)
            return { GetPointAllocator = function() return { GetNumPointsAllocated = function() CALLS = CALLS + 1; return GAME.skillsReady and ((t + l + s) % 2) or 0 end } end }
        end) }
    end) }
end) }
Api("GetMaxSimultaneousSmithingResearch", function() return 3 end)
Api("GetNumSmithingResearchLines", function(craft) return GAME.researchLines[craft] or 0 end)
Api("GetSmithingResearchLineInfo", function(craft, line) return "Item " .. craft .. "." .. line .. "^n", "", 9, 21600 end)
Api("GetSmithingResearchLineTraitInfo", function(craft, line, trait) return trait + (craft == 7 and 20 or 0), "", GAME.researchKnown(craft, line, trait) end)
Api("GetSmithingResearchLineTraitTimes", function(craft, line, trait)
    local remaining = GAME.researchRemaining(craft, line, trait)
    if remaining > 0 then return 21600, remaining end
    return nil, nil
end)
Api("GetString", function(prefix, id)
    if prefix == "SI_ITEMTRAITTYPE" then return "Trait" .. tostring(id) end
    if prefix == "SI_TRADESKILLTYPE" then return ({ "Blacksmithing", "Clothing", "Enchanting", "Alchemy", "Provisioning", "Woodworking", "Jewelry Crafting" })[id] or "?" end
    return tostring(prefix) .. tostring(id or "")
end)
Api("GetNumRecipeLists", function() return GAME.recipeLists end)
Api("GetRecipeListInfo", function(list) return "List " .. list, math.floor(GAME.recipes / GAME.recipeLists) + (list == 1 and GAME.recipes % GAME.recipeLists or 0) end)
Api("GetRecipeInfo", function(list, index) return (list * index) % 4 ~= 0, "Recipe", 1, 1, 1, 1, (list <= 10) and CRAFTING_TYPE_PROVISIONING or CRAFTING_TYPE_BLACKSMITHING end)
Api("GetNumCraftedAbilities", function() return GAME.grimoires end)
Api("GetCraftedAbilityIdAtIndex", function(i) return 100 + i end)
Api("IsCraftedAbilityUnlocked", function(id) return id % 2 == 0 end)
Api("GetNumScriptsInSlotForCraftedAbility", function(id, slot) return 8 end)
Api("GetScriptIdAtSlotIndexForCraftedAbility", function(id, slot, index) return slot * 100 + ((id + index) % 23) end)
Api("IsCraftedAbilityScriptUnlocked", function(id) return id % 3 ~= 0 end)
Api("GetNumValidItemStyles", function() return GAME.styles end)
Api("GetValidItemStyleId", function(i) return i end)
Api("IsSmithingStyleKnown", function(id) return id % 5 ~= 0 end)
Api("GetNextItemSetCollectionId", function(last) local n = (last or 0) + 1; if n <= GAME.sets then return n end end)
Api("GetNumItemSetCollectionPieces", function(id) return 15 end)
Api("GetNumItemSetCollectionSlotsUnlocked", function(id) return id % 16 end)
COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE, COLLECTIBLE_CATEGORY_TYPE_COMPANION = 301, 302
local COMPANION_NAMES = { "Bastian Hallix", "Mirri Elendis", "Ember", "Isobel Veloise", "Sharp-as-Night", "Azandar al-Cybiades", "Tanlorin", "Zerith-var" }
local COMPANION_QUESTS = { 6626, 6648, 6771, 6760, 7017, 7021, 7186, 7194 }
Api("GetTotalCollectiblesByCategoryType", function(t) return t == COLLECTIBLE_CATEGORY_TYPE_COMPANION and GAME.companions or GAME.outfitStyles end)
Api("GetCollectibleIdFromType", function(t, i) return (t == COLLECTIBLE_CATEGORY_TYPE_COMPANION and 9000 or 0) + i end)
Api("IsCollectibleUnlocked", function(id) return id > 9000 or id % 3 == 0 end)
Api("GetCollectibleName", function(id) return (COMPANION_NAMES[id - 9000] or ("Companion" .. id)) .. "^M" end)
Api("GetCollectibleReferenceId", function(id) return id - 9000 end)
Api("GetCompanionIntroQuestId", function(companionId) return COMPANION_QUESTS[companionId] or 0 end)
Api("GetCompanionCollectibleId", function(companionId) return 9000 + companionId end)
Api("HasActiveCompanion", function() return GAME.activeCompanion ~= nil end)
Api("GetActiveCompanionDefId", function() return GAME.activeCompanion or 0 end)
Api("GetNumCharacters", function() return #GAME.characters end)
Api("GetCharacterInfo", function(i) return unpack(GAME.characters[i]) end)
Api("GetPlayerChampionPointsEarned", function() return 2396 end)
-- Public dungeon group events: every one done but two.
Api("IsAchievementComplete", function(id) return id ~= 380 and id ~= 4002 end)
Api("GetAchievementInfo", function(id) return "Achievement " .. id .. "^n", "", 15, "", id ~= 380 and id ~= 4002, "", "" end)
Api("GetTotalAchievementPoints", function() return 75895 end)
Api("GetEarnedAchievementPoints", function() return 41230 end)
local QUEST_LIST, QUEST_NEXT
local function QuestList()
    if QUEST_LIST then return end
    QUEST_LIST, QUEST_NEXT = {}, {}
    for id = 4001, 4000 + GAME.questsDone do QUEST_LIST[#QUEST_LIST + 1] = id end
    for id in pairs(GAME.introDone) do if id > 4000 + GAME.questsDone then QUEST_LIST[#QUEST_LIST + 1] = id end end
    table.sort(QUEST_LIST)
    for i, id in ipairs(QUEST_LIST) do QUEST_NEXT[id] = QUEST_LIST[i + 1] end
end
function ResetQuests() QUEST_LIST = nil end
Api("GetNextCompletedQuestId", function(last)
    QuestList()
    if last == nil then return QUEST_LIST[1] end
    return QUEST_NEXT[last]
end)
-- Three finished certifications among the finished quests (the Templar is certified for more than it has writs for).
local CERTIFICATIONS = { [4001] = "Blacksmith Certification", [4002] = "Alchemist Certification", [4003] = "Jewelry Crafting Certification" }
Api("GetCompletedQuestInfo", function(id)
    if CERTIFICATIONS[id] then return CERTIFICATIONS[id] .. "^n", QUEST_TYPE_CRAFTING end
    return "Quest Number " .. id .. "^n", 1
end)
Api("HasCompletedQuest", function(id) return GAME.introDone[id] == true or (id > 4000 and id <= 4000 + GAME.questsDone) end)
CURT_MONEY, CURT_ALLIANCE_POINTS, CURT_TELVAR_STONES, CURT_WRIT_VOUCHERS = 1, 2, 3, 4
CURT_TRANSMUTE_CRYSTALS, CURT_UNDAUNTED_KEYS, CURT_SEALS, CURT_ARCHIVAL_FORTUNES, CURT_IMPERIAL_FRAGMENTS = 5, 6, 7, 8, 9
CURT_TRADE_BARS, CURT_TOME_POINTS, CURT_TOME_TOKENS, CURT_TOME_POINT_CACHES, CURT_TOME_CHALLENGE_REROLLS = 10, 11, 12, 13, 14
CURT_UNDAUNTED_CRESTS, CURT_STYLE_STONES, CURT_CROWN_GEMS, CURT_CROWNS = 15, 16, 17, 18
CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK, CURRENCY_LOCATION_ACCOUNT = 0, 1, 3
local CURRENCY_NAMES = { [5] = "Transmute Crystals", [6] = "Undaunted Keys", [7] = "Seals of Endeavor", [8] = "Archival Fortunes", [9] = "Imperial Fragments",
                         [10] = "Trade Bars", [11] = "Tome Points", [12] = "Tome Tokens", [13] = "Tome Point Caches", [14] = "Challenge Rerolls",
                         [15] = "Undaunted Crests", [16] = "Outfit Change Tokens", [17] = "Crown Gems", [18] = "Crowns" }
Api("GetCurrencyAmount", function(c, where)
    if where == CURRENCY_LOCATION_CHARACTER then return c == CURT_MONEY and GAME.money or (c <= 4 and c * 111 or 0) end
    if where == CURRENCY_LOCATION_BANK then return c <= 4 and c * 1000 or 0 end
    return (c > 4 and c ~= 13 and c ~= 15) and c * 37 or 0
end)
Api("IsCurrencyValid", function(c) return c ~= 10 end)
Api("GetCurrencyPlayerStoredLocation", function(c) return c > 4 and CURRENCY_LOCATION_ACCOUNT or CURRENCY_LOCATION_CHARACTER end)
Api("GetCurrencyName", function(c) return (CURRENCY_NAMES[c] or "?") .. "^n" end)
Api("GetNumBagUsedSlots", function(bag) return bag == BAG_BACKPACK and GAME.bagUsed or 100 + bag end)
Api("GetBagSize", function(bag) return 200 + bag end)
Api("GetNumChampionDisciplines", function() return 3 end)
Api("GetChampionDisciplineId", function(i) return i end)
Api("GetChampionDisciplineName", function(id) return ({ "Craft", "Warfare", "Fitness" })[id] end)
Api("GetNumSpentChampionPoints", function(id) return id * 200 end)
Api("GetNumUnspentChampionPoints", function(id) return id == 2 and 0 or 12 end)
Api("GetRidingStats", function() return unpack(GAME.riding) end)
Api("GetTimeUntilCanBeTrained", function() return GAME.ridingMs end)
MAX_JOURNAL_QUESTS = 25
QUEST_MAIN_STEP_INDEX = 1
Api("IsValidQuestIndex", function(i) return GAME.journal[i] ~= nil end)
Api("GetJournalQuestInfo", function(i) local q = GAME.journal[i]; return q.name, "", "", 1, "", false, false, 50, false, q.type == "craft" and QUEST_TYPE_CRAFTING or 1 end)
Api("GetJournalQuestType", function(i) local q = GAME.journal[i]; return q and q.type == "craft" and QUEST_TYPE_CRAFTING or 1 end)
Api("GetJournalQuestRepeatType", function(i) return GAME.journal[i].daily and QUEST_REPEAT_DAILY or 0 end)
Api("GetJournalQuestName", function(i) return GAME.journal[i].name end)
Api("GetJournalQuestId", function(i) return GAME.journal[i].id end)
Api("GetJournalQuestIsComplete", function(i) return GAME.journal[i].complete == true end)
Api("GetQuestConditionItemInfo", function(i) return 0, 0, GAME.journal[i].craft or 0, 0 end)
Api("GetJournalQuestNumConditions", function(i) return #GAME.journal[i].conditions end)
Api("GetJournalQuestConditionInfo", function(i, step, c) return GAME.journal[i].conditions[c], 0, 1, false, false, false, true end)
Api("GetSelectedLFGRole", function() return LFG_ROLE_DPS end)
Api("GetUIMousePosition", function() return 100, 100 end)
Api("RequestOpenUnsafeURL", function(url) URLS[#URLS + 1] = url end)
Api("ReloadUI", function() RELOADS = RELOADS + 1 end)
Api("GetAPIVersion", function() return 101051 end)
Api("PlaySound", function() end)
SOUNDS = setmetatable({}, { __index = function(_, k) return k end })

-- Real values for the constants saved data depends on.
CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_ENCHANTING, CRAFTING_TYPE_ALCHEMY = 1, 2, 3, 4
CRAFTING_TYPE_PROVISIONING, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING = 5, 6, 7

-- Anything else: a documented constant gets a number, a documented function must be stood in for
-- above, and a name that is in neither list is a mistake in the addon.
local nextConst = 5000
setmetatable(_G, { __index = function(t, key)
    if type(key) ~= "string" then return nil end
    if key:match("^FurysCharacterTracker_") then
        local c = GetControl(key); rawset(t, key, c); return c
    end
    if PY_IS_CONST(key) then nextConst = nextConst + 1; rawset(t, key, nextConst); return nextConst end
    if PY_IS_FUNC(key) then error("ESO API used but not stood in for by the harness: " .. key, 2) end
    if key == "FuryCT_SV" or key == "STRINGS" or key == "FurysAddonMenu_SV" then return nil end
    Problem("global not in the ESO API documentation: " .. key)
    return nil
end })

-- The saved file as the game writes it at logout (the compact layout).
function SavedFileText()
    local out = {}
    local function Key(k) return type(k) == "number" and ("[" .. k .. "]") or string.format("[%q]", k) end
    local function Write(value)
        local kind = type(value)
        if kind == "table" then
            local keys = {}
            for k in pairs(value) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b) if type(a) == type(b) then return a < b end return type(a) == "number" end)
            out[#out + 1] = "{"
            for _, k in ipairs(keys) do
                out[#out + 1] = Key(k) .. "="
                Write(value[k])
                out[#out + 1] = ","
            end
            out[#out + 1] = "}"
        elseif kind == "string" then
            out[#out + 1] = (string.format("%q", value):gsub("\\\n", "\\n"))
        else
            out[#out + 1] = tostring(value)
        end
    end
    out[#out + 1] = "FuryCT_SV="
    Write(FuryCT_SV)
    return table.concat(out) .. "\n"
end
