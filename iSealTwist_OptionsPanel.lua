-- Settings window and shared controls.

local addonName, iST = ...
local L = iST.L or {}
local Colors = iST.Colors or {}
local print = function(...) iST:PrintToChat(...) end

local BACKDROP_TEMPLATE = "BackdropTemplate"
local CHECKBOX_TEMPLATE = InterfaceOptionsCheckButtonTemplate and "InterfaceOptionsCheckButtonTemplate" or "UICheckButtonTemplate"
local iconPath = iST.AddonPath .. "Images\\Logo_iST.blp"
local ORANGE = { 1, 0.59, 0.09 }
local openDropdown

local function CombatLocked()
    if type(InCombatLockdown) ~= "function" then return false end
    local locked = InCombatLockdown()
    return (issecretvalue and issecretvalue(locked)) or locked == true
end

local PANEL_BACKDROP = {
    bgFile = "Interface\\BUTTONS\\WHITE8X8",
    edgeFile = "Interface\\BUTTONS\\WHITE8X8",
    edgeSize = 1,
}

local function StyleSettingsSurface(frame, header)
    frame:SetBackdrop(PANEL_BACKDROP)
    if header then frame:SetBackdropColor(0.075, 0.058, 0.035, 0.98)
    else frame:SetBackdropColor(0.025, 0.023, 0.020, 0.98) end
    frame:SetBackdropBorderColor(0.32, 0.25, 0.14, 1)
end

local function StyleSettingsCheckbox(cb)
    cb:SetSize(24, 24)
    cb:SetNormalTexture("Interface\\BUTTONS\\WHITE8X8")
    cb:GetNormalTexture():SetVertexColor(0, 0, 0, 0)
    cb:SetPushedTexture("Interface\\BUTTONS\\WHITE8X8")
    cb:GetPushedTexture():SetVertexColor(0.18, 0.13, 0.06, 1)
    cb:SetHighlightTexture("Interface\\BUTTONS\\WHITE8X8", "ADD")
    cb:GetHighlightTexture():SetVertexColor(0.5, 0.32, 0.09, 0.25)
    local background = CreateFrame("Frame", nil, cb, BACKDROP_TEMPLATE)
    background:SetAllPoints(cb)
    background:SetFrameLevel(math.max(0, cb:GetFrameLevel() - 1))
    background:SetBackdrop(PANEL_BACKDROP)
    background:SetBackdropColor(0.035, 0.030, 0.022, 1)
    background:SetBackdropBorderColor(0.42, 0.32, 0.15, 1)
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:GetCheckedTexture():SetVertexColor(1, 0.76, 0.30, 1)
    cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    cb.Text:ClearAllPoints()
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
end

local function StyleSettingsScroll(scrollFrame)
    local bar = scrollFrame.ScrollBar
    if not bar then return end
    for _, texture in ipairs({ bar:GetRegions() }) do
        if texture.IsObjectType and texture:IsObjectType("Texture") then texture:SetAlpha(0) end
    end
    -- The template can expose arrows under different keys. Hide its actual
    -- button children and prevent range updates from showing them again.
    local hiddenButtons = {}
    local function HideArrow(button)
        if not button or hiddenButtons[button] then return end
        if not button.IsObjectType or not button:IsObjectType("Button") then return end
        hiddenButtons[button] = true
        button:SetAlpha(0)
        button:EnableMouse(false)
        button:Hide()
        button:HookScript("OnShow", function(self) self:Hide() end)
    end
    HideArrow(bar.ScrollUpButton)
    HideArrow(bar.ScrollDownButton)
    for _, owner in ipairs({ bar, scrollFrame }) do
        for _, child in ipairs({ owner:GetChildren() }) do HideArrow(child) end
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -3)
    bar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 3)
    bar:SetWidth(8)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(bar)
    track:SetColorTexture(0.11, 0.09, 0.06, 0.7)
    bar:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
    bar:GetThumbTexture():SetSize(8, 28)
    bar:GetThumbTexture():SetVertexColor(0.72, 0.48, 0.17, 1)
    bar:GetThumbTexture():SetAlpha(1)
end

-- Layout helpers return the next free row so descriptions can wrap naturally.

local SETTING_DESCRIPTIONS = {
    [L["BarVisibility"]] = L["BarVisibilityDesc"],
    [L["WrathCueCounter"]] = L["WrathCueCounterDesc"],
    [L["WrathCueCircles"]] = L["WrathCueCirclesDesc"],
    [L["WrathCueBarColor"]] = L["WrathCueBarColorDesc"],
    [L["StackBubbleStyle"]] = L["StackBubbleStyleDesc"],
    [L["StackCounterTextSize"]] = L["StackCounterTextSizeDesc"],
    [L["WrathCircleSize"]] = L["WrathCircleSizeDesc"],
    [L["PlayerPipSize"]] = L["PlayerPipSizeDesc"],
    [L["CenterSwitchMode"]] = L["CenterSwitchModeDesc"],
    [L["CenterSwitchPhrase"]] = L["CenterSwitchPhraseDesc"],
    [L["CenterAttackPhrase"]] = L["CenterAttackPhraseDesc"],
    [L["ReminderEnable"]] = L["ReminderEnableDesc"],
    [L["OnlyInCombat"]] = L["ReminderOnlyInCombatDesc"],
    [L["ReminderThreshold"]] = L["ReminderThresholdDesc"],
    [L["ReminderShowIcon"]] = L["ReminderShowIconDesc"],
    [L["ReminderShowTime"]] = L["ReminderShowTimeDesc"],
    [L["ReminderScale"]] = L["ReminderScaleDesc"],
    [L["ReminderSoundExpiring"]] = L["ReminderSoundExpiringDesc"],
    [L["ReminderSoundMissing"]] = L["ReminderSoundMissingDesc"],
    [L["SoundChoice"]] = L["SoundChoiceDesc"],
    [L["BarStyle"]] = L["BarStyleDesc"],
    [L["BarTexture"]] = L["BarTextureDesc"],
    [L["BarWidth"]] = L["BarWidthDesc"],
    [L["BarHeight"]] = L["BarHeightDesc"],
    [L["IconSize"]] = L["IconSizeDesc"],
    [L["SwingTextSize"]] = L["SwingTextSizeDesc"],
    [L["CurrentSealTextSize"]] = L["CurrentSealTextSizeDesc"],
    [L["LatencyTextSize"]] = L["LatencyTextSizeDesc"],
    [L["ColorBar"]] = L["ColorBarDesc"],
    [L["ColorWrongSeal"]] = L["ColorWrongSealDesc"],
    [L["ColorBorderNormal"]] = L["ColorBorderNormalDesc"],
    [L["PreviewSealColor"]] = L["PreviewSealColorDesc"],
    [L["WrathColorScheme"]] = L["WrathColorSchemeDesc"],
    [L["ColorSwitchMessage"]] = L["ColorSwitchMessageDesc"],
    [L["ColorAttackMessage"]] = L["ColorAttackMessageDesc"],
    [L["ColorNameplateEcho"]] = L["ColorNameplateEchoDesc"],
    [L["ColorEchoTimerText"]] = L["ColorEchoTimerTextDesc"],
    [L["NameplateEchoStyle"]] = L["NameplateEchoStyleDesc"],
    [L["NameplateEchoScale"]] = L["NameplateEchoScaleDesc"],
    [L["NameplateEchoPipSize"]] = L["NameplateEchoPipSizeDesc"],
    [L["NameplateEchoOffset"]] = L["NameplateEchoOffsetDesc"],
    [L["NameplateEchoGlow"]] = L["NameplateEchoGlowDesc"],
    [L["ProfileChoose"]] = L["ProfileChooseDesc"],
    [L["DebugMode"]] = L["DebugModeDesc"],
}

local function CreateSettingDescription(parent, text, xOffset, yOffset, width)
    if not text or text == "" then return nil, yOffset end
    local description = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    description:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    description:SetWidth(width)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    description:SetText(text)
    return description, yOffset - math.max(12, description:GetStringHeight()) - 8
end

local function CreateSectionHeader(parent, text, yOffset)
    local header = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    if header.SetBackdrop then
        header:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
        header:SetBackdropColor(0.11, 0.08, 0.035, 0.6)
    end

    local accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(1)
    accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    accent:SetColorTexture(1, 0.59, 0.09, 0.4)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", header, "LEFT", 8, 0)
    label:SetText(text)
    label:SetTextColor(ORANGE[1], 0.75, 0.20)

    return header, yOffset - 34
end

local function CreateSettingsCheckbox(parent, label, descText, yOffset, getFunc, setFunc, indent)
    indent = indent or 0
    local cb = CreateFrame("CheckButton", nil, parent, CHECKBOX_TEMPLATE)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20 + indent, yOffset)
    if not cb.Text then
        cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    end
    StyleSettingsCheckbox(cb)
    cb.Text:SetText(label)
    cb.Text:SetFontObject(GameFontHighlight)
    cb.Text:SetTextColor(0.96, 0.90, 0.78)
    cb:SetChecked(getFunc())
    cb:SetScript("OnClick", function(self)
        setFunc(self:GetChecked() and true or false)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
        if iST.SettingsFrame and iST.SettingsFrame.RefreshAvailability then
            iST.SettingsFrame.RefreshAvailability()
        end
    end)

    -- The checkbox template is taller than its label. Reserve the whole control
    -- before placing descriptions or the next row underneath it.
    local nextY = yOffset - math.max(24, cb:GetHeight()) - 6
    local description
    description, nextY = CreateSettingDescription(parent, descText or SETTING_DESCRIPTIONS[label],
        52 + indent, nextY, parent:GetWidth() - 72 - indent)

    function cb:SetControlEnabled(enabled)
        enabled = enabled == true
        if self:IsEnabled() == enabled then return end
        if enabled then self:Enable() else self:Disable() end
        self:SetAlpha(enabled and 1 or 0.4)
        if description then description:SetAlpha(enabled and 1 or 0.4) end
    end

    return cb, nextY
end

local function CreateCustomSlider(parent, label, yOffset, minVal, maxVal, step, getFunc, setFunc, formatFunc)
    local ROW_HEIGHT = 36
    local TRACK_WIDTH = 420
    local TRACK_HEIGHT = 6
    local THUMB_SIZE = 14

    local sliderLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sliderLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    sliderLabel:SetText(label)
    sliderLabel:SetTextColor(0.96, 0.90, 0.78)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", sliderLabel, "RIGHT", 10, 0)
    local description, nextY = CreateSettingDescription(parent, SETTING_DESCRIPTIONS[label],
        20, yOffset - ROW_HEIGHT, parent:GetWidth() - 40)

    local function UpdateValueText(val)
        if formatFunc then
            valueText:SetText(Colors.iST .. formatFunc(val))
        else
            valueText:SetText(Colors.iST .. tostring(val))
        end
    end

    local track = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    track:SetSize(TRACK_WIDTH, TRACK_HEIGHT)
    track:SetPoint("TOPLEFT", parent, "TOPLEFT", 25, yOffset - 18)
    track:EnableMouse(true)
    track:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    track:SetBackdropColor(0.025, 0.022, 0.018, 1)
    track:SetBackdropBorderColor(0.52, 0.33, 0.09, 0.95)

    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.055, 0.045, 0.032, 0.96)

    local trackEdgeTop = track:CreateTexture(nil, "BACKGROUND", nil, 1)
    trackEdgeTop:SetHeight(1)
    trackEdgeTop:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    trackEdgeTop:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
    trackEdgeTop:SetColorTexture(0.75, 0.45, 0.10, 0.22)

    local trackEdgeBottom = track:CreateTexture(nil, "BACKGROUND", nil, 1)
    trackEdgeBottom:SetHeight(1)
    trackEdgeBottom:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    trackEdgeBottom:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)
    trackEdgeBottom:SetColorTexture(0, 0, 0, 0.80)

    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    fill:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.78)

    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(THUMB_SIZE, THUMB_SIZE)
    thumb:EnableMouse(true)

    local thumbOuter = thumb:CreateTexture(nil, "OVERLAY", nil, 1)
    thumbOuter:SetSize(THUMB_SIZE, THUMB_SIZE)
    thumbOuter:SetPoint("CENTER")
    thumbOuter:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    thumbOuter:SetVertexColor(0.18, 0.11, 0.035, 1)

    local thumbInner = thumb:CreateTexture(nil, "OVERLAY", nil, 2)
    thumbInner:SetSize(THUMB_SIZE - 3, THUMB_SIZE - 3)
    thumbInner:SetPoint("CENTER")
    thumbInner:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    thumbInner:SetVertexColor(1, 0.59, 0.09, 1)

    thumb:SetScript("OnEnter", function()
        thumbInner:SetVertexColor(1, 0.75, 0.3, 1)
    end)
    thumb:SetScript("OnLeave", function()
        thumbInner:SetVertexColor(1, 0.59, 0.09, 1)
    end)

    local function SetVisualValue(val)
        val = math.max(minVal, math.min(maxVal, val))
        local fraction = (val - minVal) / (maxVal - minVal)
        local xPos = fraction * (TRACK_WIDTH - THUMB_SIZE)
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", track, "LEFT", xPos, 0)
        fill:SetWidth(math.max(1, fraction * TRACK_WIDTH))
        UpdateValueText(val)
    end

    local function SnapValue(val)
        return math.floor((val - minVal) / step + 0.5) * step + minVal
    end

    local function ValueFromMouse()
        -- Convert screen pixels to UI coordinates before finding the slider value.
        local cx = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local left = track:GetLeft()
        local fraction = (cx - left) / TRACK_WIDTH
        fraction = math.max(0, math.min(1, fraction))
        local raw = minVal + fraction * (maxVal - minVal)
        return SnapValue(raw)
    end

    -- Dragging either the knob or the track updates the setting as it moves.
    local isDragging = false
    local controlEnabled = true
    function track:SetControlEnabled(enabled)
        enabled = enabled == true
        if controlEnabled == enabled then return end
        controlEnabled = enabled
        if not controlEnabled then isDragging = false end
        self:EnableMouse(controlEnabled)
        self:EnableMouseWheel(controlEnabled)
        thumb:EnableMouse(controlEnabled)
        self:SetAlpha(controlEnabled and 1 or 0.35)
        sliderLabel:SetAlpha(controlEnabled and 1 or 0.45)
        valueText:SetAlpha(controlEnabled and 1 or 0.45)
        if description then description:SetAlpha(controlEnabled and 1 or 0.45) end
    end
    thumb:SetScript("OnMouseDown", function() if controlEnabled then isDragging = true end end)
    thumb:SetScript("OnMouseUp", function() isDragging = false end)
    track:SetScript("OnMouseDown", function()
        if not controlEnabled then return end
        local val = ValueFromMouse()
        setFunc(val)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
        SetVisualValue(val)
        isDragging = true
    end)
    track:SetScript("OnMouseUp", function() isDragging = false end)
    track:SetScript("OnUpdate", function()
        if not controlEnabled or not isDragging then return end
        local val = ValueFromMouse()
        setFunc(val)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
        SetVisualValue(val)
    end)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        if not controlEnabled then return end
        local current = getFunc()
        local newVal = SnapValue(current + delta * step)
        newVal = math.max(minVal, math.min(maxVal, newVal))
        setFunc(newVal)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
        SetVisualValue(newVal)
    end)

    SetVisualValue(getFunc())
    return track, nextY
end

local function StyleSettingsButton(btn)
    if not btn:GetFontString() then
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        btn:SetFontString(text)
    end
    btn:SetBackdrop(PANEL_BACKDROP)
    btn:SetBackdropColor(0.035, 0.030, 0.022, 1)
    btn:SetBackdropBorderColor(0.52, 0.38, 0.17, 1)
    btn:SetNormalFontObject(GameFontNormal)
    btn:SetHighlightFontObject(GameFontHighlight)
    local function RefreshButton(self)
        local enabled = self:IsEnabled()
        if enabled and self.settingsPressed then self:SetBackdropColor(0.09, 0.065, 0.025, 1)
        elseif enabled and self.settingsHovered then self:SetBackdropColor(0.14, 0.10, 0.04, 1)
        else self:SetBackdropColor(0.035, 0.030, 0.022, 1) end
        if enabled and self.settingsHovered then self:SetBackdropBorderColor(0.78, 0.53, 0.18, 1)
        else self:SetBackdropBorderColor(0.52, 0.38, 0.17, 1) end
        self:SetAlpha(enabled and 1 or 0.45)
    end
    btn:SetScript("OnEnter", function(self)
        self.settingsHovered = true
        RefreshButton(self)
    end)
    btn:SetScript("OnLeave", function(self)
        self.settingsHovered, self.settingsPressed = false, false
        RefreshButton(self)
    end)
    btn:SetScript("OnMouseDown", function(self) self.settingsPressed = true; RefreshButton(self) end)
    btn:SetScript("OnMouseUp", function(self) self.settingsPressed = false; RefreshButton(self) end)
    btn:SetScript("OnDisable", function(self) self.settingsPressed = false; RefreshButton(self) end)
    btn:SetScript("OnEnable", RefreshButton)
    btn:GetFontString():SetTextColor(ORANGE[1], ORANGE[2], ORANGE[3])
end

local function CreateSettingsButton(parent, text, width, yOffset, onClick)
    local btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    btn:SetSize(width, 26)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    StyleSettingsButton(btn)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn, yOffset - 34
end

local function CreateSettingsButtonAt(parent, text, width, xOffset, yOffset, onClick, smallText)
    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    button:SetSize(width, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    StyleSettingsButton(button)
    if smallText then
        button:SetNormalFontObject(GameFontNormalSmall)
        button:SetHighlightFontObject(GameFontHighlightSmall)
    end
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function OpenMacroWindow()
    -- Opening and changing macros is blocked during combat.
    if InCombatLockdown and InCombatLockdown() then
        print(L["MacroWindowCombatBlocked"])
        return
    end

    if GetMacroIndexByName and GetMacroIndexByName("SealTwist") == 0 then
        iST:CreateTwistMacro()
    end

    if MacroFrame_LoadUI then
        pcall(MacroFrame_LoadUI)
    elseif C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI")
    end

    if iST.SettingsFrame then iST.SettingsFrame:Hide() end
    if ShowMacroFrame then
        ShowMacroFrame()
    elseif MacroFrame and ShowUIPanel then
        ShowUIPanel(MacroFrame)
    elseif ToggleMacroFrame then
        ToggleMacroFrame()
    end

    local function SelectSealTwistMacro()
        if not GetMacroIndexByName then return end
        local macroIndex = GetMacroIndexByName("SealTwist")
        if not macroIndex or macroIndex == 0 or not MacroFrame then return end

        -- The current macro window numbers selections within each tab.
        -- Convert the saved slot to its account or character tab first.
        if type(MacroFrame.ChangeTab) == "function" and type(MacroFrame.SelectMacro) == "function" then
            local macroConstants = Constants and Constants.MacroConsts
            local accountLimit = MAX_ACCOUNT_MACROS
                or (macroConstants and macroConstants.MAX_ACCOUNT_MACROS) or 120
            local tabID = macroIndex > accountLimit and 2 or 1
            local selectionIndex = tabID == 2 and (macroIndex - accountLimit) or macroIndex
            pcall(function()
                MacroFrame:ChangeTab(tabID)
                MacroFrame:SelectMacro(selectionIndex, true)
            end)
        elseif MacroFrame_SelectMacro then
            -- This selector uses the full macro slot number instead.
            pcall(MacroFrame_SelectMacro, macroIndex)
        end
    end

    -- Wait for the macro window to finish opening before selecting our macro.
    -- Otherwise its own refresh selects the first account macro again.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SelectSealTwistMacro)
    else
        SelectSealTwistMacro()
    end
end

local function CreateStyledDropdown(parent, width, getOptions, getValue, setValue, getOptionText, isDisabled, maxRows, previewSound)
    local dropdown = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    dropdown:SetSize(width, 28)
    StyleSettingsButton(dropdown)
    function dropdown:SetControlEnabled(enabled)
        enabled = enabled == true
        if self:IsEnabled() == enabled then return end
        if enabled then self:Enable() else self:Disable() end
        if not enabled and self.menu then self.menu:Hide() end
    end

    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 11, 0)
    dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -30, 0)
    dropdown.text:SetJustifyH("LEFT")
    dropdown.text:SetWordWrap(false)
    dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -10, 0)
    dropdown.arrow:SetText("v")
    dropdown.arrow:SetTextColor(1, 0.72, 0.12)

    -- Keep the menu outside the scrolling page so its rows are not clipped.
    dropdown.menu = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    dropdown.menu:SetWidth(width)
    dropdown.menu:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdown.menu:SetClampedToScreen(true)
    dropdown.menu:SetToplevel(true)
    dropdown.menu:EnableMouse(true)
    StyleSettingsSurface(dropdown.menu)
    local dismiss = CreateFrame("Button", nil, UIParent)
    dismiss:SetAllPoints(UIParent)
    dismiss:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdown.menu:SetFrameLevel(dismiss:GetFrameLevel() + 1)
    dismiss:SetScript("OnClick", function() dropdown.menu:Hide() end)
    dismiss:Hide()
    dropdown.menu.dismiss = dismiss
    dropdown.menu:SetScript("OnShow", function() dismiss:Show() end)
    dropdown.menu:SetScript("OnHide", function()
        dismiss:Hide()
        if dropdown.menu.scrollTrack then dropdown.menu.scrollTrack:SetScript("OnUpdate", nil) end
        if openDropdown == dropdown then openDropdown = nil end
    end)
    dropdown.menu.buttons = {}
    if maxRows then
        local function ScrollMenu(menu, delta)
            local options = menu.options or {}
            local maximum = math.max(0, #options - maxRows)
            menu.scrollOffset = math.max(0, math.min(maximum, (menu.scrollOffset or 0) - delta))
            dropdown:RefreshMenu()
        end
        dropdown.menu.scrollMenu = ScrollMenu
        dropdown.menu:EnableMouseWheel(true)
        dropdown.menu:SetScript("OnMouseWheel", ScrollMenu)
        if maxRows then
            local track = CreateFrame("Button", nil, dropdown.menu, BACKDROP_TEMPLATE)
            track:SetWidth(8)
            track:SetPoint("TOPRIGHT", dropdown.menu, "TOPRIGHT", -4, -5)
            track:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            track:SetBackdropColor(0.12, 0.10, 0.07, 1)
            track:EnableMouseWheel(true)
            track:SetScript("OnMouseWheel", function(_, delta)
                ScrollMenu(dropdown.menu, delta)
            end)
            local thumb = track:CreateTexture(nil, "ARTWORK")
            thumb:SetWidth(8)
            thumb:SetColorTexture(0.78, 0.50, 0.16, 1)
            track.thumb = thumb
            local function SeekMenu(self)
                if not GetCursorPosition then return end
                local _, cursorY = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                local top = self:GetTop()
                if not top or not scale or scale == 0 then return end
                local fraction = math.max(0, math.min(1, (top - cursorY / scale) / self:GetHeight()))
                local maximum = math.max(0, #(dropdown.menu.options or {}) - maxRows)
                dropdown.menu.scrollOffset = math.floor(maximum * fraction + 0.5)
                dropdown:RefreshMenu()
            end
            track:SetScript("OnMouseDown", SeekMenu)
            track:RegisterForDrag("LeftButton")
            track:SetScript("OnDragStart", function(self)
                SeekMenu(self)
                self:SetScript("OnUpdate", SeekMenu)
            end)
            track:SetScript("OnDragStop", function(self)
                self:SetScript("OnUpdate", nil)
            end)
            dropdown.menu.scrollTrack = track
        end
    end
    dropdown.menu:Hide()

    local function OptionValue(option)
        return type(option) == "table" and option.value or option
    end

    local function OptionText(option)
        if getOptionText then return getOptionText(option) end
        if type(option) == "table" then return option.text or tostring(option.value) end
        return tostring(option)
    end

    local function DisabledOptionText(option)
        -- Text color codes override SetTextColor; remove them for greyed-out rows.
        return OptionText(option):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end

    function dropdown:Refresh()
        local current = getValue()
        local display = L["None"] or "None"
        for _, option in ipairs(getOptions() or {}) do
            if OptionValue(option) == current then
                display = OptionText(option)
                break
            end
        end
        self.text:SetText(display)
    end

    function dropdown:RefreshMenu()
        local options = self.menu.options or getOptions() or {}
        local current = getValue()
        local visibleRows = maxRows and math.min(#options, maxRows) or #options
        self.menu.scrollOffset = math.max(0, math.min(self.menu.scrollOffset or 0, #options - visibleRows))
        for index = 1, visibleRows do
            local option = options[index + self.menu.scrollOffset]
            local selectedOption = option
            local value = OptionValue(option)
            local disabled = isDisabled and isDisabled(option) or false
            local button = self.menu.buttons[index]
            -- Reuse the menu rows when the options or current choice change.
            if not button then
                button = CreateFrame("Button", nil, self.menu, BACKDROP_TEMPLATE)
                button:SetHeight(25)
                button:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
                button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                button.text:SetPoint("LEFT", button, "LEFT", previewSound and 34 or 10, 0)
                button.text:SetPoint("RIGHT", button, "RIGHT", -10, 0)
                button.text:SetJustifyH("LEFT")
                button.text:SetWordWrap(false)
                if previewSound then
                    local speaker = CreateFrame("Button", nil, button)
                    speaker:SetSize(25, 23)
                    speaker:SetPoint("LEFT", button, "LEFT", 6, 0)
                    speaker:SetNormalTexture("Interface\\Common\\VoiceChat-Speaker")
                    speaker:SetHighlightTexture("Interface\\Common\\VoiceChat-Speaker", "ADD")
                    speaker:EnableMouseWheel(true)
                    speaker:SetScript("OnMouseWheel", function(_, delta)
                        self.menu.scrollMenu(self.menu, delta)
                    end)
                    button.speaker = speaker
                end
                button.check = button:CreateTexture(nil, "ARTWORK")
                button.check:SetWidth(3)
                button.check:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -3)
                button.check:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 3)
                button.check:SetColorTexture(1, 0.67, 0.16, 1)
                button:SetScript("OnEnter", function(menuButton)
                    if not menuButton.disabled then
                        menuButton:SetBackdropColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.16)
                    end
                end)
                button:SetScript("OnLeave", function(menuButton)
                    menuButton:SetBackdropColor(0, 0, 0, menuButton.selected and 0.30 or 0)
                end)
                if maxRows then
                    button:EnableMouseWheel(true)
                    button:SetScript("OnMouseWheel", function(_, delta)
                        self.menu.scrollMenu(self.menu, delta)
                    end)
                end
                self.menu.buttons[index] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 5, -5 - ((index - 1) * 25))
            button:SetPoint("TOPRIGHT", self.menu, "TOPRIGHT",
                self.menu.scrollTrack and #options > visibleRows and -16 or -5, -5 - ((index - 1) * 25))
            button.selected = value == current
            button.disabled = disabled
            button.text:SetText(disabled and DisabledOptionText(selectedOption) or OptionText(selectedOption))
            if disabled then
                button.text:SetTextColor(0.40, 0.36, 0.30)
            elseif button.selected then
                button.text:SetTextColor(1, 0.76, 0.30)
            else
                button.text:SetTextColor(0.92, 0.92, 0.92)
            end
            button.check:SetShown(button.selected)
            button:SetBackdropColor(0, 0, 0, button.selected and 0.30 or 0)
            button:SetScript("OnClick", function()
                if disabled then return end
                setValue(value)
                self:Refresh()
                self.menu:Hide()
                if openDropdown == self then openDropdown = nil end
                if iST.SettingsFrame and iST.SettingsFrame.RefreshAvailability then
                    iST.SettingsFrame.RefreshAvailability()
                end
            end)
            if button.speaker then
                button.speaker:SetScript("OnClick", function() previewSound(value) end)
            end
            button:Show()
        end
        for index = visibleRows + 1, #self.menu.buttons do self.menu.buttons[index]:Hide() end
        self.menu:SetHeight(math.max(12, (visibleRows * 25) + 10))
        if self.menu.scrollTrack then
            local track = self.menu.scrollTrack
            local maximum = #options - visibleRows
            track:SetShown(maximum > 0)
            if maximum > 0 then
                track:SetHeight(visibleRows * 25)
                local thumbHeight = math.max(24, math.floor(track:GetHeight() * visibleRows / #options))
                track.thumb:SetHeight(thumbHeight)
                track.thumb:ClearAllPoints()
                track.thumb:SetPoint("TOP", track, "TOP", 0,
                    -math.floor((track:GetHeight() - thumbHeight) * self.menu.scrollOffset / maximum))
            end
        end
    end

    dropdown:SetScript("OnClick", function(self)
        if not self:IsEnabled() then return end
        if self.menu:IsShown() then
            self.menu:Hide()
            openDropdown = nil
            return
        end
        if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        openDropdown = self
        self.menu.options = getOptions() or {}
        self:RefreshMenu()
        self:Refresh()
        self.menu:ClearAllPoints()
        -- Open upward if there is not enough room below the dropdown.
        local bottom = self:GetBottom() or 0
        if bottom > (self.menu:GetHeight() or 0) + 12 then
            self.menu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        else
            self.menu:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 2)
        end
        self.menu:Show()
    end)
    dropdown:HookScript("OnHide", function(self)
        self.menu:Hide()
        if openDropdown == self then openDropdown = nil end
    end)
    dropdown:Refresh()
    return dropdown
end

local function CreateSettingsDropdown(parent, label, yOffset, width, getOptions, getValue, setValue, maxRows, previewSound, descText)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    labelText:SetText(label)
    labelText:SetTextColor(0.96, 0.90, 0.78)

    local dropdown = CreateStyledDropdown(parent, width, getOptions, getValue, setValue, nil, nil, maxRows, previewSound)
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset - 18)
    local description, nextY = CreateSettingDescription(parent, descText or SETTING_DESCRIPTIONS[label],
        20, yOffset - 58, parent:GetWidth() - 40)
    function dropdown:SetControlEnabled(enabled)
        enabled = enabled == true
        if self:IsEnabled() == enabled then return end
        if enabled then self:Enable() else self:Disable() end
        if not enabled then self.menu:Hide() end
        labelText:SetAlpha(enabled and 1 or 0.4)
        if description then description:SetAlpha(enabled and 1 or 0.4) end
    end
    return dropdown, nextY, function() dropdown:Refresh() end
end

local function CreateInfoText(parent, text, yOffset, fontObj)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObj or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 25, yOffset)
    fs:SetWidth(parent:GetWidth() - 50)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    local height = fs:GetStringHeight()
    if height < 14 then height = 14 end
    return fs, yOffset - height - 4
end

local function CreateColorEditor(parent, label, yOffset, getFunc, onChange, captureOriginal)
    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    button:SetSize(parent:GetWidth() - 40, 28)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    button:SetBackdrop(PANEL_BACKDROP)
    button:SetBackdropColor(0.035, 0.030, 0.022, 0.92)
    button:SetBackdropBorderColor(0.32, 0.25, 0.14, 1)
    local description, nextY = CreateSettingDescription(parent,
        SETTING_DESCRIPTIONS[label] or string.format(L["CustomColorDesc"], label),
        20, yOffset - 36, parent:GetWidth() - 40)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.59, 0.09, 0.12)

    local labelText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelText:SetPoint("LEFT", button, "LEFT", 4, 0)
    labelText:SetText(label)
    labelText:SetTextColor(0.96, 0.90, 0.78)

    local swatchBorder = button:CreateTexture(nil, "BACKGROUND")
    swatchBorder:SetSize(32, 22)
    swatchBorder:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    swatchBorder:SetColorTexture(0, 0, 0, 1)

    local swatchBackground = button:CreateTexture(nil, "BORDER")
    swatchBackground:SetSize(28, 18)
    swatchBackground:SetPoint("CENTER", swatchBorder, "CENTER")
    swatchBackground:SetColorTexture(0.5, 0.5, 0.5, 1)

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetAllPoints(swatchBackground)

    local function RefreshSwatch()
        local color = getFunc()
        swatch:SetColorTexture(color.r, color.g, color.b, color.a or 1)
    end

    local function ApplyColor(r, g, b, a)
        local color = getFunc()
        color.r = r
        color.g = g
        color.b = b
        color.a = a or color.a or 1
        RefreshSwatch()
        if onChange then onChange(color) end
        if iST.InvalidateBarState then iST:InvalidateBarState() end
    end

    button:SetScript("OnClick", function()
        if not ColorPickerFrame then return end

        -- Some editors need to restore more than one color when Cancel is used.
        local restoreOriginal = captureOriginal and captureOriginal()
        local color = getFunc()
        local original = {
            r = color.r,
            g = color.g,
            b = color.b,
            a = color.a or 1,
        }
        local usesModernPicker = ColorPickerFrame.SetupColorPickerAndShow ~= nil

        local function PickerChanged()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = original.a
            if usesModernPicker and ColorPickerFrame.GetColorAlpha then
                a = ColorPickerFrame:GetColorAlpha()
            elseif OpacitySliderFrame then
                a = 1 - OpacitySliderFrame:GetValue()
            end
            ApplyColor(r, g, b, a)
        end

        local function PickerCancelled()
            if restoreOriginal then
                restoreOriginal()
                RefreshSwatch()
                if onChange then onChange() end
                if iST.InvalidateBarState then iST:InvalidateBarState() end
            else
                ApplyColor(original.r, original.g, original.b, original.a)
            end
        end

        if usesModernPicker then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = original.r,
                g = original.g,
                b = original.b,
                opacity = original.a,
                hasOpacity = true,
                swatchFunc = PickerChanged,
                opacityFunc = PickerChanged,
                cancelFunc = PickerCancelled,
            })
        else
            ColorPickerFrame:Hide()
            ColorPickerFrame.func = PickerChanged
            ColorPickerFrame.opacityFunc = PickerChanged
            ColorPickerFrame.cancelFunc = PickerCancelled
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = 1 - original.a
            ColorPickerFrame.previousValues = { original.r, original.g, original.b, original.a }
            ColorPickerFrame:SetColorRGB(original.r, original.g, original.b)
            ColorPickerFrame:Show()
        end
    end)

    function button:SetControlEnabled(enabled)
        enabled = enabled == true
        if self:IsEnabled() == enabled then return end
        if enabled then self:Enable() else self:Disable() end
        self:SetAlpha(enabled and 1 or 0.4)
        if description then description:SetAlpha(enabled and 1 or 0.4) end
    end

    RefreshSwatch()
    return nextY, RefreshSwatch, button
end

-- Build the window once; opening it later reuses the same controls.
function iST:CreateOptionsPanel()
    if self.SettingsFrame then return end

    local sidebarWidth = 160
    local contentWidth = 592

    local settingsFrame = CreateFrame("Frame", "iSTSettingsFrame", UIParent, BACKDROP_TEMPLATE)
    -- Let WoW close the settings panel through its normal Escape-key handling.
    table.insert(UISpecialFrames, settingsFrame:GetName())
    settingsFrame:SetSize(820, 580)
    settingsFrame:SetPoint("CENTER", UIParent, "CENTER")
    settingsFrame:SetMovable(true)
    settingsFrame:SetClampedToScreen(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:SetFrameStrata("HIGH")

    StyleSettingsSurface(settingsFrame)

    local dependentControls = {}
    local function DependsOn(control, condition)
        dependentControls[#dependentControls + 1] = { control = control, condition = condition }
        return control
    end
    local function RefreshAvailability()
        for _, dependency in ipairs(dependentControls) do
            local control = dependency.control
            local enabled = dependency.condition() == true
            if control.SetControlEnabled then
                control:SetControlEnabled(enabled)
            elseif control:IsEnabled() ~= enabled then
                if enabled then control:Enable() else control:Disable() end
            end
        end
    end
    settingsFrame.RefreshAvailability = RefreshAvailability
    settingsFrame:HookScript("OnShow", RefreshAvailability)
    local availabilityElapsed = 0
    settingsFrame:HookScript("OnUpdate", function(_, elapsed)
        availabilityElapsed = availabilityElapsed + elapsed
        if availabilityElapsed < 0.15 then return end
        availabilityElapsed = 0
        RefreshAvailability()
    end)
    local function WrathAvailable()
        return iST:IsWrathTrackingEnabled() == true
    end

    local shadow = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    shadow:SetPoint("TOPLEFT", settingsFrame, -1, 1)
    shadow:SetPoint("BOTTOMRIGHT", settingsFrame, 1, -1)
    if shadow.SetBackdrop then
        shadow:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 5 })
        shadow:SetBackdropBorderColor(0, 0, 0, 0.8)
    end

    settingsFrame:RegisterForDrag("LeftButton", "RightButton")
    settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local titleBar = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    titleBar:SetHeight(40)
    titleBar:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -1, -1)
    StyleSettingsSurface(titleBar, true)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 15, 0)
    titleText:SetText(Colors.iST .. "iSealTwist|r  |cFFAAA08C" .. L["SettingsLabel"] .. "|r")

    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetHeight(1)
    titleAccent:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 8, 2)
    titleAccent:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", -8, 2)
    titleAccent:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.25)

    local closeButton = CreateFrame("Button", nil, settingsFrame, BACKDROP_TEMPLATE)
    closeButton:SetSize(26, 26)
    closeButton:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -8, -8)
    StyleSettingsButton(closeButton)
    closeButton:SetText("X")
    closeButton:SetScript("OnClick", function() iST:SettingsClose() end)

    -- Page navigation sits beside a shared content area.
    local sidebar = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    sidebar:SetWidth(sidebarWidth)
    sidebar:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, -50)
    sidebar:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 10, 30)
    StyleSettingsSurface(sidebar)
    settingsFrame.sidebar = sidebar

    local footer = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 14, 11)
    footer:SetText(L["SettingsSavedAutomatically"])
    local versionText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionText:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -14, 11)
    versionText:SetText("v" .. iST.Version)

    local contentArea = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    contentArea:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -10, 30)
    StyleSettingsSurface(contentArea)

    local pageHeader = CreateFrame("Frame", nil, contentArea)
    pageHeader:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 1, -1)
    pageHeader:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -1, -1)
    pageHeader:SetHeight(58)
    pageHeader.title = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pageHeader.title:SetPoint("TOPLEFT", pageHeader, "TOPLEFT", 20, -12)
    pageHeader.subtitle = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pageHeader.subtitle:SetPoint("TOPLEFT", pageHeader, "TOPLEFT", 20, -34)
    pageHeader.subtitle:SetPoint("TOPRIGHT", pageHeader, "TOPRIGHT", -20, -34)
    pageHeader.subtitle:SetJustifyH("LEFT")
    settingsFrame.pageHeader = pageHeader
    local pageInfo = {
        { L["TabGeneral"], L["SettingsGeneralSummary"] },
        { L["TabIndicators"], L["SettingsIndicatorsSummary"] },
        { L["TabCustomization"], L["SettingsCustomizationSummary"] },
        { L["TabAbout"], L["SettingsAboutSummary"] },
        { L["TabIWRPromo"], L["SettingsCompanionSummary"] },
        { L["TabINIFPromo"], L["SettingsCompanionSummary"] },
        { L["TabIRCPromo"], L["SettingsCompanionSummary"] },
        { L["TabReminders"], L["SettingsRemindersSummary"] },
        { L["TabSounds"], L["SettingsSoundsSummary"] },
        { L["TabProfiles"], L["SettingsProfilesSummary"] },
    }

    -- Each page keeps its own scroll position when switching tabs.
    local scrollChildren = {}

    local function CreateTabContent()
        local container = CreateFrame("Frame", nil, contentArea)
        container:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 5, -62)
        container:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -5, 5)
        container:Hide()

        local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 0)

        StyleSettingsScroll(scrollFrame)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(contentWidth)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        table.insert(scrollChildren, scrollChild)
        scrollFrame:HookScript("OnVerticalScroll", function()
            if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        end)

        container:EnableMouseWheel(true)
        container:SetScript("OnMouseWheel", function(_, delta)
            if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
            local current = scrollFrame:GetVerticalScroll()
            local maxScroll = scrollChild:GetHeight() - scrollFrame:GetHeight()
            if maxScroll < 0 then maxScroll = 0 end
            local newScroll = math.max(0, math.min(maxScroll, current - delta * 30))
            scrollFrame:SetVerticalScroll(newScroll)
        end)

        return container, scrollChild
    end

    local generalContainer, generalContent = CreateTabContent()
    local indicatorsContainer, indicatorsContent = CreateTabContent()
    local customizationContainer, customizationContent = CreateTabContent()
    local aboutContainer, aboutContent = CreateTabContent()
    local iWRContainer, iWRContent = CreateTabContent()
    local iNIFContainer, iNIFContent = CreateTabContent()
    local iRCContainer, iRCContent = CreateTabContent()
    local remindersContainer, remindersContent = CreateTabContent()
    local soundsContainer, soundsContent = CreateTabContent()
    local profilesContainer, profilesContent = CreateTabContent()

    local tabContents = {
        generalContainer,
        indicatorsContainer,
        customizationContainer,
        aboutContainer,
        iWRContainer,
        iNIFContainer,
        iRCContainer,
        remindersContainer,
        soundsContainer,
        profilesContainer,
    }

    local function LayoutPreviewSpace(height)
        for _, container in ipairs(tabContents) do
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 5, -62 - height)
            container:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -5, 5)
        end
    end

    local sidebarButtons = {}
    local activeIndex = 1

    local function ShowTab(index)
        activeIndex = index
        RefreshAvailability()
        if settingsFrame.CustomCuePopup then settingsFrame.CustomCuePopup:Hide() end
        if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        openDropdown = nil
        pageHeader.title:SetText(pageInfo[index][1])
        pageHeader.subtitle:SetText(pageInfo[index][2])
        for i, content in ipairs(tabContents) do
            content:SetShown(i == index)
        end
        if settingsFrame.UpdatePreviewLayout then settingsFrame.UpdatePreviewLayout() end
        if index ~= 3 then settingsFrame.previewSealOverride = nil end
        if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
        for i, btn in pairs(sidebarButtons) do
            if i == index then
                btn.bg:Show()
                btn.accent:Show()
                btn.text:SetFontObject(GameFontHighlight)
                btn.text:SetTextColor(1, 0.78, 0.24)
            else
                btn.bg:Hide()
                btn.accent:Hide()
                btn.text:SetFontObject(GameFontNormal)
                btn.text:SetTextColor(0.82, 0.76, 0.66)
            end
        end
    end

    local sidebarItems = {
        { type = "header", label = Colors.iST .. "iSealTwist" },
        { type = "tab", label = L["TabGeneral"], index = 1 },
        { type = "tab", label = L["TabIndicators"], index = 2 },
        { type = "tab", label = L["TabReminders"], index = 8 },
        { type = "tab", label = L["TabSounds"], index = 9 },
        { type = "tab", label = L["TabCustomization"], index = 3 },
        { type = "tab", label = L["TabProfiles"], index = 10 },
        { type = "tab", label = L["TabAbout"], index = 4 },
        { type = "header", label = Colors.iST .. L["SidebarOtherAddons"] },
        { type = "tab", label = L["TabIWRPromo"], index = 5 },
        { type = "tab", label = L["TabINIFPromo"], index = 6 },
        { type = "tab", label = L["TabIRCPromo"], index = 7 },
    }

    local sidebarY = -10
    for _, item in ipairs(sidebarItems) do
        if item.type == "header" then
            local headerText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            headerText:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 12, sidebarY - 2)
            headerText:SetText(item.label)
            sidebarY = sidebarY - 20
        elseif item.type == "tab" then
            local tabIndex = item.index
            local btn = CreateFrame("Button", nil, sidebar)
            btn:SetSize(sidebarWidth - 12, 30)
            btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, sidebarY)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(btn)
            bg:SetColorTexture(0.85, 0.52, 0.12, 0.14)
            btn.bg = bg

            local accent = btn:CreateTexture(nil, "ARTWORK")
            accent:SetWidth(2)
            accent:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -3)
            accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 3)
            accent:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.95)
            accent:Hide()
            btn.accent = accent

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", btn, "LEFT", 14, 0)
            text:SetText(item.label)
            btn.text = text

            local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(btn)
            highlight:SetColorTexture(1, 1, 1, 0.08)

            btn:SetScript("OnClick", function() ShowTab(tabIndex) end)

            sidebarButtons[tabIndex] = btn
            sidebarY = sidebarY - 32
        end
    end

    -- General: visibility and the two seals used by the optional macro.
    do
        local y = -10
        _, y = CreateSectionHeader(generalContent, L["SectionActivation"], y)

        _, y = CreateSettingsCheckbox(generalContent, L["OnlyAsPaladin"], L["OnlyAsPaladinDesc"], y,
            function() return iSTSettings.onlyAsPaladin end,
            function(v) iSTSettings.onlyAsPaladin = v iST:UpdateBarVisibility() end
        )

        _, y = CreateSettingsDropdown(generalContent, L["BarVisibility"], y, 250,
            function() return {
                { value = "ALWAYS", text = L["VisibilityAlways"] },
                { value = "COMBAT", text = L["VisibilityCombat"] },
                { value = "COMBAT_OR_AURA", text = L["VisibilityCombatAura"] },
            } end,
            function() return iSTSettings.barVisibility end,
            function(value) iSTSettings.barVisibility = value; iST:UpdateBarVisibility() end)

        _, y = CreateSectionHeader(generalContent, L["SectionSealPair"], y)

        -- The spell table contains every rank; list each seal only once.
        local sealChoices, fromDropdown, intoDropdown, legend = {}
        local seenNames = {}
        for _, name in pairs(iST.SEALS) do
            if not seenNames[name] then
                seenNames[name] = true
                table.insert(sealChoices, name)
            end
        end
        table.sort(sealChoices)

        local function SealIcon(name)
            local spellID = iST.SEAL_SPELL_IDS and iST.SEAL_SPELL_IDS[name]
            return spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or nil
        end

        local pairCard = CreateFrame("Frame", nil, generalContent, BACKDROP_TEMPLATE)
        pairCard:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        pairCard:SetPoint("TOPRIGHT", generalContent, "TOPRIGHT", -20, y)
        pairCard:SetHeight(272)
        StyleSettingsSurface(pairCard)

        local fromLabel = pairCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fromLabel:SetPoint("TOP", pairCard, "TOPLEFT", 111, -12)
        fromLabel:SetText(L["TwistFromSeal"])

        local intoLabel = pairCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        intoLabel:SetPoint("TOP", pairCard, "TOPRIGHT", -111, -12)
        intoLabel:SetText(L["TwistIntoSeal"])

        local direction = pairCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        direction:SetPoint("CENTER", pairCard, "TOP", 0, -47)

        local function UpdateSealDirection()
            direction:SetText(Colors.Green .. "< -- >" .. Colors.Reset)
            if legend then legend:SetText(L["SealPairLegend"]) end
        end

        local function SealDropdownText(option)
            local name = type(option) == "table" and option.value or option
            local texture = SealIcon(name)
            local icon = texture and ("|T" .. tostring(texture) .. ":16:16:0:0|t ") or ""
            return icon .. name
        end

        local function SealOptions(values)
            local options = {}
            for _, value in ipairs(values) do
                options[#options + 1] = { value = value, text = SealDropdownText(value) }
            end
            return options
        end

        -- Disable the other dropdown's seal so both choices stay different.
        fromDropdown = CreateStyledDropdown(pairCard, 190,
            function() return SealOptions(sealChoices) end,
            function() return iSTSettings.twistFromSeal end,
            function(value)
                if not iST:SetTwistSeal("From", value) then return end
                if intoDropdown then intoDropdown:Refresh() end
                UpdateSealDirection()
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end,
            function(option) return option.text end,
            function(option) return option.value == iSTSettings.twistIntoSeal end)
        fromDropdown:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -32)

        intoDropdown = CreateStyledDropdown(pairCard, 190,
            function() return SealOptions(sealChoices) end,
            function() return iSTSettings.twistIntoSeal end,
            function(value)
                if not iST:SetTwistSeal("Into", value) then return end
                fromDropdown:Refresh()
                UpdateSealDirection()
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end,
            function(option) return option.text end,
            function(option) return option.value == iSTSettings.twistFromSeal end)
        intoDropdown:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -32)
        DependsOn(fromDropdown, function() return not CombatLocked() end)
        DependsOn(intoDropdown, function() return not CombatLocked() end)
        local firstHelp = pairCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        firstHelp:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -65)
        firstHelp:SetWidth(190)
        firstHelp:SetJustifyH("LEFT")
        firstHelp:SetWordWrap(true)
        firstHelp:SetText(L["TwistFromSealDesc"])
        local secondHelp = pairCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        secondHelp:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -65)
        secondHelp:SetWidth(190)
        secondHelp:SetJustifyH("LEFT")
        secondHelp:SetWordWrap(true)
        secondHelp:SetText(L["TwistIntoSealDesc"])
        legend = pairCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        local fromTargetLabel = pairCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fromTargetLabel:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -106)
        fromTargetLabel:SetText(L["SwitchAtStacks"])
        local intoTargetLabel = pairCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        intoTargetLabel:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -106)
        intoTargetLabel:SetText(L["SwitchAtStacks"])
        local stackOptions = {
            { value = 0, text = L["AnyEchoStack"] },
            { value = 1, text = L["OneStack"] },
            { value = 2, text = L["TwoStacks"] },
            { value = 3, text = L["ThreeStacks"] },
        }
        local fromTarget = CreateStyledDropdown(pairCard, 190,
            function() return stackOptions end,
            function() return iSTSettings.twistFromStacks end,
            function(value)
                iST:SetTwistStackTarget("From", value)
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end)
        fromTarget:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -124)
        local intoTarget = CreateStyledDropdown(pairCard, 190,
            function() return stackOptions end,
            function() return iSTSettings.twistIntoStacks end,
            function(value)
                iST:SetTwistStackTarget("Into", value)
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end)
        intoTarget:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -124)
        local targetHelp = pairCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        targetHelp:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -158)
        targetHelp:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -158)
        targetHelp:SetJustifyH("LEFT")
        targetHelp:SetText(L["SwitchAtStacksDesc"])
        local function TargetAvailability(dropdown, label)
            local baseSetControlEnabled = dropdown.SetControlEnabled
            function dropdown:SetControlEnabled(enabled)
                baseSetControlEnabled(self, enabled)
                label:SetAlpha(enabled and 1 or 0.4)
                targetHelp:SetAlpha(enabled and 1 or 0.4)
            end
            DependsOn(dropdown, function() return WrathAvailable() and not CombatLocked() end)
        end
        TargetAvailability(fromTarget, fromTargetLabel)
        TargetAvailability(intoTarget, intoTargetLabel)
        legend:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -185)
        legend:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -185)
        legend:SetJustifyH("LEFT")
        legend:SetHeight(34)
        UpdateSealDirection()

        local macrosButton = CreateSettingsButtonAt(pairCard, L["OpenMacros"], 130, 170, -235, OpenMacroWindow)
        macrosButton:ClearAllPoints()
        macrosButton:SetPoint("TOP", pairCard, "TOP", 0, -235)
        DependsOn(macrosButton, function() return not CombatLocked() end)

        y = y - pairCard:GetHeight() - 8

        local intoDesc = generalContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        intoDesc:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        intoDesc:SetWidth(450)
        intoDesc:SetJustifyH("LEFT")
        intoDesc:SetText(L["SealPairDesc"])
        y = y - intoDesc:GetStringHeight() - 10

        scrollChildren[1]:SetHeight(math.abs(y) + 10)
        settingsFrame:HookScript("OnShow", function()
            fromDropdown:Refresh()
            intoDropdown:Refresh()
            fromTarget:Refresh()
            intoTarget:Refresh()
        end)
    end

    -- Indicators: seal information and Unsealed Wrath cues.
    do
        local y = -10
        _, y = CreateSectionHeader(indicatorsContent, L["SectionBarInformation"], y)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowLatency"], L["ShowLatencyDesc"], y,
            function() return iSTSettings.showLatency end,
            function(v)
                iSTSettings.showLatency = v
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowSealIcon"], L["ShowSealIconDesc"], y,
            function() return iSTSettings.showSealIcon end,
            function(v)
                iSTSettings.showSealIcon = v
                iST:UpdateSealDisplay()
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end
        )

        local sealTimerCheckbox
        sealTimerCheckbox, y = CreateSettingsCheckbox(indicatorsContent, L["ShowSealTimer"], L["ShowSealTimerDesc"], y,
            function() return iSTSettings.showSealTimer end,
            function(v)
                iSTSettings.showSealTimer = v
                iST:UpdateSealTimer()
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end
        )
        DependsOn(sealTimerCheckbox, function() return iSTSettings.showSealIcon end)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowSealName"], L["ShowSealNameDesc"], y,
            function() return iSTSettings.showSealName end,
            function(v)
                iSTSettings.showSealName = v
                iST:UpdateSealDisplay()
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end)

        local echoTimerCheckbox
        echoTimerCheckbox, y = CreateSettingsCheckbox(indicatorsContent, L["ShowEchoTimer"], L["ShowEchoTimerDesc"], y,
            function() return iSTSettings.showEchoTimer end,
            function(v)
                iSTSettings.showEchoTimer = v
                iST:UpdateEchoTimerDisplay()
                iST:UpdateMoveSurfaceMouse()
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end)
        DependsOn(echoTimerCheckbox, WrathAvailable)

        local nameplateCheckbox
        nameplateCheckbox, y = CreateSettingsCheckbox(indicatorsContent, L["ShowNameplateEcho"], L["ShowNameplateEchoDesc"], y,
            function() return iSTSettings.showNameplateEcho end,
            function(v) iSTSettings.showNameplateEcho = v; iST:UpdateNameplateEchoDisplay() end)
        DependsOn(nameplateCheckbox, WrathAvailable)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowWeaponSpeed"], L["ShowWeaponSpeedDesc"], y,
            function() return iSTSettings.showWeaponSpeed end,
            function(v)
                iSTSettings.showWeaponSpeed = v
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowSwingRemaining"], L["ShowSwingRemainingDesc"], y,
            function() return iSTSettings.showSwingRemaining end,
            function(v)
                iSTSettings.showSwingRemaining = v
                iST:InvalidateBarState()
                if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
            end)

        _, y = CreateSectionHeader(indicatorsContent, L["SectionUnsealedWrath"], y)
        local echoPreview = CreateFrame("Frame", nil, contentArea, BACKDROP_TEMPLATE)
        echoPreview:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 20, -62)
        echoPreview:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -20, -62)
        echoPreview:SetHeight(206)
        StyleSettingsSurface(echoPreview)
        local previewTitle = echoPreview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        previewTitle:SetPoint("TOPLEFT", echoPreview, "TOPLEFT", 14, -10)
        previewTitle:SetText(L["EchoSetupPreview"])
        local previewBody = CreateFrame("Frame", nil, echoPreview)
        previewBody:SetAllPoints(echoPreview)
        local previewNote = previewBody:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        previewNote:SetPoint("BOTTOMLEFT", echoPreview, "BOTTOMLEFT", 14, 11)
        previewNote:SetPoint("BOTTOMRIGHT", echoPreview, "BOTTOMRIGHT", -14, 11)
        previewNote:SetJustifyH("LEFT")
        previewNote:SetText(L["EchoSetupPreviewDesc"])
        local previewBar = CreateFrame("Frame", nil, previewBody, BACKDROP_TEMPLATE)
        previewBar:SetPoint("CENTER", echoPreview, "CENTER", 0, -31)
        previewBar:SetBackdrop({ edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
        previewBar.fill = previewBar:CreateTexture(nil, "ARTWORK")
        previewBar.gloss = previewBar:CreateTexture(nil, "ARTWORK", nil, 6)
        previewBar.gloss:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        local speed = previewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        speed:SetPoint("LEFT", previewBar, "LEFT", 7, 0)
        speed:SetText("3.30")
        speed:SetTextColor(0.8, 0.8, 0.8, 0.7)
        local remaining = previewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        remaining:SetPoint("RIGHT", previewBar, "RIGHT", -7, 0)
        remaining:SetText("1.2s")
        remaining:SetTextColor(1, 1, 1, 1)
        local latency = previewBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        latency:SetPoint("TOPRIGHT", previewBar, "BOTTOMRIGHT", 0, -3)
        latency:SetText("22ms")
        latency:SetTextColor(0.5, 0.5, 0.5, 0.8)
        local sealName = previewBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sealName:SetPoint("TOP", previewBar, "BOTTOM", 0, -4)
        sealName:SetTextColor(1, 0.59, 0.09, 0.9)
        local sealRing = previewBody:CreateTexture(nil, "BORDER")
        sealRing:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        sealRing:SetPoint("RIGHT", previewBar, "LEFT", -7, 0)
        sealRing:SetVertexColor(1, 0.59, 0.09, 0.95)
        local sealIcon = previewBody:CreateTexture(nil, "ARTWORK")
        sealIcon:SetPoint("CENTER", sealRing, "CENTER")
        sealIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local sealTime = previewBody:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        sealTime:SetPoint("CENTER", sealRing, "CENTER")
        sealTime:SetText("26")
        sealTime:SetTextColor(1, 1, 1, 1)
        local sealLabel = previewBody:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sealLabel:SetPoint("BOTTOM", sealRing, "TOP", 0, 1)
        sealLabel:SetText(L["SealTimerLabel"])
        sealLabel:SetTextColor(0.35, 0.82, 1, 1)
        if sealIcon.AddMaskTexture and previewBody.CreateMaskTexture then
            local mask = previewBody:CreateMaskTexture()
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            mask:SetAllPoints(sealIcon)
            sealIcon:AddMaskTexture(mask)
        end
        local counter = previewBody:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        counter:SetPoint("BOTTOM", previewBar, "TOP", 0, 7)
        counter:SetJustifyH("CENTER")
        local previewCircles = iST:CreateStackBubbles(previewBody, nil, 18, 9)
        previewCircles:SetPoint("BOTTOM", previewBar, "TOP", 0, 6)
        local previewIcons = iST:CreateStackSealIcons(previewBody, 18, 5)
        previewIcons:SetPoint("BOTTOM", previewBar, "TOP", 0, 6)
        iST:CreateSwordImageCue(previewBar)
        local echoRing = previewBody:CreateTexture(nil, "BORDER")
        echoRing:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        echoRing:SetPoint("LEFT", previewBar, "RIGHT", 7, 0)
        echoRing:SetVertexColor(0.20, 0.72, 1, 0.95)
        local echoIcon = previewBody:CreateTexture(nil, "ARTWORK")
        echoIcon:SetPoint("CENTER", echoRing, "CENTER")
        echoIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if echoIcon.AddMaskTexture and previewBody.CreateMaskTexture then
            local mask = previewBody:CreateMaskTexture()
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            mask:SetAllPoints(echoIcon)
            echoIcon:AddMaskTexture(mask)
        end
        local echoTime = previewBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        echoTime:SetPoint("CENTER", echoRing, "CENTER")
        echoTime:SetText("12")
        local echoLabel = previewBody:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        echoLabel:SetPoint("BOTTOM", echoRing, "TOP", 0, 1)
        echoLabel:SetText(L["EchoLabel"])
        echoLabel:SetTextColor(0.35, 0.82, 1, 1)
        local function RefreshEchoPreview()
            local width = math.max(100, math.min(360, iSTSettings.barWidth or 250))
            local height = iSTSettings.barHeight or 25
            local iconSize = math.max(16, math.min(64, iSTSettings.sealIconSize or 25))
            local source = settingsFrame.previewSealOverride or iSTSettings.twistFromSeal
            local texture = iST.BarFrame and iST.BarFrame.stackSealIcons[source]
            local stageColor = iST:GetWrathCueColor(2)
            local fillColor = iSTSettings.barColorBySeal and iSTSettings.sealBarColors[source]
                or (iSTSettings.showStackBarColor and stageColor or iSTSettings.barColor)
            previewBar:SetSize(width, height)
            iST:ApplyBarStyle(previewBar)
            previewBar.fill:SetWidth(math.max(1, (width - (previewBar.contentInset or 0) * 2) * 0.65))
            previewBar.fill:SetVertexColor(fillColor.r, fillColor.g, fillColor.b, fillColor.a or 1)
            local border = iSTSettings.borderNormalColor
            previewBar:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)
            local fontPath = iST:GetBarFontPath()
            local swingSize = math.max(8, math.min(iSTSettings.swingTextSize or 11,
                math.floor(height - 4), math.floor((iSTSettings.barWidth - 16) / 5)))
            speed:SetFont(fontPath, swingSize, "OUTLINE")
            remaining:SetFont(fontPath, swingSize, "OUTLINE")
            latency:SetFont(fontPath, iSTSettings.latencyTextSize or 9, "OUTLINE")
            speed:SetShown(iSTSettings.showWeaponSpeed)
            remaining:SetShown(iSTSettings.showSwingRemaining)
            latency:SetShown(iSTSettings.showLatency)
            sealName:SetText(source or "")
            sealName:SetFont(fontPath, iSTSettings.sealTextSize or 10, "OUTLINE")
            sealName:SetShown(iSTSettings.showSealName)
            sealRing:SetSize(iconSize + 8, iconSize + 8)
            sealIcon:SetSize(iconSize, iconSize)
            sealIcon:SetTexture(texture)
            local timerSize = math.max(8, math.floor(iconSize * 0.46 + 0.5))
            local opticalOffset = timerSize * 0.1
            sealTime:ClearAllPoints()
            sealTime:SetSize(iconSize, iconSize)
            sealTime:SetPoint("CENTER", sealIcon, "CENTER", opticalOffset - 1, -opticalOffset)
            sealTime:SetFont(fontPath, timerSize, "THICKOUTLINE")
            sealRing:SetVertexColor(1, 0.59, 0.09, 0.95)
            sealTime:SetTextColor(1, 1, 1, 1)
            sealLabel:SetFont(fontPath, math.max(8, math.floor(iconSize * 0.23 + 0.5)), "OUTLINE")
            sealLabel:Hide()
            sealRing:SetShown(iSTSettings.showSealIcon)
            sealIcon:SetShown(iSTSettings.showSealIcon)
            sealTime:SetShown(iSTSettings.showSealIcon and iSTSettings.showSealTimer)
            echoRing:SetSize(iconSize + 8, iconSize + 8)
            echoIcon:SetSize(iconSize, iconSize)
            echoIcon:SetTexture(texture)
            echoTime:ClearAllPoints()
            echoTime:SetSize(iconSize, iconSize)
            echoTime:SetPoint("CENTER", echoIcon, "CENTER", opticalOffset - 1, -opticalOffset)
            echoTime:SetFont(fontPath, timerSize, "THICKOUTLINE")
            local echoTextColor = iSTSettings.echoTimerTextColor
            echoTime:SetTextColor(echoTextColor.r, echoTextColor.g, echoTextColor.b,
                echoTextColor.a or 1)
            echoLabel:SetFont(fontPath, math.max(8, math.floor(iconSize * 0.23 + 0.5)), "OUTLINE")
            echoRing:SetShown(iSTSettings.showEchoTimer)
            echoIcon:SetShown(iSTSettings.showEchoTimer)
            echoTime:SetShown(iSTSettings.showEchoTimer)
            echoLabel:SetShown(iSTSettings.showEchoTimer)
            local showCounter = iSTSettings.showStackCounter
            counter:SetShown(showCounter)
            counter:SetFont(fontPath, iSTSettings.stackCounterTextSize or 16, "THICKOUTLINE")
            counter:SetText("2 / " .. iST:GetTwistStackTargetLabel(source))
            counter:SetTextColor(stageColor.r, stageColor.g, stageColor.b, stageColor.a or 1)
            local pipSize = math.max(10, math.min(50, iSTSettings.wrathCircleSize or 18))
            iST:ResizeStackBubbles(previewCircles, pipSize)
            iST:ResizeStackSealIcons(previewIcons, pipSize)
            local target = iST:GetTwistStackTarget(source)
            iST:RenderStackBubbles(previewCircles, 2, stageColor, target)
            iST:RenderStackSealIcons(previewIcons, 2, texture, target)
            local circleShift = (3 - previewCircles.visiblePips) * (pipSize + previewCircles.pipGap) / 2
            previewCircles:ClearAllPoints()
            previewCircles:SetPoint("BOTTOM", previewBar, "TOP", circleShift, 6)
            local iconShift = (3 - previewIcons.visiblePips) * (pipSize + previewIcons.pipGap) / 2
            previewIcons:ClearAllPoints()
            previewIcons:SetPoint("BOTTOM", previewBar, "TOP", iconShift, 6)
            previewCircles:SetShown(iSTSettings.showStackCircles
                and iSTSettings.stackBubbleStyle == "CIRCLES")
            previewIcons:SetShown(iSTSettings.showStackCircles
                and iSTSettings.stackBubbleStyle == "SEAL_ICONS" and texture ~= nil)
            iST:UpdateSwordImageCue(previewBar, 2, iSTSettings.showStackSwordImages, stageColor)
            sealRing:ClearAllPoints()
            sealRing:SetPoint("RIGHT", previewBar, "LEFT",
                iSTSettings.showStackSwordImages and -(previewBar.wrathSwordImages.leftOverhang + 7) or -7, 0)
            if showCounter and iSTSettings.showStackCircles then
                counter:ClearAllPoints()
                counter:SetPoint("BOTTOM", previewBar, "TOP", 0,
                    math.max(35, pipSize + 15))
            else
                counter:ClearAllPoints()
                counter:SetPoint("BOTTOM", previewBar, "TOP", 0, 7)
            end
        end
        settingsFrame.RefreshEchoPreview = RefreshEchoPreview
        local previewToggle = CreateFrame("Button", nil, echoPreview, BACKDROP_TEMPLATE)
        previewToggle:SetSize(110, 24)
        previewToggle:SetPoint("TOPRIGHT", echoPreview, "TOPRIGHT", -8, -5)
        StyleSettingsButton(previewToggle)
        local previewCollapsed = false
        local function UpdatePreviewLayout()
            local visible = activeIndex == 2 or activeIndex == 3
            echoPreview:SetShown(visible)
            local expandedHeight = math.max(206, 135
                + (iSTSettings.showStackCounter and (iSTSettings.stackCounterTextSize or 16) or 0)
                + (iSTSettings.showStackCircles and (iSTSettings.wrathCircleSize or 18) or 0))
            echoPreview:SetHeight(previewCollapsed and 34 or expandedHeight)
            previewBody:SetShown(not previewCollapsed)
            previewToggle:SetText(previewCollapsed and L["ShowPreview"] or L["HidePreview"])
            LayoutPreviewSpace(visible and echoPreview:GetHeight() + 10 or 0)
            if visible and not previewCollapsed then RefreshEchoPreview() end
        end
        settingsFrame.UpdatePreviewLayout = UpdatePreviewLayout
        previewToggle:SetScript("OnClick", function()
            previewCollapsed = not previewCollapsed
            UpdatePreviewLayout()
        end)
        UpdatePreviewLayout()
        echoPreview:SetScript("OnShow", RefreshEchoPreview)
        indicatorsContent:HookScript("OnShow", RefreshEchoPreview)
        RefreshEchoPreview()
        local indicatorCheckboxes = {}
        local counterSizeSlider, pipSizeSlider, playerPipSizeSlider, playerFrameCheckbox
        local function AddIndicator(key, label, description)
            local checkbox
            checkbox, y = CreateSettingsCheckbox(indicatorsContent, label, description, y,
                function() return iSTSettings[key] end,
                function(value)
                    if CombatLocked() then return end
                    iSTSettings[key] = value
                    if key == "showStackCounter" then iST:CreateStackManagedDisplay() end
                    iST:UpdateWrathDisplay()
                    iST:UpdateMoveSurfaceMouse()
                    RefreshEchoPreview()
                    if settingsFrame.UpdatePreviewLayout then settingsFrame.UpdatePreviewLayout() end
                    RefreshAvailability()
                end)
            indicatorCheckboxes[#indicatorCheckboxes + 1] = checkbox
            DependsOn(checkbox, function() return WrathAvailable() and not CombatLocked() end)
        end
        AddIndicator("showStackCounter", L["WrathCueCounter"])
        AddIndicator("showStackCircles", L["WrathCueCircles"])
        AddIndicator("showStackBarColor", L["WrathCueBarColor"])
        AddIndicator("showPlayerWrathBubbles", L["ShowPlayerWrathBubbles"], L["ShowPlayerWrathBubblesDesc"])
        playerFrameCheckbox, y = CreateSettingsCheckbox(indicatorsContent,
            L["ShowPlayerPipFrame"], L["ShowPlayerPipFrameDesc"], y,
            function() return iSTSettings.showPlayerPipFrame end,
            function(value)
                iSTSettings.showPlayerPipFrame = value
                iST:UpdatePlayerWrathBubbles(GetTime())
            end, 20)
        DependsOn(playerFrameCheckbox, function()
            return WrathAvailable() and iSTSettings.showPlayerWrathBubbles and not CombatLocked()
        end)
        settingsFrame.indicatorCheckboxes = indicatorCheckboxes
        _, y = CreateInfoText(indicatorsContent, L["WrathCueDesc"], y, "GameFontDisableSmall")
        y = y - 8
        local stackStyleDropdown
        _, y = CreateSectionHeader(indicatorsContent, L["SectionIndicatorStyle"], y)
        stackStyleDropdown, y = CreateSettingsDropdown(indicatorsContent, L["StackBubbleStyle"], y, 250,
            function() return {
                { value = "SEAL_ICONS", text = L["StackBubbleSealIcons"] },
                { value = "CIRCLES", text = L["StackBubbleCircles"] },
            } end,
            function() return iSTSettings.stackBubbleStyle end,
            function(value)
                if CombatLocked() then return end
                iSTSettings.stackBubbleStyle = value
                iST:UpdateSealTimer()
                iST:UpdateWrathDisplay()
                iST:UpdatePlayerWrathBubbles(GetTime())
                RefreshEchoPreview()
            end)
        DependsOn(stackStyleDropdown, function()
            return WrathAvailable() and not CombatLocked()
                and (iSTSettings.showStackCircles or iSTSettings.showPlayerWrathBubbles)
        end)
        counterSizeSlider, y = CreateCustomSlider(indicatorsContent, L["StackCounterTextSize"], y, 10, 50, 1,
            function() return iSTSettings.stackCounterTextSize end,
            function(value)
                iSTSettings.stackCounterTextSize = value
                iST:ApplyBarTypography()
                RefreshEchoPreview()
                settingsFrame.UpdatePreviewLayout()
            end,
            function(value) return value .. "px" end)
        DependsOn(counterSizeSlider, function() return WrathAvailable() and iSTSettings.showStackCounter end)

        pipSizeSlider, y = CreateCustomSlider(indicatorsContent, L["WrathCircleSize"], y, 10, 50, 1,
            function() return iSTSettings.wrathCircleSize end,
            function(value)
                iSTSettings.wrathCircleSize = value
                iST:ApplyWrathCircleSize()
                RefreshEchoPreview()
                settingsFrame.UpdatePreviewLayout()
            end,
            function(value) return value .. "px" end)
        DependsOn(pipSizeSlider, function() return WrathAvailable() and iSTSettings.showStackCircles end)
        playerPipSizeSlider, y = CreateCustomSlider(indicatorsContent, L["PlayerPipSize"], y, 10, 50, 1,
            function() return iSTSettings.playerPipSize end,
            function(value)
                iSTSettings.playerPipSize = value
                iST:ApplyWrathCircleSize()
                iST:UpdatePlayerWrathBubbles(GetTime())
            end,
            function(value) return value .. "px" end)
        DependsOn(playerPipSizeSlider, function()
            return WrathAvailable() and iSTSettings.showPlayerWrathBubbles
        end)

        _, y = CreateSectionHeader(indicatorsContent, L["SectionCenterCue"], y)
        local centerCheckbox
        centerCheckbox, y = CreateSettingsCheckbox(indicatorsContent,
            L["CenterSwitchText"], L["CenterSwitchTextDesc"], y,
            function() return iSTSettings.showCenterSwitchText end,
            function(value)
                if CombatLocked() then return end
                iSTSettings.showCenterSwitchText = value
                if iST.State.EditMode then iST:SetCenterSwitchMoveMode(value) end
                iST:UpdateCenterSwitchText()
            end)
        DependsOn(centerCheckbox, function() return WrathAvailable() and not CombatLocked() end)

        local centerModeDropdown
        centerModeDropdown, y = CreateSettingsDropdown(indicatorsContent, L["CenterSwitchMode"], y, 250,
            function() return {
                { value = "BOTH", text = L["CenterModeBoth"] },
                { value = "SWITCH", text = L["CenterModeSwitch"] },
                { value = "ATTACK", text = L["CenterModeAttack"] },
            } end,
            function() return iSTSettings.centerSwitchMode end,
            function(value)
                if CombatLocked() then return end
                iSTSettings.centerSwitchMode = value
                iST:UpdateCenterSwitchText()
            end)
        DependsOn(centerModeDropdown, function()
            return WrathAvailable() and iSTSettings.showCenterSwitchText and not CombatLocked()
        end)

        local customPopup = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
        customPopup:SetSize(350, 140)
        customPopup:SetPoint("CENTER", settingsFrame, "CENTER")
        customPopup:SetFrameStrata("DIALOG")
        customPopup:EnableMouse(true)
        StyleSettingsSurface(customPopup)
        customPopup:Hide()
        settingsFrame.CustomCuePopup = customPopup
        local customTitle = customPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        customTitle:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 16, -13)
        local customBox = CreateFrame("EditBox", nil, customPopup, BACKDROP_TEMPLATE)
        customBox:SetSize(318, 28)
        customBox:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 16, -42)
        StyleSettingsSurface(customBox)
        customBox:SetFontObject(ChatFontNormal)
        customBox:SetTextInsets(8, 8, 0, 0)
        customBox:SetMaxLetters(60)
        customBox:SetAutoFocus(false)
        local function SaveCustomCue()
            if CombatLocked() then customPopup:Hide() return end
            local value = customBox:GetText():match("^%s*(.-)%s*$")
            if value == "" then value = customPopup.fallback end
            iSTSettings[customPopup.key] = value
            iSTSettings[customPopup.customKey] = value
            customPopup:Hide()
            customBox:ClearFocus()
            customPopup.dropdown:Refresh()
            iST:UpdateCenterSwitchText()
        end
        customBox:SetScript("OnEnterPressed", SaveCustomCue)
        customBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            customPopup:Hide()
        end)
        CreateSettingsButtonAt(customPopup, L["SaveCustomMessage"], 130, 16, -91, SaveCustomCue)
        CreateSettingsButtonAt(customPopup, L["CancelCustomMessage"], 130, 164, -91,
            function() customBox:ClearFocus(); customPopup:Hide() end)
        settingsFrame:HookScript("OnHide", function() customPopup:Hide() end)

        local function AddCueTextPicker(label, key, customKey, fallback, presets, description)
            local dropdown
            local function IsPreset(value)
                for _, preset in ipairs(presets) do
                    if value == preset then return true end
                end
                return false
            end
            dropdown, y = CreateSettingsDropdown(indicatorsContent, label, y, 250,
                function()
                    local options = {}
                    for _, preset in ipairs(presets) do
                        options[#options + 1] = { value = preset, text = preset }
                    end
                    options[#options + 1] = { value = "CUSTOM", text = L["CustomMessage"] }
                    return options
                end,
                function()
                    local value = iSTSettings[key] or fallback
                    return IsPreset(value) and value or "CUSTOM"
                end,
                function(value)
                    if CombatLocked() then return end
                    if value == "CUSTOM" then
                        customPopup.key, customPopup.customKey = key, customKey
                        customPopup.fallback, customPopup.dropdown = fallback, dropdown
                        customTitle:SetText(label)
                        customBox:SetText(iSTSettings[customKey] or iSTSettings[key] or fallback)
                        customPopup:Show()
                        customBox:SetFocus()
                    else
                        iSTSettings[key] = value
                        iST:UpdateCenterSwitchText()
                    end
                end, nil, nil, description)
            return dropdown
        end
        local switchTextDropdown = AddCueTextPicker(L["CenterSwitchPhrase"], "centerSwitchText", "centerSwitchCustomText",
            "Switch now", { "Switch now", "Unleash!", "Echoes ready" }, L["CenterSwitchPhraseDesc"])
        DependsOn(switchTextDropdown, function()
            return WrathAvailable() and iSTSettings.showCenterSwitchText
                and iSTSettings.centerSwitchMode ~= "ATTACK" and not CombatLocked()
        end)
        local attackTextDropdown = AddCueTextPicker(L["CenterAttackPhrase"], "centerAttackText", "centerAttackCustomText",
            "Attack now", { "Attack now", "Unleash now", "Strike now" }, L["CenterAttackPhraseDesc"])
        DependsOn(attackTextDropdown, function()
            return WrathAvailable() and iSTSettings.showCenterSwitchText
                and iSTSettings.centerSwitchMode ~= "SWITCH" and not CombatLocked()
        end)

        local moveButton
        moveButton, y = CreateSettingsButton(indicatorsContent,
            L["MoveCenterSwitchText"], 170, y, function()
                if CombatLocked() then return end
                local moving = not (iST.CenterSwitchFrame and iST.CenterSwitchFrame.moving)
            if moving then
                iST:SetCenterSwitchMoveMode(true)
            else
                iST:SetCenterSwitchMoveMode(false)
                iST:SetBarLocked(true)
            end
                local active = iST.CenterSwitchFrame and iST.CenterSwitchFrame.moving
                moveButton:SetText(active and L["DoneMovingCenterSwitchText"] or L["MoveCenterSwitchText"])
            end)
        settingsFrame.centerMoveButton = moveButton
        DependsOn(moveButton, function()
            return WrathAvailable() and iSTSettings.showCenterSwitchText and not CombatLocked()
        end)
        settingsFrame:HookScript("OnHide", function()
            if not iST.State.EditMode and iST.CenterSwitchFrame and iST.CenterSwitchFrame.moving then
                iST:SetCenterSwitchMoveMode(false)
                moveButton:SetText(L["MoveCenterSwitchText"])
            end
        end)

        scrollChildren[2]:SetHeight(math.abs(y) + 10)
    end

    -- Reminders have their own position and do not depend on the swing bar being visible.
    do
        local y = -10
        _, y = CreateInfoText(remindersContent, L["RemindersDesc"], y, "GameFontDisableSmall")
        y = y - 8
        for reminderIndex, kind in ipairs({ "FURY", "SEAL" }) do
            local reminderKind = kind
            local settings = iSTSettings.reminders[kind]
            local function set(key, value)
                settings[key] = value
                iST:ApplyReminderSettings()
            end
            _, y = CreateSectionHeader(remindersContent, kind == "FURY" and L["ReminderFury"] or L["ReminderSeal"], y)
            y = y - 6
            _, y = CreateSettingsCheckbox(remindersContent, L["ReminderEnable"], nil, y,
                function() return settings.enabled end, function(value) set("enabled", value) end)
            if kind == "FURY" then
                local protCheckbox
                protCheckbox, y = CreateSettingsCheckbox(remindersContent, L["ReminderProtOnly"], L["ReminderProtOnlyDesc"], y,
                    function() return settings.protOnly end, function(value) set("protOnly", value) end)
                DependsOn(protCheckbox, function() return settings.enabled end)
                local dungeonCheckbox
                dungeonCheckbox, y = CreateSettingsCheckbox(remindersContent, L["ReminderDungeonsOnly"], L["ReminderDungeonsOnlyDesc"], y,
                    function() return settings.dungeonsOnly end, function(value) set("dungeonsOnly", value) end)
                DependsOn(dungeonCheckbox, function() return settings.enabled end)
                local partyCheckbox
                partyCheckbox, y = CreateSettingsCheckbox(remindersContent, L["ReminderPartyOnly"], L["ReminderPartyOnlyDesc"], y,
                    function() return settings.partyOnly end, function(value) set("partyOnly", value) end)
                DependsOn(partyCheckbox, function() return settings.enabled end)
            else
                local combatCheckbox
                combatCheckbox, y = CreateSettingsCheckbox(remindersContent, L["OnlyInCombat"], nil, y,
                    function() return settings.onlyInCombat end, function(value) set("onlyInCombat", value) end)
                DependsOn(combatCheckbox, function() return settings.enabled end)
                local idleCheckbox
                idleCheckbox, y = CreateSettingsCheckbox(remindersContent, L["ReminderHideAfterIdle"], L["ReminderHideAfterIdleDesc"], y,
                    function() return settings.hideAfterIdle end, function(value) set("hideAfterIdle", value) end)
                DependsOn(idleCheckbox, function() return settings.enabled end)
                local capitalsCheckbox
                capitalsCheckbox, y = CreateSettingsCheckbox(remindersContent, L["ReminderHideInCapitals"], L["ReminderHideInCapitalsDesc"], y,
                    function() return settings.hideInCapitals end, function(value) set("hideInCapitals", value) end)
                DependsOn(capitalsCheckbox, function() return settings.enabled end)
            end
            y = y - 6
            local thresholdSlider
            thresholdSlider, y = CreateCustomSlider(remindersContent, L["ReminderThreshold"], y,
                0, kind == "FURY" and 600 or 30, kind == "FURY" and 5 or 1,
                function() return settings.warningSeconds end, function(value) set("warningSeconds", value) end,
                function(value) return value == 0 and L["ReminderMissingOnly"] or string.format(L["ReminderSeconds"], value) end)
            DependsOn(thresholdSlider, function() return settings.enabled end)
            local iconCheckbox
            iconCheckbox, y = CreateSettingsCheckbox(remindersContent, L["ReminderShowIcon"], nil, y,
                function() return settings.showIcon end, function(value) set("showIcon", value) end)
            DependsOn(iconCheckbox, function() return settings.enabled end)
            local timeCheckbox
            timeCheckbox, y = CreateSettingsCheckbox(remindersContent, L["ReminderShowTime"], nil, y,
                function() return settings.showTime end, function(value) set("showTime", value) end)
            DependsOn(timeCheckbox, function() return settings.enabled and settings.warningSeconds > 0 end)
            y = y - 6
            local reminderScaleSlider
            reminderScaleSlider, y = CreateCustomSlider(remindersContent, L["ReminderScale"], y, 0.5, 3, 0.05,
                function() return settings.scale end, function(value) set("scale", value) end,
                function(value) return string.format("%.2fx", value) end)
            DependsOn(reminderScaleSlider, function() return settings.enabled end)
            DependsOn(CreateSettingsButtonAt(remindersContent, L["ReminderPreviewMove"], 180, 20, y,
                function() iST:PreviewReminder(reminderKind) end),
                function() return settings.enabled end)
            DependsOn(CreateSettingsButtonAt(remindersContent, L["ResetPosition"], 160, 210, y,
                function() iST:ResetReminderPosition(reminderKind) end),
                function() return settings.enabled end)
            y = y - 50
        end
        scrollChildren[8]:SetHeight(math.abs(y) + 10)
    end

    -- Keep every sound trigger and selection together.
    do
        local y = -10
        _, y = CreateInfoText(soundsContent, L["SoundSharedDesc"], y, "GameFontDisableSmall")
        _, y = CreateSectionHeader(soundsContent, L["SectionEchoSound"], y)
        local echoSoundCheckbox
        echoSoundCheckbox, y = CreateSettingsCheckbox(soundsContent, L["SoundThreeStacks"],
            L["SoundThreeStacksDesc"], y,
            function() return iSTSettings.soundThreeStacks end,
            function(value) iSTSettings.soundThreeStacks = value end)
        DependsOn(echoSoundCheckbox, WrathAvailable)
        local echoSoundDropdown
        echoSoundDropdown, y = CreateSettingsDropdown(soundsContent, L["SoundChoice"], y, 370,
            function() return iST:GetSoundOptions(iSTSettings.soundThreeStacksChoice) end,
            function() return iSTSettings.soundThreeStacksChoice end,
            function(value) iSTSettings.soundThreeStacksChoice = value end, 8,
            function(value) iST:TestCueSound(value) end)
        DependsOn(echoSoundDropdown, function() return WrathAvailable() and iSTSettings.soundThreeStacks end)
        for soundIndex, kind in ipairs({ "FURY", "SEAL" }) do
            local settings = iSTSettings.reminders[kind]
            _, y = CreateSectionHeader(soundsContent,
                kind == "FURY" and L["ReminderFury"] or L["ReminderSeal"], y)
            local expiringCheckbox
            expiringCheckbox, y = CreateSettingsCheckbox(soundsContent, L["ReminderSoundExpiring"], nil, y,
                function() return settings.soundExpiring end,
                function(value) settings.soundExpiring = value; iST:ApplyReminderSettings() end)
            DependsOn(expiringCheckbox, function() return settings.enabled and settings.warningSeconds > 0 end)
            local missingCheckbox
            missingCheckbox, y = CreateSettingsCheckbox(soundsContent, L["ReminderSoundMissing"], nil, y,
                function() return settings.soundMissing end,
                function(value) settings.soundMissing = value; iST:ApplyReminderSettings() end)
            DependsOn(missingCheckbox, function() return settings.enabled end)
            local reminderSoundDropdown
            reminderSoundDropdown, y = CreateSettingsDropdown(soundsContent, L["SoundChoice"], y, 370,
                function() return iST:GetSoundOptions(settings.soundChoice) end,
                function() return settings.soundChoice end,
                function(value) settings.soundChoice = value; iST:ApplyReminderSettings() end, 8,
                function(value) iST:TestCueSound(value) end)
            DependsOn(reminderSoundDropdown, function()
                return settings.enabled and (settings.soundMissing
                    or (settings.soundExpiring and settings.warningSeconds > 0))
            end)
        end
        scrollChildren[9]:SetHeight(math.abs(y) + 10)
    end

    -- Appearance, position, and previews.
    do
        local y = -10
        local colorRefreshers = {}
        local refreshBarPreview
        local sealColorPreview = "Seal of Command"
        local function SealColorLabel(seal)
            local spellID = iST.SEAL_SPELL_IDS[seal]
            if spellID and C_Spell and type(C_Spell.GetSpellName) == "function" then
                local ok, localized = pcall(C_Spell.GetSpellName, spellID)
                if ok and not (issecretvalue and issecretvalue(localized))
                    and type(localized) == "string" then return localized end
            end
            return seal
        end

        local function AddColorEditor(label, getFunc, onChange, captureOriginal, condition)
            local refresh, button
            y, refresh, button = CreateColorEditor(customizationContent, label, y,
                getFunc, onChange, captureOriginal)
            table.insert(colorRefreshers, refresh)
            if condition then DependsOn(button, condition) end
        end

        _, y = CreateSectionHeader(customizationContent, L["SectionBarAppearance"], y)

        _, y = CreateSettingsDropdown(customizationContent, L["BarStyle"], y, 220,
            function()
                return {
                    { value = "CLASSIC", text = L["BarStyleClassic"] },
                    { value = "BLOCK", text = L["BarStyleBlock"] },
                    { value = "GLOSSY", text = L["BarStyleGlossy"] },
                    { value = "FRAMELESS", text = L["BarStyleFrameless"] },
                }
            end,
            function() return iSTSettings.barStyle end,
            function(value)
                iSTSettings.barStyle = value
                iST:ApplyBarStyle()
                if refreshBarPreview then refreshBarPreview() end
            end)

        _, y = CreateSettingsDropdown(customizationContent, L["BarTexture"], y, 220,
            function()
                return {
                    { value = "BLIZZARD", text = L["BarTextureBlizzard"] },
                    { value = "RAID", text = L["BarTextureRaid"] },
                    { value = "SKILLS", text = L["BarTextureSkills"] },
                    { value = "SOLID", text = L["BarTextureSolid"] },
                    { value = "SOFT", text = L["BarTextureSoft"] },
                    { value = "GLASS", text = L["BarTextureGlass"] },
                    { value = "RIDGES", text = L["BarTextureRidges"] },
                    { value = "DIAGONAL", text = L["BarTextureDiagonal"] },
                }
            end,
            function() return iSTSettings.barTexture end,
            function(value)
                iSTSettings.barTexture = value
                iST:ApplyBarStyle()
                if refreshBarPreview then refreshBarPreview() end
            end)

        refreshBarPreview = function()
            settingsFrame.previewSealOverride = sealColorPreview
            if settingsFrame.RefreshEchoPreview then settingsFrame.RefreshEchoPreview() end
        end
        customizationContent:HookScript("OnShow", refreshBarPreview)

        _, y = CreateCustomSlider(customizationContent, L["BarWidth"], y, 150, 500, 10,
            function() return iSTSettings.barWidth end,
            function(v)
                iSTSettings.barWidth = v
                if iST.BarFrame then
                    iST.BarFrame:SetWidth(v)
                    iST:ApplyBarTypography()
                end
                refreshBarPreview()
            end,
            function(v) return v .. "px" end
        )

        _, y = CreateCustomSlider(customizationContent, L["BarHeight"], y, 15, 50, 1,
            function() return iSTSettings.barHeight end,
            function(v)
                iSTSettings.barHeight = v
                if iST.BarFrame then
                    iST.BarFrame:SetHeight(v)
                    if iST.BarFrame.UpdateModernDimensions then
                        iST.BarFrame:UpdateModernDimensions(v)
                    elseif iST.BarFrame.sealIcon then
                        iST.BarFrame.sealIcon:SetSize(v, v)
                    end
                end
                refreshBarPreview()
            end,
            function(v) return v .. "px" end
        )

        local sealIconSizeSlider
        sealIconSizeSlider, y = CreateCustomSlider(customizationContent, L["IconSize"], y, 16, 64, 1,
            function() return iSTSettings.sealIconSize end,
            function(v)
                iSTSettings.sealIconSize = v
                if iST.BarFrame and iST.BarFrame.UpdateModernDimensions then
                    iST.BarFrame:UpdateModernDimensions(iSTSettings.barHeight)
                end
                iST:UpdateWrathDisplay()
                refreshBarPreview()
            end,
            function(v) return v .. "px" end
        )
        DependsOn(sealIconSizeSlider, function()
            return iSTSettings.showSealIcon or (WrathAvailable() and iSTSettings.showEchoTimer)
        end)

        _, y = CreateSectionHeader(customizationContent, L["SectionTextAppearance"], y)

        local swingTextSizeSlider
        swingTextSizeSlider, y = CreateCustomSlider(customizationContent, L["SwingTextSize"], y, 8, 28, 1,
            function() return iSTSettings.swingTextSize end,
            function(v)
                iSTSettings.swingTextSize = v
                iST:ApplyBarTypography()
                refreshBarPreview()
            end,
            function(v) return v .. "pt" end
        )
        DependsOn(swingTextSizeSlider, function()
            return iSTSettings.showWeaponSpeed or iSTSettings.showSwingRemaining
        end)

        local sealTextSizeSlider
        sealTextSizeSlider, y = CreateCustomSlider(customizationContent, L["CurrentSealTextSize"], y, 8, 24, 1,
            function() return iSTSettings.sealTextSize end,
            function(v)
                iSTSettings.sealTextSize = v
                iST:ApplyBarTypography()
                refreshBarPreview()
            end,
            function(v) return v .. "pt" end
        )
        DependsOn(sealTextSizeSlider, function() return iSTSettings.showSealName end)

        local latencyTextSizeSlider
        latencyTextSizeSlider, y = CreateCustomSlider(customizationContent, L["LatencyTextSize"], y, 8, 20, 1,
            function() return iSTSettings.latencyTextSize end,
            function(v)
                iSTSettings.latencyTextSize = v
                iST:ApplyBarTypography()
                refreshBarPreview()
            end,
            function(v) return v .. "pt" end
        )
        DependsOn(latencyTextSizeSlider, function() return iSTSettings.showLatency end)

        local function GetFontOptions()
            local options = {}
            for _, font in ipairs(iST:GetAvailableFontChoices()) do
                table.insert(options, { value = font.value, text = font.label })
            end
            return options
        end

        _, y = CreateSettingsDropdown(customizationContent, L["BarFont"], y, 250,
            GetFontOptions,
            function() return iSTSettings.barFont end,
            function(value)
                iSTSettings.barFont = value
                iST:ApplyBarTypography()
                iST:UpdateWrathDisplay()
                refreshBarPreview()
            end,
            10)
        _, y = CreateInfoText(customizationContent, L["DisplayFontDesc"], y, "GameFontDisableSmall")

        _, y = CreateSectionHeader(customizationContent, L["SectionBarColors"], y)

        AddColorEditor(L["ColorBar"],
            function() return iSTSettings.barColor end, refreshBarPreview)

        local wrongSealCheckbox
        wrongSealCheckbox, y = CreateSettingsCheckbox(customizationContent, L["HighlightWrongSeal"],
            L["HighlightWrongSealDesc"], y,
            function() return iSTSettings.highlightWrongSeal end,
            function(value)
                iSTSettings.highlightWrongSeal = value
                iST:UpdateWrathDisplay()
            end)
        DependsOn(wrongSealCheckbox, WrathAvailable)
        AddColorEditor(L["ColorWrongSeal"],
            function() return iSTSettings.wrongSealColor end,
            function() iST:UpdateWrathDisplay() end, nil,
            function() return WrathAvailable() and iSTSettings.highlightWrongSeal end)

        AddColorEditor(L["ColorBorderNormal"],
            function() return iSTSettings.borderNormalColor end, refreshBarPreview)

        _, y = CreateSectionHeader(customizationContent, L["SectionSealBarColors"], y)
        _, y = CreateSettingsCheckbox(customizationContent, L["ColorBarBySeal"],
            L["ColorBarBySealDesc"], y,
            function() return iSTSettings.barColorBySeal end,
            function(value)
                iSTSettings.barColorBySeal = value
                iST:UpdateWrathDisplay()
                refreshBarPreview()
            end)
        local previewSealDropdown
        previewSealDropdown, y = CreateSettingsDropdown(customizationContent, L["PreviewSealColor"], y, 250,
            function()
                local options = {}
                for _, seal in ipairs(iST.SealBarColorOrder) do
                    options[#options + 1] = { value = seal, text = SealColorLabel(seal) }
                end
                return options
            end,
            function() return sealColorPreview end,
            function(value) sealColorPreview = value; refreshBarPreview() end)
        DependsOn(previewSealDropdown, function() return iSTSettings.barColorBySeal end)
        for _, seal in ipairs(iST.SealBarColorOrder) do
            local selectedSeal = seal
            AddColorEditor(SealColorLabel(selectedSeal),
                function() return iSTSettings.sealBarColors[selectedSeal] end,
                function()
                    iST:UpdateWrathDisplay()
                    refreshBarPreview()
                end, nil, function() return iSTSettings.barColorBySeal end)
        end

        _, y = CreateSectionHeader(customizationContent, L["SectionStackColors"], y)
        local schemeDropdown
        local stageRefreshers = {}
        local function RefreshStageColors()
            if schemeDropdown then schemeDropdown:Refresh() end
            for _, refresh in ipairs(stageRefreshers) do refresh() end
        end
        schemeDropdown, y = CreateSettingsDropdown(customizationContent, L["WrathColorScheme"], y, 250,
            function()
                return {
                    { value = "GOLD", text = L["WrathSchemeGold"] },
                    { value = "TRAFFIC", text = L["WrathSchemeTraffic"] },
                    { value = "BLUE", text = L["WrathSchemeBlue"] },
                    { value = "CUSTOM", text = L["WrathSchemeCustom"] },
                }
            end,
            function() return iSTSettings.wrathColorScheme end,
            function(value)
                iST:SetWrathColorScheme(value)
                RefreshStageColors()
            end)
        DependsOn(schemeDropdown, WrathAvailable)
        _, y = CreateInfoText(customizationContent, L["WrathStageColorsDesc"], y, "GameFontDisableSmall")
        y = y - 8
        for stage = 0, 3 do
            local selectedStage = stage
            local refresh, stageButton
            y, refresh, stageButton = CreateColorEditor(customizationContent,
                string.format(L["WrathStageColor"], selectedStage), y,
                function()
                    local color = iST:GetWrathCueColor(selectedStage)
                    return { r = color.r, g = color.g, b = color.b, a = color.a }
                end,
                function(color)
                    if color then iST:SetWrathStageColor(selectedStage, color) end
                    RefreshStageColors()
                end,
                function()
                    local previousScheme = iSTSettings.wrathColorScheme
                    local previousColors = {}
                    for index = 0, 3 do
                        local color = iSTSettings["wrathColor" .. index]
                        previousColors[index] = { r = color.r, g = color.g, b = color.b, a = color.a }
                    end
                    return function()
                        for index = 0, 3 do iSTSettings["wrathColor" .. index] = previousColors[index] end
                        iST:SetWrathColorScheme(previousScheme)
                        RefreshStageColors()
                    end
                end)
            stageRefreshers[#stageRefreshers + 1] = refresh
            DependsOn(stageButton, WrathAvailable)
        end

        _, y = CreateSectionHeader(customizationContent, L["SectionEchoAccentColors"], y)
        AddColorEditor(L["ColorSwitchMessage"],
            function() return iSTSettings.centerSwitchColor end,
            function() iST:UpdateCenterSwitchText() end, nil,
            function()
                return WrathAvailable() and iSTSettings.showCenterSwitchText
                    and iSTSettings.centerSwitchMode ~= "ATTACK"
            end)
        AddColorEditor(L["ColorAttackMessage"],
            function() return iSTSettings.centerAttackColor end,
            function() iST:UpdateCenterSwitchText() end, nil,
            function()
                return WrathAvailable() and iSTSettings.showCenterSwitchText
                    and iSTSettings.centerSwitchMode ~= "SWITCH"
            end)
        AddColorEditor(L["ColorNameplateEcho"],
            function() return iSTSettings.nameplateEchoColor end,
            function() iST:UpdateNameplateEchoDisplay() end, nil,
            function() return WrathAvailable() and iSTSettings.showNameplateEcho end)
        AddColorEditor(L["ColorEchoTimerText"],
            function() return iSTSettings.echoTimerTextColor end,
            function() iST:UpdateEchoTimerDisplay() end, nil,
            function() return WrathAvailable() and iSTSettings.showEchoTimer end)

        _, y = CreateSettingsButton(customizationContent, L["DefaultColors"], 140, y - 4, function()
            local colorKeys = {
                "barColor",
                "wrongSealColor",
                "borderNormalColor",
                "centerSwitchColor",
                "centerAttackColor",
                "nameplateEchoColor",
                "echoTimerTextColor",
            }

            for _, key in ipairs(colorKeys) do
                local default = iST.SettingsDefault[key]
                local color = iSTSettings[key]
                color.r = default.r
                color.g = default.g
                color.b = default.b
                color.a = default.a
            end
            for _, seal in ipairs(iST.SealBarColorOrder) do
                local color = iSTSettings.sealBarColors[seal]
                local default = iST.SealBarColorDefaults[seal]
                for _, channel in ipairs({ "r", "g", "b", "a" }) do
                    color[channel] = default[channel]
                end
            end
            iST:ResetWrathColors()
            RefreshStageColors()

            for _, refresh in ipairs(colorRefreshers) do
                refresh()
            end
            if iST.InvalidateBarState then iST:InvalidateBarState() end
            iST:ApplyStackCounterColor()
            iST:UpdateWrathDisplay()
            iST:UpdateCenterSwitchText()
            iST:UpdateNameplateEchoDisplay()
            iST:UpdateEchoTimerDisplay()
            refreshBarPreview()
        end)

        _, y = CreateSectionHeader(customizationContent, L["SectionNameplateEcho"], y)

        local nameplateStyleDropdown
        nameplateStyleDropdown, y = CreateSettingsDropdown(customizationContent, L["NameplateEchoStyle"], y, 250,
            function() return {
                { value = "DOTS", text = L["NameplateEchoDots"] },
                { value = "SEAL_ICONS", text = L["NameplateEchoSealIcons"] },
            } end,
            function() return iSTSettings.nameplateEchoStyle end,
            function(value)
                if CombatLocked() then return end
                iSTSettings.nameplateEchoStyle = value
                iST:UpdateNameplateEchoDisplay()
            end)
        DependsOn(nameplateStyleDropdown, function()
            return WrathAvailable() and iSTSettings.showNameplateEcho and not CombatLocked()
        end)
        local nameplateScaleSlider
        nameplateScaleSlider, y = CreateCustomSlider(customizationContent, L["NameplateEchoScale"], y, 0.5, 2, 0.05,
            function() return iSTSettings.nameplateEchoScale end,
            function(v) iSTSettings.nameplateEchoScale = v; iST:UpdateNameplateEchoDisplay() end,
            function(v) return string.format("%.2fx", v) end)
        DependsOn(nameplateScaleSlider, function() return WrathAvailable() and iSTSettings.showNameplateEcho end)
        local nameplatePipSlider
        nameplatePipSlider, y = CreateCustomSlider(customizationContent, L["NameplateEchoPipSize"], y, 10, 40, 1,
            function() return iSTSettings.nameplateEchoPipSize or 18 end,
            function(v) iSTSettings.nameplateEchoPipSize = v; iST:UpdateNameplateEchoDisplay() end,
            function(v) return v .. "px" end)
        DependsOn(nameplatePipSlider, function()
            return WrathAvailable() and iSTSettings.showNameplateEcho and not CombatLocked()
        end)
        local nameplateOffsetSlider
        nameplateOffsetSlider, y = CreateCustomSlider(customizationContent, L["NameplateEchoOffset"], y, -60, 30, 1,
            function() return iSTSettings.nameplateEchoOffsetY end,
            function(v) iSTSettings.nameplateEchoOffsetY = v; iST:UpdateNameplateEchoDisplay() end,
            function(v) return v .. "px" end)
        DependsOn(nameplateOffsetSlider, function() return WrathAvailable() and iSTSettings.showNameplateEcho end)
        local nameplateGlowCheckbox
        nameplateGlowCheckbox, y = CreateSettingsCheckbox(customizationContent, L["NameplateEchoGlow"], nil, y,
            function() return iSTSettings.nameplateEchoGlow end,
            function(v) iSTSettings.nameplateEchoGlow = v; iST:UpdateNameplateEchoDisplay() end)
        DependsOn(nameplateGlowCheckbox, function() return WrathAvailable() and iSTSettings.showNameplateEcho end)

        _, y = CreateSectionHeader(customizationContent, L["SectionPosition"], y)
        settingsFrame.barLockCheckbox, y = CreateSettingsCheckbox(customizationContent, L["LockBar"], L["LockBarDesc"], y,
            function() return iSTSettings.barLocked end,
            function(v) iST:SetBarLocked(v) end
        )

        CreateSettingsButtonAt(customizationContent, L["CenterHorizontally"], 170, 20, y, function()
            iST:CenterBarHorizontally()
        end)
        CreateSettingsButtonAt(customizationContent, L["ResetPosition"], 140, 198, y, function()
            iST:ResetBarPosition()
        end)
        y = y - 36

        _, y = CreateInfoText(customizationContent, L["IndependentDragDesc"], y, "GameFontDisableSmall")
        DependsOn(CreateSettingsButtonAt(customizationContent, L["ResetSealPosition"], 170, 20, y,
            function() iST:ResetSealIconPosition() end),
            function() return iSTSettings.showSealIcon end)
        DependsOn(CreateSettingsButtonAt(customizationContent, L["ResetCounterPosition"], 170, 210, y,
            function() iST:ResetStackCountPosition() end),
            function() return WrathAvailable() and iSTSettings.showStackCounter end)
        DependsOn(CreateSettingsButtonAt(customizationContent, L["ResetEchoTimerPosition"], 170, 400, y,
            function() iST:ResetEchoTimerPosition() end),
            function() return WrathAvailable() and iSTSettings.showEchoTimer end)
        y = y - 40

        _, y = CreateSectionHeader(customizationContent, L["SectionPreview"], y)

        local previewCard = CreateFrame("Frame", nil, customizationContent, BACKDROP_TEMPLATE)
        previewCard:SetPoint("TOPLEFT", customizationContent, "TOPLEFT", 20, y)
        previewCard:SetPoint("TOPRIGHT", customizationContent, "TOPRIGHT", -20, y)
        previewCard:SetHeight(74)
        StyleSettingsSurface(previewCard)

        local previewDescription = previewCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        previewDescription:SetPoint("TOPLEFT", previewCard, "TOPLEFT", 12, -10)
        previewDescription:SetPoint("TOPRIGHT", previewCard, "TOPRIGHT", -12, -10)
        previewDescription:SetJustifyH("LEFT")
        previewDescription:SetText(L["PreviewSequenceDesc"])

        -- Previews use test state; they do not change the tracked combat stacks.
        CreateSettingsButtonAt(previewCard, L["PreviewNormal"], 140, 12, -34, function()
            iST:StartTestMode()
        end, true)
        CreateSettingsButtonAt(previewCard, L["PreviewStacks"], 140, 159, -34, function()
            iST:StartStackTestMode()
        end, true)
        CreateSettingsButtonAt(previewCard, L["PreviewParryHaste"], 140, 306, -34, function()
            iST:StartParryHasteTestMode()
        end, true)
        y = y - previewCard:GetHeight() - 8

        scrollChildren[3]:SetHeight(math.abs(y) + 10)
    end

    -- Account-wide snapshots and shareable setup codes.
    do
        local y = -15
        _, y = CreateSectionHeader(profilesContent, L["SectionSavedProfiles"], y)
        _, y = CreateInfoText(profilesContent, L["ProfilesDesc"], y, "GameFontDisableSmall")
        y = y - 12

        local activeProfile = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        activeProfile:SetPoint("TOPLEFT", profilesContent, "TOPLEFT", 20, y)
        activeProfile:SetTextColor(1, 0.78, 0.24)
        local function RefreshActiveProfile()
            activeProfile:SetText(string.format(L["ProfileActive"], iST:GetActiveProfileName()))
        end
        RefreshActiveProfile()
        y = y - 26

        local nameLabel = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameLabel:SetPoint("TOPLEFT", profilesContent, "TOPLEFT", 20, y)
        nameLabel:SetText(L["ProfileName"])
        y = y - 19
        local nameBox = CreateFrame("EditBox", nil, profilesContent, BACKDROP_TEMPLATE)
        nameBox:SetSize(260, 28)
        nameBox:SetPoint("TOPLEFT", profilesContent, "TOPLEFT", 20, y)
        StyleSettingsSurface(nameBox)
        nameBox:SetFontObject(ChatFontNormal)
        nameBox:SetTextInsets(8, 8, 0, 0)
        nameBox:SetMaxLetters(32)
        nameBox:SetAutoFocus(false)
        nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        local status = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetWidth(contentWidth - 40)
        status:SetJustifyH("LEFT")
        status:SetText("")
        local function SetStatus(message, errorState)
            status:SetText(message or "")
            status:SetTextColor(errorState and 1 or 0.45, errorState and 0.30 or 0.92,
                errorState and 0.22 or 0.48)
        end

        local selectedProfile, deleteArmed = iST:GetActiveProfileName(), nil
        local profileDropdown
        DependsOn(CreateSettingsButtonAt(profilesContent, L["ProfileSave"], 145, 295, y, function()
            local ok, result = iST:SaveProfile(nameBox:GetText())
            SetStatus(ok and string.format(L["ProfileSaved"], result) or result, not ok)
            if ok then
                selectedProfile, deleteArmed = result, nil
                nameBox:SetText("")
                profileDropdown:Refresh()
                RefreshActiveProfile()
            end
        end), function() return not CombatLocked() end)
        _, y = CreateSettingDescription(profilesContent, L["ProfileNameDesc"],
            20, y - 35, contentWidth - 40)
        y = y - 4
        profileDropdown, y = CreateSettingsDropdown(profilesContent, L["ProfileChoose"], y, 325,
            function()
                local options = {}
                for _, name in ipairs(iST:GetSavedProfileNames()) do
                    options[#options + 1] = { value = name, text = name }
                end
                if #options == 0 then options[1] = { value = "", text = L["ProfileChoose"] } end
                return options
            end,
            function() return selectedProfile or iST:GetActiveProfileName() end,
            function(value)
                selectedProfile, deleteArmed = value ~= "" and value or nil, nil
                SetStatus("")
            end)

        DependsOn(CreateSettingsButtonAt(profilesContent, L["ProfileLoad"], 145, 20, y, function()
            local ok, err = iST:LoadProfile(selectedProfile)
            if ok then ReloadUI() else SetStatus(err, true) end
        end), function() return selectedProfile ~= nil and not CombatLocked() end)
        DependsOn(CreateSettingsButtonAt(profilesContent, L["ProfileRename"], 145, 180, y, function()
            local ok, result = iST:RenameProfile(selectedProfile, nameBox:GetText())
            SetStatus(ok and string.format(L["ProfileRenamed"], result) or result, not ok)
            if ok then
                selectedProfile, deleteArmed = result, nil
                nameBox:SetText("")
                profileDropdown:Refresh()
                RefreshActiveProfile()
            end
        end), function()
            return selectedProfile ~= nil and selectedProfile ~= "Main"
                and selectedProfile ~= "Previous setup" and not CombatLocked()
        end)
        DependsOn(CreateSettingsButtonAt(profilesContent, L["ProfileDelete"], 145, 340, y, function()
            if not selectedProfile then SetStatus("Select a saved profile.", true); return end
            if selectedProfile == "Main" or selectedProfile == iST:GetActiveProfileName() then
                local _, err = iST:DeleteProfile(selectedProfile)
                SetStatus(err, true)
                return
            end
            if deleteArmed ~= selectedProfile then
                deleteArmed = selectedProfile
                SetStatus(L["ProfileDeleteConfirm"], true)
                return
            end
            local removed = selectedProfile
            local ok, err = iST:DeleteProfile(removed)
            if not ok then SetStatus(err, true); return end
            selectedProfile, deleteArmed = iST:GetActiveProfileName(), nil
            profileDropdown:Refresh()
            SetStatus(string.format(L["ProfileDeleted"], removed))
        end), function()
            return selectedProfile ~= nil and selectedProfile ~= "Main"
                and selectedProfile ~= iST:GetActiveProfileName() and not CombatLocked()
        end)
        y = y - 38
        status:SetPoint("TOPLEFT", profilesContent, "TOPLEFT", 20, y)
        y = y - 28

        _, y = CreateSectionHeader(profilesContent, L["SectionShareSetup"], y)
        _, y = CreateInfoText(profilesContent, L["ProfilesShareDesc"], y, "GameFontDisableSmall")
        y = y - 12
        DependsOn(CreateSettingsButtonAt(profilesContent, L["ProfileExport"], 145, 20, y, function()
            iST:OpenProfileTransfer("EXPORT")
        end), function() return not CombatLocked() end)
        DependsOn(CreateSettingsButtonAt(profilesContent, L["ProfileImport"], 145, 180, y, function()
            iST:OpenProfileTransfer("IMPORT")
        end), function() return not CombatLocked() end)
        y = y - 42
        scrollChildren[10]:SetHeight(math.abs(y) + 10)
        profilesContainer:HookScript("OnShow", function()
            selectedProfile = iST:GetActiveProfileName()
            RefreshActiveProfile()
            profileDropdown:Refresh()
        end)
    end

    -- Addon information and testing settings.
    do
        local y = -15

        local aboutIcon = aboutContent:CreateTexture(nil, "ARTWORK")
        aboutIcon:SetSize(64, 64)
        aboutIcon:SetPoint("TOP", aboutContent, "TOP", 0, y)
        aboutIcon:SetTexture(iconPath)
        y = y - 70

        local aboutTitle = aboutContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aboutTitle:SetPoint("TOP", aboutContent, "TOP", 0, y)
        aboutTitle:SetText(Colors.iST .. "iSealTwist" .. Colors.Reset .. " " .. Colors.Green .. "v" .. iST.Version .. Colors.Reset)
        y = y - 20

        local aboutAuthor = aboutContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        aboutAuthor:SetPoint("TOP", aboutContent, "TOP", 0, y)
        aboutAuthor:SetText(L["CreatedBy"] .. Colors.Cyan .. iST.Author .. Colors.Reset)
        y = y - 25

        local aboutDesc = aboutContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        aboutDesc:SetPoint("TOPLEFT", aboutContent, "TOPLEFT", 25, y)
        aboutDesc:SetWidth(contentWidth - 50)
        aboutDesc:SetJustifyH("LEFT")
        aboutDesc:SetWordWrap(true)
        aboutDesc:SetText(L["AboutText"])
        y = y - aboutDesc:GetStringHeight() - 15

        _, y = CreateSettingsButton(aboutContent, L["WhatsNewOpen"], 170, y, function()
            iST:OpenWhatsNew()
        end)
        y = y - 10

        _, y = CreateSectionHeader(aboutContent, L["SectionTesting"], y)

        _, y = CreateSettingsCheckbox(aboutContent, L["DebugMode"], nil, y,
            function() return iSTSettings.debugMode end,
            function(value)
                iSTSettings.debugMode = value
                if value then iST:DebugMsg("Debug mode enabled.", 3) end
            end)

        _, y = CreateInfoText(aboutContent, L["TestingDesc"], y, "GameFontDisableSmall")
        y = y - 12

        _, y = CreateSectionHeader(aboutContent, Colors.iST .. "Links", y)

        local linkText
        linkText, y = CreateInfoText(aboutContent,
            L["ISTCurseForgeLink"],
            y, "GameFontDisableSmall")

        scrollChildren[4]:SetHeight(math.abs(y) + 10)
    end

    -- Other addon pages show a settings shortcut when installed, or a link otherwise.
    local promoData = {
        { content = iWRContent, scrollIdx = 5, name = "iWillRemember", addonName = "iWillRemember", tabIdx = 5,
          tabLoaded = "iWillRemember", tabLabel = "iWillRemember",
          desc = L["IWRPromoDesc"], link = L["IWRPromoLink"],
          installedDesc = Colors.iST .. "iWillRemember" .. Colors.Reset .. " is installed. Open its settings to manage player notes and sync.",
          buttonText = "Open iWR Settings",
          tabLabel = L["TabIWR"], tabLabelPromo = L["TabIWRPromo"],
          getFrame = function() return _G.iWR and _G.iWR.SettingsFrame end },
        { content = iNIFContent, scrollIdx = 6, name = "iNeedIfYouNeed", addonName = "iNeedIfYouNeed", tabIdx = 6,
          desc = L["INIFPromoDesc"], link = L["INIFPromoLink"],
          installedDesc = Colors.iST .. "iNeedIfYouNeed" .. Colors.Reset .. " is installed. Open its settings to configure loot options.",
          buttonText = "Open iNIF Settings",
          tabLabel = L["TabINIF"], tabLabelPromo = L["TabINIFPromo"],
          getFrame = function() return _G["iNIFSettingsFrame"] end },
        { content = iRCContent, scrollIdx = 7, name = "iRC: Guild Connect", addonName = "iRC", tabIdx = 7,
          desc = L["IRCPromoDesc"], link = L["IRCPromoLink"],
          installedDesc = Colors.iST .. "iRC: Guild Connect" .. Colors.Reset .. " is installed. Open its panel to manage guild connections, rules, verification, and community tools.",
          buttonText = "Open iRC Panel",
          tabLabel = L["TabIRC"], tabLabelPromo = L["TabIRCPromo"],
          getFrame = function()
              local aceAddon = LibStub("AceAddon-3.0", true)
              local addon = aceAddon and aceAddon:GetAddon("iRCGuildConnect", true)
              if addon and addon.MainUI then
                  addon.MainUI:Open()
                  return addon.MainUI.frame
              end
          end },
    }

    local installedFrames = {}
    local promoFrames = {}

    for _, promo in ipairs(promoData) do
        local installedFrame = CreateFrame("Frame", nil, promo.content)
        installedFrame:SetAllPoints(promo.content)
        installedFrame:Hide()
        do
            local _, y = nil, -10
            _, y = CreateSectionHeader(installedFrame, Colors.iST .. promo.name, y)
            local desc
            desc, y = CreateInfoText(installedFrame, promo.installedDesc, y, "GameFontHighlight")
            y = y - 10
            local openBtn = CreateFrame("Button", nil, installedFrame, BACKDROP_TEMPLATE)
            openBtn:SetSize(180, 28)
            openBtn:SetPoint("TOPLEFT", installedFrame, "TOPLEFT", 25, y)
            StyleSettingsButton(openBtn)
            openBtn:SetText(promo.buttonText)
            openBtn:SetScript("OnClick", function()
                local frame = promo.getFrame()
                -- Open the other addon at this window's position.
                if frame then
                    local point, _, relPoint, xOfs, yOfs = settingsFrame:GetPoint()
                    frame:ClearAllPoints()
                    frame:SetPoint(point, UIParent, relPoint, xOfs, yOfs)
                    frame:Show()
                    settingsFrame:Hide()
                end
            end)
        end
        installedFrames[promo.tabIdx] = installedFrame

        local promoFrame = CreateFrame("Frame", nil, promo.content)
        promoFrame:SetAllPoints(promo.content)
        promoFrame:Hide()
        do
            local _, y = nil, -10
            _, y = CreateSectionHeader(promoFrame, Colors.iST .. promo.name, y)
            local desc
            desc, y = CreateInfoText(promoFrame, promo.desc, y, "GameFontHighlight")
            y = y - 4
            local link
            link, y = CreateInfoText(promoFrame, promo.link, y, "GameFontDisableSmall")
        end
        promoFrames[promo.tabIdx] = promoFrame

        scrollChildren[promo.scrollIdx]:SetHeight(400)
    end

    -- Recheck when opening because another addon may have loaded since creation.
    settingsFrame:HookScript("OnShow", function()
        settingsFrame.barLockCheckbox:SetChecked(iSTSettings.barLocked)
        for _, promo in ipairs(promoData) do
            local loaded = C_AddOns.IsAddOnLoaded(promo.addonName)
            if installedFrames[promo.tabIdx] then
                installedFrames[promo.tabIdx]:SetShown(loaded)
            end
            if promoFrames[promo.tabIdx] then
                promoFrames[promo.tabIdx]:SetShown(not loaded)
            end
            if sidebarButtons[promo.tabIdx] then
                sidebarButtons[promo.tabIdx].text:SetText(loaded and promo.tabLabel or promo.tabLabelPromo)
            end
        end
        if sidebarButtons[activeIndex] then
            pageHeader.title:SetText(sidebarButtons[activeIndex].text:GetText())
        end
    end)
    -- Menus are parented to UIParent, so closing the window must hide them too.
    settingsFrame:HookScript("OnHide", function()
        if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        openDropdown = nil
    end)

    ShowTab(1)
    RefreshAvailability()

    settingsFrame:Hide()
    self.SettingsFrame = settingsFrame
end

-- Update this version and its highlights together for the next release
-- that needs an automatic announcement. Hotfixes keep these notes and their dismissal state.
local WHATS_NEW_VERSION = "0.9.1"

function iST:OpenProfileTransfer(mode)
    if CombatLocked() or (mode ~= "EXPORT" and mode ~= "IMPORT") then return end
    local frame = self.ProfileTransferFrame
    if not frame then
        frame = CreateFrame("Frame", "iSTProfileTransferFrame", UIParent, BACKDROP_TEMPLATE)
        frame:SetSize(620, 360)
        frame:SetPoint("CENTER", UIParent, "CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        StyleSettingsSurface(frame)
        table.insert(UISpecialFrames, frame:GetName())

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
        frame.title = title
        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -45)
        frame.hint = hint

        local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -72)
        nameLabel:SetText(L["ProfileImportName"])
        local importName = CreateFrame("EditBox", nil, frame, BACKDROP_TEMPLATE)
        importName:SetSize(260, 26)
        importName:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -91)
        StyleSettingsSurface(importName)
        importName:SetFontObject(ChatFontNormal)
        importName:SetTextInsets(8, 8, 0, 0)
        importName:SetMaxLetters(32)
        importName:SetAutoFocus(false)
        importName:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        frame.importName, frame.nameLabel = importName, nameLabel

        local box = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -77)
        box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 82)
        StyleSettingsSurface(box)
        frame.box = box
        local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -23, 8)
        StyleSettingsScroll(scroll)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(520)
        edit:SetHeight(1)
        edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)
        frame.edit, frame.scroll = edit, scroll

        local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 55)
        status:SetWidth(570)
        status:SetJustifyH("LEFT")
        frame.status = status

        local apply = CreateSettingsButtonAt(frame, L["ProfileApply"], 160, 18, -317, function()
            local ok, err = iST:ImportSettings(edit:GetText(), importName:GetText())
            if ok then ReloadUI()
            else
                status:SetText(err)
                status:SetTextColor(1, 0.30, 0.22)
            end
        end)
        frame.apply = apply
        CreateSettingsButtonAt(frame, L["ProfileClose"], 110, 492, -317, function()
            frame:Hide()
        end)
        frame:Hide()
        self.ProfileTransferFrame = frame
    end

    frame.title:SetText(mode == "EXPORT" and L["ProfileExportTitle"] or L["ProfileImportTitle"])
    frame.hint:SetText(mode == "EXPORT" and L["ProfileCopyHint"] or L["ProfilePasteHint"])
    frame.apply:SetShown(mode == "IMPORT")
    frame.nameLabel:SetShown(mode == "IMPORT")
    frame.importName:SetShown(mode == "IMPORT")
    frame.box:ClearAllPoints()
    frame.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, mode == "IMPORT" and -125 or -77)
    frame.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 82)
    if mode == "EXPORT" then
        local code, err = self:ExportSettings()
        frame.edit:SetText(code or "")
        frame.status:SetText(err or "")
    else
        frame.importName:SetText("")
        frame.edit:SetText("")
        frame.status:SetText("")
    end
    frame:Show()
    frame.edit:SetCursorPosition(0)
    frame.scroll:SetVerticalScroll(0)
    frame.edit:SetFocus()
    if mode == "EXPORT" then frame.edit:HighlightText() end
end

function iST:CreateWhatsNewPanel()
    if self.WhatsNewFrame then return end

    local frame = CreateFrame("Frame", "iSTWhatsNewFrame", UIParent, BACKDROP_TEMPLATE)
    frame:Hide()
    frame:SetSize(500, 325)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    StyleSettingsSurface(frame)
    table.insert(UISpecialFrames, frame:GetName())

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -13)
    icon:SetTexture(iconPath)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -16)
    title:SetText(string.format(L["WhatsNewTitle"], WHATS_NEW_VERSION))

    local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 61, -39)
    intro:SetText(L["WhatsNewIntro"])

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -65)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -65)
    divider:SetColorTexture(1, 0.59, 0.09, 0.5)

    for index, key in ipairs({ "WhatsNewEchoTargets", "WhatsNewIndicators", "WhatsNewColorsSounds", "WhatsNewProfiles" }) do
        local y = -78 - (index - 1) * 47
        local number = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        number:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, y)
        number:SetText(tostring(index) .. ".")
        number:SetTextColor(1, 0.70, 0.18)

        local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 50, y - 1)
        detail:SetSize(420, 39)
        detail:SetJustifyH("LEFT")
        detail:SetJustifyV("TOP")
        detail:SetWordWrap(true)
        detail:SetText(L[key])
    end

    CreateSettingsButtonAt(frame, L["WhatsNewSettings"], 150, 16, -283, function()
        frame:Hide()
        iST:SettingsOpen()
    end)
    CreateSettingsButtonAt(frame, L["WhatsNewDismiss"], 110, 374, -283, function()
        frame:Hide()
    end)

    frame:SetScript("OnHide", function()
        if not iST.State.PendingWhatsNew then
            iSTAccountSettings.whatsNewSeenVersion = WHATS_NEW_VERSION
        end
    end)
    self.WhatsNewFrame = frame
end

function iST:OpenWhatsNew()
    if CombatLocked() then return end
    self:CreateWhatsNewPanel()
    self.State.PendingWhatsNew = nil
    self.WhatsNewFrame:Show()
end

function iST:MaybeShowWhatsNew()
    if not iSTAccountSettings
        or iSTAccountSettings.whatsNewSeenVersion == WHATS_NEW_VERSION then
        self.State.PendingWhatsNew = nil
        return
    end
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return end
    if CombatLocked() then
        self.State.PendingWhatsNew = true
        return
    end
    self:OpenWhatsNew()
end

-- Keep the related settings windows from overlapping when opening iST.
local function CloseOtherAddonSettings()
    local iWRFrame = _G.iWR and _G.iWR.SettingsFrame
    if iWRFrame and iWRFrame:IsShown() then iWRFrame:Hide() end
    local iNIFFrame = _G["iNIFSettingsFrame"]
    if iNIFFrame and iNIFFrame:IsShown() then iNIFFrame:Hide() end
end

function iST:CreateQuickMacroPanel()
    if self.QuickMacroFrame then return end
    local frame = CreateFrame("Frame", "iSTQuickMacroFrame", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(540, 350)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    StyleSettingsSurface(frame)
    table.insert(UISpecialFrames, frame:GetName())

    local header = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(42)
    StyleSettingsSurface(header, true)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("LEFT", header, "LEFT", 15, 0)
    title:SetText(Colors.iST .. "iSealTwist|r  |cFFAAA08C" .. L["QuickMacroTitle"] .. "|r")
    local close = CreateSettingsButtonAt(header, "X", 26, 498, -7, function() frame:Hide() end)
    close:SetHeight(26)

    local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -56)
    intro:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -56)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["SealPairLegend"])

    local function CreateSealCard(x)
        local card = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
        card:SetSize(246, 154)
        card:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -86)
        StyleSettingsSurface(card)
        card:SetBackdropColor(0.045, 0.036, 0.025, 1)
        local accent = card:CreateTexture(nil, "ARTWORK")
        accent:SetColorTexture(1, 0.59, 0.09, 0.8)
        accent:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
        accent:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
        accent:SetHeight(2)
        local divider = card:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(0.35, 0.27, 0.13, 0.8)
        divider:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -82)
        divider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -82)
        divider:SetHeight(1)
        return card
    end
    local fromCard, intoCard = CreateSealCard(16), CreateSealCard(278)

    local names, seen = {}, {}
    for _, name in pairs(self.SEALS) do
        if not seen[name] then names[#names + 1], seen[name] = name, true end
    end
    table.sort(names)
    local options = {}
    for _, name in ipairs(names) do
        local spellID = self.SEAL_SPELL_IDS[name]
        local icon = spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        options[#options + 1] = {
            value = name,
            text = (icon and "|T" .. tostring(icon) .. ":16:16:0:0|t " or "") .. name,
        }
    end
    local function Label(card, text, y, small)
        local label = card:CreateFontString(nil, "OVERLAY", small and "GameFontNormalSmall" or "GameFontNormal")
        label:SetPoint("TOPLEFT", card, "TOPLEFT", 15, y)
        label:SetText(text)
        return label
    end
    Label(fromCard, L["TwistFromSeal"], -13)
    Label(intoCard, L["TwistIntoSeal"], -13)
    local fromDropdown, intoDropdown
    fromDropdown = CreateStyledDropdown(fromCard, 216,
        function() return options end,
        function() return iSTSettings.twistFromSeal end,
        function(value)
            if self:SetTwistSeal("From", value) then intoDropdown:Refresh() end
        end, nil,
        function(option) return option.value == iSTSettings.twistIntoSeal end)
    fromDropdown:SetPoint("TOPLEFT", fromCard, "TOPLEFT", 15, -34)
    intoDropdown = CreateStyledDropdown(intoCard, 216,
        function() return options end,
        function() return iSTSettings.twistIntoSeal end,
        function(value)
            if self:SetTwistSeal("Into", value) then fromDropdown:Refresh() end
        end, nil,
        function(option) return option.value == iSTSettings.twistFromSeal end)
    intoDropdown:SetPoint("TOPLEFT", intoCard, "TOPLEFT", 15, -34)

    Label(fromCard, L["SwitchAtStacks"], -96, true)
    Label(intoCard, L["SwitchAtStacks"], -96, true)
    local stackOptions = {
        { value = 0, text = L["AnyEchoStack"] },
        { value = 1, text = L["OneStack"] },
        { value = 2, text = L["TwoStacks"] },
        { value = 3, text = L["ThreeStacks"] },
    }
    local fromTarget = CreateStyledDropdown(fromCard, 216,
        function() return stackOptions end,
        function() return iSTSettings.twistFromStacks end,
        function(value) self:SetTwistStackTarget("From", value) end)
    fromTarget:SetPoint("TOPLEFT", fromCard, "TOPLEFT", 15, -114)
    local intoTarget = CreateStyledDropdown(intoCard, 216,
        function() return stackOptions end,
        function() return iSTSettings.twistIntoStacks end,
        function(value) self:SetTwistStackTarget("Into", value) end)
    intoTarget:SetPoint("TOPLEFT", intoCard, "TOPLEFT", 15, -114)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -257)
    help:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -257)
    help:SetJustifyH("LEFT")
    help:SetWordWrap(true)
    help:SetText(L["QuickMacroDesc"])
    local helpHeight = math.max(14, help:GetStringHeight())
    local macroY = math.min(-307, -257 - helpHeight - 16)
    local macros = CreateSettingsButtonAt(frame, L["OpenMacros"], 156, 366, macroY, OpenMacroWindow)
    macros:SetHeight(30)
    frame:SetHeight(-macroY + 43)
    frame:SetScript("OnShow", function()
        for _, dropdown in ipairs({ fromDropdown, intoDropdown, fromTarget, intoTarget }) do
            dropdown:Refresh()
        end
    end)
    frame:SetScript("OnHide", function()
        if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        openDropdown = nil
    end)
    frame:Hide()
    self.QuickMacroFrame = frame
end

function iST:QuickMacroToggle()
    if self.QuickMacroFrame and self.QuickMacroFrame:IsShown() then
        self.QuickMacroFrame:Hide()
        return
    end
    if CombatLocked() then return end
    if not self.QuickMacroFrame then self:CreateQuickMacroPanel() end
    if not self.QuickMacroFrame then return end
    if self.SettingsFrame then self.SettingsFrame:Hide() end
    CloseOtherAddonSettings()
    self.QuickMacroFrame:Show()
end

function iST:SettingsToggle()
    if self.QuickMacroFrame then self.QuickMacroFrame:Hide() end
    if self.SettingsFrame and self.SettingsFrame:IsShown() then
        self.SettingsFrame:Hide()
    elseif CombatLocked() then
        return
    elseif self.SettingsFrame then
        CloseOtherAddonSettings()
        self.SettingsFrame:Show()
    else
        self:CreateOptionsPanel()
        if self.SettingsFrame then
            CloseOtherAddonSettings()
            self.SettingsFrame:Show()
        end
    end
end

function iST:SettingsOpen()
    if CombatLocked() then return end
    if self.QuickMacroFrame then self.QuickMacroFrame:Hide() end
    if not self.SettingsFrame then
        self:CreateOptionsPanel()
    end
    if self.SettingsFrame then
        CloseOtherAddonSettings()
        self.SettingsFrame:Show()
    end
end

function iST:SettingsClose()
    if self.SettingsFrame then
        self.SettingsFrame:Hide()
    end
end
