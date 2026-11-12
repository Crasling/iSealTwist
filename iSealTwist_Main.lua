-- iSealTwist: swing timing, seal tracking, and startup.
-- Created by Crasling.

-- Namespace
local addonName, iST = ...

local GetAddOnMetadata = C_AddOns.GetAddOnMetadata

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function GetLocalizedSpellName(spellID, fallback)
    local ok, localizedName = pcall(C_Spell.GetSpellName, spellID)
    if ok and not IsSecret(localizedName) and type(localizedName) == "string" then
        return localizedName
    end
    return fallback
end

local Title = "iSealTwist"
local Version = GetAddOnMetadata(addonName, "Version")
local Author = "Crasling"

-- Libraries
local LDBroker = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

-- Localization
local L = iST.L or {}
local Colors = iST.Colors or {}

-- Chat output
function iST:PrintToChat(...)
    local msg = table.concat({tostringall(...)}, " ")
    if ChatFrame1 then ChatFrame1:AddMessage(msg) end
end

-- Debug messages stay local and are printed only while Debug Mode is enabled.
-- Severity: 1 = error, 2 = warning, 3 = information.
function iST:DebugMsg(message, severity)
    if not iSTSettings or not iSTSettings.debugMode then return end
    local prefix = severity == 1 and L["DebugError"] or severity == 2 and L["DebugWarning"] or L["DebugInfo"]
    self:PrintToChat(prefix .. tostring(message))
end

local print = function(...) iST:PrintToChat(...) end

local function debugTimerReset(timer, spellID, source, before, after, fallbackName)
    if not iSTSettings or not iSTSettings.debugMode then return end
    local name, id = fallbackName or "Internal update", "none"
    if not IsSecret(spellID) and type(spellID) == "number" then
        name = GetLocalizedSpellName(spellID, fallbackName or "Unknown spell")
        id = tostring(spellID)
    end
    iST:DebugMsg(string.format("%s by %s (spell ID: %s; event: %s; combat: %s): %.1fs -> %.1fs.",
        timer, name, id, source or "INTERNAL", iST.State.InCombat and "yes" or "no", before, after), 3)
end

-- Addon details
iST.Title = Title
iST.Version = Version
iST.Author = Author
iST.AddonPath = "Interface\\AddOns\\iSealTwist\\"

iST.GameVersion, iST.GameBuild, iST.GameBuildDate, iST.GameTocVersion = GetBuildInfo()
iST.GameVersionName = "Forever"

-- Constants
iST.CONSTANTS = {
    LATENCY_UPDATE_INTERVAL = 5,    -- seconds between latency polls
    BAR_UPDATE_RATE = 0.016,        -- ~60fps
    BAR_STALE_THRESHOLD = 0.5,      -- hide bar this long after expected swing
    SEAL_DURATION = 30,            -- Forever seals are tracked from successful casts
    PARRY_EVENT_DELAY = 0.65,     -- Observed offset between Forever's parry and swing event streams
}

-- Unsealed Wrath stores stacks on a separate Echo buff for each Seal.
iST.WrathEchoSpells = {
    { id = 1311703, name = "Echo of Command", seal = "Seal of Command" },
    { id = 1311701, name = "Echo of Fury", seal = "Seal of Fury" },
    { id = 1311705, name = "Echo of Justice", seal = "Seal of Justice" },
    { id = 1328198, name = "Echo of Light", seal = "Seal of Light" },
    { id = 1311704, name = "Echo of Righteousness", seal = "Seal of Righteousness" },
    { id = 1328206, name = "Echo of Wisdom", seal = "Seal of Wisdom" },
}
iST.WrathEchoSpellIDs = {}
for _, spell in ipairs(iST.WrathEchoSpells) do iST.WrathEchoSpellIDs[spell.id] = spell.seal end

iST.FONT_CHOICES = {
    { value = "FRIZQT",   label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { value = "ARIALN",   label = "Arial Narrow",   path = "Fonts\\ARIALN.TTF" },
    { value = "MORPHEUS", label = "Morpheus",       path = "Fonts\\MORPHEUS.TTF" },
    { value = "SKURRI",   label = "Skurri",         path = "Fonts\\SKURRI.TTF" },
}

-- Known seal ranks, used to recognize successful player casts.
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

-- Keep a name lookup and one spell ID per seal for translated names.
iST.SEAL_NAMES = {}
iST.SEAL_SPELL_IDS = {}
for spellID, name in pairs(iST.SEALS) do
    iST.SEAL_NAMES[name] = true
    if not iST.SEAL_SPELL_IDS[name] or spellID < iST.SEAL_SPELL_IDS[name] then
        iST.SEAL_SPELL_IDS[name] = spellID
    end
end

-- Translated names identify the seal family; spellbook checks distinguish
-- an unlisted cast rank from a triggered effect with the same name.
iST.KNOWN_SEAL_NAMES = {
    ["Seal of Command"] = true,
    ["Seal of Righteousness"] = true,
    ["Seal of Wisdom"] = true,
    ["Seal of Light"] = true,
    ["Seal of Justice"] = true,
    ["Seal of Fury"] = true,
    ["Seal of the Crusader"] = true,
}

iST.SEAL_NAME_ALIASES = {}
for knownSpellID, canonicalName in pairs(iST.SEALS) do
    local localizedName = GetLocalizedSpellName(knownSpellID)
    if localizedName then iST.SEAL_NAME_ALIASES[localizedName] = canonicalName end
end
for canonicalName in pairs(iST.KNOWN_SEAL_NAMES) do
    iST.SEAL_NAME_ALIASES[canonicalName] = canonicalName
end

local ignoredSealSpellIDs = {}

function iST:ResolveSealCast(unit, castGUID, spellID)
    -- The proc can produce a successful-cast event too. Its name alone is not
    -- evidence that the player reapplied the seal.
    if IsSecret(spellID) or type(spellID) ~= "number" or spellID <= 0
        or spellID >= math.huge or spellID ~= math.floor(spellID) then return end
    if self.SEALS[spellID] then return spellID, self.SEALS[spellID] end

    local spellName = GetLocalizedSpellName(spellID)
    local eventSpellName = spellName and self.SEAL_NAME_ALIASES[spellName]
    if not eventSpellName then return end

    local check = C_SpellBook and C_SpellBook.IsSpellInSpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local ok, inSpellbook
    if type(check) == "function" and bank ~= nil then
        ok, inSpellbook = pcall(check, spellID, bank, false)
    end
    if ok and not IsSecret(inSpellbook) and inSpellbook == true then
        self.SEALS[spellID] = eventSpellName
        self.SEAL_NAMES[eventSpellName] = true
        self.SEAL_SPELL_IDS[eventSpellName] = self.SEAL_SPELL_IDS[eventSpellName] or spellID
        return spellID, eventSpellName
    end
    if iSTSettings and iSTSettings.debugMode and not ignoredSealSpellIDs[spellID] then
        ignoredSealSpellIDs[spellID] = true
        self:DebugMsg(string.format("Ignored %s spell %d: not confirmed in the player spellbook; seal timer unchanged.",
            eventSpellName, spellID), 3)
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

-- Runtime state is rebuilt on reload; only iSTSettings is saved.
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
    StackTestMode = false,
    PreviewStacks = 0,
    TestModeGeneration = 0,
    Initialized = false,
    TwistResultStart = 0,
    TwistResultDuration = 0,
    Idle = false,
    PendingMacroRefresh = false,
    MacroCheckGeneration = 0,
    SealCastTime = 0,
    SealExpiresAt = 0,
    SealGeneration = 0,
    SealStatusKnown = false,
    UnsealedWrathKnown = nil,
}
iST.WrathTracker = iST:NewWrathTracker()

-- Default settings
iST.SettingsDefault = {
    enabled = true,
    debugMode = false,
    fakeUnsealedWrath = false,
    barWidth = 250,
    barHeight = 25,
    sealIconSize = 25,
    barLocked = false,
    showLatency = true,
    showSealIcon = true,
    showSealTimer = true,
    showWeaponSpeed = true,
    onlyInCombat = true,
    onlyAsPaladin = true,
    barPoint = { "CENTER", nil, "CENTER", 0, -200 },
    showTwistSuccess = true,
    twistTextSize     = 16,
    stackCounterTextSize = 16,
    sealTextSize      = 10,
    latencyTextSize   = 9,
    barFont           = "FRIZQT",
    twistSuccessColor = { r = 0.2, g = 1.0, b = 0.2, a = 1.0 },
    wrathCue = "COUNTER",
    stackCounterColor = { r = 1, g = 0.78, b = 0.24, a = 1 },
    showPlayerWrathBubbles = false,
    wrathReadyText = "Switch now",
    wrathColorScheme = "GOLD",
    wrathColor0 = { r = 0.50, g = 0.45, b = 0.34, a = 1 },
    wrathColor1 = { r = 1, g = 0.52, b = 0.12, a = 1 },
    wrathColor2 = { r = 1, g = 0.68, b = 0.17, a = 1 },
    wrathColor3 = { r = 1, g = 0.78, b = 0.24, a = 1 },
    barColor          = { r = 1,    g = 0.59, b = 0.09, a = 0.9 },
    borderNormalColor = { r = 0.3,  g = 0.3,  b = 0.3,  a = 0.8 },
    twistFromSeal     = "Seal of Command",
    twistIntoSeal     = "Seal of Justice",
    sealStackMode     = "ALTERNATE",
    MinimapButton = { hide = false, minimapPos = 220, showInCompartment = true },
}

-- Fill in new settings without replacing the player's saved choices.
function iST:InitializeSettings()
    if not iSTSettings then iSTSettings = {} end
    -- Keep the counter's previous size when giving it a separate slider.
    if iSTSettings.stackCounterTextSize == nil and type(iSTSettings.twistTextSize) == "number" then
        iSTSettings.stackCounterTextSize = iSTSettings.twistTextSize
    end
    local legacyWrathColor = iSTSettings.wrathColorScheme == nil and iSTSettings.wrathCueColor or nil
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
            -- Older color settings may be missing an alpha value.
            for k, v in pairs(value) do
                if iSTSettings[key][k] == nil then
                    iSTSettings[key][k] = v
                end
            end
        end
    end
    -- Replace removed cue choices and move the old shared color to stage colors.
    local validCues = { BAR_COLOR = true, SWORD_IMAGES = true, COUNTER = true, TEXT = true, CIRCLES = true, OFF = true }
    if not validCues[iSTSettings.wrathCue] then iSTSettings.wrathCue = self.SettingsDefault.wrathCue end
    -- Move the previous default to the new counter once. Later choices stay saved.
    if not iSTSettings.stackCounterDefaultMigrated then
        if iSTSettings.wrathCue == "BAR_COLOR" then iSTSettings.wrathCue = "COUNTER" end
        iSTSettings.stackCounterDefaultMigrated = true
    end
    if iSTSettings.sealStackMode ~= "ALTERNATE" and iSTSettings.sealStackMode ~= "FROM_ONLY" then
        iSTSettings.sealStackMode = self.SettingsDefault.sealStackMode
    end
    self:InitializeWrathColors(legacyWrathColor)
    self:InitializeReminderSettings()
    iSTSettings.wrathCueColor = nil
    iSTSettings.twistWarningColor = nil
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
    local stackSize = iSTSettings.stackCounterTextSize or 16
    ApplyFont(bar.stackCountValue, stackSize, "THICKOUTLINE")
    ApplyFont(bar.stackCountTotal, stackSize, "THICKOUTLINE")
    if bar.stackCountFrame then
        local countWidth = math.max(32, math.ceil(stackSize * 1.5))
        local totalWidth = math.max(64, math.ceil(stackSize * 2.5))
        local rowWidth = countWidth + totalWidth + 8
        local rowHeight = stackSize + 10
        bar.stackCountLayout = {
            fontPath = fontPath, fontSize = stackSize,
            countWidth = countWidth, totalWidth = totalWidth,
            rowWidth = rowWidth, rowHeight = rowHeight,
        }
        bar.stackCountFrame:SetSize(rowWidth, rowHeight)
        bar.stackCountValue:ClearAllPoints()
        bar.stackCountValue:SetPoint("RIGHT", bar.stackCountFrame, "CENTER", -4, 0)
        bar.stackCountValue:SetSize(countWidth, rowHeight)
        bar.stackCountValue:SetJustifyH("RIGHT")
        bar.stackCountTotal:ClearAllPoints()
        bar.stackCountTotal:SetPoint("LEFT", bar.stackCountFrame, "CENTER", 0, 0)
        bar.stackCountTotal:SetSize(totalWidth, rowHeight)
        bar.stackCountTotal:SetJustifyH("LEFT")
        if self.LayoutManagedStackReadout then self:LayoutManagedStackReadout() end
    end
    local iconSize = math.max(16, iSTSettings.sealIconSize or iSTSettings.barHeight or 25)
    local sealTimerSize = math.floor(iconSize * 0.46 + 0.5)
    ApplyFont(bar.sealTimerText, sealTimerSize, "THICKOUTLINE")
    if bar.sealTimerOverlay then
        -- Center the visible digits, allowing for the font's side bearing and
        -- baseline padding. A fixed pixel nudge stops fitting as the icon grows.
        local opticalOffset = sealTimerSize * 0.1
        bar.sealTimerText:ClearAllPoints()
        bar.sealTimerText:SetSize(iconSize, iconSize)
        bar.sealTimerText:SetPoint("CENTER", bar.sealTimerOverlay, "CENTER", opticalOffset - 1, -opticalOffset)
    end
    ApplyFont(bar.twistResultText, iSTSettings.twistTextSize or 16, "THICKOUTLINE")
    ApplyFont(bar.wrathCueText, iSTSettings.twistTextSize or 16, "THICKOUTLINE")
    bar.latencyText:SetScale(1)
end

-- Swing bar and its labels
function iST:CreateSwingBar()
    if self.BarFrame then return end

    local barWidth = iSTSettings.barWidth
    local barHeight = iSTSettings.barHeight
    local CONTENT_INSET = 3

    local bar = CreateFrame("Frame", "iSealTwistBar", UIParent, "BackdropTemplate")
    bar:SetSize(barWidth, barHeight)
    bar.contentInset = CONTENT_INSET
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)

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

    -- A faint highlight sits over the top of the fill.
    local gloss = bar:CreateTexture(nil, "ARTWORK", nil, 6)
    gloss:SetPoint("TOPLEFT", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    gloss:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -CONTENT_INSET, -CONTENT_INSET)
    gloss:SetHeight(math.max(1, math.floor((barHeight - CONTENT_INSET * 2) * 0.35)))
    gloss:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    gloss:SetVertexColor(1, 1, 1, 0.055)
    bar.gloss = gloss

    -- Save the final anchor when the player releases the unlocked bar.
    bar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not iSTSettings.barLocked then
            self:StartMoving()
        end
    end)
    bar:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        iST:SaveBarPosition()
    end)

    -- The fill stays inside the border as the bar changes size.
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", CONTENT_INSET, CONTENT_INSET)
    fill:SetWidth(1)
    fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local bc = iSTSettings.barColor
    fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    bar.fill = fill

    local parryTrail = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    parryTrail:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    parryTrail:SetVertexColor(1, 0.78, 0.25, 1)
    parryTrail:SetBlendMode("ADD")
    parryTrail:Hide()
    bar.parryTrail = parryTrail

    local parrySpark = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    parrySpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    parrySpark:SetVertexColor(1, 0.88, 0.45, 1)
    parrySpark:SetBlendMode("ADD")
    parrySpark:Hide()
    bar.parrySpark = parrySpark

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

    -- The portrait covers the center of this circular swipe, leaving only the
    -- outer ring visible. Blizzard animates the countdown between our updates.
    local sealRingCountdown = CreateFrame("Cooldown", nil, sealIconFrame, "CooldownFrameTemplate")
    sealRingCountdown:SetAllPoints(sealIconRing)
    sealRingCountdown:SetFrameLevel(sealIconFrame:GetFrameLevel() + 1)
    sealRingCountdown:EnableMouse(false)
    sealRingCountdown:SetSwipeTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    sealRingCountdown:SetSwipeColor(1, 0.59, 0.09, 0.95)
    sealRingCountdown:SetDrawSwipe(true)
    sealRingCountdown:SetDrawEdge(false)
    sealRingCountdown:SetDrawBling(false)
    sealRingCountdown:SetUseCircularEdge(true)
    sealRingCountdown:SetReverse(false)
    sealRingCountdown:SetHideCountdownNumbers(true)
    sealRingCountdown.noCooldownCount = true
    sealRingCountdown:Hide()
    bar.sealRingCountdown = sealRingCountdown

    local sealPortraitFrame = CreateFrame("Frame", nil, sealIconFrame)
    sealPortraitFrame:SetAllPoints(sealIconFrame)
    sealPortraitFrame:SetFrameLevel(sealRingCountdown:GetFrameLevel() + 1)
    sealPortraitFrame:EnableMouse(false)
    bar.sealPortraitFrame = sealPortraitFrame

    local sealIcon = sealPortraitFrame:CreateTexture(nil, "ARTWORK")
    sealIcon:SetPoint("CENTER", sealIconFrame, "CENTER")
    sealIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local sealIconMask
    if sealIcon.AddMaskTexture and sealPortraitFrame.CreateMaskTexture then
        sealIconMask = sealPortraitFrame:CreateMaskTexture()
        sealIconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        sealIconMask:SetAllPoints(sealIcon)
        sealIcon:AddMaskTexture(sealIconMask)
    end

    function bar:UpdateModernDimensions(height)
        local iconSize = math.max(16, iSTSettings.sealIconSize or height)
        sealIconFrame:SetSize(iconSize + 6, iconSize + 6)
        sealIconShadow:SetSize(iconSize + 10, iconSize + 10)
        sealIconRing:SetSize(iconSize + 8, iconSize + 8)
        sealIcon:SetSize(iconSize, iconSize)
        gloss:SetHeight(math.max(1, math.floor((height - CONTENT_INSET * 2) * 0.35)))
        if self.sealTimerText then iST:ApplyBarTypography() end
    end

    bar:UpdateModernDimensions(barHeight)
    bar.sealIconFrame = sealIconFrame
    bar.sealIcon = sealIcon
    bar.sealIconRing = sealIconRing
    bar.sealIconMask = sealIconMask

    -- A separate, non-interactive text area follows the icon's exact bounds.
    local sealTimerOverlay = CreateFrame("Frame", nil, sealIconFrame)
    sealTimerOverlay:SetAllPoints(sealIcon)
    sealTimerOverlay:SetFrameLevel(sealPortraitFrame:GetFrameLevel() + 1)
    sealTimerOverlay:EnableMouse(false)
    bar.sealTimerOverlay = sealTimerOverlay

    local sealTimerText = sealTimerOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sealTimerText:SetAllPoints(sealTimerOverlay)
    sealTimerText:SetJustifyH("CENTER")
    sealTimerText:SetJustifyV("MIDDLE")
    sealTimerText:SetWordWrap(false)
    sealTimerText:SetNonSpaceWrap(false)
    sealTimerText:SetMaxLines(1)
    sealTimerText:SetText("")
    sealTimerText:SetTextColor(1, 1, 1, 1)
    sealTimerText:SetShadowOffset(0, 0)
    sealTimerText:SetShadowColor(0, 0, 0, 0)
    sealTimerText:Hide()
    bar.sealTimerText = sealTimerText

    -- Time remaining text (right side)
    local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    timeText:SetText("")
    timeText:SetTextColor(1, 1, 1, 1)
    bar.timeText = timeText

    -- Weapon speed text (left side)
    local speedText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    speedText:SetPoint("LEFT", bar, "LEFT", 6, 0)
    speedText:SetText("")
    speedText:SetTextColor(0.8, 0.8, 0.8, 0.7)
    bar.speedText = speedText

    -- Keep the labels above the sword image frame, including its outer glow.
    local labelOverlay = CreateFrame("Frame", nil, bar)
    labelOverlay:SetAllPoints(bar)
    labelOverlay:SetFrameLevel(bar:GetFrameLevel() + 3)
    labelOverlay:EnableMouse(false)
    bar.labelOverlay = labelOverlay

    -- Latency text (bottom-right, small)
    local latencyText = labelOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    latencyText:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -2, -2)
    latencyText:SetText("")
    latencyText:SetTextColor(0.5, 0.5, 0.5, 0.8)
    bar.latencyText = latencyText

    -- Seal name text (below bar, center)
    local sealText = labelOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sealText:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    sealText:SetText("")
    sealText:SetTextColor(1, 0.59, 0.09, 0.9)
    bar.sealText = sealText

    -- Keep release confirmation above the bar so it never covers the swing timer.
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

    bar.updateAccum = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        iST:OnBarUpdate(elapsed)
    end)

    bar:Hide()
    self.BarFrame = bar
    self:CreateWrathCue(bar)
    self:ApplyBarTypography()
    self:CreateStackManagedDisplay()
end

-- Bar position
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

-- Align the bar to the screen's horizontal center without changing its height.
function iST:CenterBarHorizontally()
    if not self.BarFrame then return end
    local _, barCenterY = self.BarFrame:GetCenter()
    local _, screenCenterY = UIParent:GetCenter()
    if not barCenterY or not screenCenterY then return end

    local yOffset = barCenterY - screenCenterY
    iSTSettings.barPoint = { "CENTER", nil, "CENTER", 0, yOffset }
    self:RestoreBarPosition()
end

-- Update the visible timer at a limited rate.
function iST:OnBarUpdate(elapsed)
    local bar = self.BarFrame
    if not bar then return end

    bar.updateAccum = bar.updateAccum + elapsed
    if bar.updateAccum < self.CONSTANTS.BAR_UPDATE_RATE then return end
    bar.updateAccum = 0

    local state, now = self.State, GetTime()
    self:UpdateSealTimer(now)
    if state.TestMode and now >= state.NextSwingTime then
        state.PreviewStacks = state.StackTestMode and (state.PreviewStacks + 1) % 4 or 0
        self:ResetSwingTimer(3.6, false, nil, "PREVIEW")
    end

    -- Wait for the next swing event rather than inventing another attack.
    -- If it does not arrive, show the dim idle bar instead of a stale timer.
    local noSwing = state.NextSwingTime <= 0 or state.WeaponSpeed <= 0
    local stale = not noSwing and not state.TestMode
        and now > state.NextSwingTime + self.CONSTANTS.BAR_STALE_THRESHOLD
    if noSwing or stale then
        self:ClearParryAnimation()
        if not state.Idle then
            state.Idle = true
            self:UpdateBarVisibility()
            local inset = bar.contentInset or 1
            bar.fill:SetWidth(math.max(1, bar:GetWidth() - inset * 2))
            bar.timeText:SetText("")
            bar.speedText:Hide()
            bar.latencyText:SetShown(iSTSettings.showLatency)
        end
    else
        state.Idle = false
        local inset = bar.contentInset or 1
        local width = bar:GetWidth() - inset * 2
        local progress = self:GetSwingBarProgress(now)
        bar.fill:SetWidth(math.max(1, progress * width))
        self:UpdateParryAnimation(now, progress, width)
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
    self:UpdateWrathDisplay(now)
end

function iST:HideBar()
    self:ClearParryAnimation()
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


-- Previews can show out of combat, but still respect the enabled and class settings.
function iST:ShouldShowBar()
    if not iSTSettings.enabled then return false end
    if iSTSettings.onlyAsPaladin then
        local _, playerClass = UnitClass("player")
        if playerClass ~= "PALADIN" then
            return false
        end
    end
    if iSTSettings.onlyInCombat and not self.State.InCombat and not self.State.TestMode then
        return false
    end
    return true
end

function iST:UpdateBarVisibility()
    if not self.BarFrame then return end
    if self:ShouldShowBar() then self:ShowBar() else self:HideBar() end
    self:UpdatePlayerWrathBubbles()
    self:UpdateReminders()
end

-- Stack release message
function iST:ShowTwistResult()
    if not self.BarFrame or not self.BarFrame.twistResultText then return end

    if not iSTSettings.showTwistSuccess then return end

    local text = self.BarFrame.twistResultText
    local state = self.State

    if self.BarFrame.resultOverlay then
        self.BarFrame.resultOverlay:Show()
    end
    text:Show()

    local fontPath = text:GetFont()
    text:SetFont(fontPath, iSTSettings.twistTextSize or 16, "THICKOUTLINE")

    text:SetText(L["WrathReleased"])
    local c = iSTSettings.twistSuccessColor
    text:SetTextColor(c.r, c.g, c.b, c.a)

    -- Fade within half a swing, capped at one second.
    local fadeTime = math.min(1.0, state.WeaponSpeed > 0 and state.WeaponSpeed * 0.5 or 1.0)
    state.TwistResultStart = GetTime()
    state.TwistResultDuration = fadeTime
    text:SetAlpha(1)
end

-- Swing timing
function iST:ClearParryAnimation()
    self.State.ParryAnimation = nil
    if self.BarFrame then
        self.BarFrame.parryTrail:Hide()
        self.BarFrame.parrySpark:Hide()
    end
end

function iST:GetSwingBarProgress(now)
    local state = self.State
    if state.WeaponSpeed <= 0 then return 0 end
    local progress = (now - state.LastSwingTime) / state.WeaponSpeed
    local animation = state.ParryAnimation
    if animation and animation.duration > 0 then
        local fraction = math.max(0, math.min((now - animation.start) / animation.duration, 1))
        -- Ease the newly gained progress into view; the actual deadline and
        -- countdown have already changed and do not wait for the animation.
        progress = progress - animation.offset * (1 - fraction) ^ 3
    end
    return math.max(0, math.min(progress, 1))
end

function iST:UpdateParryAnimation(now, progress, width)
    local state, bar = self.State, self.BarFrame
    local animation = state.ParryAnimation
    if not animation then return end
    local age = now - animation.start
    if age >= animation.fade or now >= state.NextSwingTime then
        self:ClearParryAnimation()
        return
    end
    local alpha = math.max(0, 1 - age / animation.fade)
    local inset = bar.contentInset or 1
    local origin = math.min(progress, animation.from + age / state.WeaponSpeed)
    bar.parryTrail:ClearAllPoints()
    bar.parryTrail:SetPoint("TOPLEFT", bar, "TOPLEFT", inset + origin * width, -inset)
    bar.parryTrail:SetSize(math.max(1, (progress - origin) * width), math.max(1, bar:GetHeight() - inset * 2))
    bar.parryTrail:SetAlpha(alpha * 0.35)
    bar.parryTrail:Show()
    bar.parrySpark:ClearAllPoints()
    bar.parrySpark:SetPoint("CENTER", bar, "LEFT", inset + progress * width, 0)
    bar.parrySpark:SetSize(14, math.max(18, bar:GetHeight() * 1.5))
    bar.parrySpark:SetAlpha(alpha * 0.9)
    bar.parrySpark:Show()
end

function iST:ApplyParryHaste(preview)
    local state = self.State
    if not iSTSettings.enabled or state.TestMode ~= (preview == true) then return false end
    local speed, now = state.WeaponSpeed, GetTime()
    if IsSecret(speed) or type(speed) ~= "number" or speed <= 0 or speed ~= speed or speed == math.huge then
        self:DebugMsg("Parry ignored: no readable main-hand weapon speed is cached.", 3)
        return false
    end
    local remaining = state.NextSwingTime - now
    if remaining <= 0 then
        self:DebugMsg("Parry ignored: there is no pending main-hand swing.", 3)
        return false
    end

    -- UNIT_COMBAT arrives later than PLAYER_SWING on Forever. Apply the rule
    -- at the adjusted parry time, then return to the bar's event timeline.
    -- Otherwise a previous swing's late parry can hasten the new bar cycle.
    local eventDelay = preview == true and 0 or self.CONSTANTS.PARRY_EVENT_DELAY
    local atParry = remaining + eventDelay
    if atParry > speed + 0.00001 or (eventDelay > 0 and atParry >= speed - 0.00001) then
        self:DebugMsg(string.format("Parry ignored: adjusted event belongs before this swing (bar left %.3fs; corrected %.3fs; weapon %.3fs; event offset %.3fs).",
            remaining, atParry, speed, eventDelay), 3)
        return false
    end

    local floor = speed * 0.2
    if atParry <= floor + 0.00001 then
        self:DebugMsg(string.format("Parry detected: corrected %.3fs left; already within the %.3fs parry-haste floor (bar left %.3fs).",
            atParry, floor, remaining), 3)
        return false
    end
    -- A preview has no dispatch delay, so its fresh swing may start at 100%.
    local after = math.max(0, math.max(floor, atParry - speed * 0.4) - eventDelay)
    local gained = remaining - after
    local visibleProgress = self:GetSwingBarProgress(now)
    if preview ~= true and iSTSettings.debugMode then
        state.ParryTimingCheck = state.ParryTimingCheck or { originalDeadline = state.NextSwingTime, startedAt = now }
        state.ParryTimingCheck.predictedDeadline = state.NextSwingTime - gained
    end
    state.LastSwingTime = state.LastSwingTime - gained
    state.NextSwingTime = state.NextSwingTime - gained
    local targetProgress = math.max(0, math.min(1, (now - state.LastSwingTime) / speed))
    state.ParryAnimation = {
        start = now, from = visibleProgress, offset = math.max(0, targetProgress - visibleProgress),
        duration = math.min(0.16, after * 0.5), fade = math.min(0.35, after),
    }
    state.Idle = false
    self:DebugMsg(string.format("Parry haste (UNIT_COMBAT/player/PARRY): %.3fs -> %.3fs remaining; advanced %.3fs; weapon speed %.3fs; event offset %.3fs.",
        remaining, after, gained, speed, eventDelay), 3)
    self:InvalidateBarState()
    return true
end

function iST:CheckParryPrediction(now, isMeleeAttack, sourceEvent)
    local check = self.State.ParryTimingCheck
    if not check or sourceEvent == "PREVIEW" then return end
    self.State.ParryTimingCheck = nil
    if not isMeleeAttack then
        self:DebugMsg("Parry timing check cancelled by a swing-resetting cast.", 3)
    elseif now - check.startedAt <= self.State.WeaponSpeed * 2 then
        self:DebugMsg(string.format("Next main-hand swing after parry: %.3fs from corrected prediction; %.3fs from original deadline (negative = early, positive = late).",
            now - check.predictedDeadline, now - check.originalDeadline), 3)
    else
        self:DebugMsg("Parry timing check expired before the next main-hand swing.", 3)
    end
end

function iST:ResetSwingTimer(swingDuration, isMeleeAttack, spellID, sourceEvent)
    if issecretvalue and issecretvalue(swingDuration) then swingDuration = nil end
    local speed = type(swingDuration) == "number" and swingDuration or UnitAttackSpeed("player")
    if issecretvalue and issecretvalue(speed) then return end
    if not speed or speed <= 0 then return end
    self:ClearParryAnimation()
    local now = GetTime()
    self:CheckParryPrediction(now, isMeleeAttack, sourceEvent)

    -- Update the cue at the swing. Waiting for target feedback makes release
    -- late and loses hits when the target changes before feedback arrives.
    if isMeleeAttack then
        if self:IsWrathTrackingEnabled() then
            if (self.State.SealExpiresAt or 0) <= GetTime() then self:ClearCurrentSeal() end
            local pending = self:QueueWrathSwing(now)
            if pending then
                local grouped = IsInGroup and IsInGroup()
                pending.grouped = IsSecret(grouped) or grouped == true
                local consumed = self.WrathTracker:Attack(self.State.CurrentSealName, now)
                pending.provisional = { count = self.WrathTracker.count, seal = self.WrathTracker.seal,
                    expiresAt = self.WrathTracker.expiresAt, released = consumed > 0 }
                if consumed > 0 then self:ShowTwistResult() end
                self:UpdateWrathDisplay(now)
                self:ScheduleWrathAuraCheck()
            end
        end
    end
    self.State.Idle = false

    local previousRemaining = math.max(0, self.State.NextSwingTime - now)

    self.State.WeaponSpeed = speed
    self.State.LastSwingTime = now
    self.State.NextSwingTime = now + speed
    local resetName = not IsSecret(spellID) and self.SWING_RESET_SPELLS[spellID] or nil
    debugTimerReset("Weapon swing timer reset", spellID, sourceEvent, previousRemaining, speed,
        isMeleeAttack and "Main-hand auto attack" or resetName or "Timer update")
    self:UpdateBarVisibility()
end

function iST:OnAttackSpeedChanged()
    local state = self.State
    if state.NextSwingTime <= 0 or state.WeaponSpeed <= 0 then return end

    local newSpeed = UnitAttackSpeed("player")
    if issecretvalue and issecretvalue(newSpeed) then return end
    if not newSpeed or newSpeed <= 0 then return end
    if newSpeed == state.WeaponSpeed then return end
    self:ClearParryAnimation()
    if state.ParryTimingCheck then
        state.ParryTimingCheck = nil
        self:DebugMsg("Parry timing check cancelled by an attack-speed change.", 3)
    end

    -- Haste changes the time left without restarting the swing from zero.
    local now = GetTime()
    local elapsed = now - state.LastSwingTime
    local fraction = elapsed / state.WeaponSpeed
    fraction = math.max(0, math.min(fraction, 1))

    state.WeaponSpeed = newSpeed
    state.LastSwingTime = now - (fraction * newSpeed)
    state.NextSwingTime = state.LastSwingTime + newSpeed
end

-- Settings can change while the bar is idle. Repaint it on the next update.
function iST:InvalidateBarState()
    self.State.Idle = false
    if self.BarFrame then
        self.BarFrame.updateAccum = self.CONSTANTS.BAR_UPDATE_RATE
    end
end


-- Talent and seal tracking
function iST:HasUnsealedWrath()
    -- Keep the result until a talent or loadout event asks for a fresh check.
    if self.State.UnsealedWrathKnown ~= nil then return self.State.UnsealedWrathKnown end
    local now = GetTime()
    if now < (self.State.NextWrathTalentCheck or 0) then return false end
    self.State.NextWrathTalentCheck = now + 1

    local activeTalentAPIAvailable = C_ClassTalents and C_ClassTalents.GetActiveConfigID
        and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes
        and C_Traits.GetNodeInfo and C_Traits.GetEntryInfo
        and C_Traits.GetDefinitionInfo
    if not activeTalentAPIAvailable then return false end

    -- If the configuration is missing or the lookup throws an error, try again later.
    local ok, learned = pcall(function()
        local configID = C_ClassTalents.GetActiveConfigID()
        if IsSecret(configID) or not configID then return nil end
        local config = configID and C_Traits.GetConfigInfo(configID)
        if IsSecret(config) or not config then return nil end
        for _, treeID in ipairs(config and config.treeIDs or {}) do
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local node = C_Traits.GetNodeInfo(configID, nodeID)
                if IsSecret(node) then return nil end
                local activeRank = node and (node.activeRank or node.currentRank
                    or (type(node.activeEntry) == "table" and node.activeEntry.rank))
                if IsSecret(activeRank) then return nil end
                if node and (tonumber(activeRank) or 0) > 0 then
                    local activeEntries = node.activeEntry and { node.activeEntry } or node.activeEntries or {}
                    for _, activeEntry in ipairs(activeEntries) do
                        local entryID = type(activeEntry) == "table" and activeEntry.entryID or activeEntry
                        local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
                        local definition = entry and C_Traits.GetDefinitionInfo(entry.definitionID)
                        local spellID = definition and definition.spellID
                        local spellName = spellID and C_Spell and C_Spell.GetSpellName
                            and C_Spell.GetSpellName(spellID)
                        if not IsSecret(spellName) and spellName == "Unsealed Wrath" then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end)
    if ok and learned ~= nil then
        self.State.UnsealedWrathKnown = learned
    end
    return ok and learned == true
end

function iST:IsWrathTrackingEnabled()
    return iSTSettings.fakeUnsealedWrath == true or self:HasUnsealedWrath()
end

function iST:SetFakeUnsealedWrath(enabled)
    -- Start fresh when switching between real and fake talent tracking.
    iSTSettings.fakeUnsealedWrath = enabled == true
    self:CancelWrathAuraChecks()
    self:CancelPendingWrathHits()
    self:StopTestMode()
    self.WrathTracker:Reset()
    self.State.WrathAuraInstanceID = nil
    self.State.WrathEchoSeal = nil
    self.State.WrathAuraSnapshot = nil
    self.State.VengeanceStackAuraID = nil
    self.State.TwistResultDuration = 0
    if self.BarFrame then
        self.BarFrame.twistResultText:Hide()
        self.BarFrame.resultOverlay:Hide()
    end
    self:RefreshUnsealedWrathState()
    if enabled then
        self:CreateStackManagedDisplay()
        self:RefreshVengeanceStackAura()
    end
    self:UpdateStackManagedFilter()
    if self.BarFrame then self.BarFrame.nextStackCountDisplay = nil end
    self:UpdateWrathDisplay()
    self:DebugMsg("Fake Unsealed Wrath " .. (enabled and "enabled" or "disabled") .. ".", 3)
end

function iST:RefreshUnsealedWrathState()
    self.State.UnsealedWrathKnown = nil
    self.State.NextWrathTalentCheck = 0
    if not self:IsWrathTrackingEnabled() then
        self:CancelWrathAuraChecks()
        self:CancelPendingWrathHits()
        self.WrathTracker:Reset()
        self.State.WrathAuraInstanceID = nil
        self.State.WrathEchoSeal = nil
        self.State.WrathAuraSnapshot = nil
        self.State.TwistResultDuration = 0
        if self.BarFrame and self.BarFrame.twistResultText then
            self.BarFrame.twistResultText:SetText("")
            self.BarFrame.twistResultText:Hide()
            if self.BarFrame.resultOverlay then self.BarFrame.resultOverlay:Hide() end
        end
    end
    self:InvalidateBarState()
    self:UpdateBarVisibility()
end

function iST:GetWrathDisplayState(now)
    -- Preview counts never change the live tracker.
    if self.State.TestMode then
        return self.State.PreviewStacks, self.State.StackTestMode
    end
    local count = self.WrathTracker:GetCount(now or GetTime())
    -- Once the seal is changed, the next attack is the release step.
    local armed = count > 0 and self.WrathTracker.seal ~= nil
        and self.State.CurrentSealName ~= nil and self.State.CurrentSealName ~= self.WrathTracker.seal
    local active = self:IsWrathTrackingEnabled()
    local wrongSeal = active and iSTSettings.sealStackMode == "FROM_ONLY"
        and self.State.CurrentSealName ~= nil and self.State.CurrentSealName ~= iSTSettings.twistFromSeal
        and not (armed and self.WrathTracker.seal == iSTSettings.twistFromSeal
            and self.State.CurrentSealName == iSTSettings.twistIntoSeal)
    return count, active, armed, wrongSeal
end

function iST:SetSealStackMode(mode)
    if mode ~= "ALTERNATE" and mode ~= "FROM_ONLY" then return end
    iSTSettings.sealStackMode = mode
    self:UpdateWrathDisplay()
    self:DebugMsg("Seal stacking mode: " .. mode .. ".", 3)
end

function iST:CancelWrathAuraChecks()
    self.State.WrathAuraCheckGeneration = (self.State.WrathAuraCheckGeneration or 0) + 1
    self.State.WrathAuraCheckPending = nil
end

function iST:ScheduleWrathAuraCheck()
    if self.State.WrathAuraCheckPending or iSTSettings.fakeUnsealedWrath then return end
    self.State.WrathAuraCheckPending = true
    local generation = self.State.WrathAuraCheckGeneration or 0
    -- Read after the swing's aura update has settled. Coalesce requests so a
    -- burst of aura events cannot build an unbounded queue of checks.
    for _, delay in ipairs({ 0.1, 0.3 }) do
        local final = delay == 0.3
        C_Timer.After(delay, function()
            if generation ~= (iST.State.WrathAuraCheckGeneration or 0) then return end
            if final then iST.State.WrathAuraCheckPending = nil end
            iST:ObserveWrathAura(nil, true)
        end)
    end
end

local function IsWrathAura(aura)
    if IsSecret(aura) or type(aura) ~= "table" then return false end
    local ok, name, spellID, instanceID = pcall(function() return aura.name, aura.spellId, aura.auraInstanceID end)
    if not ok then return false end
    if not IsSecret(instanceID) and iST.State.WrathAuraInstanceID and instanceID == iST.State.WrathAuraInstanceID then return true end
    if not IsSecret(spellID) and iST.WrathEchoSpellIDs[spellID] then return true end
    if IsSecret(name) or type(name) ~= "string" then return false end
    for _, spell in ipairs(iST.WrathEchoSpells) do
        if name == GetLocalizedSpellName(spell.id, spell.name) then return true end
    end
    return false
end

-- Name lookups are a fallback when UNIT_AURA does not provide a usable update.
-- A nil second result means a protected read, not a confirmed missing Echo.
function iST:FindWrathEchoAura()
    local reader = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if type(reader) ~= "function" then return nil, nil end
    for _, spell in ipairs(self.WrathEchoSpells) do
        local name = GetLocalizedSpellName(spell.id, spell.name)
        local ok, aura = pcall(reader, "player", name, "HELPFUL")
        if not ok or IsSecret(aura) then return nil, nil end
        if aura ~= nil then
            if IsWrathAura(aura) then return aura, true end
            return nil, nil
        end
    end
    return nil, true
end

function iST:ApplyWrathAura(aura, source, refreshed)
    if IsSecret(aura) or type(aura) ~= "table" then return false end
    local ok, count, expiresAt, instanceID, spellID, name = pcall(function()
        return aura.applications, aura.expirationTime, aura.auraInstanceID, aura.spellId, aura.name
    end)
    if not ok then return false end
    local state, tracker = self.State, self.WrathTracker
    -- Cache public identity fields even if this particular count is hidden.
    if not IsSecret(instanceID) and type(instanceID) == "number" and instanceID > 0 then state.WrathAuraInstanceID = instanceID end
    local echoSeal
    if not IsSecret(spellID) then echoSeal = self.WrathEchoSpellIDs[spellID] end
    if not echoSeal and not IsSecret(name) and type(name) == "string" then
        for _, spell in ipairs(self.WrathEchoSpells) do
            if name == GetLocalizedSpellName(spell.id, spell.name) then
                echoSeal = spell.seal
                break
            end
        end
    end
    if echoSeal then state.WrathEchoSeal = echoSeal end
    if not IsSecret(spellID) and type(spellID) == "number" and spellID > 0 then
        state.WrathAuraSpellID = spellID
    end
    if not IsSecret(name) and type(name) == "string" then state.WrathAuraName = name end
    if IsSecret(count) then
        if not state.WrathCountRestricted then self:DebugMsg("Unsealed Wrath stack count is restricted; continuing hit tracking.", 3) end
        state.WrathCountRestricted = true
        return false
    end
    if IsSecret(expiresAt) then expiresAt = nil end
    local snapshot = state.WrathAuraSnapshot
    local knownInstance = not IsSecret(instanceID) and type(instanceID) == "number" and instanceID > 0 and instanceID or nil
    local knownExpiry = type(expiresAt) == "number" and expiresAt or nil
    -- Keep an unchanged combat snapshot from undoing a delayed melee hit.
    -- Once combat ends, the readable buff settles both the count and timer.
    local inCombat = state.InCombat == true
    if not inCombat and InCombatLockdown then
        local locked = InCombatLockdown()
        inCombat = IsSecret(locked) or locked == true
    end
    if not inCombat and UnitAffectingCombat then
        local fighting = UnitAffectingCombat("player")
        inCombat = IsSecret(fighting) or fighting == true
    end
    if snapshot and snapshot.count == count
        and (not knownInstance or knownInstance == snapshot.instanceID)
        and (not knownExpiry or knownExpiry == snapshot.expiresAt)
        and ((tracker.count == count and not tracker.countUnconfirmed
                and (not knownExpiry or (not tracker.expiryUnconfirmed and tracker.expiresAt == knownExpiry)))
            or (inCombat and tracker.countUnconfirmed)) then return true, false end
    local previous, previousUnconfirmed = tracker.count, tracker.countUnconfirmed
    if not tracker:Observe(count, expiresAt, state.WrathEchoSeal or state.CurrentSealName, GetTime(), refreshed) then return false end
    if state.WrathEchoSeal then tracker.seal = state.WrathEchoSeal end
    state.WrathAuraSnapshot = {
        count = count,
        instanceID = knownInstance or (snapshot and snapshot.instanceID),
        expiresAt = knownExpiry or (snapshot and snapshot.expiresAt),
    }
    state.WrathAuraRevision = (state.WrathAuraRevision or 0) + 1
    state.WrathCountRestricted = nil
    if previous ~= tracker.count or previousUnconfirmed then
        self:DebugMsg(string.format("Unsealed Wrath confirmed by %s: %d -> %d/3; timer %s.",
            source, previous, tracker.count, tracker.expiryUnconfirmed and "derived from stack updates" or "confirmed by buff"), 3)
    end
    self:UpdateWrathDisplay()
    return true, true
end

function iST:ObserveWrathAura(updateInfo, delayed)
    if iSTSettings.fakeUnsealedWrath then return end
    if not self:HasUnsealedWrath() then return end
    local state, tracker = self.State, self.WrathTracker
    local removedCurrent = false
    local reader = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if not IsSecret(updateInfo) and type(updateInfo) == "table" then
        local readOK, added, updated, removed = pcall(function()
            return updateInfo.addedAuras, updateInfo.updatedAuraInstanceIDs, updateInfo.removedAuraInstanceIDs
        end)
        if readOK and not IsSecret(added) and type(added) == "table" then
            for _, aura in ipairs(added) do
                if IsWrathAura(aura) then
                    local handled, changed = self:ApplyWrathAura(aura, "UNIT_AURA addition", true)
                    if handled then return true, changed end
                end
            end
        end
        if readOK and not IsSecret(updated) and type(updated) == "table" and type(reader) == "function" then
            for _, id in ipairs(updated) do
                if not IsSecret(id) and type(id) == "number" and id > 0 then
                    local ok, aura = pcall(reader, "player", id)
                    if ok and IsWrathAura(aura) then
                        local handled, changed = self:ApplyWrathAura(aura, "UNIT_AURA update", true)
                        if handled then return true, changed end
                    end
                end
            end
        end
        if readOK and not IsSecret(removed) and type(removed) == "table" and state.WrathAuraInstanceID then
            for _, instanceID in ipairs(removed) do
                if not IsSecret(instanceID) and instanceID == state.WrathAuraInstanceID then
                    removedCurrent = true
                    break
                end
            end
        end
    end
    if removedCurrent then
        tracker:Reset()
        state.WrathAuraRevision = (state.WrathAuraRevision or 0) + 1
        state.WrathAuraInstanceID = nil
        state.WrathEchoSeal = nil
        state.WrathAuraSnapshot = nil
        self:UpdateWrathDisplay()
        return true, true
    else
        if state.WrathAuraInstanceID and type(reader) == "function" then
            local ok, aura = pcall(reader, "player", state.WrathAuraInstanceID)
            if ok then
                local handled, changed = self:ApplyWrathAura(aura, "cached aura instance")
                if handled then return true, changed end
            end
        end
        local aura = self:FindWrathEchoAura()
        if aura then
            local handled, changed = self:ApplyWrathAura(aura, "Echo buff lookup")
            if handled then return true, changed end
        end
    end
    if not delayed then self:ScheduleWrathAuraCheck() end
end

function iST:SetCurrentSeal(spellID, observedExpirationTime, sourceEvent)
    if IsSecret(spellID) then return end
    local name = self.SEALS[spellID]
    if not name then return end

    local previousRemaining = math.max(0, (self.State.SealExpiresAt or 0) - GetTime())
    self.State.SealStatusKnown = true
    self.State.CurrentSealID = spellID
    self.State.CurrentSealName = name
    self.State.CurrentSealIcon = C_Spell.GetSpellTexture(spellID)
    self.State.SealCastTime = GetTime()
    local remaining = self.CONSTANTS.SEAL_DURATION
    local observed = not IsSecret(observedExpirationTime) and type(observedExpirationTime) == "number"
        and observedExpirationTime > self.State.SealCastTime and observedExpirationTime < math.huge
    if observed then
        remaining = observedExpirationTime - self.State.SealCastTime
    end
    self.State.SealExpiresAt = self.State.SealCastTime + remaining
    debugTimerReset(observed and "Seal timer synced" or "Seal timer reset", spellID,
        sourceEvent, previousRemaining, remaining, name)
    self.State.SealGeneration = (self.State.SealGeneration or 0) + 1
    local sealGeneration = self.State.SealGeneration

    -- Use the cast's duration when buff details are hidden. The generation check
    -- stops an older expiry callback from clearing a more recent cast.
    C_Timer.After(remaining, function()
        if iST.State.SealGeneration == sealGeneration
            and iST.State.CurrentSealID == spellID then
            iST:ClearCurrentSeal()
        end
    end)

    self:UpdateSealDisplay()
    self:UpdateWrathDisplay()
end

function iST:ScanForActiveSealOutOfCombat(sourceEvent)
    -- Recover a seal that was already active when the addon loaded.
    -- Keep the current seal timer while combat blocks this scan.
    if (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then return end

    for spellID in pairs(self.SEALS) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if not ok or IsSecret(aura) then return end
        if aura ~= nil then
            local expirationTime
            local readable = pcall(function() expirationTime = aura.expirationTime end)
            if not readable then return end
            -- An unrelated aura update must not manufacture another full
            -- duration when the seal's actual expiry is unavailable.
            if IsSecret(expirationTime) or type(expirationTime) ~= "number"
                or expirationTime <= GetTime() or expirationTime >= math.huge
                or expirationTime ~= expirationTime then return end
            if self.State.CurrentSealName == self.SEALS[spellID]
                and self.State.SealExpiresAt == expirationTime then return end
            self:SetCurrentSeal(spellID, expirationTime, sourceEvent or "OUT_OF_COMBAT_AURA_SCAN")
            return
        end
    end

    self:ClearCurrentSeal()
end

function iST:ClearCurrentSeal()
    self.State.SealStatusKnown = true
    self.State.CurrentSealID = nil
    self.State.CurrentSealName = nil
    self.State.CurrentSealIcon = nil
    self.State.SealCastTime = 0
    self.State.SealExpiresAt = 0
    self.State.SealGeneration = (self.State.SealGeneration or 0) + 1
    self:UpdateSealDisplay()
end

function iST:UpdateSealTimer(now)
    local bar = self.BarFrame
    if not bar or not bar.sealTimerText then return end

    now = now or GetTime()
    local expiresAt = self.State.SealExpiresAt or 0
    local remaining = expiresAt - now
    local showTimer = iSTSettings.showSealTimer
        and iSTSettings.showSealIcon
        and self.State.CurrentSealIcon
        and remaining > 0

    local urgent = remaining < 5
    self:UpdateSealRing(expiresAt, showTimer, urgent)
    if showTimer then
        local displayedSeconds = math.ceil(remaining)
        bar.sealTimerText:SetText(tostring(displayedSeconds))
        if urgent then
            bar.sealTimerText:SetTextColor(1, 0.12, 0.08, 1)
        else
            bar.sealTimerText:SetTextColor(1, 1, 1, 1)
        end
        bar.sealTimerText:Show()
    else
        bar.sealTimerText:SetText("")
        bar.sealTimerText:Hide()
    end
end

function iST:UpdateSealRing(expiresAt, showTimer, urgent)
    local bar = self.BarFrame
    local countdown = bar and bar.sealRingCountdown
    if not countdown then return end
    if not showTimer then
        if bar.sealRingExpiresAt then countdown:Clear() end
        countdown:Hide()
        bar.sealRingExpiresAt, bar.sealRingUrgent = nil, nil
        bar.sealIconRing:SetVertexColor(1, 0.59, 0.09, 0.95)
        return
    end

    if bar.sealRingExpiresAt ~= expiresAt then
        -- A seal recovered after login may already be partly expired. Keep its
        -- full thirty-second scale instead of drawing a fresh ring on recovery.
        local duration = self.CONSTANTS.SEAL_DURATION
        countdown:SetCooldown(expiresAt - duration, duration)
        bar.sealRingExpiresAt = expiresAt
        bar.sealIconRing:SetVertexColor(0.28, 0.28, 0.28, 0.95)
    end
    if bar.sealRingUrgent ~= urgent then
        if urgent then countdown:SetSwipeColor(1, 0.08, 0.05, 1)
        else countdown:SetSwipeColor(1, 0.59, 0.09, 0.95) end
        bar.sealRingUrgent = urgent
    end
    countdown:Show()
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

    self:UpdateSealTimer()

    if self.State.CurrentSealName then
        bar.sealText:SetText(self.State.CurrentSealName)
    else
        bar.sealText:SetText("")
    end
end

-- Refresh the latency label separately from the bar animation.
function iST:UpdateLatency()
    local _, _, homeLag = GetNetStats()
    self.State.HomeLag = homeLag or 0

    C_Timer.After(iST.CONSTANTS.LATENCY_UPDATE_INTERVAL, function()
        iST:UpdateLatency()
    end)
end

-- Minimap and addon compartment button
function iST:SetBarLocked(locked, announce)
    iSTSettings.barLocked = locked == true
    local checkbox = self.SettingsFrame and self.SettingsFrame.barLockCheckbox
    if checkbox then checkbox:SetChecked(iSTSettings.barLocked) end
    if announce then print(L[iSTSettings.barLocked and "BarLocked" or "BarUnlocked"]) end
end

function iST:ToggleBarLock()
    self:SetBarLocked(not iSTSettings.barLocked, true)
end

function iST:CreateMinimapButton()
    if not LDBroker or not LDBIcon then return end
    if self.MinimapDataObject then return end

    self.MinimapDataObject = LDBroker:NewDataObject("iSealTwist", {
        type = "data source",
        text = "iSealTwist",
        icon = "Interface\\AddOns\\iSealTwist\\Images\\Logo_iST",
        iconCoords = { 0.14, 0.86, 0.10, 0.82 },
        OnClick = function(_, button)
            if button == "LeftButton" and IsShiftKeyDown() then
                iST:ToggleBarLock()
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
            tooltip:AddLine(" ", 1, 1, 1)
            tooltip:AddLine(L["TooltipStatus"] .. (iSTSettings.enabled and L["StatusEnabled"] or L["StatusDisabled"]), 1, 1, 1)
            tooltip:Show()
        end,
    })

    if not iSTSettings.MinimapButton then
        iSTSettings.MinimapButton = { hide = false, minimapPos = 220, showInCompartment = true }
    end
    iSTSettings.MinimapButton.showInCompartment = true
    LDBIcon:Register("iSealTwist", self.MinimapDataObject, iSTSettings.MinimapButton)
end

-- Seal-pair macro
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

-- Update the macro only if its body still matches the last one saved by iST.
-- A matching name alone does not mean the addon owns it.
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

        -- Read the body back; a successful call does not guarantee the edit stuck.
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

-- Macro-list events can arrive together. Only the last scheduled check runs,
-- and it recreates the macro only if it is still missing.
function iST:ScheduleTwistMacroCheck()
    self.State.MacroCheckGeneration = (self.State.MacroCheckGeneration or 0) + 1
    local generation = self.State.MacroCheckGeneration
    C_Timer.After(0.20, function()
        if generation ~= iST.State.MacroCheckGeneration or not iST.State.Initialized then return end
        local _, playerClass = UnitClass("player")
        if playerClass ~= "PALADIN" then return end
        local macroIndex = GetMacroIndexByName(TWIST_MACRO_NAME)
        if macroIndex and macroIndex > 0 then return end
        if InCombatLockdown and InCombatLockdown() then
            iST.State.PendingMacroRefresh = true
            return
        end
        iST:CreateTwistMacro()
    end)
end

-- Bar previews
function iST:StopTestMode()
    local state = self.State
    if not state.TestMode then return end
    self:ClearParryAnimation()
    state.TestMode, state.StackTestMode, state.PreviewStacks = false, false, 0
    state.TestModeGeneration = state.TestModeGeneration + 1
    -- Return to the real swing timing without touching the live stack tracker.
    local saved = state.TestSwingSnapshot
    if saved then
        state.WeaponSpeed, state.LastSwingTime, state.NextSwingTime = saved[1], saved[2], saved[3]
        state.TestSwingSnapshot = nil
    end
    state.TwistResultDuration = 0
    if self.BarFrame then
        self.BarFrame.twistResultText:Hide()
        self.BarFrame.resultOverlay:Hide()
    end
    self:InvalidateBarState()
    self:UpdateWrathDisplay()
    self:UpdateBarVisibility()
end

local function StartBarTest(stackPreview)
    local state = iST.State
    iST:ClearParryAnimation()
    if not state.TestMode then
        state.TestSwingSnapshot = { state.WeaponSpeed, state.LastSwingTime, state.NextSwingTime }
    end
    -- An older preview's timeout must not stop a more recently started preview.
    state.TestModeGeneration = (state.TestModeGeneration or 0) + 1
    local generation = state.TestModeGeneration
    state.StackTestMode = stackPreview == true
    state.PreviewStacks = 0
    state.TwistResultDuration = 0
    if iST.BarFrame then
        iST.BarFrame.twistResultText:Hide()
        iST.BarFrame.resultOverlay:Hide()
    end
    state.TestMode = true
    state.WeaponSpeed = 3.6
    state.LastSwingTime = GetTime()
    state.NextSwingTime = GetTime() + 3.6
    iST:ShowBar()
    iST:UpdateWrathDisplay()
    print(stackPreview and L["StackTestStarted"] or L["TestStarted"])

    C_Timer.After(30, function()
        if state.TestMode and state.TestModeGeneration == generation then
            iST:StopTestMode()
        end
    end)
end

function iST:StartTestMode()
    StartBarTest(false)
end

function iST:StartStackTestMode()
    StartBarTest(true)
end

function iST:StartTwistSuccessTestMode()
    StartBarTest(false)
    self:ShowTwistResult()
end

function iST:StartParryHasteTestMode()
    StartBarTest(false)
    local generation = self.State.TestModeGeneration
    C_Timer.After(0.7, function()
        if iST.State.TestMode and iST.State.TestModeGeneration == generation then
            iST:ApplyParryHaste(true)
        end
    end)
end

-- Slash commands
function iST:RegisterSlashCommands()
    SLASH_ISEALTWIST1 = "/ist"
    SLASH_ISEALTWIST2 = "/isealtwist"
    SlashCmdList["ISEALTWIST"] = function(msg)
        local input = msg and msg:trim() or ""
        local command, argument = input:match("^(%S+)%s*(.-)%s*$")
        local cmd = command and command:lower() or ""

        if cmd == "hitdebug" then
            iST:HandleHitDebugCommand(argument)
        elseif cmd == "settings" or cmd == "options" or cmd == "config" then
            iST:SettingsToggle()
        elseif cmd == "lock" then
            iST:ToggleBarLock()
        elseif cmd == "reset" then
            iST:ResetBarPosition()
        elseif cmd == "test" then
            iST:StartTestMode()
        else
            print(L["SlashHelp1"])
            print(L["SlashHelp2"])
            print(L["SlashHelp3"])
            print(L["SlashHelp4"])
            print(L["SlashHelp5"])
        end
    end
end

-- Game events
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
        -- Give login events time to settle before checking the saved macro.
        if iST.State.EnteringWorldHandled then return end
        iST.State.EnteringWorldHandled = true
        C_Timer.After(3, function()
            if not InCombatLockdown() then
                iST:CreateTwistMacro()
            else
                -- Macro edits are blocked in combat; finish on PLAYER_REGEN_ENABLED.
                iST.State.PendingMacroRefresh = true
            end
        end)
        return
    end

    if event == "PLAYER_SWING" then
        local swingDuration, swingType = ...
        if IsSecret(swingType) then return end
        if swingType == nil or swingType == Enum.PlayerSwingType.MainHand then
            iST:StopTestMode()
            iST:ResetSwingTimer(swingDuration, true, nil, "PLAYER_SWING")
        end
        return
    end

    if event == "UNIT_COMBAT" then
        iST:ObserveWrathHitFeedback(...)
        local unit, action = ...
        -- The amount field can be secret. Only the defender and action are
        -- needed, and neither is compared until its readability is checked.
        if not IsSecret(unit) and not IsSecret(action) and unit == "player" and action == "PARRY" then
            iST:ApplyParryHaste()
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        iST:CancelPendingWrathHits(true)
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        iST.State.InCombat = true
        iST:StopTestMode()

        iST:UpdateBarVisibility()

        if iST.SettingsFrame and iST.SettingsFrame:IsShown() then
            iST.SettingsFrame:Hide()
        end
        return
    end

    if event == "UPDATE_MACROS" then
        iST:ScheduleTwistMacroCheck()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        iST.State.InCombat = false
        -- Stored seals remain available through short combat breaks.
        iST.WrathTracker:GetCount(GetTime())
        iST:UpdateBarVisibility()
        iST:ScanForActiveSealOutOfCombat("PLAYER_REGEN_ENABLED")
        iST:ObserveWrathAura()
        iST:CreateStackManagedDisplay()
        iST:RefreshVengeanceStackAura()
        if iST.State.PendingStackCounterColor then iST:ApplyStackCounterColor() end
        if iST.State.PendingMacroRefresh then
            iST:RequestTwistMacroRefresh()
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if not IsSecret(unit) and unit == "player" then
            iST:ScanForActiveSealOutOfCombat("UNIT_AURA")
            iST:ObserveWrathAura(updateInfo)
            iST:RefreshVengeanceStackAura(updateInfo)
            if iST.BarFrame then
                iST.BarFrame.nextStackCountDisplay = nil
                iST.BarFrame.nextStackPresenceCheck = nil
            end
            iST:UpdateWrathDisplay()
        end
        return
    end

    if event == "PLAYER_DEAD" then
        iST:CancelWrathAuraChecks()
        iST:CancelPendingWrathHits()
        iST.State.ParryTimingCheck = nil
        iST:ClearParryAnimation()
        iST:StopTestMode()
        iST.State.LastSwingTime, iST.State.NextSwingTime = 0, 0
        iST:InvalidateBarState()
        iST.WrathTracker:Reset()
        iST.State.WrathAuraInstanceID = nil
        iST.State.WrathEchoSeal = nil
        iST.State.WrathAuraSnapshot = nil
        iST:ClearCurrentSeal()
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
        if not IsSecret(unit) and unit == "player" then
            iST:ObserveWrathFeedbackCast(spellID)
            -- Record the seal from the successful cast instead of waiting for
            -- a buff update, which may arrive later or be unreadable.
            local sealSpellID = iST:ResolveSealCast(...)
            if sealSpellID then
                iST:SetCurrentSeal(sealSpellID, nil, "UNIT_SPELLCAST_SUCCEEDED")
            end

            -- Only the spell-ID field identifies the cast. Other numeric
            -- fields, such as the cast-bar ID, must never reset the timer.
            local resetSpellID = not IsSecret(spellID) and type(spellID) == "number" and spellID or nil
            if resetSpellID and iST.SWING_RESET_SPELLS[resetSpellID] then
                iST:ResetSwingTimer(nil, false, resetSpellID, "UNIT_SPELLCAST_SUCCEEDED")
            end
        end
        return
    end

    if event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" and (...) ~= "player" then return end
        iST:RefreshUnsealedWrathState()
        -- The event can arrive before the new tree is readable. Check once more
        -- after the game has had time to apply the loadout.
        C_Timer.After(0.25, function()
            if iST.State.Initialized then iST:RefreshUnsealedWrathState() end
        end)
        return
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
for _, eventName in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SWING",
    "UNIT_COMBAT",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_DEAD",
    "UPDATE_MACROS",
    "UNIT_AURA",
    "UNIT_ATTACK_SPEED",
    "UNIT_SPELLCAST_SUCCEEDED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
}) do
    if C_EventUtils.IsEventValid(eventName) then
        eventFrame:RegisterEvent(eventName)
    end
end

-- Startup
function iST:OnAddonLoaded()
    self:InitializeSettings()
    -- Start with the buff counter now that the other cues are hidden from settings.
    iSTSettings.wrathCue = "COUNTER"
    iSTSettings.showPlayerWrathBubbles = false

    if iSTSettings.twistIntoSeal == iSTSettings.twistFromSeal then
        iSTSettings.twistIntoSeal = iSTSettings.twistFromSeal == "Seal of Justice"
            and "Seal of Righteousness" or "Seal of Justice"
    end

    local _, playerClass = UnitClass("player")
    -- Settings remain accessible even when this class cannot use the timer.
    self:CreateMinimapButton()

    if iSTSettings.onlyAsPaladin and playerClass ~= "PALADIN" then
        C_Timer.After(2, function()
            print(L["NotPaladin"])
        end)
    end

    self:CreateSwingBar()
    self:RestoreBarPosition()
    self:InitializeReminders()

    self:UpdateBarVisibility()

    self:UpdateLatency()

    self:ScanForActiveSealOutOfCombat("ADDON_LOADED")

    self:RegisterSlashCommands()

    self.State.Initialized = true
end

function iST:OnPlayerLogin()
    -- Wait until login to build settings that use Blizzard's UI frames.
    if self.CreateOptionsPanel and self.State.Initialized then
        self:CreateOptionsPanel()
    end

    -- Check the talent and active buffs again after the player UI has loaded.
    C_Timer.After(1, function()
        if iST.State.Initialized then
            iST:RefreshUnsealedWrathState()
            iST:ScanForActiveSealOutOfCombat("PLAYER_LOGIN")
            iST:ObserveWrathAura()
            iST:CreateStackManagedDisplay()
            iST:RefreshVengeanceStackAura()
        end
    end)
end
