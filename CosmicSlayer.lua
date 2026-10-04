local ACHIEVEMENT_ID = 62570
local MAPS = { 2395, 2437 }
local WATCH = { "Springclaw", "Croaker", "Grizzly" }
local WEEK_REFRESH = 600

local weekMap
local weekCheckedAt = 0

local defaults = {
    sound = true,
    chat = true,
    waypoint = true,
}

local active = {}
local shown = {}
local panel
local rows = {}
local progressText
local checks = {}

local function DB()
    if not CosmicSlayerDB then
        CosmicSlayerDB = {}
    end
    for key, value in pairs(defaults) do
        if CosmicSlayerDB[key] == nil then
            CosmicSlayerDB[key] = value
        end
    end
    return CosmicSlayerDB
end

local function WatchedName(name)
    for _, key in ipairs(WATCH) do
        if name:find(key, 1, true) then
            return key
        end
    end
end

local function ProgressLine()
    local _, _, _, completed = GetAchievementInfo(ACHIEVEMENT_ID)
    if completed then
        return "15 / 15 complete"
    end
    local criteriaCount = GetAchievementNumCriteria(ACHIEVEMENT_ID)
    if not criteriaCount or criteriaCount < 1 then
        return "Progress unavailable"
    end
    local _, _, _, quantity, reqQuantity = GetAchievementCriteriaInfo(ACHIEVEMENT_ID, 1)
    if issecretvalue(quantity) or issecretvalue(reqQuantity) then
        return "Progress unavailable"
    end
    return string.format("%d / %d", quantity or 0, reqQuantity or 15)
end

local function RefreshPanel()
    if not panel then
        return
    end
    progressText:SetText(ProgressLine())
    for _, key in ipairs(WATCH) do
        local row = rows[key]
        if shown[key] then
            row:SetText(shown[key])
            row:SetTextColor(0.45, 1, 0.55)
        else
            row:SetText(key .. " is not up")
            row:SetTextColor(0.65, 0.65, 0.65)
        end
    end
end

local function PointTo(mapID, info)
    if not DB().waypoint then
        return
    end
    local pos = info.position
    if not pos or not UiMapPoint or not C_Map.SetUserWaypoint then
        return
    end
    local point = UiMapPoint.CreateFromCoordinates(mapID, pos.x, pos.y)
    if not point then
        return
    end
    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end

local function Alert(mapID, info)
    local db = DB()
    if db.chat then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r " .. info.name .. " is up.")
    end
    if db.sound then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
    PointTo(mapID, info)
end

local function MapHasAssault(mapID)
    local quests = C_TaskQuest.GetQuestsOnMap(mapID)
    if not quests then
        return false
    end
    for _, quest in ipairs(quests) do
        local title = C_TaskQuest.GetQuestInfoByQuestID(quest.questID)
        if title and not issecretvalue(title) and title:find("Void Assaults:", 1, true) then
            return true
        end
    end
    return false
end

local function ActiveMap()
    local now = GetTime()
    if weekMap and (now - weekCheckedAt) < WEEK_REFRESH then
        return weekMap
    end
    weekCheckedAt = now
    for _, mapID in ipairs(MAPS) do
        if MapHasAssault(mapID) then
            weekMap = mapID
            return weekMap
        end
    end
    return weekMap
end

local function Scan()
    local seen = {}
    local maps = MAPS
    local activeMap = ActiveMap()
    if activeMap then
        maps = { activeMap }
    end
    for _, mapID in ipairs(maps) do
        local ids = C_AreaPoiInfo.GetEventsForMap(mapID)
        if ids then
            for _, id in ipairs(ids) do
                local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
                if info and info.name and not issecretvalue(info.name) then
                    local key = WatchedName(info.name)
                    if key and not seen[key] then
                        seen[key] = info.name
                        if not active[key] then
                            active[key] = true
                            Alert(mapID, info)
                        end
                    end
                end
            end
        end
    end
    for _, key in ipairs(WATCH) do
        if not seen[key] then
            active[key] = nil
        end
    end
    shown = seen
    RefreshPanel()
end

local function MakeCheck(label, key, y)
    local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", 16, y)
    box:SetScript("OnClick", function(self)
        DB()[key] = self:GetChecked() and true or false
    end)
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetText(label)
    checks[key] = box
end

local function ApplySettings()
    local db = DB()
    for key, box in pairs(checks) do
        box:SetChecked(db[key])
    end
    if db.point then
        panel:ClearAllPoints()
        panel:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "CosmicSlayerFrame", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(280, 248)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        DB().point = { point, relativePoint, x, y }
    end)
    panel:Hide()
    tinsert(UISpecialFrames, "CosmicSlayerFrame")
    if panel.TitleText then
        panel.TitleText:SetText("Cosmic Slayer")
    end

    progressText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    progressText:SetPoint("TOP", 0, -36)

    for index, key in ipairs(WATCH) do
        local row = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row:SetPoint("TOPLEFT", 24, -70 - (index - 1) * 22)
        row:SetJustifyH("LEFT")
        rows[key] = row
    end

    MakeCheck("Raid warning sound", "sound", -150)
    MakeCheck("Chat message", "chat", -178)
    MakeCheck("Set waypoint", "waypoint", -206)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", 0, 12)
    hint:SetText("/cs")
end

local function TogglePanel()
    if panel:IsShown() then
        panel:Hide()
        return
    end
    Scan()
    panel:Show()
end

CreatePanel()

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("AREA_POIS_UPDATED")
frame:RegisterEvent("CRITERIA_UPDATE")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= "CosmicSlayer" then
            return
        end
        ApplySettings()
        RefreshPanel()
        return
    end
    if event == "CRITERIA_UPDATE" then
        RefreshPanel()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, Scan)
        return
    end
    Scan()
end)

C_Timer.NewTicker(10, Scan)

SLASH_COSMICSLAYER1 = "/cs"
SLASH_COSMICSLAYER2 = "/cosmicslayer"
SlashCmdList["COSMICSLAYER"] = TogglePanel
