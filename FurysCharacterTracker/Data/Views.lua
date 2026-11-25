-- shared
-- The tabs of the board. Each names its columns by key; the columns themselves are made by the
-- files in Trackers/. To show a column on a tab, add its key here.
--   live      the tab shows timers, so it redraws once a minute while it is open
--   totals    label of the bottom row when it adds up instead of counting maxed characters
--   summary   function(data, now) -> a line for the top of the tab (and its hover text), instead of the usual one
local CT = FurysCharacterTracker

local function Lines(groupId, ...)
    local keys = { "name", "class", "role" }
    for _, group in ipairs(CT.GROUPS) do
        if group.id == groupId then
            for _, line in ipairs(group.lines) do keys[#keys + 1] = "line." .. line.name end
        end
    end
    for _, key in ipairs({ ... }) do keys[#keys + 1] = key end
    return keys
end

CT.VIEWS = {
    { id = "overview", title = "Overview", tip = "Everything at a glance: how many lines of each group are maxed.",
      columns = { "name", "class", "role", "skillPoints", "group.weapons", "group.armor", "group.guilds", "group.world", "group.crafting",
                  "research", "companions", "riding", "achievements", "hours" } },
    { id = "class", title = "Class", tip = "Who each character is: level, race and alliance, the three class skill lines it is using, and the other class lines it has trained.",
      columns = { "name", "class", "level", "race", "alliance", "classLine1", "classLine2", "classLine3", "classMaxed", "classOther" } },
    { id = "weapons", title = "Weapons", tip = "The rank of every weapon skill line. Top rank is 50.",
      columns = Lines("weapons") },
    { id = "armor", title = "Armor", tip = "The rank of the three armor skill lines. Top rank is 50.",
      columns = Lines("armor") },
    { id = "guilds", title = "Guilds & AvA", tip = "Guild and Alliance War skill lines. Each has its own top rank: hover a column title.",
      columns = Lines("guilds") },
    { id = "world", title = "World", tip = "World skill lines such as Legerdemain, Soul Magic and Vampire, and Scribing.",
      columns = Lines("world", "scribing") },
    { id = "crafting", title = "Crafting", tip = "The rank of the seven crafting skill lines, and traits researched.",
      columns = Lines("crafting", "research") },
    { id = "traits", title = "Research", live = true,
      tip = "Traits known and missing per craft, research slots and timers. Hover a craft for details.\nResearch timers (button below, or /fct timers) lists every research with its time left.",
      columns = { "name", "class", "role", "research.Smith", "research.Cloth", "research.Wood", "research.Jewelry", "researchSlots", "researchNext", "research" } },
    { id = "daily", title = "Daily", live = true,
      tip = "Crafting writs since today's reset, the next riding lesson, the daily dungeon and battleground rewards, and trial quests this week.",
      columns = { "name", "class", "writ.Smith", "writ.Cloth", "writ.Wood", "writ.Jewelry", "writ.Alchemy", "writ.Enchant", "writ.Provis",
                  "writsDone", "ridingLesson", "reward.dungeon", "reward.battleground", "trials" } },
    { id = "collections", title = "Collections", tip = "Recipes, furnishing plans, motifs, scribing, riding, companions and time played.",
      columns = { "name", "class", "role", "recipes", "plans", "motifs", "scribing", "riding", "companions", "achievements", "hours", "skillPoints" } },
    { id = "points", title = "Skill points", tip = "Where the skill points still to earn are: skyshards, public dungeon group events and Alliance War rank.",
      columns = { "name", "class", "skillPoints", "unspent", "shards", "shardPoints", "pubDungeons", "avaRank" } },
    { id = "wallet", title = "Wallet & CP", totals = "Total",
      tip = "Gold, Tel Var, Alliance Points, writ vouchers and bag space per character, and Champion Points spent per tree.\nThe line above the columns shows the bank and what the whole account shares.",
      columns = { "name", "class", "role", "gold", "telvar", "ap", "vouchers", "bag", "cp1", "cp2", "cp3" } },
    { id = "progress", title = "Progress", totals = "Total",
      tip = "What each character gained in the last 7 and 30 days: gold, hours played, skill points, achievement points and traits.",
      columns = { "name", "class", "delta.gold.7", "delta.gold.30", "delta.playedHours.7", "delta.playedHours.30", "delta.skillPoints.7",
                  "delta.skillPoints.30", "delta.achievementPoints.7", "delta.achievementPoints.30", "delta.research.7", "delta.research.30",
                  "trackedSince" } },
    { id = "sets", title = "Roles & gear", tip = "Your own picks and note per character, and the sets each one is wearing. Click a blue cell to change it.",
      columns = { "name", "class", "rolePick", "dpsGear", "roleGear", "plannedRace", "wearing", "note", "updated" } },
}

CT.VIEW_BY_ID = {}
for _, view in ipairs(CT.VIEWS) do CT.VIEW_BY_ID[view.id] = view end
