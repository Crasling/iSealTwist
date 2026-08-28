-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                         iSealTwist — Options Panel                             │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

local addonName, iST = ...
local L = iST.L or {}
local Colors = iST.Colors or {}
local print = function(...) iST:PrintToChat(...) end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local CHECKBOX_TEMPLATE = InterfaceOptionsCheckButtonTemplate and "InterfaceOptionsCheckButtonTemplate" or "UICheckButtonTemplate"
local iconPath = iST.AddonPath .. "Images\\Logo_iST.blp"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Helper Functions                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

local function CreateSectionHeader(parent, text, yOffset)
    local header = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    if header.SetBackdrop then
        header:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
        header:SetBackdropColor(0.15, 0.15, 0.2, 0.6)
    end

    local accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(1)
    accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    accent:SetColorTexture(1, 0.59, 0.09, 0.4)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", header, "LEFT", 8, 0)
    label:SetText(text)

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
    local TRACK_WIDTH = 300
    local TRACK_HEIGHT = 6
    local THUMB_SIZE = 14

    local sliderLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sliderLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    sliderLabel:SetText(label)

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
    local track = CreateFrame("Frame", nil, parent)
    track:SetSize(TRACK_WIDTH, TRACK_HEIGHT)
    track:SetPoint("TOPLEFT", parent, "TOPLEFT", 25, yOffset - 18)
    track:EnableMouse(true)

    -- Track background with rounded look
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.12, 0.12, 0.16, 0.9)

    -- Subtle top/bottom edges for depth
    local trackEdgeTop = track:CreateTexture(nil, "BACKGROUND", nil, 1)
    trackEdgeTop:SetHeight(1)
    trackEdgeTop:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    trackEdgeTop:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
    trackEdgeTop:SetColorTexture(0.08, 0.08, 0.1, 1)

    local trackEdgeBottom = track:CreateTexture(nil, "BACKGROUND", nil, 1)
    trackEdgeBottom:SetHeight(1)
    trackEdgeBottom:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    trackEdgeBottom:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)
    trackEdgeBottom:SetColorTexture(0.22, 0.22, 0.28, 0.6)

    -- Fill bar (orange, follows value)
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    fill:SetColorTexture(1, 0.59, 0.09, 0.6)

    -- Thumb (circular knob using the round minimap texture)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(THUMB_SIZE, THUMB_SIZE)
    thumb:EnableMouse(true)

    -- Outer circle (dark border)
    local thumbOuter = thumb:CreateTexture(nil, "OVERLAY", nil, 1)
    thumbOuter:SetSize(THUMB_SIZE, THUMB_SIZE)
    thumbOuter:SetPoint("CENTER")
    thumbOuter:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    thumbOuter:SetVertexColor(0.15, 0.15, 0.2, 1)

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

local function CreateSettingsButton(parent, text, width, yOffset, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 26)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn, yOffset - 34
end

local function CreateSettingsDropdown(parent, label, yOffset, width, getOptions, getValue, setValue)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    labelText:SetText(label)

    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset - 18)
    UIDropDownMenu_SetWidth(dropdown, width)

    local function RefreshText()
        local current = getValue()
        local display = L["None"] or "None"
        for _, option in ipairs(getOptions()) do
            if option.value == current then
                display = option.text
                break
            end
        end
        UIDropDownMenu_SetSelectedValue(dropdown, current)
        UIDropDownMenu_SetText(dropdown, display)
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(getOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.checked = option.value == getValue()
            info.func = function(button)
                setValue(button.value)
                RefreshText()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    RefreshText()
    return dropdown, yOffset - 58, RefreshText
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
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(350, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.59, 0.09, 0.12)

    local labelText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelText:SetPoint("LEFT", button, "LEFT", 4, 0)
    labelText:SetText(label)

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
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        settingsFrame:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
        settingsFrame:SetBackdropBorderColor(0.8, 0.8, 0.9, 1)
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
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        titleBar:SetBackdropColor(0.07, 0.07, 0.12, 1)
    end

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText(Colors.iST .. "iSealTwist" .. Colors.Green .. " v" .. iST.Version)

    -- Close button
    local closeButton = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", 0, 0)
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
        sidebar:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
        sidebar:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.6)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Content Area
    -- ═══════════════════════════════════════════════════════════
    local contentArea = CreateFrame("Frame", nil, settingsFrame, BACKDROP_TEMPLATE)
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
    contentArea:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -10, 10)
    if contentArea.SetBackdrop then
        contentArea:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        contentArea:SetBackdropBorderColor(0.6, 0.6, 0.7, 1)
        contentArea:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
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
    local soundContainer, soundContent = CreateTabContent()
    local aboutContainer, aboutContent = CreateTabContent()
    local iWRContainer, iWRContent = CreateTabContent()
    local iSPContainer, iSPContent = CreateTabContent()
    local iNIFContainer, iNIFContent = CreateTabContent()

    local tabContents = {
        generalContainer,
        timingContainer,
        indicatorsContainer,
        customizationContainer,
        soundContainer,
        aboutContainer,
        iWRContainer,
        iSPContainer,
        iNIFContainer,
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
                btn.bg:SetColorTexture(1, 0.59, 0.09, 0.25)
                btn.text:SetFontObject(GameFontHighlight)
            else
                btn.bg:SetColorTexture(0, 0, 0, 0)
                btn.text:SetFontObject(GameFontNormal)
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
        { type = "tab", label = L["TabSoundEffects"], index = 5 },
        { type = "tab", label = L["TabAbout"], index = 6 },
        { type = "header", label = Colors.iST .. L["SidebarOtherAddons"] },
        { type = "tab", label = L["TabIWRPromo"], index = 7 },
        { type = "tab", label = L["TabISPPromo"], index = 8 },
        { type = "tab", label = L["TabINIFPromo"], index = 9 },
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
            bg:SetColorTexture(0, 0, 0, 0)
            btn.bg = bg

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", btn, "LEFT", 14, 0)
            text:SetText(item.label)
            btn.text = text

            local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(btn)
            highlight:SetColorTexture(1, 1, 1, 0.08)

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

        _, y = CreateSettingsCheckbox(generalContent, L["OnlyInRetSpec"], L["OnlyInRetSpecDesc"], y,
            function() return iSTSettings.onlyInRetSpec end,
            function(v) iSTSettings.onlyInRetSpec = v iST:UpdateBarVisibility() end
        )

        _, y = CreateSettingsCheckbox(generalContent, L["OnlyInCombat"], L["OnlyInCombatDesc"], y,
            function() return iSTSettings.onlyInCombat end,
            function(v) iSTSettings.onlyInCombat = v iST:UpdateBarVisibility() end
        )

        _, y = CreateSectionHeader(generalContent, L["SectionSealPair"], y)

        -- Seal to Twist (restricted: SoC or SoR)
        local fromOptions = { "Seal of Command", "Seal of Righteousness" }

        local fromLabel = generalContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fromLabel:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        fromLabel:SetText(L["TwistFromSeal"])
        y = y - 20

        local fromDropdown = CreateFrame("Frame", "iSTFromSealDropdown", generalContent, "UIDropDownMenuTemplate")
        fromDropdown:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 10, y)
        UIDropDownMenu_SetWidth(fromDropdown, 200)
        UIDropDownMenu_Initialize(fromDropdown, function(self, level)
            for _, option in ipairs(fromOptions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option
                info.value = option
                info.func = function(btn)
                    UIDropDownMenu_SetSelectedValue(fromDropdown, btn.value)
                    UIDropDownMenu_SetText(fromDropdown, btn.value)
                    iSTSettings.twistFromSeal = btn.value
                    if iST.RefreshTwistMacro then iST:RefreshTwistMacro(false) end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        UIDropDownMenu_SetSelectedValue(fromDropdown, iSTSettings.twistFromSeal)
        UIDropDownMenu_SetText(fromDropdown, iSTSettings.twistFromSeal)
        y = y - 32

        local fromDesc = generalContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fromDesc:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        fromDesc:SetWidth(350)
        fromDesc:SetJustifyH("LEFT")
        fromDesc:SetText(L["TwistFromSealDesc"])
        y = y - fromDesc:GetStringHeight() - 10

        -- Seal to Twist Into (all seals)
        local intoOptions = {}
        local seenNames = {}
        for _, name in pairs(iST.SEALS) do
            if not seenNames[name] then
                seenNames[name] = true
                table.insert(intoOptions, name)
            end
        end
        table.sort(intoOptions)

        local intoLabel = generalContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        intoLabel:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        intoLabel:SetText(L["TwistIntoSeal"])
        y = y - 20

        local intoDropdown = CreateFrame("Frame", "iSTIntoSealDropdown", generalContent, "UIDropDownMenuTemplate")
        intoDropdown:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 10, y)
        UIDropDownMenu_SetWidth(intoDropdown, 200)
        UIDropDownMenu_Initialize(intoDropdown, function(self, level)
            for _, option in ipairs(intoOptions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option
                info.value = option
                info.func = function(btn)
                    UIDropDownMenu_SetSelectedValue(intoDropdown, btn.value)
                    UIDropDownMenu_SetText(intoDropdown, btn.value)
                    iSTSettings.twistIntoSeal = btn.value
                    if iST.RefreshTwistMacro then iST:RefreshTwistMacro(false) end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        UIDropDownMenu_SetSelectedValue(intoDropdown, iSTSettings.twistIntoSeal)
        UIDropDownMenu_SetText(intoDropdown, iSTSettings.twistIntoSeal)
        y = y - 32

        local intoDesc = generalContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        intoDesc:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, y)
        intoDesc:SetWidth(350)
        intoDesc:SetJustifyH("LEFT")
        intoDesc:SetText(L["TwistIntoSealDesc"])
        y = y - intoDesc:GetStringHeight() - 10

        scrollChildren[1]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab 2: Timing
    -- ═══════════════════════════════════════════════════════════
    do
        local y = -10
        _, y = CreateSectionHeader(timingContent, L["SectionTwistTiming"], y)

        _, y = CreateCustomSlider(timingContent, L["TwistWindow"], y, 200, 600, 10,
            function() return iSTSettings.twistWindow * 1000 end,
            function(v) iSTSettings.twistWindow = v / 1000 end,
            function(v) return v .. "ms" end
        )

        local twistDesc = timingContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        twistDesc:SetPoint("TOPLEFT", timingContent, "TOPLEFT", 25, y)
        twistDesc:SetWidth(350)
        twistDesc:SetText(L["TwistWindowDesc"])
        y = y - 16

        _, y = CreateSectionHeader(timingContent, L["SectionTimingGuides"], y)

        _, y = CreateSettingsCheckbox(timingContent, L["ShowGCDIndicator"], L["ShowGCDIndicatorDesc"], y,
            function() return iSTSettings.showGCDIndicator end,
            function(v) iSTSettings.showGCDIndicator = v end
        )

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

        _, y = CreateSectionHeader(indicatorsContent, L["SectionWarnings"], y)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowWrongSealWarning"], L["ShowWrongSealWarningDesc"], y,
            function() return iSTSettings.showWrongSealWarning end,
            function(v) iSTSettings.showWrongSealWarning = v end
        )

        _, y = CreateSectionHeader(indicatorsContent, L["SectionPulseIndicators"], y)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowGreenPulse"], L["ShowGreenPulseDesc"], y,
            function() return iSTSettings.showGreenPulse end,
            function(v) iSTSettings.showGreenPulse = v end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowOrangePulse"], L["ShowOrangePulseDesc"], y,
            function() return iSTSettings.showOrangePulse end,
            function(v) iSTSettings.showOrangePulse = v end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowRedPulse"], L["ShowRedPulseDesc"], y,
            function() return iSTSettings.showRedPulse end,
            function(v) iSTSettings.showRedPulse = v end
        )

        _, y = CreateSectionHeader(indicatorsContent, L["SectionTwistFeedback"], y)

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowTwistSuccess"], L["ShowTwistSuccessDesc"], y,
            function() return iSTSettings.showTwistSuccess end,
            function(v) iSTSettings.showTwistSuccess = v end
        )

        _, y = CreateSettingsCheckbox(indicatorsContent, L["ShowTwistFail"], L["ShowTwistFailDesc"], y,
            function() return iSTSettings.showTwistFail end,
            function(v) iSTSettings.showTwistFail = v end
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

        AddColorEditor(L["ColorTwistZone"],
            function() return iSTSettings.twistZoneColor end, nil)

        AddColorEditor(L["ColorAlert"],
            function() return iSTSettings.alertColor end, nil)

        AddColorEditor(L["ColorGCDZone"],
            function() return iSTSettings.gcdZoneColor end, nil)

        AddColorEditor(L["ColorTwistMarker"],
            function() return iSTSettings.twistMarkerColor end,
            function()
                if iST.BarFrame and iST.BarFrame.twistMarker then
                    local c = iSTSettings.twistMarkerColor
                    iST.BarFrame.twistMarker:SetVertexColor(c.r, c.g, c.b, c.a)
                end
            end)

        AddColorEditor(L["ColorGCDMarker"],
            function() return iSTSettings.gcdMarkerColor end, nil)

        AddColorEditor(L["ColorBorderNormal"],
            function() return iSTSettings.borderNormalColor end, nil)

        AddColorEditor(L["ColorTwistSuccess"],
            function() return iSTSettings.twistSuccessColor end, nil)

        AddColorEditor(L["ColorTwistFail"],
            function() return iSTSettings.twistFailColor end, nil)

        _, y = CreateSettingsButton(customizationContent, L["DefaultColors"], 140, y - 4, function()
            local colorKeys = {
                "barColor",
                "twistZoneColor",
                "alertColor",
                "gcdZoneColor",
                "twistMarkerColor",
                "gcdMarkerColor",
                "borderNormalColor",
                "twistSuccessColor",
                "twistFailColor",
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

        _, y = CreateSettingsButton(customizationContent, L["ResetPosition"], 130, y, function()
            iST:ResetBarPosition()
        end)

        _, y = CreateSettingsButton(customizationContent, L["TestBar"], 130, y, function()
            iST:StartTestMode()
        end)

        scrollChildren[4]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab 5: Sound Effects
    -- ═══════════════════════════════════════════════════════════
    do
        local y = -10
        _, y = CreateSectionHeader(soundContent, L["SectionSoundEffects"], y)
        _, y = CreateInfoText(soundContent, L["SoundEffectsWIP"], y, "GameFontNormalSmall")
        _, y = CreateInfoText(soundContent, L["SoundEffectsIntro"], y, "GameFontHighlight")
        y = y - 6

        _, y = CreateSettingsCheckbox(soundContent, L["EnableSoundEffects"], L["EnableSoundEffectsDesc"], y,
            function() return iSTSettings.enableSoundEffects end,
            function(v) iSTSettings.enableSoundEffects = v end
        )

        local function GetSoundOptions()
            local options = { { value = "", text = L["None"] } }
            local seen = { [""] = true }

            for _, sound in ipairs(iST.BUILTIN_SOUNDS) do
                table.insert(options, { value = sound.value, text = "[WoW] " .. sound.label })
                seen[sound.value] = true
            end

            if iST:IsISPLoaded() then
                for _, soundName in ipairs(iSPSettings.SoundFiles or {}) do
                    if not seen[soundName] then
                        local displayName = soundName
                        if iSPSettings.SoundNames and iSPSettings.SoundNames[soundName] and iSPSettings.SoundNames[soundName] ~= "" then
                            displayName = iSPSettings.SoundNames[soundName]
                        end
                        table.insert(options, { value = soundName, text = "[iSP] " .. displayName })
                        seen[soundName] = true
                    end
                end
            end

            return options
        end

        local function AddSoundSelector(label, getValue, setValue)
            local rowY = y
            _, y = CreateSettingsDropdown(soundContent, label, y, 250, GetSoundOptions, getValue, setValue)

            local testButton = CreateFrame("Button", nil, soundContent, "UIPanelButtonTemplate")
            testButton:SetSize(70, 22)
            testButton:SetPoint("TOPLEFT", soundContent, "TOPLEFT", 330, rowY - 20)
            testButton:SetText(L["TestSound"])
            testButton:SetScript("OnClick", function()
                iST:PlayConfiguredSound(getValue())
            end)
        end

        AddSoundSelector(L["TwistSuccessSound"],
            function() return iSTSettings.twistSuccessSound end,
            function(value) iSTSettings.twistSuccessSound = value end)

        AddSoundSelector(L["TwistFailSound"],
            function() return iSTSettings.twistFailSound end,
            function(value) iSTSettings.twistFailSound = value end)

        _, y = CreateCustomSlider(soundContent, L["WrongSealSoundLeadTime"], y, 0.2, 1.5, 0.1,
            function() return iSTSettings.wrongSealSoundLeadTime end,
            function(v) iSTSettings.wrongSealSoundLeadTime = v end,
            function(v) return string.format("%.1fs", v) end
        )

        AddSoundSelector(L["WrongSealWarningSound"],
            function() return iSTSettings.wrongSealWarningSound end,
            function(value) iSTSettings.wrongSealWarningSound = value end)

        y = y - 4
        if iST:IsISPLoaded() then
            _, y = CreateInfoText(soundContent, L["CustomSoundsAvailable"], y, "GameFontDisableSmall")
        else
            _, y = CreateInfoText(soundContent, L["CustomSoundsViaISP"], y, "GameFontDisableSmall")
        end

        scrollChildren[5]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tab 6: About
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

        scrollChildren[6]:SetHeight(math.abs(y) + 10)
    end

    -- ═══════════════════════════════════════════════════════════
    -- Tabs 7-9: Other Addons (Installed + Promo dual frames)
    -- ═══════════════════════════════════════════════════════════
    local promoData = {
        { content = iWRContent, scrollIdx = 7, name = "iWillRemember", addonName = "iWillRemember", tabIdx = 7,
          tabLoaded = "iWillRemember", tabLabel = "iWillRemember",
          desc = L["IWRPromoDesc"], link = L["IWRPromoLink"],
          installedDesc = Colors.iST .. "iWillRemember" .. Colors.Reset .. " is installed. Open its settings to manage player notes and sync.",
          buttonText = "Open iWR Settings",
          tabLabel = L["TabIWR"], tabLabelPromo = L["TabIWRPromo"],
          getFrame = function() return _G.iWR and _G.iWR.SettingsFrame end },
        { content = iSPContent, scrollIdx = 8, name = "iSoundPlayer", addonName = "iSoundPlayer", tabIdx = 8,
          desc = L["ISPPromoDesc"], link = L["ISPPromoLink"],
          installedDesc = Colors.iST .. "iSoundPlayer" .. Colors.Reset .. " is installed. Open its settings to configure sounds and triggers.",
          buttonText = "Open iSP Settings",
          tabLabel = L["TabISP"], tabLabelPromo = L["TabISPPromo"],
          getFrame = function() return _G["iSPSettingsFrame"] end },
        { content = iNIFContent, scrollIdx = 9, name = "iNeedIfYouNeed", addonName = "iNeedIfYouNeed", tabIdx = 9,
          desc = L["INIFPromoDesc"], link = L["INIFPromoLink"],
          installedDesc = Colors.iST .. "iNeedIfYouNeed" .. Colors.Reset .. " is installed. Open its settings to configure loot options.",
          buttonText = "Open iNIF Settings",
          tabLabel = L["TabINIF"], tabLabelPromo = L["TabINIFPromo"],
          getFrame = function() return _G["iNIFSettingsFrame"] end },
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
            local openBtn = CreateFrame("Button", nil, installedFrame, "UIPanelButtonTemplate")
            openBtn:SetSize(180, 28)
            openBtn:SetPoint("TOPLEFT", installedFrame, "TOPLEFT", 25, y)
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
            local loaded = false
            if C_AddOns and C_AddOns.IsAddOnLoaded then
                loaded = C_AddOns.IsAddOnLoaded(promo.addonName)
            elseif IsAddOnLoaded then
                loaded = IsAddOnLoaded(promo.addonName)
            end
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
    local iSPFrame = _G["iSPSettingsFrame"]
    if iSPFrame and iSPFrame:IsShown() then iSPFrame:Hide() end
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
