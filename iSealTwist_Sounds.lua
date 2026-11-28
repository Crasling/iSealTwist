local _, iST = ...

-- Bundled cues always work without a separate media addon. Keep the old
-- SoundKit keys so existing saved sound choices still play.
iST.SoundChoices = {
    MAP_PING = { label = "Map ping", fallback = 3175 },
    AUCTION_WINDOW_OPEN = { label = "Bell", fallback = 5274 },
    IG_MAINMENU_OPTION_CHECKBOX_ON = { label = "Click", fallback = 856 },
    IG_QUEST_LOG_ABANDON_QUEST = { label = "Short warning", fallback = 846 },
    ["FILE:Soft Chime"] = { label = "Soft Chime", file = "SoftChime.ogg" },
    ["FILE:Bright Chime"] = { label = "Bright Chime", file = "BrightChime.ogg" },
    ["FILE:Silver Bell"] = { label = "Silver Bell", file = "SilverBell.ogg" },
    ["FILE:Double Bell"] = { label = "Double Bell", file = "DoubleBell.ogg" },
    ["FILE:Rising Ping"] = { label = "Rising Ping", file = "RisingPing.ogg" },
    ["FILE:Falling Ping"] = { label = "Falling Ping", file = "FallingPing.ogg" },
    ["FILE:Warm Pulse"] = { label = "Warm Pulse", file = "WarmPulse.ogg" },
    ["FILE:Sharp Pulse"] = { label = "Sharp Pulse", file = "SharpPulse.ogg" },
    ["FILE:Echo Spark"] = { label = "Echo Spark", file = "EchoSpark.ogg" },
    ["FILE:Alert Tick"] = { label = "Alert Tick", file = "AlertTick.ogg" },
    ["FILE:Short Sweep"] = { label = "Short Sweep", file = "ShortSweep.ogg" },
    ["FILE:Triad"] = { label = "Triad", file = "Triad.ogg" },
}
iST.SoundChoiceOrder = {
    "FILE:Soft Chime", "FILE:Bright Chime", "FILE:Silver Bell", "FILE:Double Bell",
    "FILE:Rising Ping", "FILE:Falling Ping", "FILE:Warm Pulse", "FILE:Sharp Pulse",
    "FILE:Echo Spark", "FILE:Alert Tick", "FILE:Short Sweep", "FILE:Triad",
    "MAP_PING", "AUCTION_WINDOW_OPEN", "IG_MAINMENU_OPTION_CHECKBOX_ON", "IG_QUEST_LOG_ABANDON_QUEST",
}

local function SharedSounds()
    if not LibStub then return nil end
    local ok, media = pcall(LibStub, "LibSharedMedia-3.0", true)
    return ok and media or nil
end

function iST:IsSoundChoiceValid(choice)
    return self.SoundChoices[choice] ~= nil
        or type(choice) == "string" and choice:sub(1, 4) == "LSM:" and #choice > 4
end

function iST:GetSoundOptions(selected)
    local choices, found = {}, {}
    for _, key in ipairs(self.SoundChoiceOrder) do
        local sound = self.SoundChoices[key]
        choices[#choices + 1] = { value = key,
            text = (sound.file and "iSealTwist: " or "WoW: ") .. sound.label }
        found[key] = true
    end
    local media = SharedSounds()
    if media and type(media.List) == "function" then
        local ok, names = pcall(media.List, media, "sound")
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do
                if type(name) == "string" then
                    local key = "LSM:" .. name
                    if not found[key] then
                        local source = "SharedMedia"
                        if type(media.Fetch) == "function" then
                            local pathOK, path = pcall(media.Fetch, media, "sound", name, true)
                            if pathOK and type(path) == "string" then
                                source = path:gsub("/", "\\"):match("[Ii]nterface\\[Aa]dd[Oo]ns\\([^\\]+)")
                                    or source
                            end
                        end
                        choices[#choices + 1] = { value = key, text = source .. ": " .. name }
                        found[key] = true
                    end
                end
            end
        end
    end
    if type(selected) == "string" and selected:sub(1, 4) == "LSM:" and not found[selected] then
        choices[#choices + 1] = { value = selected,
            text = "SharedMedia: " .. selected:sub(5) .. " (unavailable)" }
    end
    return choices
end

function iST:PlayCueSound(choice)
    if type(choice) == "string" and choice:sub(1, 4) == "LSM:" then
        local media = SharedSounds()
        if not media or type(media.Fetch) ~= "function" or type(PlaySoundFile) ~= "function" then return false end
        local ok, path = pcall(media.Fetch, media, "sound", choice:sub(5), true)
        if not ok or type(path) ~= "string" or path == "" then return false end
        local playedOK, played = pcall(PlaySoundFile, path, "Master")
        return playedOK and played == true
    end
    local selected = self.SoundChoices[choice]
    if not selected then return false end
    if selected.file then
        if type(PlaySoundFile) ~= "function" then return false end
        local ok, played = pcall(PlaySoundFile, self.AddonPath .. "Sounds\\" .. selected.file, "Master")
        return ok and played == true
    end
    if type(PlaySound) ~= "function" then return false end
    local sound = SOUNDKIT and SOUNDKIT[choice] or selected.fallback
    if type(sound) ~= "number" then return false end
    local ok, played = pcall(PlaySound, sound, "Master")
    return ok and played == true
end

function iST:TestCueSound(choice)
    if not self:PlayCueSound(choice) then print(self.L["SoundUnavailable"]) end
end

function iST:CheckCueSound(which)
    local reminders = iSTSettings and iSTSettings.reminders
    if not reminders then return end
    local kind = type(which) == "string" and which:upper() or ""
    local reminder = reminders[kind]
    if reminder then
        local played = self:PlayCueSound(reminder.soundChoice)
        self:PrintToChat(string.format("[iST] %s sound check: %s playback %s.",
            kind, reminder.soundChoice, played and "OK" or "failed"))
        return
    end

    self:PrintToChat("[iST] Preview a reminder with /ist soundcheck fury, seal, blessing, or aura.")
    for _, reminderKind in ipairs(self.ReminderKinds) do
        local settings = reminders[reminderKind]
        self:PrintToChat(string.format("[iST] %s sound: reminder=%s, low=%s, missing=%s.",
            reminderKind, tostring(settings.enabled == true), tostring(settings.soundExpiring == true),
            tostring(settings.soundMissing == true)))
    end
end

function iST:UpdateReminderSound(kind, settings, inCombat, eligible, visible, preview, known, active, warning)
    local stages = self.State.ReminderSoundStages
    if not stages then stages = {}; self.State.ReminderSoundStages = stages end
    if not inCombat or not visible or not settings.enabled or not eligible then
        stages[kind] = nil
        return
    end
    -- A hidden aura read is inconclusive. Keep the last stage until a known
    -- state arrives so combat restrictions cannot replay the same warning.
    if preview or not known then return end
    local stage = not active and "missing" or warning and "expiring" or nil
    if stage == stages[kind] then return end
    stages[kind] = stage
    if (stage == "missing" and settings.soundMissing)
        or (stage == "expiring" and settings.soundExpiring) then
        local played = self:PlayCueSound(settings.soundChoice)
        if iSTSettings.debugMode then
            self:DebugMsg(string.format("%s reminder sound (%s): %s playback %s.",
                kind, stage, settings.soundChoice, played and "accepted" or "failed"), played and 3 or 2)
        end
    end
end
