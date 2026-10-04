-- Fake the retail client and drive Cosmic Slayer through play sessions.
-- Run from the repo root: lua tests/scenarios.lua

local root = (arg[0] or ""):match("^(.*)/tests/scenarios%.lua$") or "."
local addonPath = root .. "/CosmicSlayer.lua"
local failures = 0

local SECRET = {}

local function secret(value)
    return { [SECRET] = true, value = value }
end

local function issecretvalue(value)
    return type(value) == "table" and value[SECRET] == true
end

local function fontString()
    local fs = { text = "" }
    function fs:SetPoint() end
    function fs:SetSpacing() end
    function fs:ClearAllPoints() end
    function fs:SetWidth() end
    function fs:SetJustifyH() end
    function fs:SetWordWrap() end
    function fs:SetText(text)
        self.text = text
    end
    function fs:GetText()
        return self.text
    end
    function fs:SetTextColor(r, g, b)
        self.r, self.g, self.b = r, g, b
    end
    function fs:Hide()
        self.shown = false
    end
    function fs:Show()
        self.shown = true
    end
    function fs:IsShown()
        return self.shown ~= false
    end
    return fs
end

local function widget(kind, name, template)
    local frame = {
        kind = kind,
        name = name,
        template = template,
        scripts = {},
        shown = true,
        events = {},
        text = "",
        checked = false,
        fontStrings = {},
    }
    function frame:SetScript(script, fn)
        self.scripts[script] = fn
    end
    function frame:HookScript(script, fn)
        self.scripts[script] = fn
    end
    function frame:SetText(text)
        self.text = text
    end
    function frame:GetText()
        return self.text
    end
    function frame:SetChecked(value)
        self.checked = value and true or false
    end
    function frame:GetChecked()
        return self.checked
    end
    function frame:SetNormalFontObject() end
    function frame:SetHighlightFontObject() end
    function frame:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function frame:SetBackdrop() end
    function frame:SetBackdropColor(r, g, b, a)
        self.bg = { r, g, b, a }
    end
    function frame:SetBackdropBorderColor(r, g, b, a)
        self.border = { r, g, b, a }
    end
    function frame:CreateTexture()
        local tex = { shown = true }
        function tex:SetTexture() end
        function tex:SetSize() end
        function tex:SetPoint() end
        function tex:SetAllPoints() end
        function tex:SetRotation() end
        function tex:SetVertexColor(r, g, b, a)
            self.color = { r, g, b, a }
        end
        function tex:Hide()
            self.shown = false
        end
        function tex:Show()
            self.shown = true
        end
        return tex
    end
    function frame:SetPoint() end
    function frame:ClearAllPoints() end
    function frame:GetPoint()
        return "CENTER", nil, "CENTER", 0, 0
    end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:SetClampedToScreen() end
    function frame:RegisterForDrag() end
    function frame:Hide()
        self.shown = false
    end
    function frame:Show()
        self.shown = true
    end
    function frame:IsShown()
        return self.shown
    end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:CreateFontString()
        local fs = fontString()
        table.insert(self.fontStrings, fs)
        return fs
    end
    function frame:Click()
        local fn = self.scripts.OnClick
        if fn then
            fn(self)
        end
    end
    return frame
end

local function newWorld()
    local env = {
        clock = 0,
        timers = {},
        created = {},
        chat = {},
        sounds = {},
        waypoints = {},
        playerMap = 110,
        mapInfo = {
            [2395] = { parentMapID = 0, name = "Eversong Woods" },
            [2437] = { parentMapID = 0, name = "Zul'Aman" },
            [110] = { parentMapID = 0, name = "Silvermoon City" },
        },
        events = {},
        pois = {},
        quests = {},
        UIParent = {},
        UISpecialFrames = {},
        SlashCmdList = {},
        SOUNDKIT = { RAID_WARNING = 8959 },
    }

    function env.secret(value)
        return secret(value)
    end

    function env.GetTime()
        return env.clock
    end

    function env.date(fmt)
        return os.date(fmt, 1700000000 + math.floor(env.clock))
    end

    function env.issecretvalue(value)
        return issecretvalue(value)
    end

    function env.advance(seconds)
        local target = env.clock + seconds
        while true do
            local soonest
            for _, timer in ipairs(env.timers) do
                if not timer.dead and timer.at <= target and (not soonest or timer.at < soonest.at) then
                    soonest = timer
                end
            end
            if not soonest then
                break
            end
            env.clock = soonest.at
            if soonest.ticker then
                soonest.at = soonest.at + soonest.interval
            else
                soonest.dead = true
            end
            soonest.fn()
        end
        env.clock = target
    end

    function env.addEvent(mapID, poi)
        poi.mapID = mapID
        poi.position = { x = poi.x or 0.5, y = poi.y or 0.5 }
        env.pois[poi.id] = poi
        env.events[mapID] = env.events[mapID] or {}
        table.insert(env.events[mapID], poi.id)
        return poi
    end

    function env.clearEvents()
        env.events = {}
        env.pois = {}
    end

    function env.CreateFrame(kind, name, _, template)
        local frame = widget(kind, name, template)
        table.insert(env.created, frame)
        if name then
            env[name] = frame
        end
        return frame
    end

    function env.eventFrame()
        for _, frame in ipairs(env.created) do
            if frame.events.ADDON_LOADED then
                return frame
            end
        end
        error("event frame was not created")
    end

    function env.fire(event, arg1)
        local frame = env.eventFrame()
        frame.scripts.OnEvent(frame, event, arg1)
    end

    function env.panel()
        return env.CosmicSlayerFrame
    end

    function env.strikeWidgets()
        local fonts = env.panel().fontStrings
        for index, fs in ipairs(fonts) do
            if fs.text == "Current strike" then
                return fonts[index + 1], fonts[index + 2]
            end
        end
        error("current strike label is missing")
    end

    function env.button(label)
        for _, frame in ipairs(env.created) do
            if frame.text == label then
                return frame
            end
        end
        error("missing button " .. label)
    end

    function env.checks()
        local list = {}
        for _, frame in ipairs(env.created) do
            if frame.template == "UICheckButtonTemplate" then
                table.insert(list, frame)
            end
        end
        return list
    end

    function env.fontExact(text)
        for _, fs in ipairs(env.panel().fontStrings) do
            if fs.text == text then
                return fs
            end
        end
    end

    function env.fontMatching(fragment)
        local hits = {}
        for _, fs in ipairs(env.panel().fontStrings) do
            if type(fs.text) == "string" and fs.text:find(fragment, 1, true) then
                table.insert(hits, fs)
            end
        end
        return hits
    end

    env.C_Timer = {}
    function env.C_Timer.After(delay, fn)
        table.insert(env.timers, { at = env.clock + delay, fn = fn })
    end
    function env.C_Timer.NewTicker(interval, fn)
        table.insert(env.timers, { at = env.clock + interval, fn = fn, ticker = true, interval = interval })
    end

    env.C_Map = {
        GetBestMapForUnit = function()
            return env.playerMap
        end,
        GetMapInfo = function(mapID)
            return env.mapInfo[mapID]
        end,
        SetUserWaypoint = function(point)
            table.insert(env.waypoints, point)
        end,
    }
    env.C_SuperTrack = {
        SetSuperTrackedUserWaypoint = function()
            env.superTracked = true
        end,
    }
    env.UiMapPoint = {
        CreateFromCoordinates = function(mapID, x, y)
            return { mapID = mapID, x = x, y = y }
        end,
    }
    env.C_AreaPoiInfo = {
        GetEventsForMap = function(mapID)
            return env.events[mapID] or {}
        end,
        GetAreaPOIInfo = function(mapOrID, id)
            if id == nil then
                return env.pois[mapOrID]
            end
            local poi = env.pois[id]
            if poi and poi.mapID == mapOrID then
                return poi
            end
        end,
    }
    env.C_TaskQuest = {
        GetQuestsOnMap = function(mapID)
            return env.quests[mapID]
        end,
        GetQuestInfoByQuestID = function(questID)
            for _, list in pairs(env.quests) do
                for _, quest in ipairs(list) do
                    if quest.questID == questID then
                        return quest.title
                    end
                end
            end
        end,
    }
    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, message)
            table.insert(env.chat, message)
        end,
    }
    function env.PlaySound(sound)
        table.insert(env.sounds, sound)
    end
    function env.GetAchievementInfo()
        return "Cosmic Slayer", nil, nil, false
    end
    function env.GetAchievementNumCriteria()
        return 1
    end
    function env.GetAchievementCriteriaInfo()
        return nil, nil, nil, 3, 15
    end
    env.GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        Show = function() end,
    }
    function env.GameTooltip_Hide() end

    return setmetatable(env, {
        __index = {
            ipairs = ipairs,
            pairs = pairs,
            type = type,
            tostring = tostring,
            string = string,
            table = table,
            math = math,
            error = error,
            select = select,
            next = next,
            tinsert = table.insert,
        },
    })
end

local function loadAddon(env)
    local chunk, err = loadfile(addonPath, "t", env)
    if not chunk then
        error(err)
    end
    chunk()
end

local function eversongWeek(env)
    env.quests[2395] = {
        { questID = 94385, title = "Void Assaults: Eversong Woods" },
    }
end

local function boot(setup)
    local env = newWorld()
    if setup then
        setup(env)
    end
    loadAddon(env)
    env.fire("ADDON_LOADED", "CosmicSlayer")
    return env
end

local function enter(env, mapID)
    env.playerMap = mapID
    env.fire("PLAYER_ENTERING_WORLD")
    env.advance(2)
end

local function scenario(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("ok  " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name)
        print(tostring(err))
    end
end

scenario("loading outside a strike zone does not scan", function()
    local env = boot(function(world)
        world.playerMap = 110
    end)
    local strike, meta = env.strikeWidgets()
    assert(strike.text == "Waiting for first scan", strike.text)
    assert(meta.text == "Paused outside the strike zone", meta.text)
    assert(#env.chat == 0)
end)

scenario("entering Eversong waits 2 seconds, then scans an empty zone", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    env.fire("PLAYER_ENTERING_WORLD")
    local strike = env.strikeWidgets()
    assert(strike.text == "Waiting for first scan", "scanned before the delay")
    env.advance(2)
    strike, meta = env.strikeWidgets()
    assert(strike.text == "No Void Ritual strike", strike.text)
    assert(meta.text:find("Every 15s", 1, true), meta.text)
    assert(meta.text:find("0 events", 1, true), meta.text)
    assert(env.fontMatching("Eversong Woods  ·  this week")[1], "week header missing")
    assert(env.fontExact("Zul'Aman"), "Zul'Aman header should stay plain when it is not this week")
    assert(env.fontMatching("Croaker is not up")[1], "croaker row missing")
    assert(#env.chat == 0)
end)

scenario("fifteen seconds outside the zone does not scan", function()
    local env = boot(function(world)
        world.playerMap = 110
    end)
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.4, y = 0.6, isCurrentEvent = true })
    env.advance(15)
    local strike = env.strikeWidgets()
    assert(strike.text == "Waiting for first scan", strike.text)
    assert(#env.chat == 0)
    assert(#env.waypoints == 0)
end)

scenario("fifteen seconds in the zone picks up a strike that spawned quietly", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    local _, metaBefore = env.strikeWidgets()
    local before = metaBefore.text
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.advance(15)
    local strike, meta = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Croaker", strike.text)
    assert(meta.text ~= before, "scan clock did not move\nbefore: " .. tostring(before) .. "\nafter:  " .. tostring(meta.text))
    assert(meta.text:find("1 events", 1, true), meta.text)
    assert(#env.chat == 1, "expected one alert, got " .. #env.chat)
    assert(env.chat[1]:find("Croaker is up", 1, true), env.chat[1])
end)

scenario("a void strike spawning in the zone alerts once and marks the boss", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    local strike, meta = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Croaker", strike.text)
    assert(env.fontMatching("Void Ritual: Croaker")[1], "croaker row was not updated")
    assert(env.fontMatching("Springclaw is not up")[1], "springclaw should stay down")
    assert(env.fontMatching("Grizzly is not up")[1], "grizzly should stay down")
    assert(meta.text:find("Eversong", 1, true), meta.text)
    assert(#env.chat == 1)
    assert(#env.sounds == 1)
    assert(env.sounds[1] == env.SOUNDKIT.RAID_WARNING)
    assert(#env.waypoints == 1)
    assert(env.waypoints[1].mapID == 2395)
    assert(env.waypoints[1].x == 0.41)
    assert(env.superTracked == true)
end)

scenario("more time with the same strike does not alert again", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    env.advance(15)
    env.advance(15)
    assert(#env.chat == 1, "alerted " .. #env.chat .. " times")
    assert(#env.sounds == 1)
end)

scenario("the strike changing clears the old boss and alerts the new one", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    env.clearEvents()
    env.addEvent(2437, { id = 8800, name = "Void Ritual: Grizzly", x = 0.2, y = 0.8, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    local strike = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Grizzly", strike.text)
    assert(env.fontMatching("Croaker is not up")[1], "croaker should have cleared")
    assert(env.fontMatching("Void Ritual: Grizzly")[1], "grizzly row missing")
    assert(#env.chat == 2, "expected a second alert")
    assert(env.chat[2]:find("Grizzly is up", 1, true), env.chat[2])
    assert(env.waypoints[#env.waypoints].mapID == 2437)
end)

scenario("the same boss alerts again after it despawns and returns", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    env.clearEvents()
    env.fire("AREA_POIS_UPDATED")
    local strike = env.strikeWidgets()
    assert(strike.text == "No Void Ritual strike", strike.text)
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    assert(#env.chat == 2, "return spawn did not alert")
end)

scenario("leaving the zone pauses updates until Refresh", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    env.playerMap = 110
    env.fire("ZONE_CHANGED_NEW_AREA")
    local strike, meta = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Croaker", strike.text)
    assert(meta.text:find("Paused", 1, true), meta.text)
    env.clearEvents()
    env.addEvent(2437, { id = 8800, name = "Void Ritual: Grizzly", x = 0.2, y = 0.8, isCurrentEvent = true })
    env.advance(20)
    strike = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Croaker", "ticker scanned outside the zone")
    assert(#env.chat == 1)
    env.button("Refresh"):Click()
    strike = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Grizzly", strike.text)
    assert(#env.chat == 2)
end)

scenario("a Zul'Aman strike is found while the week quest says Eversong", function()
    local env = boot(function(world)
        world.playerMap = 2437
        eversongWeek(world)
    end)
    env.addEvent(2437, { id = 8800, name = "Void Ritual: Grizzly", x = 0.2, y = 0.8, isCurrentEvent = true })
    enter(env, 2437)
    local strike, meta = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Grizzly", strike.text)
    assert(meta.text:find("Zul'Aman", 1, true), meta.text)
    assert(env.fontMatching("Eversong Woods  ·  this week")[1], "week label should stay on Eversong")
    assert(#env.chat == 1)
end)

scenario("a child map of Eversong is included in the scan", function()
    local env = boot(function(world)
        world.mapInfo[9001] = { parentMapID = 2395, name = "Runestone" }
        world.playerMap = 9001
        eversongWeek(world)
    end)
    env.addEvent(9001, { id = 8724, name = "Void Ritual: Springclaw", x = 0.3, y = 0.7, isCurrentEvent = true })
    enter(env, 9001)
    local strike, meta = env.strikeWidgets()
    assert(strike.text == "Void Ritual: Springclaw", strike.text)
    assert(meta.text:find("Eversong", 1, true), meta.text)
    assert(env.fontMatching("Void Ritual: Springclaw")[1], "springclaw row missing")
    assert(#env.chat == 1)
end)

scenario("a void incursion is shown alone and can be waypointed", function()
    local env = boot(function(world)
        world.playerMap = 2437
        eversongWeek(world)
    end)
    enter(env, 2437)
    env.addEvent(2437, { id = 1, name = "Saltheril's Soiree", x = 0.1, y = 0.1, isCurrentEvent = true })
    env.addEvent(2437, { id = 2, name = "Void Incursion", x = 0.44, y = 0.71, isCurrentEvent = true })
    env.addEvent(2437, { id = 3, name = "Abyss Anglers", x = 0.8, y = 0.2, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    local strike = env.strikeWidgets()
    assert(strike.text == "Void Incursion", strike.text)
    assert(#env.chat == 0, "an incursion is not a watched boss")
    env.button("Set waypoint"):Click()
    assert(#env.waypoints == 1, "incursion waypoint missing")
    assert(env.waypoints[1].mapID == 2437)
    assert(env.waypoints[1].x == 0.44)
    assert(env.waypoints[1].y == 0.71)
end)

scenario("a current event with a different name is still shown", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    env.addEvent(2395, { id = 8701, name = "Voidwing Ambush", x = 0.5, y = 0.5, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    local strike = env.strikeWidgets()
    assert(strike.text == "Voidwing Ambush", strike.text)
    assert(#env.chat == 0, "unwatched event should not alert")
    assert(env.fontMatching("Springclaw is not up")[1])
end)

scenario("a secret strike name is shown and is not read as text", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    local hidden = env.secret("Void Ritual: Croaker")
    env.addEvent(2395, { id = 8723, name = hidden, x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    local strike = env.strikeWidgets()
    assert(strike.text == hidden, "secret name was dropped or stringified")
    assert(#env.chat == 0, "secret name was passed to string methods")
    assert(#env.waypoints == 0)
end)

scenario("the waypoint check blocks the automatic pin and the button still sets it", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    enter(env, 2395)
    local box = env.checks()[3]
    box:SetChecked(false)
    box:Click()
    env.addEvent(2395, { id = 8723, name = "Void Ritual: Croaker", x = 0.41, y = 0.62, isCurrentEvent = true })
    env.fire("AREA_POIS_UPDATED")
    assert(#env.waypoints == 0, "checkbox off still dropped a pin")
    assert(#env.chat == 1)
    env.button("Set waypoint"):Click()
    assert(#env.waypoints == 1, "button did not set a waypoint")
    assert(env.waypoints[1].mapID == 2395)
    assert(env.waypoints[1].x == 0.41)
end)

scenario("the panel opens expanded and collapses to a borderless bar", function()
    local env = boot(function(world)
        world.playerMap = 2395
        eversongWeek(world)
    end)
    local panel = env.panel()
    assert(panel.height == 428, "panel should open expanded")
    assert(math.abs(panel.bg[4] - 0.78) < 0.001, "expanded backdrop should be ElvUI-dark")
    assert(panel.border[4] == 1)
    assert(env.button("Refresh"):IsShown())
    assert(env.button("Track achievement"):IsShown())
    assert(env.fontExact("3 / 15"))
    assert(env.fontExact("Not refreshed yet"):IsShown() == false)
    local toggle = env.CosmicSlayerCollapse
    toggle:Click()
    assert(panel.height == 72, "collapsed height")
    assert(math.abs(panel.bg[4] - 0.10) < 0.001, "collapsed backdrop should be 10% alpha")
    assert(panel.border[4] == 0, "collapsed view has no border")
    assert(env.button("Track achievement"):IsShown() == false)
    assert(env.fontExact("Croaker is not up"):IsShown() == false)
    assert(env.button("Refresh"):IsShown())
    assert(env.button("Refresh").label.text == "Refresh")
    enter(env, 2395)
    local refreshed = env.fontMatching("Last refresh")[1]
    assert(refreshed and refreshed:IsShown(), "last refresh should show while collapsed")
    local strike = env.strikeWidgets()
    assert(strike.text == "No Void Ritual strike", strike.text)
    panel:Show()
    env.CosmicSlayerClose:Click()
    assert(panel:IsShown() == false, "X should hide the panel")
    toggle:Click()
    assert(panel.height == 428)
    assert(env.fontExact("Croaker is not up"):IsShown())
end)

if failures > 0 then
    print(failures .. " failed")
    os.exit(1)
end
print("all scenarios passed")
