MPHFrameMixin = {};

function MPHFrameMixin:OnLoad()
    self.scrollFrame.ScrollBar.ScrollDownButton.Disabled:SetDesaturated(true)
    self.scrollFrame.ScrollBar.ScrollDownButton.Disabled:SetAtlas("NPE_ArrowDown")
    self.scrollFrame.ScrollBar.ScrollDownButton.Disabled:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ScrollDownButton.Highlight:SetAtlas("NPE_ArrowDownGlow")
    self.scrollFrame.ScrollBar.ScrollDownButton.Highlight:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ScrollDownButton.Normal:SetAtlas("NPE_ArrowDown")
    self.scrollFrame.ScrollBar.ScrollDownButton.Normal:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ScrollDownButton.Pushed:SetAtlas("NPE_ArrowDown")
    self.scrollFrame.ScrollBar.ScrollDownButton.Pushed:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ScrollUpButton.Disabled:SetAtlas("NPE_ArrowUp")
    self.scrollFrame.ScrollBar.ScrollUpButton.Disabled:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ScrollUpButton.Disabled:SetDesaturated(true)
    self.scrollFrame.ScrollBar.ScrollUpButton.Highlight:SetAtlas("NPE_ArrowUpGlow")
    self.scrollFrame.ScrollBar.ScrollUpButton.Highlight:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ScrollUpButton.Normal:SetAtlas("NPE_ArrowUp")
    self.scrollFrame.ScrollBar.ScrollUpButton.Normal:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ScrollUpButton.Pushed:SetAtlas("NPE_ArrowUp")
    self.scrollFrame.ScrollBar.ScrollUpButton.Pushed:SetAlpha(0.6)
    self.scrollFrame.ScrollBar.ThumbTexture:SetAtlas("voicechat-icon-loudnessbar-2")
    self.scrollFrame.ScrollBar.ThumbTexture:SetAtlas("voicechat-icon-loudnessbar-2")
    self.scrollFrame.ScrollBar.ThumbTexture:SetAlpha(0.6)
    self.scrollFrame.ScrollBar:Hide()


    local navigationStepFrame = CreateFrame("Frame", "MPHNavigationStepFrame", self, "MPHNavigationStepFrameTemplate")

    self.NavigationStepFrame = navigationStepFrame
end

function MPHFrameMixin:OnDragStart()
    if IsControlKeyDown() then
        self:StartMoving()
    end
end

function MPHFrameMixin:OnDragStop(s)
    self:StopMovingOrSizing()
end
