local addonName, addon = ...

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                     Colors                                     │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local Colors = {
    -- Addon Brand Color
    iST = "|cffff9716",

    -- Standard Colors
    White = "|cFFFFFFFF",
    Red = "|cFFFF0000",
    Green = "|cFF00FF00",
    Yellow = "|cFFFFFF00",
    Orange = "|cFFFFA500",
    Gray = "|cFF808080",
    Cyan = "|cFF00FFFF",

    -- WoW Class Colors
    Classes = {
        PALADIN = "|cFFF58CBA",
    },

    -- Reset
    Reset = "|r",
}

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Localization Table Setup                              │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
local L = {}
addon.L = L
addon.Colors = Colors

-- Fallback: Return key if translation missing
setmetatable(L, {__index = function(t, k)
    return k
end})

-- Helper for consistent message formatting
local function Msg(message)
    return Colors.iST .. "[iST]: " .. message
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                 Chat Messages                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
L["PrintPrefix"] = Colors.iST .. "[iST]: "
L["DebugInfo"] = Colors.iST .. "[iST]: " .. Colors.White .. "INFO: " .. Colors.Reset .. Colors.iST
L["DebugWarning"] = Colors.iST .. "[iST]: " .. Colors.Yellow .. "WARNING: " .. Colors.Reset .. Colors.iST
L["DebugError"] = Colors.iST .. "[iST]: " .. Colors.Red .. "ERROR: " .. Colors.Reset .. Colors.iST

L["AddonLoaded"] = Msg(Colors.iST .. "iSealTwist " .. Colors.Green .. "v%s" .. Colors.Reset .. " Loaded.")
L["NotPaladin"] = Msg("Only active for Paladins. Disable 'Only As Paladin' in settings to override.")
L["UnsupportedVersion"] = "iSealTwist is designed for Anniversary TBC only. Detected: %s. The swing timer and seal twist features are disabled."
L["BarEnabled"] = Msg("Swing timer " .. Colors.Green .. "enabled" .. Colors.iST .. ".")
L["BarDisabled"] = Msg("Swing timer " .. Colors.Red .. "disabled" .. Colors.iST .. ".")
L["BarLocked"] = Msg("Bar " .. Colors.Green .. "locked" .. Colors.iST .. ".")
L["BarUnlocked"] = Msg("Bar " .. Colors.Yellow .. "unlocked" .. Colors.iST .. ". Drag to reposition.")
L["BarReset"] = Msg("Bar position reset to center.")
L["TestStarted"] = Msg("Test mode: simulating a " .. Colors.Yellow .. "3.6s" .. Colors.iST .. " swing.")
L["MinimapLeftClick"] = (Colors.Yellow .. "Left Click: " .. Colors.Orange .. "Enable/Disable")
L["MinimapShiftLeftClick"] = (Colors.Yellow .. "Shift-Left Click: " .. Colors.Orange .. "Toggle Bar Lock")
L["MinimapRightClick"] = (Colors.Yellow .. "Right Click: " .. Colors.Orange .. "Open Settings")

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                               Slash Command Help                               │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
L["SlashHelp1"] = Colors.iST .. "iSealTwist Commands:"
L["SlashHelp2"] = Colors.Yellow .. "  /ist settings" .. Colors.Reset .. " — Open settings panel"
L["SlashHelp3"] = Colors.Yellow .. "  /ist lock" .. Colors.Reset .. " — Toggle bar lock"
L["SlashHelp4"] = Colors.Yellow .. "  /ist reset" .. Colors.Reset .. " — Reset bar position"
L["SlashHelp5"] = Colors.Yellow .. "  /ist test" .. Colors.Reset .. " — Simulate a swing for testing"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                                Settings Panel                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
L["SettingsTitle"] = Colors.iST .. "iSealTwist — Settings"

-- Sidebar
L["TabGeneral"] = "General"
L["TabDisplay"] = "Display"
L["TabAbout"] = "About"
L["SidebarOtherAddons"] = "Other Addons"

-- Bar Appearance
L["SectionBarAppearance"] = Colors.iST .. "Bar Appearance"
L["BarWidth"] = "Bar Width"
L["BarHeight"] = "Bar Height"

-- Twist Timing
L["SectionTwistTiming"] = Colors.iST .. "Twist Timing"
L["TwistWindow"] = "Twist Window (ms)"
L["TwistWindowDesc"] = Colors.Gray .. "Time before swing to start the twist. Default: 400ms.|r"
L["ShowLatency"] = "Show Latency"
L["ShowLatencyDesc"] = Colors.Gray .. "Display current home latency on the bar.|r"

-- Display
L["ShowSealIcon"] = "Show Seal Icon"
L["ShowSealIconDesc"] = Colors.Gray .. "Display the active seal icon next to the bar.|r"
L["ShowWeaponSpeed"] = "Show Weapon Speed"
L["ShowWeaponSpeedDesc"] = Colors.Gray .. "Display weapon speed on the bar.|r"
L["OnlyInCombat"] = "Only Show In Combat"
L["OnlyInCombatDesc"] = Colors.Gray .. "Hide the bar when out of combat.|r"
L["OnlyAsPaladin"] = "Only Active As Paladin"
L["OnlyAsPaladinDesc"] = Colors.Gray .. "Only activate the addon on Paladin characters.|r"
L["OnlyInRetSpec"] = "Only Active In Retribution Spec"
L["OnlyInRetSpecDesc"] = Colors.Gray .. "Automatically hide the bar when you are in Holy or Protection spec. Detected by which talent tree has the most points.|r"
L["ShowTwistSuccess"] = "Show 'Seal Twisted!' Text"
L["ShowTwistSuccessDesc"] = Colors.Gray .. "Show green text on the bar when a twist is successful.|r"
L["ShowTwistFail"] = "Show 'Fail Twist!' Text"
L["ShowTwistFailDesc"] = Colors.Gray .. "Show red text on the bar when a twist fails (too late).|r"

-- Display sub-sections
L["SectionVisibility"] = Colors.iST .. "Visibility"
L["SectionTwistFeedback"] = Colors.iST .. "Twist Feedback"
L["SectionSealPair"] = Colors.iST .. "Seal Pair"

-- Seal pair dropdowns
L["TwistFromSeal"] = "Seal to Twist"
L["TwistFromSealDesc"] = Colors.Gray .. "The seal you normally have active (the one you cast FROM). Must be Seal of Command or Seal of Righteousness.|r"
L["TwistIntoSeal"] = "Seal to Twist Into"
L["TwistIntoSealDesc"] = Colors.Gray .. "The seal you switch to inside the twist window (e.g. Seal of Blood / Seal of the Martyr).|r"

-- GCD indicator & wrong seal warning
L["ShowGCDIndicator"] = "Show GCD Indicator"
L["ShowGCDIndicatorDesc"] = Colors.Gray .. "Show a gold marker line on the bar one GCD (1.5s) before the twist window opens — this is when to press your twist macro.|r"
L["ShowWrongSealWarning"] = "Show Wrong Seal Warning"
L["ShowWrongSealWarningDesc"] = Colors.Gray .. "Highlight the bar in red when you are not on either of your configured twist seals.|r"

-- Pulse indicators
L["SectionPulseIndicators"] = Colors.iST .. "Pulse Indicators"
L["ShowGreenPulse"] = "Green Pulse — Seal1 + Twist Window + GCD Free"
L["ShowGreenPulseDesc"] = Colors.Gray .. "Pulse green when Seal1 is active, you are inside the twist window, and GCD is available — cast Seal2 now.|r"
L["ShowOrangePulse"] = "Orange Pulse — Seal2 Active"
L["ShowOrangePulseDesc"] = Colors.Gray .. "Pulse orange when Seal2 (twist into seal) is active — twist completed, waiting for swing.|r"
L["ShowRedPulse"] = "Red Pulse — GCD Runs Past Swing"
L["ShowRedPulseDesc"] = Colors.Gray .. "Pulse red when Seal1 is active but the active GCD will not expire before the swing — too late to twist.|r"

-- Twist text customization
L["TwistTextSize"] = "Twist Text Size"

-- Bar colors section
L["SectionBarColors"]   = Colors.iST .. "Bar Colors"
L["ColorBar"]           = "Fill"
L["ColorTwistZone"]     = "Twist Zone Fill"
L["ColorAlert"]         = "Alert (Wrong Seal)"
L["ColorGCDZone"]       = "GCD Zone"
L["ColorTwistMarker"]   = "Twist Marker Line"
L["ColorGCDMarker"]     = "GCD Marker Line"
L["ColorBorderNormal"]  = "Border"
L["ColorTwistSuccess"]  = "Twist Success Text"
L["ColorTwistFail"]     = "Twist Fail Text"

-- Position
L["SectionPosition"] = Colors.iST .. "Position"
L["LockBar"] = "Lock Bar Position"
L["LockBarDesc"] = Colors.Gray .. "Prevent the bar from being dragged.|r"
L["ResetPosition"] = "Reset Position"
L["TestBar"] = "Test Bar"

-- About
L["AboutText"] = Colors.iST .. "iSealTwist " .. Colors.Reset .. "is a seal twist timing helper for TBC Paladins. It tracks your weapon swing timer and shows the optimal window to twist seals for maximum DPS."
L["CreatedBy"] = "Created by: "
L["ISTCurseForgeLink"] = "Available on CurseForge: curseforge.com/wow/addons/isealtwist"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Other Addon Tabs                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
L["TabIWR"] = "iWR Settings"
L["TabIWRPromo"] = "iWillRemember"
L["TabISP"] = "iSP Settings"
L["TabISPPromo"] = "iSoundPlayer"
L["TabICC"] = "iCC Settings"
L["TabICCPromo"] = "iCommunityChat"
L["TabINIF"] = "iNIF Settings"
L["TabINIFPromo"] = "iNeedIfYouNeed"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Other Addon Promos                                │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
L["IWRPromoDesc"] = Colors.iST .. "iWillRemember " .. Colors.Reset .. "is a player notes addon. Track, rate, and share notes about players with your friends. Never forget a ninja looter again."
L["IWRPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/iwillremember"
L["ISPPromoDesc"] = Colors.iST .. "iSoundPlayer " .. Colors.Reset .. "is a custom sound addon. Play your own sounds on game events, spell cooldowns, and buff changes. Your game, your sounds."
L["ISPPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/isoundplayer"
L["ICCPromoDesc"] = Colors.iST .. "iCommunityChat " .. Colors.Reset .. "is a cross-guild community chat addon. Chat across guilds with a shared channel and roster."
L["ICCPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/icommunitychat"
L["INIFPromoDesc"] = Colors.iST .. "iNeedIfYouNeed " .. Colors.Reset .. "is a smart loot addon. Automatic need/greed rolling with party coordination. Don't let them ninja without needing back."
L["INIFPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/ineedifyouneed"
