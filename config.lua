local core = LibStub("AceAddon-3.0"):GetAddon("MapPinEnhanced")
local module = core:NewModule("Config")



local AceGUI = LibStub("AceGUI-3.0")

local function setSettingsOnLoad()
    if core.db.profile.options["changedalpha"] then
        SuperTrackedFrameMixin:SetTargetAlphaForState(0, 1)
        SuperTrackedFrameMixin:SetTargetAlphaForState(1, 1)
    end
end

function module:OnInitialize()
    if not core.db then return end
    setSettingsOnLoad()

    local f = AceGUI:Create("SimpleGroup")
    f:SetLayout("Flow")

    local cb1 = AceGUI:Create("CheckBox")
    cb1:SetLabel("Unlimited Supertrack Distance")
    cb1:SetValue(core.db.profile.options["changedalpha"])
    cb1:SetCallback("OnValueChanged", function(widget, event, value)
        if value == true then
            core.db.profile.options["changedalpha"] = true
            SuperTrackedFrameMixin:SetTargetAlphaForState(0, 1)
            SuperTrackedFrameMixin:SetTargetAlphaForState(1, 1)
        elseif value == false then
            core.db.profile.options["changedalpha"] = false
            SuperTrackedFrameMixin:SetTargetAlphaForState(0, 0)
            SuperTrackedFrameMixin:SetTargetAlphaForState(1, 0.6)
        end

    end)
    f:AddChild(cb1)




    local category = Settings.RegisterCanvasLayoutCategory(f.frame, core.GetName(core))
    Settings.RegisterAddOnCategory(category)




end
