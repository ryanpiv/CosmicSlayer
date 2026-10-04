local ACHIEVEMENT_ID = 62570
local ZONES = {
    { mapID = 2395, label = "Eversong Woods", short = "Eversong", bosses = { "Springclaw", "Croaker" } },
    { mapID = 2437, label = "Zul'Aman", short = "Zul'Aman", bosses = { "Grizzly" } },
}
local MAPS = {}
local MAP_LABEL = {}
local WATCH = {}
for _, zone in ipairs(ZONES) do
    tinsert(MAPS, zone.mapID)
    MAP_LABEL[zone.mapID] = zone.short
    for _, boss in ipairs(zone.bosses) do
        tinsert(WATCH, boss)
    end
end
local WEEK_REFRESH = 600
local POLL_SECONDS = 15
local COLLAPSED_HEIGHT = 72
local EXPANDED_HEIGHT = 428
local FLAT = "Interface\\Buttons\\WHITE8X8"

local weekMap
local weekCheckedAt = 0

local defaults = {
    sound = true,
    chat = true,
    waypoint = true,
    collapsed = false,
}

local active = {}
local shown = {}
local panel
local rows = {}
local zoneHeaders = {}
local progressText
local titleText
local strikeLabel
local strikeText
local strikeMeta
local refreshedText
local trackButton
local waypointButton
local collapseButton
local closeButton
local refreshButton
local checks = {}
local detailWidgets = {}
local currentStrike
local currentStrikeSecret
local currentPin
local currentZone
local currentEventCount = 0
local lastScanClock
local inZone = false

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

local function IsAchievementTracked()
    if not C_ContentTracking or not C_ContentTracking.IsTracking or not Enum or not Enum.ContentTrackingType then
        return false
    end
    return C_ContentTracking.IsTracking(Enum.ContentTrackingType.Achievement, ACHIEVEMENT_ID)
end

local function RefreshTrackButton()
    if not trackButton then
        return
    end
    if IsAchievementTracked() then
        trackButton:SetText("Untrack achievement")
    else
        trackButton:SetText("Track achievement")
    end
end

local function TrackAchievement()
    if not C_ContentTracking or not C_ContentTracking.StartTracking or not Enum or not Enum.ContentTrackingType then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r Achievement tracking is unavailable.")
        return
    end
    if IsAchievementTracked() then
        local stopType = Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual
        C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, ACHIEVEMENT_ID, stopType)
    else
        C_ContentTracking.StartTracking(Enum.ContentTrackingType.Achievement, ACHIEVEMENT_ID)
    end
    RefreshTrackButton()
end

local function RefreshPanel()
    if not panel then
        return
    end
    progressText:SetText(ProgressLine())
    if not lastScanClock then
        strikeText:SetText("Waiting for first scan")
        strikeText:SetTextColor(0.65, 0.65, 0.65)
        if inZone then
            strikeMeta:SetText("Every " .. POLL_SECONDS .. "s")
        else
            strikeMeta:SetText("Paused outside the strike zone")
        end
    else
        if currentStrikeSecret then
            strikeText:SetText(currentStrikeSecret)
            strikeText:SetTextColor(1, 0.86, 0.4)
        elseif currentStrike then
            strikeText:SetText(currentStrike)
            if WatchedName(currentStrike) then
                strikeText:SetTextColor(0.45, 1, 0.55)
            else
                strikeText:SetTextColor(1, 0.86, 0.4)
            end
        else
            strikeText:SetText("No Void Ritual strike")
            strikeText:SetTextColor(0.65, 0.65, 0.65)
        end
        local status = inZone and ("Every " .. POLL_SECONDS .. "s") or "Paused"
        strikeMeta:SetText(string.format("%s  ·  %s  ·  %d events  ·  %s", status, currentZone or "No map", currentEventCount, lastScanClock))
    end
    if refreshedText then
        if lastScanClock then
            refreshedText:SetText("Last refresh " .. lastScanClock)
        else
            refreshedText:SetText("Not refreshed yet")
        end
    end
    for _, zone in ipairs(ZONES) do
        local header = zoneHeaders[zone.mapID]
        if weekMap == zone.mapID then
            header:SetText(zone.label .. "  ·  this week")
            header:SetTextColor(0.78, 0.86, 0.94)
        else
            header:SetText(zone.label)
            if weekMap then
                header:SetTextColor(0.42, 0.46, 0.5)
            else
                header:SetTextColor(0.72, 0.76, 0.8)
            end
        end
    end
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
    RefreshTrackButton()
end

local function PlaceWaypoint(mapID, x, y)
    if not mapID or not x or not y or not UiMapPoint or not C_Map.SetUserWaypoint then
        return false
    end
    if issecretvalue(x) or issecretvalue(y) then
        return false
    end
    local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
    if not point then
        return false
    end
    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    return true
end

local function PointTo(mapID, info)
    if not DB().waypoint then
        return
    end
    local pos = info.position
    if not pos or issecretvalue(pos) then
        return
    end
    PlaceWaypoint(mapID, pos.x, pos.y)
end

local function SetWaypoint()
    if not currentPin then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r No strike pin to mark.")
        return
    end
    if not PlaceWaypoint(currentPin.mapID, currentPin.x, currentPin.y) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r Could not set a waypoint.")
    end
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

local function MapIsUnder(mapID, target)
    local guard = 0
    while mapID and mapID ~= 0 and guard < 8 do
        if issecretvalue(mapID) then
            return false
        end
        if mapID == target then
            return true
        end
        local info = C_Map.GetMapInfo(mapID)
        if not info or issecretvalue(info.parentMapID) or not info.parentMapID or info.parentMapID == mapID then
            return false
        end
        mapID = info.parentMapID
        guard = guard + 1
    end
    return false
end

local function InRightZone()
    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap or issecretvalue(playerMap) then
        return false
    end
    for _, mapID in ipairs(MAPS) do
        if MapIsUnder(playerMap, mapID) then
            return true
        end
    end
    return false
end

local function ZoneName(mapID)
    local guard = 0
    local id = mapID
    while id and id ~= 0 and guard < 8 do
        if issecretvalue(id) then
            return nil
        end
        if MAP_LABEL[id] then
            return MAP_LABEL[id]
        end
        local info = C_Map.GetMapInfo(id)
        if not info or issecretvalue(info.parentMapID) or not info.parentMapID or info.parentMapID == id then
            return nil
        end
        id = info.parentMapID
        guard = guard + 1
    end
end

local function MapsToScan()
    local list = {}
    local seen = {}
    local function add(mapID)
        if not mapID or issecretvalue(mapID) or seen[mapID] then
            return
        end
        seen[mapID] = true
        tinsert(list, mapID)
    end
    for _, mapID in ipairs(MAPS) do
        add(mapID)
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and mapID ~= 0 and guard < 8 and not issecretvalue(mapID) do
        local underZone = false
        for _, zoneID in ipairs(MAPS) do
            if MapIsUnder(mapID, zoneID) then
                underZone = true
            end
        end
        if underZone then
            add(mapID)
        end
        for _, zoneID in ipairs(MAPS) do
            if mapID == zoneID then
                return list
            end
        end
        local info = C_Map.GetMapInfo(mapID)
        if not info or issecretvalue(info.parentMapID) or not info.parentMapID or info.parentMapID == mapID then
            break
        end
        mapID = info.parentMapID
        guard = guard + 1
    end
    return list
end

local function Readable(value)
    if not value or issecretvalue(value) then
        return nil
    end
    return value
end

local function IsStrikeText(text)
    if not text then
        return false
    end
    if text:find("Void Ritual", 1, true) or text:find("Void Strike", 1, true) then
        return true
    end
    return WatchedName(text) ~= nil
end

local function PoiInfo(mapID, id)
    if issecretvalue(id) then
        return nil
    end
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
    if not info or not info.name then
        local fallback = C_AreaPoiInfo.GetAreaPOIInfo(id)
        if fallback and fallback.name then
            return fallback
        end
    end
    return info
end

local function IsIncursionText(text)
    return text and text:find("Incursion", 1, true)
end

local function Scan()
    inZone = InRightZone()
    ActiveMap()
    local seen = {}
    local strikeList = {}
    local strikeSeen = {}
    local currentNames = {}
    local currentSeen = {}
    local incursionName
    local secretStrike
    local eventCount = 0
    local pinMap, pinX, pinY
    local pinRank = -1
    local strikeZone
    local function Remember(mapID, info, rank)
        local pos = info.position
        if not pos or issecretvalue(pos) or issecretvalue(pos.x) or issecretvalue(pos.y) then
            return
        end
        if rank < pinRank then
            return
        end
        pinMap, pinX, pinY = mapID, pos.x, pos.y
        pinRank = rank
    end
    for _, mapID in ipairs(MapsToScan()) do
        local ids = C_AreaPoiInfo.GetEventsForMap(mapID)
        if ids and not issecretvalue(ids) then
            for _, id in ipairs(ids) do
                if not issecretvalue(id) then
                    eventCount = eventCount + 1
                    local info = PoiInfo(mapID, id)
                    if info then
                        local plainName = Readable(info.name)
                        local plainDesc = Readable(info.description)
                        local currentEvent = info.isCurrentEvent
                        if issecretvalue(currentEvent) then
                            currentEvent = nil
                        end
                        local label = ZoneName(mapID)
                        if plainName and (IsStrikeText(plainName) or IsStrikeText(plainDesc)) and not strikeSeen[plainName] then
                            strikeSeen[plainName] = true
                            tinsert(strikeList, plainName)
                            Remember(mapID, info, WatchedName(plainName) and 4 or 3)
                            strikeZone = label or strikeZone
                        elseif plainName and (IsIncursionText(plainName) or IsIncursionText(plainDesc)) and not incursionName then
                            incursionName = plainName
                            Remember(mapID, info, 2)
                            strikeZone = label or strikeZone
                        elseif plainName and currentEvent and not currentSeen[plainName] then
                            currentSeen[plainName] = true
                            tinsert(currentNames, plainName)
                            Remember(mapID, info, 1)
                            strikeZone = label or strikeZone
                        elseif not plainName and info.name and issecretvalue(info.name) and not secretStrike then
                            secretStrike = info.name
                            Remember(mapID, info, 0)
                            strikeZone = label or strikeZone
                        end
                        local key = plainName and WatchedName(plainName)
                        if key and not seen[key] then
                            seen[key] = plainName
                            Remember(mapID, info, 4)
                            if not active[key] then
                                active[key] = true
                                Alert(mapID, info)
                            end
                        end
                    end
                end
            end
        end
    end
    currentStrikeSecret = nil
    if #strikeList > 0 then
        currentStrike = table.concat(strikeList, ", ")
    elseif incursionName then
        currentStrike = incursionName
    elseif #currentNames == 1 then
        currentStrike = currentNames[1]
    elseif secretStrike then
        currentStrike = nil
        currentStrikeSecret = secretStrike
    else
        currentStrike = nil
    end
    if pinMap then
        currentPin = { mapID = pinMap, x = pinX, y = pinY }
    else
        currentPin = nil
    end
    currentZone = strikeZone or "Eversong + Zul'Aman"
    currentEventCount = eventCount
    lastScanClock = date("%H:%M:%S")
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
    checks[key] = box
    if not label or label == "" then
        return box
    end
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetText(label)
    return text
end

local function AddDetail(widget)
    if widget then
        tinsert(detailWidgets, widget)
    end
    return widget
end

local function TintLines(button, r, g, b)
    for _, line in ipairs(button.lines) do
        line:SetVertexColor(r, g, b)
    end
end

local function MarkButton(name, onClick)
    local button = CreateFrame("Button", name, panel)
    button:SetSize(16, 16)
    button.lines = {}
    local function line(width, rotation, x)
        local tex = button:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(FLAT)
        tex:SetSize(width, 1)
        tex:SetPoint("CENTER", x or 0, 0)
        tex:SetRotation(rotation)
        tex:SetVertexColor(0.82, 0.86, 0.92)
        tinsert(button.lines, tex)
        return tex
    end
    button.line = line
    button:SetScript("OnEnter", function(self)
        TintLines(self, 1, 1, 1)
    end)
    button:SetScript("OnLeave", function(self)
        TintLines(self, 0.82, 0.86, 0.92)
    end)
    button:SetScript("OnClick", onClick)
    return button
end

local function PaintButton(button, quiet)
    button.quiet = quiet
    if quiet then
        button:SetBackdropColor(0, 0, 0, 0)
        button:SetBackdropBorderColor(0, 0, 0, 0)
    else
        button:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        button:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

local function TintButtonText(button, r, g, b)
    if button.label then
        button.label:SetTextColor(r, g, b)
    end
end

local function FlatButton(text, width)
    local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
    button:SetSize(width, 20)
    button:SetBackdrop({
        bgFile = FLAT,
        edgeFile = FLAT,
        edgeSize = 1,
    })
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    label:SetTextColor(0.86, 0.88, 0.9)
    button.label = label
    button.text = text
    PaintButton(button, false)
    button:SetScript("OnEnter", function(self)
        if not self.quiet then
            self:SetBackdropBorderColor(0.45, 0.5, 0.56, 1)
        end
        TintButtonText(self, 1, 1, 1)
    end)
    button:SetScript("OnLeave", function(self)
        if not self.quiet then
            self:SetBackdropBorderColor(0, 0, 0, 1)
        end
        TintButtonText(self, 0.86, 0.88, 0.9)
    end)
    return button
end

local function ApplyLayout()
    if not panel or not collapseButton then
        return
    end
    local collapsed = DB().collapsed
    panel:SetSize(300, collapsed and COLLAPSED_HEIGHT or EXPANDED_HEIGHT)
    for _, widget in ipairs(detailWidgets) do
        if collapsed then
            widget:Hide()
        else
            widget:Show()
        end
    end
    local tilt = math.rad(collapsed and 42 or -42)
    collapseButton.lines[1]:SetRotation(tilt)
    collapseButton.lines[2]:SetRotation(-tilt)
    if collapsed then
        panel:SetBackdropColor(0.02, 0.02, 0.02, 0.10)
        panel:SetBackdropBorderColor(0, 0, 0, 0)
        refreshedText:Show()
        progressText:ClearAllPoints()
        progressText:SetPoint("TOPLEFT", 12, -8)
        progressText:SetSpacing(6)
        strikeText:ClearAllPoints()
        strikeText:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, -6)
        strikeText:SetWidth(276)
        strikeText:SetSpacing(6)
        refreshedText:ClearAllPoints()
        refreshedText:SetPoint("TOPLEFT", strikeText, "BOTTOMLEFT", 0, -6)
        refreshedText:SetJustifyH("LEFT")
        refreshedText:SetSpacing(6)
        refreshButton:ClearAllPoints()
        refreshButton:SetSize(72, 18)
        refreshButton:SetPoint("RIGHT", collapseButton, "LEFT", -6, 0)
        refreshButton:Show()
        refreshButton.label:Show()
        PaintButton(refreshButton, true)
    else
        panel:SetBackdropColor(0.06, 0.06, 0.06, 0.78)
        panel:SetBackdropBorderColor(0, 0, 0, 1)
        refreshedText:Hide()
        progressText:ClearAllPoints()
        progressText:SetPoint("TOPLEFT", 14, -34)
        strikeText:ClearAllPoints()
        strikeText:SetPoint("TOPLEFT", strikeLabel, "BOTTOMLEFT", 0, -2)
        strikeText:SetWidth(260)
        strikeText:SetSpacing(0)
        progressText:SetSpacing(0)
        refreshedText:SetSpacing(0)
        refreshButton:ClearAllPoints()
        refreshButton:SetSize(96, 20)
        refreshButton:SetPoint("BOTTOMRIGHT", -12, 12)
        refreshButton:Show()
        refreshButton.label:Show()
        PaintButton(refreshButton, false)
    end
end

local function ToggleCollapsed()
    DB().collapsed = not DB().collapsed
    ApplyLayout()
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
    if not db.layout then
        db.collapsed = false
        db.layout = 2
    end
    ApplyLayout()
end

local function CreatePanel()
    panel = CreateFrame("Frame", "CosmicSlayerFrame", UIParent, "BackdropTemplate")
    panel:SetSize(300, EXPANDED_HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetBackdrop({
        bgFile = FLAT,
        edgeFile = FLAT,
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.78)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
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

    closeButton = MarkButton("CosmicSlayerClose", function()
        panel:Hide()
    end)
    closeButton:SetPoint("TOPRIGHT", -8, -8)
    closeButton.line(10, math.rad(45), 0)
    closeButton.line(10, math.rad(-45), 0)

    collapseButton = MarkButton("CosmicSlayerCollapse", ToggleCollapsed)
    collapseButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    collapseButton.line(7, math.rad(42), -2)
    collapseButton.line(7, math.rad(-42), 2)

    titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("TOPLEFT", 14, -10)
    titleText:SetText("Cosmic Slayer")
    titleText:SetTextColor(0.9, 0.92, 0.94)
    AddDetail(titleText)

    progressText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    progressText:SetPoint("TOPLEFT", 14, -34)
    progressText:SetTextColor(0.92, 0.94, 0.96)

    strikeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strikeLabel:SetPoint("TOPLEFT", 14, -56)
    strikeLabel:SetText("Current strike")
    strikeLabel:SetTextColor(0.55, 0.62, 0.68)
    AddDetail(strikeLabel)

    strikeText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strikeText:SetPoint("TOPLEFT", strikeLabel, "BOTTOMLEFT", 0, -2)
    strikeText:SetWidth(260)
    strikeText:SetJustifyH("LEFT")
    strikeText:SetWordWrap(true)

    strikeMeta = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    strikeMeta:SetPoint("TOPLEFT", strikeText, "BOTTOMLEFT", 0, -2)
    strikeMeta:SetWidth(260)
    strikeMeta:SetJustifyH("LEFT")
    AddDetail(strikeMeta)

    refreshedText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    refreshedText:SetPoint("BOTTOMLEFT", 12, 8)
    refreshedText:SetWidth(200)
    refreshedText:SetJustifyH("LEFT")
    refreshedText:SetText("Not refreshed yet")

    local y = -128
    for _, zone in ipairs(ZONES) do
        local header = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        header:SetPoint("TOPLEFT", 14, y)
        header:SetText(zone.label)
        zoneHeaders[zone.mapID] = header
        AddDetail(header)
        y = y - 18
        for _, key in ipairs(zone.bosses) do
            local row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row:SetPoint("TOPLEFT", 28, y)
            row:SetJustifyH("LEFT")
            rows[key] = row
            AddDetail(row)
            y = y - 18
        end
        y = y - 8
    end

    AddDetail(MakeCheck("Raid warning sound", "sound", y - 4))
    AddDetail(checks.sound)
    AddDetail(MakeCheck("Chat message", "chat", y - 32))
    AddDetail(checks.chat)
    AddDetail(MakeCheck("", "waypoint", y - 60))
    checks.waypoint:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("When checked, set a waypoint automatically when a watched boss is up.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    checks.waypoint:HookScript("OnLeave", GameTooltip_Hide)

    waypointButton = FlatButton("Set waypoint", 140)
    waypointButton:SetPoint("LEFT", checks.waypoint, "RIGHT", 6, 0)
    waypointButton:SetScript("OnClick", SetWaypoint)
    AddDetail(waypointButton)

    trackButton = FlatButton("Track achievement", 180)
    trackButton:SetPoint("BOTTOM", 0, 40)
    trackButton:SetScript("OnClick", TrackAchievement)
    AddDetail(trackButton)

    refreshButton = FlatButton("Refresh", 96)
    refreshButton:SetPoint("BOTTOMRIGHT", -12, 12)
    refreshButton:SetScript("OnClick", Scan)

    ApplyLayout()
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
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("AREA_POIS_UPDATED")
frame:RegisterEvent("CRITERIA_UPDATE")
frame:RegisterEvent("CONTENT_TRACKING_UPDATE")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= "CosmicSlayer" then
            return
        end
        ApplySettings()
        inZone = InRightZone()
        RefreshPanel()
        return
    end
    if event == "CRITERIA_UPDATE" or event == "CONTENT_TRACKING_UPDATE" then
        RefreshPanel()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            if InRightZone() then
                Scan()
            else
                inZone = false
                RefreshPanel()
            end
        end)
        return
    end
    if InRightZone() then
        Scan()
    else
        inZone = false
        RefreshPanel()
    end
end)

C_Timer.NewTicker(POLL_SECONDS, function()
    if InRightZone() then
        Scan()
    else
        inZone = false
        RefreshPanel()
    end
end)

SLASH_COSMICSLAYER1 = "/cs"
SLASH_COSMICSLAYER2 = "/cosmicslayer"
SlashCmdList["COSMICSLAYER"] = TogglePanel
