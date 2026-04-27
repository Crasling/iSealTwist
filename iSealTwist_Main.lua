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
for _, name in pairs(iST.SEALS) do
    iST.SEAL_NAMES[name] = true
end

-- Spells that reset the swing timer (e.g., Crusader Strike)
iST.SWING_RESET_SPELLS = {
    [35395] = true, -- Crusader Strike
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
    TwistResultStart = 0,
    TwistResultDuration = 0,
    GCDStartTime = 0,
    GCDEndTime = 0,
    InCast = false,
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Settings Defaults                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
iST.SettingsDefault = {
    enabled = true,
    barWidth = 250,
    barHeight = 25,
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

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                             Create Swing Bar                                   │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:CreateSwingBar()
    if self.BarFrame then return end

    local barWidth = iSTSettings.barWidth
    local barHeight = iSTSettings.barHeight

    -- Main bar frame
    local bar = CreateFrame("Frame", "iSealTwistBar", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bar:SetSize(barWidth, barHeight)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)

    -- Background
    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeSize = 1,
        })
        bar:SetBackdropColor(0.05, 0.05, 0.1, 0.85)
        bar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end

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
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(1)
    fill:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local bc = iSTSettings.barColor
    fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    bar.fill = fill

    -- Twist zone overlay (semi-transparent green area from twist point to end)
    local twistZone = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    twistZone:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
    twistZone:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    twistZone:SetWidth(1)
    twistZone:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local tc = iSTSettings.twistZoneColor
    twistZone:SetVertexColor(tc.r, tc.g, tc.b, tc.a)
    bar.twistZone = twistZone

    -- Twist marker line (vertical line at twist point)
    local marker = bar:CreateTexture(nil, "OVERLAY")
    marker:SetWidth(2)
    marker:SetPoint("TOP", bar, "TOPLEFT", 0, 0)
    marker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", 0, 0)
    marker:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local tm = iSTSettings.twistMarkerColor
    marker:SetVertexColor(tm.r, tm.g, tm.b, tm.a)
    bar.twistMarker = marker

    -- Seal switch zone (amber block from GCD marker to twist window — the "cast twistFromSeal here" window)
    local sealSwitchZone = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    sealSwitchZone:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sealSwitchZone:SetVertexColor(1, 0.55, 0.0, 0.35)
    sealSwitchZone:SetPoint("TOPLEFT",    bar, "TOPLEFT",    0, -1)
    sealSwitchZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0,  1)
    sealSwitchZone:SetWidth(1)
    sealSwitchZone:Hide()
    bar.sealSwitchZone = sealSwitchZone

    -- Red glow edges (rendered outside bar bounds, pulse in alert mode)
    local GLOW = 5
    local function MakeGlowEdge()
        local g = bar:CreateTexture(nil, "OVERLAY", nil, 5)
        g:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        g:SetVertexColor(1, 0.05, 0.05, 0)
        return g
    end
    local ge_top    = MakeGlowEdge()
    local ge_bottom = MakeGlowEdge()
    local ge_left   = MakeGlowEdge()
    local ge_right  = MakeGlowEdge()

    ge_top:SetHeight(GLOW)
    ge_top:SetPoint("BOTTOMLEFT",  bar, "TOPLEFT",   -GLOW, GLOW)
    ge_top:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT",   GLOW, GLOW)

    ge_bottom:SetHeight(GLOW)
    ge_bottom:SetPoint("TOPLEFT",  bar, "BOTTOMLEFT",  -GLOW, -GLOW)
    ge_bottom:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT",  GLOW, -GLOW)

    ge_left:SetWidth(GLOW)
    ge_left:SetPoint("TOPRIGHT",    bar, "TOPLEFT",    -GLOW,  GLOW)
    ge_left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -GLOW, -GLOW)

    ge_right:SetWidth(GLOW)
    ge_right:SetPoint("TOPLEFT",    bar, "TOPRIGHT",    GLOW,  GLOW)
    ge_right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", GLOW, -GLOW)

    bar.glowEdges = { ge_top, ge_bottom, ge_left, ge_right }

    -- GCD active zone (gray block showing current GCD duration on bar)
    local gcdZone = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    gcdZone:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local gz = iSTSettings.gcdZoneColor
    gcdZone:SetVertexColor(gz.r, gz.g, gz.b, gz.a)
    gcdZone:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
    gcdZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 1)
    gcdZone:SetWidth(1)
    gcdZone:Hide()
    bar.gcdZone = gcdZone

    -- GCD indicator line (vertical — marks where to press SoC)
    local gcdMarker = bar:CreateTexture(nil, "OVERLAY")
    gcdMarker:SetWidth(2)
    gcdMarker:SetPoint("TOP", bar, "TOPLEFT", 0, 0)
    gcdMarker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", 0, 0)
    gcdMarker:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local gm = iSTSettings.gcdMarkerColor
    gcdMarker:SetVertexColor(gm.r, gm.g, gm.b, gm.a)
    gcdMarker:Hide()
    bar.gcdMarker = gcdMarker

    -- Seal icon (left of bar)
    local sealIcon = bar:CreateTexture(nil, "OVERLAY")
    sealIcon:SetSize(barHeight, barHeight)
    sealIcon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    sealIcon:Hide()
    bar.sealIcon = sealIcon

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
    latencyText:SetScale(0.85)
    bar.latencyText = latencyText

    -- Seal name text (below bar, center)
    local sealText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sealText:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    sealText:SetText("")
    sealText:SetTextColor(1, 0.59, 0.09, 0.9)
    bar.sealText = sealText

    -- Twist result text (center of bar, fades out)
    local twistResultText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    twistResultText:SetPoint("CENTER", bar, "CENTER", 0, 0)
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
        if iSTSettings.onlyInCombat then
            self:HideBar()
        else
            -- Stay visible but show an empty idle bar
            bar.fill:SetWidth(1)
            local bc = iSTSettings.barColor
            bar.fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a * 0.4)
            bar.twistZone:Hide()
            bar.twistMarker:Hide()
            if bar.gcdZone   then bar.gcdZone:Hide()   end
            if bar.gcdMarker then bar.gcdMarker:Hide() end
            if bar.sealSwitchZone then bar.sealSwitchZone:Hide() end
            if bar.glowEdges then
                for _, g in ipairs(bar.glowEdges) do g:SetVertexColor(0,0,0,0) end
            end
            local bnc = iSTSettings.borderNormalColor
            if bar.SetBackdropBorderColor then
                bar:SetBackdropBorderColor(bnc.r, bnc.g, bnc.b, bnc.a * 0.5)
            end
            bar.speedText:SetShown(iSTSettings.showWeaponSpeed)
            bar.latencyText:SetShown(iSTSettings.showLatency)
        end
        return
    end

    local barWidth = bar:GetWidth() - 2 -- account for border
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
    local gcdStartFrac = twistStart - iST.CONSTANTS.GCD_DURATION / state.WeaponSpeed

    -- Three pulsing states (mutually exclusive, priority order):
    -- ORANGE: Seal2 is active — twist completed, waiting for swing
    local orangeMode = iSTSettings.showOrangePulse and onIntoSeal
    -- GREEN:  Seal1 active + inside twist window + GCD free — cast Seal2 now!
    local greenMode  = iSTSettings.showGreenPulse and
                       (not orangeMode) and onFromSeal and (progress >= twistStart) and gcdFree
    -- RED:    Seal1 active + GCD will not expire before swing — missed the window
    local redMode    = iSTSettings.showRedPulse and iSTSettings.showWrongSealWarning and
                       (not orangeMode) and onFromSeal and gcdRunsPastSwing

    local ac  = iSTSettings.alertColor
    local bnc = iSTSettings.borderNormalColor
    local pulse = math.sin(now * 6) * 0.35 + 0.65

    -- Fill color
    if redMode then
        bar.fill:SetVertexColor(ac.r, ac.g, ac.b, ac.a * pulse)
    elseif greenMode then
        bar.fill:SetVertexColor(0.2, 1.0, 0.2, tc.a * pulse)
    elseif orangeMode then
        bar.fill:SetVertexColor(1.0, 0.55, 0.1, tc.a * pulse)
    elseif progress >= twistStart then
        bar.fill:SetVertexColor(tc.r, tc.g, tc.b, tc.a)
    else
        bar.fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    end

    -- Border + glow edges
    local glowAlpha = (redMode or greenMode or orangeMode) and pulse or 0
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
    if bar.glowEdges then
        local edgeAlpha = (redMode and glowAlpha) or
                          (greenMode and glowAlpha * 0.8) or
                          (orangeMode and glowAlpha * 0.7) or 0
        for _, g in ipairs(bar.glowEdges) do
            g:SetVertexColor(gr, gg * (redMode and 0.3 or 1.0), gb * (redMode and 0.3 or 1.0), edgeAlpha)
        end
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
    local markerX = 1 + (twistStart * barWidth)
    bar.twistMarker:ClearAllPoints()
    bar.twistMarker:SetPoint("TOP", bar, "TOPLEFT", markerX, 0)
    bar.twistMarker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", markerX, 0)
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
            local startX = 1 + startFrac * barWidth
            bar.gcdZone:ClearAllPoints()
            bar.gcdZone:SetPoint("TOPLEFT",    bar, "TOPLEFT",    startX, -1)
            bar.gcdZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", startX,  1)
            bar.gcdZone:SetWidth(zoneWidth)
            bar.gcdZone:Show()
        else
            bar.gcdZone:Hide()
        end
    end

    -- GCD indicator: position one GCD before the twist window opens
    if bar.gcdMarker then
        if iSTSettings.showGCDIndicator and state.WeaponSpeed > 0 then
            local gcdStart = twistStart - iST.CONSTANTS.GCD_DURATION / state.WeaponSpeed
            if gcdStart > 0.02 then
                local gcdX = 1 + (gcdStart * barWidth)
                bar.gcdMarker:ClearAllPoints()
                bar.gcdMarker:SetPoint("TOP", bar, "TOPLEFT", gcdX, 0)
                bar.gcdMarker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", gcdX, 0)
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
            local startX = 1 + gcdStartFrac * barWidth
            local zoneW  = math.max(1, (twistStart - gcdStartFrac) * barWidth)
            bar.sealSwitchZone:ClearAllPoints()
            bar.sealSwitchZone:SetPoint("TOPLEFT",    bar, "TOPLEFT",    startX, -1)
            bar.sealSwitchZone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", startX,  1)
            bar.sealSwitchZone:SetWidth(zoneW)
            bar.sealSwitchZone:Show()
        else
            bar.sealSwitchZone:Hide()
        end
    end

    -- Time remaining text
    local remaining = math.max(0, state.NextSwingTime - now)
    bar.timeText:SetText(string.format("%.1fs", remaining))

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

    -- Fade twist result text
    if bar.twistResultText and state.TwistResultDuration > 0 then
        local elapsed = now - state.TwistResultStart
        if elapsed < state.TwistResultDuration then
            local alpha = 1.0 - (elapsed / state.TwistResultDuration)
            bar.twistResultText:SetAlpha(alpha)
        else
            bar.twistResultText:SetAlpha(0)
            bar.twistResultText:SetText("")
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
-- Falls back to true when no talents are spent (fresh character / loading).
function iST:IsRetSpec()
    if not GetNumTalentTabs then return true end
    local maxPoints, maxTab = 0, 0
    for i = 1, GetNumTalentTabs() do
        local _, _, pointsSpent = GetTalentTabInfo(i)
        if (pointsSpent or 0) > maxPoints then
            maxPoints = pointsSpent
            maxTab = i
        end
    end
    if maxPoints == 0 then return true end  -- no talents spent, show anyway
    return maxTab == 3  -- Paladin tab 3 = Retribution
end

-- Central visibility decision: respects enabled, spec, and combat settings.
function iST:UpdateBarVisibility()
    if not self.BarFrame then return end
    if not iSTSettings.enabled then self:HideBar() return end
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
function iST:ShowTwistResult(success)
    if not self.BarFrame or not self.BarFrame.twistResultText then return end

    -- Check settings
    if success and not iSTSettings.showTwistSuccess then return end
    if not success and not iSTSettings.showTwistFail then return end

    local text = self.BarFrame.twistResultText
    local state = self.State

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

    self.State.WeaponSpeed = speed
    self.State.LastSwingTime = GetTime()
    self.State.NextSwingTime = GetTime() + speed
    self:ShowBar()
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

        if (subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED") and spellID and self.SWING_RESET_SPELLS[spellID] then
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
    self.State.CurrentSealID = spellID
    self.State.PreviousSealID = nil -- clear once consumed
    self.State.CurrentSealName = name
    self.State.CurrentSealIcon = GetSpellTexture(spellID)

    -- Detect twist timing (only if seal actually changed)
    if previousSealID and previousSealID ~= spellID then
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
        end
    end

    self:UpdateSealDisplay()
end

function iST:ClearCurrentSeal()
    -- Preserve previous seal ID so twist detection works across REMOVED→APPLIED gap
    if self.State.CurrentSealID then
        self.State.PreviousSealID = self.State.CurrentSealID
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
    else
        bar.sealIcon:Hide()
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
            self.State.CurrentSealName = name
            self.State.CurrentSealIcon = GetSpellTexture(spellID or 0)
            self:UpdateSealDisplay()
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
                    iST:HideBar()
                end
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
function iST:CreateTwistMacro()
    -- Only create once — flag saved so users can freely remove/rename the macros
    if iSTSettings.macroCreated then return end

    local macros = {
        {
            name = "SealTwist",
            body = "#showtooltip\n/castsequence reset=30 Seal of Command, Seal of Righteousness\n/startattack",
            icon = "INV_Hammer_04",
        },
    }

    local created = 0
    for _, macro in ipairs(macros) do
        local numGlobal, numPerChar = GetNumMacros()
        local ok, err = pcall(function()
            if numGlobal < 36 then
                CreateMacro(macro.name, macro.icon, macro.body, false)
                print(L["PrintPrefix"] .. Colors.Green .. "Created macro: " .. Colors.Yellow .. macro.name .. Colors.Reset)
                created = created + 1
            elseif numPerChar < 18 then
                CreateMacro(macro.name, macro.icon, macro.body, true)
                print(L["PrintPrefix"] .. Colors.Green .. "Created character macro: " .. Colors.Yellow .. macro.name .. Colors.Reset)
                created = created + 1
            else
                print(L["PrintPrefix"] .. Colors.Red .. "No macro slots available for " .. macro.name .. ". Create it manually." .. Colors.Reset)
            end
        end)
        if not ok then
            print(L["PrintPrefix"] .. Colors.Red .. "Failed to create macro " .. macro.name .. ": " .. tostring(err) .. Colors.Reset)
        end
    end

    -- Only set flag if at least one macro was actually created
    if created > 0 then
        iSTSettings.macroCreated = true
    end
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Test Mode                                         │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:StartTestMode()
    self.State.TestMode = true
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
                self:HideBar()
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

    -- GCD tracking: cast-time spells trigger GCD on START; instant spells on SUCCEEDED
    if event == "UNIT_SPELLCAST_START" then
        local unit = ...
        if unit == "player" then
            iST.State.InCast = true
            iST.State.GCDStartTime = GetTime()
            iST.State.GCDEndTime   = GetTime() + iST.CONSTANTS.GCD_DURATION
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit == "player" then
            if not iST.State.InCast then
                -- Instant spell (no START event fired)
                iST.State.GCDStartTime = GetTime()
                iST.State.GCDEndTime   = GetTime() + iST.CONSTANTS.GCD_DURATION
            end
            iST.State.InCast = false
        end
        return
    end

    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" then
            iST.State.InCast = false
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

    -- Set faction-aware default for twistIntoSeal on first load
    if iSTSettings.twistIntoSeal == "" then
        local _, playerFaction = UnitFactionGroup("player")
        if playerFaction == "Horde" then
            iSTSettings.twistIntoSeal = "Seal of Blood"
        else
            iSTSettings.twistIntoSeal = "Seal of the Martyr"
        end
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
        -- Still register slash commands for configuration
        self:RegisterSlashCommands()
        C_Timer.After(2, function()
            print(L["NotPaladin"])
        end)
        return
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
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")

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

    -- Login message
    C_Timer.After(2, function()
        print(string.format(L["AddonLoaded"], iST.Version))
    end)
end
