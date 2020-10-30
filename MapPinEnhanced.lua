local addonName, addon = ...
local MPH = addon

_G.MPH = MPH

local hbd = LibStub("HereBeDragons-2.0")
local hbdp = LibStub("HereBeDragons-Pins-2.0")

local waypoints = {}

local blockevent = false

local function PinManager(point)
end



function MPH:AddWaypoint(x, y, mapID)
    if x and y and mapID then
        local pin = CreateFrame("Button", nil, MPH_MapOverlayFrame)
        pin:SetSize(30, 30)
        pin:EnableMouse(true)
        pin:SetMouseClickEnabled(true)
        
        pin.supertracked = false
        pin.x = x
        pin.y = y
        pin.mapID = mapID

        pin.icon = pin:CreateTexture(nil, "BACKGROUND")
        pin.icon:SetAtlas("Waypoint-MapPin-Untracked", true)
        pin.icon:SetSize(30, 30)
        pin.icon:SetBlendMode("BLEND")
        pin.icon:SetAllPoints(pin)
        pin:SetScript("OnMouseDown", function(self, arg1)
            if arg1 == "LeftButton" then
                if self.supertracked then
                    self.supertracked = false
                    self.icon:SetAtlas("Waypoint-MapPin-Untracked", true)
                else
                    self.supertracked = true
                    self.icon:SetAtlas("Waypoint-MapPin-Tracked", true)
                    blockevent = true
                    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(self.mapID, self.x,self.y))
                    blockevent = false
                    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                end
                if IsShiftKeyDown() then
                    print("shift")
                end
                if IsControlKeyDown() then
                    pin:Hide()
                end
            end 
            self:SetPoint("CENTER", 2, -2)
        end)

        pin:SetScript("OnMouseUp", function(self, arg1)
            self:SetPoint("CENTER", 0, 0)
        end)

        pin:SetScript("OnEnter", function(self, motion)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cFFFF7D0AKrillidi|r hat gerade geduscht!")
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function(self, motion)
            GameTooltip:Hide()
        end)


        local highlightTexture = pin:CreateTexture(nil, "HIGHLIGHT")
        highlightTexture:SetAllPoints(true)
        highlightTexture:SetAtlas("Waypoint-MapPin-Highlight", true)

        hbdp:AddWorldMapIconMap(self, pin, mapID, x, y, 3)
        waypoints[userwaypoint] = pin
    else
        error("x, y or mapID missing")
    end
end





local function OnEvent(self, event, ...)
    print(self, event, ...)
    if blockevent then return end
    if not MPH_MapOverlayFrame then
        local overlay = CreateFrame("Frame", "MPH_MapOverlayFrame", WorldMapFrame.BorderFrame)
        overlay:SetFrameStrata("HIGH")
        overlay:SetFrameLevel(9000)
        overlay:SetAllPoints(true)
    end
    local userwaypoint = C_Map.GetUserWaypoint()
    blockevent = true
    C_Map.ClearUserWaypoint()
    blockevent = false
    if userwaypoint then
        local x, y = userwaypoint["position"]["x"], userwaypoint["position"]["y"]
        local mapID = userwaypoint["uiMapID"]    
        MPH:AddWaypoint(x, y, mapID)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("USER_WAYPOINT_UPDATED")
f:SetScript("OnEvent", OnEvent)


