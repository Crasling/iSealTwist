local _, iST = ...
local L = iST.L
local FURY_SPELL = 25780
local SEAL_IDLE_HIDE_SECONDS = 300
local CAPITAL_MAPS = { [1453] = "Alliance", [1454] = "Horde", [1455] = "Alliance",
    [1456] = "Horde", [1457] = "Alliance", [1458] = "Horde" }

iST.ReminderDefaults = {
    FURY = { enabled = false, showIcon = true, showTime = true, locked = true, scale = 1,
        warningSeconds = 60, protOnly = false, dungeonsOnly = false, partyOnly = false,
        soundExpiring = false, soundMissing = false, soundChoice = "FILE:Sharp Pulse",
        point = { "CENTER", "CENTER", -180, -120 } },
    SEAL = { enabled = false, showIcon = true, showTime = true, locked = true, scale = 1,
        warningSeconds = 5, onlyInCombat = false, hideAfterIdle = false, hideInCapitals = false,
        soundExpiring = false, soundMissing = false, soundChoice = "FILE:Alert Tick",
        point = { "CENTER", "CENTER", 180, -120 } },
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
local previewUntil, nextProtectionRead, protectionRefreshGeneration = {}, 0, 0
local lastSealCombatAt = GetTime()
local capitalMap, nextCapitalCheck = nil, 0

local function inCapital(now)
    if now < nextCapitalCheck then return capitalMap == true end
    nextCapitalCheck = now + 2
    local mapAPI = C_Map
    local mapID = read(mapAPI and mapAPI.GetBestMapForUnit, "player")
    if not number(mapID) then return capitalMap == true end
    local faction = read(UnitFactionGroup, "player")
    if faction ~= "Alliance" and faction ~= "Horde" then capitalMap = false; return false end
    for _ = 1, 6 do
        if CAPITAL_MAPS[mapID] then
            capitalMap = CAPITAL_MAPS[mapID] == faction
            return capitalMap
        end
        local info = read(mapAPI and mapAPI.GetMapInfo, mapID)
        if type(info) ~= "table" then break end
        local parentID = read(function() return info.parentMapID end)
        if not number(parentID) or parentID <= 0 or parentID == mapID then break end
        mapID = parentID
    end
    capitalMap = false
    return false
end
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
        if not self:IsSoundChoiceValid(settings.soundChoice) then settings.soundChoice = defaults.soundChoice end
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
    if class ~= "PALADIN" then
        self.State.ReminderProtection = false
        self.State.ReminderProtectionGroup = nil
        self.State.ReminderProtectionConfigID = nil
        return
    end
    local configID = read(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    if not number(configID) then return end
    local group = read(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup, false, false)
    if not number(group) then group = nil end
    local state = self.State
    if state.ReminderProtectionConfigID == configID and state.ReminderProtectionGroup == group
        and state.ReminderProtection ~= nil
        and GetTime() < (state.ReminderProtectionNextScanAt or 0) then return end
    local traits = C_Traits
    if not traits or type(traits.GetGroupDisplayInfoByTreeID) ~= "function" then return end
    local ok, points = pcall(function()
        local config = traits.GetConfigInfo(configID)
        if secret(config) or type(config) ~= "table" then return nil end
        local treeIDs = config.treeIDs
        if secret(treeIDs) or type(treeIDs) ~= "table" or not number(treeIDs[1]) then return nil end
        local treeID = treeIDs[1]
        local groups = traits.GetGroupDisplayInfoByTreeID(treeID)
        if secret(groups) or type(groups) ~= "table" or #groups < 3 then return nil end
        table.sort(groups, function(a, b) return a.orderIndex < b.orderIndex end)
        local groupIndex, result = {}, { 0, 0, 0 }
        for index = 1, 3 do
            local info = groups[index]
            if secret(info) or not number(info.groupID) then return nil end
            groupIndex[info.groupID] = index
        end
        local nodes = traits.GetTreeNodes(treeID)
        if secret(nodes) or type(nodes) ~= "table" then return nil end
        for _, nodeID in ipairs(nodes) do
            if not number(nodeID) then return nil end
            local node = traits.GetNodeInfo(configID, nodeID)
            if secret(node) then return nil end
            if node and node.isVisible and node.entryIDs and node.entryIDs[1] then
                local rank = node.activeRank or node.currentRank
                if not number(rank) then return nil end
                if rank > 0 then
                    local memberships = node.groupIDs
                    if secret(memberships) or type(memberships) ~= "table" then return nil end
                    for _, groupID in ipairs(memberships) do
                        local index = groupIndex[groupID]
                        if index then result[index] = result[index] + rank; break end
                    end
                end
            end
        end
        return result
    end)
    if not ok or not points then return end
    state.ReminderProtectionGroup = group
    state.ReminderProtectionConfigID = configID
    state.ReminderProtectionNextScanAt = GetTime() + 5
    self.State.ReminderProtection = points[2] > 0 and points[2] > points[1] and points[2] > points[3]
    self:DebugMsg(string.format("Righteous Fury reminder: active config %d, group %s; points Holy %d / Protection %d / Retribution %d; Protection filter %s.",
        configID, tostring(state.ReminderProtectionGroup or "?"), points[1], points[2], points[3],
        state.ReminderProtection and "matched" or "not matched"), 3)
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
            if not iSTSettings.barLocked and iSTSettings.reminders[reminderKind].enabled
                and not (InCombatLockdown and InCombatLockdown()) then
                self.isDragging = true
                iST:BeginMoveGuides(self)
            end
        end)
        frame:SetScript("OnDragStop", function(self)
            if not self.isDragging then return end
            iST:EndMoveGuides(self)
            self.isDragging = nil
            local point, _, relativePoint, x, y = self:GetPoint()
            iSTSettings.reminders[reminderKind].point = { point, relativePoint, x, y }
        end)
        frame:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" and iST:CanResetMovePosition(self) then
                iST:ResetReminderPosition(reminderKind)
            end
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
        and now >= nextProtectionRead then
        nextProtectionRead = now + 1
        self:RefreshReminderProtection()
    end
    local _, class = read(UnitClass, "player")
    local visible = iSTSettings.enabled and (not iSTSettings.onlyAsPaladin or class == "PALADIN")
        and read(UnitIsDeadOrGhost, "player") ~= true
    local inCombat = state.ReminderCombat == true or read(InCombatLockdown) == true
        or read(UnitAffectingCombat, "player") == true
    for kind, frame in pairs(self.ReminderFrames) do
        local settings = iSTSettings.reminders[kind]
        if previewUntil[kind] and now >= previewUntil[kind] then previewUntil[kind] = nil end
        local preview = previewUntil[kind] ~= nil or state.EditMode and settings.enabled
        local known, active, expires, icon, title
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
        end
        if secret(icon) then icon = nil end
        local remaining = number(expires) and expires > 0 and math.max(0, expires - now) or nil
        if remaining == 0 then active = false end
        local eligible = true
        if kind == "FURY" then
            if settings.protOnly and state.ReminderProtection ~= true then eligible = false end
            if settings.dungeonsOnly then
                local inInstance, instanceType = read(IsInInstance)
                if inInstance ~= true or (instanceType ~= "party" and instanceType ~= "raid") then
                    eligible = false
                end
            end
            if settings.partyOnly and read(IsInGroup) ~= true then eligible = false end
        else
            if settings.onlyInCombat and not inCombat then eligible = false end
            if settings.hideAfterIdle and not inCombat and now - lastSealCombatAt >= SEAL_IDLE_HIDE_SECONDS then
                eligible = false
            end
            if settings.hideInCapitals and inCapital(now) then eligible = false end
        end
        local warning = known and (not active or (remaining and settings.warningSeconds > 0 and remaining <= settings.warningSeconds))
        local show = visible and (preview or (settings.enabled and eligible and warning))
        -- A Fury timer can become stale while its aura is unreadable in combat.
        -- Sound "missing" only after Fury itself was confirmed absent.
        local soundActive = kind == "FURY" and state.FuryPresent == true or active
        self:UpdateReminderSound(kind, settings, inCombat, eligible, visible, preview, known, soundActive, warning)
        frame:SetShown(show == true)
        frame:SetFrameStrata(preview and "DIALOG" or "MEDIUM")
        frame:EnableMouse(not iSTSettings.barLocked and settings.enabled and not inCombat)
        if show then
            if preview then
                title = kind == "FURY" and L["ReminderFury"] or L["ReminderSeal"]
                active, remaining = true, math.max(1, settings.warningSeconds)
            end
            local left = settings.showIcon and 38 or 0
            local danger = not active
            local message
            if preview then message = title
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
    if iSTSettings.enabled and (enabled() or next(previewUntil) or state.EditMode) then
        worker:Show()
    else
        worker:Hide()
    end
    if state.EditMode then self:UpdateMoveOutlines() end
end

worker:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    iST:UpdateReminders()
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_DEAD",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_NODE_CHANGED",
    "TRAIT_TREE_CURRENCY_INFO_UPDATED" }) do
    if C_EventUtils.IsEventValid(event) then events:RegisterEvent(event) end
end
events:SetScript("OnEvent", function(_, event, ...)
    if not iSTSettings or not iST.ReminderFrames then return end
    if event == "PLAYER_REGEN_DISABLED" then iST.State.ReminderCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        iST.State.ReminderCombat = false
        lastSealCombatAt = GetTime()
    elseif event == "PLAYER_LOGIN" then
        lastSealCombatAt = GetTime()
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
        or event == "ZONE_CHANGED_NEW_AREA" then nextCapitalCheck = 0 end
    if event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_NODE_CHANGED" or event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" and (secret((...)) or (...) ~= "player") then return end
        iST.State.ReminderProtection = nil
        iST.State.ReminderProtectionGroup = nil
        iST.State.ReminderProtectionConfigID = nil
        iST.State.ReminderProtectionNextScanAt = 0
        nextProtectionRead = 0
        if iSTSettings.reminders.FURY.enabled and iSTSettings.reminders.FURY.protOnly then
            -- Talent events may arrive before the new points are available.
            -- Recheck once the active tree has settled, including same-group edits.
            protectionRefreshGeneration = protectionRefreshGeneration + 1
            local generation = protectionRefreshGeneration
            C_Timer.After(0.3, function()
                if generation ~= protectionRefreshGeneration then return end
                iST.State.ReminderProtection = nil
                iST.State.ReminderProtectionGroup = nil
                iST.State.ReminderProtectionConfigID = nil
                iST.State.ReminderProtectionNextScanAt = 0
                nextProtectionRead = 0
                iST:UpdateReminders()
            end)
        end
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
