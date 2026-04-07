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
    barPoint = { "CENTER", nil, "CENTER", 0, -200 },
    showTwistSuccess = true,
    showTwistFail = true,
    barColor = { r = 1, g = 0.59, b = 0.09, a = 0.9 },
    twistZoneColor = { r = 0.2, g = 1, b = 0.2, a = 0.7 },
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
    marker:SetVertexColor(1, 1, 0, 0.9) -- Yellow
    bar.twistMarker = marker

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

    -- Check if swing timer is active
    if state.NextSwingTime <= 0 or state.WeaponSpeed <= 0 then return end

    -- Check if stale (swing should have happened)
    if now > state.NextSwingTime + iST.CONSTANTS.BAR_STALE_THRESHOLD then
        if not state.TestMode then
            self:HideBar()
            return
        end
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

    -- Switch fill color based on twist zone
    local bc = iSTSettings.barColor
    local tc = iSTSettings.twistZoneColor
    if progress >= twistStart then
        bar.fill:SetVertexColor(tc.r, tc.g, tc.b, tc.a)
    else
        bar.fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    end

    -- Update twist zone overlay position
    local twistZoneWidth = math.max(1, (1.0 - twistStart) * barWidth)
    bar.twistZone:SetWidth(twistZoneWidth)

    -- Update twist marker line position
    local markerX = 1 + (twistStart * barWidth)
    bar.twistMarker:ClearAllPoints()
    bar.twistMarker:SetPoint("TOP", bar, "TOPLEFT", markerX, 0)
    bar.twistMarker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", markerX, 0)

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

    if success then
        text:SetText("Seal Twisted!")
        text:SetTextColor(0.2, 1, 0.2)
    else
        text:SetText("Fail Twist!")
        text:SetTextColor(1, 0.2, 0.2)
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
        if iSTSettings.onlyInCombat and not iST.State.TestMode then
            iST:HideBar()
        end
        -- Rescan seal (may have changed)
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

    -- Start latency polling
    self:UpdateLatency()

    -- Register combat events
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_ATTACK_SPEED")

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
