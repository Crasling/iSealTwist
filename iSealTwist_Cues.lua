local _, iST = ...
local L = iST.L or {}

local function CopyColor(color)
    return { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
end

-- Each palette runs from no stacks to three stacks.
local COLOR_SCHEMES = {
    GOLD = {
        { r = 0.50, g = 0.45, b = 0.34, a = 1 },
        { r = 1, g = 0.52, b = 0.12, a = 1 },
        { r = 1, g = 0.68, b = 0.17, a = 1 },
        { r = 1, g = 0.78, b = 0.24, a = 1 },
    },
    TRAFFIC = {
        { r = 0.95, g = 0.18, b = 0.18, a = 1 },
        { r = 1, g = 0.45, b = 0.10, a = 1 },
        { r = 1, g = 0.85, b = 0.15, a = 1 },
        { r = 0.20, g = 1, b = 0.30, a = 1 },
    },
    BLUE = {
        { r = 0.35, g = 0.40, b = 0.52, a = 1 },
        { r = 0.25, g = 0.50, b = 0.90, a = 1 },
        { r = 0.20, g = 0.75, b = 1, a = 1 },
        { r = 0.40, g = 1, b = 0.90, a = 1 },
    },
}

function iST:InitializeWrathColors(legacyColor)
    if not COLOR_SCHEMES[iSTSettings.wrathColorScheme] and iSTSettings.wrathColorScheme ~= "CUSTOM" then
        iSTSettings.wrathColorScheme = "GOLD"
    end
    for stage = 0, 3 do
        local key = "wrathColor" .. stage
        local color = iSTSettings[key]
        if type(color) ~= "table" or type(color.r) ~= "number"
            or type(color.g) ~= "number" or type(color.b) ~= "number" then
            color = self.SettingsDefault[key]
        end
        iSTSettings[key] = CopyColor(color)
    end
    -- Older settings had one cue color. Keep a custom choice for every stage,
    -- but let the old default gold use the new palette.
    if type(legacyColor) == "table" and type(legacyColor.r) == "number"
        and type(legacyColor.g) == "number" and type(legacyColor.b) == "number"
        and (legacyColor.r ~= 1 or legacyColor.g ~= 0.78 or legacyColor.b ~= 0.24
            or (legacyColor.a or 1) ~= 1) then
        for stage = 0, 3 do iSTSettings["wrathColor" .. stage] = CopyColor(legacyColor) end
        iSTSettings.wrathColorScheme = "CUSTOM"
    end
end

function iST:GetWrathCueColor(stage)
    stage = math.max(0, math.min(3, math.floor(tonumber(stage) or 0)))
    local scheme = COLOR_SCHEMES[iSTSettings.wrathColorScheme]
    return scheme and scheme[stage + 1] or iSTSettings["wrathColor" .. stage]
end

function iST:SetWrathColorScheme(scheme)
    if not COLOR_SCHEMES[scheme] and scheme ~= "CUSTOM" then return end
    iSTSettings.wrathColorScheme = scheme
    self:UpdateWrathDisplay()
end

function iST:SetWrathStageColor(stage, color)
    if type(stage) ~= "number" or stage < 0 or stage > 3 or stage ~= math.floor(stage) then return end
    -- Editing one preset color should leave the other three looking the same.
    if iSTSettings.wrathColorScheme ~= "CUSTOM" then
        for index = 0, 3 do
            iSTSettings["wrathColor" .. index] = CopyColor(self:GetWrathCueColor(index))
        end
        iSTSettings.wrathColorScheme = "CUSTOM"
    end
    iSTSettings["wrathColor" .. stage] = CopyColor(color)
    self:UpdateWrathDisplay()
end

function iST:ResetWrathColors()
    for stage = 0, 3 do
        local key = "wrathColor" .. stage
        iSTSettings[key] = CopyColor(self.SettingsDefault[key])
    end
    self:SetWrathColorScheme("GOLD")
end

-- Three blade sections surround the existing timer. The first section also
-- lights the grip and guard; the last section completes the sword tip.
local function CreateSwordStroke(frame, section)
    local glow = frame:CreateLine(nil, "OVERLAY", nil, 1)
    glow:SetThickness(7)
    local edge = frame:CreateLine(nil, "OVERLAY", nil, 2)
    edge:SetThickness(2)
    local stroke = { glow = glow, edge = edge, section = section }
    frame.strokes[#frame.strokes + 1] = stroke
    return stroke
end

local function PositionStroke(stroke, frame, x1, y1, x2, y2)
    stroke.glow:SetStartPoint("BOTTOMLEFT", frame, x1, y1)
    stroke.glow:SetEndPoint("BOTTOMLEFT", frame, x2, y2)
    stroke.edge:SetStartPoint("BOTTOMLEFT", frame, x1, y1)
    stroke.edge:SetEndPoint("BOTTOMLEFT", frame, x2, y2)
end

local function LayoutSword(bar)
    local sword = bar.wrathSword
    local width, height = bar:GetWidth(), bar:GetHeight()
    -- Only move the lines when the bar is resized.
    if sword.width == width and sword.height == height then return end
    sword.width, sword.height = width, height

    local middle, top, bottom = height * 0.5, height + 2, -2
    local bladeEnd = math.max(4, width - 3)
    local third = bladeEnd / 3
    for section = 1, 3 do
        local startX = (section - 1) * third
        local endX = section * third
        PositionStroke(sword.bladeTop[section], sword, startX, top, endX, top)
        PositionStroke(sword.bladeBottom[section], sword, startX, bottom, endX, bottom)
    end
    PositionStroke(sword.tipTop, sword, bladeEnd, top, width + 13, middle)
    PositionStroke(sword.tipBottom, sword, width + 13, middle, bladeEnd, bottom)

    PositionStroke(sword.guard, sword, -4, bottom - 4, -4, top + 4)
    PositionStroke(sword.guardTop, sword, -8, top + 4, 0, top + 4)
    PositionStroke(sword.guardBottom, sword, -8, bottom - 4, 0, bottom - 4)
    PositionStroke(sword.gripTop, sword, -25, middle + 3, -7, middle + 3)
    PositionStroke(sword.gripBottom, sword, -25, middle - 3, -7, middle - 3)
    PositionStroke(sword.pommel, sword, -25, middle - 4, -25, middle + 4)
    for index, wrap in ipairs(sword.gripWraps) do
        local x = -22 + (index - 1) * 4
        PositionStroke(wrap, sword, x, middle - 3, x + 2, middle + 3)
    end

    bar.wrathCueFrame:SetWidth(math.max(100, width))
end

function iST:CreateWrathCue(bar)
    if bar.wrathSword then return end

    local sword = CreateFrame("Frame", nil, bar)
    sword:SetAllPoints(bar)
    sword:SetFrameLevel(bar:GetFrameLevel() + 2)
    sword:EnableMouse(false)
    sword.strokes, sword.bladeTop, sword.bladeBottom = {}, {}, {}
    for section = 1, 3 do
        sword.bladeTop[section] = CreateSwordStroke(sword, section)
        sword.bladeBottom[section] = CreateSwordStroke(sword, section)
    end
    sword.tipTop = CreateSwordStroke(sword, 3)
    sword.tipBottom = CreateSwordStroke(sword, 3)
    sword.guard = CreateSwordStroke(sword, 1)
    sword.guardTop = CreateSwordStroke(sword, 1)
    sword.guardBottom = CreateSwordStroke(sword, 1)
    sword.gripTop = CreateSwordStroke(sword, 1)
    sword.gripBottom = CreateSwordStroke(sword, 1)
    sword.pommel = CreateSwordStroke(sword, 1)
    sword.gripWraps = {}
    for index = 1, 4 do sword.gripWraps[index] = CreateSwordStroke(sword, 1) end
    sword:Hide()
    bar.wrathSword = sword

    local cueFrame = CreateFrame("Frame", nil, bar)
    cueFrame:SetPoint("BOTTOM", bar, "TOP", 0, 9)
    cueFrame:SetHeight(24)
    cueFrame:SetFrameLevel(bar:GetFrameLevel() + 4)
    cueFrame:EnableMouse(false)
    cueFrame:Hide()
    bar.wrathCueFrame = cueFrame

    local text = cueFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", cueFrame, "CENTER")
    text:SetText("")
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    bar.wrathCueText = text
    self:CreateSwordImageCue(bar)
    bar.wrathCircles = self:CreateStackBubbles(bar, nil, 18, 9)
    bar.wrathCircles:SetPoint("BOTTOM", bar, "TOP", 0, 7)
    bar.wrathCircles:SetFrameLevel(bar:GetFrameLevel() + 4)
    self:CreatePlayerWrathFrame()
    LayoutSword(bar)
end

function iST:UpdateWrathDisplay(now)
    local bar = self.BarFrame
    if not bar or not bar.wrathSword then return end
    now = now or GetTime()
    -- Previews supply their own count; drawing the cue does not change live stacks.
    local count, active, armed = self:GetWrathDisplayState(now)
    count = math.max(0, math.min(3, math.floor(count or 0)))
    local style = iSTSettings.wrathCue or "SWORD"
    local swordVisible = active and style == "SWORD"
    local sword = bar.wrathSword
    local color = self:GetWrathCueColor(count)

    LayoutSword(bar)
    if swordVisible then
        local pulse = count == 3 and (0.24 + math.sin(now * 4) * 0.07) or 0.19
        for _, stroke in ipairs(sword.strokes) do
            local filled = count >= stroke.section
            local brightness = filled and 1 or 0.28
            local alpha = (color.a or 1) * (filled and 1 or 0.55)
            stroke.edge:SetColorTexture(color.r * brightness, color.g * brightness,
                color.b * brightness, alpha)
            stroke.glow:SetColorTexture(color.r, color.g, color.b,
                filled and pulse * (color.a or 1) or 0)
        end
        sword:Show()
        if bar.SetBackdropBorderColor then bar:SetBackdropBorderColor(0, 0, 0, 0) end
    else
        sword:Hide()
        -- Other cue styles use the normal border unless the image sword replaces it below.
        local border = iSTSettings.borderNormalColor
        if bar.SetBackdropBorderColor then
            bar:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)
        end
    end

    local imagesVisible = active and style == "SWORD_IMAGES"
    self:UpdateSwordImageCue(bar, count, imagesVisible, color)
    -- Leave room for either sword's hilt, then restore the usual icon gap on other styles.
    local iconOffset = imagesVisible and -(bar.wrathSwordImages.leftOverhang + 7) or swordVisible and -37 or -7
    if bar.sealIconFrame and bar.wrathIconOffset ~= iconOffset then
        bar.sealIconFrame:ClearAllPoints()
        bar.sealIconFrame:SetPoint("RIGHT", bar, "LEFT", iconOffset, 0)
        bar.wrathIconOffset = iconOffset
    end

    local ready = iSTSettings.wrathReadyText or "Switch now"
    -- Once the replacement seal is active, the next attack releases the stored stacks.
    if armed and ready == "Switch now" then ready = L["WrathAttackNow"] end
    local cueText
    if active and style == "COUNTER" then
        cueText = string.format(L["WrathCounter"], count)
        if count == 3 then
            -- Keep the counter alone if the ready message would spill past the bar.
            local combined = string.format(L["WrathCounterReady"], count, ready)
            local fontSize = iSTSettings.twistTextSize or 16
            if #combined * fontSize * 0.58 <= math.max(100, bar:GetWidth()) then
                cueText = combined
            end
        end
    elseif active and style == "TEXT" and count == 3 then
        cueText = ready
    end

    -- Give the release message this space until its short display time is over.
    if cueText and (self.State.TwistResultDuration or 0) <= 0 then
        bar.wrathCueText:SetText(cueText)
        bar.wrathCueText:SetTextColor(color.r, color.g, color.b, color.a or 1)
        bar.wrathCueFrame:Show()
    else
        bar.wrathCueText:SetText("")
        bar.wrathCueFrame:Hide()
    end
    local circlesVisible = active and style == "CIRCLES" and (self.State.TwistResultDuration or 0) <= 0
    if circlesVisible then self:RenderStackBubbles(bar.wrathCircles, count, color) end
    bar.wrathCircles:SetShown(circlesVisible)
    self:UpdatePlayerWrathBubbles(now)
end
