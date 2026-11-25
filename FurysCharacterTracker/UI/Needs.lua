-- Who needs me (/fct needs): one list of what your characters are waiting on you for.
-- The list itself is put together in Core/Needs.lua from what each file in Trackers/ reports.
local CT = FurysCharacterTracker
local Needs = CT.Needs

local ROW_TYPE = 1
local UPDATE_MS = 60000
local T = CT.Theme
local TEXT, DIM, AMBER = T.RGB.TEXT, T.RGB.MUTED, T.RGB.WARN

local function Paint(label, text, rgb)
    label:SetText(text or "")
    label:SetColor(rgb[1], rgb[2], rgb[3], 1)
end

local function SetupRow(control, row)
    control:GetNamedChild("Stripe"):SetHidden(not row.stripe)
    T.RowHover(control, false)
    -- The name is written once per character; its other rows leave it blank.
    Paint(control:GetNamedChild("Name"), row.first and row.name or "", TEXT)
    Paint(control:GetNamedChild("What"), row.text, AMBER)
    Paint(control:GetNamedChild("Detail"), row.detail, DIM)
    control.furyRow = control
    CT.Window.SetTip(control, function() return row.name .. "\n" .. row.text .. (row.detail ~= "" and ("\n" .. row.detail) or "") .. "\n\nClick for this character's details." end)
    control:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then CT.Details:Show(row.id) end end)
end

function Needs:Build()
    if self.list then return end
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Needs, false)
    self.list = FurysCharacterTracker_NeedsList
    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FurysCharacterTracker_NeedRow", 26, SetupRow)
    local header = FurysCharacterTracker_NeedsHeader
    for _, title in ipairs({ { "Name", "Character" }, { "What", "Waiting on you" }, { "Detail", "" } }) do
        local label = header:GetNamedChild(title[1])
        label:SetFont(T.FONT_HEADER)
        Paint(label, title[2], T.RGB.BLUE)
    end
    FurysCharacterTracker_NeedsLegend:SetText("Writs, riding lessons, free research slots, full bags  ·  click a row for details  ·  /fct needs")
    local pos = CT.sv.needsWindow
    if pos then
        FurysCharacterTracker_Needs:ClearAnchors()
        FurysCharacterTracker_Needs:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Needs.SavePosition()
    CT.sv.needsWindow = { x = FurysCharacterTracker_Needs:GetLeft(), y = FurysCharacterTracker_Needs:GetTop() }
end

function Needs:Refresh()
    if not self.list then return end
    local rows, characters = Needs.Rows()
    ZO_ScrollList_Clear(self.list)
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    local stripe = false
    for _, row in ipairs(rows) do
        -- Stripes go by character, so one character's rows read as a block.
        if row.first then stripe = not stripe end
        row.stripe = stripe
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, row)
    end
    ZO_ScrollList_Commit(self.list)
    FurysCharacterTracker_NeedsSubtitle:SetText(CT.ViewLabel())
    FurysCharacterTracker_NeedsSummary:SetText(Needs.Summary(rows, characters))
    FurysCharacterTracker_NeedsHeader:SetHidden(#rows == 0)
end

function Needs:Show()
    self:Build()
    self:Refresh()
    SCENE_MANAGER:ShowTopLevel(FurysCharacterTracker_Needs)
    CT.Raise(FurysCharacterTracker_Needs)
    EVENT_MANAGER:RegisterForUpdate(CT.name .. "Needs", UPDATE_MS, function()
        -- Closed some other way (Esc)? Stop counting.
        if FurysCharacterTracker_Needs:IsHidden() then EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Needs") else self:Refresh() end
    end)
end

function Needs:Hide()
    EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Needs")
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Needs)
end

function Needs:Toggle()
    if FurysCharacterTracker_Needs:IsHidden() then self:Show() else self:Hide() end
end

function Needs:RefreshIfShown()
    if not FurysCharacterTracker_Needs:IsHidden() then self:Refresh() end
end
