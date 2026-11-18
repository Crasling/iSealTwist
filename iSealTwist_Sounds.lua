local _, iST = ...

-- Use game sounds so cues work without a sound addon or external files.
iST.SoundChoices = {
    MAP_PING = { label = "Map ping", fallback = 3175 },
    AUCTION_WINDOW_OPEN = { label = "Bell", fallback = 5274 },
    IG_MAINMENU_OPTION_CHECKBOX_ON = { label = "Click", fallback = 856 },
    IG_QUEST_LOG_ABANDON_QUEST = { label = "Short warning", fallback = 846 },
}
iST.SoundChoiceOrder = { "MAP_PING", "AUCTION_WINDOW_OPEN", "IG_MAINMENU_OPTION_CHECKBOX_ON", "IG_QUEST_LOG_ABANDON_QUEST" }

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
        choices[#choices + 1] = { value = key, text = self.SoundChoices[key].label }
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
                        choices[#choices + 1] = { value = key, text = name .. " (shared)" }
                        found[key] = true
                    end
                end
            end
        end
    end
    if type(selected) == "string" and selected:sub(1, 4) == "LSM:" and not found[selected] then
        choices[#choices + 1] = { value = selected, text = selected:sub(5) .. " (unavailable)" }
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
    if not selected or type(PlaySound) ~= "function" then return false end
    local sound = SOUNDKIT and SOUNDKIT[choice] or selected.fallback
    if type(sound) ~= "number" then return false end
    local ok, played = pcall(PlaySound, sound, "Master")
    return ok and played == true
end

function iST:TestCueSound(choice)
    if not self:PlayCueSound(choice) then print(self.L["SoundUnavailable"]) end
end

function iST:UpdateThreeStackSound(count, active, now)
    local state = self.State
    active = active and self:ShouldShowBar()
    -- Arm a new cue only after the stacks have cleared. A brief correction
    -- from three to two and back is still the same stack cycle.
    if not active or count <= 0 then
        state.ThreeStackSoundReady = true
        return
    end
    if count < 3 then return end
    if not state.ThreeStackSoundReady then return end
    state.ThreeStackSoundReady = false
    if state.TestMode or not iSTSettings.soundThreeStacks then return end
    now = now or GetTime()
    if now - (state.ThreeStackSoundAt or -100) < 1.5 then return end
    state.ThreeStackSoundAt = now
    self:PlayCueSound(iSTSettings.soundThreeStacksChoice)
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
        self:PlayCueSound(settings.soundChoice)
    end
end
