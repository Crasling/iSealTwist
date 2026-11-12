local addonName, addon = ...

-- Colors
local Colors = {
    -- Addon color
    iST = "|cffff9716",

    -- Shared text colors
    White = "|cFFFFFFFF",
    Red = "|cFFFF0000",
    Green = "|cFF00FF00",
    Yellow = "|cFFFFFF00",
    Orange = "|cFFFFA500",
    Gray = "|cFF808080",
    Cyan = "|cFF00FFFF",

    -- Class colors
    Classes = {
        PALADIN = "|cFFF58CBA",
    },

    Reset = "|r",
}

-- English text and shared colors
local L = {}
addon.L = L
addon.Colors = Colors

-- Show the key when a translation is missing, so the label is still visible.
setmetatable(L, {__index = function(t, k)
    return k
end})

-- Use the same addon prefix for player-facing messages.
local function Msg(message)
    return Colors.iST .. "[iST]: " .. message
end

-- Chat messages
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
L["StackTestStarted"] = Msg("Test mode: building three stored Seal stacks.")
L["WrathReleased"] = "Seals unleashed!"
L["WrathCounter"] = "%d / 3"
L["WrathCounterReady"] = "%d / 3 - %s"
L["MacroUpdated"] = "Macro updated with %s, %s."
L["MinimapLeftClick"] = (Colors.Yellow .. "Left Click: " .. Colors.Orange .. "Enable/Disable")
L["MinimapShiftLeftClick"] = (Colors.Yellow .. "Shift-Left Click: " .. Colors.Orange .. "Toggle Bar Lock")
L["MinimapRightClick"] = (Colors.Yellow .. "Right Click: " .. Colors.Orange .. "Open Settings")
L["TooltipStatus"] = Colors.Yellow .. "Status: " .. Colors.Reset
L["StatusEnabled"] = Colors.Green .. "Swing timer enabled" .. Colors.Reset
L["StatusDisabled"] = Colors.Red .. "Swing timer disabled" .. Colors.Reset

-- Slash command help
L["SlashHelp1"] = Colors.iST .. "iSealTwist Commands:"
L["SlashHelp2"] = Colors.Yellow .. "  /ist settings" .. Colors.Reset .. " — Open settings panel"
L["SlashHelp3"] = Colors.Yellow .. "  /ist lock" .. Colors.Reset .. " — Toggle bar lock"
L["SlashHelp4"] = Colors.Yellow .. "  /ist reset" .. Colors.Reset .. " — Reset bar position"
L["SlashHelp5"] = Colors.Yellow .. "  /ist test" .. Colors.Reset .. " — Simulate a swing for testing"

-- Settings panel
L["SettingsTitle"] = Colors.iST .. "iSealTwist — Settings"
L["SettingsLabel"] = "Settings"
L["SettingsSavedAutomatically"] = "Changes are saved automatically."
L["SettingsGeneralSummary"] = "Choose your seals, macro and when the swing timer appears."
L["SettingsTimingSummary"] = "Adjust the swing bar size and latency display."
L["SettingsIndicatorsSummary"] = "Choose the information and stack cues shown on the bar."
L["SettingsCustomizationSummary"] = "Adjust fonts, colors and previews."
L["SettingsRemindersSummary"] = "Configure seal and Righteous Fury reminders."
L["SettingsAboutSummary"] = "Addon information and testing options."
L["SettingsCompanionSummary"] = "Information and settings for this addon."

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
L["ShowSealTimer"] = "Show Seal Timer"
L["ShowSealTimerDesc"] = Colors.Gray .. "Show the seal's remaining time inside its icon and on a ring that drains into gray.|r"
L["ShowWeaponSpeed"] = "Show Weapon Speed"
L["ShowWeaponSpeedDesc"] = Colors.Gray .. "Display weapon speed on the bar.|r"
L["OnlyInCombat"] = "Only Show In Combat"
L["OnlyInCombatDesc"] = Colors.Gray .. "Hide the bar when out of combat.|r"
L["OnlyAsPaladin"] = "Only Active As Paladin"
L["OnlyAsPaladinDesc"] = Colors.Gray .. "Only activate the addon on Paladin characters.|r"
L["ShowTwistSuccess"] = "Show Release Text"
L["ShowTwistSuccessDesc"] = Colors.Gray .. "Show feedback when an attack with a different seal releases stored stacks.|r"

-- Indicator sub-sections
L["SectionBarInformation"] = Colors.iST .. "Bar Information"
L["SectionUnsealedWrath"] = Colors.iST .. "Unsealed Wrath"
L["WrathCueStyle"] = "Stack Indicator"
L["WrathCueBarColor"] = "Swing Bar Colors"
L["WrathCueSwordImages"] = "Sword Images"
L["WrathCueCircles"] = "Glowing Circles"
L["WrathCueCounter"] = "Stack Counter"
L["WrathCueText"] = "Ready Text"
L["WrathCueOff"] = "Off"
L["WrathCueDesc"] = Colors.Gray .. "Requires Unsealed Wrath. Stored seals last 15 seconds. Show stacks through swing bar colors, sword images, circles, a counter, or a ready message.|r"
L["ShowPlayerWrathBubbles"] = "Show Stacks Below Player Mana"
L["ShowPlayerWrathBubblesDesc"] = Colors.Gray .. "Show a separate frame with three stack bubbles below the standard player mana bar. Uses your stack colors and works alongside any swing-timer cue.|r"
L["WrathReadyText"] = "Ready Message"
L["WrathAttackNow"] = "Attack now"
L["WrongSeal"] = "Wrong seal"
L["WrathTrackingDesc"] = Colors.Gray .. "Tracks stacks from main-hand swings and hit feedback, then corrects them from the buff when readable. Misses, dodges and parries can briefly affect the displayed count.|r"
L["SectionSealPair"] = Colors.iST .. "Seal Pair"

-- Seal pair dropdowns
L["TwistFromSeal"] = "Build-up Seal (From)"
L["TwistFromSealDesc"] = Colors.Gray .. "The seal your optional macro starts with. Build stored stacks before switching to the other seal.|r"
L["TwistIntoSeal"] = "Release Seal (Into)"
L["TwistIntoSealDesc"] = Colors.Gray .. "The different seal your macro switches into. An attack with that seal releases stored stacks.|r"
L["SealStackMode"] = "Stacking Mode"
L["SealStackAlternate"] = "Back and forth"
L["SealStackFromOnly"] = "Always stack From"
L["SealPairLegend"] = "Build stacks on either seal, then switch to release them."
L["SealPairFromOnlyLegend"] = "Build stacks on From, release with Into, then return to From. Shows Wrong seal until you return."
L["SealPairDesc"] = Colors.Gray .. "Choose the seals for your optional SealTwist macro and preferred stack buildup. Cast seals yourself; iST provides reminders.|r"
L["OpenMacros"] = "Open Macros"
L["MacroWindowCombatBlocked"] = Msg("The macro window cannot be opened during combat.")

-- Twist text customization
L["SectionTextAppearance"] = Colors.iST .. "Text"
L["TwistTextSize"] = "Release Text Size"
L["IconSize"] = "Seal Icon Size"
L["CurrentSealTextSize"] = "Current Seal Text Size"
L["LatencyTextSize"] = "Latency Text Size"
L["BarFont"] = "Bar Font"

-- Bar colors section
L["SectionBarColors"]   = Colors.iST .. "Bar Colors"
L["DefaultColors"]      = "Default Colors"
L["ColorBar"]           = "Fill"
L["ColorBorderNormal"]  = "Border"
L["ColorTwistSuccess"]  = "Release Text"
L["SectionStackColors"] = Colors.iST .. "Stack Colors"
L["WrathColorScheme"] = "Color Scheme"
L["WrathSchemeGold"] = "Gold"
L["WrathSchemeTraffic"] = "Red to Green"
L["WrathSchemeBlue"] = "Blue to Cyan"
L["WrathSchemeCustom"] = "Custom"
L["WrathStageColor"] = "%d / 3 stacks"
L["WrathStageColorsDesc"] = Colors.Gray .. "Choose a scheme or customize each stack stage. Colors apply to the swing bar, sword images, circles, counter, ready text, and player-frame bubbles. Editing a color switches to Custom; only sword images replace the normal border.|r"

-- Position
L["SectionPosition"] = Colors.iST .. "Position"
L["SectionPreview"] = Colors.iST .. "Bar Preview"
L["PreviewSequenceDesc"] = Colors.Gray .. "Preview each bar state in its normal gameplay order.|r"
L["LockBar"] = "Lock Bar Position"
L["LockBarDesc"] = Colors.Gray .. "Prevent the bar from being dragged.|r"
L["CenterHorizontally"] = "Center Horizontally"
L["ResetPosition"] = "Reset Position"
L["TestBar"] = "Test Bar"
L["TestStackBar"] = "Test Stack Buildup"
L["TestTwistSuccess"] = "Test Release"
L["PreviewNormal"] = "1. Normal"
L["PreviewStacks"] = "2. Build Stacks"
L["PreviewSuccess"] = "3. Release"
L["PreviewParryHaste"] = "Test Parry Haste"

-- Separate buff reminders
L["TabReminders"] = "Reminders"
L["ReminderFury"] = "Righteous Fury"
L["ReminderSeal"] = "Seal"
L["RemindersDesc"] = Colors.Gray .. "Show a reminder when a buff is missing or running out. Set the warning time to 0 for missing buffs only. Each reminder has its own size and position. Preview / Move lets you drag it for 30 seconds; click again to stop.|r"
L["ReminderEnable"] = "Enable Reminder"
L["ReminderProtOnly"] = "Only with Protection Talents"
L["ReminderProtOnlyDesc"] = Colors.Gray .. "Show only when Protection has more points than either other talent tree.|r"
L["ReminderDungeonsOnly"] = "Dungeons / Raids Only"
L["ReminderDungeonsOnlyDesc"] = Colors.Gray .. "Show only inside a dungeon or raid instance. Battlegrounds are excluded.|r"
L["ReminderPartyOnly"] = "Party / Raid Only"
L["ReminderPartyOnlyDesc"] = Colors.Gray .. "Show only while in a party or raid group.|r"
L["ReminderHideAfterIdle"] = "Hide After 5 Minutes Out of Combat"
L["ReminderHideAfterIdleDesc"] = Colors.Gray .. "Hide the seal reminder after five minutes without combat. It returns when combat starts.|r"
L["ReminderHideInCapitals"] = "Hide in Friendly Capital Cities"
L["ReminderHideInCapitalsDesc"] = Colors.Gray .. "Hide the seal reminder in your faction's capital cities. Enemy capitals still show it.|r"
L["ReminderThreshold"] = "Warn with Time Left"
L["ReminderMissingOnly"] = "Missing only"
L["ReminderSeconds"] = "%d seconds"
L["ReminderShowIcon"] = "Show Icon"
L["ReminderShowTime"] = "Show Time Left"
L["ReminderScale"] = "Reminder Scale"
L["ReminderLock"] = "Lock Position"
L["ReminderPreviewMove"] = "Preview / Move"
L["ReminderPreview"] = "Drag to move"
L["ReminderCastBuff"] = "Cast %s"
L["ReminderCastSeal"] = "Cast a seal"
L["ReminderRefreshBuff"] = "Refresh %s"
L["ReminderSwitchSeal"] = "Switch to %s"
L["ReminderTimeLeft"] = "%s left"

-- About
L["SectionTesting"] = Colors.iST .. "Testing"
L["DebugMode"] = "Debug Mode"
L["FakeUnsealedWrath"] = "Fake Unsealed Wrath"
L["TestingDesc"] = Colors.Gray .. "Debug Mode shows diagnostics. Fake Unsealed Wrath lets iST track stacks without the talent; it does not grant the talent in-game. Attack with an active seal or use the stack preview to test your cues.|r"
L["AboutText"] = Colors.iST .. "iSealTwist " .. Colors.Reset .. "is a WoW Forever Paladin weapon-swing timer. With Unsealed Wrath learned, it tracks stored Seal stacks and shows when three stacks are ready for a seal switch."
L["CreatedBy"] = "Created by: "
L["ISTCurseForgeLink"] = "Available on CurseForge: curseforge.com/wow/addons/isealtwist"

-- Other addon tabs
L["TabIWR"] = "iWR Settings"
L["TabIWRPromo"] = "iWillRemember"
L["TabINIF"] = "iNIF Settings"
L["TabINIFPromo"] = "iNeedIfYouNeed"
L["TabIRC"] = "iRC Panel"
L["TabIRCPromo"] = "iRC: Guild Connect"

-- Other addon descriptions
L["IWRPromoDesc"] = Colors.iST .. "iWillRemember " .. Colors.Reset .. "is a player notes addon. Track, rate, and share notes about players with your friends. Never forget a ninja looter again."
L["IWRPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/iwillremember"
L["INIFPromoDesc"] = Colors.iST .. "iNeedIfYouNeed " .. Colors.Reset .. "is a smart loot addon. Automatic need/greed rolling with party coordination. Don't let them ninja without needing back."
L["INIFPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/ineedifyouneed"
L["IRCPromoDesc"] = Colors.iST .. "iRC: Guild Connect " .. Colors.Reset .. "connects guild members through shared rules, verification, guild statistics, professions, and community tools."
L["IRCPromoLink"] = "Available on CurseForge: curseforge.com/wow/addons/ircguildconnect"
