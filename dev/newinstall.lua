-- Game mode with no saved file: what a brand-new player gets.
local CT = FurysCharacterTracker
local function Problem(fmt, ...)
    local text = "NEW: " .. string.format(fmt, ...)
    if not PROBLEMS[text] then PROBLEMS[text] = true; PROBLEMS[#PROBLEMS + 1] = text end
end
local function Check(ok, fmt, ...) if not ok then Problem(fmt, ...) end end
local sv = CT.sv
Check(sv.alertResearch == false and sv.alertRiding == false and sv.loginNotice == false, "alerts are not turned off on a new install")
Check(not sv.openAtLogin, "open at login is on")
Check(sv.dataVersion == #CT.UPGRADES, "data version %s", tostring(sv.dataVersion))
Check(#LOG == 0, "chat lines at login on a new install: %s", tostring(LOG[1]))
Check(FurysCharacterTracker_Window.hidden, "the board opened by itself")
for name in pairs(UPDATES) do Check(not name:find("Alert"), "an alert timer is running with alerts off: %s", name) end
SLASH_COMMANDS["/fct"]("")
Check(not FurysCharacterTracker_Details.hidden and FurysCharacterTracker_DetailsTitle.text == "Start here", "Start here did not open with the board the first time")
CT.Details:Hide(); CT.Window:Hide()
SLASH_COMMANDS["/fct"]("")
Check(FurysCharacterTracker_Details.hidden, "Start here opened a second time")
UI_OUT[#UI_OUT + 1] = "summary: " .. FurysCharacterTracker_WindowSummary.text
for _, option in ipairs(LAM_OPTIONS) do
    if option.type == "checkbox" then Check(option.getFunc() == false, "settings checkbox %s is on for a new install", option.name) end
end
UICheck()
