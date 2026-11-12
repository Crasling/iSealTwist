local _, iST = ...
-- Hit capture stays idle until the player starts it with /ist hitdebug.
local L = setmetatable({
    HitDebugHelp = "Hit debug: start [10-180 seconds], stop, mark <note>, status, show, clear. Start before combat; default capture is 60 seconds.",
    HitDebugStarted = "Hit capture started for %d seconds. Use /ist hitdebug mark <note> for misses or buff counts you see.",
    HitDebugStopped = "Hit capture stopped. Use /ist hitdebug show to copy the report.",
    HitDebugNotRunning = "Start a capture with /ist hitdebug start first.",
    HitDebugMarked = "Marker added to the hit capture.",
    HitDebugStatus = "Hit capture: %s; %d stored rows.",
    HitDebugCleared = "Saved hit capture cleared.",
    HitDebugNoReport = "No hit capture saved. Use /ist hitdebug start before attacking.",
    HitDebugTitle = "iST Hit Debug",
    HitDebugCopyHint = "Text is selected: press Ctrl+C to copy. Escape closes this window.",
}, { __index = iST.L })
local HitDebug = {}
iST.HitDebug = HitDebug

local MAX_ROWS, MAX_SECONDS, COPY_LIMIT = 1000, 180, 120000
local frame = CreateFrame("Frame")
frame:Hide()
local capture, active, lastSwing, swingCount, targetCount
local playerGUID, lastMeterLine, lastMeterAt, previousTotals

local function secret(value) return issecretvalue and issecretvalue(value) end
local function number(value)
    return not secret(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end
local function text(value)
    if secret(value) then return "<secret>" end
    if type(value) == "number" then
        if not number(value) then return "<invalid number>" end
        return string.format(value == math.floor(value) and "%.0f" or "%.3f", value)
    end
    if type(value) == "boolean" then return value and "true" or "false" end
    if value == nil then return "nil" end
    if type(value) ~= "string" then return "<" .. type(value) .. ">" end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%c]", " "):sub(1, 180)
end
local function field(object, key)
    if secret(object) then return object end
    if type(object) ~= "table" then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
end
local function call(callback, ...)
    if type(callback) ~= "function" then return nil, "unavailable" end
    local ok, value = pcall(callback, ...)
    if not ok then return nil, "error: " .. text(value) end
    return value, secret(value) and "secret" or "returned"
end
local function notice(message)
    iST:PrintToChat(L["PrintPrefix"] .. message)
end
local function elapsedSinceSwing()
    return lastSwing and string.format("%.3f", GetTime() - lastSwing) or "none"
end

function HitDebug:IsActive() return active == true end

function HitDebug:Record(kind, message)
    if not active then return end
    local line = string.format("+%08.3f %s %s", GetTime() - capture.startedAt, kind, message):sub(1, 600)
    local index
    if capture.count < MAX_ROWS then
        capture.count = capture.count + 1
        index = (capture.head + capture.count - 2) % MAX_ROWS + 1
    else
        index = capture.head
        capture.head = capture.head % MAX_ROWS + 1
        capture.dropped = capture.dropped + 1
    end
    capture.rows[index] = line
end

function HitDebug:Snapshot(reason)
    local state, tracker = iST.State, iST.WrathTracker
    self:Record("STATE", "reason=" .. reason .. " combat=" .. text(call(InCombatLockdown))
        .. " seal=" .. text(state.CurrentSealName) .. " stacks=" .. text(tracker.count)
        .. " countUnconfirmed=" .. text(tracker.countUnconfirmed) .. " fake=" .. text(iSTSettings.fakeUnsealedWrath)
        .. " talentCached=" .. text(state.UnsealedWrathKnown)
        .. " wrathInstance=" .. text(state.WrathAuraInstanceID) .. " target#=" .. targetCount)
    local restriction = call(C_Secrets and C_Secrets.ShouldAurasBeSecret)
    self:Record("AURA", "restricted=" .. text(restriction))
    -- This is a diagnostic, not a way around aura restrictions. Never enumerate
    -- protected buffs or try to turn their values into public strings.
    if secret(restriction) or restriction ~= false then return end
    local aura, result = call(iST.FindWrathEchoAura, iST)
    self:Record("AURA", "echoQuery=" .. result .. " value=" .. text(aura)
        .. " applications=" .. text(field(aura, "applications"))
        .. " expiry=" .. text(field(aura, "expirationTime"))
        .. " instance=" .. text(field(aura, "auraInstanceID")))
    -- List matching public player buffs when aura access is available.
    local readIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if type(readIndex) ~= "function" then return end
    for index = 1, 40 do
        local candidate, status = call(readIndex, "player", index, "HELPFUL")
        if status ~= "returned" or secret(candidate) or candidate == nil then break end
        local name = field(candidate, "name")
        if not secret(name) and type(name) == "string" then
            local lowerName = name:lower()
            if lowerName:find("echo", 1, true) or lowerName:find("unsealed", 1, true)
                or lowerName:find("windfury", 1, true) then
                self:Record("AURA_CANDIDATE", "name=" .. text(name)
                    .. " spellID=" .. text(field(candidate, "spellId"))
                    .. " stacks=" .. text(field(candidate, "applications"))
                    .. " expiry=" .. text(field(candidate, "expirationTime"))
                    .. " instance=" .. text(field(candidate, "auraInstanceID")))
            end
        end
    end
end

local function spellName(id)
    if not number(id) then return "<unreadable ID>" end
    return text(call(C_Spell and C_Spell.GetSpellName, id))
end

function HitDebug:SampleMeter(force)
    if not active then return end
    local api = C_DamageMeter or {}
    local session, result = call(api.GetCombatSessionFromType, 1, 0)
    local sources = field(session, "combatSources")
    local own
    if not secret(sources) and type(sources) == "table" then
        for index, source in ipairs(sources) do
            if index > 80 then break end
            local isMe = field(source, "isLocalPlayer")
            if not secret(isMe) and isMe == true then own = source; break end
        end
    end
    local summary = "query=" .. result .. " session=" .. text(session) .. " sources=" .. text(sources)
        .. " selfTotal=" .. text(field(own, "totalAmount"))
    local sourceGUID = playerGUID
    if not sourceGUID then
        local candidate = field(own, "sourceGUID")
        if not secret(candidate) and type(candidate) == "string" and candidate ~= "" then sourceGUID = candidate end
    end
    local spells, detailsResult
    if sourceGUID then
        local sourceData
        sourceData, detailsResult = call(api.GetCombatSessionSourceFromType, 1, 0, sourceGUID)
        spells = field(sourceData, "combatSpells")
    else detailsResult = "skipped: no public player GUID" end
    summary = summary .. " breakdown=" .. detailsResult .. " spells=" .. text(spells)
    local spellLines = {}
    if not secret(spells) and type(spells) == "table" then
        for index, spell in ipairs(spells) do
            if index > 30 then break end
            local id, amount = field(spell, "spellID"), field(spell, "totalAmount")
            local delta = "unavailable"
            if number(id) and number(amount) then
                local previous = previousTotals[id]
                if previous then delta = amount >= previous and text(amount - previous) or "baseline reset" end
                previousTotals[id] = amount
            end
            spellLines[#spellLines + 1] = "row=" .. index .. " id=" .. text(id) .. " name=" .. spellName(id)
                .. " total=" .. text(amount) .. " delta=" .. delta
        end
    end
    -- Compare only strings built from public values and literal placeholders.
    -- A changing number on screen is not used to infer a protected delta.
    local signature = summary .. table.concat(spellLines, ";")
    local now = GetTime()
    if force or signature ~= lastMeterLine or now - lastMeterAt >= 1 then
        self:Record("METER", summary .. " sinceSwing=" .. elapsedSinceSwing())
        for _, line in ipairs(spellLines) do self:Record("SPELL_TOTAL", line) end
        lastMeterLine, lastMeterAt = signature, now
    end
end

function HitDebug:Stop(reason, quiet)
    if not active then return end
    self:Snapshot("capture stop")
    self:SampleMeter(true)
    self:Record("STOP", reason or "manual")
    capture.status, capture.elapsed = reason or "manual", GetTime() - capture.startedAt
    active = false
    frame:UnregisterAllEvents()
    frame:Hide()
    if not quiet then notice(L["HitDebugStopped"]) end
end

local EVENTS = { "PLAYER_SWING", "UNIT_COMBAT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
    "COMBAT_TEXT_UPDATE", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_RESET",
    "GROUP_ROSTER_UPDATE", "PLAYER_LOGOUT" }

function HitDebug:Start(seconds)
    if active then self:Stop("restarted", true) end
    seconds = number(seconds) and math.floor(seconds) or 60
    seconds = math.max(10, math.min(MAX_SECONDS, seconds))
    capture = { format = 1, version = text(iST.Version), client = text(iST.GameVersion), build = text(iST.GameBuild),
        startedAt = GetTime(), duration = seconds, status = "recording", count = 0, head = 1, dropped = 0, rows = {} }
    capture.grouped, capture.raid, capture.members = text(call(IsInGroup)), text(call(IsInRaid)), text(call(GetNumGroupMembers))
    iSTSettings.hitDebugCapture = capture
    active, lastSwing, swingCount, targetCount = true, nil, 0, 1
    lastMeterLine, lastMeterAt, previousTotals = nil, 0, {}
    local guid = call(UnitGUID, "player")
    playerGUID = not secret(guid) and type(guid) == "string" and guid or nil
    for _, event in ipairs(EVENTS) do
        if C_EventUtils.IsEventValid(event) then frame:RegisterEvent(event) end
    end
    frame:Show()
    self:Record("START", "duration=" .. seconds .. " grouped=" .. text(call(IsInGroup))
        .. " raid=" .. text(call(IsInRaid)) .. " members=" .. text(call(GetNumGroupMembers))
        .. " publicPlayerGUID=" .. text(playerGUID ~= nil))
    self:Record("METER_API", "available=" .. text(call(C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable)))
    self:Snapshot("capture start")
    self:SampleMeter(true)
    notice(string.format(L["HitDebugStarted"], seconds))
end

local COMBAT_TEXT_TYPES = { DAMAGE = true, SPELL_DAMAGE = true, MISS = true, DODGE = true, PARRY = true,
    BLOCK = true, RESIST = true, IMMUNE = true, SPELL_MISS = true, SPELL_DODGE = true, SPELL_PARRY = true }
frame:SetScript("OnEvent", function(_, event, ...)
    if not active then return end
    if event == "PLAYER_SWING" then
        local duration, hand = ...
        if not secret(hand) and hand == 0 then lastSwing, swingCount = GetTime(), swingCount + 1 end
        HitDebug:Record("SWING", "number=" .. swingCount .. " hand=" .. text(hand) .. " duration=" .. text(duration))
        HitDebug:Snapshot("swing")
    elseif event == "UNIT_COMBAT" then
        local unit, action, flags, amount, school = ...
        if secret(unit) or (unit ~= "player" and unit ~= "target") then return end
        HitDebug:Record("FEEDBACK", "unit=" .. text(unit) .. " action=" .. text(action) .. " flags=" .. text(flags)
            .. " amount=" .. text(amount) .. " school=" .. text(school) .. " sinceSwing=" .. elapsedSinceSwing()
            .. " target#=" .. targetCount)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, id = ...
        if secret(unit) or unit ~= "player" then return end
        HitDebug:Record("CAST", "id=" .. text(id) .. " name=" .. spellName(id)
            .. " knownSealCast=" .. text(number(id) and iST.SEALS[id] ~= nil) .. " sinceSwing=" .. elapsedSinceSwing())
    elseif event == "UNIT_AURA" then
        local unit, info = ...
        if secret(unit) or unit ~= "player" then return end
        local added, updated, removed = field(info, "addedAuras"), field(info, "updatedAuraInstanceIDs"), field(info, "removedAuraInstanceIDs")
        local function size(value)
            if secret(value) then return "<secret>" end
            return type(value) == "table" and tostring(#value) or "nil"
        end
        HitDebug:Record("AURA_EVENT", "added=" .. size(added) .. " updated=" .. size(updated) .. " removed=" .. size(removed))
        HitDebug:Snapshot("aura event")
    elseif event == "COMBAT_TEXT_UPDATE" then
        local kind = ...
        if not secret(kind) and COMBAT_TEXT_TYPES[kind] then HitDebug:Record("COMBAT_TEXT", kind .. " sinceSwing=" .. elapsedSinceSwing()) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        targetCount = targetCount + 1
        HitDebug:Record("TARGET", "number=" .. targetCount .. " exists=" .. text(call(UnitExists, "target"))
            .. " isPlayer=" .. text(call(UnitIsPlayer, "target")))
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        local kind, sessionID = ...
        -- One swing updates several meter categories. Keep Damage Done only;
        -- the other copies add no hit evidence and crowd useful rows out.
        if not secret(kind) and kind ~= 0 then return end
        HitDebug:Record("METER_UPDATE", "type=" .. text(kind) .. " session=" .. text(sessionID)
            .. " sinceSwing=" .. elapsedSinceSwing())
    elseif event == "GROUP_ROSTER_UPDATE" then
        HitDebug:Record("GROUP", "grouped=" .. text(call(IsInGroup)) .. " raid=" .. text(call(IsInRaid))
            .. " members=" .. text(call(GetNumGroupMembers)))
    elseif event == "PLAYER_LOGOUT" then
        HitDebug:Stop("logout", true)
    else
        if event == "PLAYER_REGEN_DISABLED" or event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" or event == "DAMAGE_METER_RESET" then
            -- Each fight has a different current-session total. Do not report
            -- a negative damage delta by comparing it with the previous fight.
            previousTotals = {}
        end
        HitDebug:Record(event, "sinceSwing=" .. elapsedSinceSwing())
        if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
            HitDebug:Snapshot(event)
            HitDebug:SampleMeter(true)
        end
    end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    if not active then return end
    if GetTime() - capture.startedAt >= capture.duration then HitDebug:Stop("time limit"); return end
end)

function HitDebug:GetReport()
    local saved = iSTSettings and iSTSettings.hitDebugCapture
    if type(saved) ~= "table" or saved.format ~= 1 then return L["HitDebugNoReport"] end
    local header = string.format("iST Hit Debug | v%s | Client %s | Build %s\nStatus: %s | Window: %ss | Rows: %d | Older rows dropped: %d\n",
        saved.version, saved.client, saved.build, saved.status == "recording" and not active and "interrupted by reload" or saved.status,
        saved.duration, saved.count, saved.dropped)
        .. "Group at start: " .. text(saved.grouped) .. " | Raid: " .. text(saved.raid) .. " | Members: " .. text(saved.members) .. "\n"
        .. "<secret> means intentionally unreadable. Target feedback has no attacker identity. Timing and public damage deltas are observations, not confirmed stack gains.\n\n"
    local lines, bytes = {}, #header
    for offset = saved.count - 1, 0, -1 do
        local line = saved.rows[(saved.head + offset - 1) % MAX_ROWS + 1]
        if bytes + #line + 1 > COPY_LIMIT then break end
        table.insert(lines, 1, line)
        bytes = bytes + #line + 1
    end
    if #lines < saved.count then header = header .. "Only the newest rows fit in this copy window.\n" end
    return header .. table.concat(lines, "\n")
end

function HitDebug:ShowReport()
    local window = self.window
    if not window then
        window = CreateFrame("Frame", "iSTHitDebugReport", UIParent, "BackdropTemplate")
        window:SetSize(820, 550)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetClampedToScreen(true)
        window:EnableMouse(true)
        window:SetMovable(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", function(self) self:StartMoving() end)
        window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        window:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        window:SetBackdropColor(0.025, 0.022, 0.018, 0.99)
        window:SetBackdropBorderColor(1, 0.59, 0.09, 1)
        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -15)
        title:SetText(L["HitDebugTitle"])
        local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 18, -40)
        hint:SetText(L["HitDebugCopyHint"])
        local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -5, -5)
        close:SetScript("OnClick", function() window:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -64)
        scroll:SetPoint("BOTTOMRIGHT", -34, 18)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(758)
        edit:SetHeight(1)
        edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed", function() window:Hide() end)
        scroll:SetScrollChild(edit)
        window.edit, window.scroll = edit, scroll
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "iSTHitDebugReport" end
        self.window = window
    end
    window.edit:SetText(self:GetReport())
    window:Show()
    window.edit:SetCursorPosition(0)
    window.scroll:SetVerticalScroll(0)
    window.edit:SetFocus()
    window.edit:HighlightText()
end

function iST:HandleHitDebugCommand(message)
    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "start" or command == "on" then HitDebug:Start(tonumber(argument))
    elseif command == "stop" or command == "off" then HitDebug:Stop("manual")
    elseif command == "show" or command == "report" then HitDebug:ShowReport()
    elseif command == "mark" then
        if not active then notice(L["HitDebugNotRunning"]); return end
        HitDebug:Record("MARK", text(argument ~= "" and argument or "manual marker"))
        HitDebug:Snapshot("manual marker")
        notice(L["HitDebugMarked"])
    elseif command == "status" then
        local saved = capture or iSTSettings.hitDebugCapture
        notice(string.format(L["HitDebugStatus"], active and "recording" or "stopped", saved and saved.count or 0))
    elseif command == "clear" then
        HitDebug:Stop("cleared", true)
        iSTSettings.hitDebugCapture, capture = nil, nil
        notice(L["HitDebugCleared"])
    else notice(L["HitDebugHelp"]) end
end
