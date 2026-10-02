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

L["NotPaladin"] = Msg("Only active for Paladins. Disable 'Only As Paladin' in settings to override.")
L["BarEnabled"] = Msg("Swing timer " .. Colors.Green .. "enabled" .. Colors.iST .. ".")
L["BarDisabled"] = Msg("Swing timer " .. Colors.Red .. "disabled" .. Colors.iST .. ".")
L["BarLocked"] = Msg("Bar " .. Colors.Green .. "locked" .. Colors.iST .. ".")
L["BarUnlocked"] = Msg("Bar " .. Colors.Yellow .. "unlocked" .. Colors.iST .. ". Drag to reposition.")
L["BarReset"] = Msg("Bar position reset to center.")
L["TestStarted"] = Msg("Test mode: simulating a " .. Colors.Yellow .. "3.6s" .. Colors.iST .. " swing.")
L["MacroUpdated"] = "Macro updated with %s, %s."
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
L["TabTiming"] = "Timing"
L["TabIndicators"] = "Indicators"
L["TabCustomization"] = "Customization"
L["TabAbout"] = "About"
L["SidebarOtherAddons"] = "Other Addons"
L["None"] = "None"

-- General
L["SectionActivation"] = Colors.iST .. "Activation"

-- Bar size
L["SectionBarAppearance"] = Colors.iST .. "Bar Size"
L["BarWidth"] = "Bar Width"
L["BarHeight"] = "Bar Height"

L["ShowLatency"] = "Show Latency"
L["ShowLatencyDesc"] = Colors.Gray .. "Display current home latency on the bar.|r"
L["SectionTimingGuides"] = Colors.iST .. "Swing Timer"

-- Display
L["ShowSealIcon"] = "Show Seal Icon"
L["ShowSealIconDesc"] = Colors.Gray .. "Display the active seal icon next to the bar.|r"
L["ShowWeaponSpeed"] = "Show Weapon Speed"
L["ShowWeaponSpeedDesc"] = Colors.Gray .. "Display weapon speed on the bar.|r"
L["OnlyInCombat"] = "Only Show In Combat"
L["OnlyInCombatDesc"] = Colors.Gray .. "Hide the bar when out of combat.|r"
L["OnlyAsPaladin"] = "Only Active As Paladin"
L["OnlyAsPaladinDesc"] = Colors.Gray .. "Only activate the addon on Paladin characters.|r"
L["ShowTwistSuccess"] = "Show 'Seal Twisted!' Text"
L["ShowTwistSuccessDesc"] = Colors.Gray .. "Show green text when Twist of Light creates an Echo between melee attacks.|r"

-- Indicator sub-sections
L["SectionBarInformation"] = Colors.iST .. "Bar Information"
L["SectionTwistFeedback"] = Colors.iST .. "Twist Feedback"
L["SectionSealPair"] = Colors.iST .. "Seal Pair"

-- Seal pair dropdowns
L["TwistFromSeal"] = "Echo Seal (From)"
L["TwistFromSealDesc"] = Colors.Gray .. "The eligible seal your QoL macro replaces. Twist of Light supports Command, Righteousness, Fury, and Justice.|r"
L["TwistIntoSeal"] = "Replacement Seal (Into)"
L["TwistIntoSealDesc"] = Colors.Gray .. "The different seal your QoL macro switches into. This pair only configures the macro; detection accepts every valid replacement.|r"
L["SealPairDesc"] = Colors.Gray .. "Green seals can create an Echo when replaced, so a pair of two green seals works in either direction. Orange seals can only be used as the destination. This pair configures the optional SealTwist macro.|r"

-- Twist text customization
L["SectionTextAppearance"] = Colors.iST .. "Text"
L["TwistTextSize"] = "Twist Text Size"
L["IconSize"] = "Seal Icon Size"
L["CurrentSealTextSize"] = "Current Seal Text Size"
L["LatencyTextSize"] = "Latency Text Size"
L["BarFont"] = "Bar Font"

-- Bar colors section
L["SectionBarColors"]   = Colors.iST .. "Bar Colors"
L["DefaultColors"]      = "Default Colors"
L["ColorBar"]           = "Fill"
L["ColorBorderNormal"]  = "Border"
L["ColorTwistSuccess"]  = "Twist Success Text"

-- Position
L["SectionPosition"] = Colors.iST .. "Position"
L["LockBar"] = "Lock Bar Position"
L["LockBarDesc"] = Colors.Gray .. "Prevent the bar from being dragged.|r"
L["ResetPosition"] = "Reset Position"
L["TestBar"] = "Test Bar"

-- About
L["AboutText"] = Colors.iST .. "iSealTwist " .. Colors.Reset .. "is a WoW Forever Paladin weapon-swing timer. With Twist of Light learned, it reports successful Echo creation when an eligible seal is replaced between melee attacks."
L["CreatedBy"] = "Created by: "
L["ISTCurseForgeLink"] = "Available on CurseForge: curseforge.com/wow/addons/isealtwist"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Other Addon Tabs                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
L["TabIWR"] = "iWR Settings"
L["TabIWRPromo"] = "iWillRemember"
L["TabINIF"] = "iNIF Settings"
L["TabINIFPromo"] = "iNeedIfYouNeed"
L["TabIRC"] = "iRC Panel"
L["TabIRCPromo"] = "iRC: Guild Connect"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Other Addon Promos                                │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
L["IWRPromoDesc"] = Colors.iST .. "iWillRemember " .. Colors.Reset .. "is a player notes addon. Track, rate, and share notes about players with your friends. Never forget a ninja looter again."
L["IWRPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/iwillremember"
L["INIFPromoDesc"] = Colors.iST .. "iNeedIfYouNeed " .. Colors.Reset .. "is a smart loot addon. Automatic need/greed rolling with party coordination. Don't let them ninja without needing back."
L["INIFPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/ineedifyouneed"
L["IRCPromoDesc"] = Colors.iST .. "iRC: Guild Connect " .. Colors.Reset .. "connects guild members through shared rules, verification, guild statistics, professions, and community tools."
L["IRCPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/ircguildconnect"
