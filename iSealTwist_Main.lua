-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                                                                │
-- │                              iSealTwist                                        │
-- │                    Seal Twist Helper for WoW Forever                           │
-- │                            by Crasling                                         │
-- │                                                                                │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                   Namespace                                    │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local addonName, iST = ...

local GetAddOnMetadata = C_AddOns.GetAddOnMetadata

local function GetLocalizedSpellName(spellID, fallback)
    local localizedName
    localizedName = C_Spell.GetSpellName(spellID)
    return localizedName or fallback
end

local Title = "iSealTwist"
local Version = GetAddOnMetadata(addonName, "Version")
local Author = "Crasling"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                  Libraries                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local LDBroker = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                 Localization                                   │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local L = iST.L or {}
local Colors = iST.Colors or {}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                Chat Output                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:PrintToChat(...)
    local msg = table.concat({tostringall(...)}, " ")
    if ChatFrame1 then ChatFrame1:AddMessage(msg) end
end

local print = function(...) iST:PrintToChat(...) end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                 Addon Metadata                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
iST.Title = Title
iST.Version = Version
iST.Author = Author
iST.AddonPath = "Interface\\AddOns\\iSealTwist\\"

-- Game version info
iST.GameVersion, iST.GameBuild, iST.GameBuildDate, iST.GameTocVersion = GetBuildInfo()
iST.GameVersionName = "Forever"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                  Constants                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
iST.CONSTANTS = {
    LATENCY_UPDATE_INTERVAL = 5,    -- seconds between latency polls
    BAR_UPDATE_RATE = 0.016,        -- ~60fps
    BAR_STALE_THRESHOLD = 0.5,      -- hide bar this long after expected swing
    SEAL_DURATION = 30,            -- Forever seals are tracked from successful casts
}

iST.FONT_CHOICES = {
    { value = "FRIZQT",   label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { value = "ARIALN",   label = "Arial Narrow",   path = "Fonts\\ARIALN.TTF" },
    { value = "MORPHEUS", label = "Morpheus",       path = "Fonts\\MORPHEUS.TTF" },
    { value = "SKURRI",   label = "Skurri",         path = "Fonts\\SKURRI.TTF" },
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                               Seal Spell IDs                                   │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
-- Forever Seal spell IDs used to identify successful player casts.
iST.SEALS = {
    -- Seal of Command (ranks)
    [20375] = "Seal of Command",
    [20915] = "Seal of Command",
    [20918] = "Seal of Command",
    [20919] = "Seal of Command",
    [20920] = "Seal of Command",
    -- Seal of Righteousness (ranks)
    [20154] = "Seal of Righteousness",
    [20287] = "Seal of Righteousness",
    [20288] = "Seal of Righteousness",
    [20289] = "Seal of Righteousness",
    [20290] = "Seal of Righteousness",
    [20291] = "Seal of Righteousness",
    [20292] = "Seal of Righteousness",
    [20293] = "Seal of Righteousness",
    -- Seal of Wisdom (ranks)
    [20166] = "Seal of Wisdom",
    [20356] = "Seal of Wisdom",
    [20357] = "Seal of Wisdom",
    [20358] = "Seal of Wisdom",
    -- Seal of Light (ranks)
    [20165] = "Seal of Light",
    [20347] = "Seal of Light",
    [20348] = "Seal of Light",
    [20349] = "Seal of Light",
    [20350] = "Seal of Light",
    -- Seal of Justice
    [20164] = "Seal of Justice",
    -- Seal of Fury (Forever ranks)
    [20418] = "Seal of Fury",
    [20419] = "Seal of Fury",
    [20420] = "Seal of Fury",
    [20421] = "Seal of Fury",
    [20422] = "Seal of Fury",
    [20423] = "Seal of Fury",
    -- Seal of the Crusader (ranks)
    [21082] = "Seal of the Crusader",
    [20162] = "Seal of the Crusader",
    [20305] = "Seal of the Crusader",
    [20306] = "Seal of the Crusader",
    [20307] = "Seal of the Crusader",
    [20308] = "Seal of the Crusader",
}

-- Reverse lookup: name -> true (for name-based fallback matching)
iST.SEAL_NAMES = {}
-- Representative spell ID per seal name (lowest rank, used for localization).
iST.SEAL_SPELL_IDS = {}
for spellID, name in pairs(iST.SEALS) do
    iST.SEAL_NAMES[name] = true
    if not iST.SEAL_SPELL_IDS[name] or spellID < iST.SEAL_SPELL_IDS[name] then
        iST.SEAL_SPELL_IDS[name] = spellID
    end
end

-- Successful casts can teach the addon new beta spell IDs by localized name.
iST.KNOWN_SEAL_NAMES = {
    ["Seal of Command"] = true,
    ["Seal of Righteousness"] = true,
    ["Seal of Wisdom"] = true,
    ["Seal of Light"] = true,
    ["Seal of Justice"] = true,
    ["Seal of Fury"] = true,
    ["Seal of the Crusader"] = true,
}

-- Twist of Light only creates an Echo when one of these four seals is
-- replaced. The replacement seal may be any different seal.
iST.TWIST_OF_LIGHT_FROM_SEALS = {
    ["Seal of Command"] = true,
    ["Seal of Righteousness"] = true,
    ["Seal of Fury"] = true,
    ["Seal of Justice"] = true,
}
iST.SEAL_NAME_ALIASES = {}
for knownSpellID, canonicalName in pairs(iST.SEALS) do
    local localizedName = GetLocalizedSpellName(knownSpellID)
    if localizedName then iST.SEAL_NAME_ALIASES[localizedName] = canonicalName end
end
for canonicalName in pairs(iST.KNOWN_SEAL_NAMES) do
    iST.SEAL_NAME_ALIASES[canonicalName] = canonicalName
end

function iST:ResolveSealCast(...)
    local fallbackSpellID, eventSpellName
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" then
            if self.SEALS[value] then return value, self.SEALS[value] end
            if not fallbackSpellID and value > 100 then fallbackSpellID = value end
        elseif type(value) == "string" and self.SEAL_NAME_ALIASES[value] then
            eventSpellName = self.SEAL_NAME_ALIASES[value]
        end
    end

    if fallbackSpellID then
        local spellName = GetLocalizedSpellName(fallbackSpellID)
        if spellName and self.SEAL_NAME_ALIASES[spellName] then
            eventSpellName = self.SEAL_NAME_ALIASES[spellName]
        end
    end

    if fallbackSpellID and eventSpellName then
        self.SEALS[fallbackSpellID] = eventSpellName
        self.SEAL_NAMES[eventSpellName] = true
        self.SEAL_SPELL_IDS[eventSpellName] = self.SEAL_SPELL_IDS[eventSpellName] or fallbackSpellID
        return fallbackSpellID, eventSpellName
    end
end

-- Spells that reset the swing timer (credits: https://github.com/IvanRL22)
-- Holy Strike and other special attacks do not reset the Forever swing timer.
iST.SWING_RESET_SPELLS = {
    -- Repentance
    [20066] = "Repentance",
    -- Holy Wrath
    [2812]  = "Holy Wrath", -- Rank 1
    [10318] = "Holy Wrath", -- Rank 2
    -- Hammer of Justice
    [853]   = "Hammer of Justice", -- Rank 1
    [5588]  = "Hammer of Justice", -- Rank 2
    [5589]  = "Hammer of Justice", -- Rank 3
    [10308] = "Hammer of Justice", -- Rank 4
    -- Hammer of Wrath
    [24275] = "Hammer of Wrath", -- Rank 1
    [24274] = "Hammer of Wrath", -- Rank 2
    [24239] = "Hammer of Wrath", -- Rank 3
    -- Holy Light
    [635]   = "Holy Light", -- Rank 1
    [639]   = "Holy Light", -- Rank 2
    [647]   = "Holy Light", -- Rank 3
    [1026]  = "Holy Light", -- Rank 4
    [1042]  = "Holy Light", -- Rank 5
    [3472]  = "Holy Light", -- Rank 6
    [10328] = "Holy Light", -- Rank 7
    [10329] = "Holy Light", -- Rank 8
    [25292] = "Holy Light", -- Rank 9
    -- Flash of Light
    [19750] = "Flash of Light", -- Rank 1
    [19939] = "Flash of Light", -- Rank 2
    [19940] = "Flash of Light", -- Rank 3
    [19941] = "Flash of Light", -- Rank 4
    [19942] = "Flash of Light", -- Rank 5
    [19943] = "Flash of Light", -- Rank 6
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                 Runtime State                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
iST.State = {
    InCombat = false,
    LastSwingTime = 0,
    WeaponSpeed = 0,
    NextSwingTime = 0,
    SwingCycleActive = false,
    CurrentSealID = nil,
    CurrentSealName = nil,
    CurrentSealIcon = nil,
    HomeLag = 0,
    BarVisible = false,
    TestMode = false,
    Initialized = false,
    PreviousSealID = nil,
    PreviousSealName = nil,
    TwistResultStart = 0,
    TwistResultDuration = 0,
    Idle = false,
    PendingMacroRefresh = false,
    SealCastTime = 0,
    SealExpiresAt = 0,
    SealGeneration = 0,
    TwistOfLightKnown = nil,
    EchoPending = false,
    EchoSealName = nil,
    SealAtLastSwing = nil,
    TwistSucceededThisSwing = false,
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Settings Defaults                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
iST.SettingsDefault = {
    enabled = true,
    barWidth = 250,
    barHeight = 25,
    sealIconSize = 25,
    barLocked = false,
    showLatency = true,
    showSealIcon = true,
    showWeaponSpeed = true,
    onlyInCombat = true,
    onlyAsPaladin = true,
    barPoint = { "CENTER", nil, "CENTER", 0, -200 },
    showTwistSuccess = true,
    twistTextSize     = 16,
    sealTextSize      = 10,
    latencyTextSize   = 9,
    barFont           = "FRIZQT",
    twistSuccessColor = { r = 0.2, g = 1.0, b = 0.2, a = 1.0 },
    barColor          = { r = 1,    g = 0.59, b = 0.09, a = 0.9 },
    borderNormalColor = { r = 0.3,  g = 0.3,  b = 0.3,  a = 0.8 },
    twistFromSeal     = "Seal of Command",
    twistIntoSeal     = "Seal of Justice",
    MinimapButton = { hide = false, minimapPos = 220 },
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                            Initialize Settings                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:InitializeSettings()
    if not iSTSettings then iSTSettings = {} end
    for key, value in pairs(self.SettingsDefault) do
        if iSTSettings[key] == nil then
            if type(value) == "table" then
                iSTSettings[key] = {}
                for k, v in pairs(value) do
                    iSTSettings[key][k] = v
                end
            else
                iSTSettings[key] = value
            end
        elseif type(value) == "table" and type(iSTSettings[key]) == "table" then
            -- Patch missing sub-keys into existing tables (e.g. adding 'a' to old color saves)
            for k, v in pairs(value) do
                if iSTSettings[key][k] == nil then
                    iSTSettings[key][k] = v
                end
            end
        end
    end
end

function iST:GetBarFontPath()
    local selected = iSTSettings and iSTSettings.barFont or self.SettingsDefault.barFont
    for _, font in ipairs(self.FONT_CHOICES) do
        if font.value == selected then
            return font.path
        end
    end
    return self.FONT_CHOICES[1].path
end

function iST:ApplyBarTypography()
    local bar = self.BarFrame
    if not bar then return end

    local fontPath = self:GetBarFontPath()
    local function ApplyFont(fontString, size, flags)
        if fontString then
            fontString:SetFont(fontPath, size, flags)
        end
    end

    local _, timeSize = bar.timeText:GetFont()
    local _, speedSize = bar.speedText:GetFont()
    ApplyFont(bar.timeText, timeSize or 11, "OUTLINE")
    ApplyFont(bar.speedText, speedSize or 11, "OUTLINE")
    ApplyFont(bar.latencyText, iSTSettings.latencyTextSize or 9, "OUTLINE")
    ApplyFont(bar.sealText, iSTSettings.sealTextSize or 10, "OUTLINE")
    ApplyFont(bar.twistResultText, iSTSettings.twistTextSize or 16, "THICKOUTLINE")
    bar.latencyText:SetScale(1)
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                             Create Swing Bar                                   │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:CreateSwingBar()
    if self.BarFrame then return end

    local barWidth = iSTSettings.barWidth
    local barHeight = iSTSettings.barHeight
    local CONTENT_INSET = 3

    -- Main bar frame
    local bar = CreateFrame("Frame", "iSealTwistBar", UIParent, "BackdropTemplate")
    bar:SetSize(barWidth, barHeight)
    bar.contentInset = CONTENT_INSET
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)

    -- Background
    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 9,
            insets = { left = CONTENT_INSET, right = CONTENT_INSET, top = CONTENT_INSET, bottom = CONTENT_INSET },
        })
        bar:SetBackdropColor(0.025, 0.025, 0.045, 0.94)
        bar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end

    -- Subtle inner highlight for a cleaner, more modern surface.
    local gloss = bar:CreateTexture(nil, "ARTWORK", nil, 6)
    gloss:SetPoint("TOPLEFT", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    gloss:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -CONTENT_INSET, -CONTENT_INSET)
    gloss:SetHeight(math.max(1, math.floor((barHeight - CONTENT_INSET * 2) * 0.35)))
    gloss:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    gloss:SetVertexColor(1, 1, 1, 0.055)
    bar.gloss = gloss

    -- Drag handlers
    bar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not iSTSettings.barLocked then
            self:StartMoving()
        end
    end)
    bar:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        iST:SaveBarPosition()
    end)

    -- Fill texture (progress bar)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", CONTENT_INSET, CONTENT_INSET)
    fill:SetWidth(1)
    fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local bc = iSTSettings.barColor
    fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    bar.fill = fill


    -- Circular seal icon (left of bar)
    local sealIconFrame = CreateFrame("Frame", nil, bar)
    sealIconFrame:SetPoint("RIGHT", bar, "LEFT", -7, 0)
    sealIconFrame:Hide()

    local sealIconShadow = sealIconFrame:CreateTexture(nil, "BACKGROUND")
    sealIconShadow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    sealIconShadow:SetPoint("CENTER", sealIconFrame, "CENTER", 1, -1)
    sealIconShadow:SetVertexColor(0, 0, 0, 0.75)

    local sealIconRing = sealIconFrame:CreateTexture(nil, "BORDER")
    sealIconRing:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    sealIconRing:SetPoint("CENTER", sealIconFrame, "CENTER")
    sealIconRing:SetVertexColor(1, 0.59, 0.09, 0.95)

    local sealIcon = sealIconFrame:CreateTexture(nil, "ARTWORK")
    sealIcon:SetPoint("CENTER", sealIconFrame, "CENTER")
    sealIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local sealIconMask
    if sealIcon.AddMaskTexture and sealIconFrame.CreateMaskTexture then
        sealIconMask = sealIconFrame:CreateMaskTexture()
        sealIconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        sealIconMask:SetAllPoints(sealIcon)
        sealIcon:AddMaskTexture(sealIconMask)
    end

    function bar:UpdateModernDimensions(height)
        local iconSize = math.max(16, iSTSettings.sealIconSize or height)
        sealIconFrame:SetSize(iconSize + 6, iconSize + 6)
        sealIconShadow:SetSize(iconSize + 8, iconSize + 8)
        sealIconRing:SetSize(iconSize + 6, iconSize + 6)
        sealIcon:SetSize(iconSize, iconSize)
        gloss:SetHeight(math.max(1, math.floor((height - CONTENT_INSET * 2) * 0.35)))
    end

    bar:UpdateModernDimensions(barHeight)
    bar.sealIconFrame = sealIconFrame
    bar.sealIcon = sealIcon
    bar.sealIconMask = sealIconMask

    -- Time remaining text (right side)
    local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    timeText:SetText("")
    timeText:SetTextColor(1, 1, 1, 1)
    bar.timeText = timeText

    -- Weapon speed text (left side)
    local speedText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    speedText:SetPoint("LEFT", bar, "LEFT", 6, 0)
    speedText:SetText("")
    speedText:SetTextColor(0.8, 0.8, 0.8, 0.7)
    bar.speedText = speedText

    -- Latency text (bottom-right, small)
    local latencyText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    latencyText:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -2, -2)
    latencyText:SetText("")
    latencyText:SetTextColor(0.5, 0.5, 0.5, 0.8)
    bar.latencyText = latencyText

    -- Seal name text (below bar, center)
    local sealText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sealText:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    sealText:SetText("")
    sealText:SetTextColor(1, 0.59, 0.09, 0.9)
    bar.sealText = sealText

    -- Keep Echo confirmation above the bar so it never covers the swing timer.
    local resultOverlay = CreateFrame("Frame", nil, bar)
    resultOverlay:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 8)
    resultOverlay:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 8)
    resultOverlay:SetHeight(24)
    resultOverlay:SetFrameLevel(bar:GetFrameLevel() + 5)
    resultOverlay:EnableMouse(false)
    resultOverlay:Hide()
    bar.resultOverlay = resultOverlay

    local twistResultText = resultOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    twistResultText:SetPoint("CENTER", resultOverlay, "CENTER", 0, 0)
    twistResultText:SetText("")
    twistResultText:SetAlpha(0)
    twistResultText:SetShadowOffset(1, -1)
    twistResultText:SetShadowColor(0, 0, 0, 1)
    bar.twistResultText = twistResultText

    -- OnUpdate handler for animation
    bar.updateAccum = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        iST:OnBarUpdate(elapsed)
    end)

    bar:Hide() -- Start hidden
    self.BarFrame = bar
    self:ApplyBarTypography()
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Bar Position                                      │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:SaveBarPosition()
    if not self.BarFrame then return end
    local point, _, relativePoint, xOfs, yOfs = self.BarFrame:GetPoint()
    iSTSettings.barPoint = { point, nil, relativePoint, xOfs, yOfs }
end

function iST:RestoreBarPosition()
    if not self.BarFrame then return end
    local p = iSTSettings.barPoint
    if p and p[1] then
        self.BarFrame:ClearAllPoints()
        self.BarFrame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    end
end

function iST:ResetBarPosition()
    iSTSettings.barPoint = { "CENTER", nil, "CENTER", 0, -200 }
    self:RestoreBarPosition()
    print(L["BarReset"])
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                            Bar Update (OnUpdate)                               │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:OnBarUpdate(elapsed)
    local bar = self.BarFrame
    if not bar then return end

    bar.updateAccum = bar.updateAccum + elapsed
    if bar.updateAccum < self.CONSTANTS.BAR_UPDATE_RATE then return end
    bar.updateAccum = 0

    local state, now = self.State, GetTime()
    if state.TestMode and now >= state.NextSwingTime then
        self:ResetSwingTimer(3.6, true)
    end

    local noSwing = state.NextSwingTime <= 0 or state.WeaponSpeed <= 0
    local stale = not noSwing and not state.TestMode
        and now > state.NextSwingTime + self.CONSTANTS.BAR_STALE_THRESHOLD
    if noSwing or stale then
        if stale then state.SwingCycleActive = false end
        if not state.Idle then
            state.Idle = true
            self:UpdateBarVisibility()
            local inset = bar.contentInset or 1
            bar.fill:SetWidth(math.max(1, bar:GetWidth() - inset * 2))
            local color = iSTSettings.barColor
            bar.fill:SetVertexColor(color.r, color.g, color.b, 0.18)
            bar.timeText:SetText("")
            bar.speedText:Hide()
            bar.latencyText:SetShown(iSTSettings.showLatency)
        end
    else
        state.Idle = false
        local inset = bar.contentInset or 1
        local width = bar:GetWidth() - inset * 2
        local progress = math.max(0, math.min((now - state.LastSwingTime) / state.WeaponSpeed, 1))
        -- A new melee cycle begins red. A valid Twist of Light seal
        -- replacement during that cycle turns both the fill and border green.
        local r, g, b, a, borderR, borderG, borderB, borderA
        if state.TwistSucceededThisSwing then
            r, g, b, a = 0.18, 0.9, 0.28, 0.95
            borderR, borderG, borderB, borderA = 0.12, 0.75, 0.2, 1
        else
            r, g, b, a = 0.95, 0.18, 0.18, 0.9
            borderR, borderG, borderB, borderA = 0.75, 0.1, 0.1, 1
        end
        bar.fill:SetWidth(math.max(1, progress * width))
        bar.fill:SetVertexColor(r, g, b, a)
        if bar.SetBackdropBorderColor then
            bar:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
        end
        bar.timeText:SetText(string.format("%.1fs", math.max(0, state.NextSwingTime - now)))
        if iSTSettings.showWeaponSpeed then
            bar.speedText:SetText(string.format("%.2f", state.WeaponSpeed))
            bar.speedText:Show()
        else
            bar.speedText:Hide()
        end
        if iSTSettings.showLatency then
            bar.latencyText:SetText(state.HomeLag .. "ms")
            bar.latencyText:Show()
        else
            bar.latencyText:Hide()
        end
    end

    if bar.twistResultText and state.TwistResultDuration > 0 then
        local resultElapsed = now - state.TwistResultStart
        if resultElapsed < state.TwistResultDuration then
            bar.twistResultText:SetAlpha(1.0 - resultElapsed / state.TwistResultDuration)
        else
            bar.twistResultText:SetAlpha(0)
            bar.twistResultText:SetText("")
            bar.twistResultText:Hide()
            if bar.resultOverlay then bar.resultOverlay:Hide() end
            state.TwistResultDuration = 0
        end
    end
end

function iST:HideBar()
    if self.BarFrame then
        self.BarFrame:Hide()
        self.State.BarVisible = false
    end
end

function iST:ShowBar()
    if self.BarFrame then
        self.BarFrame:Show()
        self.State.BarVisible = true
    end
end


-- Central visibility decision: respects enabled, class, spec, and combat settings.
function iST:UpdateBarVisibility()
    if not self.BarFrame then return end
    if not iSTSettings.enabled then self:HideBar() return end
    if iSTSettings.onlyAsPaladin then
        local _, playerClass = UnitClass("player")
        if playerClass ~= "PALADIN" then
            self:HideBar()
            return
        end
    end
    if iSTSettings.onlyInCombat and not self.State.InCombat and not self.State.TestMode then
        self:HideBar()
        return
    end
    self:ShowBar()
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                          Twist Result Display                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:ShowTwistResult()
    if not self.BarFrame or not self.BarFrame.twistResultText then return end

    -- Check settings
    if not iSTSettings.showTwistSuccess then return end

    local text = self.BarFrame.twistResultText
    local state = self.State

    if self.BarFrame.resultOverlay then
        self.BarFrame.resultOverlay:Show()
    end
    text:Show()

    -- Apply configured size
    local fontPath = text:GetFont()
    text:SetFont(fontPath, iSTSettings.twistTextSize or 16, "THICKOUTLINE")

    text:SetText("Seal Twisted!")
    local c = iSTSettings.twistSuccessColor
    text:SetTextColor(c.r, c.g, c.b, c.a)

    -- Duration: min(1s, 50% of weapon speed)
    local fadeTime = math.min(1.0, state.WeaponSpeed > 0 and state.WeaponSpeed * 0.5 or 1.0)
    state.TwistResultStart = GetTime()
    state.TwistResultDuration = fadeTime
    text:SetAlpha(1)
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Swing Timer Logic                                    │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:ResetSwingTimer(swingDuration, isMeleeAttack)
    if issecretvalue and issecretvalue(swingDuration) then swingDuration = nil end
    local speed = type(swingDuration) == "number" and swingDuration or UnitAttackSpeed("player")
    if issecretvalue and issecretvalue(speed) then return end
    if not speed or speed <= 0 then return end

    if isMeleeAttack then
        -- Only a real melee attack consumes the Echo. Casts which merely reset
        -- the weapon timer must not be mistaken for an attack.
        self.State.EchoPending = false
        self.State.EchoSealName = nil
        self.State.SealAtLastSwing = self.State.CurrentSealName
        self.State.TwistSucceededThisSwing = false
        self.State.SwingCycleActive = true
    end
    self.State.Idle = false

    local now = GetTime()

    self.State.WeaponSpeed = speed
    self.State.LastSwingTime = now
    self.State.NextSwingTime = now + speed
    self:UpdateBarVisibility()
end

function iST:OnAttackSpeedChanged()
    local state = self.State
    if state.NextSwingTime <= 0 or state.WeaponSpeed <= 0 then return end

    local newSpeed = UnitAttackSpeed("player")
    if issecretvalue and issecretvalue(newSpeed) then return end
    if not newSpeed or newSpeed <= 0 then return end

    -- Preserve current progress fraction, recalculate with new speed
    local now = GetTime()
    local elapsed = now - state.LastSwingTime
    local fraction = elapsed / state.WeaponSpeed
    fraction = math.max(0, math.min(fraction, 1))

    state.WeaponSpeed = newSpeed
    state.LastSwingTime = now - (fraction * newSpeed)
    state.NextSwingTime = state.LastSwingTime + newSpeed
end

-- Force the next OnUpdate to re-apply idle visuals after a live setting change.
function iST:InvalidateBarState()
    self.State.Idle = false
    if self.BarFrame then
        self.BarFrame.updateAccum = self.CONSTANTS.BAR_UPDATE_RATE
    end
end


-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Seal Tracking                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:HasTwistOfLight()
    if self.State.TwistOfLightKnown ~= nil then return self.State.TwistOfLightKnown end

    local learned = IsPlayerSpell and IsPlayerSpell(105692) == true or false
    -- Discover the active Forever talent by spell name so beta data-ID changes
    -- do not break detection.
    if not learned and C_ClassTalents and C_ClassTalents.GetActiveConfigID
        and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes
        and C_Traits.GetNodeInfo and C_Traits.GetEntryInfo
        and C_Traits.GetDefinitionInfo then
        pcall(function()
            local configID = C_ClassTalents.GetActiveConfigID()
            local config = configID and C_Traits.GetConfigInfo(configID)
            for _, treeID in ipairs(config and config.treeIDs or {}) do
                for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                    local node = C_Traits.GetNodeInfo(configID, nodeID)
                    local activeRank = node and (node.activeRank or node.currentRank
                        or (type(node.activeEntry) == "table" and node.activeEntry.rank))
                    if node and (tonumber(activeRank) or 0) > 0 then
                        local activeEntries = node.activeEntry and { node.activeEntry } or node.activeEntries or {}
                        for _, activeEntry in ipairs(activeEntries) do
                            local entryID = type(activeEntry) == "table" and activeEntry.entryID or activeEntry
                            local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
                            local definition = entry and C_Traits.GetDefinitionInfo(entry.definitionID)
                            local spellID = definition and definition.spellID
                            local spellName = spellID and C_Spell and C_Spell.GetSpellName
                                and C_Spell.GetSpellName(spellID)
                            if spellName == "Twist of Light" then learned = true return end
                        end
                    end
                end
            end
        end)
    end

    self.State.TwistOfLightKnown = learned
    return learned
end

function iST:SetCurrentSeal(spellID, observedExpirationTime)
    local name = self.SEALS[spellID]
    if not name then return end

    local previousSealID = self.State.CurrentSealID or self.State.PreviousSealID
    local previousSealName = self.State.CurrentSealName or
                             self.State.PreviousSealName or
                             (previousSealID and self.SEALS[previousSealID])
    self.State.CurrentSealID = spellID
    self.State.PreviousSealID = nil -- clear once consumed
    self.State.PreviousSealName = nil
    self.State.CurrentSealName = name
    self.State.CurrentSealIcon = C_Spell.GetSpellTexture(spellID)
    self.State.SealCastTime = GetTime()
    local remaining = self.CONSTANTS.SEAL_DURATION
    if type(observedExpirationTime) == "number" and observedExpirationTime > self.State.SealCastTime then
        remaining = observedExpirationTime - self.State.SealCastTime
    end
    self.State.SealExpiresAt = self.State.SealCastTime + remaining
    self.State.SealGeneration = (self.State.SealGeneration or 0) + 1
    local sealGeneration = self.State.SealGeneration

    -- Forever does not expose readable aura state to addons. A successful seal
    -- cast is authoritative; expire only that exact cast if it is not replaced.
    C_Timer.After(remaining, function()
        if iST.State.SealGeneration == sealGeneration
            and iST.State.CurrentSealID == spellID then
            iST:ClearCurrentSeal()
        end
    end)

    local sealChanged = previousSealName and previousSealName ~= name

    -- Twist of Light is not timing based. Replacing an eligible seal at any
    -- point between two melee attacks creates an Echo for the next attack.
    if sealChanged and self.TWIST_OF_LIGHT_FROM_SEALS[previousSealName]
        and self:HasTwistOfLight() and self.State.SwingCycleActive then
        self.State.EchoPending = true
        self.State.EchoSealName = previousSealName
        self.State.TwistSucceededThisSwing = true
        self:ShowTwistResult()
    end

    self:UpdateSealDisplay()
end

function iST:ScanForActiveSealOutOfCombat()
    if (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then return end

    for spellID in pairs(self.SEALS) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if not ok then return end
        if aura ~= nil then
            local expirationTime
            local readable = pcall(function() expirationTime = aura.expirationTime end)
            if not readable then return end
            if issecretvalue and issecretvalue(expirationTime) then expirationTime = nil end
            self:SetCurrentSeal(spellID, expirationTime)
            return
        end
    end

    self:ClearCurrentSeal()
end

function iST:ClearCurrentSeal()
    -- Preserve previous seal ID so twist detection works across REMOVED→APPLIED gap
    if self.State.CurrentSealID then
        self.State.PreviousSealID = self.State.CurrentSealID
    end
    if self.State.CurrentSealName then
        self.State.PreviousSealName = self.State.CurrentSealName
    end
    self.State.CurrentSealID = nil
    self.State.CurrentSealName = nil
    self.State.CurrentSealIcon = nil
    self.State.SealCastTime = 0
    self.State.SealExpiresAt = 0
    self.State.SealGeneration = (self.State.SealGeneration or 0) + 1
    self:UpdateSealDisplay()
end

function iST:UpdateSealDisplay()
    if not self.BarFrame then return end
    local bar = self.BarFrame

    if self.State.CurrentSealIcon and iSTSettings.showSealIcon then
        bar.sealIcon:SetTexture(self.State.CurrentSealIcon)
        bar.sealIcon:Show()
        if bar.sealIconFrame then bar.sealIconFrame:Show() end
    else
        bar.sealIcon:Hide()
        if bar.sealIconFrame then bar.sealIconFrame:Hide() end
    end

    if self.State.CurrentSealName then
        bar.sealText:SetText(self.State.CurrentSealName)
    else
        bar.sealText:SetText("")
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                             Latency Polling                                    │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:UpdateLatency()
    local _, _, homeLag = GetNetStats()
    self.State.HomeLag = homeLag or 0

    -- Schedule next update
    C_Timer.After(iST.CONSTANTS.LATENCY_UPDATE_INTERVAL, function()
        iST:UpdateLatency()
    end)
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                            Minimap Button (LibDBIcon)                          │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:CreateMinimapButton()
    if not LDBroker or not LDBIcon then return end
    if self.MinimapDataObject then return end

    self.MinimapDataObject = LDBroker:NewDataObject("iSealTwist", {
        type = "data source",
        text = "iSealTwist",
        icon = "Interface\\AddOns\\iSealTwist\\Images\\Logo_iST",
        OnClick = function(_, button)
            if button == "LeftButton" and IsShiftKeyDown() then
                iSTSettings.barLocked = not iSTSettings.barLocked
                if iSTSettings.barLocked then
                    print(L["BarLocked"])
                else
                    print(L["BarUnlocked"])
                end
            elseif button == "LeftButton" then
                iSTSettings.enabled = not iSTSettings.enabled
                if iSTSettings.enabled then
                    print(L["BarEnabled"])
                else
                    print(L["BarDisabled"])
                end
                iST:UpdateBarVisibility()
            elseif button == "RightButton" then
                iST:SettingsToggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText(Colors.iST .. "iSealTwist" .. Colors.Green .. " v" .. iST.Version, 1, 1, 1)
            tooltip:AddLine(" ", 1, 1, 1)
            tooltip:AddLine(L["MinimapLeftClick"], 1, 1, 1)
            tooltip:AddLine(L["MinimapShiftLeftClick"], 1, 1, 1)
            tooltip:AddLine(L["MinimapRightClick"], 1, 1, 1)
            tooltip:Show()
        end,
    })

    if not iSTSettings.MinimapButton then
        iSTSettings.MinimapButton = { hide = false, minimapPos = 220 }
    end
    LDBIcon:Register("iSealTwist", self.MinimapDataObject, iSTSettings.MinimapButton)
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Auto-Create Twist Macro                              │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local TWIST_MACRO_NAME = "SealTwist"
local TWIST_MACRO_ICON = "INV_Hammer_04"

function iST:BuildTwistMacroBody(fromSeal, intoSeal)
    fromSeal = fromSeal or iSTSettings.twistFromSeal
    intoSeal = intoSeal or iSTSettings.twistIntoSeal
    if not fromSeal or fromSeal == "" or not intoSeal or intoSeal == "" then
        return nil
    end

    local fromSpellID = self.SEAL_SPELL_IDS[fromSeal]
    local intoSpellID = self.SEAL_SPELL_IDS[intoSeal]
    local localizedFrom = fromSpellID and GetLocalizedSpellName(fromSpellID, fromSeal) or fromSeal
    local localizedInto = intoSpellID and GetLocalizedSpellName(intoSpellID, intoSeal) or intoSeal

    return "#showtooltip\n/castsequence reset=30 " .. localizedFrom .. ", " .. localizedInto .. "\n/startattack"
end

local function NormalizeMacroBody(body)
    if type(body) ~= "string" then return nil end
    return body:gsub("\r\n", "\n"):gsub("%s+$", "")
end

-- Update only the exact macro body created by this Forever version. User edits
-- and unrelated macros with the same name are never overwritten.
function iST:RefreshTwistMacro()
    if not iSTSettings then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local macroIndex = GetMacroIndexByName(TWIST_MACRO_NAME)
    if not macroIndex or macroIndex == 0 then return false end

    local _, icon, currentBody = GetMacroInfo(macroIndex)
    local managedBody = iSTSettings.generatedMacroBody
    local isManaged = managedBody
        and NormalizeMacroBody(currentBody) == NormalizeMacroBody(managedBody)
    if not isManaged then return false end

    local desiredBody = self:BuildTwistMacroBody()
    if not desiredBody then return false end

    local macroUpdated = false
    if currentBody ~= desiredBody then
        local ok, err = pcall(EditMacro, macroIndex, TWIST_MACRO_NAME, icon or TWIST_MACRO_ICON, desiredBody)
        if not ok then
            print(L["PrintPrefix"] .. Colors.Red .. "Failed to update macro " .. TWIST_MACRO_NAME .. ": " .. tostring(err) .. Colors.Reset)
            return false
        end

        -- EditMacro may fail without throwing on some clients. Only store the
        -- new ownership body after the game confirms the edit was applied.
        local _, _, updatedBody = GetMacroInfo(macroIndex)
        if NormalizeMacroBody(updatedBody) ~= NormalizeMacroBody(desiredBody) then
            print(L["PrintPrefix"] .. Colors.Red .. "Failed to update macro " .. TWIST_MACRO_NAME .. "." .. Colors.Reset)
            return false
        end
        macroUpdated = true
    end

    iSTSettings.generatedMacroBody = desiredBody
    iSTSettings.macroCreated = true

    if macroUpdated then
        local fromSeal = iSTSettings.twistFromSeal
        local intoSeal = iSTSettings.twistIntoSeal
        local fromSpellID = self.SEAL_SPELL_IDS[fromSeal]
        local intoSpellID = self.SEAL_SPELL_IDS[intoSeal]
        local displayFrom = fromSpellID and GetLocalizedSpellName(fromSpellID, fromSeal) or fromSeal
        local displayInto = intoSpellID and GetLocalizedSpellName(intoSpellID, intoSeal) or intoSeal
        print(L["PrintPrefix"] .. Colors.iST .. string.format(
            L["MacroUpdated"],
            Colors.Yellow .. displayFrom .. Colors.iST,
            Colors.Yellow .. displayInto .. Colors.iST
        ) .. Colors.Reset)
    end

    return true
end

-- Apply seal-pair changes immediately when possible. Macro edits are protected
-- during combat, so remember the request and complete it after combat ends.
function iST:RequestTwistMacroRefresh()
    if InCombatLockdown and InCombatLockdown() then
        self.State.PendingMacroRefresh = true
        return false
    end

    self.State.PendingMacroRefresh = false
    return self:CreateTwistMacro()
end

function iST:CreateTwistMacro()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PALADIN" then return false end
    if InCombatLockdown and InCombatLockdown() then
        self.State.PendingMacroRefresh = true
        return false
    end

    local macroBody = self:BuildTwistMacroBody()
    if not macroBody then return false end

    -- Respect an existing user-created macro with the same name.
    local existingIndex = GetMacroIndexByName(TWIST_MACRO_NAME)
    if existingIndex and existingIndex > 0 then
        local _, _, existingBody = GetMacroInfo(existingIndex)
        if NormalizeMacroBody(existingBody) == NormalizeMacroBody(macroBody) then
            iSTSettings.macroCreated = true
            iSTSettings.generatedMacroBody = existingBody
            return true
        end

        -- A body previously written by iST remains safe to update. Any other
        -- same-named macro belongs to the player and must not be overwritten.
        if iSTSettings.generatedMacroBody
            and NormalizeMacroBody(existingBody) == NormalizeMacroBody(iSTSettings.generatedMacroBody) then
            return self:RefreshTwistMacro()
        end
        print(L["PrintPrefix"] .. Colors.Red .. "A macro named " .. TWIST_MACRO_NAME
            .. " already exists and was not changed." .. Colors.Reset)
        return false
    end

    -- The saved flag may outlive a deleted macro. Missing macros are recreated.
    iSTSettings.macroCreated = nil
    iSTSettings.generatedMacroBody = nil

    local numGlobal, numPerChar = GetNumMacros()
    local macroConstants = Constants and Constants.MacroConsts
    local globalLimit = MAX_ACCOUNT_MACROS or (macroConstants and macroConstants.MAX_ACCOUNT_MACROS) or 120
    local characterLimit = MAX_CHARACTER_MACROS or (macroConstants and macroConstants.MAX_CHARACTER_MACROS) or 18
    local perCharacter = false

    if numGlobal >= globalLimit then
        if numPerChar >= characterLimit then
            print(L["PrintPrefix"] .. Colors.Red .. "No macro slots available for " .. TWIST_MACRO_NAME .. "." .. Colors.Reset)
            return false
        end
        perCharacter = true
    end

    local ok, result = pcall(CreateMacro, TWIST_MACRO_NAME, TWIST_MACRO_ICON, macroBody, perCharacter)
    if not ok then
        print(L["PrintPrefix"] .. Colors.Red .. "Failed to create macro " .. TWIST_MACRO_NAME .. ": " .. tostring(result) .. Colors.Reset)
        return false
    end

    local createdIndex = type(result) == "number" and result or GetMacroIndexByName(TWIST_MACRO_NAME)
    if not createdIndex or createdIndex == 0 then
        print(L["PrintPrefix"] .. Colors.Red .. "Failed to create macro " .. TWIST_MACRO_NAME .. "." .. Colors.Reset)
        return false
    end

    local _, _, createdBody = GetMacroInfo(createdIndex)
    if NormalizeMacroBody(createdBody) ~= NormalizeMacroBody(macroBody) then
        print(L["PrintPrefix"] .. Colors.Red .. "The created macro could not be verified." .. Colors.Reset)
        return false
    end

    iSTSettings.macroCreated = true
    iSTSettings.generatedMacroBody = createdBody
    self.State.PendingMacroRefresh = false
    local scope = perCharacter and "character macro" or "macro"
    print(L["PrintPrefix"] .. Colors.Green .. "Created " .. scope .. ": "
        .. Colors.Yellow .. TWIST_MACRO_NAME .. Colors.Reset)
    return true
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Test Mode                                         │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:StartTestMode()
    self.State.TestMode = true
    self.State.WeaponSpeed = 3.6
    self.State.LastSwingTime = GetTime()
    self.State.NextSwingTime = GetTime() + 3.6
    self:ShowBar()
    print(L["TestStarted"])

    -- Auto-stop test after 30 seconds
    C_Timer.After(30, function()
        if self.State.TestMode then
            self.State.TestMode = false
            if not self.State.InCombat then
                self:UpdateBarVisibility()
            end
        end
    end)
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                             Slash Commands                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:RegisterSlashCommands()
    SLASH_ISEALTWIST1 = "/ist"
    SLASH_ISEALTWIST2 = "/isealtwist"
    SlashCmdList["ISEALTWIST"] = function(msg)
        local cmd = msg and msg:lower():trim() or ""

        if cmd == "settings" or cmd == "options" or cmd == "config" then
            iST:SettingsToggle()
        elseif cmd == "lock" then
            iSTSettings.barLocked = not iSTSettings.barLocked
            if iSTSettings.barLocked then
                print(L["BarLocked"])
            else
                print(L["BarUnlocked"])
            end
        elseif cmd == "reset" then
            iST:ResetBarPosition()
        elseif cmd == "test" then
            iST:StartTestMode()
        else
            -- Show help
            print(L["SlashHelp1"])
            print(L["SlashHelp2"])
            print(L["SlashHelp3"])
            print(L["SlashHelp4"])
            print(L["SlashHelp5"])
        end
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                             Event Handling                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            iST:OnAddonLoaded()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        iST:OnPlayerLogin()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Macro creation must happen after UI is fully loaded, with a delay
        if iST.State.EnteringWorldHandled then return end
        iST.State.EnteringWorldHandled = true
        C_Timer.After(3, function()
            if not InCombatLockdown() then
                iST:CreateTwistMacro()
            else
                -- PLAYER_REGEN_ENABLED is registered during initial loading;
                -- let that safe event path perform the protected update.
                iST.State.PendingMacroRefresh = true
            end
        end)
        return
    end

    if event == "PLAYER_SWING" then
        local swingDuration, swingType = ...
        if swingType == nil or swingType == Enum.PlayerSwingType.MainHand then
            iST:ResetSwingTimer(swingDuration, true)
        end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        iST.State.InCombat = true
        iST.State.TestMode = false

        -- Immediately update visibility when entering combat
        iST:UpdateBarVisibility()

        -- Close settings in combat
        if iST.SettingsFrame and iST.SettingsFrame:IsShown() then
            iST.SettingsFrame:Hide()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        iST.State.InCombat = false
        iST.State.SwingCycleActive = false
        iST.State.EchoPending = false
        iST.State.EchoSealName = nil
        iST.State.TwistSucceededThisSwing = false
        iST:UpdateBarVisibility()
        iST:ScanForActiveSealOutOfCombat()
        if iST.State.PendingMacroRefresh then
            iST:RequestTwistMacroRefresh()
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then iST:ScanForActiveSealOutOfCombat() end
        return
    end

    if event == "UNIT_ATTACK_SPEED" then
        local unit = ...
        if unit == "player" then
            iST:OnAttackSpeedChanged()
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "player" then
            -- A successful seal cast is a deterministic transition source on
            -- clients where aura updates arrive in an unexpected order.
            local sealSpellID = iST:ResolveSealCast(...)
            if sealSpellID then iST:SetCurrentSeal(sealSpellID) end

            -- The standard payload places spellID third. Keep a guarded scan
            -- because Forever beta payloads have changed between builds.
            local resetSpellID = type(spellID) == "number" and spellID or nil
            if not (resetSpellID and iST.SWING_RESET_SPELLS[resetSpellID]) then
                for index = 1, select("#", ...) do
                    local value = select(index, ...)
                    if type(value) == "number" and iST.SWING_RESET_SPELLS[value] then
                        resetSpellID = value
                        break
                    end
                end
            end
            if resetSpellID and iST.SWING_RESET_SPELLS[resetSpellID] then
                iST:ResetSwingTimer(nil, false)
            end
        end
        return
    end

    if event == "PLAYER_TALENT_UPDATE" then
        iST.State.TwistOfLightKnown = nil
        iST:HasTwistOfLight()
        iST:UpdateBarVisibility()
        return
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
for _, eventName in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SWING",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "UNIT_AURA",
    "UNIT_ATTACK_SPEED",
    "UNIT_SPELLCAST_SUCCEEDED",
    "PLAYER_TALENT_UPDATE",
}) do
    if C_EventUtils.IsEventValid(eventName) then
        eventFrame:RegisterEvent(eventName)
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Addon Loaded Handler                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:OnAddonLoaded()
    -- Initialize saved settings
    self:InitializeSettings()

    if iSTSettings.twistIntoSeal == iSTSettings.twistFromSeal then
        iSTSettings.twistIntoSeal = iSTSettings.twistFromSeal == "Seal of Justice"
            and "Seal of Righteousness" or "Seal of Justice"
    end

    -- Class gate
    local _, playerClass = UnitClass("player")
    -- Always create minimap button (for settings access on any class)
    self:CreateMinimapButton()

    if iSTSettings.onlyAsPaladin and playerClass ~= "PALADIN" then
        C_Timer.After(2, function()
            print(L["NotPaladin"])
        end)
    end

    -- Create the swing timer bar
    self:CreateSwingBar()
    self:RestoreBarPosition()

    -- Apply initial visibility.
    self:UpdateBarVisibility()

    -- Start latency polling
    self:UpdateLatency()

    -- Aura details are readable here only when combat restrictions are absent.
    self:ScanForActiveSealOutOfCombat()

    -- Register slash commands
    self:RegisterSlashCommands()

    self.State.Initialized = true
end

function iST:OnPlayerLogin()
    -- Create options panel (deferred to login so all frames exist)
    if self.CreateOptionsPanel and self.State.Initialized then
        self:CreateOptionsPanel()
    end

    -- Refresh visibility after the player UI has settled.
    C_Timer.After(1, function()
        if iST.State.Initialized then
            iST.State.TwistOfLightKnown = nil
            iST:HasTwistOfLight()
            iST:ScanForActiveSealOutOfCombat()
            iST:UpdateBarVisibility()
        end
    end)

    -- Login message
    C_Timer.After(2, function()
        print(string.format(L["AddonLoaded"], iST.Version))
    end)
end
