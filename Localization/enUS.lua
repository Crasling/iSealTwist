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
L["BarLocked"] = Msg("All positions " .. Colors.Green .. "locked" .. Colors.iST .. ".")
L["BarUnlocked"] = Msg("All positions " .. Colors.Yellow .. "unlocked" .. Colors.iST .. ". Drag to move; right-click an element to reset it.")
L["BarReset"] = Msg("Bar position reset to center.")
L["TestStarted"] = Msg("Test mode: simulating a " .. Colors.Yellow .. "3.6s" .. Colors.iST .. " swing.")
L["StackTestStarted"] = Msg("Test mode: building three stored Seal stacks.")
L["MacroUpdated"] = "Macro updated with %s, %s."
L["MinimapLeftClick"] = (Colors.Yellow .. "Left Click: " .. Colors.Orange .. "Seal Pair & Macro")
L["MinimapShiftLeftClick"] = (Colors.Yellow .. "Shift-Left Click: " .. Colors.Orange .. "Enable/Disable")
L["MinimapRightClick"] = (Colors.Yellow .. "Right Click: " .. Colors.Orange .. "Open Settings")
L["MinimapShiftRightClickLock"] = (Colors.Yellow .. "Shift-Right Click: " .. Colors.Orange .. "Lock All Positions")
L["MinimapShiftRightClickUnlock"] = (Colors.Yellow .. "Shift-Right Click: " .. Colors.Orange .. "Unlock All Positions")
L["TooltipStatus"] = Colors.Yellow .. "Status: " .. Colors.Reset
L["StatusEnabled"] = Colors.Green .. "Swing timer enabled" .. Colors.Reset
L["StatusDisabled"] = Colors.Red .. "Swing timer disabled" .. Colors.Reset
L["TooltipPositionLock"] = Colors.Yellow .. "Positions: " .. Colors.Reset
L["StatusPositionsLocked"] = Colors.Green .. "Locked" .. Colors.Reset
L["StatusPositionsUnlocked"] = Colors.Yellow .. "Unlocked" .. Colors.Reset
L["MinimapMoveResetHint"] = Colors.Yellow .. "Move mode: " .. Colors.Orange .. "Right-click an element to reset it"

-- Slash command help
L["SlashHelp1"] = Colors.iST .. "iSealTwist Commands:"
L["SlashHelp2"] = Colors.Yellow .. "  /ist settings" .. Colors.Reset .. " — Open settings panel"
L["SlashHelp3"] = Colors.Yellow .. "  /ist lock" .. Colors.Reset .. " — Lock or unlock all positions"
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
L["WhatsNewEchoTargets"] = "Choose a separate Switch target for each Seal: >0, 1, 2, or 3 stacks."
L["WhatsNewIndicators"] = "Combine Echo indicators, including an Echo timer and resizable nameplate markers."
L["WhatsNewColorsSounds"] = "Color the bar by Seal and try the new sounds on the Sounds page."
L["WhatsNewProfiles"] = "Save profiles, share a setup code, and use the quick Seal Pair panel from the minimap."
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
L["ProfilesDesc"] = Colors.Gray .. "Main is your starting setup. Saved profiles are available on your other characters, and Previous lets you return to the setup you just left.|r"
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
L["ProfilesShareDesc"] = Colors.Gray .. "Copy your setup to share it, or paste someone else's code to create a new profile. The game reloads when you load or import a profile.|r"
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
L["ShowLatencyDesc"] = Colors.Gray .. "Show your connection delay on the bar.|r"

-- Display
L["ShowSealIcon"] = "Show Seal Icon"
L["ShowSealIconDesc"] = Colors.Gray .. "Display the active seal icon next to the bar.|r"
L["ShowSealTimer"] = "Show Seal Timer"
L["ShowSealTimerDesc"] = Colors.Gray .. "Show the Seal's remaining time inside its icon and on a shrinking ring.|r"
L["ShowSealName"] = "Show Seal Name"
L["ShowSealNameDesc"] = Colors.Gray .. "Display the active Seal name below the swing bar.|r"
L["ShowEchoTimer"] = "Show Echo Icon Timer"
L["ShowEchoTimerDesc"] = Colors.Gray .. "Show your current Echo and its remaining time in a round icon. Its size follows the Seal icon size.|r"
L["EchoLabel"] = "ECHO"
L["SealTimerLabel"] = "SEAL"
L["ShowNameplateEcho"] = "Echo Stacks on Target Nameplate"
L["ShowNameplateEchoDesc"] = Colors.Gray .. "Show the Seals icon with an Echo timer ring and stack markers below your target's nameplate. Markers can be dots or Seal icons.|r"
L["NameplateEchoScale"] = "Nameplate Echo Size"
L["NameplateEchoPipSize"] = "Nameplate Stack Marker Size"
L["NameplateEchoOffset"] = "Nameplate Echo Vertical Offset"
L["NameplateEchoGlow"] = "Glow Around Nameplate Stacks"
L["NameplateEchoStyle"] = "Nameplate Stack Style"
L["NameplateEchoDots"] = "Dots"
L["NameplateEchoSealIcons"] = "Seal Icons"
L["ShowWeaponSpeed"] = "Show Weapon Speed"
L["ShowWeaponSpeedDesc"] = Colors.Gray .. "Display weapon speed on the bar.|r"
L["ShowSwingRemaining"] = "Show Time Until Next Swing"
L["ShowSwingRemainingDesc"] = Colors.Gray .. "Display the time until your next swing inside the bar.|r"
L["BarVisibility"] = "Swing Bar Visibility"
L["VisibilityAlways"] = "Always"
L["VisibilityCombat"] = "Only in combat"
L["VisibilityCombatAura"] = "In combat, with Seal or Echo stacks"
L["OnlyInCombat"] = "Only Show In Combat"
L["OnlyInCombatDesc"] = Colors.Gray .. "Hide the bar when out of combat.|r"
L["ShowWithSealOrStacks"] = "Show in Combat, with Seal or Stacks"
L["ShowWithSealOrStacksDesc"] = Colors.Gray .. "Show the bar during combat and whenever you have an active Seal or Echo stacks.|r"
L["OnlyAsPaladin"] = "Only Active As Paladin"
L["OnlyAsPaladinDesc"] = Colors.Gray .. "Only activate the addon on Paladin characters.|r"

-- Indicator sub-sections
L["SectionBarInformation"] = Colors.iST .. "Bar Information"
L["SectionUnsealedWrath"] = Colors.iST .. "Unsealed Wrath"
L["EchoSetupPreview"] = "Preview: 2 Echo stacks"
L["EchoSetupPreviewDesc"] = Colors.Gray .. "See how your bar and Echo indicators look without changing your current stacks.|r"
L["ShowPreview"] = "Show preview"
L["HidePreview"] = "Hide preview"
L["SectionIndicatorStyle"] = Colors.iST .. "Stack Display"
L["SectionFloatingCue"] = Colors.iST .. "Floating Wings (Experimental)"
L["WorldEchoCuePhase"] = "Show Wings When"
L["SectionCenterCue"] = Colors.iST .. "Center Message"
L["StackCounterTextSize"] = "Stack Counter Text Size"
L["CenterSwitchText"] = "Show Switch Cue"
L["CenterSwitchTextDesc"] = Colors.Gray .. "Choose which message appears at the stack target and after casting another Seal. Move it with the button below.|r"
L["CenterSwitchMode"] = "Switch Cue Messages"
L["CenterModeBoth"] = "Switch and attack"
L["CenterModeSwitch"] = "Switch only"
L["CenterModeAttack"] = "Attack only"
L["CenterSwitchPhrase"] = "Switch Message"
L["CenterAttackPhrase"] = "Attack Message"
L["CustomMessage"] = "Custom..."
L["SaveCustomMessage"] = "Save text"
L["CancelCustomMessage"] = "Cancel"
L["MoveCenterSwitchText"] = "Move Message"
L["DoneMovingCenterSwitchText"] = "Done Moving"
L["WrathCircleSize"] = "Swing Bar Pip Size"
L["PlayerPipSize"] = "Player Mana Pip Size"
L["WrathCueStyle"] = "Stack Indicators"
L["WrathCueBarColor"] = "Swing Bar Colors"
L["WrathCueSwordImages"] = "Sword Images"
L["WrathCueCircles"] = "Stack Pips Above Swing Bar"
L["WrathCueCounter"] = "Stack Counter"
L["WrathCueOff"] = "Off"
L["WrathCueDesc"] = Colors.Gray .. "Choose the Echo indicators you want to see. You can use several at once. Change these options outside combat.|r"
L["StackBubbleStyle"] = "Stack Pip Style (Bar and Player Mana)"
L["StackBubbleCircles"] = "Glowing Circles"
L["StackBubbleSealIcons"] = "Seal Icons"
L["WorldEchoCue"] = "Floating Echo Wings (Experimental)"
L["WorldEchoCueScale"] = "Wing Size"
L["MoveWorldEchoCue"] = "Move Wings"
L["DoneMovingWorldEchoCue"] = "Done Moving"
L["ResetWorldEchoCuePosition"] = "Center on Character"
L["ShowPlayerWrathBubbles"] = "Show Stacks Below Player Mana"
L["ShowPlayerWrathBubblesDesc"] = Colors.Gray .. "Show Echo pips below the player mana bar. Their number follows the chosen stack target and grows if more stacks build.|r"
L["ShowPlayerPipFrame"] = "Show Frame Around Player Mana Pips"
L["ShowPlayerPipFrameDesc"] = Colors.Gray .. "Show the gold frame beneath the default player mana bar. Turn this off to show only the pips.|r"
L["WrathAttackNow"] = "Attack now"
L["WrathSealUnleashed"] = "Seal unleashed!"
L["WrathTrackingDesc"] = Colors.Gray .. "Your Echo indicators show the stacks you have. Use the preview to try different layouts.|r"
L["SoundThreeStacks"] = "Sound for Switch Cue (Experimental)"
L["SectionEchoSound"] = Colors.iST .. "Echo Stack Sound (Experimental)"
L["SoundThreeStacksDesc"] = Colors.Gray .. "Try a sound when it is time to switch Seals. This experimental alert may miss cues during combat.|r"
L["SoundChoice"] = "Choose Sound"
L["SoundUnavailable"] = "[iST]: Sound could not play. Check sound settings or choose another file."
L["SoundSharedDesc"] = Colors.Gray .. "Choose a sound from iSealTwist, WoW, or another addon. Click the speaker to hear it before choosing.|r"
L["SectionSealPair"] = Colors.iST .. "Seal Pair"

-- Seal pair dropdowns
L["TwistFromSeal"] = "First Macro Seal"
L["TwistFromSealDesc"] = Colors.Gray .. "The seal your optional macro casts first.|r"
L["TwistIntoSeal"] = "Second Macro Seal"
L["TwistIntoSealDesc"] = Colors.Gray .. "The seal your optional macro casts second.|r"
L["SealPairLegend"] = "Build stacks on either seal, then switch to release them."
L["SealPairDesc"] = Colors.Gray .. "Choose the two Seals for your optional macro. Build Echo stacks with one Seal, then switch to the other before your next attack.|r"
L["SwitchAtStacks"] = "Switch at or above"
L["SwitchAtStacksDesc"] = Colors.Gray .. "The Switch cue appears at this count or higher. Choose >0 to keep the Switch cue after an Echo ends, until you change Seals.|r"
L["AnyEchoStack"] = ">0 (switch back)"
L["OneStack"] = "1 stack"
L["TwoStacks"] = "2 stacks"
L["ThreeStacks"] = "3 stacks"
L["StackTargetCombatBlocked"] = Msg("Change Echo stack targets outside combat.")
L["SealPairCombatBlocked"] = Msg("Change the Seal pair outside combat.")
L["QuickMacroTitle"] = "Seal Pair & Macro"
L["QuickMacroDesc"] = "The macro alternates between these two Seals. Choose a stack target, or >0 to keep the Switch cue after an Echo ends."
L["OpenMacros"] = "Open Macros"
L["MacroWindowCombatBlocked"] = Msg("The macro window cannot be opened during combat.")

-- Twist text customization
L["SectionTextAppearance"] = Colors.iST .. "Text"
L["SwingTextSize"] = "Swing Bar Text Size (fits bar)"
L["IconSize"] = "Seal Icon Size"
L["CurrentSealTextSize"] = "Current Seal Text Size"
L["LatencyTextSize"] = "Latency Text Size"
L["BarFont"] = "Display Font"
L["DisplayFontDesc"] = Colors.Gray .. "Choose a font for the bar, Seal name, Echo numbers, and messages. Fonts from other installed addons may also appear.|r"

-- Bar colors section
L["SectionBarColors"]   = Colors.iST .. "Bar Colors"
L["DefaultColors"]      = "Default Colors"
L["ColorBar"]           = "Fill"
L["HighlightWrongSeal"] = "Red Bar for Other Seals"
L["HighlightWrongSealDesc"] = Colors.Gray .. "Turn the bar red when your active Seal is outside your chosen pair. Your own Seal colors override this warning.|r"
L["ColorWrongSeal"] = "Other Seal Color"
L["ColorBorderNormal"]  = "Border"
L["SectionSealBarColors"] = Colors.iST .. "Seal Bar Colors"
L["ColorBarBySeal"] = "Color Bar by Active Seal"
L["ColorBarBySealDesc"] = Colors.Gray .. "Give each Seal its own bar color. These colors override other bar color choices.|r"
L["PreviewSealColor"] = "Preview Seal Color"
L["SectionStackColors"] = Colors.iST .. "Stack Colors"
L["SectionEchoAccentColors"] = Colors.iST .. "Echo Accent Colors"
L["ColorSwitchMessage"] = "Switch Message"
L["ColorAttackMessage"] = "Attack Message"
L["ColorFloatingEcho"] = "Floating Wings"
L["ColorNameplateEcho"] = "Nameplate Dots / Glow"
L["ColorEchoTimerText"] = "Echo Timer Text"
L["WrathColorScheme"] = "Color Scheme"
L["WrathSchemeGold"] = "Gold"
L["WrathSchemeTraffic"] = "Red to Green"
L["WrathSchemeBlue"] = "Blue to Cyan"
L["WrathSchemeCustom"] = "Custom"
L["WrathStageColor"] = "%d / 3 stacks"
L["WrathStageColorsDesc"] = Colors.Gray .. "Choose a color theme or set a color for each Echo stack count. These colors appear on your bar and Echo indicators. Changing one color selects Custom.|r"

-- Position
L["SectionPosition"] = Colors.iST .. "Position"
L["SectionNameplateEcho"] = Colors.iST .. "Target Nameplate Echo"
L["SectionPreview"] = Colors.iST .. "Bar Preview"
L["PreviewSequenceDesc"] = Colors.Gray .. "Preview each bar state in its normal gameplay order.|r"
L["LockBar"] = "Lock All Positions"
L["LockBarDesc"] = Colors.Gray .. "Unlock to position the bar, indicators, and enabled Seal and Righteous Fury reminders. Drag to move, right-click an element to reset it, or hold Shift to move freely.|r"
L["CenterHorizontally"] = "Center Horizontally"
L["ResetPosition"] = "Reset Position"
L["IndependentDragDesc"] = Colors.Gray .. "The Seal icon, Echo timer, and Echo counter follow the swing bar until you drag them separately. Reset a position to attach it to the bar again.|r"
L["ResetSealPosition"] = "Reset Seal Icon"
L["ResetEchoTimerPosition"] = "Reset Echo Timer"
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
L["RemindersDesc"] = Colors.Gray .. "Get a warning when your Seal or Righteous Fury is missing or nearly over. Set the warning time to 0 to warn only when it is missing. Unlock All Positions to move a reminder.|r"
L["ReminderEnable"] = "Enable Reminder"
L["ReminderProtOnly"] = "Only with Protection Talents"
L["ReminderProtOnlyDesc"] = Colors.Gray .. "Show only when Protection is your strongest talent tree.|r"
L["ReminderDungeonsOnly"] = "Dungeons / Raids Only"
L["ReminderDungeonsOnlyDesc"] = Colors.Gray .. "Show only while you are inside a dungeon or raid. Battlegrounds do not count.|r"
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
L["ReminderPreviewMove"] = "Preview Reminder"
L["ReminderPreview"] = "Reminder preview"
L["ReminderCastBuff"] = "Cast %s"
L["ReminderCastSeal"] = "Cast a seal"
L["ReminderRefreshBuff"] = "Refresh %s"
L["ReminderTimeLeft"] = "%s left"
L["ReminderSoundExpiring"] = "Sound When Running Low in Combat"
L["ReminderSoundMissing"] = "Sound When Missing in Combat"

-- About
L["SectionTesting"] = Colors.iST .. "Testing"
L["DebugMode"] = "Debug Mode"
L["TestingDesc"] = Colors.Gray .. "Use the preview to try different layouts without changing your Echo stacks. Debug Mode prints extra details in chat.|r"
L["AboutText"] = Colors.iST .. "iSealTwist " .. Colors.Reset .. "is a WoW Forever Paladin weapon-swing timer. With Unsealed Wrath learned, it tracks stored Seal stacks and shows when three stacks are ready for a seal switch."
L["CreatedBy"] = "Created by: "
L["ISTCurseForgeLink"] = "Available on CurseForge: curseforge.com/wow/addons/isealtwist"

-- Short descriptions shown beneath controls that do not have a dedicated help row.
L["BarVisibilityDesc"] = Colors.Gray .. "Show the bar always, in combat, or while a Seal or Echo is active.|r"
L["WrathCueCounterDesc"] = Colors.Gray .. "Show the active Echo stack count above the swing bar.|r"
L["WrathCueCirclesDesc"] = Colors.Gray .. "Show Echo pips near the bar. Their number follows the chosen target and grows with extra stacks.|r"
L["WrathCueBarColorDesc"] = Colors.Gray .. "Change the bar fill by Echo stack count unless a Seal color takes priority.|r"
L["WorldEchoCueDesc"] = Colors.Gray .. "Show Wings near your character when the chosen Echo cue is active.|r"
L["StackBubbleStyleDesc"] = Colors.Gray .. "Use circles or the Echo Seal icon for bar and player mana pips.|r"
L["StackCounterTextSizeDesc"] = Colors.Gray .. "Resize the Echo stack number above the bar.|r"
L["WrathCircleSizeDesc"] = Colors.Gray .. "Resize the Echo pips attached to the swing bar.|r"
L["PlayerPipSizeDesc"] = Colors.Gray .. "Resize the Echo pips below the player mana bar.|r"
L["WorldEchoCuePhaseDesc"] = Colors.Gray .. "Show Wings when it is time to switch Seals or to attack.|r"
L["WorldEchoCueScaleDesc"] = Colors.Gray .. "Resize the floating Wings cue.|r"
L["CenterSwitchModeDesc"] = Colors.Gray .. "Show the switch message, attack message, or both.|r"
L["CenterSwitchPhraseDesc"] = Colors.Gray .. "Choose the message shown when the Echo target is reached.|r"
L["CenterAttackPhraseDesc"] = Colors.Gray .. "Choose the message shown after switching to another Seal.|r"
L["ReminderEnableDesc"] = Colors.Gray .. "Turn this buff reminder on or off.|r"
L["ReminderOnlyInCombatDesc"] = Colors.Gray .. "Show the Seal reminder only during combat.|r"
L["ReminderThresholdDesc"] = Colors.Gray .. "Warn at this time remaining; zero warns only when the buff is missing.|r"
L["ReminderShowIconDesc"] = Colors.Gray .. "Display the buff icon beside the warning text.|r"
L["ReminderShowTimeDesc"] = Colors.Gray .. "Include the buff's remaining time while it is running low.|r"
L["ReminderScaleDesc"] = Colors.Gray .. "Resize this reminder's icon and text.|r"
L["ReminderSoundExpiringDesc"] = Colors.Gray .. "Play a sound when this buff starts running low in combat.|r"
L["ReminderSoundMissingDesc"] = Colors.Gray .. "Play a sound when this buff is missing in combat.|r"
L["SoundChoiceDesc"] = Colors.Gray .. "Choose a sound; use the speaker button to preview it.|r"
L["BarStyleDesc"] = Colors.Gray .. "Choose the shape and border of the swing bar.|r"
L["BarTextureDesc"] = Colors.Gray .. "Choose the texture used for the moving bar fill.|r"
L["BarWidthDesc"] = Colors.Gray .. "Set the swing bar's horizontal size.|r"
L["BarHeightDesc"] = Colors.Gray .. "Set the swing bar's vertical size.|r"
L["IconSizeDesc"] = Colors.Gray .. "Resize the Seal icon and Echo timer icon.|r"
L["SwingTextSizeDesc"] = Colors.Gray .. "Resize weapon speed and remaining swing time inside the bar.|r"
L["CurrentSealTextSizeDesc"] = Colors.Gray .. "Resize the active Seal name below the bar.|r"
L["LatencyTextSizeDesc"] = Colors.Gray .. "Resize the latency text near the bar.|r"
L["ColorBarDesc"] = Colors.Gray .. "Choose the base swing bar fill color.|r"
L["ColorWrongSealDesc"] = Colors.Gray .. "Choose the warning color for Seals outside your selected pair.|r"
L["ColorBorderNormalDesc"] = Colors.Gray .. "Choose the normal swing bar border color.|r"
L["PreviewSealColorDesc"] = Colors.Gray .. "Choose which Seal color appears in the preview above.|r"
L["WrathColorSchemeDesc"] = Colors.Gray .. "Apply a preset to all Echo stack stages.|r"
L["ColorSwitchMessageDesc"] = Colors.Gray .. "Choose the Switch message text color.|r"
L["ColorAttackMessageDesc"] = Colors.Gray .. "Choose the Attack message text color.|r"
L["ColorFloatingEchoDesc"] = Colors.Gray .. "Choose the floating Wings tint.|r"
L["ColorNameplateEchoDesc"] = Colors.Gray .. "Choose the Echo color on target nameplates.|r"
L["ColorEchoTimerTextDesc"] = Colors.Gray .. "Choose the remaining-time color inside the Echo icon.|r"
L["NameplateEchoStyleDesc"] = Colors.Gray .. "Show Echo stacks as circles or Seal icons on the target nameplate.|r"
L["NameplateEchoScaleDesc"] = Colors.Gray .. "Resize the whole Echo indicator, including its timer icon and stack markers.|r"
L["NameplateEchoPipSizeDesc"] = Colors.Gray .. "Resize the stack circles or Seal icons without changing the timer icon.|r"
L["NameplateEchoOffsetDesc"] = Colors.Gray .. "Move the Echo indicator up or down relative to the nameplate.|r"
L["NameplateEchoGlowDesc"] = Colors.Gray .. "Add a glow around the target's Echo stack indicators.|r"
L["ProfileChooseDesc"] = Colors.Gray .. "Select a saved profile to load, rename, or delete.|r"
L["ProfileNameDesc"] = Colors.Gray .. "Enter a name to save this setup or rename the selected profile.|r"
L["DebugModeDesc"] = Colors.Gray .. "Show extra details in chat to help find problems.|r"
L["CustomColorDesc"] = Colors.Gray .. "Choose a custom color for %s.|r"

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
