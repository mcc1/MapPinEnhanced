---@class MapPinEnhanced
local MapPinEnhanced = select(2, ...)


---@class MapPinEnhancedTrackerTextImportButtonMixin : Button
MapPinEnhancedTrackerTextImportButtonMixin = {}


function MapPinEnhancedTrackerTextImportButtonMixin:OnLoad()
    print("MapPinEnhancedTrackerTextImportButtonMixin:OnLoad()")
end

function MapPinEnhancedTrackerTextImportButtonMixin:OnClick()
    MapPinEnhanced:ToggleImportWindow()
end
