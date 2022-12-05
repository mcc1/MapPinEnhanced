local _G = _G
local MapPinEnhanced = LibStub("AceAddon-3.0"):NewAddon("MapPinEnhanced", "AceConsole-3.0", "AceEvent-3.0",
    "AceTimer-3.0")


local HBD = LibStub("HereBeDragons-2.0")
local HBDP = LibStub("HereBeDragons-Pins-2.0")
local LDBIcon = LibStub("LibDBIcon-1.0")

local globalMPH = {}
_G["MapPinEnhanced"] = globalMPH
MapPinEnhanced.name = "Map Pin Enhanced"


local DEFAULT_PIN_TITLE = "Map Pin"



--@do-not-package@
-- Possible features:
-- TODO: Add ElvUI Skin
-- TODO: overcome the problem with notsetable waypoints (e.g. in dungeons, Dalaran)
-- TODO: Add possibility to set custom icons for pins (minimap, objective, tooltip, pin)
-- TODO: Add click handler to blizz map overlays and set waypoint (maybe with isMouseOver check and same keybind)
-- TODO: Add custom hyperlink with zone name and coords to chat (https://wowpedia.fandom.com/wiki/Hyperlinks#garrmission)
-- FIXME: find way to get rid of blizz minimap pin tooltip
-- TODO: make it possible to set pin on map even if navigation is not possible: mapCanvas:AddGlobalPinMouseActionHandler, set pin on parent map and set dummy frame on mapCanvas for correct map
-- TODO: Investigate broken supertracking for instanced zones (uldum bfa <> uldum cata)
-- TODO: Be able to overwrite presets
-- TODO: finish navigation: Finish navigation step pins, fix distance tracking in zones with no waypointsupport, replace secure button so frame stays interactable in combat
--@end-do-not-package@



local HBDmapData = HBD.mapData


local overrides = {
    [101] = { mapType = Enum.UIMapType.World }, -- Outland
    [125] = { mapType = Enum.UIMapType.Zone }, -- Dalaran
    [126] = { mapType = Enum.UIMapType.Micro },
    [195] = { suffix = "1" }, -- Kaja'mine
    [196] = { suffix = "2" }, -- Kaja'mine
    [197] = { suffix = "3" }, -- Kaja'mine
    [501] = { mapType = Enum.UIMapType.Zone }, -- Dalaran
    [502] = { mapType = Enum.UIMapType.Micro },
    [572] = { mapType = Enum.UIMapType.World }, -- Draenor
    [579] = { suffix = "1" }, -- Lunarfall Excavation
    [580] = { suffix = "2" }, -- Lunarfall Excavation
    [581] = { suffix = "3" }, -- Lunarfall Excavation
    [582] = { mapType = Enum.UIMapType.Zone }, -- Lunarfall
    [585] = { suffix = "1" }, -- Frostwall Mine
    [586] = { suffix = "2" }, -- Frostwall Mine
    [587] = { suffix = "3" }, -- Frostwall Mine
    [590] = { mapType = Enum.UIMapType.Zone }, -- Frostwall
    [625] = { mapType = Enum.UIMapType.Orphan }, -- Dalaran
    [626] = { mapType = Enum.UIMapType.Micro }, -- Dalaran
    [627] = { mapType = Enum.UIMapType.Zone },
    [628] = { mapType = Enum.UIMapType.Micro },
    [629] = { mapType = Enum.UIMapType.Micro },
    [943] = { suffix = FACTION_HORDE }, -- Arathi Highlands
    [1044] = { suffix = FACTION_ALLIANCE },
}

local CZWFromMapID = {}
local function GetCZWFromMapID(m)
    local zone, continent, world, map
    local mapInfo = nil

    if not m then
        return nil, nil, nil;
    end

    -- Return the cached CZW
    if CZWFromMapID[m] then
        return unpack(CZWFromMapID[m])
    end

    map = m -- Save the original map
    repeat
        mapInfo = C_Map.GetMapInfo(m)
        if not mapInfo then
            -- No more parents, return what we have
            CZWFromMapID[map] = { continent, zone, world }
            return continent, zone, world
        end
        local mapType = (overrides[m] and overrides[m].mapType) or mapInfo.mapType
        if mapType == Enum.UIMapType.Zone then
            -- Its a zone map
            zone = m
        elseif mapType == Enum.UIMapType.Continent then
            continent = m
        elseif (mapType == Enum.UIMapType.World) or (mapType == Enum.UIMapType.Cosmic) then
            world = m
            continent = continent or m -- Hack for one continent worlds
        end
        m = mapInfo.parentMapID
    until (m == 0)
    CZWFromMapID[map] = { continent, zone, world }
    return continent, zone, world
end

MapPinEnhanced.mapDataID = {}
local mapDataID = MapPinEnhanced.mapDataID

function MapPinEnhanced:ToggleDropDown(menuParent)
    self.menuFrame = self.menuFrame or CreateFrame("Frame", "MPHLDBDropdown", UIParent, "UIDropDownMenuTemplate")
    local menuTable = {}
    table.insert(menuTable, 1, {
        text = "Toggle Import Window",
        func = function()
            MapPinEnhanced:ToggleImportWindow()
        end,
        notCheckable = true,
    })


    if (#self.db.global.presets > 0) then
        table.insert(menuTable, 2, {
            text = "Presets",
            notCheckable = true,
            isTitle = true
        })
    end


    for i, j in ipairs(self.db.global.presets) do
        table.insert(menuTable, i + 2, {
            text = "  " .. j.name,
            func = function()
                self:ParseImport(j.input)
            end,
            notCheckable = true,
        })
    end

    if menuParent then
        EasyMenu(menuTable, self.menuFrame, menuParent, 0, 0, "MENU")
    else
        EasyMenu(menuTable, self.menuFrame, "cursor", 0, 0, "MENU")
    end
end

local brokerText = "|A:Waypoint-MapPin-Tracked:19:19|aMPH"
-- Minimap Button and Minimap Button
local MapPinEnhancedBroker = LibStub("LibDataBroker-1.1"):NewDataObject("MapPinEnhanced", {
    type = "data source",
    text = brokerText,
    icon = "Interface\\Addons\\MapPinEnhanced\\assets\\logo",
    OnClick = function(_, button)
        if button == "LeftButton" then
            MapPinEnhanced:TogglePinTrackerWindow()
        elseif button == "RightButton" then
            MapPinEnhanced:ToggleDropDown()
        end
    end,
    OnTooltipShow = function(tt)
        tt:AddLine("|cffeda55fLeft-Click|r to toggle the pin tracker.")
        tt:AddLine("|cffeda55fRight-Click|r to toggle presets view.")
    end
})


local defaults = {
    global = {
        minimap = {
            hide = false
        },
        savedPins = {
            pinsData = {},
            lastTrackedIndex = nil
        },
        presets = {},
        trackerPos = {
            x = 0,
            y = 0,
            point = "CENTER",
            relativePoint = "CENTER"
        },
        options = {
            changedalpha = true,
            maxTrackerEntries = 6,
            showTimeOnSuperTrackedFrame = true,
            hidePins = false,
            hyperlink = true,
            trackerScale = 1,
        }
    }
}

local pinsRestored = false


function MapPinEnhanced:PrintMSG(msgTable, hasTitle)
    if not msgTable then return end
    local out = ""
    if hasTitle then
        out = "|A:Waypoint-MapPin-Tracked:19:19|a|cFFFFD100" .. self.name .. "|r\n"
    end

    for i = 1, #msgTable do
        if hasTitle then
            out = out .. msgTable[i] .. "\n"
        else
            out = out .. "|A:Waypoint-MapPin-Tracked:19:19|a " .. msgTable[i] .. "\n"
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage(out)
end

function MapPinEnhanced:TogglePinTrackerWindow()
    if self.MPHFrame:IsShown() then
        self.MPHFrame:Hide()
        if self.db.global.options["hidePins"] then
            self.pinManager:HideAllPins()
        end
    else
        self.MPHFrame:Show()
        if self.db.global.options["hidePins"] then
            self.pinManager:ShowAllPins()
        end
    end
end

function MapPinEnhanced:OnInitialize()
    self.blockWAYPOINTevent = false
    -- Saved Vars
    self.db = LibStub("AceDB-3.0"):New("MapPinEnhancedDB", defaults)

    -- conversion to new global saved vars
    if self.db.profile then
        if self.db.minimap ~= nil then
            self.db.global.minimap.hide = self.db.minimap.hide
        end
        if self.db.profile.savedpins ~= nil then
            self.db.global.savedPins = {
                pinsData = {},
                lastTrackedIndex = nil
            }
        end
        if self.db.profile.pintrackerposition ~= nil then
            self.db.global.trackerPos = {
                x = self.db.profile.pintrackerposition.x,
                y = self.db.profile.pintrackerposition.y,
            }
        end
        if self.db.options then
            if self.db.profile.options.changedalpha ~= nil then
                self.db.global.options.changedalpha = self.db.profile.options.changedalpha
            end
        end

        self.db.profile = nil
    end

    -- Minimap Icon
    LDBIcon:Register("MapPinEnhanced", MapPinEnhancedBroker, self.db.global.minimap)
    self:UpdateMinimapButton()

    -- Structure mapdata like TomTom, Snippet from TomTom Addon
    for id in pairs(HBDmapData) do
        local c, z, w = GetCZWFromMapID(id)
        local mapType = (overrides[id] and overrides[id].mapType) or HBDmapData[id].mapType
        if (mapType == Enum.UIMapType.Zone) or (mapType == Enum.UIMapType.Continent) or
            (mapType == Enum.UIMapType.Micro) then
            local name = HBDmapData[id].name
            if (overrides[id] and overrides[id].suffix) then
                name = name .. " " .. overrides[id].suffix
            end
            if w then
                if name and mapDataID[name] then
                    if type(mapDataID[name]) ~= "table" then
                        -- convert to table
                        mapDataID[name] = { mapDataID[name] }
                    end
                    table.insert(mapDataID[name], id)
                else
                    mapDataID[name] = id
                end
            end

            mapDataID["#" .. id] = id
        end
    end

    local newEntries = {}
    for name, mapID in pairs(mapDataID) do
        if type(mapID) == "table" then
            mapDataID[name] = nil
            for _, mapId in pairs(mapID) do
                local parent = HBDmapData[mapId].parent
                local parentName = (parent and (parent > 0) and HBDmapData[parent].name)
                if parentName then
                    -- We rely on the implicit acending order of mapID's so the lowest one wins
                    if not newEntries[name .. ":" .. parentName] then
                        newEntries[name .. ":" .. parentName] = mapId
                    else
                        newEntries[name .. ":" .. tostring(mapId)] = mapId
                    end
                end
            end
        end
    end
    for name, mapID in pairs(newEntries) do
        mapDataID[name] = mapID
    end
    wipe(newEntries)
    collectgarbage("collect")
end

function MapPinEnhanced:UpdateMinimapButton()
    if (self.db.global.minimap.hide) then
        LDBIcon:Hide("MapPinEnhanced")
    else
        LDBIcon:Show("MapPinEnhanced")
    end
end

function MapPinEnhanced:ToggleMinimapButton()
    if (self.db.global.minimap.hide) then
        self.db.global.minimap.hide = false
    else
        self.db.global.minimap.hide = true
    end
    self:UpdateMinimapButton()
end

StaticPopupDialogs["MPH_ENABLE_NAVIGATION"] = {
    text = "Ingame Navigation is disabled! You need to enable it to use MapPinEnhanced properly!",
    button1 = "Enable",
    button2 = "Cancel",
    notClosableByLogout = true,
    showAlert = true,
    exclusive = true,
    OnAccept = function()
        SetCVar("showInGameNavigation", 1)
    end,
    whileDead = true,
    preferredIndex = 3,
}

function MapPinEnhanced:OnEnable()

    if GetCVar("showInGameNavigation") == "0" then
        StaticPopup_Show("MPH_ENABLE_NAVIGATION")
    end
    -- Register Events
    self:RegisterEvent("SUPER_TRACKING_CHANGED")
    self:RegisterEvent("USER_WAYPOINT_UPDATED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LOGIN")


    local MPHFrame = CreateFrame("Frame", "MPHFrame", UIParent, "MPHFrameTemplate")
    MPHFrame:ClearAllPoints()
    local x = 0
    local y = 0
    local relativePoint = "CENTER"
    local point = "CENTER"
    if self.db.global.trackerPos then
        x = self.db.global.trackerPos.x
        y = self.db.global.trackerPos.y
        relativePoint = self.db.global.trackerPos.relativePoint
        point = self.db.global.trackerPos.point
    end
    MPHFrame:SetPoint(point, UIParent, relativePoint, x, y)
    MPHFrame:SetScript("OnMouseUp", function(self)
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        if xOfs and yOfs and point and relativePoint then
            MapPinEnhanced.db.global.trackerPos = {
                x = xOfs,
                y = yOfs,
                point = point,
                relativePoint = relativePoint
            }
        end
        self:StopMovingOrSizing()
    end)
    MPHFrame:StopMovingOrSizing()
    MPHFrame:SetScript("OnEnter", function(self)
        local isDefault = true
        for i, j in pairs(MapPinEnhanced.db.global.trackerPos) do
            if j ~= defaults.global.trackerPos[i] then
                isDefault = false
                break
            end
        end
        if isDefault then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText("|cffeda55fCtrl + Left-Click|r to move the pin tracker")
            GameTooltip:Show()
        end
    end)

    MPHFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    MPHFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() then
            self:StartMoving()
        elseif button == "RightButton" then
            MapPinEnhanced:ToggleDropDown()
        end
    end)

    MPHFrame.header.presets:SetScript("OnMouseDown", function(self)
        if MapPinEnhanced.menuFrame then
            if MapPinEnhanced.menuFrame:IsShown() then
                MapPinEnhanced.menuFrame:Hide()
                CloseDropDownMenus()
            else
                MapPinEnhanced:ToggleDropDown(self)
            end
        else
            MapPinEnhanced:ToggleDropDown(self)
        end
    end)

    MPHFrame.header.close:SetScript("OnClick", function(self)
        MapPinEnhanced:TogglePinTrackerWindow()
    end)
    self.MPHFrame = MPHFrame
end

local MPHFramePool = {}

local function CreatePin(x, y, mapID, emit, title, persist)

    local tracked = false
    local navigating = false
    local objective = CreateFrame("Button", nil, MapPinEnhanced.MPHFrame.scrollFrame.scrollChild,
        "MPHTrackerEntryTemplate")
    local pin = CreateFrame("Button", nil, nil, "MPHMapPinTemplate")
    local minimappin = CreateFrame("Button", nil, nil, "MPHMinimapPinTemplate")
    local persistent = false
    local index;
    local title = title

    local function isPersistent()
        return persistent
    end

    local function setPersistent(value)
        persistent = value
        pin.Icon:SetDesaturated(value)
        pin.Highlight:SetDesaturated(value)
        objective.button.normal:SetDesaturated(value)
        objective.button.highlight:SetDesaturated(value)
        minimappin.Icon:SetDesaturated(value)
        minimappin.Highlight:SetDesaturated(value)
        SuperTrackedFrame.Icon:SetDesaturated(isPersistent())
    end

    setPersistent(persist)


    local function setDistanceText(distance)
        if distance then
            objective.distance:SetText("[" .. ("%s yds"):format(AbbreviateNumbers(distance)) .. "]")
        else
            objective.distance:SetText("")
        end
    end

    local function distanceCheck(distance)
        if (distance <= 5) and distance > 0 and not navigating and not persistent then
            emit("remove")
        else
            if distance <= 0 then
                setDistanceText(nil)
            else
                setDistanceText(Round(distance))
            end
        end
    end

    local function Track(x2, y2, mapID2)
        tracked = true
        pin:Track()
        objective:Track()
        minimappin:Track()
        SuperTrackedFrame.Icon:SetDesaturated(isPersistent())
        MapPinEnhanced.blockWAYPOINTevent = true
        if C_Map.CanSetUserWaypointOnMap(mapID2) then
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID2, x2, y2, 0))
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            if not MapPinEnhanced.distanceTimer then
                MapPinEnhanced.distanceTimer = MapPinEnhanced:ScheduleRepeatingTimer("DistanceTimer", 0.1,
                    distanceCheck)
            elseif MapPinEnhanced.distanceTimer.cancelled then
                MapPinEnhanced.distanceTimer = MapPinEnhanced:ScheduleRepeatingTimer("DistanceTimer", 0.1,
                    distanceCheck)
            end
        end
        MapPinEnhanced.lastDistance = nil
        if MapPinEnhanced.superTrackedTimer then
            MapPinEnhanced.superTrackedTimer:Hide()
        end
        if not MapPinEnhanced.db.global.savedpins then
            MapPinEnhanced.db.global.savedpins = {}
        end
        MapPinEnhanced.db.global.savedpins.lastTrackedPin = {
            x = x2,
            y = y2,
            mapID = mapID2,
        }
        MapPinEnhanced.blockWAYPOINTevent = false
    end

    local function Untrack()
        tracked = false
        pin:Untrack()
        objective:Untrack()
        minimappin:Untrack()
        SuperTrackedFrame.Icon:SetDesaturated(false)
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
        MapPinEnhanced.db.global.savedpins.lastTrackedPin = nil
        if MapPinEnhanced.distanceTimer then
            if not MapPinEnhanced.distanceTimer.cancelled then
                MapPinEnhanced:CancelTimer(MapPinEnhanced.distanceTimer)
            end
        end
    end

    local function ToggleTracked()
        if tracked then
            Untrack()
        else
            emit("track")
        end
    end

    local function ShowOnMap() -- for newly created map pins
        objective:Show()
        HBDP:AddWorldMapIconMap(MapPinEnhanced, pin, mapID, x, y, 3, "PIN_FRAME_LEVEL_ENCOUNTER")
        HBDP:AddMinimapIconMap(MapPinEnhanced, minimappin, mapID, x, y, false, false)
    end

    local function RemoveFromMap()
        objective:Hide()
        objective:ClearAllPoints()
        HBDP:RemoveWorldMapIcon(MapPinEnhanced, pin)
        HBDP:RemoveMinimapIcon(MapPinEnhanced, minimappin)
    end

    local function MoveOnMap(x2, y2, mapID2)
        HBDP:RemoveWorldMapIcon(MapPinEnhanced, pin)
        HBDP:RemoveMinimapIcon(MapPinEnhanced, minimappin)
        HBDP:AddWorldMapIconMap(MapPinEnhanced, pin, mapID2, x2, y2, 3, "PIN_FRAME_LEVEL_ENCOUNTER")
        HBDP:AddMinimapIconMap(MapPinEnhanced, minimappin, mapID2, x2, y2, false, false)
    end

    local function HidePin()
        pin:EnableMouse(false)
        pin:SetAlpha(0)
        objective:EnableMouse(false)
        objective:SetAlpha(0)
        minimappin:EnableMouse(false)
        -- blizzard minimap pin is always invisible but still has tooltip
        minimappin:SetAlpha(0)
    end

    local function ShowPin()
        pin:EnableMouse(true)
        pin:SetAlpha(1)
        objective:EnableMouse(true)
        objective:SetAlpha(1)
        minimappin:EnableMouse(true)
        -- blizzard minimap pin is always invisible but still has tooltip
        minimappin:SetAlpha(1)
    end

    local function IsTracked()
        return tracked
    end

    local function scrollToObjective(i, isRetry)
        local scrollIndex = index
        if i then
            scrollIndex = i
        end

        if scrollIndex then
            local _, max = MapPinEnhanced.MPHFrame.scrollFrame.ScrollBar:GetMinMaxValues()
            if max == 0 then
                if not isRetry then
                    C_Timer.After(0.01, function() scrollToObjective(scrollIndex, true) end)
                end
                return
            end


            local value = (scrollIndex - 1) * objective:GetHeight()
            if value > max then
                if not isRetry then
                    C_Timer.After(0.01, function() scrollToObjective(scrollIndex, true) end)
                    return
                end
            end
            isRetry = nil
            MapPinEnhanced.MPHFrame.scrollFrame.ScrollBar:SetValue(value)
        end
    end

    pin:SetScript("OnMouseDown", function(self, arg1)
        if arg1 == "LeftButton" then
            if IsControlKeyDown() then
                emit("remove")
            elseif IsShiftKeyDown() then
                emit("hyperlink")
            else
                ToggleTracked()
                -- scroll to tracked pin
                scrollToObjective()
            end
        elseif arg1 == "RightButton" then
            if IsShiftKeyDown() then
                setPersistent(not persistent)
            end
        end
        self:SetPoint("CENTER", 2, -2)
    end)
    pin:SetScript("OnMouseUp", function(self)
        self:SetPoint("CENTER", 0, 0)
    end)


    local function SetTooltip(title2)
        pin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -16, -4)
            GameTooltip_SetTitle(GameTooltip, title2);
            GameTooltip:AddLine("|A:newplayertutorial-icon-mouse-leftbutton:12:12|a to track/untrack the pin")
            GameTooltip:AddLine(
                "|cffeda55fCtrl +|r|A:newplayertutorial-icon-mouse-leftbutton:12:12|a to remove the pin")
            GameTooltip:AddLine(
                "|cffeda55fShift +|r|A:newplayertutorial-icon-mouse-leftbutton:12:12|a to share the pin")
            GameTooltip:AddLine(
                "|cffeda55fShift +|r|A:newplayertutorial-icon-mouse-rightbutton:12:12|a to make the pin persistent")
            GameTooltip:Show()
        end)

        minimappin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -16, -4)
            GameTooltip_SetTitle(GameTooltip, title2);
            GameTooltip:Show()
        end)

        objective:SetScript("OnEnter", function()
            objective:OnEnter(tracked, title2)
        end)
        objective:SetScript("OnLeave", function()
            objective:OnLeave(tracked)
        end)
    end

    SetTooltip(title)


    objective:SetScript("OnMouseDown", function(self, arg1)
        if arg1 == "LeftButton" then
            if IsControlKeyDown() then
                emit("remove")
            elseif IsShiftKeyDown() then
                emit("hyperlink")
            else
                ToggleTracked()
            end
        elseif arg1 == "RightButton" then
            if IsShiftKeyDown() then
                setPersistent(not persistent)
            else
                emit("remove")
            end
        end
    end)




    -- objective.navStart:SetScript("OnClick", function(self)
    --     emit("track")
    --     navigating = true
    --     emit("navigate")
    -- end)


    local function SetTrackerPosition(i)
        index = i
        objective:ClearAllPoints()
        objective:SetPoint("TOPLEFT", MapPinEnhanced.MPHFrame.scrollFrame.scrollChild, "TOPLEFT", 5,
            -((i - 1) * (objective:GetHeight())))
        objective:SetIndex(i)
        if not objective:IsShown() then
            objective:Show()
        end

        if tracked then
            scrollToObjective(i)
        end
    end

    local function SetObjectiveTitle(title2)
        objective:SetTitle(strlen(title2) > 15 and strsub(title2, 1, 13) .. "..." or title2)
    end

    SetObjectiveTitle(strlen(title) > 15 and strsub(title, 1, 13) .. "..." or title)

    local function SetObjectiveText(x2, y2, mapID2)
        local zoneName = HBDmapData[mapID2]["name"]
        zoneName = strlen(zoneName) > 20 and strsub(zoneName, 1, 18) .. "..." or zoneName


        objective.info:SetText(zoneName .. " (" .. Round(x2 * 100) .. ", " .. Round(y2 * 100) .. ")")
        objective.info:Show()
    end

    SetObjectiveText(x, y, mapID)




    return {
        Untrack = Untrack,
        Track = Track,
        ToggleTracked = ToggleTracked,
        ShowOnMap = ShowOnMap,
        RemoveFromMap = RemoveFromMap,
        MoveOnMap = MoveOnMap,
        IsTracked = IsTracked,
        isPersistent = isPersistent,
        setPersistent = setPersistent,
        SetTooltip = SetTooltip,
        scrollToObjective = scrollToObjective,
        SetTrackerPosition = SetTrackerPosition,
        SetObjectiveTitle = SetObjectiveTitle,
        SetObjectiveText = SetObjectiveText,
        HidePin = HidePin,
        ShowPin = ShowPin,
        x = x,
        y = y,
        mapID = mapID,
        title = title,

    }
end

local function DistanceFromPlayer(pin)
    local PlayerZonePosition = { HBD:GetPlayerZonePosition() }
    return (
        HBD:GetZoneDistance(PlayerZonePosition[3], PlayerZonePosition[1], PlayerZonePosition[2], pin.mapID, pin.x,
            pin.y))
end

local function IsCloser(pin, ref)
    if ref and DistanceFromPlayer(pin) and DistanceFromPlayer(ref) then
        return DistanceFromPlayer(pin) < DistanceFromPlayer(ref)
    else
        return true
    end
end

function MapPinEnhanced:FormatHyperlink(x, y, mapID)
    if x and y and mapID then
        return ("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(mapID, x * 10000, y * 10000, MAP_PIN_HYPERLINK)
    end
end

local function PinManager()
    local pins = {}

    local function SavePinsPersistent()
        local data = {}
        for _, pin in pairs(pins) do
            table.insert(data, {
                x = pin.x,
                y = pin.y,
                mapID = pin.mapID,
                title = pin.title,
                persistent = pin.persistent,
            })
        end
        MapPinEnhanced.db.global.savedpins.pinsData = data
    end

    local function UpdateTrackerPositions()
        for i, p in ipairs(pins) do
            p.SetTrackerPosition(i)
        end

        if MapPinEnhanced.MPHFrame:IsShown() and #pins == 0 then
            MapPinEnhanced:TogglePinTrackerWindow()
        elseif not MapPinEnhanced.MPHFrame:IsShown() and #pins > 0 then
            MapPinEnhanced:TogglePinTrackerWindow()
        end

        if #pins > 0 and not MapPinEnhanced.MPHFrame.scrollFrame:IsShown() then
            MapPinEnhanced.MPHFrame.scrollFrame:Show()
        end
        if (#pins <= MapPinEnhanced.db.global.options["maxTrackerEntries"]) then
            MapPinEnhanced.MPHFrame.scrollFrame.ScrollBar:SetAlpha(0)
            local newHeight = 65 + ((#pins - 1) * 40)
            MapPinEnhanced.MPHFrame:SetHeight(newHeight)
            if pinsRestored then
                MapPinEnhanced.MPHFrame:ClearAllPoints()
                MapPinEnhanced.MPHFrame:SetPoint(MapPinEnhanced.db.global.trackerPos.point, UIParent,
                    MapPinEnhanced.db.global.trackerPos.relativePoint, MapPinEnhanced.db.global.trackerPos.x,
                    MapPinEnhanced.db.global.trackerPos.y)
            end
        else
            MapPinEnhanced.MPHFrame.scrollFrame.ScrollBar:SetAlpha(1)
            local newHeight = 65 + ((MapPinEnhanced.db.global.options["maxTrackerEntries"] - 1) * 40)
            MapPinEnhanced.MPHFrame:SetHeight(newHeight)
        end
        if #pins > 0 then
            MapPinEnhancedBroker.text = brokerText .. ": " .. #pins
        else
            MapPinEnhancedBroker.text = brokerText
        end

    end

    local function SupertrackClosest()
        if not C_SuperTrack.IsSuperTrackingQuest() then
            local pin = nil
            for _, p in ipairs(pins) do
                p.Untrack()
                if IsCloser(p, pin) then
                    pin = p
                end
            end
            if pin then
                pin.Track(pin.x, pin.y, pin.mapID)

            end
        end
    end

    local function RemovePin(pin)
        pin.RemoveFromMap()
        for i, p in ipairs(pins) do
            if p == pin then
                pins[i] = pins[#pins]
                pins[#pins] = nil
                C_Map.ClearUserWaypoint()
                SupertrackClosest()
                tinsert(MPHFramePool, pin)
                UpdateTrackerPositions()
                SavePinsPersistent()
                return
            end
        end
    end

    local function UntrackPins()
        for _, p in ipairs(pins) do
            if p.IsTracked() then
                p.Untrack()
                return
            end
        end
    end

    local function AddPin(x, y, mapID, name, isPersistent, noTrack)
        if #pins > 0 then
            for _, p in ipairs(pins) do
                if math.abs(x - p.x) < 0.005 and math.abs(y - p.y) < 0.005 and mapID == p.mapID then
                    UntrackPins()
                    p.Track(x, y, mapID)
                    return
                end
            end
        end


        local title
        if not name or name == "" then
            title = DEFAULT_PIN_TITLE
        else
            title = name
        end

        -- FIXME: change to blizz framepool
        local ReusedPinFrame = tremove(MPHFramePool)
        local pin
        if not ReusedPinFrame then
            pin = CreatePin(x, y, mapID, function(e)
                if e == "remove" then
                    RemovePin(pin)
                    SupertrackClosest()
                elseif e == "track" then
                    UntrackPins()
                    pin.Track(pin.x, pin.y, pin.mapID)
                elseif e == "hyperlink" then
                    local link = MapPinEnhanced:FormatHyperlink(pin.x, pin.y, pin.mapID)
                    ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
                    ChatEdit_InsertLink(link)
                elseif e == "navigate" then
                    --MapPinEnhanced:navigateToPin(pin.x, pin.y, pin.mapID)
                end
            end, title, isPersistent)
            pin.ShowOnMap()
        else
            pin = ReusedPinFrame
            pin.x = x
            pin.y = y
            pin.mapID = mapID
            pin.title = title
            pin.setPersistent = isPersistent
            pin.SetTooltip(title)
            pin.MoveOnMap(x, y, mapID)
            pin.SetObjectiveTitle(title)
            pin.SetObjectiveText(x, y, mapID)

        end
        pins[#pins + 1] = pin

        if not noTrack then
            UntrackPins()
            pin.Track(x, y, mapID)
        else
            pin.scrollToObjective()
        end

        UpdateTrackerPositions()
        SavePinsPersistent()

    end

    local function RestorePin()
        for _, p in ipairs(pins) do
            if p.SupertrackClosest() then
                break
            end
        end
    end

    local function RefreshTracking()
        for _, p in ipairs(pins) do
            if p.IsTracked() then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end
    end

    local function RemoveTrackedPin()
        for _, p in ipairs(pins) do
            if p.IsTracked() then
                RemovePin(p)
                return
            end
        end
    end

    local function RestoreAllPins()
        if (not MapPinEnhanced.db.global.savedpins) then
            return
        end
        if (not MapPinEnhanced.db.global.savedpins.pinsData) then
            return
        end

        local pTracked = MapPinEnhanced.db.global.savedpins.lastTrackedPin
        local hasTracked = pTracked ~= nil

        for _, p in ipairs(MapPinEnhanced.db.global.savedpins.pinsData) do
            if hasTracked then
                AddPin(p.x, p.y, p.mapID, p.title, p.persistent,
                    not (p.x == pTracked.x and p.y == pTracked.y and p.mapID == pTracked.mapID))
            else
                AddPin(p.x, p.y, p.mapID, p.title, p.persistent, true)
            end
        end

        pinsRestored = true
    end

    local function RemoveAllPins()
        for i, pin in ipairs(pins) do
            pin.RemoveFromMap()
            tinsert(MPHFramePool, pin)
            pins[i] = nil
        end
        SavePinsPersistent()
        C_Map.ClearUserWaypoint()
    end

    local function GetAllPinData()
        local t = {}
        for i, pin in ipairs(pins) do
            tinsert(t, { pin.x, pin.y, pin.mapID, pin.title })
        end
        return t
    end

    local function HideAllPins()
        for i, pin in ipairs(pins) do
            pin.HidePin()
        end
    end

    local function ShowAllPins()
        for i, pin in ipairs(pins) do
            pin.ShowPin()
        end
    end

    local function GetNumPins() return #pins end

    return {
        AddPin = AddPin,
        RemovePin = RemovePin,
        RestorePin = RestorePin,
        UntrackPins = UntrackPins,
        RefreshTracking = RefreshTracking,
        RemoveTrackedPin = RemoveTrackedPin,
        RestoreAllPins = RestoreAllPins,
        RemoveAllPins = RemoveAllPins,
        GetAllPinData = GetAllPinData,
        UpdateTrackerPositions = UpdateTrackerPositions,
        HideAllPins = HideAllPins,
        ShowAllPins = ShowAllPins,
        GetNumPins = GetNumPins,
    }
end

MapPinEnhanced.pinManager = PinManager()




function MapPinEnhanced:AddWaypoint(x, y, mapID, name)
    if x and y and mapID then
        if not C_Map.CanSetUserWaypointOnMap(mapID) then
            self:PrintMSG({ "The blizzard arrow does not work in this zone" })
        end
        self.pinManager.AddPin(x, y, mapID, name)
    else
        error("x, y or mapID missing")
    end
end

function MapPinEnhanced:SUPER_TRACKING_CHANGED()
    if C_SuperTrack.IsSuperTrackingQuest() then
        self.pinManager.UntrackPins()
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
        C_Map.ClearUserWaypoint()
    else
        if not C_SuperTrack.IsSuperTrackingUserWaypoint() then
            self.pinManager.RefreshTracking()
        end
    end
    if self.db.global.options["showTimeOnSuperTrackedFrame"] and
        C_SuperTrack.IsSuperTrackingAnything() then
        if not self.distanceTimerFast then
            self.distanceTimerFast = self:ScheduleRepeatingTimer("DistanceTimerFast", 1, function(distance)
                if C_Navigation.WasClampedToScreen() then
                    if self.superTrackedTimer then
                        self.superTrackedTimer:Hide()
                    end
                else
                    self:UpdateTrackerTime(distance)
                    if self.superTrackedTimer then
                        self.superTrackedTimer:Show()
                    end
                end
            end)
        elseif self.distanceTimerFast.cancelled then
            self.distanceTimerFast = self:ScheduleRepeatingTimer("DistanceTimerFast", 1, function(distance)
                if C_Navigation.WasClampedToScreen() then
                    if self.superTrackedTimer then
                        self.superTrackedTimer:Hide()
                    end
                else
                    self:UpdateTrackerTime(distance)
                    if self.superTrackedTimer then
                        self.superTrackedTimer:Show()
                    end
                end
            end)
        end
    else
        if self.distanceTimerFast then
            self:CancelTimer(self.distanceTimerFast)
            self.distanceTimerFast = nil
            if self.superTrackedTimer then
                self.superTrackedTimer:Hide()
            end
        end
    end
end

function MapPinEnhanced:USER_WAYPOINT_UPDATED()
    if self.blockWAYPOINTevent then
        return
    end
    local userwaypoint = C_Map.GetUserWaypoint()
    if userwaypoint then
        local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
        if superTrackedQuestID ~= 0 then
            if C_QuestLog.IsWorldQuest(superTrackedQuestID) then
                C_QuestLog.RemoveWorldQuestWatch(superTrackedQuestID)
            else
                C_QuestLog.RemoveQuestWatch(superTrackedQuestID)
            end
        end
        self.blockWAYPOINTevent = true
        C_Map.ClearUserWaypoint()
        self.blockWAYPOINTevent = false
        self:AddWaypoint(userwaypoint.position.x, userwaypoint.position.y, userwaypoint.uiMapID)
    end
end

function MapPinEnhanced:PLAYER_LOGIN()
    C_Map.ClearUserWaypoint()
end

-- SuperTrackedTimer Text
function MapPinEnhanced:UpdateSuperTrackedTimerText(time)
    if not self.superTrackedTimer then
        local frame = CreateFrame("Frame", nil, SuperTrackedFrame)

        frame:SetSize(200, 20)
        frame:SetPoint("TOP", SuperTrackedFrame.DistanceText, "BOTTOM", 0, 0)


        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetAllPoints()
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")

        self.superTrackedTimer = text
    end

    if time > 0 then
        self.superTrackedTimer:SetText(TIMER_MINUTES_DISPLAY:format(floor(time / 60), floor(time % 60)))
    else
        self.superTrackedTimer:SetText("??:??")
    end
end

function MapPinEnhanced:UpdateTrackerTime(distance)
    if not C_SuperTrack.IsSuperTrackingAnything() then
        self:CancelTimer(self.distanceTimerFast)
        self.distanceTimerFast = nil
        self.lastDistance = nil
        if self.superTrackedTimer then
            self.superTrackedTimer:Hide()
        end
        return
    end
    if self.lastDistance then
        local speed = (self.lastDistance - distance)
        if speed > 0 then
            local time = distance / speed
            if time < 1800 then
                self:UpdateSuperTrackedTimerText(time)
            end
        end
    end
    self.lastDistance = distance
end

local TomTomLoaded
function MapPinEnhanced:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        self.pinManager.RestoreAllPins()
        -- Check if TomTom is Loaded
        if IsAddOnLoaded("TomTom") then
            TomTomLoaded = true
            self:PrintMSG({
                "TomTom is enabled! Using '/way' is disabled for MapPinEnhanced. You can use '/mph' instead."
            }) -- Localize
        else
            TomTomLoaded = false
        end
        if self.db.global.options["showTimeOnSuperTrackedFrame"] and
            (C_Map.GetUserWaypoint() and C_SuperTrack.IsSuperTrackingAnything()) then
            if not self.distanceTimerFast then
                self.distanceTimerFast = self:ScheduleRepeatingTimer("DistanceTimerFast", 1,
                    function(distance)
                        if C_Navigation.WasClampedToScreen() then
                            if self.superTrackedTimer then
                                self.superTrackedTimer:Hide()
                            end
                        else
                            self:UpdateTrackerTime(distance)
                            if self.superTrackedTimer then
                                self.superTrackedTimer:Show()
                            end
                        end
                    end)
            elseif self.distanceTimerFast.cancelled then
                self.distanceTimerFast = self:ScheduleRepeatingTimer("DistanceTimerFast", 1,
                    function(distance)
                        if C_Navigation.WasClampedToScreen() then
                            if self.superTrackedTimer then
                                self.superTrackedTimer:Hide()
                            end
                        else
                            self:UpdateTrackerTime(distance)
                            if self.superTrackedTimer then
                                self.superTrackedTimer:Show()
                            end
                        end
                    end)
            end
        end
    end
end

function MapPinEnhanced:DistanceTimerFast(cb)
    local distance = C_Navigation.GetDistance();
    cb(distance)
end

local wrongseparator = "(%d)" .. (tonumber("1.1") and "," or ".") .. "(%d)"
local rightseparator = "%1" .. (tonumber("1.1") and "." or ",") .. "%2"


function MapPinEnhanced:ParseImport(importstring)
    if not importstring then return end
    if self.pinManager.GetNumPins() > 0 then
        self.pinManager.RemoveAllPins()
    end
    local msg
    for s in importstring:gmatch("[^\r\n]+") do
        if string.match(s:lower(), "/way ") or string.match(s:lower(), "/mph ") or string.match(s:lower(), "/pin ") then
            msg = string.gsub(s, "/%a%a%a", "")
        else
            self:PrintMSG({ "Formating error! Use |cffeda55f/mph|r [x] [y] <title>" })
        end
        self:ParseInput(msg)
    end
end

function MapPinEnhanced:ParseInput(msg)
    if not msg then
        return
    end
    local sx
    local sy
    local smapid
    local stitle
    local matches = {}
    msg = msg:gsub("(%d)[%.,] (%d)", "%1 %2"):gsub(wrongseparator, rightseparator)
    local tokens = {}
    for token in msg:gmatch("%S+") do
        table.insert(tokens, token)
    end

    if tokens[1] and not tonumber(tokens[1]) then
        local zoneEnd
        for idx = 1, #tokens do
            local token = tokens[idx]
            if tonumber(token) then
                zoneEnd = idx - 1
                break
            end
        end

        if not zoneEnd then
            return
        end

        local zone = table.concat(tokens, " ", 1, zoneEnd)
        local x, y, title = select(zoneEnd + 1, unpack(tokens))

        if title then title = table.concat(tokens, " ", zoneEnd + 3) end
        local lzone = zone:lower():gsub("[%s]", "")
        for name, mapId in pairs(mapDataID) do
            local lname = name:lower():gsub("[%s]", "")
            if lname == lzone then
                -- We have an exact match
                matches = { name }
                break
            elseif lname:match(lzone) then
                table.insert(matches, name)
            end
        end

        if #matches > 1 and #matches < 7 then
            local msg = string.format("Found multiple matches for zone '%s'.  Did you mean: %s", zone,
                table.concat(matches, ", "))
            ChatFrame1:AddMessage(msg)
            return
        elseif #matches == 0 then
            local msg = string.format("Could not find any matches for zone %s.", zone)
            ChatFrame1:AddMessage(msg)
            return
        end

        -- There was only one match, so proceed
        local zoneName = matches[1]
        smapid = mapDataID[zoneName]

        x = x and tonumber(x)
        y = y and tonumber(y)

        if not x or not y then
            return
        end

        sx, sy = tonumber(x) / 100, tonumber(y) / 100


        stitle = table.concat(tokens, " ", zoneEnd + 3)
        if sx and sy and smapid then
            MapPinEnhanced:AddWaypoint(sx, sy, smapid, stitle)
        end
    elseif tokens[1] and tonumber(tokens[1]) then
        -- A vanilla set command
        local x, y, title = unpack(tokens)
        if not x or not tonumber(x) then
            return
        elseif not y or not tonumber(y) then
            return
        end
        if title then
            title = table.concat(tokens, " ", 3)
        end
        x = tonumber(x)
        y = tonumber(y)

        smapid = HBD:GetPlayerZone()
        sx, sy = unpack(tokens)
        if sx and sy and smapid then
            sx, sy = tonumber(sx) / 100, tonumber(sy) / 100
            stitle = table.concat(tokens, " ", 3)
            if sx and sy and smapid then
                MapPinEnhanced:AddWaypoint(sx, sy, smapid, stitle)
            end
        else
            MapPinEnhanced:PrintMSG({ "Formating error! Use |cffeda55f/mph|r [x] [y] <title>" })
        end
    else
        MapPinEnhanced:PrintMSG({ "Formating error! Use |cffeda55f/mph|r [x] [y] <title>" })
    end
end

function MapPinEnhanced:ParseExport()
    local pinData = MapPinEnhanced.pinManager.GetAllPinData()
    local output = ""
    for _, pin in ipairs(pinData) do
        -- check if pin has a title
        local title = ""
        if pin[4] ~= DEFAULT_PIN_TITLE and pin[4] then
            title = pin[4]
        end
        local slashcmd = string.format("/way #%d %.2f %.2f %s", pin[3], pin[1] * 100, pin[2] * 100, title)
        output = output .. slashcmd .. "\n"
    end
    return output
end

if not TomTomLoaded then
    SLASH_MPH1 = "/way"
end
SLASH_MPH2 = "/pin"
SLASH_MPH3 = "/mph"

SlashCmdList["MPH"] = function(msg)
    if msg == "removeall" then
        MapPinEnhanced.pinManager.RemoveAllPins()
    elseif msg == "tracker" then
        MapPinEnhanced:TogglePinTrackerWindow()
    elseif msg == "import" or msg == "export" then
        MapPinEnhanced:ToggleImportWindow()
    elseif msg == "minimap" then
        MapPinEnhanced:ToggleMinimapButton()
    elseif msg == "version" then
        local versionMPH = GetAddOnMetadata("MapPinEnhanced", "Version")
        local version, build = GetBuildInfo()
        MapPinEnhanced:PrintMSG({ MapPinEnhanced.name .. ": " .. versionMPH,
            string.format("Game: %s (%d)", version, build) },
            true)
    elseif msg == "config" or msg == "options" then
        if InterfaceOptionsFrame ~= nil then
            InterfaceOptionsFrame:Show()
        end
        InterfaceOptionsFrame_OpenToCategory(MapPinEnhanced.optionsFrame)
    elseif msg == "" or msg == "help" then
        MapPinEnhanced:PrintMSG({
            "|cffeda55f/mph config|r - Open the options menu",
            "|cffeda55f/mph tracker|r - Toggle the Pin Tracker Window",
            "|cffeda55f/mph import|r - Toggle the Import Window",
            "|cffeda55f/mph minimap|r - Toggle the Minimap Button",
            "|cffeda55f/mph removeall|r - Remove all pins",
            "|cffeda55f/mph version|r - Show version information",
        }, true)
    else
        MapPinEnhanced:ParseInput(msg)
    end
end







function MapPinEnhanced:DistanceTimer(cb)
    local hasBlizzWaypoint = C_Map.HasUserWaypoint()
    if hasBlizzWaypoint then
        local distance = C_Navigation.GetDistance()
        if distance == 0 then
            cb(-1)
            self.distanceTimer.delay = 1
        else
            cb(distance)
            self.distanceTimer.delay = (0.015 * distance ^ (0.7)) -- calc new update delay based on distance
        end
    else
        self:CancelTimer(self.distanceTimer)
    end
end

hooksecurefunc(WaypointLocationPinMixin, "OnAcquired", function(self) -- hide default blizzard waypoint
    self:SetAlpha(0)
    self:EnableMouse(false)
end)



-- Set globally available functions
globalMPH.AddWaypoint = MapPinEnhanced.AddWaypoint
globalMPH.ParseInput = MapPinEnhanced.ParseInput
globalMPH.ParseExport = MapPinEnhanced.ParseExport
