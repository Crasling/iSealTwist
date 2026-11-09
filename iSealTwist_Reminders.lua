local _, iST = ...
local L = iST.L
local FURY_SPELL = 25780

iST.ReminderDefaults = {
    FURY = { enabled = false, showIcon = true, showTime = true, locked = true, scale = 1,
        warningSeconds = 60, protOnly = false, point = { "CENTER", "CENTER", -180, -120 } },
    SEAL = { enabled = false, showIcon = true, showTime = true, locked = true, scale = 1,
        warningSeconds = 5, onlyInCombat = false, point = { "CENTER", "CENTER", 180, -120 } },
}

local function secret(value) return issecretvalue and issecretvalue(value) end
local function number(value)
    return not secret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function read(callback, ...)
    if type(callback) ~= "function" then return nil end
    local function pack(...) return { n = select("#", ...), ... } end
    local result = pack(pcall(callback, ...))
    if not result[1] then return nil end
    for index = 2, result.n do if secret(result[index]) then return nil end end
    return unpack(result, 2, result.n)
end
local function enabled()
    return iSTSettings and iSTSettings.reminders
        and (iSTSettings.reminders.FURY.enabled or iSTSettings.reminders.SEAL.enabled)
end
local previewUntil, nextProtectionRead = {}, 0
local worker = CreateFrame("Frame")
worker:Hide()
local elapsed = 0

function iST:InitializeReminderSettings()
    if type(iSTSettings.reminders) ~= "table" then iSTSettings.reminders = {} end
    for kind, defaults in pairs(self.ReminderDefaults) do
        local settings = iSTSettings.reminders[kind]
        if type(settings) ~= "table" then settings = {}; iSTSettings.reminders[kind] = settings end
        for key, value in pairs(defaults) do
            if settings[key] == nil then
                if type(value) == "table" then
                    settings[key] = { unpack(value) }
                else settings[key] = value end
            end
            if type(value) == "boolean" and type(settings[key]) ~= "boolean" then settings[key] = value end
        end
        if not number(settings.scale) then settings.scale = defaults.scale end
        settings.scale = math.max(0.5, math.min(3, settings.scale))
        if not number(settings.warningSeconds) then settings.warningSeconds = defaults.warningSeconds end
        settings.warningSeconds = math.max(0, math.min(kind == "SEAL" and 30 or 600, settings.warningSeconds))
        local anchors = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
            TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
        local point = settings.point
        if type(point) ~= "table" or not anchors[point[1]] or not anchors[point[2]]
            or not number(point[3]) or not number(point[4]) then settings.point = { unpack(defaults.point) } end
    end
end

function iST:RefreshReminderProtection()
    -- Keep a readable result during combat. A combat reload waits for a safe
    -- talent read instead of guessing the character's specialization.
    if read(InCombatLockdown) ~= false or read(UnitAffectingCombat, "player") ~= false then return end
    local _, class = read(UnitClass, "player")
    if class ~= "PALADIN" then self.State.ReminderProtection = false; return end
    local reader = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
    if type(reader) ~= "function" then return end
    local points = {}
    for index = 1, 3 do
        local ok, spent = pcall(function() return select(7, reader(index, false, false)) end)
        if not ok or not number(spent) or spent < 0 then return end
        points[index] = spent
    end
    self.State.ReminderProtection = points[2] > 0 and points[2] > points[1] and points[2] > points[3]
    self:DebugMsg(string.format("Righteous Fury reminder: talent points Holy %d / Protection %d / Retribution %d; Protection filter %s.",
        points[1], points[2], points[3], self.State.ReminderProtection and "matched" or "not matched"), 3)
end

local function furyScanAllowed()
    return iST.State.ReminderCombat ~= true and read(InCombatLockdown) == false
        and read(UnitAffectingCombat, "player") == false
end

local function queryAura(callback, ...)
    if type(callback) ~= "function" then return nil, false end
    local ok, aura = pcall(callback, ...)
    if not ok or secret(aura) or (aura ~= nil and type(aura) ~= "table") then return nil, false end
    return aura, true
end

local function isFuryAura(aura)
    if secret(aura) or type(aura) ~= "table" then return false, false end
    local ok, spellID, name = pcall(function() return aura.spellId, aura.name end)
    if not ok then return false, false end
    if number(spellID) then return spellID == FURY_SPELL, true end
    if not secret(name) and type(name) == "string" then
        local localized = read(C_Spell and C_Spell.GetSpellName, FURY_SPELL)
        return name == (localized or L["ReminderFury"]), true
    end
    return false, false
end

local function findFuryAura()
    local api, state = C_UnitAuras or {}, iST.State
    local aura = queryAura(api.GetPlayerAuraBySpellID, FURY_SPELL)
    if aura then return aura, "present", "spell lookup" end
    -- A spell lookup may be hidden while the instance learned before combat
    -- remains readable. The cached ID is public; no secret ID is passed back.
    if number(state.FuryAuraID) and state.FuryAuraID > 0 then
        aura = queryAura(api.GetAuraDataByAuraInstanceID, "player", state.FuryAuraID)
        if aura then return aura, "present", "cached aura instance" end
    end
    if not furyScanAllowed() then return nil, "unknown", "combat lookup unavailable" end
    if type(api.GetAuraDataByIndex) ~= "function" then return nil, "unknown", "buff scan unavailable" end
    local incomplete = false
    for index = 1, 255 do
        local readable
        aura, readable = queryAura(api.GetAuraDataByIndex, "player", index, "HELPFUL")
        if not readable then return nil, "unknown", "buff scan restricted" end
        if not aura then
            return nil, incomplete and "unknown" or "missing", "helpful buff scan"
        end
        local matches, identityKnown = isFuryAura(aura)
        if matches then return aura, "present", "helpful buff scan" end
        if not identityKnown then incomplete = true end
    end
    return nil, "unknown", "buff scan incomplete"
end

function iST:ObserveReminderFury(aura, source)
    local state, now = self.State, GetTime()
    local wasPresent, oldExpiry, oldID = state.FuryPresent, state.FuryExpiresAt, state.FuryAuraID
    state.FuryKnown, state.FuryPresent = true, true
    state.FuryPendingMissingAt, state.FuryReadDeferred = nil, nil
    local fieldsOK, expires, duration, auraID = pcall(function()
        return aura.expirationTime, aura.duration, aura.auraInstanceID
    end)
    if fieldsOK then
        if number(expires) and (expires == 0 or expires > now) then state.FuryExpiresAt = expires
        elseif state.FuryExpiresAt and state.FuryExpiresAt <= now then state.FuryExpiresAt = nil end
        if number(duration) and duration >= 0 then state.FuryDuration = duration end
        if number(auraID) and auraID > 0 then state.FuryAuraID = auraID end
    end
    local removal = state.FuryRemovalPending
    if removal and (state.FuryAuraID ~= removal.id or now >= removal.at + 0.3) then state.FuryRemovalPending = nil end
    state.FuryNextCheckAt = state.FuryRemovalPending and state.FuryRemovalPending.at + 0.3 or now + 1
    if wasPresent ~= true or oldExpiry ~= state.FuryExpiresAt or oldID ~= state.FuryAuraID then
        self:DebugMsg(string.format("Righteous Fury confirmed by %s: %.1fs left; duration=%s; instance=%s.",
            source, state.FuryExpiresAt and math.max(0, state.FuryExpiresAt - now) or 0,
            tostring(state.FuryDuration), tostring(state.FuryAuraID)), 3)
    end
end

local function confirmFuryMissing(source)
    local state = iST.State
    if state.FuryPresent ~= false or state.FuryKnown ~= true then
        iST:DebugMsg("Righteous Fury confirmed missing by " .. source .. ".", 3)
    end
    state.FuryKnown, state.FuryPresent, state.FuryExpiresAt, state.FuryAuraID = true, false, nil, nil
    state.FuryRemovalPending, state.FuryPendingMissingAt, state.FuryConfirmUntil = nil, nil, nil
    state.FuryReadDeferred = nil
end

function iST:RefreshReminderFury()
    local now, state = GetTime(), self.State
    local aura, result, source = findFuryAura()
    state.FuryNextCheckAt = now + 1
    if aura then self:ObserveReminderFury(aura, source); return end
    if state.FuryConfirmUntil and now < state.FuryConfirmUntil then
        state.FuryNextCheckAt = state.FuryConfirmUntil
        return
    end
    state.FuryConfirmUntil = nil
    local removal = state.FuryRemovalPending
    if removal then
        if now >= removal.at + 0.3 then confirmFuryMissing("aura removal after replacement check")
        else state.FuryNextCheckAt = removal.at + 0.3 end
        return
    end
    if result == "missing" then
        -- A transient empty read at combat entry must not destroy a live timer.
        -- Require another complete out-of-combat scan before clearing that buff.
        if state.FuryPresent == true and not state.FuryPendingMissingAt then state.FuryPendingMissingAt = now end
        if state.FuryPendingMissingAt and now < state.FuryPendingMissingAt + 0.3 then
            state.FuryNextCheckAt = state.FuryPendingMissingAt + 0.3
            return
        end
        confirmFuryMissing(source)
    else
        state.FuryPendingMissingAt = nil
        if state.FuryReadDeferred ~= source then
            self:DebugMsg(string.format("Righteous Fury %s; keeping confirmed state=%s, expiry=%s.",
                source, tostring(state.FuryPresent), tostring(state.FuryExpiresAt)), 3)
            state.FuryReadDeferred = source
        end
    end
end

local function remainingText(seconds)
    seconds = math.max(0, math.ceil(seconds))
    if seconds >= 3600 then return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    if seconds >= 60 then return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60) end
    return seconds .. "s"
end

function iST:InitializeReminders()
    if self.ReminderFrames then return end
    self.ReminderFrames = {}
    for _, kind in ipairs({ "FURY", "SEAL" }) do
        local reminderKind = kind
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(180, 34)
        frame:SetFrameStrata("MEDIUM")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        -- Only the buff icon has a border. The warning itself floats over the world.
        frame.iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.iconFrame:SetSize(30, 30)
        frame.iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
        frame.iconFrame:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
        frame.iconFrame:SetBackdropColor(0, 0, 0, 0.8)
        frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetPoint("TOPLEFT", frame.iconFrame, "TOPLEFT", 2, -2)
        frame.icon:SetPoint("BOTTOMRIGHT", frame.iconFrame, "BOTTOMRIGHT", -2, 2)
        frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetJustifyH("LEFT")
        frame.title:SetWordWrap(false)
        frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.timer:SetJustifyH("LEFT")
        frame.timer:SetWordWrap(false)
        frame.timer:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -1)
        frame.timer:SetTextColor(1, 0.88, 0.62)
        local font = frame.title:GetFont()
        frame.title:SetFont(font, 16, "OUTLINE")
        frame.timer:SetFont(font, 11, "OUTLINE")
        for _, text in ipairs({ frame.title, frame.timer }) do
            text:SetShadowColor(0, 0, 0, 1)
            text:SetShadowOffset(1, -1)
        end
        frame:SetScript("OnDragStart", function(self)
            if not iSTSettings.reminders[reminderKind].locked or previewUntil[reminderKind] then self:StartMoving() end
        end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relativePoint, x, y = self:GetPoint()
            iSTSettings.reminders[reminderKind].point = { point, relativePoint, x, y }
        end)
        frame:Hide()
        self.ReminderFrames[kind] = frame
    end
    self:ApplyReminderSettings()
end

function iST:ApplyReminderSettings()
    if not self.ReminderFrames then return end
    for kind, frame in pairs(self.ReminderFrames) do
        local settings = iSTSettings.reminders[kind]
        frame:SetScale(settings.scale)
        frame:ClearAllPoints()
        local point = settings.point
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    end
    if iSTSettings.reminders.FURY.enabled then
        if iSTSettings.reminders.FURY.protOnly then self:RefreshReminderProtection() end
        self:RefreshReminderFury()
    end
    self:UpdateReminders()
end

function iST:PreviewReminder(kind)
    if not self.ReminderFrames or not self.ReminderFrames[kind] then return end
    if previewUntil[kind] then previewUntil[kind] = nil else previewUntil[kind] = GetTime() + 30 end
    self:UpdateReminders()
end

function iST:ResetReminderPosition(kind)
    local defaults = self.ReminderDefaults[kind]
    if not defaults then return end
    iSTSettings.reminders[kind].point = { unpack(defaults.point) }
    self:ApplyReminderSettings()
end

function iST:UpdateReminders()
    if not self.ReminderFrames then return end
    local now, state = GetTime(), self.State
    if iSTSettings.reminders.FURY.enabled and now >= (state.FuryNextCheckAt or 0) then
        self:RefreshReminderFury()
    end
    if iSTSettings.reminders.FURY.enabled and iSTSettings.reminders.FURY.protOnly
        and state.ReminderProtection == nil and now >= nextProtectionRead then
        nextProtectionRead = now + 1
        self:RefreshReminderProtection()
    end
    local _, class = read(UnitClass, "player")
    local visible = iSTSettings.enabled and (not iSTSettings.onlyAsPaladin or class == "PALADIN")
        and read(UnitIsDeadOrGhost, "player") ~= true
    for kind, frame in pairs(self.ReminderFrames) do
        local settings = iSTSettings.reminders[kind]
        if previewUntil[kind] and now >= previewUntil[kind] then previewUntil[kind] = nil end
        local preview = previewUntil[kind] ~= nil
        local known, active, expires, icon, title, wrong
        if kind == "FURY" then
            known, active, expires = state.FuryKnown, state.FuryPresent, state.FuryExpiresAt
            title = L["ReminderFury"]
            icon = read(C_Spell and C_Spell.GetSpellTexture, FURY_SPELL)
        else
            known, expires = state.SealStatusKnown, state.SealExpiresAt
            active = state.CurrentSealName ~= nil and expires and expires > now
            title = state.CurrentSealName or L["ReminderSeal"]
            icon = state.CurrentSealIcon
            if secret(icon) then icon = nil end
            if not icon then icon = read(C_Spell and C_Spell.GetSpellTexture, self.SEAL_SPELL_IDS[iSTSettings.twistFromSeal]) end
            if iSTSettings.sealStackMode == "FROM_ONLY" and (iSTSettings.fakeUnsealedWrath or state.UnsealedWrathKnown == true) then
                local _, _, _, wrongSeal = self:GetWrathDisplayState(now)
                wrong = wrongSeal
            end
        end
        if secret(icon) then icon = nil end
        local remaining = number(expires) and expires > 0 and math.max(0, expires - now) or nil
        if remaining == 0 then active = false end
        local eligible = kind ~= "FURY" or not settings.protOnly or state.ReminderProtection == true
        if kind == "SEAL" and settings.onlyInCombat then
            eligible = read(InCombatLockdown) == true or read(UnitAffectingCombat, "player") == true
        end
        local warning = known and (not active or wrong or (remaining and settings.warningSeconds > 0 and remaining <= settings.warningSeconds))
        local show = visible and (preview or (settings.enabled and eligible and warning))
        frame:SetShown(show == true)
        frame:SetFrameStrata(preview and "DIALOG" or "MEDIUM")
        frame:EnableMouse(not settings.locked or preview)
        if show then
            if preview then
                title = kind == "FURY" and L["ReminderFury"] or L["ReminderSeal"]
                active, remaining, wrong = true, math.max(1, settings.warningSeconds), false
            end
            local left = settings.showIcon and 38 or 0
            local danger = not active or wrong
            local message
            if preview then message = title
            elseif wrong then message = string.format(L["ReminderSwitchSeal"], iSTSettings.twistFromSeal)
            elseif active then message = string.format(L["ReminderRefreshBuff"], title)
            elseif kind == "SEAL" then message = L["ReminderCastSeal"]
            else message = string.format(L["ReminderCastBuff"], title) end
            local timerText = preview and L["ReminderPreview"]
                or settings.showTime and active and remaining and string.format(L["ReminderTimeLeft"], remainingText(remaining)) or ""
            frame.iconFrame:SetShown(settings.showIcon)
            frame.icon:SetShown(settings.showIcon)
            if icon then frame.icon:SetTexture(icon) end
            frame.title:SetPoint("LEFT", frame, "LEFT", left, timerText ~= "" and 7 or 0)
            frame.title:SetText(message)
            frame.title:SetTextColor(1, danger and 0.25 or 0.82, danger and 0.15 or 0.35)
            frame.iconFrame:SetBackdropBorderColor(1, danger and 0.25 or 0.75, danger and 0.15 or 0.25, 0.9)
            frame.timer:SetText(timerText)
            frame.timer:SetShown(timerText ~= "")
            frame:SetWidth(left + math.max(frame.title:GetStringWidth(), frame.timer:GetStringWidth()) + 4)
        end
    end
    if iSTSettings.enabled and (enabled() or next(previewUntil)) then worker:Show() else worker:Hide() end
end

worker:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    iST:UpdateReminders()
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_DEAD",
    "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" }) do
    if C_EventUtils.IsEventValid(event) then events:RegisterEvent(event) end
end
events:SetScript("OnEvent", function(_, event, ...)
    if not iSTSettings or not iST.ReminderFrames then return end
    if event == "PLAYER_REGEN_DISABLED" then iST.State.ReminderCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then iST.State.ReminderCombat = false end
    if event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" and (secret((...)) or (...) ~= "player") then return end
        iST.State.ReminderProtection = nil
        nextProtectionRead = 0
    end
    if not enabled() then iST:UpdateReminders(); return end
    local furyFromEvent = false
    if event == "UNIT_AURA" then
        local unit, info = ...
        if secret(unit) or unit ~= "player" then return end
        if not secret(info) and type(info) == "table" then
            local oldID = iST.State.FuryAuraID
            local addedFury, unknownAddition = false, false
            local additionsOK, added = pcall(function() return info.addedAuras end)
            if additionsOK and not secret(added) and type(added) == "table" then
                for _, aura in ipairs(added) do
                    local matches, readable = isFuryAura(aura)
                    if matches then
                        iST:ObserveReminderFury(aura, "UNIT_AURA addition")
                        addedFury, furyFromEvent = true, true
                    elseif not readable then unknownAddition = true end
                end
            elseif not additionsOK or secret(added) then unknownAddition = true end
            if unknownAddition then iST.State.FuryRemovalPending = nil end
            local ok, removed = pcall(function() return info.removedAuraInstanceIDs end)
            if ok and not secret(removed) and type(removed) == "table" then
                for _, id in ipairs(removed) do
                    if not secret(id) and id == oldID and not addedFury and not unknownAddition then
                        iST.State.FuryRemovalPending = { id = oldID, at = GetTime() }
                        iST:DebugMsg("Righteous Fury removal received; checking for a replacement before clearing the timer.", 3)
                    end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if secret(unit) or secret(spellID) or unit ~= "player" or spellID ~= FURY_SPELL then return end
        local state = iST.State
        state.FuryKnown, state.FuryPresent, state.FuryAuraID = true, true, nil
        state.FuryRemovalPending, state.FuryPendingMissingAt = nil, nil
        state.FuryExpiresAt = state.FuryDuration and state.FuryDuration > 0 and GetTime() + state.FuryDuration or nil
        state.FuryConfirmUntil = GetTime() + 0.75
    end
    if iSTSettings.reminders.FURY.enabled and not furyFromEvent then iST:RefreshReminderFury() end
    iST:UpdateReminders()
end)
