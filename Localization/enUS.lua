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
L["MacroUpdated"] = "Macro updated with %s, %s."
L["MinimapLeftClick"] = (Colors.Yellow .. "Left Click: " .. Colors.Orange .. "Seal Pair & Macro")
L["MinimapShiftLeftClick"] = (Colors.Yellow .. "Shift-Left Click: " .. Colors.Orange .. "Enable/Disable")
L["MinimapRightClick"] = (Colors.Yellow .. "Right Click: " .. Colors.Orange .. "Open Settings")
L["MinimapShiftRightClick"] = (Colors.Yellow .. "Shift-Right Click: " .. Colors.Orange .. "Toggle Bar Lock")
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
L["SettingsIndicatorsSummary"] = "Choose bar information and Echo indicators."
L["SettingsCustomizationSummary"] = "Adjust fonts, colors and previews."
L["SettingsRemindersSummary"] = "Configure seal and Righteous Fury reminders."
L["SettingsSoundsSummary"] = "Choose sounds for Echo stacks and buff reminders."
L["SettingsProfilesSummary"] = "Save your setup or share it with another iST user."
L["SettingsAboutSummary"] = "Addon information and testing options."
L["SettingsCompanionSummary"] = "Information and settings for this addon."
L["WhatsNewTitle"] = "What's New in iSealTwist v%s"
L["WhatsNewIntro"] = "A quick look at this update:"
L["WhatsNewEchoTargets"] = "Choose a switch target of 1, 2, or 3 Echo stacks for each Seal."
L["WhatsNewIndicators"] = "Combine Echo indicators, including nameplate Seal icons and an Echo timer."
L["WhatsNewColorsSounds"] = "Customize Seal bar colors and preview new sounds in the Sounds tab."
L["WhatsNewOpen"] = "What's New"
L["WhatsNewSettings"] = "Open Settings"
L["WhatsNewDismiss"] = "Got It"

-- Sidebar
L["TabGeneral"] = "General"
L["TabIndicators"] = "Indicators"
L["TabCustomization"] = "Customization"
L["TabSounds"] = "Sounds"
L["TabAbout"] = "About"
L["TabProfiles"] = "Profiles"
L["SectionSavedProfiles"] = Colors.iST .. "Saved Profiles"
L["ProfilesDesc"] = Colors.Gray .. "Main keeps this character's original setup. Other profiles are saved for the account. Switching profiles keeps a Previous setup backup.|r"
L["ProfileActive"] = "Active profile: %s"
L["ProfileName"] = "Profile name"
L["ProfileChoose"] = "Choose a saved profile"
L["ProfileSave"] = "Save Current"
L["ProfileLoad"] = "Load Profile"
L["ProfileRename"] = "Rename Profile"
L["ProfileRenamed"] = "Renamed profile: %s"
L["ProfileDelete"] = "Delete Profile"
L["ProfileDeleteConfirm"] = "Click Delete Profile again to remove it."
L["ProfileSaved"] = "Saved profile: %s"
L["ProfileDeleted"] = "Deleted profile: %s"
L["SectionShareSetup"] = Colors.iST .. "Share Your Setup"
L["ProfilesShareDesc"] = Colors.Gray .. "Export the active setup or import a code as a new profile. Loading and importing reload the UI.|r"
L["ProfileExport"] = "Export Setup"
L["ProfileImport"] = "Import Setup"
L["ProfileExportTitle"] = "Export iST Setup"
L["ProfileImportTitle"] = "Import iST Setup"
L["ProfileCopyHint"] = "Press Ctrl+C to copy this code."
L["ProfilePasteHint"] = "Name the new profile, paste an iST setup code, then apply it."
L["ProfileImportName"] = "New profile name (optional)"
L["ProfileApply"] = "Apply & Reload"
L["ProfileClose"] = "Close"
L["SidebarOtherAddons"] = "Other Addons"
L["None"] = "None"

-- General
L["SectionActivation"] = Colors.iST .. "Activation"

-- Bar size
L["SectionBarAppearance"] = Colors.iST .. "Bar Appearance"
L["BarStyle"] = "Swing Bar Style"
L["BarStyleClassic"] = "Classic"
L["BarStyleBlock"] = "Block"
L["BarStyleGlossy"] = "Glossy"
L["BarStyleFrameless"] = "Frameless"
L["BarTexture"] = "Bar Fill Texture"
L["BarTextureBlizzard"] = "Classic Status Bar"
L["BarTextureRaid"] = "Raid Bar"
L["BarTextureSkills"] = "Character Skills"
L["BarTextureSolid"] = "Solid"
L["BarTextureSoft"] = "Soft"
L["BarTextureGlass"] = "Glass"
L["BarTextureRidges"] = "Ridges"
L["BarTextureDiagonal"] = "Diagonal"
L["BarPreview"] = "Bar preview"
L["BarWidth"] = "Bar Width"
L["BarHeight"] = "Bar Height"

L["ShowLatency"] = "Show Latency"
L["ShowLatencyDesc"] = Colors.Gray .. "Display current home latency on the bar.|r"

-- Display
L["ShowSealIcon"] = "Show Seal Icon"
L["ShowSealIconDesc"] = Colors.Gray .. "Display the active seal icon next to the bar.|r"
L["ShowSealTimer"] = "Show Seal Timer"
L["ShowSealTimerDesc"] = Colors.Gray .. "Show the seal's remaining time inside its icon and on a ring that drains into gray.|r"
L["ShowSealName"] = "Show Seal Name"
L["ShowSealNameDesc"] = Colors.Gray .. "Display the active Seal name below the swing bar.|r"
L["ShowEchoTimer"] = "Show Echo Icon Timer"
L["ShowEchoTimerDesc"] = Colors.Gray .. "Show the active Echo in a round icon with a blue timer ring and remaining buff time. The icon follows Seal Icon Size and appears only while its Echo buff is active.|r"
L["EchoLabel"] = "ECHO"
L["ShowNameplateEcho"] = "Echo Stacks on Target Nameplate"
L["ShowNameplateEchoDesc"] = Colors.Gray .. "Show the active Echo icon and three stack markers below your target's nameplate. Markers can be dots or Seal icons.|r"
L["NameplateEchoScale"] = "Nameplate Echo Size"
L["NameplateEchoOffset"] = "Nameplate Echo Vertical Offset"
L["NameplateEchoGlow"] = "Glow Around Nameplate Stacks"
L["NameplateEchoStyle"] = "Nameplate Stack Style"
L["NameplateEchoDots"] = "Dots"
L["NameplateEchoSealIcons"] = "Seal Icons"
L["ShowWeaponSpeed"] = "Show Weapon Speed"
L["ShowWeaponSpeedDesc"] = Colors.Gray .. "Display weapon speed on the bar.|r"
L["ShowSwingRemaining"] = "Show Time Until Next Swing"
L["ShowSwingRemainingDesc"] = Colors.Gray .. "Hide the moving countdown while keeping the bar and weapon speed.|r"
L["BarVisibility"] = "Swing Bar Visibility"
L["VisibilityAlways"] = "Always"
L["VisibilityCombat"] = "Only in combat"
L["VisibilityCombatAura"] = "In combat, with Seal or Echo stacks"
L["OnlyInCombat"] = "Only Show In Combat"
L["OnlyInCombatDesc"] = Colors.Gray .. "Hide the bar when out of combat.|r"
L["ShowWithSealOrStacks"] = "Show in Combat, with Seal or Stacks"
L["ShowWithSealOrStacksDesc"] = Colors.Gray .. "Show the bar in combat or outside combat with an active Seal or confirmed Echo stacks. The stack display stays separate while the bar fades.|r"
L["OnlyAsPaladin"] = "Only Active As Paladin"
L["OnlyAsPaladinDesc"] = Colors.Gray .. "Only activate the addon on Paladin characters.|r"

-- Indicator sub-sections
L["SectionBarInformation"] = Colors.iST .. "Bar Information"
L["SectionUnsealedWrath"] = Colors.iST .. "Unsealed Wrath"
L["EchoSetupPreview"] = "Preview: 2 Echo stacks"
L["EchoSetupPreviewDesc"] = Colors.Gray .. "Shows your selected bar and stack display without changing live Echo tracking.|r"
L["SectionIndicatorStyle"] = Colors.iST .. "Stack Display"
L["SectionFloatingCue"] = Colors.iST .. "Floating Echo Cue"
L["SectionCenterCue"] = Colors.iST .. "Center Message"
L["StackCounterTextSize"] = "Stack Counter Text Size"
L["CenterSwitchText"] = "Show Switch Cue"
L["CenterSwitchTextDesc"] = Colors.Gray .. "Shows a switch cue at the stack target chosen for that Seal, then your attack message after you cast another Seal. Move it with the button below.|r"
L["CenterSwitchVisual"] = "Switch Cue Style"
L["CenterVisualText"] = "Text"
L["CenterVisualRadiant"] = "Radiant Symbol"
L["CenterSwitchPhrase"] = "Switch Message"
L["CenterAttackPhrase"] = "Attack Message"
L["MoveCenterSwitchText"] = "Move Message"
L["DoneMovingCenterSwitchText"] = "Done Moving"
L["WrathCircleSize"] = "Glowing Circles Size"
L["WrathCueStyle"] = "Stack Indicators"
L["WrathCueBarColor"] = "Swing Bar Colors"
L["WrathCueSwordImages"] = "Sword Images"
L["WrathCueCircles"] = "Stack Pips Above Swing Bar"
L["WrathCueCounter"] = "Stack Counter"
L["WrathCueOff"] = "Off"
L["WrathCueDesc"] = Colors.Gray .. "Enable any combination of Echo indicators. They follow the active buff. Change these options outside combat.|r"
L["StackBubbleStyle"] = "Stack Pip Style (Bar and Player Mana)"
L["StackBubbleCircles"] = "Glowing Circles"
L["StackBubbleSealIcons"] = "Seal Icons"
L["WorldEchoCue"] = "Floating Echo Glow / Wings"
L["WorldEchoCueStyle"] = "Floating Cue Style"
L["WorldEchoCueWings"] = "Wings"
L["WorldEchoCueGlow"] = "Proc Glow"
L["WorldEchoCueSparks"] = "Sparkles"
L["WorldEchoCueFrame"] = "Pixel Outline"
L["WorldEchoCueScale"] = "Floating Cue Size"
L["MoveWorldEchoCue"] = "Move Floating Cue"
L["DoneMovingWorldEchoCue"] = "Done Moving"
L["ResetWorldEchoCuePosition"] = "Center on Character"
L["ShowPlayerWrathBubbles"] = "Show Stacks Below Player Mana"
L["ShowPlayerWrathBubblesDesc"] = Colors.Gray .. "Show three stack pips below the player mana bar. Choose glowing circles or icons of the Seal that created the Echo with Stack Pip Style.|r"
L["WrathAttackNow"] = "Attack now"
L["WrathSealUnleashed"] = "Seal unleashed!"
L["WrathTrackingDesc"] = Colors.Gray .. "Live Echo indicators follow the native buff display. Swing and hit observations remain available for diagnostics and do not set the visible stack count.|r"
L["SoundThreeStacks"] = "Sound at Switch Target"
L["SectionEchoSound"] = Colors.iST .. "Echo Stacks"
L["SoundThreeStacksDesc"] = Colors.Gray .. "Play once when the Echo buff's readable stack count reaches the chosen target. If the count is protected in combat, no sound plays.|r"
L["SoundChoice"] = "Choose Sound"
L["SoundUnavailable"] = "[iST]: Sound could not play. Check sound settings or choose another file."
L["SoundSharedDesc"] = Colors.Gray .. "Choose an iSealTwist, WoW, or shared addon sound. Click the speaker beside a name to preview it without changing your selection.|r"
L["SectionSealPair"] = Colors.iST .. "Seal Pair"

-- Seal pair dropdowns
L["TwistFromSeal"] = "First Macro Seal"
L["TwistFromSealDesc"] = Colors.Gray .. "The seal your optional macro casts first.|r"
L["TwistIntoSeal"] = "Second Macro Seal"
L["TwistIntoSealDesc"] = Colors.Gray .. "The seal your optional macro casts second.|r"
L["SealPairLegend"] = "Build stacks on either seal, then switch to release them."
L["SealPairDesc"] = Colors.Gray .. "Choose the seals for your optional SealTwist macro. Stacks can build on either seal; switching seals releases them.|r"
L["SwitchAtStacks"] = "Switch at or above"
L["OneStack"] = "1 stack"
L["TwoStacks"] = "2 stacks"
L["ThreeStacks"] = "3 stacks"
L["StackTargetCombatBlocked"] = Msg("Change Echo stack targets outside combat.")
L["SealPairCombatBlocked"] = Msg("Change the Seal pair outside combat.")
L["QuickMacroTitle"] = "Seal Pair & Macro"
L["QuickMacroDesc"] = "The macro alternates these two Seals. A switch cue stays active at the selected stack count and above. Targets do not change the macro sequence."
L["OpenMacros"] = "Open Macros"
L["MacroWindowCombatBlocked"] = Msg("The macro window cannot be opened during combat.")

-- Twist text customization
L["SectionTextAppearance"] = Colors.iST .. "Text"
L["SwingTextSize"] = "Swing Bar Text Size (fits bar)"
L["IconSize"] = "Seal Icon Size"
L["CurrentSealTextSize"] = "Current Seal Text Size"
L["LatencyTextSize"] = "Latency Text Size"
L["BarFont"] = "Bar Font"

-- Bar colors section
L["SectionBarColors"]   = Colors.iST .. "Bar Colors"
L["DefaultColors"]      = "Default Colors"
L["ColorBar"]           = "Fill"
L["HighlightWrongSeal"] = "Red Bar for Other Seals"
L["HighlightWrongSealDesc"] = Colors.Gray .. "Mark an active Seal outside your chosen pair in red. Active Seal colors take priority when enabled.|r"
L["ColorWrongSeal"] = "Other Seal Color"
L["ColorBorderNormal"]  = "Border"
L["SectionSealBarColors"] = Colors.iST .. "Seal Bar Colors"
L["ColorBarBySeal"] = "Color Bar by Active Seal"
L["ColorBarBySealDesc"] = Colors.Gray .. "Choose a fill color for each Seal. These colors take priority over the red other-Seal warning and Echo stack bar colors.|r"
L["PreviewSealColor"] = "Preview Seal Color"
L["SectionStackColors"] = Colors.iST .. "Stack Colors"
L["SectionEchoAccentColors"] = Colors.iST .. "Echo Accent Colors"
L["ColorFloatingEcho"] = "Floating Glow / Wings"
L["ColorNameplateEcho"] = "Nameplate Dots / Glow"
L["ColorEchoTimerText"] = "Echo Timer Text"
L["WrathColorScheme"] = "Color Scheme"
L["WrathSchemeGold"] = "Gold"
L["WrathSchemeTraffic"] = "Red to Green"
L["WrathSchemeBlue"] = "Blue to Cyan"
L["WrathSchemeCustom"] = "Custom"
L["WrathStageColor"] = "%d / 3 stacks"
L["WrathStageColorsDesc"] = Colors.Gray .. "Choose a scheme or customize each stack stage. Colors apply to the swing bar, sword images, circles, counter, ready text, and player-frame bubbles. Editing a color switches to Custom; only sword images replace the normal border.|r"

-- Position
L["SectionPosition"] = Colors.iST .. "Position"
L["SectionNameplateEcho"] = Colors.iST .. "Target Nameplate Echo"
L["SectionPreview"] = Colors.iST .. "Bar Preview"
L["PreviewSequenceDesc"] = Colors.Gray .. "Preview each bar state in its normal gameplay order.|r"
L["LockBar"] = "Lock Bar Position"
L["LockBarDesc"] = Colors.Gray .. "Prevent the bar from being dragged.|r"
L["CenterHorizontally"] = "Center Horizontally"
L["ResetPosition"] = "Reset Position"
L["IndependentDragDesc"] = Colors.Gray .. "The Seal icon and Echo counter follow the swing bar until you drag them separately. Reset either position to attach it to the bar again.|r"
L["ResetSealPosition"] = "Reset Seal Icon"
L["ResetCounterPosition"] = "Reset Echo Counter"
L["TestBar"] = "Test Bar"
L["TestStackBar"] = "Test Stack Buildup"
L["PreviewNormal"] = "1. Normal"
L["PreviewStacks"] = "2. Build Stacks"
L["PreviewParryHaste"] = "3. Parry Haste"

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
L["ReminderTimeLeft"] = "%s left"
L["ReminderSoundExpiring"] = "Sound When Running Low in Combat"
L["ReminderSoundMissing"] = "Sound When Missing in Combat"

-- About
L["SectionTesting"] = Colors.iST .. "Testing"
L["DebugMode"] = "Debug Mode"
L["TestingDesc"] = Colors.Gray .. "Debug Mode shows diagnostics. Use the stack preview to test indicator layouts without changing your live Echo tracking.|r"
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
