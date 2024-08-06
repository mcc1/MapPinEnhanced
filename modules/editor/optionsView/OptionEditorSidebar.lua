-- Template: file://./OptionEditorSidebar.xml

---@class MapPinEnhanced
local MapPinEnhanced = select(2, ...)

---@class CategoryListScrollFrame : ScrollFrame
---@field Child Frame




---@class MapPinEnhancedOptionEditorViewSidebarMixin : Frame
---@field switchViewButton Button
---@field body MapPinEnhancedOptionEditorViewBodyMixin
---@field categoryButtonPool FramePool
---@field scrollFrame CategoryListScrollFrame
---@field header Frame
MapPinEnhancedOptionEditorViewSidebarMixin = {}



local Options = MapPinEnhanced:GetModule("Options")


function MapPinEnhancedOptionEditorViewSidebarMixin:UpdateCategoryList()
    local categories = Options:GetCategories()
    local lastCategoryButton = nil
    local activeButton = nil
    for i, category in ipairs(categories) do
        local categoryButton = self.categoryButtonPool:Acquire() --[[@as MapPinEnhancedOptionEditorViewCategoryButtonMixin]]
        categoryButton:SetLabel(category)
        categoryButton:SetInactive()

        categoryButton:ClearAllPoints()
        if lastCategoryButton then
            categoryButton:SetPoint("TOPLEFT", lastCategoryButton, "BOTTOMLEFT", 0, -10)
            categoryButton:SetPoint("TOPRIGHT", lastCategoryButton, "BOTTOMRIGHT", 0, -10)
        else
            categoryButton:SetPoint("TOP", self.scrollFrame.Child)
            categoryButton:SetPoint("LEFT", self.scrollFrame.Child)
            categoryButton:SetPoint("RIGHT", self.scrollFrame.Child)
            categoryButton:SetActive() -- set the first category to active
            activeButton = categoryButton
        end
        categoryButton:SetParent(self.scrollFrame.Child)
        categoryButton:SetScript("OnClick", function()
            self.body:SetActiveCategory(category)
        end)
        categoryButton:Show()
        categoryButton:SetScript("OnClick", function()
            -- FIXME: highlight is not working properly
            self.body:SetActiveCategory(category)
            if activeButton then
                activeButton:SetInactive()
            end
            categoryButton:SetActive()
            activeButton = categoryButton
        end)
        lastCategoryButton = categoryButton
    end
end

function MapPinEnhancedOptionEditorViewSidebarMixin:OnShow()
    self:UpdateCategoryList()
end

function MapPinEnhancedOptionEditorViewSidebarMixin:OnLoad()
    self.categoryButtonPool = CreateFramePool("Button", nil, "MapPinEnhancedOptionEditorViewCategoryButtonTemplate")


    self.header:SetScript("OnMouseDown", function(self)
        MapPinEnhanced.editorWindow:StartMoving()
        SetCursor("Interface/CURSOR/UI-Cursor-Move.crosshair")
    end)

    self.header:SetScript("OnMouseUp", function(self)
        MapPinEnhanced.editorWindow:StopMovingOrSizing()
        SetCursor(nil)
    end)
end
