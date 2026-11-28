local _, iST = ...
local L = iST.L
local FURY_SPELL = 25780
local SEAL_IDLE_HIDE_SECONDS = 300
local OWN_BUFF_FILTER = "HELPFUL|PLAYER"
local EXTERNAL_BUFF_FILTER = "HELPFUL|!PLAYER"
local CAPITAL_MAPS = { [1453] = "Alliance", [1454] = "Horde", [1455] = "Alliance",
    [1456] = "Horde", [1457] = "Alliance", [1458] = "Horde" }

iST.ReminderDefaults = {
    FURY = { enabled = false, showIcon = true, showTime = true, locked = true, scale = 1,
        warningSeconds = 60, protOnly = false, dungeonsOnly = false, partyOnly = false,
        hideOnTaxi = false, hideWhileDead = true, hideInCapitals = false,
        soundExpiring = false, soundMissing = false, soundChoice = "FILE:Sharp Pulse",
        point = { "CENTER", "CENTER", -180, -120 } },
    SEAL = { enabled = false, showIcon = true, showTime = true, locked = true, scale = 1,
        warningSeconds = 5, onlyInCombat = false, hideAfterIdle = false,
        hideOnTaxi = false, hideWhileDead = true, hideInCapitals = false,
        soundExpiring = false, soundMissing = false, soundChoice = "FILE:Alert Tick",
        point = { "CENTER", "CENTER", 180, -120 } },
    BLESSING = { enabled = false, showIcon = true, showTime = true, scale = 1,
        warningSeconds = 60, onlyInCombat = false, spell = "MIGHT",
        hideOnTaxi = false, hideWhileDead = true, hideInCapitals = false,
        soundExpiring = false, soundMissing = false, soundChoice = "FILE:Soft Chime",
        point = { "CENTER", "CENTER", -180, -165 } },
    AURA = { enabled = false, showIcon = true, showTime = false, scale = 1,
        warningSeconds = 0, onlyInCombat = false, spell = "ANY",
        hideOnTaxi = false, hideWhileDead = true, hideInCapitals = false,
        soundExpiring = false, soundMissing = false, soundChoice = "FILE:Soft Chime",
        point = { "CENTER", "CENTER", 180, -165 } },
}

iST.ReminderKinds = { "FURY", "SEAL", "BLESSING", "AURA" }
local reminderTitles = {
    FURY = "ReminderFury", SEAL = "ReminderSeal", BLESSING = "ReminderBlessing", AURA = "ReminderAura",
}
local remindersBySpell = {
    BLESSING = {
        { key = "MIGHT", name = "Blessing of Might", id = 19740, greater = 25782,
            rankIDs = { 19834, 19835, 19836, 19837, 19838, 25291, 25916 } },
        { key = "WISDOM", name = "Blessing of Wisdom", id = 19742, greater = 25894,
            rankIDs = { 19850, 19852, 19853, 19854, 25290, 25918 } },
        { key = "KINGS", name = "Blessing of Kings", id = 20217, greater = 25898 },
    },
    AURA = {
        { key = "DEVOTION", name = "Devotion Aura", id = 465,
            rankIDs = { 10290, 643, 10291, 1032, 10292, 10293 } },
        { key = "RETRIBUTION", name = "Retribution Aura", id = 7294,
            rankIDs = { 10298, 10299, 10300, 10301 } },
        { key = "CONCENTRATION", name = "Concentration Aura", id = 19746 },
        { key = "SHADOW", name = "Shadow Resistance Aura", id = 19876, rankIDs = { 19895, 19896 } },
        { key = "FROST", name = "Frost Resistance Aura", id = 19888, rankIDs = { 19897, 19898 } },
        { key = "FIRE", name = "Fire Resistance Aura", id = 19891, rankIDs = { 19899, 19900 } },
    },
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
    for _, kind in ipairs(iST.ReminderKinds) do
        local settings = iSTSettings and iSTSettings.reminders and iSTSettings.reminders[kind]
        if settings and settings.enabled then return true end
    end
    return false
end
local previewUntil, nextProtectionRead = {}, 0
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

function iST:GetReminderTitle(kind)
    return L[reminderTitles[kind]]
end

function iST:GetReminderSpellOptions(kind)
    local options = { { value = "ANY", text = L["ReminderAny" .. kind] } }
    for _, spell in ipairs(remindersBySpell[kind] or {}) do
        options[#options + 1] = {
            value = spell.key, text = read(C_Spell and C_Spell.GetSpellName, spell.id) or spell.name,
        }
    end
    return options
end

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
        if defaults.spell and settings.spell ~= "ANY" then
            local found = false
            for _, spell in ipairs(remindersBySpell[kind]) do
                if spell.key == settings.spell then found = true; break end
            end
            if not found then settings.spell = defaults.spell end
        end
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
    if not class then return end
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
        and state.ReminderProtection ~= nil then return end
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
        if secret(nodes) or type(nodes) ~= "table" or #nodes == 0 then return nil end
        local hasNode = false
        for _, nodeID in ipairs(nodes) do
            if not number(nodeID) then return nil end
            local node = traits.GetNodeInfo(configID, nodeID)
            if secret(node) then return nil end
            if node then hasNode = true end
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
        return hasNode and result or nil
    end)
    if not ok or not points then return end
    state.ReminderProtectionGroup = group
    state.ReminderProtectionConfigID = configID
    state.ReminderProtection = points[2] > 0 and points[2] > points[1] and points[2] > points[3]
    if iSTSettings.debugMode then
        local message = string.format(
            "Righteous Fury reminder: config %d, group %s. Holy %d / Protection %d / Retribution %d. Protection filter %s.",
            configID, tostring(group or "?"), points[1], points[2], points[3],
            state.ReminderProtection and "matched" or "not matched")
        if state.ReminderProtectionDebugMessage ~= message then
            state.ReminderProtectionDebugMessage = message
            self:DebugMsg(message, 3)
        end
    end
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

local function BuildBuffWatch(kind, selection)
    local api = C_Spell or {}
    local spells = remindersBySpell[kind]
    local watch = { selection = selection, names = {}, ids = {}, auras = {}, familyCount = #spells }
    watch.title = L["ReminderAny" .. kind]
    for _, spell in ipairs(spells) do
        local name = read(api.GetSpellName, spell.id) or spell.name
        watch.names[name], watch.ids[spell.id] = spell.key, spell.key
        if spell.greater then
            local greater = read(api.GetSpellName, spell.greater) or ("Greater " .. spell.name)
            watch.names[greater], watch.ids[spell.greater] = spell.key, spell.key
        end
        if spell.rankIDs then
            for _, id in ipairs(spell.rankIDs) do watch.ids[id] = spell.key end
        end
        if selection == "ANY" or selection == spell.key then
            if selection ~= "ANY" then watch.title = name end
            watch.icon = watch.icon or read(api.GetSpellTexture, spell.id)
        end
    end
    return watch
end

local function IsSelfCast(aura, instanceID, previousOwner)
    local caster = read(function() return aura.sourceUnit end)
    if caster == "player" then return true end
    if type(caster) == "string" and caster ~= "" then
        local own = read(UnitIsUnit, caster, "player")
        if type(own) == "boolean" then return own end
    end
    local own = read(function() return aura.isFromPlayerOrPlayerPet end)
    if type(own) == "boolean" then return own end
    if previousOwner ~= nil then return previousOwner end
    if instanceID then
        local filtered = read(C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID,
            "player", instanceID, OWN_BUFF_FILTER)
        if type(filtered) == "boolean" then return not filtered end
    end
end

local buffWatches = {}
local nextBuffScan = 0
local function SyncBuffWatches()
    for kind in pairs(remindersBySpell) do
        local settings = iSTSettings.reminders[kind]
        local watch = buffWatches[kind]
        if not settings.enabled then
            buffWatches[kind] = nil
        elseif not watch or watch.selection ~= settings.spell then
            buffWatches[kind] = BuildBuffWatch(kind, settings.spell)
            nextBuffScan = 0
        end
    end
end

local function ObserveBuffAura(aura, seen, instanceID)
    if secret(aura) or type(aura) ~= "table" then return false end
    local name = read(function() return aura.name end)
    local id = read(function() return aura.spellId end)
    instanceID = instanceID or read(function() return aura.auraInstanceID end)
    if not number(instanceID) or instanceID <= 0 then instanceID = nil end
    local identified = type(name) == "string" or number(id)

    for kind, watch in pairs(buffWatches) do
        local previous = instanceID and watch.auras[instanceID]
        local family = watch.ids[id] or watch.names[name] or (not identified and previous and previous.family)
        if family then
            local selfCast = IsSelfCast(aura, instanceID, previous and previous.selfCast)
            local fallbackKey = family .. ":" .. tostring(selfCast)
            local key = instanceID or fallbackKey
            previous = previous or watch.auras[fallbackKey]
            local expires = read(function() return aura.expirationTime end)
            local icon = read(function() return aura.icon end)
            if instanceID then watch.auras[fallbackKey] = nil end
            if selfCast == true then
                watch.known = true
                -- One Blessing and one Aura per Paladin can be active on the player.
                for oldKey, other in pairs(watch.auras) do
                    if oldKey ~= key and other.selfCast == true then watch.auras[oldKey] = nil end
                end
            end
            watch.auras[key] = { family = family, selfCast = selfCast,
                expires = number(expires) and expires or (previous and previous.expires),
                icon = icon or (previous and previous.icon) }
            if seen then seen[kind][key] = true end
        end
    end
    return identified
end

local function scanBuffReminders(now, inCombat)
    SyncBuffWatches()
    if not next(buffWatches) or now < nextBuffScan then return end
    nextBuffScan = now + 1
    local seen = {}
    for kind in pairs(buffWatches) do seen[kind] = {} end
    local identifiedAll, sawAura = true, false
    local lookup = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for index = 1, 255 do
        local aura, readable = queryAura(lookup, "player", index, "HELPFUL")
        if not readable then return end
        if not aura then
            -- A restricted combat scan can end without exposing any buffs.
            local restricted = inCombat and read(C_Secrets and C_Secrets.ShouldAurasBeSecret) == true
            if not identifiedAll or restricted or (inCombat and not sawAura) then return end
            for kind, watch in pairs(buffWatches) do
                watch.known = true
                for key in pairs(watch.auras) do
                    if not seen[kind][key] then watch.auras[key] = nil end
                end
            end
            return
        end
        sawAura = true
        if not ObserveBuffAura(aura, seen) then identifiedAll = false end
    end
end

local function UpdateBuffAuras(info)
    if not next(buffWatches) then return end
    if read(function() return info.isFullUpdate end) == true then nextBuffScan = 0 end
    local removed = read(function() return info.removedAuraInstanceIDs end)
    if type(removed) == "table" then
        for _, id in ipairs(removed) do
            if number(id) then
                for _, watch in pairs(buffWatches) do watch.auras[id] = nil end
            end
        end
    end
    local added = read(function() return info.addedAuras end)
    if type(added) == "table" then
        for _, aura in ipairs(added) do ObserveBuffAura(aura) end
    end
    local updated = read(function() return info.updatedAuraInstanceIDs end)
    if type(updated) == "table" then
        local lookup = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
        for _, id in ipairs(updated) do
            if number(id) then ObserveBuffAura(queryAura(lookup, "player", id), nil, id) end
        end
    end
end

local function GetBuffStatus(watch, now)
    local covered, count = {}, 0
    local activeAura, unknownCaster
    for _, aura in pairs(watch.auras) do
        local expires, family = aura.expires, aura.family
        if not expires or expires == 0 or expires > now then
            if not covered[family] then
                covered[family] = true
                count = count + 1
            end
            if watch.selection == "ANY" or watch.selection == family then
                if aura.selfCast == true then activeAura = aura
                elseif aura.selfCast == nil then unknownCaster = true end
            end
        end
    end
    if activeAura then return true, true, activeAura.expires, activeAura.icon end
    if count == watch.familyCount then return true, true end
    return watch.known and not unknownCaster, false, nil, nil, covered[watch.selection]
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

local function CreateReminderArtwork(frame)
    local art = CreateFrame("Frame", nil, frame)
    art:SetAllPoints(frame)
    art:EnableMouse(false)
    frame.artwork = art
    -- Only the icon has a border. The warning text floats over the world.
    frame.iconFrame = CreateFrame("Frame", nil, art, "BackdropTemplate")
    frame.iconFrame:SetSize(30, 30)
    frame.iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.iconFrame:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
    frame.iconFrame:SetBackdropColor(0, 0, 0, 0.8)
    frame.iconFrame:EnableMouse(false)
    frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", frame.iconFrame, "TOPLEFT", 2, -2)
    frame.icon:SetPoint("BOTTOMRIGHT", frame.iconFrame, "BOTTOMRIGHT", -2, 2)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.title = art:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    frame.timer = art:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.timer:SetJustifyH("LEFT")
    frame.timer:SetWordWrap(false)
    frame.timer:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -1)
    frame.timer:SetTextColor(1, 0.88, 0.62)
    local font = frame.title:GetFont()
    frame.title:SetFont(font, 16, "OUTLINE")
    frame.timer:SetFont(font, 11, "OUTLINE")
    for _, label in ipairs({ frame.title, frame.timer }) do
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
    end
end

function iST:InitializeReminders()
    if self.ReminderFrames then return end
    self.ReminderFrames = {}
    for _, kind in ipairs(self.ReminderKinds) do
        local reminderKind = kind
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(180, 34)
        frame:SetFrameStrata("MEDIUM")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(false)
        frame:RegisterForDrag("LeftButton")
        CreateReminderArtwork(frame)
        frame:SetScript("OnDragStart", function(self)
            if iST.State.EditMode and not iSTSettings.barLocked and iSTSettings.reminders[reminderKind].enabled
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
    nextBuffScan = 0
    for kind, frame in pairs(self.ReminderFrames) do
        local settings = iSTSettings.reminders[kind]
        frame:SetScale(settings.scale)
        frame:ClearAllPoints()
        local point = settings.point
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    end
    if iSTSettings.reminders.FURY.enabled then self:RefreshReminderFury() end
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

local function RenderReminder(frame, showIcon, icon, message, timerText, danger)
    local remeasure = false
    if frame.displayIcon ~= showIcon then
        frame.iconFrame:SetShown(showIcon)
        frame.icon:SetShown(showIcon)
        frame.displayIcon = showIcon
        remeasure = true
    end
    if showIcon and frame.displayTexture ~= icon then
        frame.icon:SetTexture(icon)
        frame.displayTexture = icon
    end
    if frame.displayDanger ~= danger then
        frame.title:SetTextColor(1, danger and 0.25 or 0.82, danger and 0.15 or 0.35)
        frame.iconFrame:SetBackdropBorderColor(1, danger and 0.25 or 0.75, danger and 0.15 or 0.25, 0.9)
        frame.displayDanger = danger
    end
    if frame.displayMessage ~= message then
        frame.title:SetText(message)
        frame.displayMessage = message
        remeasure = true
    end
    if frame.displayTimer ~= timerText then
        frame.timer:SetText(timerText)
        frame.displayTimer = timerText
        remeasure = true
    end
    local left, hasTimer = showIcon and 38 or 0, timerText ~= ""
    if frame.displayLeft ~= left or frame.displayHasTimer ~= hasTimer then
        frame.title:SetPoint("LEFT", frame, "LEFT", left, hasTimer and 7 or 0)
        frame.timer:SetShown(hasTimer)
        frame.displayLeft, frame.displayHasTimer = left, hasTimer
    end
    if remeasure then
        local width = left + math.max(frame.title:GetStringWidth(), frame.timer:GetStringWidth()) + 4
        if frame.displayWidth ~= width then
            frame:SetWidth(width)
            frame.displayWidth = width
        end
    end
end

local function MissingBuffMessage(kind, selection, title)
    if kind == "SEAL" then return L["ReminderCastSeal"] end
    if selection == "ANY" then
        if kind == "AURA" then return L["ReminderActivateAura"] end
        if kind == "BLESSING" then return L["ReminderCastBlessing"] end
    end
    return string.format(L["ReminderCastBuff"], title)
end

local AURA_WARNING_WIDTH = 640
local AURA_WARNING_SPAN = AURA_WARNING_WIDTH + 1

local function GetNativeBuffFilters(watch)
    local own, families = {}, {}
    for id, family in pairs(watch.ids) do
        if not families[family] then families[family] = {} end
        families[family][id] = true
        if watch.selection == "ANY" or watch.selection == family then own[id] = true end
    end
    return own, families
end

local function CreateBuffContainer(parent)
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:EnableMouse(false)
    container:SetUnit("player")
    return container
end

local function AddBuffPresenceGroup(container, key, filter, ids, width)
    container:AddAuraGroup(key, filter, {
        candidateFilters = { includeSpellIDs = ids },
        maxFrameCount = 1,
        layout = { elementWidth = width or AURA_WARNING_SPAN, elementHeight = 1 },
        initializeFrame = function(button) button:EnableMouse(false) end,
    })
end

local function CreateBuffClip(parent)
    local clip = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    return clip
end

local function CreateBuffAbsenceClip(root, container, threshold, parent)
    container:SetPoint("TOPLEFT", root, "TOPLEFT", -1 - (threshold - 1) * AURA_WARNING_SPAN, 0)
    local clip = CreateBuffClip(parent or root)
    clip:SetPoint("TOPLEFT", container, "TOPRIGHT")
    clip:SetPoint("BOTTOMRIGHT", root, "BOTTOMLEFT", AURA_WARNING_WIDTH, 0)
    return clip
end

local function CreateBuffWarningRow(root, clip)
    local row = CreateFrame("Frame", nil, clip)
    row:SetSize(180, 34)
    row:SetPoint("LEFT", root, "LEFT")
    row:EnableMouse(false)
    row:Show()
    CreateReminderArtwork(row)
    return row
end

local function CreateNativeBuffWarning(root, kind, watch)
    local ownIDs, families = GetNativeBuffFilters(watch)
    local native = { root = root, presence = CreateBuffContainer(root), watch = watch }
    -- Each covered family adds one span. A matching self-cast contributes
    -- the entire threshold, so either condition closes the missing text clip.
    AddBuffPresenceGroup(native.presence, "own", OWN_BUFF_FILTER, ownIDs, watch.familyCount * AURA_WARNING_SPAN)
    for family, ids in pairs(families) do AddBuffPresenceGroup(native.presence, family, "HELPFUL", ids) end
    local missingClip = CreateBuffAbsenceClip(root, native.presence, watch.familyCount)
    -- A matching buff from another caster selects the general reminder.
    native.tracked = CreateBuffContainer(root)
    AddBuffPresenceGroup(native.tracked, "tracked", EXTERNAL_BUFF_FILTER, ownIDs)
    local specificClip = CreateBuffAbsenceClip(root, native.tracked, 1, missingClip)
    local generalClip = CreateBuffClip(missingClip)
    generalClip:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT")
    generalClip:SetPoint("TOPRIGHT", native.tracked, "TOPRIGHT")
    native.missing = CreateBuffWarningRow(root, specificClip)
    native.general = CreateBuffWarningRow(root, generalClip)
    if kind == "BLESSING" then
        native.expiring = CreateBuffContainer(root)
        native.expiring:SetPoint("TOPLEFT", root, "TOPLEFT")
        native.expiring:AddAuraSlot("expiring", OWN_BUFF_FILTER, {
            candidateFilters = { includeSpellIDs = ownIDs },
            initializeFrame = function(button)
                button:SetAllPoints(root)
                button:EnableMouse(false)
                local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetPoint("LEFT", button, "LEFT")
                label:SetJustifyH("LEFT")
                label:SetWordWrap(false)
                label:SetFont(label:GetFont(), 16, "OUTLINE")
                label:SetShadowColor(0, 0, 0, 1)
                label:SetShadowOffset(1, -1)
                label:SetTextColor(1, 0.82, 0.35)
                native.expiringButton, native.expiringLabel = button, label
            end,
        })
    end
    return native
end

local function ConfigureNativeBuffWarning(native, kind, watch, settings)
    if native.watch ~= watch then
        local ownIDs = GetNativeBuffFilters(watch)
        native.presence:SetAuraGroupCandidateFilters("own", { includeSpellIDs = ownIDs })
        native.tracked:SetAuraGroupCandidateFilters("tracked", { includeSpellIDs = ownIDs })
        if native.expiring then native.expiring:SetAuraSlotCandidateFilters("expiring", { includeSpellIDs = ownIDs }) end
    end
    local icon = watch.icon or 134400
    RenderReminder(native.missing, settings.showIcon, icon, MissingBuffMessage(kind, watch.selection, watch.title), "", true)
    RenderReminder(native.general, settings.showIcon, icon, MissingBuffMessage(kind, "ANY", watch.title), "", true)
    if native.expiring then
        local formatter = C_StringUtil.CreateNumericRuleFormatter()
        local refresh = string.format(L["ReminderRefreshBuff"], watch.title):gsub("%%", "%%%%")
        if settings.showIcon then refresh = ("|T%d:28:28|t  "):format(icon) .. refresh end
        if settings.showTime then refresh = refresh .. "  |cffffe09e" .. L["ReminderTimeLeft"]:format("%.0fs") .. "|r" end
        local limit = settings.warningSeconds
        formatter:SetBreakpoints({
            { threshold = 0, format = limit > 0 and refresh or "" },
            { threshold = limit + 0.001, format = "" },
        })
        native.expiringButton:SetDurationText(native.expiringLabel, { textFormatter = formatter })
    end
    native.watch = watch
    native.showIcon, native.showTime, native.warningSeconds = settings.showIcon, settings.showTime, settings.warningSeconds
    native.configured = true
end

local function EnableNativeBuffWarning(native, enabled)
    native.presence:SetEnabled(enabled)
    native.tracked:SetEnabled(enabled)
    if native.expiring then native.expiring:SetEnabled(enabled) end
    native.enabled = enabled
end

local function SyncNativeBuffWarning(frame, kind, watch, settings)
    local native = frame.nativeBuff
    if not watch or not settings.enabled then
        if native and native.enabled then
            if not pcall(EnableNativeBuffWarning, native, false) then native.enabled = false end
        end
        return
    end
    if frame.nativeBuffFailed then return end
    if not native then
        if not iST.EnsureNativeAuraContainer() then return end
        if kind == "BLESSING" and not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
        local root = CreateFrame("Frame", nil, frame)
        root:SetAllPoints(frame)
        root:EnableMouse(false)
        root:Hide()
        local ok, result = pcall(CreateNativeBuffWarning, root, kind, watch)
        if not ok then
            frame.nativeBuffFailed = true
            iST:DebugMsg("Native reminder could not be created: " .. tostring(result), 2)
            return
        end
        native = result
        frame.nativeBuff = native
    end
    if not native.configured or native.watch ~= watch or native.showIcon ~= settings.showIcon
        or native.showTime ~= settings.showTime or native.warningSeconds ~= settings.warningSeconds then
        local ok, err = pcall(ConfigureNativeBuffWarning, native, kind, watch, settings)
        if not ok then
            native.configured = false
            frame.nativeBuffFailed = true
            pcall(EnableNativeBuffWarning, native, false)
            iST:DebugMsg("Native reminder could not be configured: " .. tostring(err), 2)
            return
        end
    end
    if not native.enabled then
        local ok, err = pcall(EnableNativeBuffWarning, native, true)
        if not ok then
            frame.nativeBuffFailed = true
            pcall(EnableNativeBuffWarning, native, false)
            iST:DebugMsg("Native reminder could not be enabled: " .. tostring(err), 2)
        end
    end
end

function iST:UpdateReminders()
    if not self.ReminderFrames then return end
    local now, state = GetTime(), self.State
    if not (enabled() or next(previewUntil) or state.EditMode or worker:IsShown()) then return end
    if iSTSettings.reminders.FURY.enabled and now >= (state.FuryNextCheckAt or 0) then
        self:RefreshReminderFury()
    end
    local _, class = read(UnitClass, "player")
    local visible = iSTSettings.enabled and (not iSTSettings.onlyAsPaladin or class == "PALADIN")
    local dead = visible and read(UnitIsDeadOrGhost, "player") == true
    local onTaxi
    local inCombat = state.ReminderCombat == true or read(InCombatLockdown) == true
        or read(UnitAffectingCombat, "player") == true
    local fury = iSTSettings.reminders.FURY
    if visible and not inCombat and fury.enabled and fury.protOnly
        and state.ReminderProtection == nil and now >= nextProtectionRead then
        nextProtectionRead = now + 1
        self:RefreshReminderProtection()
    end
    if visible then scanBuffReminders(now, inCombat) end
    for kind, frame in pairs(self.ReminderFrames) do
        local settings = iSTSettings.reminders[kind]
        if previewUntil[kind] and now >= previewUntil[kind] then previewUntil[kind] = nil end
        local preview = previewUntil[kind] ~= nil or state.EditMode and settings.enabled
        local known, active, expires, icon, title, trackedPresent
        local watch = buffWatches[kind]
        if kind == "FURY" then
            known, active, expires = state.FuryKnown, state.FuryPresent, state.FuryExpiresAt
            title = L["ReminderFury"]
        elseif kind == "SEAL" then
            known, expires = state.SealStatusKnown, state.SealExpiresAt
            active = state.CurrentSealName ~= nil and expires and expires > now
            title = state.CurrentSealName or L["ReminderSeal"]
            icon = state.CurrentSealIcon
            if secret(icon) then icon = nil end
        else
            title = self:GetReminderTitle(kind)
            if watch then
                known, active, expires, icon, trackedPresent = GetBuffStatus(watch, now)
                title, icon = watch.title, icon or watch.icon
            end
        end
        if secret(icon) then icon = nil end
        local remaining = number(expires) and expires > 0 and math.max(0, expires - now) or nil
        if remaining == 0 then active = false end
        local eligible = not (settings.hideWhileDead and dead)
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
            if kind == "SEAL" and settings.hideAfterIdle and not inCombat
                and now - lastSealCombatAt >= SEAL_IDLE_HIDE_SECONDS then
                eligible = false
            end
        end
        if visible and settings.enabled and eligible and not preview then
            if settings.hideOnTaxi then
                if onTaxi == nil then onTaxi = not not read(UnitOnTaxi, "player") end
                if onTaxi then eligible = false end
            end
            if eligible and settings.hideInCapitals and inCapital(now) then eligible = false end
        end
        local warning = known and (not active or (remaining and settings.warningSeconds > 0 and remaining <= settings.warningSeconds))
        if remindersBySpell[kind] and not inCombat then
            SyncNativeBuffWarning(frame, kind, visible and watch or nil, settings)
        end
        local native = frame.nativeBuff
        local showNative = (inCombat and not preview and visible and settings.enabled and eligible
            and native and native.enabled and native.configured) == true
        local show = showNative or (visible and (preview or (settings.enabled and eligible and warning))) == true
        -- A Fury timer can become stale while its aura is unreadable in combat.
        -- Sound "missing" only after Fury itself was confirmed absent.
        local soundActive = kind == "FURY" and state.FuryPresent == true or active
        self:UpdateReminderSound(kind, settings, inCombat, eligible, visible, preview, known, soundActive, warning)
        if frame.displayShown ~= show then
            frame:SetShown(show)
            frame.displayShown = show
        end
        if frame.nativeVisible ~= showNative then
            if native then native.root:SetShown(showNative) end
            frame.artwork:SetShown(not showNative)
            frame.nativeVisible = showNative
        end
        local strata = preview and "DIALOG" or "MEDIUM"
        if frame.displayStrata ~= strata then
            frame:SetFrameStrata(strata)
            frame.displayStrata = strata
        end
        local movable = state.EditMode == true and not iSTSettings.barLocked and settings.enabled and not inCombat
        if frame:IsMouseEnabled() ~= movable then frame:EnableMouse(movable) end
        if show and not showNative then
            if preview then
                if kind == "FURY" or kind == "SEAL" then title = self:GetReminderTitle(kind) end
                active, remaining = true, math.max(1, settings.warningSeconds)
            end
            local danger = not active
            local message
            if preview then message = title
            elseif active then message = string.format(L["ReminderRefreshBuff"], title)
            else message = MissingBuffMessage(kind, trackedPresent and "ANY" or settings.spell, title) end
            local timerText = preview and L["ReminderPreview"]
                or settings.showTime and active and remaining and string.format(L["ReminderTimeLeft"], remainingText(remaining)) or ""
            if settings.showIcon and not icon and (kind == "FURY" or kind == "SEAL") then
                local spellID = kind == "FURY" and FURY_SPELL or self.SEAL_SPELL_IDS[iSTSettings.twistFromSeal]
                if frame.fallbackSpellID ~= spellID or not frame.fallbackIcon then
                    frame.fallbackIcon = read(C_Spell and C_Spell.GetSpellTexture, spellID)
                    frame.fallbackSpellID = spellID
                end
                icon = frame.fallbackIcon
            end
            RenderReminder(frame, settings.showIcon, icon or 134400, message, timerText, danger)
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
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
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
        nextBuffScan = 0
    elseif event == "PLAYER_LOGIN" then
        lastSealCombatAt = GetTime()
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
        or event == "ZONE_CHANGED_NEW_AREA" then nextCapitalCheck = 0 end
    if event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_NODE_CHANGED" or event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" and (secret((...)) or (...) ~= "player") then return end
        -- Talent events can arrive before the active tree reflects the edit.
        -- Wait for the event burst to settle, then cache the next readable result.
        iST.State.ReminderProtection = nil
        nextProtectionRead = GetTime() + 0.3
    end
    if not enabled() then iST:UpdateReminders(); return end
    local furyFromEvent = false
    if event == "UNIT_AURA" then
        local unit, info = ...
        if secret(unit) or unit ~= "player" then return end
        if not secret(info) and type(info) == "table" then
            UpdateBuffAuras(info)
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
