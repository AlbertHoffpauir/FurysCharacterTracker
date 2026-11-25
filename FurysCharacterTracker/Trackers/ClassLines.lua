-- shared
-- Class skill lines. A character uses three: its own class's, or (with subclassing) up to two
-- swapped for another class's. Other lines it has trained are kept too. Saved one text per line:
--   c.classLines = { "skill line id|line name|rank|class id|class name|state|mastery points", ... }
-- state: "a" one of the three in use, "t" being trained, "" trained earlier and not in use,
-- "m" the class mastery line. Class mastery is not a fourth line with a rank: it opens when a class
-- line reaches its top rank, its skills are bought with Class Mastery Points, and the game turns it
-- off while the character is subclassing. So it has points, never a rank out of 50.
local CT = FurysCharacterTracker
local U = CT.Util
local MAX = CT.CLASS_LINE_MAX

-- The saved lines of a character, split up: in use (game order) and the rest (highest rank first).
local function Lines(c)
    local active, other = {}, {}
    for _, text in ipairs(c.classLines or {}) do
        local p = U.Split(text, "|")
        local line = { id = tonumber(p[1]), name = p[2], rank = tonumber(p[3]) or 0, classId = tonumber(p[4]), class = p[5], state = p[6] or "",
                       points = tonumber(p[7]) }
        if line.state == "a" then
            active[#active + 1] = line
        elseif line.state ~= "m" or line.classId == c.classId then   -- 1.5.0 also saved other classes' mastery lines
            other[#other + 1] = line
        end
    end
    table.sort(other, function(a, b)
        if (a.state == "m") ~= (b.state == "m") then return a.state == "m" end   -- class mastery first
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.name < b.name
    end)
    return active, other
end

-- True when one of the three lines in use comes from another class: the game turns class mastery off then.
local function Subclassing(c)
    for _, line in ipairs((Lines(c))) do
        if line.classId ~= c.classId then return true end
    end
    return false
end

-- What a class mastery line is worth showing as: its points, and whether it is switched off.
local function MasteryText(line, c)
    local text = line.points and U.Count(line.points, "Class Mastery Point") or "open"
    if Subclassing(c) then text = text .. ", off while subclassing" end
    return text
end
CT.ClassLines = Lines

local STATE = { t = "in training" }
local function Describe(line, ownClassId, c)
    if line.state == "m" then return string.format("%s  ·  class mastery: %s", line.name, MasteryText(line, c)) end
    local text = string.format("%s  %d / %d", line.name, math.min(line.rank, MAX), MAX)
    if line.classId ~= ownClassId and line.class and line.class ~= "" then text = text .. "  (" .. line.class .. ")" end
    if STATE[line.state] then text = text .. "  ·  " .. STATE[line.state] end
    return text
end

local NOT_READ = "Not read yet: log in on this character once."

local function LineColumn(index)
    return { key = "classLine" .. index, title = "Class line " .. index, width = 164, max = MAX,
             head = "A class skill line this character is using, and its rank (the top rank is " .. MAX .. ").\nWith subclassing, up to two of the three can come from another class.",
             value = function(e) local line = Lines(e.c)[index]; return line and line.rank or 0 end,
             display = function(v, e)
                 local line = Lines(e.c)[index]
                 if not line then return "-" end
                 return line.name .. "  " .. U.Whole(math.min(v, MAX))
             end,
             dim = function(_, e) return Lines(e.c)[index] == nil end,
             tip = function(e)
                 local line = Lines(e.c)[index]
                 if not e.c.classLines then return NOT_READ end
                 return line and Describe(line, e.c.classId, e.c) or "No class line here."
             end }
end

CT.Track({
    id = "classLines",
    read = function(c)
        local gender, list = GetUnitGender("player"), {}
        local skillType = SKILL_TYPE_CLASS
        for lineIndex = 1, GetNumSkillLines(skillType) do
            local rank, _, isActive, isDiscovered, _, isInTraining, isClassMastery = GetSkillLineDynamicInfo(skillType, lineIndex)
            local classId = GetSkillLineClassId(skillType, lineIndex)
            local lineId = GetSkillLineId(skillType, lineIndex)
            local state = (isClassMastery and "m") or (isActive and "a") or (isInTraining and "t") or ""
            local keep, points
            if isClassMastery then
                -- Only this character's own class mastery, and only once the game has opened it.
                keep = classId == GetUnitClassId("player") and (isDiscovered or HasMaxRankInAnyClassSkillLine())
                points = GetNumClassMasteryPointsBySkillLineId(lineId)
            else
                -- A line that is neither in use nor trained is one of the other classes' untouched lines.
                keep = isActive or isInTraining or (isDiscovered and rank > 1)
            end
            if keep then
                list[#list + 1] = table.concat({ lineId, U.Clean(U.Plain(GetSkillLineNameById(lineId))), rank, classId,
                                                 U.Clean(U.Plain(GetClassName(gender, classId))), state, points }, "|")
            end
        end
        -- Nothing found means the skill data is not ready yet: keep what was saved.
        if #list > 0 then c.classLines = list end
    end,
    events = { EVENT_SKILL_RANK_UPDATE, EVENT_SKILL_LINE_ADDED, EVENT_SKILLS_FULL_UPDATE },
    columns = {
        LineColumn(1), LineColumn(2), LineColumn(3),
        { key = "classMaxed", title = "Maxed", width = 70, max = 3,
          head = "Maxed: how many of the three class lines in use are at rank " .. MAX .. ".",
          value = function(e)
              local n = 0
              for _, line in ipairs(Lines(e.c)) do if line.rank >= MAX then n = n + 1 end end
              return n
          end,
          display = function(v, e) return e.c.classLines and U.Of(v, 3) or "-" end,
          dim = function(_, e) return not e.c.classLines end,
          tip = function(e)
              if not e.c.classLines then return NOT_READ end
              local lines = {}
              for _, line in ipairs(Lines(e.c)) do lines[#lines + 1] = Describe(line, e.c.classId) end
              return table.concat(lines, "\n")
          end },
        { key = "classOther", title = "Other class lines", width = 166, align = "left",
          head = "Other class lines this character has: its class mastery if it is open, lines in training, and lines trained earlier that are not in use now.\nClass mastery has no rank: it opens when a class line reaches rank " .. MAX .. " and is bought with Class Mastery Points.\nHover a cell for the whole list.",
          value = function(e) local _, other = Lines(e.c); return #other end,
          display = function(v, e)
              if v == 0 then return "-" end
              local _, other = Lines(e.c)
              local names = {}
              for i, line in ipairs(other) do
                  names[i] = line.state == "m" and (line.name .. " (mastery)") or (line.name .. " " .. U.Whole(math.min(line.rank, MAX)))
              end
              return table.concat(names, "  ·  ")
          end,
          dim = function(v) return v == 0 end,
          tip = function(e)
              if not e.c.classLines then return NOT_READ end
              local _, other = Lines(e.c)
              if #other == 0 then return "No other class lines trained." end
              local lines = {}
              for _, line in ipairs(other) do lines[#lines + 1] = Describe(line, e.c.classId, e.c) end
              return table.concat(lines, "\n")
          end },
    },
    sections = function(e)
        if not e.c.classLines then return nil end
        local active, other = Lines(e.c)
        local items = {}
        for _, line in ipairs(active) do items[#items + 1] = CT.Trackers.Progress(line.name, math.min(line.rank, MAX), MAX) end
        for _, line in ipairs(other) do
            if line.state == "m" then
                items[#items + 1] = { line.name .. " (class mastery)", MasteryText(line, e.c) }
            else
                items[#items + 1] = CT.Trackers.Progress(string.format("%s (%s)", line.name, STATE[line.state] or "not in use"), math.min(line.rank, MAX), MAX)
            end
        end
        return { { title = "Class lines", items = items } }
    end,
    export = {
        { "Class line 1", function(e) local l = Lines(e.c)[1]; return l and (l.name .. " " .. U.Whole(l.rank)) end },
        { "Class line 2", function(e) local l = Lines(e.c)[2]; return l and (l.name .. " " .. U.Whole(l.rank)) end },
        { "Class line 3", function(e) local l = Lines(e.c)[3]; return l and (l.name .. " " .. U.Whole(l.rank)) end },
    },
})
