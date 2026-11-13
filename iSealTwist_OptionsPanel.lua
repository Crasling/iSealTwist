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

local function CreateSettingsCheckbox(parent, label, descText, yOffset, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", nil, parent, CHECKBOX_TEMPLATE)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
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
    end)

    -- The checkbox template is taller than its label. Reserve the whole control
    -- before placing descriptions or the next row underneath it.
    local nextY = yOffset - math.max(24, cb:GetHeight()) - 6
    if descText and descText ~= "" then
        local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 52, nextY)
        desc:SetWidth(parent:GetWidth() - 72)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(descText)
        local height = desc:GetStringHeight()
        if height < 12 then height = 12 end
        nextY = nextY - height - 6
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
    thumb:SetScript("OnMouseDown", function() isDragging = true end)
    thumb:SetScript("OnMouseUp", function() isDragging = false end)
    track:SetScript("OnMouseDown", function()
        local val = ValueFromMouse()
        setFunc(val)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
        SetVisualValue(val)
        isDragging = true
    end)
    track:SetScript("OnMouseUp", function() isDragging = false end)
    track:SetScript("OnUpdate", function()
        if not isDragging then return end
        local val = ValueFromMouse()
        setFunc(val)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
        SetVisualValue(val)
    end)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        local current = getFunc()
        local newVal = SnapValue(current + delta * step)
        newVal = math.max(minVal, math.min(maxVal, newVal))
        setFunc(newVal)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
        SetVisualValue(newVal)
    end)

    SetVisualValue(getFunc())
    return track, yOffset - ROW_HEIGHT
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

local function CreateStyledDropdown(parent, width, getOptions, getValue, setValue, getOptionText, isDisabled)
    local dropdown = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    dropdown:SetSize(width, 28)
    StyleSettingsButton(dropdown)

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
        if openDropdown == dropdown then openDropdown = nil end
    end)
    dropdown.menu.buttons = {}
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
        local options = getOptions() or {}
        local current = getValue()
        for index, option in ipairs(options) do
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
                button.text:SetPoint("LEFT", button, "LEFT", 10, 0)
                button.text:SetPoint("RIGHT", button, "RIGHT", -10, 0)
                button.text:SetJustifyH("LEFT")
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
                self.menu.buttons[index] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 5, -5 - ((index - 1) * 25))
            button:SetPoint("TOPRIGHT", self.menu, "TOPRIGHT", -5, -5 - ((index - 1) * 25))
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
            end)
            button:Show()
        end
        for index = #options + 1, #self.menu.buttons do self.menu.buttons[index]:Hide() end
        self.menu:SetHeight(math.max(12, (#options * 25) + 10))
    end

    dropdown:SetScript("OnClick", function(self)
        if self.menu:IsShown() then
            self.menu:Hide()
            openDropdown = nil
            return
        end
        if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        openDropdown = self
        self:RefreshMenu()
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

local function CreateSettingsDropdown(parent, label, yOffset, width, getOptions, getValue, setValue)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    labelText:SetText(label)
    labelText:SetTextColor(0.96, 0.90, 0.78)

    local dropdown = CreateStyledDropdown(parent, width, getOptions, getValue, setValue)
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset - 18)
    return dropdown, yOffset - 58, function() dropdown:Refresh() end
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

    RefreshSwatch()
    return yOffset - 30, RefreshSwatch
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

        container:EnableMouseWheel(true)
        container:SetScript("OnMouseWheel", function(_, delta)
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

    local tabContents = {
        generalContainer,
        indicatorsContainer,
        customizationContainer,
        aboutContainer,
        iWRContainer,
        iNIFContainer,
        iRCContainer,
        remindersContainer,
    }

    local sidebarButtons = {}
    local activeIndex = 1

    local function ShowTab(index)
        activeIndex = index
        if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        openDropdown = nil
        pageHeader.title:SetText(pageInfo[index][1])
        pageHeader.subtitle:SetText(pageInfo[index][2])
        for i, content in ipairs(tabContents) do
            content:SetShown(i == index)
        end
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
        { type = "tab", label = L["TabCustomization"], index = 3 },
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

        _, y = CreateSettingsCheckbox(generalContent, L["OnlyInCombat"], L["OnlyInCombatDesc"], y,
            function() return iSTSettings.onlyInCombat end,
            function(v) iSTSettings.onlyInCombat = v iST:UpdateBarVisibility() end
        )

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
        pairCard:SetHeight(166)
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
                iSTSettings.twistFromSeal = value
                if intoDropdown then intoDropdown:Refresh() end
                UpdateSealDirection()
                iST:UpdateWrathDisplay()
                if iST.RequestTwistMacroRefresh then iST:RequestTwistMacroRefresh() end
            end,
            function(option) return option.text end,
            function(option) return option.value == iSTSettings.twistIntoSeal end)
        fromDropdown:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -32)

        intoDropdown = CreateStyledDropdown(pairCard, 190,
            function() return SealOptions(sealChoices) end,
            function() return iSTSettings.twistIntoSeal end,
            function(value)
                iSTSettings.twistIntoSeal = value
                fromDropdown:Refresh()
                UpdateSealDirection()
                iST:UpdateWrathDisplay()
                if iST.RequestTwistMacroRefresh then iST:RequestTwistMacroRefresh() end
            end,
            function(option) return option.text end,
            function(option) return option.value == iSTSettings.twistFromSeal end)
        intoDropdown:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -32)
        legend = pairCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        legend:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -78)
        legend:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -78)
        legend:SetJustifyH("LEFT")
        legend:SetHeight(34)
        UpdateSealDirection()

        local macrosButton = CreateSettingsButtonAt(pairCard, L["OpenMacros"], 130, 170, -124, OpenMacroWindow)
        macrosButton:ClearAllPoints()
        macrosButton:SetPoint("TOP", pairCard, "TOP", 0, -124)

        y = y - pairCard:GetHeight() - 8

        local intoDesc = generalContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        intoDesc:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        intoDesc:SetWidth(450)
        intoDesc:SetJustifyH("LEFT")
        intoDesc:SetText(L["SealPairDesc"])
        y = y - intoDesc:GetStringHeight() - 10

        scrollChildren[1]:SetHeight(math.abs(y) + 10)
    end

    -- Indicators: seal information and Unsealed Wrath cues.
    do
        local y = -10
        _, y = CreateSectionHeader(indicatorsContent, L["SectionBarInformation"], y)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowLatency"], L["ShowLatencyDesc"], y,
            function() return iSTSettings.showLatency end,
            function(v) iSTSettings.showLatency = v end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowSealIcon"], L["ShowSealIconDesc"], y,
            function() return iSTSettings.showSealIcon end,
            function(v)
                iSTSettings.showSealIcon = v
                iST:UpdateSealDisplay()
            end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowSealTimer"], L["ShowSealTimerDesc"], y,
            function() return iSTSettings.showSealTimer end,
            function(v)
                iSTSettings.showSealTimer = v
                iST:UpdateSealTimer()
            end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowWeaponSpeed"], L["ShowWeaponSpeedDesc"], y,
            function() return iSTSettings.showWeaponSpeed end,
            function(v) iSTSettings.showWeaponSpeed = v end
        )

        _, y = CreateSectionHeader(indicatorsContent, L["SectionUnsealedWrath"], y)
        _, y = CreateInfoText(indicatorsContent, L["WrathCueDesc"], y, "GameFontDisableSmall")
        y = y - 8
        y, settingsFrame.refreshStackCounterColor = CreateColorEditor(indicatorsContent,
            L["StackCounterColor"], y,
            function() return iSTSettings.stackCounterColor end,
            function() iST:ApplyStackCounterColor() end)

        _, y = CreateCustomSlider(indicatorsContent, L["StackCounterTextSize"], y - 8, 8, 40, 1,
            function() return iSTSettings.stackCounterTextSize end,
            function(value)
                iSTSettings.stackCounterTextSize = value
                iST:ApplyBarTypography()
            end,
            function(value) return value .. "pt" end)

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
                _, y = CreateSettingsCheckbox(remindersContent, L["ReminderProtOnly"], L["ReminderProtOnlyDesc"], y,
                    function() return settings.protOnly end, function(value) set("protOnly", value) end)
                _, y = CreateSettingsCheckbox(remindersContent, L["ReminderDungeonsOnly"], L["ReminderDungeonsOnlyDesc"], y,
                    function() return settings.dungeonsOnly end, function(value) set("dungeonsOnly", value) end)
                _, y = CreateSettingsCheckbox(remindersContent, L["ReminderPartyOnly"], L["ReminderPartyOnlyDesc"], y,
                    function() return settings.partyOnly end, function(value) set("partyOnly", value) end)
            else
                _, y = CreateSettingsCheckbox(remindersContent, L["OnlyInCombat"], nil, y,
                    function() return settings.onlyInCombat end, function(value) set("onlyInCombat", value) end)
                _, y = CreateSettingsCheckbox(remindersContent, L["ReminderHideAfterIdle"], L["ReminderHideAfterIdleDesc"], y,
                    function() return settings.hideAfterIdle end, function(value) set("hideAfterIdle", value) end)
                _, y = CreateSettingsCheckbox(remindersContent, L["ReminderHideInCapitals"], L["ReminderHideInCapitalsDesc"], y,
                    function() return settings.hideInCapitals end, function(value) set("hideInCapitals", value) end)
            end
            y = y - 6
            _, y = CreateCustomSlider(remindersContent, L["ReminderThreshold"], y,
                0, kind == "FURY" and 600 or 30, kind == "FURY" and 5 or 1,
                function() return settings.warningSeconds end, function(value) set("warningSeconds", value) end,
                function(value) return value == 0 and L["ReminderMissingOnly"] or string.format(L["ReminderSeconds"], value) end)
            _, y = CreateSettingsCheckbox(remindersContent, L["ReminderShowIcon"], nil, y,
                function() return settings.showIcon end, function(value) set("showIcon", value) end)
            _, y = CreateSettingsCheckbox(remindersContent, L["ReminderShowTime"], nil, y,
                function() return settings.showTime end, function(value) set("showTime", value) end)
            y = y - 6
            _, y = CreateCustomSlider(remindersContent, L["ReminderScale"], y, 0.5, 3, 0.05,
                function() return settings.scale end, function(value) set("scale", value) end,
                function(value) return string.format("%.2fx", value) end)
            _, y = CreateSettingsCheckbox(remindersContent, L["ReminderLock"], nil, y,
                function() return settings.locked end, function(value) set("locked", value) end)
            CreateSettingsButtonAt(remindersContent, L["ReminderPreviewMove"], 180, 20, y,
                function() iST:PreviewReminder(reminderKind) end)
            CreateSettingsButtonAt(remindersContent, L["ResetPosition"], 160, 210, y,
                function() iST:ResetReminderPosition(reminderKind) end)
            y = y - 50
        end
        scrollChildren[8]:SetHeight(math.abs(y) + 10)
    end

    -- Appearance, position, and previews.
    do
        local y = -10
        local colorRefreshers = {}

        local function AddColorEditor(label, getFunc, onChange, captureOriginal)
            local refresh
            y, refresh = CreateColorEditor(customizationContent, label, y, getFunc, onChange, captureOriginal)
            table.insert(colorRefreshers, refresh)
        end

        _, y = CreateSectionHeader(customizationContent, L["SectionBarAppearance"], y)

        _, y = CreateCustomSlider(customizationContent, L["BarWidth"], y, 100, 500, 10,
            function() return iSTSettings.barWidth end,
            function(v)
                iSTSettings.barWidth = v
                if iST.BarFrame then
                    iST.BarFrame:SetWidth(v)
                    iST:ApplyBarTypography()
                end
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
            end,
            function(v) return v .. "px" end
        )

        _, y = CreateCustomSlider(customizationContent, L["IconSize"], y, 16, 64, 1,
            function() return iSTSettings.sealIconSize end,
            function(v)
                iSTSettings.sealIconSize = v
                if iST.BarFrame and iST.BarFrame.UpdateModernDimensions then
                    iST.BarFrame:UpdateModernDimensions(iSTSettings.barHeight)
                end
            end,
            function(v) return v .. "px" end
        )

        _, y = CreateSectionHeader(customizationContent, L["SectionTextAppearance"], y)

        _, y = CreateCustomSlider(customizationContent, L["SwingTextSize"], y, 8, 28, 1,
            function() return iSTSettings.swingTextSize end,
            function(v)
                iSTSettings.swingTextSize = v
                iST:ApplyBarTypography()
            end,
            function(v) return v .. "pt" end
        )

        _, y = CreateCustomSlider(customizationContent, L["CurrentSealTextSize"], y, 8, 24, 1,
            function() return iSTSettings.sealTextSize end,
            function(v)
                iSTSettings.sealTextSize = v
                iST:ApplyBarTypography()
            end,
            function(v) return v .. "pt" end
        )

        _, y = CreateCustomSlider(customizationContent, L["LatencyTextSize"], y, 8, 20, 1,
            function() return iSTSettings.latencyTextSize end,
            function(v)
                iSTSettings.latencyTextSize = v
                iST:ApplyBarTypography()
            end,
            function(v) return v .. "pt" end
        )

        local function GetFontOptions()
            local options = {}
            for _, font in ipairs(iST.FONT_CHOICES) do
                table.insert(options, { value = font.value, text = font.label })
            end
            return options
        end

        _, y = CreateSettingsDropdown(customizationContent, L["BarFont"], y, 220,
            GetFontOptions,
            function() return iSTSettings.barFont end,
            function(value)
                iSTSettings.barFont = value
                iST:ApplyBarTypography()
            end
        )

        _, y = CreateSectionHeader(customizationContent, L["SectionBarColors"], y)

        AddColorEditor(L["ColorBar"],
            function() return iSTSettings.barColor end, nil)

        AddColorEditor(L["ColorBorderNormal"],
            function() return iSTSettings.borderNormalColor end, nil)

        _, y = CreateSettingsButton(customizationContent, L["DefaultColors"], 140, y - 4, function()
            local colorKeys = {
                "barColor",
                "borderNormalColor",
                "stackCounterColor",
            }

            for _, key in ipairs(colorKeys) do
                local default = iST.SettingsDefault[key]
                local color = iSTSettings[key]
                color.r = default.r
                color.g = default.g
                color.b = default.b
                color.a = default.a
            end
            iST:ResetWrathColors()

            for _, refresh in ipairs(colorRefreshers) do
                refresh()
            end
            if settingsFrame.refreshStackCounterColor then settingsFrame.refreshStackCounterColor() end

            if iST.InvalidateBarState then iST:InvalidateBarState() end
            iST:ApplyStackCounterColor()
        end)

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

        _, y = CreateSectionHeader(aboutContent, L["SectionTesting"], y)

        CreateSettingsCheckbox(aboutContent, L["DebugMode"], nil, y,
            function() return iSTSettings.debugMode end,
            function(value)
                iSTSettings.debugMode = value
                if value then iST:DebugMsg("Debug mode enabled.", 3) end
            end)

        -- This overrides addon tracking only; it does not change the game talent.
        local fakeTalent = CreateSettingsCheckbox(aboutContent, L["FakeUnsealedWrath"], nil, y,
            function() return iSTSettings.fakeUnsealedWrath end,
            function(value) iST:SetFakeUnsealedWrath(value) end)
        fakeTalent:ClearAllPoints()
        fakeTalent:SetPoint("TOPLEFT", aboutContent, "TOPLEFT", 245, y)
        y = y - 30

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

    settingsFrame:Hide()
    self.SettingsFrame = settingsFrame
end

-- Keep the related settings windows from overlapping when opening iST.
local function CloseOtherAddonSettings()
    local iWRFrame = _G.iWR and _G.iWR.SettingsFrame
    if iWRFrame and iWRFrame:IsShown() then iWRFrame:Hide() end
    local iNIFFrame = _G["iNIFSettingsFrame"]
    if iNIFFrame and iNIFFrame:IsShown() then iNIFFrame:Hide() end
end

function iST:SettingsToggle()
    if self.SettingsFrame and self.SettingsFrame:IsVisible() then
        self.SettingsFrame:Hide()
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
