local ACHIEVEMENT_ID = 62570
local ZONES = {
    { mapID = 2395, label = "Eversong Woods", short = "Eversong", bosses = { "Springclaw", "Croaker" } },
    { mapID = 2437, label = "Zul'Aman", short = "Zul'Aman", bosses = { "Grizzly" } },
}
-- Wowhead creature ids for the three Cosmic Slayer strike bosses.
-- Croaker's in-game name is Void-Corrupted Dart Frog; there is no NPC named Croaker.
local BOSSES = {
    { npcID = 263912, name = "Void-Corrupted Springclaw Patriarch", mapID = 2395, x = 0.530, y = 0.394 },
    { npcID = 252609, name = "Void-Corrupted Dart Frog", mapID = 2395, x = 0.560, y = 0.768 },
    { npcID = 256589, name = "Void-Corrupted Matriarch", mapID = 2437, x = 0.320, y = 0.716 },
}
local BOSS_BY_ID = {}
for _, boss in ipairs(BOSSES) do
    BOSS_BY_ID[boss.npcID] = boss
end
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
local COLLAPSED_HEIGHT = 76
local ICON = 18
local CROSSHAIR = 22
local EXPANDED_WIDTH = 340
local MIN_WIDTH = 320
local MAX_WIDTH = 640
local MAX_HEIGHT = 900
local FLAT = "Interface\\Buttons\\WHITE8X8"

local weekMap
local weekCheckedAt = 0
local LayoutBody
local ApplyPanelSize

local FONT_CANDIDATES = {
    { name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
    { name = "Friz Quadrata Cyrillic", file = "Fonts\\FRIZQT___CYR.TTF" },
    { name = "Arial Narrow", file = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", file = "Fonts\\MORPHEUS.TTF" },
    { name = "Morpheus Cyrillic", file = "Fonts\\MORPHEUS_CYR.TTF" },
    { name = "Skurri", file = "Fonts\\SKURRI.TTF" },
    { name = "Skurri Cyrillic", file = "Fonts\\SKURRI_CYR.TTF" },
    { name = "2002", file = "Fonts\\2002.TTF" },
    { name = "2002 Bold", file = "Fonts\\2002B.TTF" },
    { name = "AR Kai", file = "Fonts\\ARKai_T.ttf" },
    { name = "AR Kai C", file = "Fonts\\ARKai_C.ttf" },
    { name = "AR Hei", file = "Fonts\\ARHei.ttf" },
    { name = "bLEI", file = "Fonts\\bLEI00D.ttf" },
    { name = "bHEI", file = "Fonts\\bHEI00M.ttf" },
    { name = "bHEI Bold", file = "Fonts\\bHEI01B.ttf" },
    { name = "K Page Text", file = "Fonts\\K_Pagetext.TTF" },
    { name = "K Damage", file = "Fonts\\K_Damage.TTF" },
    { name = "Nimrod MT", file = "Fonts\\NIM_____.ttf" },
    { name = "bKAI", file = "Fonts\\bKAI00M.ttf" },
}
local LEGACY_FILES = {
    "Fonts\\FRIZQT__.TTF",
    "Fonts\\ARIALN.TTF",
    "Fonts\\MORPHEUS.TTF",
    "Fonts\\SKURRI.TTF",
}

local SOUNDS = {
    { name = "Warning horn", kit = "RAID_WARNING" },
    { name = "Ready check", kit = "READY_CHECK" },
    { name = "Alarm", kit = "ALARM_CLOCK_WARNING_2" },
    { name = "Boss emote", kit = "RAID_BOSS_EMOTE_WARNING" },
    { name = "Queue", kit = "PVP_THROUGH_QUEUE" },
}

local defaults = {
    sound = true,
    chat = true,
    screen = true,
    alertSound = "RAID_WARNING",
    waypoint = true,
    bossPing = true,
    locked = false,
    collapsed = false,
    alpha = 1,
    transparency = 0.78,
    collapsedTransparency = 0.10,
    bgR = 0.06,
    bgG = 0.06,
    bgB = 0.06,
    font = 1,
    fontSize = 12,
    width = EXPANDED_WIDTH,
    poll = 15,
}

local active = {}
local shown = {}
local bossAlerted = {}
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
local contentFonts = {}
local chromeFonts = {}
local settingsFrame
local settingsSwatch
local settingsButton
local lockButton
local resizeButton

local function TrackContent(fs)
    tinsert(contentFonts, fs)
    return fs
end

local function TrackChrome(fs)
    tinsert(chromeFonts, fs)
    return fs
end
local currentStrike
local currentStrikeSecret
local currentPin
local trackedPoi
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
    if not trackButton or not trackButton.icon then
        return
    end
    if IsAchievementTracked() then
        trackButton.icon:SetVertexColor(1, 0.86, 0.35)
    else
        trackButton.icon:SetVertexColor(1, 1, 1)
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

local function ApplyZoneList()
    if not panel then
        return
    end
    local collapsed = DB().collapsed
    for _, zone in ipairs(ZONES) do
        local show = (not collapsed) and (not weekMap or weekMap == zone.mapID)
        local header = zoneHeaders[zone.mapID]
        if header then
            header:SetText(zone.label)
            if weekMap == zone.mapID then
                header:SetTextColor(0.78, 0.86, 0.94)
            else
                header:SetTextColor(0.72, 0.76, 0.8)
            end
            if show then
                header:Show()
            else
                header:Hide()
            end
        end
        for _, key in ipairs(zone.bosses) do
            local row = rows[key]
            if row then
                if show then
                    row:Show()
                else
                    row:Hide()
                end
            end
        end
    end
end

local function RefreshPanel()
    if not panel then
        return
    end
    progressText:SetText(ProgressLine())
    if not lastScanClock then
        strikeText:SetText("Waiting for first scan")
        strikeText:SetTextColor(0.65, 0.65, 0.65)
        strikeMeta:SetText("Not refreshed yet")
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
        strikeMeta:SetText("Last refresh: " .. lastScanClock)
    end
    if refreshedText then
        if lastScanClock then
            refreshedText:SetText("Last refresh: " .. lastScanClock)
        else
            refreshedText:SetText("Not refreshed yet")
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
    ApplyZoneList()
    if LayoutBody and not DB().collapsed then
        LayoutBody()
    end
    RefreshTrackButton()
end

local function TrackStrike(poiID)
    if not poiID or issecretvalue(poiID) or not C_SuperTrack.SetSuperTrackedMapPin or not Enum or not Enum.SuperTrackingMapPinType then
        return false
    end
    C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, poiID)
    trackedPoi = poiID
    return true
end

local function AutoTrack(force)
    if not DB().waypoint then
        return
    end
    if not currentPin or not currentPin.poiID or issecretvalue(currentPin.poiID) then
        trackedPoi = nil
        return
    end
    if not force and trackedPoi == currentPin.poiID then
        return
    end
    TrackStrike(currentPin.poiID)
end

local function TrackCurrentStrike()
    if not currentPin or not currentPin.poiID or issecretvalue(currentPin.poiID) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r No strike to track.")
        return
    end
    if not TrackStrike(currentPin.poiID) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r Could not track that strike.")
    end
end

local function AlertSound()
    local db = DB()
    for _, sound in ipairs(SOUNDS) do
        if sound.kit == db.alertSound then
            return sound
        end
    end
    db.alertSound = SOUNDS[1].kit
    return SOUNDS[1]
end

local function PlayAlertSound()
    local kit = SOUNDKIT and SOUNDKIT[AlertSound().kit]
    if kit then
        PlaySound(kit, "Master")
    end
end

local function Alert(mapID, info, poiID)
    local db = DB()
    local boss = WatchedName(info.name) or info.name
    if db.chat then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r " .. info.name .. " is up.")
    end
    if db.screen and RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, "CS: " .. boss .. " is up", ChatTypeInfo.RAID_WARNING)
    end
    if db.sound then
        PlayAlertSound()
    end
end

local function BossFromText(text)
    if not text then
        return nil
    end
    for _, boss in ipairs(BOSSES) do
        if text:find(boss.name, 1, true) then
            return boss
        end
    end
end

local function NpcIDFromGUID(guid)
    if not guid or issecretvalue(guid) or type(guid) ~= "string" then
        return nil
    end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then
        return nil
    end
    return tonumber(id)
end

local function AlertBoss(boss, poiID)
    if not DB().bossPing or bossAlerted[boss.npcID] then
        return
    end
    bossAlerted[boss.npcID] = true
    local db = DB()
    if db.chat then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc45cffCS|r " .. boss.name .. " has spawned.")
    end
    if db.screen and RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, "CS: " .. boss.name .. " has spawned", ChatTypeInfo.RAID_WARNING)
    end
    if db.sound then
        PlayAlertSound()
    end
    if not poiID or issecretvalue(poiID) then
        poiID = currentPin and currentPin.poiID
    end
    TrackStrike(poiID)
end

local function SeeBoss(found, boss, poiID)
    if not boss then
        return
    end
    found[boss.npcID] = true
    AlertBoss(boss, poiID)
end

local function ObserveBosses()
    local found = {}
    if C_VignetteInfo and C_VignetteInfo.GetVignettes then
        local vignettes = C_VignetteInfo.GetVignettes()
        if vignettes and not issecretvalue(vignettes) then
            for _, vignetteGUID in ipairs(vignettes) do
                if not issecretvalue(vignetteGUID) then
                    local info = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
                    if info and not issecretvalue(info) then
                        local vignetteName = info.name
                        if not vignetteName or issecretvalue(vignetteName) then
                            vignetteName = nil
                        end
                        local boss = BOSS_BY_ID[NpcIDFromGUID(info.objectGUID)] or BossFromText(vignetteName)
                        if boss then
                            SeeBoss(found, boss)
                        end
                    end
                end
            end
        end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates and not issecretvalue(plates) then
            for _, plate in ipairs(plates) do
                if plate and not issecretvalue(plate) then
                    local unit = plate.namePlateUnitToken
                    if not unit or issecretvalue(unit) then
                        unit = plate.UnitFrame and plate.UnitFrame.unit
                    end
                    if unit and not issecretvalue(unit) then
                        local guidOK, guid = pcall(UnitGUID, unit)
                        local boss = guidOK and BOSS_BY_ID[NpcIDFromGUID(guid)]
                        if not boss then
                            local nameOK, name = pcall(UnitName, unit)
                            if nameOK and name and not issecretvalue(name) then
                                boss = BossFromText(name)
                            end
                        end
                        SeeBoss(found, boss)
                    end
                end
            end
        end
    end
    return found
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
    local pinPOI
    local pinRank = -1
    local strikeZone
    local poiBosses = {}
    local function Remember(mapID, info, rank, id)
        if not id or issecretvalue(id) or rank < pinRank then
            return
        end
        pinPOI = id
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
                            Remember(mapID, info, WatchedName(plainName) and 4 or 3, id)
                            strikeZone = label or strikeZone
                        elseif plainName and (IsIncursionText(plainName) or IsIncursionText(plainDesc)) and not incursionName then
                            incursionName = plainName
                            Remember(mapID, info, 2, id)
                            strikeZone = label or strikeZone
                        elseif plainName and currentEvent and not currentSeen[plainName] then
                            currentSeen[plainName] = true
                            tinsert(currentNames, plainName)
                            Remember(mapID, info, 1, id)
                            strikeZone = label or strikeZone
                        elseif not plainName and info.name and issecretvalue(info.name) and not secretStrike then
                            secretStrike = info.name
                            Remember(mapID, info, 0, id)
                            strikeZone = label or strikeZone
                        end
                        local key = plainName and WatchedName(plainName)
                        if key and not seen[key] then
                            seen[key] = plainName
                            Remember(mapID, info, 4, id)
                            if not active[key] then
                                active[key] = true
                                Alert(mapID, info, id)
                            end
                        end
                        if DB().bossPing then
                            local boss = BossFromText(plainName) or BossFromText(plainDesc)
                            if boss then
                                SeeBoss(poiBosses, boss, id)
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
    if pinPOI then
        currentPin = { poiID = pinPOI }
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
    local seenBosses
    if DB().bossPing then
        seenBosses = ObserveBosses()
        for npcID in pairs(poiBosses) do
            seenBosses[npcID] = true
        end
        for npcID in pairs(bossAlerted) do
            if not seenBosses[npcID] then
                bossAlerted[npcID] = nil
            end
        end
    end
    AutoTrack()
    shown = seen
    RefreshPanel()
end

local function MakeCheck(label, key, y, parent)
    parent = parent or panel
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", 12, y)
    box:SetScript("OnClick", function(self)
        DB()[key] = self:GetChecked() and true or false
    end)
    checks[key] = box
    if not label or label == "" then
        return box
    end
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetText(label)
    box.label = text
    if parent == panel then
        TrackContent(text)
    else
        TrackChrome(text)
    end
    return text
end

local function AddDetail(widget)
    if widget then
        tinsert(detailWidgets, widget)
    end
    return widget
end

local function IconButton(name, onClick, hint)
    local button = CreateFrame("Button", name, panel)
    button:SetSize(ICON, ICON)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAlpha(0.92)
    button.icon = icon
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture(FLAT)
    highlight:SetVertexColor(1, 0.9, 0.55, 0.35)
    button:SetHighlightTexture(highlight)
    button:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(1)
        if hint and GameTooltip then
            local text = hint
            if type(hint) == "function" then
                text = hint()
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(0.92)
        if hint and GameTooltip_Hide then
            GameTooltip_Hide()
        end
    end)
    button:SetScript("OnClick", onClick)
    if type(hint) == "string" then
        button.text = hint
    end
    return button
end

local function UseTexture(button, path, inset)
    button.icon:SetTexture(path)
    inset = inset or 0
    button.icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
end

local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"

local function UseLock(button, locked)
    button:SetSize(ICON, ICON)
    button.icon:SetTexture(LOCK_ICON)
    button.icon:SetTexCoord(0.0546875, 0.9453125, 0.0703125, 0.9453125)
    if locked then
        button.icon:SetVertexColor(0.95, 0.93, 0.88)
    else
        button.icon:SetVertexColor(0.55, 0.58, 0.62)
    end
end
local function UseAtlas(button, atlas, fallback)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        button.icon:SetAtlas(atlas)
        return
    end
    if fallback then
        UseTexture(button, fallback)
    end
end

local function UseCrosshair(button)
    button:SetSize(CROSSHAIR, CROSSHAIR)
    button:SetClipsChildren(true)
    button.icon:ClearAllPoints()
    button.icon:SetVertexColor(1, 1, 1)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("TargetCrosshairs") then
        button.icon:SetAtlas("TargetCrosshairs")
        local scale = CROSSHAIR / 0.4
        button.icon:SetSize(scale, scale)
        button.icon:SetPoint("CENTER", (0.5 - 0.3) * scale, (0.3 - 0.5) * scale)
        return
    end
    button.icon:SetTexture("Interface\\Cursor\\Crosshairs")
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(CROSSHAIR, CROSSHAIR)
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

local function FlatButton(text, width, parent)
    local button = CreateFrame("Button", nil, parent or panel, "BackdropTemplate")
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
    TrackChrome(label)
    PaintButton(button, false)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.17, 0.14, 1)
        self:SetBackdropBorderColor(0.9, 0.78, 0.35, 1)
        TintButtonText(self, 1, 0.95, 0.75)
    end)
    button:SetScript("OnLeave", function(self)
        if not self.quiet then
            self:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
            self:SetBackdropBorderColor(0, 0, 0, 1)
        else
            self:SetBackdropColor(0, 0, 0, 0)
            self:SetBackdropBorderColor(0, 0, 0, 0)
        end
        TintButtonText(self, 0.86, 0.88, 0.9)
    end)
    return button
end

local fontChoices
local fontProbe

local function FontLoads(file)
    if type(file) ~= "string" or file == "" then
        return false
    end
    local parent = settingsFrame or panel
    if not parent or not parent.CreateFontString then
        return true
    end
    if not fontProbe then
        fontProbe = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fontProbe:Hide()
    end
    local ok, loaded = pcall(fontProbe.SetFont, fontProbe, file, 12, "")
    return ok and loaded and true or false
end

local function FontChoices(refresh)
    if fontChoices and not refresh then
        return fontChoices
    end
    local choices = {}
    local seen = {}
    local function add(name, file)
        if type(file) ~= "string" or seen[file] or not FontLoads(file) then
            return
        end
        seen[file] = true
        tinsert(choices, { name = name or file, file = file })
    end
    for _, font in ipairs(FONT_CANDIDATES) do
        add(font.name, font.file)
    end
    local media
    if type(LibStub) == "function" then
        local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and lib and lib.List and lib.Fetch then
            media = lib
        end
    end
    if not media and type(ElvUI) == "table" and type(ElvUI[1]) == "table" and type(ElvUI[1].Libs) == "table" then
        media = ElvUI[1].Libs.LSM
    end
    if media and media.List and media.Fetch then
        local list = media:List("font")
        if list then
            for _, name in ipairs(list) do
                add(name, media:Fetch("font", name))
            end
        end
    end
    table.sort(choices, function(a, b)
        if a.name == b.name then
            return a.file < b.file
        end
        return a.name < b.name
    end)
    fontChoices = choices
    return choices
end

local function Face()
    local db = DB()
    if type(db.fontFile) ~= "string" then
        db.fontFile = LEGACY_FILES[db.font] or LEGACY_FILES[1]
    end
    local choices = FontChoices()
    for _, font in ipairs(choices) do
        if font.file == db.fontFile then
            return font
        end
    end
    if choices[1] then
        db.fontFile = choices[1].file
        return choices[1]
    end
    return { name = "Friz Quadrata", file = LEGACY_FILES[1] }
end

local function LineHeight()
    return (DB().fontSize or 12) + 3
end

local function ZoneListTop()
    local line = LineHeight()
    return 10 + line + 6 + line + 10 + line + 2 + line + 2 + line + 12
end

local function ContentHeight()
    local line = LineHeight()
    local y = ZoneListTop()
    local shown = false
    for _, zone in ipairs(ZONES) do
        if not weekMap or weekMap == zone.mapID then
            shown = true
            y = y + line + (#zone.bosses * line) + 6
        end
    end
    if not shown then
        y = y + line
    end
    return y + 10
end

local function CollapsedHeight()
    local size = DB().fontSize or 12
    return math.max(COLLAPSED_HEIGHT, 12 + (size + 8) * 3)
end

function LayoutBody()
    local line = LineHeight()
    local y = -ZoneListTop()
    for _, zone in ipairs(ZONES) do
        local header = zoneHeaders[zone.mapID]
        if header and (not weekMap or weekMap == zone.mapID) then
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 14, y)
            header:SetJustifyH("LEFT")
            header:SetSpacing(0)
            y = y - line
            for _, key in ipairs(zone.bosses) do
                local row = rows[key]
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 28, y)
                row:SetJustifyH("LEFT")
                row:SetSpacing(0)
                y = y - line
            end
            y = y - 6
        end
    end
end

local function ApplyStyle()
    if not panel then
        return
    end
    local db = DB()
    local face = Face()
    local size = db.fontSize or 12
    for _, fs in ipairs(contentFonts) do
        fs:SetFont(face.file, size, "")
    end
    for _, fs in ipairs(chromeFonts) do
        if not fs.previewFile then
            fs:SetFont(face.file, 12, "")
        end
    end
    if db.collapsed then
        ApplyPanelSize()
        panel:SetBackdropColor(db.bgR, db.bgG, db.bgB, db.collapsedTransparency or 0.10)
        panel:SetBackdropBorderColor(0, 0, 0, 0)
    else
        ApplyPanelSize()
        panel:SetBackdropColor(db.bgR, db.bgG, db.bgB, db.transparency or 0.78)
        panel:SetBackdropBorderColor(0, 0, 0, 1)
        LayoutBody()
    end
    panel:SetAlpha(db.alpha or 1)
    if settingsFrame then
        settingsFrame:SetBackdropColor(db.bgR, db.bgG, db.bgB, db.transparency or 0.78)
        settingsFrame:SetBackdropBorderColor(0, 0, 0, 1)
        settingsFrame:SetAlpha(db.alpha or 1)
    end
    if settingsSwatch then
        settingsSwatch:SetBackdropColor(db.bgR, db.bgG, db.bgB, 1)
    end
end

local function Percent(value)
    return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
end

local pollTicker

local function Tick()
    if InRightZone() then
        Scan()
    else
        inZone = false
        RefreshPanel()
    end
end

local function StartPoll()
    local seconds = DB().poll or 15
    if pollTicker then
        pollTicker:Cancel()
        pollTicker = nil
    end
    pollTicker = C_Timer.NewTicker(seconds, Tick)
end

local function MakeSlider(parent, label, minValue, maxValue, step, key, y, display)
    local caption = TrackChrome(parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    caption:SetPoint("TOPLEFT", 12, y)
    caption:SetText(label)
    caption:SetTextColor(0.7, 0.74, 0.78)
    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 12, y - 16)
    slider:SetSize(140, 14)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetBackdrop({
        bgFile = FLAT,
        edgeFile = FLAT,
        edgeSize = 1,
    })
    slider:SetBackdropColor(0.12, 0.12, 0.12, 1)
    slider:SetBackdropBorderColor(0, 0, 0, 1)
    slider:SetThumbTexture(FLAT)
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(8, 14)
        thumb:SetVertexColor(0.82, 0.86, 0.92, 1)
    end
    local valueText = TrackChrome(parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valueText:SetTextColor(0.86, 0.88, 0.9)
    slider.text = label
    slider:SetScript("OnValueChanged", function(_, value)
        if key == "fontSize" or key == "poll" then
            value = math.floor(value + 0.5)
        end
        if key == "poll" then
            value = math.max(minValue, math.min(maxValue, value))
        end
        DB()[key] = value
        valueText:SetText(display(value))
        if key == "poll" then
            StartPoll()
        else
            ApplyStyle()
        end
    end)
    slider:SetValue(DB()[key])
    return slider
end

local function PickBackground()
    local db = DB()
    local function apply(r, g, b)
        db.bgR, db.bgG, db.bgB = r, g, b
        ApplyStyle()
    end
    local previous = { r = db.bgR, g = db.bgG, b = db.bgB }
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = db.bgR,
            g = db.bgG,
            b = db.bgB,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                apply(r, g, b)
            end,
            cancelFunc = function(prev)
                local restore = prev or previous
                apply(restore.r, restore.g, restore.b)
            end,
        })
        return
    end
    if not ColorPickerFrame then
        return
    end
    ColorPickerFrame:SetColorRGB(db.bgR, db.bgG, db.bgB)
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.func = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply(r, g, b)
    end
    ColorPickerFrame:Show()
end

local function CreateSettings()
    settingsFrame = CreateFrame("Frame", "CosmicSlayerSettings", UIParent, "BackdropTemplate")
    settingsFrame:SetSize(248, 540)
    settingsFrame:SetPoint("TOPLEFT", panel, "TOPRIGHT", 6, 0)
    settingsFrame:SetBackdrop({
        bgFile = FLAT,
        edgeFile = FLAT,
        edgeSize = 1,
    })
    settingsFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
    settingsFrame:SetBackdropBorderColor(0, 0, 0, 1)
    settingsFrame:Hide()

    local title = TrackChrome(settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Settings")
    title:SetTextColor(0.9, 0.92, 0.94)

    local function Section(text, y)
        local label = TrackChrome(settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
        label:SetPoint("TOPLEFT", 12, y)
        label:SetText(text)
        label:SetTextColor(0.77, 0.36, 1)
        return label
    end

    local function Tip(box, text)
        box:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        box:HookScript("OnLeave", GameTooltip_Hide)
    end

    Section("Alerts", -28)
    MakeCheck("Chat message", "chat", -46, settingsFrame)
    Tip(checks.chat, "Print the alert in chat.")
    MakeCheck("Screen banner", "screen", -74, settingsFrame)
    Tip(checks.screen, "Show large text in the middle of the screen. This chooses how an alert looks, not which event sends it.")
    MakeCheck("Play sound", "sound", -102, settingsFrame)
    Tip(checks.sound, "Play the sound selected below when an alert fires.")

    local soundLabel = TrackChrome(settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    soundLabel:SetPoint("TOPLEFT", 12, -128)
    soundLabel:SetText("Sound")
    soundLabel:SetTextColor(0.7, 0.74, 0.78)

    local soundButton = FlatButton(AlertSound().name, 220, settingsFrame)
    soundButton:SetPoint("TOPLEFT", 12, -144)
    local soundMenu
    local soundRows = {}
    local function ShowSoundMenu()
        if not soundMenu then
            soundMenu = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
            soundMenu:SetFrameStrata("DIALOG")
            soundMenu:SetBackdrop({
                bgFile = FLAT,
                edgeFile = FLAT,
                edgeSize = 1,
            })
            soundMenu:SetBackdropColor(0.06, 0.06, 0.06, 0.96)
            soundMenu:SetBackdropBorderColor(0, 0, 0, 1)
            soundMenu:Hide()
        end
        for index, sound in ipairs(SOUNDS) do
            local row = soundRows[index]
            if not row then
                row = FlatButton("", 212, soundMenu)
                soundRows[index] = row
                row:SetScript("OnClick", function(self)
                    local db = DB()
                    db.alertSound = self.soundKit
                    soundButton.text = self.soundName
                    soundButton.label:SetText(self.soundName)
                    soundMenu:Hide()
                    PlayAlertSound()
                end)
            end
            row.soundKit = sound.kit
            row.soundName = sound.name
            row.text = sound.name
            row.label:SetText(sound.name)
            if sound.kit == DB().alertSound then
                row.label:SetTextColor(1, 0.86, 0.35)
            else
                row.label:SetTextColor(0.86, 0.88, 0.9)
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * 22))
            row:SetSize(212, 20)
            row:Show()
        end
        soundMenu:SetSize(220, #SOUNDS * 22 + 8)
        soundMenu:ClearAllPoints()
        soundMenu:SetPoint("TOPLEFT", soundButton, "BOTTOMLEFT", 0, -2)
        soundMenu:Show()
    end
    soundButton:SetScript("OnClick", function()
        if soundMenu and soundMenu:IsShown() then
            soundMenu:Hide()
            return
        end
        ShowSoundMenu()
    end)
    Tip(soundButton, "Choose the alert sound. The chosen sound plays when you pick it.")

    Section("Tracking", -176)
    MakeCheck("Auto track", "waypoint", -194, settingsFrame)
    Tip(checks.waypoint, "Select the current strike on the map when that strike changes. The game drops the pin when the strike ends.")
    checks.waypoint:HookScript("OnClick", function(self)
        if self:GetChecked() then
            AutoTrack(true)
        end
    end)
    MakeCheck("Boss spawn ping", "bossPing", -222, settingsFrame)
    Tip(checks.bossPing, "When the boss creature spawns, send an alert and track that strike. Separate from Screen banner, which only controls how alerts are shown.")

    Section("Appearance", -250)

    local bgLabel = TrackChrome(settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    bgLabel:SetPoint("TOPLEFT", 12, -268)
    bgLabel:SetText("Background")
    bgLabel:SetTextColor(0.7, 0.74, 0.78)

    settingsSwatch = CreateFrame("Button", nil, settingsFrame, "BackdropTemplate")
    settingsSwatch:SetSize(44, 18)
    settingsSwatch:SetPoint("LEFT", bgLabel, "RIGHT", 10, 0)
    settingsSwatch:SetBackdrop({
        bgFile = FLAT,
        edgeFile = FLAT,
        edgeSize = 1,
    })
    settingsSwatch:SetBackdropBorderColor(0, 0, 0, 1)
    settingsSwatch.text = "Background"
    settingsSwatch:SetScript("OnClick", PickBackground)

    MakeSlider(settingsFrame, "Transparency", 0.05, 1, 0.01, "transparency", -292, Percent)
    MakeSlider(settingsFrame, "Collapsed transparency", 0.05, 1, 0.01, "collapsedTransparency", -328, Percent)
    MakeSlider(settingsFrame, "Frame alpha", 0.15, 1, 0.01, "alpha", -364, Percent)

    local fontLabel = TrackChrome(settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    fontLabel:SetPoint("TOPLEFT", 12, -400)
    fontLabel:SetText("Font")
    fontLabel:SetTextColor(0.7, 0.74, 0.78)

    local fontButton = FlatButton(Face().name, 180, settingsFrame)
    fontButton:SetPoint("TOPLEFT", 12, -416)
    local fontMenu
    local fontRows = {}
    local function ShowFontMenu()
        local choices = FontChoices(true)
        if not fontMenu then
            fontMenu = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
            fontMenu:SetFrameStrata("DIALOG")
            fontMenu:SetBackdrop({
                bgFile = FLAT,
                edgeFile = FLAT,
                edgeSize = 1,
            })
            fontMenu:SetBackdropColor(0.06, 0.06, 0.06, 0.96)
            fontMenu:SetBackdropBorderColor(0, 0, 0, 1)
            fontMenu.scroll = CreateFrame("ScrollFrame", "CosmicSlayerFontScroll", fontMenu)
            fontMenu.scroll:SetPoint("TOPLEFT", 4, -4)
            fontMenu.scroll:SetPoint("BOTTOMRIGHT", -10, 4)
            fontMenu.scroll:EnableMouseWheel(true)
            fontMenu.child = CreateFrame("Frame", nil, fontMenu.scroll)
            fontMenu.scroll:SetScrollChild(fontMenu.child)
            fontMenu.bar = fontMenu:CreateTexture(nil, "OVERLAY")
            fontMenu.bar:SetTexture(FLAT)
            fontMenu.bar:SetVertexColor(0.82, 0.86, 0.92, 0.9)
            fontMenu:EnableMouseWheel(true)
            fontMenu:Hide()
        end
        local function ScrollFontList(delta)
            local scroll = fontMenu.scroll
            local child = scroll:GetScrollChild()
            local view = scroll:GetHeight() or 0
            local full = (child and child:GetHeight()) or 0
            local maxScroll = math.max(full - view, 0)
            local current = scroll:GetVerticalScroll() or 0
            local nextScroll = current - (delta or 0) * 44
            if nextScroll < 0 then
                nextScroll = 0
            end
            if nextScroll > maxScroll then
                nextScroll = maxScroll
            end
            scroll:SetVerticalScroll(nextScroll)
            if maxScroll > 0 then
                local barH = math.max(view * (view / full), 18)
                local travel = math.max(view - barH, 0)
                fontMenu.bar:SetSize(4, barH)
                fontMenu.bar:ClearAllPoints()
                fontMenu.bar:SetPoint("TOPRIGHT", -3, -4 - travel * (nextScroll / maxScroll))
                fontMenu.bar:Show()
            else
                fontMenu.bar:Hide()
            end
        end
        fontMenu.scroll:SetScript("OnMouseWheel", function(_, delta)
            ScrollFontList(delta)
        end)
        fontMenu:SetScript("OnMouseWheel", function(_, delta)
            ScrollFontList(delta)
        end)
        for _, row in ipairs(fontRows) do
            row:Hide()
        end
        for index, font in ipairs(choices) do
            local row = fontRows[index]
            if not row then
                row = FlatButton("", 172, fontMenu.child)
                fontRows[index] = row
                row:SetScript("OnClick", function(self)
                    local db = DB()
                    db.fontFile = self.fontFile
                    db.fontName = self.fontName
                    fontButton.text = self.fontName
                    fontButton.label:SetText(self.fontName)
                    fontMenu:Hide()
                    ApplyStyle()
                end)
            end
            row.fontFile = font.file
            row.fontName = font.name
            row.text = font.name
            row.label:SetText(font.name)
            row.label.previewFile = font.file
            pcall(row.label.SetFont, row.label, font.file, 12, "")
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -((index - 1) * 22))
            row:SetSize(164, 20)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta)
                ScrollFontList(delta)
            end)
            row:Show()
        end
        fontMenu.child:SetSize(164, math.max(#choices * 22, 1))
        local shown = math.min(math.max(#choices, 1), 10)
        local menuHeight = shown * 22 + 8
        fontMenu:SetSize(180, menuHeight)
        fontMenu.scroll:SetSize(166, menuHeight - 8)
        fontMenu:ClearAllPoints()
        fontMenu:SetPoint("TOPLEFT", fontButton, "BOTTOMLEFT", 0, -2)
        ScrollFontList(0)
        ApplyStyle()
        fontMenu:Show()
    end
    fontButton:SetScript("OnClick", function()
        if fontMenu and fontMenu:IsShown() then
            fontMenu:Hide()
            return
        end
        ShowFontMenu()
    end)

    MakeSlider(settingsFrame, "Font size", 10, 20, 1, "fontSize", -440, function(value)
        return tostring(math.floor(value + 0.5))
    end)

    Section("Scanning", -476)
    MakeSlider(settingsFrame, "Poll", 1, 60, 1, "poll", -494, function(value)
        return tostring(math.floor(value + 0.5)) .. "s"
    end)
    settingsFrame:SetHeight(540)
end

local sizing

local function MinPanelWidth()
    local size = DB().fontSize or 12
    local titleWidth = math.ceil(size * 11.5)
    return math.max(MIN_WIDTH, 14 + titleWidth + 12 + 156)
end

local function PanelWidth()
    local width = DB().width or EXPANDED_WIDTH
    local minWidth = MinPanelWidth()
    if width < minWidth then
        width = minWidth
    end
    if width > MAX_WIDTH then
        width = MAX_WIDTH
    end
    return width
end

local function PanelHeight()
    local minHeight = ContentHeight()
    local height = DB().height or minHeight
    if height < minHeight then
        height = minHeight
    end
    if height > MAX_HEIGHT then
        height = MAX_HEIGHT
    end
    return height
end

local function PinTopLeft()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not left or not top then
        return
    end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    DB().point = { "TOPLEFT", "BOTTOMLEFT", left, top }
end

function ApplyPanelSize()
    if not panel or sizing then
        return
    end
    PinTopLeft()
    if DB().collapsed then
        panel:SetSize(PanelWidth(), CollapsedHeight())
    else
        panel:SetSize(PanelWidth(), PanelHeight())
    end
end

local function SavePanelSize()
    local db = DB()
    db.width = panel:GetWidth()
    db.height = panel:GetHeight()
    db.width = PanelWidth()
    db.height = PanelHeight()
    ApplyPanelSize()
end

local function ApplyResizeGrip()
    if not panel or not resizeButton then
        return
    end
    local usable = not DB().locked and not DB().collapsed
    panel:SetResizable(usable and true or false)
    if panel.SetResizeBounds then
        panel:SetResizeBounds(MinPanelWidth(), ContentHeight(), MAX_WIDTH, MAX_HEIGHT)
    end
    if usable then
        resizeButton:Show()
    else
        resizeButton:Hide()
    end
end

local function ApplyLayout()
    if not panel or not collapseButton then
        return
    end
    local collapsed = DB().collapsed
    ApplyPanelSize()
    for _, widget in ipairs(detailWidgets) do
        if collapsed then
            widget:Hide()
        else
            widget:Show()
        end
    end
    if collapsed then
        UseTexture(collapseButton, "Interface\\Buttons\\UI-Panel-ExpandButton-Up", 0.2)
    else
        UseTexture(collapseButton, "Interface\\Buttons\\UI-Panel-CollapseButton-Up", 0.2)
    end
    if collapsed then
        if settingsFrame then
            settingsFrame:Hide()
        end
        refreshedText:Show()
        progressText:ClearAllPoints()
        progressText:SetWidth(math.max(40, PanelWidth() - 174))
        progressText:SetJustifyH("LEFT")
        progressText:SetJustifyV("TOP")
        progressText:SetPoint("TOPLEFT", 12, -8)
        progressText:SetSpacing(6)
        strikeText:ClearAllPoints()
        strikeText:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, -10)
        strikeText:SetWidth(PanelWidth() - 24)
        strikeText:SetSpacing(6)
        refreshedText:ClearAllPoints()
        refreshedText:SetPoint("TOPLEFT", strikeText, "BOTTOMLEFT", 0, -6)
        refreshedText:SetJustifyH("LEFT")
        refreshedText:SetSpacing(6)
        refreshButton:Show()
    else
        refreshedText:Hide()
        progressText:ClearAllPoints()
        progressText:SetWidth(PanelWidth() - 28)
        progressText:SetJustifyH("LEFT")
        progressText:SetSpacing(0)
        progressText:SetPoint("TOPLEFT", 14, -(10 + LineHeight() + 6))
        strikeLabel:ClearAllPoints()
        strikeLabel:SetJustifyH("LEFT")
        strikeLabel:SetSpacing(0)
        strikeLabel:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, -10)
        strikeText:ClearAllPoints()
        strikeText:SetPoint("TOPLEFT", strikeLabel, "BOTTOMLEFT", 0, -2)
        strikeText:SetWidth(PanelWidth() - 28)
        strikeText:SetJustifyH("LEFT")
        strikeMeta:SetWidth(PanelWidth() - 28)
        strikeMeta:SetJustifyH("LEFT")
        strikeMeta:SetSpacing(0)
        strikeText:SetSpacing(0)
        progressText:SetSpacing(0)
        refreshedText:SetSpacing(0)
        refreshButton:Show()
    end
    waypointButton:ClearAllPoints()
    waypointButton:SetSize(CROSSHAIR, CROSSHAIR)
    waypointButton:SetPoint("RIGHT", refreshButton, "LEFT", -2, 0)
    waypointButton:Show()
    ApplyZoneList()
    ApplyStyle()
    ApplyResizeGrip()
end

local function ToggleCollapsed()
    DB().collapsed = not DB().collapsed
    ApplyLayout()
end

local function ApplyLock()
    if not panel or not lockButton then
        return
    end
    local locked = DB().locked and true or false
    panel:SetMovable(not locked)
    if locked then
        panel:RegisterForDrag()
    else
        panel:RegisterForDrag("LeftButton")
    end
    UseLock(lockButton, locked)
    ApplyResizeGrip()
end

local function ToggleLock()
    local db = DB()
    db.locked = not db.locked
    ApplyLock()
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
    ApplyLock()
end

local function CreatePanel()
    panel = CreateFrame("Frame", "CosmicSlayerFrame", UIParent, "BackdropTemplate")
    panel:SetSize(EXPANDED_WIDTH, 220)
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
    panel:SetScript("OnDragStart", function(self)
        if DB().locked then
            return
        end
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if sizing then
            return
        end
        PinTopLeft()
    end)
    panel:SetResizable(true)
    if panel.SetResizeBounds then
        panel:SetResizeBounds(MIN_WIDTH, 180, MAX_WIDTH, MAX_HEIGHT)
    end

    resizeButton = CreateFrame("Button", "CosmicSlayerResize", panel)
    resizeButton:SetSize(ICON, ICON)
    resizeButton:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    local resizeHighlight = resizeButton:CreateTexture(nil, "HIGHLIGHT")
    resizeHighlight:SetAllPoints()
    resizeHighlight:SetTexture(FLAT)
    resizeHighlight:SetVertexColor(1, 0.9, 0.55, 0.35)
    resizeButton:SetHighlightTexture(resizeHighlight)
    resizeButton:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(resizeButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Resize", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    resizeButton:SetScript("OnLeave", function()
        if GameTooltip_Hide then
            GameTooltip_Hide()
        end
    end)
    resizeButton:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or DB().locked or DB().collapsed then
            return
        end
        sizing = true
        PinTopLeft()
        panel:StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then
            return
        end
        panel:StopMovingOrSizing()
        sizing = false
        if DB().locked or DB().collapsed then
            return
        end
        SavePanelSize()
    end)
    panel:Hide()
    panel:HookScript("OnHide", function()
        if settingsFrame then
            settingsFrame:Hide()
        end
    end)

    closeButton = IconButton("CosmicSlayerClose", function()
        panel:Hide()
    end, "Close")
    closeButton:SetPoint("TOPRIGHT", -8, -8)
    UseAtlas(closeButton, "common-icon-redx")

    collapseButton = IconButton("CosmicSlayerCollapse", ToggleCollapsed, function()
        if DB().collapsed then
            return "Expand"
        end
        return "Collapse"
    end)
    collapseButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    UseTexture(collapseButton, "Interface\\Buttons\\UI-Panel-CollapseButton-Up", 0.2)

    lockButton = IconButton("CosmicSlayerLock", ToggleLock, function()
        if DB().locked then
            return "Unlock"
        end
        return "Lock"
    end)
    lockButton:SetPoint("RIGHT", collapseButton, "LEFT", -2, 0)
    UseLock(lockButton, false)

    settingsButton = IconButton("CosmicSlayerSettingsButton", function()
        if settingsFrame:IsShown() then
            settingsFrame:Hide()
        else
            settingsFrame:Show()
        end
    end, "Settings")
    settingsButton:SetPoint("RIGHT", lockButton, "LEFT", -2, 0)
    UseTexture(settingsButton, "Interface\\Buttons\\UI-OptionsButton")

    trackButton = IconButton("CosmicSlayerTrack", TrackAchievement, function()
        if IsAchievementTracked() then
            return "Untrack"
        end
        return "Track"
    end)
    trackButton:SetPoint("RIGHT", settingsButton, "LEFT", -2, 0)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-Achievement-Shield-2") then
        UseAtlas(trackButton, "UI-Achievement-Shield-2")
    else
        UseAtlas(trackButton, "UI-Achievement-Shield-1")
    end

    refreshButton = IconButton("CosmicSlayerRefresh", Scan, "Refresh")
    refreshButton:SetPoint("RIGHT", trackButton, "LEFT", -2, 0)
    UseAtlas(refreshButton, "UI-RefreshButton", "Interface\\Buttons\\UI-RefreshButton")

    waypointButton = IconButton(nil, TrackCurrentStrike, "Track strike")
    waypointButton:SetPoint("RIGHT", refreshButton, "LEFT", -2, 0)
    UseCrosshair(waypointButton)

    titleText = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    titleText:SetPoint("TOPLEFT", 14, -10)
    titleText:SetJustifyH("LEFT")
    titleText:SetJustifyV("TOP")
    titleText:SetWordWrap(false)
    titleText:SetMaxLines(1)
    titleText:SetText("Cosmic Slayer")
    titleText:SetTextColor(0.77, 0.36, 1)
    AddDetail(titleText)

    progressText = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    progressText:SetPoint("TOPLEFT", 14, -34)
    progressText:SetJustifyH("LEFT")
    progressText:SetJustifyV("TOP")
    progressText:SetSpacing(0)
    progressText:SetTextColor(0.92, 0.94, 0.96)

    strikeLabel = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    strikeLabel:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, -10)
    strikeLabel:SetJustifyH("LEFT")
    strikeLabel:SetSpacing(0)
    strikeLabel:SetText("Current strike")
    strikeLabel:SetTextColor(0.55, 0.62, 0.68)
    AddDetail(strikeLabel)

    strikeText = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    strikeText:SetPoint("TOPLEFT", strikeLabel, "BOTTOMLEFT", 0, -2)
    strikeText:SetWidth(260)
    strikeText:SetJustifyH("LEFT")
    strikeText:SetWordWrap(true)

    strikeMeta = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
    strikeMeta:SetPoint("TOPLEFT", strikeText, "BOTTOMLEFT", 0, -2)
    strikeMeta:SetWidth(260)
    strikeMeta:SetJustifyH("LEFT")
    AddDetail(strikeMeta)

    refreshedText = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
    refreshedText:SetPoint("BOTTOMLEFT", 12, 8)
    refreshedText:SetWidth(200)
    refreshedText:SetJustifyH("LEFT")
    refreshedText:SetText("Not refreshed yet")

    local y = -128
    for _, zone in ipairs(ZONES) do
        local header = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
        header:SetPoint("TOPLEFT", 14, y)
        header:SetText(zone.label)
        zoneHeaders[zone.mapID] = header
        AddDetail(header)
        y = y - 18
        for _, key in ipairs(zone.bosses) do
            local row = TrackContent(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
            row:SetPoint("TOPLEFT", 28, y)
            row:SetJustifyH("LEFT")
            rows[key] = row
            AddDetail(row)
            y = y - 18
        end
        y = y - 8
    end

    CreateSettings()
    ApplyLayout()
    ApplyLock()
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
frame:RegisterEvent("VIGNETTES_UPDATED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
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
    if not CosmicSlayerDB then
        return
    end
    if event == "VIGNETTES_UPDATED" or event == "NAME_PLATE_UNIT_ADDED" then
        if DB().bossPing then
            ObserveBosses()
        end
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

StartPoll()

SLASH_COSMICSLAYER1 = "/cs"
SLASH_COSMICSLAYER2 = "/cosmicslayer"
SlashCmdList["COSMICSLAYER"] = TogglePanel
