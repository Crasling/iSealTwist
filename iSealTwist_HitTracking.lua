local _, iST = ...

-- Measured in the 70862 captures: physical feedback followed swings by about
-- 0.43-0.57s, or 0.99s on some Command-proc swings. Match those delayed events;
-- UNIT_COMBAT does not name the attacker.
local MIN_DELAY, MAX_DELAY = 0.30, 1.20
-- Close player swing events can be one attack burst. Target damage alone does
-- not prove that a second hit was ours, so each player swing permits one result.
local BURST_GAP, MAX_BURST_SWINGS = 0.15, 2
local TIMING_EPSILON = 0.000001
local OUTCOMES = { WOUND = true, MISS = true, DODGE = true, PARRY = true }
-- Successful cast IDs paired with Holy damage in the Forever captures.
local HOLY_ATTACK_CASTS = { [1866] = true, [20271] = true } -- Holy Strike, Judgement
local function secret(value) return issecretvalue and issecretvalue(value) end
local function number(value)
    return not secret(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function iST:NewWrathHitMatcher()
    local matcher = { pending = {}, targetGeneration = 0, nextID = 0 }
    local function deadline(swing)
        return swing.firstOutcomeAt and (swing.firstOutcomeAt + BURST_GAP) or (swing.at + MAX_DELAY)
    end
    local function eligible(swing, now, target)
        if swing.target ~= target then return false end
        if swing.firstOutcomeAt then return now <= deadline(swing) + TIMING_EPSILON end
        local elapsed = now - swing.at
        return elapsed >= MIN_DELAY - TIMING_EPSILON and elapsed <= MAX_DELAY + TIMING_EPSILON
    end
    function matcher:Clear(changeTarget)
        self.pending = {}
        if changeTarget then self.targetGeneration = self.targetGeneration + 1 end
    end
    function matcher:Expire(now)
        for index = #self.pending, 1, -1 do
            local swing = self.pending[index]
            if swing.invalid or now > deadline(swing) + TIMING_EPSILON then table.remove(self.pending, index) end
        end
    end
    function matcher:Add(now, seal, sealExpiresAt, revision, tracker)
        self:Expire(now)
        local previous = self.pending[#self.pending]
        if previous and previous.outcomes == 0 and previous.swingEvents < MAX_BURST_SWINGS
            and previous.target == self.targetGeneration and previous.seal == seal
            and now - previous.at <= BURST_GAP + TIMING_EPSILON then
            -- Some extra attacks may emit their own swing event. Only that
            -- player event can increase the number of results we accept.
            previous.swingEvents = previous.swingEvents + 1
            return previous, false
        end
        self.nextID = self.nextID + 1
        local swing = { id = self.nextID, at = now, seal = seal, sealExpiresAt = sealExpiresAt,
            target = self.targetGeneration, revision = revision, outcomes = 0, swingEvents = 1,
            previousCount = tracker:GetCount(now), previousSeal = tracker.seal, previousExpiry = tracker.expiresAt,
            previousCountUnconfirmed = tracker.countUnconfirmed,
            previousExpiryUnconfirmed = tracker.expiryUnconfirmed }
        if #self.pending >= 8 then table.remove(self.pending, 1) end
        self.pending[#self.pending + 1] = swing
        return swing, true
    end
    function matcher:Match(now, action)
        self:Expire(now)
        local found, candidates = nil, 0
        for index, swing in ipairs(self.pending) do
            if eligible(swing, now, self.targetGeneration) then
                candidates, found = candidates + 1, index
            end
        end
        if candidates == 0 then return nil, "no matching swing" end
        if candidates > 1 then
            -- Separate swing windows still need an unambiguous match. Close
            -- extra-attack events were already combined when they were queued.
            for index = #self.pending, 1, -1 do
                if eligible(self.pending[index], now, self.targetGeneration) then
                    table.remove(self.pending, index)
                end
            end
            return nil, "overlapping swings"
        end
        local swing = self.pending[found]
        if swing.holyCast and action ~= "WOUND" and not swing.contested then
            -- An avoided Holy Strike can report school 1 too. Keep waiting for
            -- the autoattack's physical hit rather than consuming this attempt.
            return nil, "avoidance overlapped a Holy spell"
        end
        if swing.contested then
            table.remove(self.pending, found)
            return nil, "another cast overlapped the swing"
        end
        swing.outcomes = swing.outcomes + 1
        swing.firstOutcomeAt = swing.firstOutcomeAt or now
        if swing.outcomes >= swing.swingEvents then
            table.remove(self.pending, found)
        end
        return swing, action == "WOUND" and "hit" or "avoided"
    end
    return matcher
end

local function matcher()
    if not iST.WrathHitMatcher then iST.WrathHitMatcher = iST:NewWrathHitMatcher() end
    return iST.WrathHitMatcher
end

local function log(message)
    iST:DebugMsg("Wrath hit tracking: " .. message, 3)
end

local function trace(format, ...)
    local recorder = iST.HitDebug
    if recorder and recorder:IsActive() then
        recorder:Record("TRACK", string.format(format, ...))
    end
end

function iST:CancelPendingWrathHits(changeTarget)
    if self.WrathHitMatcher then self.WrathHitMatcher:Clear(changeTarget) end
end

function iST:QueueWrathSwing(now)
    if not iSTSettings.enabled then trace("swing skipped: addon disabled"); return end
    if not self:IsWrathTrackingEnabled() then trace("swing skipped: talent not confirmed"); return end
    local state = self.State
    if not state.CurrentSealName or (state.SealExpiresAt or 0) <= now then
        trace("swing skipped: no active seal")
        return
    end
    local pending, created = matcher():Add(now, state.CurrentSealName, state.SealExpiresAt,
        state.WrathAuraRevision or 0, self.WrathTracker)
    trace("swing #%d queued: player swings=%d, results=%d, seal=%s, stacks=%d",
        pending.id, pending.swingEvents, pending.outcomes, pending.seal, self.WrathTracker.count)
    if not created then
        log(string.format("swing #%d includes a second melee event; checking physical results.", pending.id))
        return pending
    end
    log(string.format("swing #%d queued; %d/3 before swing; seal=%s.", pending.id, self.WrathTracker.count, pending.seal))
    C_Timer.After(MAX_DELAY + BURST_GAP + 0.01, function()
        if not iST.WrathHitMatcher then return end
        for _, candidate in ipairs(iST.WrathHitMatcher.pending) do
            if candidate == pending and pending.outcomes == 0 then
                log(string.format("swing #%d timed out without usable feedback; buff will correct the displayed count when readable.", pending.id))
                break
            end
        end
        iST.WrathHitMatcher:Expire(GetTime())
    end)
    return pending
end

function iST:ObserveWrathFeedbackCast(spellID)
    local hitMatcher = self.WrathHitMatcher
    if not hitMatcher or #hitMatcher.pending == 0 then return end
    -- Seal applications and triggered seal effects are expected around swings.
    -- These spells deal Holy damage, so they cannot be our physical WOUND.
    -- Their avoidance feedback is ambiguous; unknown casts remain guarded.
    local holyCast = false
    if number(spellID) then
        if self.SEALS[spellID] or spellID == 6603 or spellID == 6803 then return end
        holyCast = HOLY_ATTACK_CASTS[spellID] == true
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and not secret(name) and name and self.SEAL_NAME_ALIASES[name] then return end
        if not holyCast and ok and not secret(name) and type(name) == "string" then
            for baseID in pairs(HOLY_ATTACK_CASTS) do
                local baseOK, baseName = pcall(C_Spell.GetSpellName, baseID)
                if baseOK and not secret(baseName) and type(baseName) == "string" and name == baseName then
                    holyCast = true
                    break
                end
            end
        end
    end
    local now = GetTime()
    for _, swing in ipairs(hitMatcher.pending) do
        if now <= swing.at + MAX_DELAY then
            if holyCast then swing.holyCast = true
            else swing.contested = true end
        end
    end
end

function iST:ObserveWrathHitFeedback(unit, action, flags, amount, school)
    -- The damage amount is deliberately unused; it is secret in the captures.
    if secret(unit) or secret(action) or secret(school) or unit ~= "target" or school ~= 1
        or not OUTCOMES[action] or not self.WrathHitMatcher then return false end
    if not iSTSettings.enabled or not self:IsWrathTrackingEnabled() then return false end
    local now, state = GetTime(), self.State
    local pending, outcome = self.WrathHitMatcher:Match(now, action)
    if not pending then
        trace("%s skipped: %s; stacks=%d", action, outcome, self.WrathTracker.count)
        if outcome ~= "no matching swing" then log(outcome .. "; count unchanged.") end
        return false
    end
    if outcome ~= "hit" then
        if state.PendingWrathRelease == pending.release then state.PendingWrathRelease = nil end
        local provisional = pending.provisional
        local tracker = self.WrathTracker
        local canRestore = provisional and pending.swingEvents == 1 and not pending.grouped
            and self.WrathHitMatcher.nextID == pending.id
            and pending.revision == (state.WrathAuraRevision or 0)
            and tracker.count == provisional.count and tracker.seal == provisional.seal
            and tracker.expiresAt == provisional.expiresAt
        if canRestore then
            tracker.count, tracker.seal, tracker.expiresAt = pending.previousCount,
                pending.previousSeal, pending.previousExpiry
            tracker.countUnconfirmed, tracker.expiryUnconfirmed = pending.previousCountUnconfirmed,
                pending.previousExpiryUnconfirmed
            tracker:GetCount(now)
            self:UpdateWrathDisplay(now)
            trace("swing #%d %s: provisional count restored to %d", pending.id, action, tracker.count)
        end
        trace("swing #%d %s: result %d/%d; stacks=%d",
            pending.id, action, pending.outcomes, pending.swingEvents, self.WrathTracker.count)
        log(string.format("swing #%d %s at +%.3fs; %d/3 shown.",
            pending.id, action, now - pending.at, self.WrathTracker:GetCount(now)))
        self:ScheduleWrathAuraCheck()
        return true
    end
    -- The player may cast another seal before this delayed result arrives.
    -- Use the seal and expiry saved at the swing, not the current buff.
    if not pending.seal or (pending.sealExpiresAt or 0) <= pending.at then
        pending.invalid = true
        trace("swing #%d hit skipped: no valid seal at swing", pending.id)
        log(string.format("swing #%d had no valid seal at the swing; count unchanged.", pending.id))
        return false
    end
    -- The swing already updated the display. A changed buff snapshot can
    -- correct it; delayed feedback must not add the same hit a second time.
    local observed, changed
    if not iSTSettings.fakeUnsealedWrath then observed, changed = self:ObserveWrathAura(nil, true) end
    if pending.provisional then
        trace("swing #%d matched target hit: stacks=%d; buff changed=%s",
            pending.id, self.WrathTracker.count, tostring(changed == true))
        self:ScheduleWrathAuraCheck()
        return true
    end
    if changed or pending.revision ~= (state.WrathAuraRevision or 0) then
        log(string.format("swing #%d matched WOUND; readable buff state takes precedence.", pending.id))
        trace("swing #%d hit: buff update took precedence; stacks=%d",
            pending.id, self.WrathTracker.count)
        self:ScheduleWrathAuraCheck()
        return true
    end
    local before = self.WrathTracker:GetCount(now)
    local consumed = self.WrathTracker:Attack(pending.seal, now)
    trace("swing #%d hit %d/%d: stacks %d -> %d; released=%d",
        pending.id, pending.outcomes, pending.swingEvents, before, self.WrathTracker.count, consumed)
    log(string.format("swing #%d physical hit %d at +%.3fs; %d -> %d/3%s.", pending.id, pending.outcomes, now - pending.at,
        before, self.WrathTracker.count, consumed > 0 and "; released stored stacks" or ""))
    self:UpdateWrathDisplay(now)
    self:ScheduleWrathAuraCheck()
    return true
end
