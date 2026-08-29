-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                                                                │
-- │                              iSealTwist                                        │
-- │                        Seal Twist Helper for TBC                               │
-- │                            by Crasling                                         │
-- │                                                                                │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                   Namespace                                    │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local addonName, iST = ...

-- API compat for TBC Classic (C_AddOns may not exist)
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local GetAddOnInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
local IsAddOnLoadedAPI = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local function GetLocalizedSpellName(spellID, fallback)
    local localizedName
    if C_Spell and C_Spell.GetSpellName then
        localizedName = C_Spell.GetSpellName(spellID)
    end
    if not localizedName and GetSpellInfo then
        localizedName = GetSpellInfo(spellID)
    end
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
iST.GameVersionName = ""

-- Game version detection
local gameTocNumber = tonumber(iST.GameTocVersion) or 0
if gameTocNumber >= 20500 and gameTocNumber < 30000 then
    iST.GameVersionName = "Anniversary TBC"
    iST.SupportedVersion = true
else
    iST.SupportedVersion = false
    if gameTocNumber >= 120000 then
        iST.GameVersionName = "Retail WoW"
    elseif gameTocNumber > 50000 and gameTocNumber < 59999 then
        iST.GameVersionName = "Classic MoP"
    elseif gameTocNumber > 40000 and gameTocNumber < 49999 then
        iST.GameVersionName = "Classic Cata"
    elseif gameTocNumber > 30000 and gameTocNumber < 39999 then
        iST.GameVersionName = "Classic WotLK"
    elseif gameTocNumber >= 20000 and gameTocNumber < 20500 then
        iST.GameVersionName = "Classic TBC"
    elseif gameTocNumber > 10000 and gameTocNumber < 19999 then
        iST.GameVersionName = "Classic Era"
    else
        iST.GameVersionName = "Unknown Version"
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                  Constants                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
iST.CONSTANTS = {
    DEFAULT_TWIST_WINDOW = 0.400,   -- 400ms
    MIN_TWIST_WINDOW = 0.200,       -- 200ms
    MAX_TWIST_WINDOW = 0.600,       -- 600ms
    LATENCY_UPDATE_INTERVAL = 5,    -- seconds between latency polls
    BAR_UPDATE_RATE = 0.016,        -- ~60fps
    BAR_STALE_THRESHOLD = 0.5,      -- hide bar this long after expected swing
    GCD_DURATION = 1.5,            -- TBC GCD in seconds
}

iST.FONT_CHOICES = {
    { value = "FRIZQT",   label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { value = "ARIALN",   label = "Arial Narrow",   path = "Fonts\\ARIALN.TTF" },
    { value = "MORPHEUS", label = "Morpheus",       path = "Fonts\\MORPHEUS.TTF" },
    { value = "SKURRI",   label = "Skurri",         path = "Fonts\\SKURRI.TTF" },
}

iST.BUILTIN_SOUNDS = {
    { value = "wow:856",  label = "Soft Confirm" },
    { value = "wow:857",  label = "Soft Warning" },
    { value = "wow:3339", label = "Map Ping" },
    { value = "wow:8959", label = "Raid Warning" },
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                               Seal Spell IDs                                   │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
-- TBC Seal spellIDs — covers all ranks for UnitBuff matching
iST.SEALS = {
    -- Seal of Command (ranks)
    [20375] = "Seal of Command",
    [20915] = "Seal of Command",
    [20918] = "Seal of Command",
    [20919] = "Seal of Command",
    [20920] = "Seal of Command",
    [27170] = "Seal of Command",
    -- Seal of Blood (Horde)
    [31892] = "Seal of Blood",
    [38008] = "Seal of Blood",
    [41459] = "Seal of Blood",
    -- Seal of the Martyr (Alliance)
    [53720] = "Seal of the Martyr",
    [348700] = "Seal of the Martyr",
    -- Seal of Righteousness (ranks)
    [20154] = "Seal of Righteousness",
    [20287] = "Seal of Righteousness",
    [20288] = "Seal of Righteousness",
    [20289] = "Seal of Righteousness",
    [20290] = "Seal of Righteousness",
    [20291] = "Seal of Righteousness",
    [20292] = "Seal of Righteousness",
    [20293] = "Seal of Righteousness",
    [27155] = "Seal of Righteousness",
    -- Seal of Vengeance / Corruption
    [31801] = "Seal of Vengeance",
    [53736] = "Seal of Corruption",
    -- Seal of Wisdom (ranks)
    [20166] = "Seal of Wisdom",
    [20356] = "Seal of Wisdom",
    [27166] = "Seal of Wisdom",
    -- Seal of Light (ranks)
    [20165] = "Seal of Light",
    [20347] = "Seal of Light",
    [20348] = "Seal of Light",
    [20349] = "Seal of Light",
    [27160] = "Seal of Light",
    -- Seal of Justice
    [20164] = "Seal of Justice",
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

function iST:IsSealAvailableForPlayerFaction(sealName)
    local _, playerFaction = UnitFactionGroup("player")
    if playerFaction == "Alliance" then
        return sealName ~= "Seal of Blood" and sealName ~= "Seal of Corruption"
    end
    if playerFaction == "Horde" then
        return sealName ~= "Seal of the Martyr" and sealName ~= "Seal of Vengeance"
    end
    return true
end

function iST:GetFactionSealEquivalent(sealName)
    local _, playerFaction = UnitFactionGroup("player")
    if playerFaction == "Alliance" then
        if sealName == "Seal of Blood" then return "Seal of the Martyr" end
        if sealName == "Seal of Corruption" then return "Seal of Vengeance" end
    elseif playerFaction == "Horde" then
        if sealName == "Seal of the Martyr" then return "Seal of Blood" end
        if sealName == "Seal of Vengeance" then return "Seal of Corruption" end
    end
    return sealName
end

-- Spells that reset the swing timer (credits: https://github.com/IvanRL22)
-- NOTE: Crusader Strike (35395) does NOT reset the auto-attack swing timer in TBC —
-- it is a special attack on its own cooldown and must NOT be listed here.
iST.SWING_RESET_SPELLS = {
    -- Repentance
    [20066] = "Repentance",
    -- Holy Wrath
    [2812]  = "Holy Wrath", -- Rank 1
    [10318] = "Holy Wrath", -- Rank 2
    [27139] = "Holy Wrath", -- Rank 3
    -- Hammer of Justice
    [853]   = "Hammer of Justice", -- Rank 1
    [5588]  = "Hammer of Justice", -- Rank 2
    [5589]  = "Hammer of Justice", -- Rank 3
    [10308] = "Hammer of Justice", -- Rank 4
    -- Hammer of Wrath
    [24275] = "Hammer of Wrath", -- Rank 1
    [24274] = "Hammer of Wrath", -- Rank 2
    [24239] = "Hammer of Wrath", -- Rank 3
    [27180] = "Hammer of Wrath", -- Rank 4
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
    [27135] = "Holy Light", -- Rank 10
    [27136] = "Holy Light", -- Rank 11
    -- Flash of Light
    [19750] = "Flash of Light", -- Rank 1
    [19939] = "Flash of Light", -- Rank 2
    [19940] = "Flash of Light", -- Rank 3
    [19941] = "Flash of Light", -- Rank 4
    [19942] = "Flash of Light", -- Rank 5
    [19943] = "Flash of Light", -- Rank 6
    [27137] = "Flash of Light", -- Rank 7
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                 Runtime State                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
iST.State = {
    InCombat = false,
    LastSwingTime = 0,
    WeaponSpeed = 0,
    NextSwingTime = 0,
    CurrentSealID = nil,
    CurrentSealName = nil,
    CurrentSealIcon = nil,
    HomeLag = 0,
    BarVisible = false,
    TestMode = false,
    Initialized = false,
    InTwistZone = false,
    SealChangedInTwistZone = false,
    PendingSealChange = false,
    PreviousSealID = nil,
    PreviousSealName = nil,
    TwistResultStart = 0,
    TwistResultDuration = 0,
    GCDStartTime = 0,
    GCDEndTime = 0,
    GCDDuration = 1.5,
    Idle = false,
    WrongSealSoundPlayed = false,
    WrongSealSince = nil,
    PendingMacroRefresh = false,
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
    twistWindow = 0.400,
    showLatency = true,
    showSealIcon = true,
    showWeaponSpeed = true,
    onlyInCombat = true,
    onlyAsPaladin = true,
    onlyInRetSpec = false,
    barPoint = { "CENTER", nil, "CENTER", 0, -200 },
    showTwistSuccess = true,
    showTwistFail = true,
    twistTextSize     = 16,
    sealTextSize      = 10,
    latencyTextSize   = 9,
    barFont           = "FRIZQT",
    enableSoundEffects = false,
    twistSuccessSound = "wow:856",
    twistFailSound    = "wow:857",
    wrongSealWarningSound = "wow:3339",
    wrongSealSoundLeadTime = 0.5,
    twistSuccessColor = { r = 0.2, g = 1.0, b = 0.2, a = 1.0 },
    twistFailColor    = { r = 1.0, g = 0.2, b = 0.2, a = 1.0 },
    barColor          = { r = 1,    g = 0.59, b = 0.09, a = 0.9 },
    twistZoneColor    = { r = 0.2,  g = 1,    b = 0.2,  a = 0.7 },
    alertColor        = { r = 0.9,  g = 0.1,  b = 0.1,  a = 0.9 },
    gcdZoneColor      = { r = 0.55, g = 0.55, b = 0.55, a = 0.35 },
    twistMarkerColor  = { r = 1,    g = 1,    b = 0,    a = 0.9 },
    gcdMarkerColor    = { r = 1,    g = 0.85, b = 0.3,  a = 0.85 },
    borderNormalColor = { r = 0.3,  g = 0.3,  b = 0.3,  a = 0.8 },
    showGCDIndicator  = true,
    showWrongSealWarning = true,
    showGreenPulse    = true,   -- Seal1 + in twist window + GCD free  → green pulse
    showOrangePulse   = true,   -- Seal2 active (twist done)           → orange pulse
    showRedPulse      = true,   -- Seal1 + GCD runs past swing         → red pulse
    twistFromSeal     = "Seal of Command",  -- the seal you cast FROM (SoC or SoR)
    twistIntoSeal     = "",  -- the seal you twist INTO (faction-aware on first load)
    MinimapButton = { hide = false, minimapPos = 220 },
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                            Initialize Settings                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:InitializeSettings()
    if not iSTSettings then iSTSettings = {} end
    if iSTSettings.enableSoundEffects == nil and iSTSettings.enableISPSounds ~= nil then
        iSTSettings.enableSoundEffects = iSTSettings.enableISPSounds
    end
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
    local bar = CreateFrame("Frame", "iSealTwistBar", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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

    -- Twist zone overlay (semi-transparent green area from twist point to end)
    local twistZone = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    twistZone:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -CONTENT_INSET, -CONTENT_INSET)
    twistZone:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -CONTENT_INSET, CONTENT_INSET)
    twistZone:SetWidth(1)
    twistZone:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local tc = iSTSettings.twistZoneColor
    twistZone:SetVertexColor(tc.r, tc.g, tc.b, tc.a)
    bar.twistZone = twistZone

    -- Twist marker line (vertical line at twist point)
    local marker = bar:CreateTexture(nil, "OVERLAY")
    marker:SetWidth(2)
    marker:SetPoint("TOP", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    marker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", CONTENT_INSET, CONTENT_INSET)
    marker:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local tm = iSTSettings.twistMarkerColor
    marker:SetVertexColor(tm.r, tm.g, tm.b, tm.a)
    bar.twistMarker = marker

    -- Seal switch zone (amber block from GCD marker to twist window — the "cast twistFromSeal here" window)
    local sealSwitchZone = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    sealSwitchZone:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sealSwitchZone:SetVertexColor(1, 0.55, 0.0, 0.35)
    sealSwitchZone:SetPoint("TOPLEFT",    bar, "TOPLEFT",    CONTENT_INSET, -CONTENT_INSET)
    sealSwitchZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", CONTENT_INSET,  CONTENT_INSET)
    sealSwitchZone:SetWidth(1)
    sealSwitchZone:Hide()
    bar.sealSwitchZone = sealSwitchZone

    -- Continuous rounded alert halo. Keep it broad enough to remain clearly
    -- visible around the modern rounded bar at every supported bar height.
    local alertGlow = CreateFrame("Frame", nil, bar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    alertGlow:SetPoint("TOPLEFT", bar, "TOPLEFT", -7, 7)
    alertGlow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 7, -7)
    alertGlow:SetFrameLevel(bar:GetFrameLevel() + 4)
    if alertGlow.SetBackdrop then
        alertGlow:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 20,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        alertGlow:SetBackdropBorderColor(1, 0.1, 0.1, 0)
    end
    bar.alertGlow = alertGlow

    -- GCD active zone (gray block showing current GCD duration on bar)
    local gcdZone = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    gcdZone:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local gz = iSTSettings.gcdZoneColor
    gcdZone:SetVertexColor(gz.r, gz.g, gz.b, gz.a)
    gcdZone:SetPoint("TOPLEFT", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    gcdZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", CONTENT_INSET, CONTENT_INSET)
    gcdZone:SetWidth(1)
    gcdZone:Hide()
    bar.gcdZone = gcdZone

    -- GCD indicator line (vertical — marks where to press SoC)
    local gcdMarker = bar:CreateTexture(nil, "OVERLAY")
    gcdMarker:SetWidth(2)
    gcdMarker:SetPoint("TOP", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    gcdMarker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", CONTENT_INSET, CONTENT_INSET)
    gcdMarker:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local gm = iSTSettings.gcdMarkerColor
    gcdMarker:SetVertexColor(gm.r, gm.g, gm.b, gm.a)
    gcdMarker:Hide()
    bar.gcdMarker = gcdMarker

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

    -- Twist result text in a dedicated feedback row above the bar. Keeping this
    -- outside the timer content makes it readable without covering the swing,
    -- seal, GCD, or alert indicators.
    local resultOverlay = CreateFrame("Frame", nil, bar)
    resultOverlay:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 8)
    resultOverlay:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 8)
    resultOverlay:SetHeight(24)
    resultOverlay:SetFrameLevel(alertGlow:GetFrameLevel() + 1)
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
    if bar.updateAccum < iST.CONSTANTS.BAR_UPDATE_RATE then return end
    bar.updateAccum = 0

    local state = self.State
    local now = GetTime()

    -- Test mode: use simulated values
    if state.TestMode then
        if now >= state.NextSwingTime then
            -- Test swing "landed" — reset for another cycle
            state.LastSwingTime = now
            state.WeaponSpeed = 3.6
            state.NextSwingTime = now + 3.6
        end
    end

    -- Check if swing timer is active or stale
    local noSwing = (state.NextSwingTime <= 0 or state.WeaponSpeed <= 0)
    local stale   = (not noSwing) and (not state.TestMode) and
                    (now > state.NextSwingTime + iST.CONSTANTS.BAR_STALE_THRESHOLD)

    if noSwing or stale then
        -- The idle appearance and visibility only need updating when entering
        -- the idle state. Visibility changes are otherwise driven by events
        -- and settings callbacks.
        if state.Idle then
            return
        end
        state.Idle = true

        self:UpdateBarVisibility()

        -- Stop here if enabled/spec/combat settings require the bar to be hidden
        if not self.State.BarVisible then
            return
        end

        -- Idle state while waiting for the next valid swing
        local contentInset = bar.contentInset or 1
        local idleWidth = math.max(1, bar:GetWidth() - contentInset * 2)
        bar.fill:SetWidth(idleWidth)

        local bc = iSTSettings.barColor
        bar.fill:SetVertexColor(bc.r, bc.g, bc.b, 0.18)

        bar.twistZone:Hide()
        bar.twistMarker:Hide()

        if bar.gcdZone then
            bar.gcdZone:Hide()
        end

        if bar.gcdMarker then
            bar.gcdMarker:Hide()
        end

        if bar.sealSwitchZone then
            bar.sealSwitchZone:Hide()
        end

        if bar.alertGlow and bar.alertGlow.SetBackdropBorderColor then
            bar.alertGlow:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local borderColor = iSTSettings.borderNormalColor
        if bar.SetBackdropBorderColor then
            bar:SetBackdropBorderColor(
                borderColor.r,
                borderColor.g,
                borderColor.b,
                borderColor.a
            )
        end

        bar.timeText:SetText("")
        bar.speedText:Hide()
        bar.latencyText:SetShown(iSTSettings.showLatency)

        return
    end

    state.Idle = false

    local contentInset = bar.contentInset or 1
    local barWidth = bar:GetWidth() - contentInset * 2
    local progress = (now - state.LastSwingTime) / state.WeaponSpeed
    progress = math.max(0, math.min(progress, 1))

    -- Calculate twist point (fraction of bar where twist zone starts)
    local twistWindowSec = iSTSettings.twistWindow
    local lagCompensation = state.HomeLag * 0.002 -- double lag for round-trip, convert ms to sec
    local twistStart = 1.0 - (twistWindowSec + lagCompensation) / state.WeaponSpeed
    twistStart = math.max(0.1, math.min(twistStart, 0.95))

    -- Update fill width
    local fillWidth = math.max(1, progress * barWidth)
    bar.fill:SetWidth(fillWidth)

    -- Determine seal state for visual feedback
    local bc = iSTSettings.barColor
    local tc = iSTSettings.twistZoneColor
    local onFromSeal = (state.CurrentSealName == iSTSettings.twistFromSeal)
    local onIntoSeal = (state.CurrentSealName == iSTSettings.twistIntoSeal)
    local gcdFree = (state.GCDEndTime == 0 or state.GCDEndTime <= now)
    local gcdRunsPastSwing = (state.GCDEndTime > 0 and state.GCDEndTime >= state.NextSwingTime)
    local gcdDuration = state.GCDDuration or iST.CONSTANTS.GCD_DURATION
    local gcdStartFrac = twistStart - gcdDuration / state.WeaponSpeed

    -- Three pulsing states (mutually exclusive, priority order):
    -- ORANGE: Seal2 is active — twist completed, waiting for swing
    local orangeMode = iSTSettings.showOrangePulse and onIntoSeal
    -- GREEN:  Seal1 active + inside twist window + GCD free — cast Seal2 now!
    local greenMode  = iSTSettings.showGreenPulse and
                       (not orangeMode) and onFromSeal and (progress >= twistStart) and gcdFree
    -- RED: wrong seal, or Seal1 with a GCD that makes the twist impossible
    -- before the next swing lands.
    local hasWrongSeal = (not onFromSeal) and (not onIntoSeal)
    if hasWrongSeal then
        state.WrongSealSince = state.WrongSealSince or now
    else
        state.WrongSealSince = nil
    end
    local wrongSealMode = iSTSettings.showWrongSealWarning and hasWrongSeal
    local tooLateToTwist = (not orangeMode) and onFromSeal and gcdRunsPastSwing
    local missedWindowMode = iSTSettings.showRedPulse and tooLateToTwist
    local redMode = wrongSealMode or missedWindowMode

    local ac  = iSTSettings.alertColor
    local bnc = iSTSettings.borderNormalColor
    local pulse = math.sin(now * 6) * 0.35 + 0.65

    -- Fill color
    if redMode then
        local redAlpha = missedWindowMode and (ac.a * pulse) or ac.a
        bar.fill:SetVertexColor(ac.r, ac.g, ac.b, redAlpha)
    elseif greenMode then
        bar.fill:SetVertexColor(0.2, 1.0, 0.2, tc.a * pulse)
    elseif orangeMode then
        bar.fill:SetVertexColor(1.0, 0.55, 0.1, tc.a * pulse)
    elseif progress >= twistStart then
        bar.fill:SetVertexColor(tc.r, tc.g, tc.b, tc.a)
    else
        bar.fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    end

    -- Main border + softly pulsing rounded alert halo
    local glowAlpha = missedWindowMode and (0.82 + pulse * 0.18) or
                      (wrongSealMode and (0.76 + pulse * 0.22) or
                      ((greenMode or orangeMode) and (0.55 + pulse * 0.35) or 0))
    local gr, gg, gb
    if redMode then
        gr, gg, gb = ac.r, ac.g, ac.b
    elseif greenMode then
        gr, gg, gb = 0.2, 1.0, 0.2
    elseif orangeMode then
        gr, gg, gb = 1.0, 0.55, 0.1
    else
        gr, gg, gb = bnc.r, bnc.g, bnc.b
    end

    if bar.SetBackdropBorderColor then
        if redMode or greenMode or orangeMode then
            bar:SetBackdropBorderColor(gr, gg, gb, glowAlpha)
        elseif progress >= twistStart then
            bar:SetBackdropBorderColor(tc.r, tc.g, tc.b, 0.9)
        else
            bar:SetBackdropBorderColor(bnc.r, bnc.g, bnc.b, bnc.a)
        end
    end
    if bar.alertGlow and bar.alertGlow.SetBackdropBorderColor then
        local haloAlpha = (missedWindowMode and glowAlpha) or
                          (wrongSealMode and glowAlpha * 0.9) or
                          (greenMode and glowAlpha * 0.42) or
                          (orangeMode and glowAlpha * 0.36) or 0
        bar.alertGlow:SetBackdropBorderColor(gr, gg, gb, haloAlpha)
    end

    -- GCD zone color (update each frame in case settings changed)
    if bar.gcdZone then
        local gz = iSTSettings.gcdZoneColor
        bar.gcdZone:SetVertexColor(gz.r, gz.g, gz.b, gz.a)
    end

    -- Update twist zone overlay position
    local twistZoneWidth = math.max(1, (1.0 - twistStart) * barWidth)
    bar.twistZone:SetWidth(twistZoneWidth)

    -- Update twist marker line position + color
    local markerX = contentInset + (twistStart * barWidth)
    bar.twistMarker:ClearAllPoints()
    bar.twistMarker:SetPoint("TOP", bar, "TOPLEFT", markerX, -contentInset)
    bar.twistMarker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", markerX, contentInset)
    local tm = iSTSettings.twistMarkerColor
    bar.twistMarker:SetVertexColor(tm.r, tm.g, tm.b, tm.a)

    -- GCD active zone: gray block from GCD start to GCD end
    if bar.gcdZone then
        local gcdEnd = state.GCDEndTime
        if gcdEnd > now and state.WeaponSpeed > 0 then
            local startFrac = (state.GCDStartTime - state.LastSwingTime) / state.WeaponSpeed
            local endFrac   = (gcdEnd           - state.LastSwingTime) / state.WeaponSpeed
            startFrac = math.max(0, math.min(startFrac, 1))
            endFrac   = math.max(0, math.min(endFrac, 1))
            local zoneWidth = math.max(1, (endFrac - startFrac) * barWidth)
            local startX = contentInset + startFrac * barWidth
            bar.gcdZone:ClearAllPoints()
            bar.gcdZone:SetPoint("TOPLEFT",    bar, "TOPLEFT",    startX, -contentInset)
            bar.gcdZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", startX,  contentInset)
            bar.gcdZone:SetWidth(zoneWidth)
            bar.gcdZone:Show()
        else
            bar.gcdZone:Hide()
        end
    end

    -- GCD indicator: position one GCD before the twist window opens
    if bar.gcdMarker then
        if iSTSettings.showGCDIndicator and state.WeaponSpeed > 0 then
            local gcdStart = twistStart - gcdDuration / state.WeaponSpeed
            if gcdStart > 0.02 then
                local gcdX = contentInset + (gcdStart * barWidth)
                bar.gcdMarker:ClearAllPoints()
                bar.gcdMarker:SetPoint("TOP", bar, "TOPLEFT", gcdX, -contentInset)
                bar.gcdMarker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", gcdX, contentInset)
                local gmColor = iSTSettings.gcdMarkerColor
                bar.gcdMarker:SetVertexColor(gmColor.r, gmColor.g, gmColor.b, gmColor.a)
                bar.gcdMarker:Show()
            else
                bar.gcdMarker:Hide()
            end
        else
            bar.gcdMarker:Hide()
        end
    end

    -- Seal switch zone: amber block from GCD marker to twist window ("press twistFromSeal here")
    if bar.sealSwitchZone then
        if iSTSettings.showGCDIndicator and gcdStartFrac > 0.02 and gcdStartFrac < twistStart then
            local startX = contentInset + gcdStartFrac * barWidth
            local zoneW  = math.max(1, (twistStart - gcdStartFrac) * barWidth)
            bar.sealSwitchZone:ClearAllPoints()
            bar.sealSwitchZone:SetPoint("TOPLEFT",    bar, "TOPLEFT",    startX, -contentInset)
            bar.sealSwitchZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", startX,  contentInset)
            bar.sealSwitchZone:SetWidth(zoneW)
            bar.sealSwitchZone:Show()
        else
            bar.sealSwitchZone:Hide()
        end
    end

    -- Time remaining text
    local remaining = math.max(0, state.NextSwingTime - now)
    bar.timeText:SetText(string.format("%.1fs", remaining))

    -- Optional warning: fire once per swing when time is running out on a wrong seal.
    local warningSound = iSTSettings.wrongSealWarningSound
    local warningLeadTime = iSTSettings.wrongSealSoundLeadTime or 0.5
    if not state.TestMode and iSTSettings.enableSoundEffects and hasWrongSeal and
       not state.WrongSealSoundPlayed and warningSound and warningSound ~= "" and
       state.WrongSealSince and (now - state.WrongSealSince) >= 0.1 and
       remaining > 0 and remaining <= warningLeadTime then
        state.WrongSealSoundPlayed = true
        self:PlayConfiguredSound(warningSound)
    end

    -- Weapon speed text
    if iSTSettings.showWeaponSpeed then
        bar.speedText:SetText(string.format("%.2f", state.WeaponSpeed))
        bar.speedText:Show()
    else
        bar.speedText:Hide()
    end

    -- Latency text
    if iSTSettings.showLatency then
        bar.latencyText:SetText(state.HomeLag .. "ms")
        bar.latencyText:Show()
    else
        bar.latencyText:Hide()
    end

    -- Track twist zone state
    state.InTwistZone = (progress >= twistStart)

    -- Fade twist result text and fully hide its frame when finished.
    if bar.twistResultText and state.TwistResultDuration > 0 then
        local elapsed = now - state.TwistResultStart
        if elapsed < state.TwistResultDuration then
            local alpha = 1.0 - (elapsed / state.TwistResultDuration)
            bar.twistResultText:SetAlpha(alpha)
        else
            bar.twistResultText:SetAlpha(0)
            bar.twistResultText:SetText("")
            bar.twistResultText:Hide()
            if bar.resultOverlay then
                bar.resultOverlay:Hide()
            end
            state.TwistResultDuration = 0
        end
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Show / Hide Bar                                      │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:ShowBar()
    if self.BarFrame and iSTSettings.enabled then
        self.BarFrame:Show()
        self.State.BarVisible = true
    end
end

function iST:HideBar()
    if self.BarFrame then
        self.BarFrame:Hide()
        self.State.BarVisible = false
    end
end

-- Returns true when player has the most talent points in Retribution (tab 3).
-- Falls back to true when no talents are spent or talent data is unavailable.
function iST:IsRetSpec()
    if not GetNumTalentTabs or not GetTalentTabInfo then
        return true
    end

    local maxPoints = 0
    local maxTab = 0

    for tabIndex = 1, GetNumTalentTabs() do
        local _, _, thirdValue, _, fifthValue = GetTalentTabInfo(tabIndex)

        -- Older Classic clients return pointsSpent as the third value.
        -- TBC AE returns pointsSpent as the fifth value.
        local pointsSpent = 0

        if type(thirdValue) == "number" then
            pointsSpent = thirdValue
        elseif type(fifthValue) == "number" then
            pointsSpent = fifthValue
        end

        if pointsSpent > maxPoints then
            maxPoints = pointsSpent
            maxTab = tabIndex
        end
    end

    if maxPoints == 0 then
        return true
    end

    -- Paladin talent tab 3 is Retribution.
    return maxTab == 3
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
    if iSTSettings.onlyInRetSpec and not self:IsRetSpec() then
        self:HideBar()
        return
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
function iST:IsISPLoaded()
    return IsAddOnLoadedAPI and IsAddOnLoadedAPI("iSoundPlayer") and type(iSPSettings) == "table"
end

function iST:IsBuiltinSound(soundName)
    for _, sound in ipairs(self.BUILTIN_SOUNDS) do
        if sound.value == soundName then return true end
    end
    return false
end

function iST:PlayConfiguredSound(soundName)
    if not soundName or soundName == "" then return false end

    local soundKitID = soundName:match("^wow:(%d+)$")
    if soundKitID and self:IsBuiltinSound(soundName) then
        local ok, willPlay = pcall(PlaySound, tonumber(soundKitID), "Master")
        return ok and willPlay and true or false
    end

    if not self:IsISPLoaded() or iSPSettings.Enabled == false then return false end

    local registered = false
    for _, registeredSound in ipairs(iSPSettings.SoundFiles or {}) do
        if registeredSound == soundName then
            registered = true
            break
        end
    end
    if not registered then return false end

    local channel = iSPSettings.SoundChannel or "Master"
    if channel == "Dialog" then channel = "Master" end

    soundKitID = soundName:match("^wow:(%d+)$")
    if soundKitID then
        local ok, willPlay = pcall(PlaySound, tonumber(soundKitID), channel)
        return ok and willPlay and true or false
    end

    local paths = {
        "Interface\\AddOns\\iSoundPlayer_Sounds\\" .. soundName,
        "Interface\\AddOns\\iSoundPlayer\\sounds\\" .. soundName,
    }
    for _, path in ipairs(paths) do
        local ok, willPlay = pcall(PlaySoundFile, path, channel)
        if ok and willPlay then return true end
    end
    return false
end

function iST:PlayTwistSound(success)
    if not iSTSettings.enableSoundEffects then return end
    local soundName = success and iSTSettings.twistSuccessSound or iSTSettings.twistFailSound
    self:PlayConfiguredSound(soundName)
end

function iST:ShowTwistResult(success)
    self:PlayTwistSound(success)

    if not self.BarFrame or not self.BarFrame.twistResultText then return end

    -- Check settings
    if success and not iSTSettings.showTwistSuccess then return end
    if not success and not iSTSettings.showTwistFail then return end

    local text = self.BarFrame.twistResultText
    local state = self.State

    if self.BarFrame.resultOverlay then
        self.BarFrame.resultOverlay:Show()
    end
    text:Show()

    -- Apply configured size
    local fontPath = text:GetFont()
    text:SetFont(fontPath, iSTSettings.twistTextSize or 16, "THICKOUTLINE")

    if success then
        text:SetText("Seal Twisted!")
        local c = iSTSettings.twistSuccessColor
        text:SetTextColor(c.r, c.g, c.b, c.a)
    else
        text:SetText("Fail Twist!")
        local c = iSTSettings.twistFailColor
        text:SetTextColor(c.r, c.g, c.b, c.a)
    end

    -- Duration: min(1s, 50% of weapon speed)
    local fadeTime = math.min(1.0, state.WeaponSpeed > 0 and state.WeaponSpeed * 0.5 or 1.0)
    state.TwistResultStart = GetTime()
    state.TwistResultDuration = fadeTime
    text:SetAlpha(1)
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Swing Timer Logic                                    │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:ResetSwingTimer()
    local speed = UnitAttackSpeed("player")
    if not speed or speed <= 0 then return end

    -- Check for failed twist: seal changed AFTER the swing landed (too late)
    if self.State.PendingSealChange and not self.State.SealChangedInTwistZone then
        self:ShowTwistResult(false)
    end
    self.State.PendingSealChange = false
    self.State.SealChangedInTwistZone = false
    self.State.InTwistZone = false
    self.State.Idle = false
    self.State.WrongSealSoundPlayed = false

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

-- Read the real global cooldown instead of assuming every spell cast triggers it.
function iST:UpdateGCDState()
    local startTime, duration

    if C_Spell and C_Spell.GetSpellCooldown then
        local cooldownInfo = C_Spell.GetSpellCooldown(61304)
        if cooldownInfo then
            startTime = cooldownInfo.startTime
            duration = cooldownInfo.duration
        end
    end
    if not startTime and GetSpellCooldown then
        startTime, duration = GetSpellCooldown(61304)
    end

    if startTime and duration and startTime > 0 and duration > 0 then
        self.State.GCDStartTime = startTime
        self.State.GCDEndTime = startTime + duration
        self.State.GCDDuration = duration
    else
        self.State.GCDStartTime = 0
        self.State.GCDEndTime = 0
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                         Combat Log Event Parsing                               │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:OnCombatLogEvent()
    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")

    -- Swing events (player as source)
    if sourceGUID == playerGUID then
        if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
            self:ResetSwingTimer()
            return
        end

        -- Spells that reset the melee swing timer reset it when the cast succeeds.
        if subevent == "SPELL_CAST_SUCCESS"
            and spellID
            and self.SWING_RESET_SPELLS[spellID] then

            self:ResetSwingTimer()
            return
        end
    end

    -- Seal aura events (player as destination — separate from source check)
    if destGUID == playerGUID and spellID then
        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            if self.SEALS[spellID] then
                self:SetCurrentSeal(spellID)
            end
            return
        end

        if subevent == "SPELL_AURA_REMOVED" then
            if self.SEALS[spellID] and (self.State.CurrentSealID == spellID) then
                self:ClearCurrentSeal()
            end
            return
        end
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Seal Tracking                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:SetCurrentSeal(spellID)
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
    self.State.CurrentSealIcon = GetSpellTexture(spellID)

    -- Only the configured FROM -> INTO transition is a twist attempt.
    local isConfiguredTwist = previousSealName == iSTSettings.twistFromSeal and
                              name == iSTSettings.twistIntoSeal
    local sealChanged = previousSealName and previousSealName ~= name

    if sealChanged and isConfiguredTwist then
        if self.State.NextSwingTime > 0 and self.State.WeaponSpeed > 0 then
            local now = GetTime()

            -- Calculate twist zone inline (don't rely on OnUpdate cache)
            local twistWindowSec = iSTSettings.twistWindow
            local lagComp = self.State.HomeLag * 0.002
            local twistStart = 1.0 - (twistWindowSec + lagComp) / self.State.WeaponSpeed
            twistStart = math.max(0.1, math.min(twistStart, 0.95))
            local progress = (now - self.State.LastSwingTime) / self.State.WeaponSpeed

            if now >= self.State.NextSwingTime then
                -- Seal changed after the swing should have landed — fail!
                self.State.PendingSealChange = false
                self:ShowTwistResult(false)
            elseif progress >= twistStart then
                -- Seal changed inside the twist window — success!
                self.State.SealChangedInTwistZone = true
                self.State.PendingSealChange = false
                self:ShowTwistResult(true)
            else
                -- Seal changed before twist window — too early
                self.State.PendingSealChange = true
                self.State.SealChangedInTwistZone = false
            end
        else
            self.State.PendingSealChange = false
            self.State.SealChangedInTwistZone = false
        end
    elseif sealChanged then
        -- An unrelated seal change cancels any pending configured attempt.
        self.State.PendingSealChange = false
        self.State.SealChangedInTwistZone = false
    end

    self:UpdateSealDisplay()
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

function iST:ScanForActiveSeal()
    -- Scan player buffs for an active seal
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end

        -- Try spellID match first
        if spellID and self.SEALS[spellID] then
            self:SetCurrentSeal(spellID)
            return
        end

        -- Fallback: name-based match
        if name and self.SEAL_NAMES[name] then
            local representativeSpellID = self.SEAL_SPELL_IDS[name]
            if representativeSpellID then
                self:SetCurrentSeal(representativeSpellID)
            end
            return
        end
    end

    -- No seal found
    self:ClearCurrentSeal()
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
local LEGACY_TWIST_MACRO_BODY = "#showtooltip\n/castsequence reset=30 Seal of Command, Seal of Righteousness\n/startattack"

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

-- Recognize every exact macro body iST can generate, including the older
-- English-only format. This recovers management metadata lost by old releases
-- while still rejecting macros with custom commands or edits.
function iST:IsGeneratedTwistMacroBody(body)
    local normalizedBody = NormalizeMacroBody(body)
    if not normalizedBody then return false end
    if normalizedBody == NormalizeMacroBody(LEGACY_TWIST_MACRO_BODY) then return true end

    for fromSeal in pairs(self.SEAL_SPELL_IDS) do
        for intoSeal in pairs(self.SEAL_SPELL_IDS) do
            local localizedBody = self:BuildTwistMacroBody(fromSeal, intoSeal)
            local englishBody = "#showtooltip\n/castsequence reset=30 " ..
                                fromSeal .. ", " .. intoSeal .. "\n/startattack"
            if normalizedBody == NormalizeMacroBody(localizedBody) or
               normalizedBody == NormalizeMacroBody(englishBody) then
                return true
            end
        end
    end

    return false
end

-- Update only a macro whose body is still known to be addon-managed. This keeps
-- user edits intact while allowing seal-pair changes and the 0.4.2 migration.
function iST:RefreshTwistMacro(allowLegacyMigration)
    if not iSTSettings then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local macroIndex = GetMacroIndexByName(TWIST_MACRO_NAME)
    if not macroIndex or macroIndex == 0 then return false end

    local _, icon, currentBody = GetMacroInfo(macroIndex)
    local managedBody = iSTSettings.generatedMacroBody
    local localizedLegacyBody = self:BuildTwistMacroBody("Seal of Command", "Seal of Righteousness")
    local isManaged = (managedBody and NormalizeMacroBody(currentBody) == NormalizeMacroBody(managedBody)) or
                      self:IsGeneratedTwistMacroBody(currentBody) or
                      (allowLegacyMigration and
                       (NormalizeMacroBody(currentBody) == NormalizeMacroBody(LEGACY_TWIST_MACRO_BODY) or
                        NormalizeMacroBody(currentBody) == NormalizeMacroBody(localizedLegacyBody)))
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
    return self:RefreshTwistMacro(false)
end

function iST:CreateTwistMacro()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PALADIN" then return end

    -- Existing 0.4.2 users are migrated only when the old generated body is
    -- untouched. Renamed, removed, or manually edited macros remain untouched.
    if iSTSettings.macroCreated then
        self:RefreshTwistMacro(not iSTSettings.generatedMacroBody)
        return
    end

    local macroBody = self:BuildTwistMacroBody()
    if not macroBody then return end

    -- Respect an existing user-created macro with the same name.
    local existingIndex = GetMacroIndexByName(TWIST_MACRO_NAME)
    if existingIndex and existingIndex > 0 then
        -- Recover addon ownership metadata only when the existing body exactly
        -- matches the currently generated macro. Custom bodies remain untouched.
        local _, _, existingBody = GetMacroInfo(existingIndex)
        if NormalizeMacroBody(existingBody) == NormalizeMacroBody(macroBody) or
           self:IsGeneratedTwistMacroBody(existingBody) then
            iSTSettings.macroCreated = true
            iSTSettings.generatedMacroBody = existingBody
            self:RefreshTwistMacro(true)
        end
        return
    end

    local numGlobal, numPerChar = GetNumMacros()
    local created = false
    local ok, err = pcall(function()
        if numGlobal < 36 then
            CreateMacro(TWIST_MACRO_NAME, TWIST_MACRO_ICON, macroBody, false)
            print(L["PrintPrefix"] .. Colors.Green .. "Created macro: " .. Colors.Yellow .. TWIST_MACRO_NAME .. Colors.Reset)
            created = true
        elseif numPerChar < 18 then
            CreateMacro(TWIST_MACRO_NAME, TWIST_MACRO_ICON, macroBody, true)
            print(L["PrintPrefix"] .. Colors.Green .. "Created character macro: " .. Colors.Yellow .. TWIST_MACRO_NAME .. Colors.Reset)
            created = true
        else
            print(L["PrintPrefix"] .. Colors.Red .. "No macro slots available for " .. TWIST_MACRO_NAME .. ". Create it manually." .. Colors.Reset)
        end
    end)
    if not ok then
        print(L["PrintPrefix"] .. Colors.Red .. "Failed to create macro " .. TWIST_MACRO_NAME .. ": " .. tostring(err) .. Colors.Reset)
    end

    if created then
        iSTSettings.macroCreated = true
        iSTSettings.generatedMacroBody = macroBody
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Test Mode                                         │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:StartTestMode()
    self.State.TestMode = true
    self.State.WrongSealSoundPlayed = false
    self.State.WeaponSpeed = 3.6
    self.State.LastSwingTime = GetTime()
    self.State.NextSwingTime = GetTime() + 3.6
    self:ScanForActiveSeal()
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
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(3, function()
            if not InCombatLockdown() then
                iST:CreateTwistMacro()
            else
                -- Retry after combat ends
                local retryFrame = CreateFrame("Frame")
                retryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                retryFrame:SetScript("OnEvent", function(self)
                    self:UnregisterAllEvents()
                    C_Timer.After(1, function() iST:CreateTwistMacro() end)
                end)
            end
        end)
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        iST:OnCombatLogEvent()
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
        iST:UpdateBarVisibility()
        iST:ScanForActiveSeal()
        if iST.State.PendingMacroRefresh then
            iST:RequestTwistMacroRefresh()
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            iST:ScanForActiveSeal()
        end
        return
    end

    if event == "UNIT_ATTACK_SPEED" then
        local unit = ...
        if unit == "player" then
            iST:OnAttackSpeedChanged()
        end
        return
    end

    if event == "SPELL_UPDATE_COOLDOWN" then
        iST:UpdateGCDState()
        return
    end

    -- Fallback refresh for clients where the cooldown event arrives late.
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            -- A successful seal cast is a deterministic transition source on
            -- clients where aura updates arrive in an unexpected order.
            if event == "UNIT_SPELLCAST_SUCCEEDED" and spellID and iST.SEALS[spellID] then
                iST:SetCurrentSeal(spellID)
            end
            C_Timer.After(0, function()
                iST:UpdateGCDState()
            end)
        end
        return
    end

    if event == "PLAYER_TALENT_UPDATE" then
        iST:UpdateBarVisibility()
        return
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Addon Loaded Handler                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:OnAddonLoaded()
    -- Initialize saved settings
    self:InitializeSettings()

    -- Set and repair the faction-aware twist target. This also migrates saved
    -- selections made before faction-specific seals were filtered.
    local _, playerFaction = UnitFactionGroup("player")
    if iSTSettings.twistIntoSeal == "" then
        iSTSettings.twistIntoSeal = playerFaction == "Horde" and
                                    "Seal of Blood" or "Seal of the Martyr"
    elseif not self:IsSealAvailableForPlayerFaction(iSTSettings.twistIntoSeal) then
        iSTSettings.twistIntoSeal = self:GetFactionSealEquivalent(iSTSettings.twistIntoSeal)
    end

    -- Version warning (non-blocking)
    if not self.SupportedVersion then
        C_Timer.After(2, function()
            print(L["PrintPrefix"] .. Colors.Yellow .. string.format(L["UnsupportedVersion"], iST.GameVersionName) .. Colors.Reset)
        end)
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

    -- Apply initial visibility (respects onlyInRetSpec + onlyInCombat)
    self:UpdateBarVisibility()

    -- Start latency polling
    self:UpdateLatency()

    -- Register combat events
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_ATTACK_SPEED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")

    self:UpdateGCDState()

    -- Initial seal scan
    self:ScanForActiveSeal()

    -- Register slash commands
    self:RegisterSlashCommands()

    -- Register PLAYER_ENTERING_WORLD for macro creation (needs fully loaded UI)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    self.State.Initialized = true
end

function iST:OnPlayerLogin()
    -- Create options panel (deferred to login so all frames exist)
    if self.CreateOptionsPanel and self.State.Initialized then
        self:CreateOptionsPanel()
    end

    -- Re-scan for seals after a short delay — player buffs aren't available at ADDON_LOADED time
    C_Timer.After(1, function()
        if iST.State.Initialized then
            iST:ScanForActiveSeal()
            iST:UpdateBarVisibility()
        end
    end)

    -- Login message
    C_Timer.After(2, function()
        print(string.format(L["AddonLoaded"], iST.Version))
    end)
end
