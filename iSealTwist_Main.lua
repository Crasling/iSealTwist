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
    NAMEPLATE_ECHO_OFFSET_RANGE = { -60, 300 },
    VERTICAL_SWORD_GLOW_SCALE_RANGE = { 75, 225 },
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
local UNSEALED_WRATH_TALENT_ID = 1310735
iST.UnsealedWrathTalentID = UNSEALED_WRATH_TALENT_ID

iST.FONT_CHOICES = {
    { value = "FRIZQT",   label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { value = "ARIALN",   label = "Arial Narrow",   path = "Fonts\\ARIALN.TTF" },
    { value = "MORPHEUS", label = "Morpheus",       path = "Fonts\\MORPHEUS.TTF" },
    { value = "SKURRI",   label = "Skurri",         path = "Fonts\\SKURRI.TTF" },
    { value = "2002",     label = "2002",           path = "Fonts\\2002.TTF" },
    { value = "2002B",    label = "2002 Bold",      path = "Fonts\\2002B.TTF" },
    { value = "ARKAI_T",  label = "Arkai",          path = "Fonts\\ARKai_T.TTF" },
    { value = "BLEI00D",  label = "Blei",           path = "Fonts\\bLEI00D.TTF" },
    { value = "FRIZ_CYR", label = "Friz Cyrillic",  path = "Fonts\\FRIZQT___CYR.TTF" },
    { value = "K_PAGE",   label = "Page Text",      path = "Fonts\\K_PAGETEXT.TTF" },
    { value = "K_DAMAGE", label = "Damage",         path = "Fonts\\K_Damage.TTF" },
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

iST.SealBarColorOrder = {
    "Seal of Command", "Seal of Righteousness", "Seal of Fury", "Seal of Justice",
    "Seal of Light", "Seal of Wisdom", "Seal of the Crusader",
}
iST.SealBarColorDefaults = {
    ["Seal of Command"] = { r = 1, g = 0.66, b = 0.12, a = 0.9 },
    ["Seal of Righteousness"] = { r = 0.83, g = 0.82, b = 0.72, a = 0.9 },
    ["Seal of Fury"] = { r = 1, g = 0.38, b = 0.20, a = 0.9 },
    ["Seal of Justice"] = { r = 0.68, g = 0.46, b = 0.88, a = 0.9 },
    ["Seal of Light"] = { r = 1, g = 0.86, b = 0.42, a = 0.9 },
    ["Seal of Wisdom"] = { r = 0.30, g = 0.65, b = 1, a = 0.9 },
    ["Seal of the Crusader"] = { r = 1, g = 0.52, b = 0.25, a = 0.9 },
}

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
    Idle = false,
    PendingMacroRefresh = false,
    MacroCheckGeneration = 0,
    SealCastTime = 0,
    SealExpiresAt = 0,
    SealGeneration = 0,
    SealStatusKnown = false,
    UnsealedWrathKnown = nil,
    EchoSwitchBackSeal = nil,
}
iST.WrathTracker = iST:NewWrathTracker()

-- Default settings
iST.SettingsDefault = {
    enabled = true,
    showSwingBar = true,
    debugMode = false,
    barWidth = 250,
    barHeight = 25,
    barStyle = "CLASSIC",
    barTexture = "BLIZZARD",
    sealIconSize = 25,
    barLocked = false,
    showLatency = true,
    showSealIcon = true,
    showSealTimer = true,
    showEchoTimer = false,
    showNameplateEcho = false,
    nameplateEchoGlow = true,
    nameplateEchoStyle = "DOTS",
    nameplateEchoScale = 1,
    nameplateEchoPipSize = 18,
    nameplateEchoOffsetY = -5,
    showSealName = true,
    showWeaponSpeed = true,
    showSwingRemaining = true,
    soundThreeStacks = false,
    soundThreeStacksChoice = "FILE:Echo Spark",
    barVisibility = "COMBAT_OR_AURA",
    onlyAsPaladin = true,
    barPoint = { "CENTER", nil, "CENTER", 0, -200 },
    swingTextSize     = 11,
    stackCounterTextSize = 16,
    showCenterSwitchText = true,
    centerSwitchText = "Switch now",
    centerSwitchCustomText = "Switch now",
    centerSwitchVisual = "TEXT",
    centerAttackText = "Attack now",
    centerAttackCustomText = "Attack now",
    centerSwitchMode = "BOTH",
    centerSwitchColor = { r = 1, g = 0.78, b = 0.24, a = 1 },
    centerAttackColor = { r = 1, g = 0.78, b = 0.24, a = 1 },
    centerSwitchPoint = { "CENTER", nil, "CENTER", 0, 0 },
    wrathCircleSize = 18,
    playerPipSize = 18,
    sealTextSize      = 10,
    latencyTextSize   = 9,
    barFont           = "FRIZQT",
    showStackCounter = true,
    showStackCircles = true,
    stackBubbleStyle = "SEAL_ICONS",
    showStackBarColor = false,
    showStackSwordImages = false,
    swordFrameStyle = "Original",
    showVerticalSword = false,
    verticalSwordVisibility = "ALWAYS",
    verticalSwordMode = "SHARED",
    verticalSwordStyle = "Ashbringer_Forged",
    verticalSwordSecondStyle = "Frostmourne_Forged",
    verticalSwordHeight = 176,
    verticalSwordOpacity = 70,
    showVerticalSwordPhaseMarker = true,
    fadeVerticalSwordGlow = true,
    showVerticalSwordSealGlow = false,
    verticalSwordCorrectGlowScale = 75,
    verticalSwordWrongGlowScale = 75,
    nameplateEchoColor = { r = 1, g = 0.72, b = 0.20, a = 1 },
    echoTimerTextColor = { r = 0.20, g = 0.72, b = 1, a = 1 },
    showPlayerWrathBubbles = false,
    showPlayerPipFrame = true,
    playerPipFrameStyle = "PORTRAIT",
    wrathColorScheme = "GOLD",
    wrathColor0 = { r = 0.50, g = 0.45, b = 0.34, a = 1 },
    wrathColor1 = { r = 1, g = 0.52, b = 0.12, a = 1 },
    wrathColor2 = { r = 1, g = 0.68, b = 0.17, a = 1 },
    wrathColor3 = { r = 1, g = 0.78, b = 0.24, a = 1 },
    barColor          = { r = 1,    g = 0.59, b = 0.09, a = 0.9 },
    barColorBySeal    = false,
    highlightWrongSeal = true,
    wrongSealColor = { r = 1, g = 0.13, b = 0.09, a = 1 },
    borderNormalColor = { r = 0.3,  g = 0.3,  b = 0.3,  a = 0.8 },
    twistFromSeal     = "Seal of Command",
    twistIntoSeal     = "Seal of Justice",
    twistFromStacks   = 3,
    twistIntoStacks   = 3,
    twistMacroResetOnCombat = true,
    MinimapButton = { hide = false, minimapPos = 220, showInCompartment = true },
}

-- Fill in new settings without replacing the player's saved choices.
function iST:InitializeSettings()
    if not iSTSettings then iSTSettings = {} end
    if type(iSTAccountSettings) ~= "table" then iSTAccountSettings = {} end
    if iSTAccountSettings.whatsNewSeenVersion == nil
        and type(iSTSettings.whatsNewSeenVersion) == "string" then
        iSTAccountSettings.whatsNewSeenVersion = iSTSettings.whatsNewSeenVersion
    end
    iSTSettings.whatsNewSeenVersion = nil
    iSTSettings.fakeUnsealedWrath = nil
    iSTSettings.vengeanceDisplaySpellID = nil
    if iSTSettings.barVisibility == nil then
        iSTSettings.barVisibility = iSTSettings.onlyInCombat == false and "ALWAYS" or "COMBAT_OR_AURA"
    end
    -- Keep the counter's previous size when giving it a separate slider.
    if iSTSettings.stackCounterTextSize == nil and type(iSTSettings.twistTextSize) == "number" then
        iSTSettings.stackCounterTextSize = iSTSettings.twistTextSize
    end
    iSTSettings.showTwistSuccess = nil
    iSTSettings.twistTextSize = nil
    iSTSettings.twistSuccessColor = nil
    iSTSettings.stackCounterColor = nil
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
    -- Older setups could use a 100 px bar. Keep them loadable while applying
    -- the new minimum before the bar and its controls are created.
    iSTSettings.barWidth = math.max(150, math.min(500,
        type(iSTSettings.barWidth) == "number" and iSTSettings.barWidth or self.SettingsDefault.barWidth))
    -- The previous Echo timer default was gold. Update that untouched default
    -- to blue while preserving colors the player chose deliberately.
    local echoTextColor = iSTSettings.echoTimerTextColor
    if type(echoTextColor) == "table" and echoTextColor.r == 1
        and echoTextColor.g == 0.82 and echoTextColor.b == 0.35 then
        echoTextColor.r, echoTextColor.g, echoTextColor.b = 0.20, 0.72, 1
    end
    iSTSettings.barColorBySeal = iSTSettings.barColorBySeal == true
    if type(iSTSettings.sealBarColors) ~= "table" then iSTSettings.sealBarColors = {} end
    for seal, default in pairs(self.SealBarColorDefaults) do
        local color = iSTSettings.sealBarColors[seal]
        if type(color) ~= "table" then color = {}; iSTSettings.sealBarColors[seal] = color end
        for _, channel in ipairs({ "r", "g", "b", "a" }) do
            local value = color[channel]
            if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
                color[channel] = default[channel]
            end
        end
    end
    if not self:IsSoundChoiceValid(iSTSettings.soundThreeStacksChoice) then
        iSTSettings.soundThreeStacksChoice = self.SettingsDefault.soundThreeStacksChoice
    end
    -- Import the single old indicator once; afterwards each indicator is independent.
    if iSTSettings.indicatorsMigrated ~= true then
        local cue = iSTSettings.wrathCue
        if cue == "TEXT" then cue = "COUNTER" end
        if cue == "SWORD" then cue = "BAR_COLOR" end
        if cue then
            iSTSettings.showStackCounter = cue == "COUNTER"
            iSTSettings.showStackCircles = cue == "CIRCLES"
            iSTSettings.showStackBarColor = cue == "BAR_COLOR"
            iSTSettings.showStackSwordImages = cue == "SWORD_IMAGES"
        end
        iSTSettings.indicatorsMigrated = true
    end
    iSTSettings.wrathCue = nil
    iSTSettings.showWorldEchoCue = nil
    iSTSettings.worldEchoCueStyle = nil
    iSTSettings.worldEchoCuePhase = nil
    iSTSettings.worldEchoCueScale = nil
    iSTSettings.worldEchoCueColor = nil
    iSTSettings.worldEchoCuePoint = nil
    iSTSettings.swordFrameStyle = self:NormalizeSwordStyle(iSTSettings.swordFrameStyle)
    self:NormalizeVerticalSwordSettings(iSTSettings)
    local swordOpacity = tonumber(iSTSettings.verticalSwordOpacity) or self.SettingsDefault.verticalSwordOpacity
    iSTSettings.verticalSwordOpacity = math.floor(math.max(0, math.min(100, swordOpacity)) + 0.5)
    iSTSettings.testThreeStackHighlight = nil
    -- Remove unfinished ready-message choices from saved settings.
    iSTSettings.showThreeStackReadyText = nil
    iSTSettings.wrathReadyText = nil
    if iSTSettings.stackBubbleStyle ~= "CIRCLES" and iSTSettings.stackBubbleStyle ~= "SEAL_ICONS" then
        iSTSettings.stackBubbleStyle = "SEAL_ICONS"
    end
    if iSTSettings.playerPipFrameStyle ~= "PORTRAIT" and iSTSettings.playerPipFrameStyle ~= "GOLD" then
        iSTSettings.playerPipFrameStyle = self.SettingsDefault.playerPipFrameStyle
    end
    if iSTSettings.centerSwitchMode ~= "SWITCH" and iSTSettings.centerSwitchMode ~= "ATTACK"
        and iSTSettings.centerSwitchMode ~= "BOTH" then
        iSTSettings.centerSwitchMode = "BOTH"
    end
    if iSTSettings.nameplateEchoStyle ~= "DOTS" and iSTSettings.nameplateEchoStyle ~= "SEAL_ICONS" then
        iSTSettings.nameplateEchoStyle = "DOTS"
    end
    local validBarStyles = { CLASSIC = true, BLOCK = true, GLOSSY = true, FRAMELESS = true }
    if not validBarStyles[iSTSettings.barStyle] then
        iSTSettings.barStyle = self.SettingsDefault.barStyle
    end
    if iSTSettings.barTexture == "AUTO" then
        iSTSettings.barTexture = iSTSettings.barStyle == "BLOCK" and "SOLID" or "BLIZZARD"
    end
    local validBarTextures = {
        BLIZZARD = true, RAID = true, SKILLS = true, SOLID = true,
        SOFT = true, GLASS = true, RIDGES = true, DIAGONAL = true,
    }
    if not validBarTextures[iSTSettings.barTexture] then
        iSTSettings.barTexture = self.SettingsDefault.barTexture
    end
    -- The old fixed-From guidance could hide the real Echo count after a
    -- different opening seal. Keep existing characters on the normal display.
    iSTSettings.sealStackMode = nil
    if iSTSettings.centerSwitchText == "3 stacks ready" then
        iSTSettings.centerSwitchText = "Echoes ready"
    end
    if iSTSettings.centerSwitchCustomText == "Switch now"
        and iSTSettings.centerSwitchText ~= "Switch now"
        and iSTSettings.centerSwitchText ~= "Unleash!"
        and iSTSettings.centerSwitchText ~= "Echoes ready" then
        iSTSettings.centerSwitchCustomText = iSTSettings.centerSwitchText
    end
    if iSTSettings.centerAttackCustomText == "Attack now"
        and iSTSettings.centerAttackText ~= "Attack now"
        and iSTSettings.centerAttackText ~= "Unleash now"
        and iSTSettings.centerAttackText ~= "Strike now" then
        iSTSettings.centerAttackCustomText = iSTSettings.centerAttackText
    end
    iSTSettings.centerSwitchVisual = "TEXT"
    for _, key in ipairs({ "barVisibility", "verticalSwordVisibility" }) do
        local mode = iSTSettings[key]
        if mode ~= "ALWAYS" and mode ~= "COMBAT" and mode ~= "COMBAT_OR_AURA" then
            iSTSettings[key] = self.SettingsDefault[key]
        end
    end
    iSTSettings.onlyInCombat = nil
    for _, key in ipairs({ "twistFromStacks", "twistIntoStacks" }) do
        local value = iSTSettings[key]
        if type(value) ~= "number" or value ~= math.floor(value) or value < 0 or value > 3 then
            iSTSettings[key] = 3
        end
    end
    self:InitializeWrathColors(legacyWrathColor)
    self:InitializeReminderSettings()
    iSTSettings.wrathCueColor = nil
    iSTSettings.twistWarningColor = nil
end

function iST:GetTwistStackSelection(seal)
    if seal == iSTSettings.twistFromSeal then return iSTSettings.twistFromStacks end
    if seal == iSTSettings.twistIntoSeal then return iSTSettings.twistIntoStacks end
    return 3
end

function iST:GetTwistStackTarget(seal)
    return math.max(1, self:GetTwistStackSelection(seal) or 3)
end

function iST:GetTwistStackTargetLabel(seal)
    return self:GetTwistStackSelection(seal) == 0 and ">0" or tostring(self:GetTwistStackTarget(seal))
end

function iST:SetTwistStackTarget(side, target)
    if side ~= "From" and side ~= "Into" then return false end
    if type(target) ~= "number" or target ~= math.floor(target) or target < 0 or target > 3 then return false end
    if InCombatLockdown and InCombatLockdown() then
        self:PrintToChat(self.L["StackTargetCombatBlocked"])
        return false
    end
    iSTSettings["twist" .. side .. "Stacks"] = target
    self.State.EchoSwitchBackSeal = nil
    self:ApplyStackStageFormatter()
    self:UpdateCenterSwitchText()
    self:CreateStackManagedDisplay()
    self:UpdateWrathDisplay()
    return true
end

function iST:SetTwistSeal(side, seal)
    if side ~= "From" and side ~= "Into" or not self.SEAL_SPELL_IDS[seal] then return false end
    if InCombatLockdown and InCombatLockdown() then
        self:PrintToChat(self.L["SealPairCombatBlocked"])
        return false
    end
    local key = "twist" .. side .. "Seal"
    local other = side == "From" and iSTSettings.twistIntoSeal or iSTSettings.twistFromSeal
    if seal == other then return false end
    self.State.EchoSwitchBackSeal = nil
    iSTSettings[key] = seal
    self:ApplyStackStageFormatter()
    self:UpdateCenterSwitchText()
    self:UpdateWrathDisplay()
    self:RequestTwistMacroRefresh()
    return true
end

function iST:IsDisplayFontAvailable(path)
    if type(path) ~= "string" or path == "" then return false end
    self.FontPathAvailability = self.FontPathAvailability or {}
    if self.FontPathAvailability[path] == nil then
        local probe = self.FontProbe
        if not probe then
            probe = UIParent:CreateFontString(nil, "OVERLAY")
            self.FontProbe = probe
        end
        local ok, loaded = pcall(probe.SetFont, probe, path, 12, "OUTLINE")
        self.FontPathAvailability[path] = ok and loaded ~= false
    end
    return self.FontPathAvailability[path]
end

function iST:GetBarFontPath()
    local selected = iSTSettings and iSTSettings.barFont or self.SettingsDefault.barFont
    for _, font in ipairs(self.FONT_CHOICES) do
        if font.value == selected and self:IsDisplayFontAvailable(font.path) then
            return font.path
        end
    end
    if type(selected) == "string" and selected:sub(1, 4) == "LSM:" and LibStub then
        local shared = LibStub("LibSharedMedia-3.0", true)
        local path = shared and shared:Fetch("font", selected:sub(5), true)
        if self:IsDisplayFontAvailable(path) then return path end
    end
    return self.FONT_CHOICES[1].path
end

function iST:GetAvailableFontChoices()
    local choices = {}
    local function add(value, label, path)
        if self:IsDisplayFontAvailable(path) then
            choices[#choices + 1] = { value = value, label = label, path = path }
        end
    end
    for _, font in ipairs(self.FONT_CHOICES) do
        add(font.value, font.label, font.path)
    end
    local shared = LibStub and LibStub("LibSharedMedia-3.0", true)
    if shared then
        local names = shared:List("font") or {}
        table.sort(names)
        for _, name in ipairs(names) do
            add("LSM:" .. name, "Shared: " .. name, shared:Fetch("font", name, true))
        end
    end
    return choices
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

    -- Both numbers share a size. Fit it inside the bar so a narrow or short
    -- layout keeps the labels readable without overlapping each other.
    local swingSize = math.max(8, math.min(iSTSettings.swingTextSize or 11,
        math.floor(bar:GetHeight() - 4), math.floor((bar:GetWidth() - 16) / 5)))
    ApplyFont(bar.timeText, swingSize, "OUTLINE")
    ApplyFont(bar.speedText, swingSize, "OUTLINE")
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
        local stackIconSize = math.max(18, math.min(32, math.floor(stackSize * 0.8 + 0.5)))
        bar.stackCountLayout = {
            fontPath = fontPath, fontSize = stackSize,
            countWidth = countWidth, totalWidth = totalWidth,
            rowWidth = rowWidth, rowHeight = rowHeight, iconSize = stackIconSize,
        }
        bar.stackCountFrame:SetSize(rowWidth + stackIconSize + 6, rowHeight)
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
    ApplyFont(bar.sealTimerLabel, math.max(8, math.floor(iconSize * 0.23 + 0.5)), "OUTLINE")
    if bar.sealTimerOverlay then
        -- Center the visible digits, allowing for the font's side bearing and
        -- baseline padding. A fixed pixel nudge stops fitting as the icon grows.
        local opticalOffset = sealTimerSize * 0.1
        bar.sealTimerText:ClearAllPoints()
        bar.sealTimerText:SetSize(iconSize, iconSize)
        bar.sealTimerText:SetPoint("CENTER", bar.sealTimerOverlay, "CENTER", opticalOffset - 1, -opticalOffset)
    end
    ApplyFont(bar.wrathCueText, iSTSettings.stackCounterTextSize or 16, "THICKOUTLINE")
    bar.latencyText:SetScale(1)
end

function iST:ApplyBarStyle(bar)
    bar = bar or self.BarFrame
    if not bar or not bar.fill then return end
    local style = iSTSettings.barStyle
    local artwork = bar.artwork or bar
    local frameless = style == "FRAMELESS"
    local inset = frameless and 0 or 3
    bar.contentInset = inset
    local red, green, blue, alpha = artwork:GetBackdropBorderColor()
    if not red then
        local color = iSTSettings.borderNormalColor
        red, green, blue, alpha = color.r, color.g, color.b, color.a or 1
    end
    artwork:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = not frameless and (style == "CLASSIC" and "Interface\\Tooltips\\UI-Tooltip-Border" or "Interface\\BUTTONS\\WHITE8X8") or nil,
        edgeSize = not frameless and (style == "CLASSIC" and 9 or 1) or nil,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    artwork:SetBackdropColor(0.025, 0.025, 0.045, frameless and 0.55 or 0.94)
    artwork:SetBackdropBorderColor(red, green, blue, alpha)
    local textures = {
        BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar",
        RAID = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
        SKILLS = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
        SOLID = "Interface\\BUTTONS\\WHITE8X8",
        SOFT = self.AddonPath .. "Images\\Textures\\Bar_Soft.tga",
        GLASS = self.AddonPath .. "Images\\Textures\\Bar_Glass.tga",
        RIDGES = self.AddonPath .. "Images\\Textures\\Bar_Ridges.tga",
        DIAGONAL = self.AddonPath .. "Images\\Textures\\Bar_Diagonal.tga",
    }
    local selected = iSTSettings.barTexture
    bar.fill:SetTexture(textures[selected] or textures.BLIZZARD)
    bar.fill:ClearAllPoints()
    bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", inset, -inset)
    bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", inset, inset)
    bar.gloss:ClearAllPoints()
    bar.gloss:SetPoint("TOPLEFT", bar, "TOPLEFT", inset, -inset)
    bar.gloss:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -inset, -inset)
    bar.gloss:SetHeight(math.max(1, math.floor((bar:GetHeight() - inset * 2) * 0.35)))
    bar.gloss:SetVertexColor(1, 1, 1, style == "GLOSSY" and 0.22 or 0.055)
    bar.gloss:SetShown(style == "CLASSIC" or style == "GLOSSY")
    if bar.artwork then
        bar.artwork:SetShown(iSTSettings.showSwingBar)
        bar.labelOverlay:SetShown(iSTSettings.showSwingBar)
    end
    if bar == self.BarFrame then self:InvalidateBarState() end
end

-- Swing bar and its labels
local MOVE_SNAP_DISTANCE = 12

local function CreateMoveOutline(target)
    -- Keep the outline outside the movable frame. Native aura children can
    -- become protected in combat, while this UIParent overlay stays ours.
    local outline = CreateFrame("Frame", nil, UIParent)
    outline:SetPoint("TOPLEFT", target, "TOPLEFT", -2, 2)
    outline:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2, -2)
    outline:SetFrameStrata("MEDIUM")
    outline:SetFrameLevel(100)
    outline:EnableMouse(false)
    local function edge()
        local texture = outline:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(1, 0.68, 0.18, 0.88)
        return texture
    end
    local top = edge()
    top:SetHeight(1)
    top:SetPoint("TOPLEFT", outline)
    top:SetPoint("TOPRIGHT", outline)
    local bottom = edge()
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", outline)
    bottom:SetPoint("BOTTOMRIGHT", outline)
    local left = edge()
    left:SetWidth(1)
    left:SetPoint("TOPLEFT", outline)
    left:SetPoint("BOTTOMLEFT", outline)
    local right = edge()
    right:SetWidth(1)
    right:SetPoint("TOPRIGHT", outline)
    right:SetPoint("BOTTOMRIGHT", outline)
    outline:Hide()
    return outline
end

function iST:UpdateMoveOutlines()
    local editing = self.State.EditMode and not iSTSettings.barLocked
        and not (InCombatLockdown and InCombatLockdown())
    if not editing and not self.MoveOutlines then return end
    local wanted = {}
    if editing and self.BarFrame then
        local bar = self.BarFrame
        wanted[bar] = true
        if iSTSettings.showSealIcon and bar.sealIconFrame then
            wanted[bar.sealIconFrame] = true
        end
        if iSTSettings.showEchoTimer and bar.echoTimerFrame then
            wanted[bar.echoTimerFrame] = true
        end
        if iSTSettings.showStackCounter and bar.stackCountFrame then
            wanted[bar.stackCountFrame] = true
        end
        if iSTSettings.showVerticalSword and self.VerticalSwordFrame then
            wanted[self.VerticalSwordFrame] = true
        end
        if iSTSettings.showCenterSwitchText and self.CenterSwitchFrame then
            wanted[self.CenterSwitchFrame] = true
        end
        for kind, frame in pairs(self.ReminderFrames or {}) do
            if iSTSettings.reminders[kind].enabled then wanted[frame] = true end
        end
    end
    self.MoveOutlines = self.MoveOutlines or {}
    for target, outline in pairs(self.MoveOutlines) do
        local shouldShow = wanted[target] == true
        if shouldShow then
            local ok, shown = pcall(target.IsShown, target)
            shouldShow = ok and shown == true
        end
        outline:SetShown(shouldShow)
        wanted[target] = nil
    end
    for target in pairs(wanted) do
        local ok, shown = pcall(target.IsShown, target)
        if ok and shown == true then
            local outline = CreateMoveOutline(target)
            self.MoveOutlines[target] = outline
            outline:Show()
        end
    end
end

local function MoveGuideLine(parent, vertical, alpha)
    local line = parent:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(1, 0.72, 0.22, alpha)
    if vertical then line:SetWidth(1) else line:SetHeight(1) end
    return line
end

local function PositionMoveGuide(line, vertical, position)
    line:ClearAllPoints()
    if vertical then
        line:SetPoint("TOP", UIParent, "TOPLEFT", position, 0)
        line:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", position, 0)
    else
        line:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, position)
        line:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, position)
    end
end

local function MoveGuideCandidates(frame)
    local left, right = UIParent:GetLeft(), UIParent:GetRight()
    local bottom, top = UIParent:GetBottom(), UIParent:GetTop()
    if not left or not right or not bottom or not top then return end
    local width, height = right - left, top - bottom
    local xs = {
        { value = left + 24, offset = -1 },
        { value = left + width * 0.25, offset = 0 },
        { value = left + width * 0.5, offset = 0 },
        { value = left + width * 0.75, offset = 0 },
        { value = right - 24, offset = 1 },
    }
    local ys = {
        { value = bottom + 24, offset = -1 },
        { value = bottom + height * 0.25, offset = 0 },
        { value = bottom + height * 0.5, offset = 0 },
        { value = bottom + height * 0.75, offset = 0 },
        { value = top - 24, offset = 1 },
    }
    for target, outline in pairs(iST.MoveOutlines or {}) do
        local followsBar = frame == iST.BarFrame and (
            target == frame.sealIconFrame and not iSTSettings.sealIconPoint
            or target == frame.echoTimerFrame and not iSTSettings.echoTimerPoint
            or target == frame.stackCountFrame and not iSTSettings.stackCountPoint)
        if target ~= frame and not followsBar and outline:IsShown() then
            local ok, centerX, centerY = pcall(target.GetCenter, target)
            if ok then
                local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
                if type(centerX) == "number" then xs[#xs + 1] = { value = centerX * scale, offset = 0 } end
                if type(centerY) == "number" then ys[#ys + 1] = { value = centerY * scale, offset = 0 } end
            end
        end
    end
    return xs, ys, left, bottom, width, height
end

local function FindMoveSnap(center, halfSize, candidates)
    local snapped, guide, closest = nil, nil, MOVE_SNAP_DISTANCE
    for _, candidate in ipairs(candidates) do
        local offset = (candidate.offset or 0) * halfSize
        local gap = math.abs(center + offset - candidate.value)
        if gap <= closest then
            snapped, guide, closest = candidate.value - offset, candidate.value, gap
        end
    end
    return snapped, guide
end

local function UpdateMovingFrame(guides)
    local frame = guides.movingFrame
    if not frame or not GetCursorPosition then return end
    if InCombatLockdown and InCombatLockdown() then
        guides.movingFrame = nil
        guides:Hide()
        return
    end
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local screenX, screenY = UIParent:GetCenter()
    if not cursorX or not cursorY or not scale or scale == 0
        or not screenX or not screenY then return end
    local x = cursorX / scale + guides.cursorOffsetX
    local y = cursorY / scale + guides.cursorOffsetY
    local frameScale = frame:GetEffectiveScale() / scale
    if frameScale == 0 then return end
    local xs, ys = MoveGuideCandidates(frame)
    if not xs or not ys then return end
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    local guideX, guideY
    if not shift then
        local width, height = frame:GetWidth(), frame:GetHeight()
        local snappedX, snappedY
        snappedX, guideX = FindMoveSnap(x, width * frameScale * 0.5, xs)
        snappedY, guideY = FindMoveSnap(y, height * frameScale * 0.5, ys)
        x, y = snappedX or x, snappedY or y
    end
    if guides.lastX ~= x or guides.lastY ~= y then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER",
            (x - screenX) / frameScale, (y - screenY) / frameScale)
        guides.lastX, guides.lastY = x, y
    end
    guides.activeVertical:SetShown(guideX ~= nil)
    guides.activeHorizontal:SetShown(guideY ~= nil)
    if guideX then PositionMoveGuide(guides.activeVertical, true, guideX) end
    if guideY then PositionMoveGuide(guides.activeHorizontal, false, guideY) end
    for _, line in ipairs(guides.gridVertical) do line:SetAlpha(shift and 0 or 0.14) end
    for _, line in ipairs(guides.gridHorizontal) do line:SetAlpha(shift and 0 or 0.14) end
end

function iST:BeginMoveGuides(movingFrame)
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local frameX, frameY = movingFrame:GetCenter()
    if not cursorX or not cursorY or not scale or scale == 0
        or not frameX or not frameY then return end
    local frameScale = movingFrame:GetEffectiveScale() / scale
    if frameScale == 0 then return end
    frameX, frameY = frameX * frameScale, frameY * frameScale
    local guides = self.MoveGuides
    if not guides then
        guides = CreateFrame("Frame", nil, UIParent)
        guides:SetAllPoints(UIParent)
        guides:SetFrameStrata("TOOLTIP")
        guides:EnableMouse(false)
        guides.gridVertical, guides.gridHorizontal = {}, {}
        for index = 1, 3 do
            guides.gridVertical[index] = MoveGuideLine(guides, true, 0.14)
            guides.gridHorizontal[index] = MoveGuideLine(guides, false, 0.14)
        end
        guides.activeVertical = MoveGuideLine(guides, true, 0.95)
        guides.activeHorizontal = MoveGuideLine(guides, false, 0.95)
        guides:SetScript("OnUpdate", UpdateMovingFrame)
        guides:Hide()
        self.MoveGuides = guides
    end
    local left, right = UIParent:GetLeft(), UIParent:GetRight()
    local bottom, top = UIParent:GetBottom(), UIParent:GetTop()
    if left and right and bottom and top then
        for index = 1, 3 do
            PositionMoveGuide(guides.gridVertical[index], true,
                left + (right - left) * index * 0.25)
            PositionMoveGuide(guides.gridHorizontal[index], false,
                bottom + (top - bottom) * index * 0.25)
        end
    end
    guides.cursorOffsetX = frameX - cursorX / scale
    guides.cursorOffsetY = frameY - cursorY / scale
    guides.lastX, guides.lastY = nil, nil
    guides.movingFrame = movingFrame
    guides:Show()
    UpdateMovingFrame(guides)
end

function iST:EndMoveGuides(movingFrame)
    local guides = self.MoveGuides
    if not guides then return end
    if guides.movingFrame == movingFrame then UpdateMovingFrame(guides) end
    guides.movingFrame = nil
    guides:Hide()
end

function iST:CanResetMovePosition(frame)
    if not self.State or not self.State.EditMode or iSTSettings.barLocked then return false end
    local inCombat = self.State.InCombat
    if IsSecret(inCombat) or inCombat == true or (frame and frame.isDragging) then return false end
    if self.MoveGuides and self.MoveGuides.movingFrame == frame then return false end
    if type(InCombatLockdown) == "function" then
        local locked = InCombatLockdown()
        if IsSecret(locked) or locked then return false end
    end
    return true
end

function iST:CreateSwingBar()
    if self.BarFrame then return end

    local barWidth = iSTSettings.barWidth
    local barHeight = iSTSettings.barHeight
    local CONTENT_INSET = 3

    local bar = CreateFrame("Frame", "iSealTwistBar", UIParent)
    bar:SetSize(barWidth, barHeight)
    bar.contentInset = CONTENT_INSET
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(false)

    -- The visuals can be hidden while the shared anchor and buff indicators keep updating.
    local artwork = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    artwork:SetAllPoints(bar)
    artwork:EnableMouse(false)
    bar.artwork = artwork

    -- A faint highlight sits over the top of the fill.
    local gloss = artwork:CreateTexture(nil, "ARTWORK", nil, 6)
    gloss:SetPoint("TOPLEFT", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    gloss:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -CONTENT_INSET, -CONTENT_INSET)
    gloss:SetHeight(math.max(1, math.floor((barHeight - CONTENT_INSET * 2) * 0.35)))
    gloss:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    gloss:SetVertexColor(1, 1, 1, 0.055)
    bar.gloss = gloss

    -- Use drag start/stop so releasing outside the bar still saves its position.
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self)
        if iST.State.EditMode and not iSTSettings.barLocked
            and not (InCombatLockdown and InCombatLockdown()) then
            self.isDragging = true
            iST:BeginMoveGuides(self)
        end
    end)
    bar:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        iST:EndMoveGuides(self)
        self.isDragging = nil
        iST:SaveBarPosition()
    end)
    bar:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and iST:CanResetMovePosition(self) then
            iST:ResetBarPosition()
        end
    end)

    -- The fill stays inside the border as the bar changes size.
    local fill = artwork:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)
    fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", CONTENT_INSET, CONTENT_INSET)
    fill:SetWidth(1)
    fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local bc = iSTSettings.barColor
    fill:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    bar.fill = fill

    local parryTrail = artwork:CreateTexture(nil, "ARTWORK", nil, 2)
    parryTrail:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    parryTrail:SetVertexColor(1, 0.78, 0.25, 1)
    parryTrail:SetBlendMode("ADD")
    parryTrail:Hide()
    bar.parryTrail = parryTrail

    local parrySpark = artwork:CreateTexture(nil, "ARTWORK", nil, 3)
    parrySpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    parrySpark:SetVertexColor(1, 0.88, 0.45, 1)
    parrySpark:SetBlendMode("ADD")
    parrySpark:Hide()
    bar.parrySpark = parrySpark

    -- Circular seal icon (left of bar)
    local sealIconFrame = CreateFrame("Frame", nil, bar)
    if iSTSettings.sealIconPoint then
        local point = iSTSettings.sealIconPoint
        sealIconFrame:SetPoint("CENTER", UIParent, "CENTER", point[1], point[2])
    else
        sealIconFrame:SetPoint("RIGHT", bar, "LEFT", -7, 0)
    end
    sealIconFrame:SetMovable(true)
    sealIconFrame:EnableMouse(false)
    sealIconFrame:RegisterForDrag("LeftButton")
    sealIconFrame:SetScript("OnDragStart", function(self)
        if iST.State.EditMode and not iSTSettings.barLocked
            and not (InCombatLockdown and InCombatLockdown()) then
            self.isDragging = true
            iST:BeginMoveGuides(self)
        end
    end)
    sealIconFrame:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        iST:EndMoveGuides(self)
        self.isDragging = nil
        local x, y = self:GetCenter()
        local rootX, rootY = UIParent:GetCenter()
        if x and y and rootX and rootY then
            iSTSettings.sealIconPoint = { x - rootX, y - rootY }
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", iSTSettings.sealIconPoint[1],
                iSTSettings.sealIconPoint[2])
        end
    end)
    sealIconFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and iST:CanResetMovePosition(self) then
            iST:ResetSealIconPosition()
        end
    end)
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
        gloss:SetHeight(math.max(1, math.floor((height - (self.contentInset or CONTENT_INSET) * 2) * 0.35)))
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
    local sealTimerLabel = sealTimerOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sealTimerLabel:SetPoint("BOTTOM", sealIconFrame, "TOP", 0, 1)
    sealTimerLabel:SetText(L["SealTimerLabel"])
    sealTimerLabel:SetTextColor(0.35, 0.82, 1, 1)
    sealTimerLabel:Hide()
    bar.sealTimerLabel = sealTimerLabel

    -- Keep the labels above the sword and the native stack graphics.
    local labelOverlay = CreateFrame("Frame", nil, bar)
    labelOverlay:SetAllPoints(bar)
    labelOverlay:SetFrameLevel(bar:GetFrameLevel() + 20)
    labelOverlay:EnableMouse(false)
    bar.labelOverlay = labelOverlay

    -- Time remaining text (right side)
    local timeText = labelOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    timeText:SetText("")
    timeText:SetTextColor(1, 1, 1, 1)
    bar.timeText = timeText

    -- Weapon speed text (left side)
    local speedText = labelOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    speedText:SetPoint("LEFT", bar, "LEFT", 6, 0)
    speedText:SetText("")
    speedText:SetTextColor(0.8, 0.8, 0.8, 0.7)
    bar.speedText = speedText

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

    bar.updateAccum = 0
    bar:Hide()
    self.BarFrame = bar
    self:ApplyBarStyle()
    self:CreateWrathCue(bar)
    self:AnchorAttachedIndicators()
    self:ApplyBarTypography()
    self:CreateStackManagedDisplay()
end

-- Bar position
function iST:SaveBarPosition()
    if not self.BarFrame then return end
    local point, _, relativePoint, xOfs, yOfs = self.BarFrame:GetPoint()
    iSTSettings.barPoint = { point, nil, relativePoint, xOfs, yOfs }
    self:AnchorAttachedIndicators()
end

function iST:GetAttachedStackCounterOffset()
    local swordLift = self:GetSwordImagePipLift()
    if iSTSettings.showStackCircles then
        local pipSize = math.max(10, math.min(50, tonumber(iSTSettings.wrathCircleSize) or 18))
        return math.max(35, pipSize + 15) + swordLift
    end
    return 7 + swordLift
end

function iST:GetStackPipYOffset()
    return 6 + self:GetSwordImagePipLift()
end

function iST:AnchorAttachedIndicators()
    local bar = self.BarFrame
    if not bar then return end
    if bar.sealIconFrame and not iSTSettings.sealIconPoint then
        bar.sealIconFrame:ClearAllPoints()
        bar.sealIconFrame:SetPoint("RIGHT", bar, "LEFT", bar.wrathIconOffset or -7, 0)
    end
    if bar.echoTimerFrame and not iSTSettings.echoTimerPoint then
        bar.echoTimerFrame:ClearAllPoints()
        bar.echoTimerFrame:SetPoint("LEFT", bar, "RIGHT", bar.wrathEchoOffset or 7, 0)
    end
    if bar.stackCountFrame and not iSTSettings.stackCountPoint then
        bar.stackCountFrame:ClearAllPoints()
        bar.stackCountFrame:SetPoint("BOTTOM", bar, "TOP", 0,
            self:GetAttachedStackCounterOffset())
    end
end

function iST:RestoreBarPosition()
    if not self.BarFrame then return end
    local p = iSTSettings.barPoint
    if p and p[1] then
        self.BarFrame:ClearAllPoints()
        self.BarFrame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
        self:AnchorAttachedIndicators()
    end
end

function iST:ResetBarPosition()
    iSTSettings.barPoint = { "CENTER", nil, "CENTER", 0, -200 }
    self:RestoreBarPosition()
    print(L["BarReset"])
end

function iST:ResetSealIconPosition()
    iSTSettings.sealIconPoint = nil
    self:AnchorAttachedIndicators()
end

function iST:ResetEchoTimerPosition()
    iSTSettings.echoTimerPoint = nil
    self:AnchorAttachedIndicators()
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

local function RunSwingBarAnimation(_, elapsed)
    iST:OnBarUpdate(elapsed)
end

local function SetSwingFillWidth(bar, width)
    if bar.displayedFillWidth == width then return end
    bar.fill:SetWidth(width)
    bar.displayedFillWidth = width
end

function iST:UpdateBarAnimationDriver()
    local bar = self.BarFrame
    if not bar then return end
    local alpha = bar.fadeAlpha or 1
    local fading = bar.fadeTarget ~= nil and bar.fadeTarget ~= alpha
    local animating = bar:IsShown() and (fading or alpha > 0 and (
        self.State.TestMode == true or iSTSettings.showSwingBar and not self.State.Idle
        or bar.nextSealDisplayAt ~= nil))
    if bar.animating == animating then return end
    bar.animating = animating
    bar.updateAccum = 0
    bar:SetScript("OnUpdate", animating and RunSwingBarAnimation or nil)
end

-- The timer and the fade need frame updates. Echo graphics follow aura events.
function iST:OnBarUpdate(elapsed)
    local bar = self.BarFrame
    if not bar then return end

    self:UpdateBarFade(elapsed)
    if bar.fadeAlpha == 0 then
        self:UpdateBarAnimationDriver()
        return
    end
    bar.updateAccum = bar.updateAccum + elapsed
    if bar.updateAccum < self.CONSTANTS.BAR_UPDATE_RATE then return end
    bar.updateAccum = 0

    local state, now = self.State, GetTime()
    if bar.nextSealDisplayAt and now >= bar.nextSealDisplayAt then self:UpdateSealTimer(now) end
    if state.TestMode and now >= state.NextSwingTime then
        if not state.EditMode then
            state.PreviewStacks = state.StackTestMode and (state.PreviewStacks + 1) % 4 or 0
        end
        self:ResetSwingTimer(3.6, false, nil, "PREVIEW")
    end

    if not iSTSettings.showSwingBar then
        self:UpdateBarAnimationDriver()
        return
    end

    -- An expired swing leaves a dim bar until the next real swing.
    local noSwing = state.NextSwingTime <= 0 or state.WeaponSpeed <= 0
    local stale = not noSwing and not state.TestMode
        and now > state.NextSwingTime + self.CONSTANTS.BAR_STALE_THRESHOLD
    if noSwing or stale then
        if not state.Idle then
            self:ClearParryAnimation()
            state.Idle = true
            self:UpdateSwingFillColor()
            local inset = bar.contentInset or 1
            SetSwingFillWidth(bar, math.max(1, bar:GetWidth() - inset * 2))
            bar.timeText:SetText("")
            bar.speedText:Hide()
            bar.displayedSwingTenths, bar.displayedWeaponSpeed = nil, nil
        end
    else
        state.Idle = false
        local inset = bar.contentInset or 1
        local width = bar:GetWidth() - inset * 2
        local progress = self:GetSwingBarProgress(now)
        SetSwingFillWidth(bar, math.max(1, progress * width))
        self:UpdateParryAnimation(now, progress, width)
        local tenths = iSTSettings.showSwingRemaining
            and math.floor(math.max(0, state.NextSwingTime - now) * 10 + 0.5) or nil
        if bar.displayedSwingTenths ~= tenths then
            bar.timeText:SetText(tenths and string.format("%.1fs", tenths / 10) or "")
            bar.displayedSwingTenths = tenths
        end
        local speed = iSTSettings.showWeaponSpeed and state.WeaponSpeed or nil
        if bar.displayedWeaponSpeed ~= speed then
            if speed then bar.speedText:SetText(string.format("%.2f", speed)) end
            bar.speedText:SetShown(speed ~= nil)
            bar.displayedWeaponSpeed = speed
        end
    end

    self:UpdateBarAnimationDriver()
end

local function SetSwingBarAlpha(bar, alpha)
    bar:SetAlpha(alpha)
end

function iST:HideBar()
    self:ClearParryAnimation()
    if self.BarFrame then
        self.BarFrame.fadeTarget = nil
        self.BarFrame.fadeAlpha = 1
        SetSwingBarAlpha(self.BarFrame, 1)
        self.BarFrame:Hide()
        self:UpdateBarAnimationDriver()
        if self.BarFrame.stackCountFrame then self.BarFrame.stackCountFrame:Hide() end
        self.State.BarVisible = false
    end
end

function iST:ShowBar()
    if self.BarFrame then
        self.BarFrame.fadeTarget = nil
        self.BarFrame.fadeAlpha = 1
        SetSwingBarAlpha(self.BarFrame, 1)
        self.BarFrame:EnableMouse(self.State.EditMode == true and not iSTSettings.barLocked
            and self.State.InCombat ~= true and not (InCombatLockdown and InCombatLockdown()))
        self.BarFrame:Show()
        self:UpdateBarAnimationDriver()
        self.State.BarVisible = true
    end
end

-- The buff counter is anchored separately and remains visible while the bar fades.
function iST:FadeBarTo(target)
    local bar = self.BarFrame
    if not bar then return end
    if not bar:IsShown() or not self.State.Initialized then
        bar.fadeAlpha = target
        SetSwingBarAlpha(bar, target)
    end
    if bar.fadeTarget ~= target then
        bar:EnableMouse(target > 0 and self.State.EditMode == true and not iSTSettings.barLocked
            and self.State.InCombat ~= true and not (InCombatLockdown and InCombatLockdown()))
        if bar.fadeTarget ~= nil and not self.State.InCombat then
            self:DebugMsg(target > 0 and "Swing bar shown: active Seal or confirmed Echo stacks."
                or "Swing bar faded: no active Seal or confirmed Echo stacks.", 3)
        end
    end
    bar.fadeTarget = target
    bar:Show()
    self:UpdateBarAnimationDriver()
    self.State.BarVisible = target > 0
end

function iST:UpdateBarFade(elapsed)
    local bar = self.BarFrame
    if not bar or bar.fadeTarget == nil then return end
    local current, target = bar.fadeAlpha or 1, bar.fadeTarget
    if current == target then return end
    local step = math.max(0, elapsed) / 0.2
    current = target > current and math.min(target, current + step)
        or math.max(target, current - step)
    bar.fadeAlpha = current
    SetSwingBarAlpha(bar, current)
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
    return true
end

function iST:ShouldShowAuxiliaryCues()
    return self:ShouldShowBar() and (iSTSettings.barVisibility ~= "COMBAT"
        or self.State.InCombat or self.State.TestMode)
end

function iST:HasActiveSeal()
    local expires = self.State.SealExpiresAt
    local seal = self.State.CurrentSealName
    local now = GetTime()
    return not IsSecret(seal) and type(seal) == "string" and seal ~= ""
        and not IsSecret(expires) and type(expires) == "number" and expires > now
end

function iST:GetActiveSealPairStatus()
    if not self:HasActiveSeal() then return nil end
    local seal = self.State.CurrentSealName
    if seal == iSTSettings.twistFromSeal or seal == iSTSettings.twistIntoSeal then return "CORRECT" end
    return "OTHER"
end

function iST:GetBarFillColor()
    if iSTSettings.barColorBySeal and self:HasActiveSeal() then
        local colors = iSTSettings.sealBarColors
        local color = colors and colors[self.State.CurrentSealName]
        if type(color) == "table" then return color end
    end
    if iSTSettings.highlightWrongSeal and self:IsWrathTrackingEnabled() and self:GetActiveSealPairStatus() == "OTHER" then
        return iSTSettings.wrongSealColor
    end
    return iSTSettings.barColor
end

function iST:HasConfirmedWrathStacks()
    local auraID = self.State.WrathAuraInstanceID
    if not IsSecret(auraID) and type(auraID) == "number" then
        local reader = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
        if type(reader) == "function" then
            local ok, aura = pcall(reader, "player", auraID)
            if ok and not IsSecret(aura) then return aura ~= nil end
        end
    end
    return false
end

function iST:MatchesDisplayVisibility(mode, confirmedEcho)
    if mode == "ALWAYS" or self.State.TestMode or self.State.InCombat then return true end
    return mode == "COMBAT_OR_AURA" and (self:HasActiveSeal() or confirmedEcho or self:HasConfirmedWrathStacks())
end

function iST:UpdateSwingBarVisibility(confirmedEcho)
    if not self.BarFrame then return end
    if not self:ShouldShowBar() then
        self:HideBar()
    -- A confirmed Echo can keep the bar up after the Seal ends.
    elseif iSTSettings.barVisibility ~= "ALWAYS" and not self.State.TestMode then
        local visible = self:MatchesDisplayVisibility(iSTSettings.barVisibility, confirmedEcho)
        self:FadeBarTo(visible and 1 or 0)
    else
        self:ShowBar()
    end
end

function iST:UpdateBarVisibility(confirmedEcho)
    if not self.BarFrame then return end
    self:UpdateSwingBarVisibility(confirmedEcho)
    self:UpdateWrathDisplay(nil, confirmedEcho)
    self:UpdateReminders()
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

    if isMeleeAttack then
        if self:IsWrathTrackingEnabled() then
            if (self.State.SealExpiresAt or 0) <= GetTime() then self:ClearCurrentSeal() end
            -- Native Echo auras drive live cues. Keep swing/feedback matching
            -- only for diagnostics.
            local capture = self.HitDebug and self.HitDebug:IsActive()
            if iSTSettings.debugMode or capture then
                local pending = self:QueueWrathSwing(now)
                if pending then
                    local grouped = IsInGroup and IsInGroup()
                    pending.grouped = IsSecret(grouped) or grouped == true
                    local spent = self.WrathTracker:Attack(self.State.CurrentSealName, now)
                    if spent > 0 then
                        pending.release = { at = now, auraID = self.State.WrathAuraInstanceID }
                        self.State.PendingWrathRelease = pending.release
                    end
                    pending.provisional = { count = self.WrathTracker.count, seal = self.WrathTracker.seal,
                        expiresAt = self.WrathTracker.expiresAt }
                    self:UpdateWrathDisplay(now)
                end
            end
            self:ScheduleWrathAuraCheck()
        end
    end
    local wasIdle = self.State.Idle
    self.State.Idle = false

    local previousRemaining = math.max(0, self.State.NextSwingTime - now)

    self.State.WeaponSpeed = speed
    self.State.LastSwingTime = now
    self.State.NextSwingTime = now + speed
    local resetName = not IsSecret(spellID) and self.SWING_RESET_SPELLS[spellID] or nil
    debugTimerReset("Weapon swing timer reset", spellID, sourceEvent, previousRemaining, speed,
        isMeleeAttack and "Main-hand auto attack" or resetName or "Timer update")
    if self.State.TestMode then
        self:UpdateBarVisibility()
    else
        self:UpdateSwingBarVisibility()
        if wasIdle and self.BarFrame then self:UpdateSwingFillColor() end
    end
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
    self:InvalidateBarState()
end

-- Settings can change while the bar is idle. Repaint it on the next update.
function iST:InvalidateBarState()
    self.State.Idle = false
    if self.BarFrame then
        self:UpdateBarAnimationDriver()
        self.BarFrame.updateAccum = self.CONSTANTS.BAR_UPDATE_RATE
    end
end


-- Talent and seal tracking
function iST:HasUnsealedWrath()
    -- A positive result stays valid until a talent event. A negative result
    -- may come from a talent tree that was still loading at login.
    if self.State.UnsealedWrathKnown == true then return true end
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
        if type(config.treeIDs) ~= "table" or #config.treeIDs == 0 then return nil end
        local nodesSeen = 0
        for _, treeID in ipairs(config.treeIDs) do
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                nodesSeen = nodesSeen + 1
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
                        if not IsSecret(spellID) and spellID == UNSEALED_WRATH_TALENT_ID then
                            return true
                        end
                    end
                end
            end
        end
        if nodesSeen == 0 then return nil end
        return false
    end)
    if ok and learned ~= nil then
        self.State.UnsealedWrathKnown = learned
        if not learned then self.State.NextWrathTalentCheck = now + 10 end
        if learned and self.State.Initialized and self.BarFrame then
            C_Timer.After(0, function()
                if self.State.Initialized then
                    self:CreateStackManagedDisplay()
                    self:UpdateBarVisibility()
                end
            end)
        end
    end
    if self.State.UnsealedWrathKnown ~= true and self.State.Initialized and not self.State.WrathTalentRetryPending then
        self.State.WrathTalentRetryPending = true
        C_Timer.After(self.State.NextWrathTalentCheck - now, function()
            self.State.WrathTalentRetryPending = nil
            if self:ShouldShowBar() and self.State.UnsealedWrathKnown ~= true then
                self.State.NextWrathTalentCheck = 0
                self:HasUnsealedWrath()
            end
        end)
    end
    return ok and learned == true
end

function iST:IsWrathTrackingEnabled()
    return self:HasUnsealedWrath()
end

function iST:RefreshUnsealedWrathState()
    self.State.UnsealedWrathKnown = nil
    self.State.NextWrathTalentCheck = 0
    local wrathEnabled = self:IsWrathTrackingEnabled()
    if not wrathEnabled then
        self:CancelWrathAuraChecks()
        self:CancelPendingWrathHits()
        self.WrathTracker:Reset()
        self.State.ThreeStackSoundReady = true
        self.State.PendingWrathRelease = nil
        self.State.WrathUnleashedUntil = nil
        self.State.WrathAuraInstanceID = nil
        self.State.WrathEchoSeal = nil
        self.State.EchoSwitchBackSeal = nil
        self.State.WrathLastSealCastName = nil
        self.State.WrathLastSwitchFrom = nil
        self.State.WrathAuraSnapshot = nil
    else
        -- A newly learned talent needs its native Echo buttons before combat.
        self:CreateStackManagedDisplay()
    end
    self:InvalidateBarState()
    self:UpdateBarVisibility()
end

function iST:GetWrathDisplayState(now)
    -- Preview counts never change the live tracker.
    if self.State.TestMode then
        return self.State.PreviewStacks, self.State.StackTestMode
    end
    -- Native aura buttons compare live counts without exposing protected
    -- numbers to addon code.
    return 0, self:IsWrathTrackingEnabled(), false
end

function iST:ConfirmWrathRelease()
    local pending = self.State.PendingWrathRelease
    self.State.PendingWrathRelease = nil
    local now = GetTime()
    if not pending or now - pending.at > 2 or self.WrathTracker:GetCount(now) ~= 0 then return end
    self.State.WrathUnleashedUntil = now + 1.25
end

function iST:CancelWrathAuraChecks()
    self.State.WrathAuraCheckGeneration = (self.State.WrathAuraCheckGeneration or 0) + 1
    self.State.WrathAuraCheckPending = nil
end

function iST:ScheduleWrathAuraCheck()
    if self.State.WrathAuraCheckPending then return end
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

function iST:ApplyWrathAura(aura, source, refreshed, newlyAdded)
    if IsSecret(aura) or type(aura) ~= "table" then return false end
    local ok, count, expiresAt, instanceID, spellID, name = pcall(function()
        return aura.applications, aura.expirationTime, aura.auraInstanceID, aura.spellId, aura.name
    end)
    if not ok then return false end
    local state, tracker = self.State, self.WrathTracker
    -- Cache public identity fields even if this particular count is hidden.
    local previousInstance = state.WrathAuraInstanceID
    local knownInstance = not IsSecret(instanceID) and type(instanceID) == "number" and instanceID > 0 and instanceID or nil
    if knownInstance then state.WrathAuraInstanceID = knownInstance end
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
    if echoSeal then
        state.WrathEchoSeal = echoSeal
        state.EchoSwitchBackSeal = nil
        if knownInstance then
            self:ObserveVerticalSwordEcho(knownInstance, echoSeal, newlyAdded and knownInstance ~= previousInstance)
        end
    end
    if not IsSecret(spellID) and type(spellID) == "number" and spellID > 0 then
        state.WrathAuraSpellID = spellID
    end
    if not IsSecret(name) and type(name) == "string" then state.WrathAuraName = name end
    if IsSecret(count) then
        if not state.WrathCountRestricted then self:DebugMsg("Unsealed Wrath stack count is restricted; continuing hit tracking.", 3) end
        state.WrathCountRestricted = true
        if previousInstance ~= state.WrathAuraInstanceID then self:UpdateBarVisibility(true) end
        -- Aura identity is confirmed. A fallback lookup must not clear it
        -- just because this update could not supply a readable count.
        return true, false
    end
    if IsSecret(expiresAt) then expiresAt = nil end
    local snapshot = state.WrathAuraSnapshot
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
    if not tracker:Observe(count, expiresAt, state.WrathEchoSeal or state.CurrentSealName, GetTime(), refreshed) then
        if previousInstance ~= state.WrathAuraInstanceID then self:UpdateBarVisibility(true) end
        return false
    end
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
    self:UpdateThreeStackSound(tracker.count, self:IsWrathTrackingEnabled(), GetTime(), true)
    self:UpdateBarVisibility(knownInstance ~= nil)
    return true, true
end

function iST:ObserveWrathAura(updateInfo, delayed)
    if not self:HasUnsealedWrath() then return end
    local state, tracker = self.State, self.WrathTracker
    local removedCurrent = false
    local reader = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if not IsSecret(updateInfo) and type(updateInfo) == "table" then
        local readOK, added, updated, removed, full = pcall(function()
            return updateInfo.addedAuras, updateInfo.updatedAuraInstanceIDs, updateInfo.removedAuraInstanceIDs, updateInfo.isFullUpdate
        end)
        if readOK and not IsSecret(added) and type(added) == "table" then
            for _, aura in ipairs(added) do
                if IsWrathAura(aura) then
                    local newlyAdded = not IsSecret(full) and full ~= true
                    local handled, changed = self:ApplyWrathAura(aura, "UNIT_AURA addition", true, newlyAdded)
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
    if not removedCurrent and state.WrathAuraInstanceID and type(reader) == "function" then
        local ok, aura = pcall(reader, "player", state.WrathAuraInstanceID)
        if ok and not IsSecret(aura) then
            if aura == nil then
                removedCurrent = not state.InCombat
                    and not (InCombatLockdown and InCombatLockdown())
            else
                local handled, changed = self:ApplyWrathAura(aura, "cached aura instance")
                if handled then return true, changed end
            end
        end
    end
    if not removedCurrent then
        local aura, absenceKnown = self:FindWrathEchoAura()
        if aura then
            local handled, changed = self:ApplyWrathAura(aura, "Echo buff lookup")
            if handled then return true, changed end
        elseif absenceKnown and state.WrathEchoSeal and not state.InCombat
            and not (InCombatLockdown and InCombatLockdown()) then
            removedCurrent = true
        end
    end
    if removedCurrent then
        local removedID = state.WrathAuraInstanceID
        local removedSeal = state.WrathEchoSeal or tracker.seal
        state.EchoSwitchBackSeal = removedSeal and self:GetTwistStackSelection(removedSeal) == 0
            and (state.CurrentSealName == nil or state.CurrentSealName == removedSeal)
            and removedSeal or nil
        tracker:Reset()
        state.WrathAuraRevision = (state.WrathAuraRevision or 0) + 1
        state.WrathAuraInstanceID = nil
        state.WrathEchoSeal = nil
        state.WrathAuraSnapshot = nil
        local pending = state.PendingWrathRelease
        if pending and pending.auraID == removedID then self:ConfirmWrathRelease() end
        self:UpdateThreeStackSound(0, self:IsWrathTrackingEnabled(), GetTime(), true)
        self:UpdateBarVisibility()
        return true, true
    end
    if not delayed then self:ScheduleWrathAuraCheck() end
end

function iST:SetCurrentSeal(spellID, observedExpirationTime, sourceEvent)
    if IsSecret(spellID) then return end
    local name = self.SEALS[spellID]
    if not name then return end

    local previousRemaining = math.max(0, (self.State.SealExpiresAt or 0) - GetTime())
    self.State.SealStatusKnown = true
    if self.State.CurrentSealID ~= spellID or sourceEvent == "UNIT_SPELLCAST_SUCCEEDED" then
        self.State.SealAuraInstanceID = nil
    end
    self.State.CurrentSealID = spellID
    local previousSeal = self.State.CurrentSealName
    self.State.CurrentSealName = name
    if self.State.EchoSwitchBackSeal and self.State.EchoSwitchBackSeal ~= name then
        self.State.EchoSwitchBackSeal = nil
    end
    if sourceEvent == "UNIT_SPELLCAST_SUCCEEDED" then
        if previousSeal and previousSeal ~= name then
            self.State.WrathLastSwitchFrom = previousSeal
        end
        self.State.WrathLastSealCastName = name
    end
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
    self:UpdateBarVisibility()
end

function iST:ScanForActiveSealOutOfCombat(sourceEvent, preferredID)
    -- Recover a seal that was already active when the addon loaded.
    -- Keep the current seal timer while combat blocks this scan.
    if (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then return end

    local function checkSpell(spellID)
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if not ok or IsSecret(aura) then return true end
        if aura == nil then return false end
        local readable, expirationTime, instanceID = pcall(function()
            return aura.expirationTime, aura.auraInstanceID
        end)
        if not readable then return true end
        -- Keep the cast's timer if the duration cannot be read.
        if IsSecret(expirationTime) or type(expirationTime) ~= "number"
            or expirationTime <= GetTime() or expirationTime >= math.huge
            or expirationTime ~= expirationTime then return true end
        if self.State.CurrentSealName ~= self.SEALS[spellID] or self.State.SealExpiresAt ~= expirationTime then
            self:SetCurrentSeal(spellID, expirationTime, sourceEvent or "OUT_OF_COMBAT_AURA_SCAN")
        end
        if not IsSecret(instanceID) and type(instanceID) == "number" then
            self.State.SealAuraInstanceID = instanceID
        end
        return true
    end
    local currentID = self.State.CurrentSealID
    if preferredID and checkSpell(preferredID) then return end
    if currentID and currentID ~= preferredID and checkSpell(currentID) then return end
    for spellID in pairs(self.SEALS) do
        if spellID ~= currentID and spellID ~= preferredID and checkSpell(spellID) then return end
    end

    self:ClearCurrentSeal()
end

local EMPTY_AURA_CHANGES = {}

local function PlayerAuraImpact(addon, info)
    if IsSecret(info) or type(info) ~= "table" then return true, true end
    local ok, full, added, updated, removed = pcall(function()
        return info.isFullUpdate, info.addedAuras, info.updatedAuraInstanceIDs, info.removedAuraInstanceIDs
    end)
    if not ok or IsSecret(full) or full == true
        or IsSecret(added) or IsSecret(updated) or IsSecret(removed) then return true, true end
    if (added ~= nil and type(added) ~= "table") or (updated ~= nil and type(updated) ~= "table")
        or (removed ~= nil and type(removed) ~= "table")
        or (full ~= false and not added and not updated and not removed) then return true, true end

    local state = addon.State
    local seal, echo, sealSpellID = false, false, nil
    local function checkAura(aura)
        local readable, spellID = pcall(function() return aura.spellId end)
        if not readable or IsSecret(spellID) or type(spellID) ~= "number" then
            seal, echo = true, true
        elseif addon.SEALS[spellID] then
            seal, sealSpellID = true, spellID
        elseif addon.WrathEchoSpellIDs[spellID] then
            echo = true
        end
    end
    for _, aura in ipairs(added or EMPTY_AURA_CHANGES) do
        if IsSecret(aura) or type(aura) ~= "table" then return true, true end
        checkAura(aura)
    end
    local lookup = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    for _, id in ipairs(updated or EMPTY_AURA_CHANGES) do
        if IsSecret(id) or type(id) ~= "number" then return true, true end
        local knownSeal = id == state.SealAuraInstanceID
        local knownEcho = id == state.WrathAuraInstanceID
        if knownSeal or knownEcho then
            seal, echo = seal or knownSeal, echo or knownEcho
        elseif type(lookup) == "function" then
            local readOK, aura = pcall(lookup, "player", id)
            if not readOK or IsSecret(aura) then return true, true end
            if aura then checkAura(aura) end
        else
            return true, true
        end
    end
    for _, id in ipairs(removed or EMPTY_AURA_CHANGES) do
        if IsSecret(id) or type(id) ~= "number" then return true, true end
        seal = seal or id == state.SealAuraInstanceID
            or (state.CurrentSealID ~= nil and state.SealAuraInstanceID == nil)
        echo = echo or id == state.WrathAuraInstanceID or state.WrathEchoSeal ~= nil
            and state.WrathAuraInstanceID == nil
    end
    return seal, echo, sealSpellID
end

function iST:ClearCurrentSeal()
    if self.State.SealStatusKnown and not self.State.CurrentSealID and not self.State.CurrentSealName
        and not self.State.CurrentSealIcon and self.State.SealExpiresAt == 0 then return end
    self.State.SealStatusKnown = true
    self.State.CurrentSealID = nil
    self.State.SealAuraInstanceID = nil
    self.State.CurrentSealName = nil
    self.State.CurrentSealIcon = nil
    self.State.SealCastTime = 0
    self.State.SealExpiresAt = 0
    self.State.SealGeneration = (self.State.SealGeneration or 0) + 1
    self:UpdateSealDisplay()
    self:UpdateBarVisibility()
end

function iST:UpdateSealTimer(now)
    local bar = self.BarFrame
    if not bar or not bar.sealTimerText then return end

    now = now or GetTime()
    if self.State.EditMode and (self.State.EditSealExpiresAt or 0) <= now then
        self.State.EditSealExpiresAt = now + 25
    end
    local expiresAt = self.State.EditMode and self.State.EditSealExpiresAt
        or self.State.SealExpiresAt or 0
    local remaining = expiresAt - now
    local showTimer = iSTSettings.showSealTimer
        and iSTSettings.showSealIcon
        and (self.State.CurrentSealIcon or self.State.EditMode)
        and remaining > 0

    local urgent = remaining <= 5
    self:UpdateSealRing(expiresAt, showTimer, urgent)
    local displayedSeconds = showTimer and math.ceil(remaining) or nil
    if bar.sealDisplayedSeconds ~= displayedSeconds then
        bar.sealTimerText:SetText(displayedSeconds and tostring(displayedSeconds) or "")
        bar.sealDisplayedSeconds = displayedSeconds
    end
    if showTimer then
        if bar.sealTextUrgent ~= urgent then
            bar.sealTimerText:SetTextColor(1, urgent and 0.12 or 1, urgent and 0.08 or 1, 1)
            bar.sealTextUrgent = urgent
        end
        bar.nextSealDisplayAt = expiresAt - displayedSeconds + 1
    else
        bar.nextSealDisplayAt = nil
    end
    local visible = displayedSeconds ~= nil
    if bar.sealTextVisible ~= visible then
        bar.sealTimerText:SetShown(visible)
        bar.sealTextVisible = visible
    end
    self:UpdateBarAnimationDriver()
end

function iST:UpdateSealRing(expiresAt, showTimer, urgent)
    local bar = self.BarFrame
    local countdown = bar and bar.sealRingCountdown
    if not countdown then return end
    if not showTimer then
        if bar.sealRingExpiresAt then
            countdown:Clear()
            countdown:Hide()
            bar.sealRingExpiresAt, bar.sealRingUrgent = nil, nil
            bar.sealIconRing:SetVertexColor(1, 0.59, 0.09, 0.95)
        end
        return
    end

    local expiryChanged = bar.sealRingExpiresAt ~= expiresAt
    if expiryChanged then
        -- A seal recovered after login may already be partly expired. Keep its
        -- full thirty-second scale instead of drawing a fresh ring on recovery.
        local duration = self.CONSTANTS.SEAL_DURATION
        countdown:SetCooldown(expiresAt - duration, duration)
        countdown:Show()
        bar.sealRingExpiresAt = expiresAt
    end
    if expiryChanged then
        bar.sealIconRing:SetVertexColor(0.28, 0.28, 0.28, 0.95)
    end
    if bar.sealRingUrgent ~= urgent then
        if urgent then countdown:SetSwipeColor(1, 0.08, 0.05, 1)
        else countdown:SetSwipeColor(1, 0.59, 0.09, 0.95) end
        bar.sealRingUrgent = urgent
    end
end

function iST:UpdateSealDisplay()
    if not self.BarFrame then return end
    local bar = self.BarFrame

    local previewSeal = self.State.EditMode and iSTSettings.twistFromSeal or nil
    local previewIcon = previewSeal and self.SEAL_SPELL_IDS[previewSeal]
        and C_Spell.GetSpellTexture(self.SEAL_SPELL_IDS[previewSeal])
    local icon = self.State.EditMode and previewIcon or self.State.CurrentSealIcon
    if icon and iSTSettings.showSealIcon then
        bar.sealIcon:SetTexture(icon)
        bar.sealIcon:Show()
        if bar.sealIconFrame then bar.sealIconFrame:Show() end
    else
        bar.sealIcon:Hide()
        if bar.sealIconFrame then bar.sealIconFrame:Hide() end
    end

    self:UpdateSealTimer()

    if iSTSettings.showSealName and (previewSeal or self.State.CurrentSealName) then
        bar.sealText:SetText(previewSeal or self.State.CurrentSealName)
    else
        bar.sealText:SetText("")
    end
end

-- Refresh the latency label separately from the bar animation.
function iST:UpdateLatencyLabel()
    local bar = self.BarFrame
    if not bar then return end
    bar.latencyText:SetText(iSTSettings.showLatency and (self.State.HomeLag or 0) .. "ms" or "")
    bar.latencyText:SetShown(iSTSettings.showLatency)
end

function iST:UpdateLatency()
    local _, _, homeLag = GetNetStats()
    self.State.HomeLag = homeLag or 0
    self:UpdateLatencyLabel()

    C_Timer.After(iST.CONSTANTS.LATENCY_UPDATE_INTERVAL, function()
        iST:UpdateLatency()
    end)
end

-- Minimap and addon compartment button
function iST:IsLayoutUnlocked()
    return self.State.EditMode == true and not iSTSettings.barLocked
        and self.State.InCombat ~= true and not (InCombatLockdown and InCombatLockdown())
end

function iST:UpdateMoveSurfaceMouse()
    local moving = self:IsLayoutUnlocked()
    local bar = self.BarFrame
    if bar then
        pcall(bar.EnableMouse, bar, moving and bar:IsShown() and (bar.fadeTarget or 1) > 0)
        for _, frame in pairs({ bar.sealIconFrame, bar.echoTimerFrame, bar.stackCountFrame }) do
            if frame then pcall(frame.EnableMouse, frame, moving) end
        end
    end
    if self.ReminderFrames then
        for kind, frame in pairs(self.ReminderFrames) do
            local settings = iSTSettings.reminders and iSTSettings.reminders[kind]
            pcall(frame.EnableMouse, frame, moving and settings ~= nil and settings.enabled == true)
        end
    end
    if self.VerticalSwordFrame then
        local handle = self.VerticalSwordFrame.handle
        handle:EnableMouse(moving and iSTSettings.showVerticalSword == true)
    end
    if not moving then
        local center = self.CenterSwitchFrame
        if center then
            pcall(center.EnableMouse, center, false)
            if center.dragHandle then
                pcall(center.dragHandle.EnableMouse, center.dragHandle, false)
                pcall(center.dragHandle.Hide, center.dragHandle)
            end
        end
    end
end

function iST:SetBarLocked(locked, announce)
    iSTSettings.barLocked = locked == true
    if locked then self.State.ResumeEditAfterCombat = nil end
    if iSTSettings.barLocked and self.State.EditMode then
        self:StopTestMode()
    elseif not iSTSettings.barLocked and not self.State.EditMode
        and not (InCombatLockdown and InCombatLockdown()) then
        self:StartEditMode()
    end
    self:UpdateMoveSurfaceMouse()
    self:UpdateReminders()
    self:UpdateMoveOutlines()
    local checkbox = self.SettingsFrame and self.SettingsFrame.barLockCheckbox
    if checkbox then checkbox:SetChecked(not self:IsLayoutUnlocked()) end
    if self.SettingsFrame then
        local panel = self.SettingsFrame
        if panel.centerMoveButton then
            panel.centerMoveButton:SetText(self.CenterSwitchFrame and self.CenterSwitchFrame.moving
                and L["DoneMovingCenterSwitchText"] or L["MoveCenterSwitchText"])
        end
    end
    if announce then print(L[self:IsLayoutUnlocked() and "BarUnlocked" or "BarLocked"]) end
end

function iST:ToggleBarLock()
    if self.State.InCombat or (InCombatLockdown and InCombatLockdown()) then return end
    self:SetBarLocked(self:IsLayoutUnlocked(), true)
end

function iST:ToggleLayoutEdit()
    if self.State.InCombat or (InCombatLockdown and InCombatLockdown()) or not self:ShouldShowBar() then return end
    local wasEditing = self.State.EditMode == true
    self:SetBarLocked(wasEditing)
    if not wasEditing and self.State.EditMode then self:SettingsClose() end
end

function iST:CreateMinimapButton()
    local broker = LDBroker or (LibStub and LibStub("LibDataBroker-1.1", true))
    local iconLibrary = LDBIcon or (LibStub and LibStub("LibDBIcon-1.0", true))
    if not broker or not iconLibrary then return end
    if self.MinimapDataObject then return end

    self.MinimapDataObject = broker:NewDataObject("iSealTwist", {
        type = "data source",
        text = "iSealTwist",
        icon = "Interface\\AddOns\\iSealTwist\\Images\\Logo_iST",
        iconCoords = { 0.14, 0.86, 0.10, 0.82 },
        OnClick = function(_, button)
            if button == "RightButton" and IsShiftKeyDown() then
                iST:ToggleBarLock()
            elseif button == "LeftButton" then
                iST:QuickMacroToggle()
            elseif button == "RightButton" then
                iST:SettingsToggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText(Colors.iST .. "iSealTwist" .. Colors.Green .. " v" .. iST.Version, 1, 1, 1)
            tooltip:AddLine(" ", 1, 1, 1)
            tooltip:AddLine(L["MinimapLeftClick"], 1, 1, 1)
            tooltip:AddLine(L["MinimapRightClick"], 1, 1, 1)
            local unlocked = iST:IsLayoutUnlocked()
            if not iST.State.InCombat and not (InCombatLockdown and InCombatLockdown()) then
                tooltip:AddLine(L[unlocked and "MinimapShiftRightClickLock"
                    or "MinimapShiftRightClickUnlock"], 1, 1, 1)
            end
            tooltip:AddLine(" ", 1, 1, 1)
            tooltip:AddLine(L["TooltipStatus"] .. (iSTSettings.enabled and L["StatusEnabled"] or L["StatusDisabled"]), 1, 1, 1)
            tooltip:AddLine(L["TooltipPositionLock"] .. L[unlocked and "StatusPositionsUnlocked"
                or "StatusPositionsLocked"], 1, 1, 1)
            if unlocked then tooltip:AddLine(L["MinimapMoveResetHint"], 1, 1, 1) end
            tooltip:Show()
        end,
    })

    if not iSTSettings.MinimapButton then
        iSTSettings.MinimapButton = { hide = false, minimapPos = 220, showInCompartment = true }
    end
    iSTSettings.MinimapButton.showInCompartment = true
    iconLibrary:Register("iSealTwist", self.MinimapDataObject, iSTSettings.MinimapButton)
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

    local reset = iSTSettings.twistMacroResetOnCombat == false and "30" or "combat/30"
    return "#showtooltip\n/castsequence reset=" .. reset .. " " .. localizedFrom .. ", " .. localizedInto .. "\n/startattack"
end

local function NormalizeMacroBody(body)
    if type(body) ~= "string" then return nil end
    return body:gsub("\r\n", "\n"):gsub("%s+$", "")
end

local function IsManagedTwistMacro(addon, body)
    body = NormalizeMacroBody(body)
    if not body then return false end
    if body == NormalizeMacroBody(iSTSettings.generatedMacroBody) then return true end

    -- A generated account macro may be missing the ownership record on this character.
    local reset, from, into = body:match("^#showtooltip\n/castsequence reset=(%S+) ([^,\n]+), ([^\n]+)\n/startattack$")
    if reset ~= "30" and reset ~= "combat/30" then return false end
    local fromFound, intoFound = false, false
    for seal, spellID in pairs(addon.SEAL_SPELL_IDS) do
        local name = GetLocalizedSpellName(spellID, seal)
        fromFound, intoFound = fromFound or name == from, intoFound or name == into
        if fromFound and intoFound then return true end
    end
    return false
end

function iST:RefreshTwistMacro()
    if not iSTSettings then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local macroIndex = GetMacroIndexByName(TWIST_MACRO_NAME)
    if not macroIndex or macroIndex == 0 then return false end

    local _, icon, currentBody = GetMacroInfo(macroIndex)
    if not IsManagedTwistMacro(self, currentBody) then return false end

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

        if IsManagedTwistMacro(self, existingBody) then
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
function iST:StopTestMode(resumeEditAfterCombat)
    local state = self.State
    if not state.TestMode then return end
    if state.EditMode then
        state.ResumeEditAfterCombat = resumeEditAfterCombat and not iSTSettings.barLocked or nil
        state.EditMode = nil
        state.EditSealExpiresAt = nil
        if self.CenterSwitchFrame and self.CenterSwitchFrame.moving then
            pcall(self.SetCenterSwitchMoveMode, self, false)
        end
    end
    self:ClearParryAnimation()
    state.TestMode, state.StackTestMode, state.PreviewStacks = false, false, 0
    if self.UpdateLayoutControls then self:UpdateLayoutControls() end
    state.TestModeGeneration = state.TestModeGeneration + 1
    -- Return to the real swing timing without touching the live stack tracker.
    local saved = state.TestSwingSnapshot
    if saved then
        state.WeaponSpeed, state.LastSwingTime, state.NextSwingTime = saved[1], saved[2], saved[3]
        state.TestSwingSnapshot = nil
    end
    self:InvalidateBarState()
    self:UpdateSealDisplay()
    self:UpdateWrathDisplay()
    self:UpdateBarVisibility()
    self:UpdateMoveSurfaceMouse()
    self:UpdateReminders()
    self:UpdateMoveOutlines()
end

local function StartBarTest(stackPreview)
    local state = iST.State
    if state.EditMode then iST:StopTestMode() end
    iST:ClearParryAnimation()
    if not state.TestMode then
        state.TestSwingSnapshot = { state.WeaponSpeed, state.LastSwingTime, state.NextSwingTime }
    end
    -- An older preview's timeout must not stop a more recently started preview.
    state.TestModeGeneration = (state.TestModeGeneration or 0) + 1
    local generation = state.TestModeGeneration
    state.StackTestMode = stackPreview == true
    state.PreviewStacks = 0
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

function iST:StartEditMode()
    if not iSTSettings.enabled or not self.BarFrame or self.State.InCombat then return end
    local state = self.State
    if state.EditMode then return end
    if not state.TestMode then
        state.TestSwingSnapshot = { state.WeaponSpeed, state.LastSwingTime, state.NextSwingTime }
    end
    state.TestModeGeneration = (state.TestModeGeneration or 0) + 1
    state.TestMode, state.StackTestMode, state.EditMode = true, true, true
    if self.UpdateLayoutControls then self:UpdateLayoutControls() end
    state.PreviewStacks = 2
    state.EditSealExpiresAt = GetTime() + 25
    state.WeaponSpeed = 3.6
    state.LastSwingTime = GetTime()
    state.NextSwingTime = GetTime() + 3.6
    self:ShowBar()
    self:UpdateSealDisplay()
    self:UpdateWrathDisplay()
    if iSTSettings.showCenterSwitchText then self:SetCenterSwitchMoveMode(true) end
    self:UpdateReminders()
    self:UpdateMoveSurfaceMouse()
    self:UpdateMoveOutlines()
end

function iST:StartTestMode()
    StartBarTest(false)
end

function iST:StartStackTestMode()
    StartBarTest(true)
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
        elseif cmd == "soundcheck" then
            iST:CheckCueSound(argument)
        elseif cmd == "settings" or cmd == "options" or cmd == "config" then
            iST:SettingsToggle()
        elseif cmd == "new" or cmd == "news" then
            iST:OpenWhatsNew()
        elseif cmd == "lock" then
            iST:ToggleBarLock()
        elseif cmd == "edit" then
            iST:ToggleLayoutEdit()
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
            print(L["SlashHelpEdit"])
            print(L["SlashHelpWhatsNew"])
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

    if event == "PLAYER_LOGOUT" then
        if iST.SaveActiveProfile then iST:SaveActiveProfile() end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        local combat = InCombatLockdown and InCombatLockdown()
        if not IsSecret(combat) then
            iST.State.InCombat = combat == true
            iST:UpdateBarVisibility()
        end
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
            -- A real swing can arrive before the combat start event.
            iST:StopTestMode(true)
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
        iST:UpdateNameplateEchoDisplay()
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        if iSTSettings.showNameplateEcho then iST:UpdateNameplateEchoDisplay() end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        iST.State.InCombat = true
        iST:StopTestMode(true)
        iST:UpdateMoveSurfaceMouse()

        iST:UpdateBarVisibility()

        if iST.SettingsFrame and iST.SettingsFrame:IsShown() then
            iST.SettingsFrame:Hide()
        end
        if iST.QuickMacroFrame and iST.QuickMacroFrame:IsShown() then
            iST.QuickMacroFrame:Hide()
        end
        if iST.WhatsNewFrame and iST.WhatsNewFrame:IsShown() then
            iST.State.PendingWhatsNew = true
            iST.WhatsNewFrame:Hide()
        end
        if iST.ProfileTransferFrame and iST.ProfileTransferFrame:IsShown() then
            iST.ProfileTransferFrame:Hide()
        end
        return
    end

    if event == "UPDATE_MACROS" then
        iST:ScheduleTwistMacroCheck()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        iST.State.InCombat = false
        iST:UpdateMoveSurfaceMouse()
        iST.State.CenterSwitchPhaseBlocked = nil
        -- Stored seals remain available through short combat breaks.
        if iSTSettings.debugMode then
            iST.WrathTracker:GetCount(GetTime())
        end
        iST:ScanForActiveSealOutOfCombat("PLAYER_REGEN_ENABLED")
        iST:ObserveWrathAura()
        iST:UpdateBarVisibility()
        iST:CreateStackManagedDisplay()
        if iST.State.PendingStackCounterColor then iST:ApplyStackCounterColor() end
        if iST.State.PendingStackStageFormatter then iST:ApplyStackStageFormatter() end
        if iST.State.PendingStackTypography then iST:ApplyBarTypography() end
        if iST.State.PendingWrathCircleSize then iST:ApplyWrathCircleSize() end
        if iST.State.PendingMacroRefresh then
            iST:RequestTwistMacroRefresh()
        end
        if iST.State.PendingWhatsNew and iST.MaybeShowWhatsNew then
            iST:MaybeShowWhatsNew()
        end
        if iST.State.ResumeEditAfterCombat then
            iST.State.ResumeEditAfterCombat = nil
            if not iSTSettings.barLocked and iST:ShouldShowBar() then iST:SetBarLocked(false) end
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if not IsSecret(unit) and unit == "player" then
            local scanSeal, scanEcho, sealSpellID = PlayerAuraImpact(iST, updateInfo)
            if scanSeal then iST:ScanForActiveSealOutOfCombat("UNIT_AURA", sealSpellID) end
            if scanEcho and iST:IsWrathTrackingEnabled() then
                local _, changed = iST:ObserveWrathAura(updateInfo)
                if not changed then iST:RequestWrathDisplayUpdate() end
            end
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
        iST.State.PendingWrathRelease = nil
        iST.State.WrathUnleashedUntil = nil
        iST.State.WrathAuraInstanceID = nil
        iST.State.WrathEchoSeal = nil
        iST.State.EchoSwitchBackSeal = nil
        iST.State.WrathLastSealCastName = nil
        iST.State.WrathLastSwitchFrom = nil
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
    "PLAYER_LOGOUT",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SWING",
    "UNIT_COMBAT",
    "PLAYER_TARGET_CHANGED",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
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
    if self.ReconcileActiveProfileOnLoad then self:ReconcileActiveProfileOnLoad() end
    local combat = InCombatLockdown and InCombatLockdown()
    if not IsSecret(combat) then self.State.InCombat = combat == true end
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
    self:UpdateMoveSurfaceMouse()

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

    C_Timer.After(4, function()
        if iST.State.Initialized and iST.MaybeShowWhatsNew then
            iST:MaybeShowWhatsNew()
        end
    end)

    -- Check the talent and active buffs again after the player UI has loaded.
    C_Timer.After(1, function()
        if iST.State.Initialized then
            iST:RefreshUnsealedWrathState()
            iST:ScanForActiveSealOutOfCombat("PLAYER_LOGIN")
            iST:ObserveWrathAura()
            iST:CreateStackManagedDisplay()
        end
    end)
end
