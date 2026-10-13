-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                         iSealTwist — Options Panel                             │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

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
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Helper Functions                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

local function CreateSectionHeader(parent, text, yOffset)
    local header = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    if header.SetBackdrop then
        header:SetBackdrop(PANEL_BACKDROP)
        header:SetBackdropColor(0.045, 0.040, 0.035, 0.96)
        header:SetBackdropBorderColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.42)
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

    return header, yOffset - 28
end

local function CreateSettingsCheckbox(parent, label, descText, yOffset, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", nil, parent, CHECKBOX_TEMPLATE)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    if not cb.Text then
        cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    end
    cb.Text:SetText(label)
    cb.Text:SetFontObject(GameFontHighlight)
    cb.Text:SetTextColor(0.96, 0.90, 0.78)
    cb:SetChecked(getFunc())
    cb:SetScript("OnClick", function(self)
        setFunc(self:GetChecked() and true or false)
        if iST.InvalidateBarState then iST:InvalidateBarState() end
    end)

    local nextY = yOffset - 22
    if descText and descText ~= "" then
        local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 48, nextY)
        desc:SetWidth(350)
        desc:SetJustifyH("LEFT")
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

    -- Track (thin bar)
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

    -- Track background with rounded look
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.055, 0.045, 0.032, 0.96)

    -- Subtle top/bottom edges for depth
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

    -- Fill bar (orange, follows value)
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    fill:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.78)

    -- Thumb (circular knob using the round minimap texture)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(THUMB_SIZE, THUMB_SIZE)
    thumb:EnableMouse(true)

    -- Outer circle (dark border)
    local thumbOuter = thumb:CreateTexture(nil, "OVERLAY", nil, 1)
    thumbOuter:SetSize(THUMB_SIZE, THUMB_SIZE)
    thumbOuter:SetPoint("CENTER")
    thumbOuter:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    thumbOuter:SetVertexColor(0.18, 0.11, 0.035, 1)

    -- Inner circle (orange fill, slightly smaller)
    local thumbInner = thumb:CreateTexture(nil, "OVERLAY", nil, 2)
    thumbInner:SetSize(THUMB_SIZE - 3, THUMB_SIZE - 3)
    thumbInner:SetPoint("CENTER")
    thumbInner:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    thumbInner:SetVertexColor(1, 0.59, 0.09, 1)

    -- Highlight on hover
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
        local cx = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local left = track:GetLeft()
        local fraction = (cx - left) / TRACK_WIDTH
        fraction = math.max(0, math.min(1, fraction))
        local raw = minVal + fraction * (maxVal - minVal)
        return SnapValue(raw)
    end

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
    btn:SetBackdropColor(0.035, 0.030, 0.022, 0.99)
    btn:SetBackdropBorderColor(0.62, 0.39, 0.10, 1)
    btn:SetNormalFontObject(GameFontNormal)
    btn:SetHighlightFontObject(GameFontHighlight)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.15)
        self:SetBackdropBorderColor(ORANGE[1], ORANGE[2], ORANGE[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.035, 0.030, 0.022, 0.99)
        self:SetBackdropBorderColor(0.62, 0.39, 0.10, 1)
    end)
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

        -- Newer clients expose the macro frame as a mixin. Its selection index
        -- is relative to the active account/character tab, not the global slot.
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
            -- Older Macro UIs select by the global macro slot directly.
            pcall(MacroFrame_SelectMacro, macroIndex)
        end
    end

    -- MacroFrame's OnShow selects the first account macro, so run our selection
    -- one frame later after Blizzard has completed its initial refresh.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SelectSealTwistMacro)
    else
        SelectSealTwistMacro()
    end
end

local function CreateStyledDropdown(parent, width, getOptions, getValue, setValue, getOptionText, isDisabled)
    local dropdown = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    dropdown:SetSize(width, 30)
    dropdown:SetBackdrop(PANEL_BACKDROP)
    dropdown:SetBackdropColor(0.035, 0.030, 0.022, 0.99)
    dropdown:SetBackdropBorderColor(0.62, 0.39, 0.10, 1)
    dropdown:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 11, 0)
    dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -30, 0)
    dropdown.text:SetJustifyH("LEFT")
    dropdown.text:SetWordWrap(false)
    dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -10, 0)
    dropdown.arrow:SetText("v")
    dropdown.arrow:SetTextColor(1, 0.72, 0.12)

    dropdown.menu = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    dropdown.menu:SetWidth(width)
    dropdown.menu:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdown.menu:SetClampedToScreen(true)
    dropdown.menu:SetToplevel(true)
    dropdown.menu:EnableMouse(true)
    dropdown.menu:SetBackdrop(PANEL_BACKDROP)
    dropdown.menu:SetBackdropColor(0.018, 0.016, 0.012, 0.995)
    dropdown.menu:SetBackdropBorderColor(0.78, 0.48, 0.12, 1)
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
        -- Embedded |c color markup wins over FontString:SetTextColor. Remove
        -- only that markup so disabled seal choices can render visibly grey.
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
                button.check:SetColorTexture(0.25, 1, 0.35, 1)
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
                button.text:SetTextColor(0.35, 1, 0.42)
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
    fs:SetWidth(370)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    local height = fs:GetStringHeight()
    if height < 14 then height = 14 end
    return fs, yOffset - height - 4
end

local function CreateColorEditor(parent, label, yOffset, getFunc, onChange)
    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    button:SetSize(470, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    button:SetBackdrop(PANEL_BACKDROP)
    button:SetBackdropColor(0.035, 0.030, 0.022, 0.92)
    button:SetBackdropBorderColor(0.38, 0.27, 0.12, 0.85)

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
        if onChange then onChange() end
        if iST.InvalidateBarState then iST:InvalidateBarState() end
    end

    button:SetScript("OnClick", function()
        if not ColorPickerFrame then return end

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
            ApplyColor(original.r, original.g, original.b, original.a)
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

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Create Options Panel                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:CreateOptionsPanel()
    if self.SettingsFrame then return end

    local sidebarWidth = 150
    local contentWidth = 550

    -- ═══════════════════════════════════════════════════════════
    -- Main Frame
    -- ═══════════════════════════════════════════════════════════
    local settingsFrame = CreateFrame("Frame", "iSTSettingsFrame", UIParent, BACKDROP_TEMPLATE)
    settingsFrame:SetSize(750, 520)
    settingsFrame:SetPoint("CENTER", UIParent, "CENTER")
    settingsFrame:SetMovable(true)
    settingsFrame:SetClampedToScreen(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:SetFrameStrata("HIGH")

    if settingsFrame.SetBackdrop then
        settingsFrame:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        settingsFrame:SetBackdropColor(0.018, 0.016, 0.012, 0.98)
        settingsFrame:SetBackdropBorderColor(0.72, 0.44, 0.10, 0.95)
    end

    -- Shadow
    local shadow = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    shadow:SetPoint("TOPLEFT", settingsFrame, -1, 1)
    shadow:SetPoint("BOTTOMRIGHT", settingsFrame, 1, -1)
    if shadow.SetBackdrop then
        shadow:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 5 })
        shadow:SetBackdropBorderColor(0, 0, 0, 0.8)
    end

    -- Drag
    settingsFrame:RegisterForDrag("LeftButton", "RightButton")
    settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- ═══════════════════════════════════════════════════════════
    -- Title Bar
    -- ═══════════════════════════════════════════════════════════
    local titleBar = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    titleBar:SetHeight(31)
    titleBar:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", 0, 0)
    if titleBar.SetBackdrop then
        titleBar:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        titleBar:SetBackdropColor(0.055, 0.043, 0.025, 1)
        titleBar:SetBackdropBorderColor(0.58, 0.35, 0.08, 0.95)
    end

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText(Colors.iST .. "iSealTwist" .. Colors.Green .. " v" .. iST.Version)

    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetHeight(1)
    titleAccent:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 8, 2)
    titleAccent:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", -8, 2)
    titleAccent:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.70)

    -- Compact close control matching the dark-gold iRC buttons.
    local closeButton = CreateFrame("Button", nil, settingsFrame, BACKDROP_TEMPLATE)
    closeButton:SetSize(24, 22)
    closeButton:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -7, -5)
    StyleSettingsButton(closeButton)
    closeButton:SetText("X")
    closeButton:SetScript("OnClick", function() iST:SettingsClose() end)

    -- ═══════════════════════════════════════════════════════════
    -- Sidebar
    -- ═══════════════════════════════════════════════════════════
    local sidebar = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    sidebar:SetWidth(sidebarWidth)
    sidebar:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, -35)
    sidebar:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 10, 10)
    if sidebar.SetBackdrop then
        sidebar:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        sidebar:SetBackdropColor(0.025, 0.022, 0.018, 0.98)
        sidebar:SetBackdropBorderColor(0.48, 0.31, 0.10, 0.85)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Content Area
    -- ═══════════════════════════════════════════════════════════
    local contentArea = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
    contentArea:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -10, 10)
    if contentArea.SetBackdrop then
        contentArea:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        contentArea:SetBackdropBorderColor(0.48, 0.31, 0.10, 0.90)
        contentArea:SetBackdropColor(0.028, 0.025, 0.021, 0.98)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab Content Factory
    -- ═══════════════════════════════════════════════════════════
    local scrollChildren = {}

    local function CreateTabContent()
        local container = CreateFrame("Frame", nil, contentArea)
        container:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 5, -5)
        container:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -5, 5)
        container:Hide()

        local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 0)

        -- Hide scrollbar
        local sb = scrollFrame.ScrollBar
        if sb then sb:SetAlpha(0) sb:SetWidth(1) end

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(contentWidth - 40)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        table.insert(scrollChildren, scrollChild)

        -- Mousewheel
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

    -- ═══════════════════════════════════════════════════════════
    -- Create Tab Containers
    -- ═══════════════════════════════════════════════════════════
    local generalContainer, generalContent = CreateTabContent()
    local timingContainer, timingContent = CreateTabContent()
    local indicatorsContainer, indicatorsContent = CreateTabContent()
    local customizationContainer, customizationContent = CreateTabContent()
    local aboutContainer, aboutContent = CreateTabContent()
    local iWRContainer, iWRContent = CreateTabContent()
    local iNIFContainer, iNIFContent = CreateTabContent()
    local iRCContainer, iRCContent = CreateTabContent()

    local tabContents = {
        generalContainer,
        timingContainer,
        indicatorsContainer,
        customizationContainer,
        aboutContainer,
        iWRContainer,
        iNIFContainer,
        iRCContainer,
    }

    -- ═══════════════════════════════════════════════════════════
    -- Tab Selection
    -- ═══════════════════════════════════════════════════════════
    local sidebarButtons = {}
    local activeIndex = 1

    local function ShowTab(index)
        activeIndex = index
        for i, content in ipairs(tabContents) do
            content:SetShown(i == index)
        end
        for i, btn in ipairs(sidebarButtons) do
            if i == index then
                btn.bg:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.22)
                btn.accent:Show()
                btn.text:SetFontObject(GameFontHighlight)
                btn.text:SetTextColor(1, 0.78, 0.24)
            else
                btn.bg:SetColorTexture(0.04, 0.035, 0.028, 0.72)
                btn.accent:Hide()
                btn.text:SetFontObject(GameFontNormal)
                btn.text:SetTextColor(0.82, 0.76, 0.66)
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════
    -- Build Sidebar Items
    -- ═══════════════════════════════════════════════════════════
    local sidebarItems = {
        { type = "header", label = Colors.iST .. "iSealTwist" },
        { type = "tab", label = L["TabGeneral"], index = 1 },
        { type = "tab", label = L["TabTiming"], index = 2 },
        { type = "tab", label = L["TabIndicators"], index = 3 },
        { type = "tab", label = L["TabCustomization"], index = 4 },
        { type = "tab", label = L["TabAbout"], index = 5 },
        { type = "header", label = Colors.iST .. L["SidebarOtherAddons"] },
        { type = "tab", label = L["TabIWRPromo"], index = 6 },
        { type = "tab", label = L["TabINIFPromo"], index = 7 },
        { type = "tab", label = L["TabIRCPromo"], index = 8 },
    }

    local sidebarY = -8
    for _, item in ipairs(sidebarItems) do
        if item.type == "header" then
            local headerText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            headerText:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, sidebarY)
            headerText:SetText(item.label)
            sidebarY = sidebarY - 18
        elseif item.type == "tab" then
            local tabIndex = item.index
            local btn = CreateFrame("Button", nil, sidebar)
            btn:SetSize(sidebarWidth - 12, 26)
            btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, sidebarY)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(btn)
            bg:SetColorTexture(0.04, 0.035, 0.028, 0.72)
            btn.bg = bg

            local accent = btn:CreateTexture(nil, "ARTWORK")
            accent:SetWidth(3)
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
            highlight:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.10)

            btn:SetScript("OnClick", function() ShowTab(tabIndex) end)

            sidebarButtons[tabIndex] = btn
            sidebarY = sidebarY - 26
        end
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab 1: General
    -- ═══════════════════════════════════════════════════════════
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

        -- These are the four seals which Twist of Light can turn into an Echo.
        local fromOptions = {
            "Seal of Command", "Seal of Righteousness", "Seal of Fury", "Seal of Justice",
        }
        local intoOptions, intoDropdown

        intoOptions = {}
        local seenNames = {}
        for _, name in pairs(iST.SEALS) do
            if not seenNames[name] then
                seenNames[name] = true
                table.insert(intoOptions, name)
            end
        end
        table.sort(intoOptions)

        local function SealOptionText(name)
            if iST.TWIST_OF_LIGHT_FROM_SEALS[name] then
                return "|cff46e36d" .. name .. "|r"
            end
            return "|cffffb347" .. name .. "|r"
        end

        local function SealIcon(name)
            local spellID = iST.SEAL_SPELL_IDS and iST.SEAL_SPELL_IDS[name]
            return spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or nil
        end

        local pairCard = CreateFrame("Frame", nil, generalContent, BACKDROP_TEMPLATE)
        pairCard:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        pairCard:SetPoint("TOPRIGHT", generalContent, "TOPRIGHT", -20, y)
        pairCard:SetHeight(146)
        if pairCard.SetBackdrop then
            pairCard:SetBackdrop({
                bgFile = "Interface\\BUTTONS\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            pairCard:SetBackdropColor(0.035, 0.030, 0.022, 0.96)
            pairCard:SetBackdropBorderColor(1, 0.59, 0.09, 0.45)
        end

        local fromLabel = pairCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fromLabel:SetPoint("TOP", pairCard, "TOPLEFT", 111, -12)
        fromLabel:SetText(L["TwistFromSeal"])

        local intoLabel = pairCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        intoLabel:SetPoint("TOP", pairCard, "TOPRIGHT", -111, -12)
        intoLabel:SetText(L["TwistIntoSeal"])

        local direction = pairCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        direction:SetPoint("CENTER", pairCard, "TOP", 0, -47)

        local function UpdateSealDirection()
            local bothWays = iST.TWIST_OF_LIGHT_FROM_SEALS[iSTSettings.twistFromSeal]
                and iST.TWIST_OF_LIGHT_FROM_SEALS[iSTSettings.twistIntoSeal]
            local color = bothWays and Colors.Green or Colors.iST
            direction:SetText(color .. (bothWays and "< -- >" or "-->") .. Colors.Reset)
        end

        local function SealDropdownText(option)
            local name = type(option) == "table" and option.value or option
            local texture = SealIcon(name)
            local icon = texture and ("|T" .. tostring(texture) .. ":16:16:0:0|t ") or ""
            return icon .. SealOptionText(name)
        end

        local function SealOptions(values)
            local options = {}
            for _, value in ipairs(values) do
                options[#options + 1] = { value = value, text = SealDropdownText(value) }
            end
            return options
        end

        local fromDropdown = CreateStyledDropdown(pairCard, 190,
            function() return SealOptions(fromOptions) end,
            function() return iSTSettings.twistFromSeal end,
            function(value)
                iSTSettings.twistFromSeal = value
                if iSTSettings.twistIntoSeal == value then
                    for _, replacement in ipairs(intoOptions or {}) do
                        if replacement ~= value then
                            iSTSettings.twistIntoSeal = replacement
                            break
                        end
                    end
                end
                if intoDropdown then intoDropdown:Refresh() end
                UpdateSealDirection()
                if iST.RequestTwistMacroRefresh then iST:RequestTwistMacroRefresh() end
            end,
            function(option) return option.text end)
        fromDropdown:SetPoint("TOPLEFT", pairCard, "TOPLEFT", 16, -32)

        intoDropdown = CreateStyledDropdown(pairCard, 190,
            function() return SealOptions(intoOptions) end,
            function() return iSTSettings.twistIntoSeal end,
            function(value)
                iSTSettings.twistIntoSeal = value
                UpdateSealDirection()
                if iST.RequestTwistMacroRefresh then iST:RequestTwistMacroRefresh() end
            end,
            function(option) return option.text end,
            function(option) return option.value == iSTSettings.twistFromSeal end)
        intoDropdown:SetPoint("TOPRIGHT", pairCard, "TOPRIGHT", -16, -32)
        UpdateSealDirection()

        local legend = pairCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        legend:SetPoint("BOTTOM", pairCard, "BOTTOM", 0, 44)
        legend:SetText("|cff46e36dBoth ways|r  -  can create an Echo when replaced    "
            .. "|cffffb347Into only|r  -  destination only")

        CreateSettingsButtonAt(pairCard, L["OpenMacros"], 130, 170, -110, OpenMacroWindow)

        y = y - pairCard:GetHeight() - 8

        local intoDesc = generalContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        intoDesc:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        intoDesc:SetWidth(450)
        intoDesc:SetJustifyH("LEFT")
        intoDesc:SetText(L["SealPairDesc"])
        y = y - intoDesc:GetStringHeight() - 10

        scrollChildren[1]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab 2: Timing
    -- ═══════════════════════════════════════════════════════════
    do
        local y = -10
        _, y = CreateSectionHeader(timingContent, L["SectionTimingGuides"], y)

        _, y = CreateSettingsCheckbox(timingContent, L["ShowLatency"], L["ShowLatencyDesc"], y,
            function() return iSTSettings.showLatency end,
            function(v) iSTSettings.showLatency = v end
        )

        scrollChildren[2]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab 3: Indicators
    -- ═══════════════════════════════════════════════════════════
    do
        local y = -10
        _, y = CreateSectionHeader(indicatorsContent, L["SectionBarInformation"], y)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowSealIcon"], L["ShowSealIconDesc"], y,
            function() return iSTSettings.showSealIcon end,
            function(v)
                iSTSettings.showSealIcon = v
                iST:UpdateSealDisplay()
            end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowWeaponSpeed"], L["ShowWeaponSpeedDesc"], y,
            function() return iSTSettings.showWeaponSpeed end,
            function(v) iSTSettings.showWeaponSpeed = v end
        )

        _, y = CreateSectionHeader(indicatorsContent, L["SectionTwistFeedback"], y)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowTwistSuccess"], L["ShowTwistSuccessDesc"], y,
            function() return iSTSettings.showTwistSuccess end,
            function(v) iSTSettings.showTwistSuccess = v end
        )

        scrollChildren[3]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab 4: Customization
    -- ═══════════════════════════════════════════════════════════
    do
        local y = -10
        local colorRefreshers = {}

        local function AddColorEditor(label, getFunc, onChange)
            local refresh
            y, refresh = CreateColorEditor(customizationContent, label, y, getFunc, onChange)
            table.insert(colorRefreshers, refresh)
        end

        _, y = CreateSectionHeader(customizationContent, L["SectionBarAppearance"], y)

        _, y = CreateCustomSlider(customizationContent, L["BarWidth"], y, 100, 500, 10,
            function() return iSTSettings.barWidth end,
            function(v)
                iSTSettings.barWidth = v
                if iST.BarFrame then iST.BarFrame:SetWidth(v) end
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

        _, y = CreateCustomSlider(customizationContent, L["TwistTextSize"], y, 8, 32, 1,
            function() return iSTSettings.twistTextSize end,
            function(v)
                iSTSettings.twistTextSize = v
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

        AddColorEditor(L["ColorTwistSuccess"],
            function() return iSTSettings.twistSuccessColor end, nil)

        AddColorEditor(L["ColorTwistWarning"],
            function() return iSTSettings.twistWarningColor end, nil)

        _, y = CreateSettingsButton(customizationContent, L["DefaultColors"], 140, y - 4, function()
            local colorKeys = {
                "barColor",
                "borderNormalColor",
                "twistSuccessColor",
                "twistWarningColor",
            }

            for _, key in ipairs(colorKeys) do
                local default = iST.SettingsDefault[key]
                local color = iSTSettings[key]
                color.r = default.r
                color.g = default.g
                color.b = default.b
                color.a = default.a
            end

            for _, refresh in ipairs(colorRefreshers) do
                refresh()
            end

            if iST.InvalidateBarState then iST:InvalidateBarState() end
        end)

        _, y = CreateSectionHeader(customizationContent, L["SectionPosition"], y)

        _, y = CreateSettingsCheckbox(customizationContent, L["LockBar"], L["LockBarDesc"], y,
            function() return iSTSettings.barLocked end,
            function(v) iSTSettings.barLocked = v end
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
        previewCard:SetHeight(72)
        previewCard:SetBackdrop(PANEL_BACKDROP)
        previewCard:SetBackdropColor(0.035, 0.030, 0.022, 0.96)
        previewCard:SetBackdropBorderColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.45)

        local previewDescription = previewCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        previewDescription:SetPoint("TOPLEFT", previewCard, "TOPLEFT", 12, -10)
        previewDescription:SetPoint("TOPRIGHT", previewCard, "TOPRIGHT", -12, -10)
        previewDescription:SetJustifyH("LEFT")
        previewDescription:SetText(L["PreviewSequenceDesc"])

        CreateSettingsButtonAt(previewCard, L["PreviewNormal"], 140, 12, -34, function()
            iST:StartTestMode()
        end, true)
        CreateSettingsButtonAt(previewCard, L["PreviewWarning"], 140, 159, -34, function()
            iST:StartWarningTestMode()
        end, true)
        CreateSettingsButtonAt(previewCard, L["PreviewSuccess"], 140, 306, -34, function()
            iST:StartTwistSuccessTestMode()
        end, true)
        y = y - previewCard:GetHeight() - 8

        scrollChildren[4]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- ═══════════════════════════════════════════════════════════
    -- ═══════════════════════════════════════════════════════════
    -- Tab 5: About
    -- ═══════════════════════════════════════════════════════════
    do
        local y = -15

        -- Icon
        local aboutIcon = aboutContent:CreateTexture(nil, "ARTWORK")
        aboutIcon:SetSize(64, 64)
        aboutIcon:SetPoint("TOP", aboutContent, "TOP", 0, y)
        aboutIcon:SetTexture(iconPath)
        y = y - 70

        -- Title
        local aboutTitle = aboutContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aboutTitle:SetPoint("TOP", aboutContent, "TOP", 0, y)
        aboutTitle:SetText(Colors.iST .. "iSealTwist" .. Colors.Reset .. " " .. Colors.Green .. "v" .. iST.Version .. Colors.Reset)
        y = y - 20

        -- Author
        local aboutAuthor = aboutContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        aboutAuthor:SetPoint("TOP", aboutContent, "TOP", 0, y)
        aboutAuthor:SetText(L["CreatedBy"] .. Colors.Cyan .. iST.Author .. Colors.Reset)
        y = y - 25

        -- Description
        local aboutDesc = aboutContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        aboutDesc:SetPoint("TOPLEFT", aboutContent, "TOPLEFT", 25, y)
        aboutDesc:SetWidth(370)
        aboutDesc:SetJustifyH("LEFT")
        aboutDesc:SetWordWrap(true)
        aboutDesc:SetText(L["AboutText"])
        y = y - aboutDesc:GetStringHeight() - 15

        -- CurseForge link
        _, y = CreateSectionHeader(aboutContent, Colors.iST .. "Links", y)

        local linkText
        linkText, y = CreateInfoText(aboutContent,
            L["ISTCurseForgeLink"],
            y, "GameFontDisableSmall")

        scrollChildren[5]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tabs 6-8: Other Addons (Installed + Promo dual frames)
    -- ═══════════════════════════════════════════════════════════
    local promoData = {
        { content = iWRContent, scrollIdx = 6, name = "iWillRemember", addonName = "iWillRemember", tabIdx = 6,
          tabLoaded = "iWillRemember", tabLabel = "iWillRemember",
          desc = L["IWRPromoDesc"], link = L["IWRPromoLink"],
          installedDesc = Colors.iST .. "iWillRemember" .. Colors.Reset .. " is installed. Open its settings to manage player notes and sync.",
          buttonText = "Open iWR Settings",
          tabLabel = L["TabIWR"], tabLabelPromo = L["TabIWRPromo"],
          getFrame = function() return _G.iWR and _G.iWR.SettingsFrame end },
        { content = iNIFContent, scrollIdx = 7, name = "iNeedIfYouNeed", addonName = "iNeedIfYouNeed", tabIdx = 7,
          desc = L["INIFPromoDesc"], link = L["INIFPromoLink"],
          installedDesc = Colors.iST .. "iNeedIfYouNeed" .. Colors.Reset .. " is installed. Open its settings to configure loot options.",
          buttonText = "Open iNIF Settings",
          tabLabel = L["TabINIF"], tabLabelPromo = L["TabINIFPromo"],
          getFrame = function() return _G["iNIFSettingsFrame"] end },
        { content = iRCContent, scrollIdx = 8, name = "iRC: Guild Connect", addonName = "iRC", tabIdx = 8,
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
        -- Installed frame
        local installedFrame = CreateFrame("Frame", nil, promo.content)
        installedFrame:SetAllPoints(promo.content)
        installedFrame:Hide()
        do
            local y = -10
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

        -- Promo frame
        local promoFrame = CreateFrame("Frame", nil, promo.content)
        promoFrame:SetAllPoints(promo.content)
        promoFrame:Hide()
        do
            local y = -10
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

    -- ═══════════════════════════════════════════════════════════
    -- OnShow: detect installed addons and toggle frames
    -- ═══════════════════════════════════════════════════════════
    settingsFrame:HookScript("OnShow", function()
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
    end)
    settingsFrame:HookScript("OnHide", function()
        if openDropdown and openDropdown.menu then openDropdown.menu:Hide() end
        openDropdown = nil
    end)

    -- ═══════════════════════════════════════════════════════════
    -- Show first tab
    -- ═══════════════════════════════════════════════════════════
    ShowTab(1)

    settingsFrame:Hide()
    self.SettingsFrame = settingsFrame
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                        Settings Toggle / Open / Close                          │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
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
