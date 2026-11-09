local _, iST = ...

-- Measured in the 70862 captures: physical feedback followed swings by about
-- 0.43-0.57s, or 0.99s on some Command-proc swings. Match those delayed events;
-- UNIT_COMBAT does not name the attacker.
local MIN_DELAY, MAX_DELAY = 0.30, 1.20
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
    function matcher:Clear(changeTarget)
        self.pending = {}
        if changeTarget then self.targetGeneration = self.targetGeneration + 1 end
    end
    function matcher:Expire(now)
        for index = #self.pending, 1, -1 do
            if now > self.pending[index].at + MAX_DELAY + TIMING_EPSILON then table.remove(self.pending, index) end
        end
    end
    function matcher:Add(now, seal, sealExpiresAt, revision, tracker)
        self:Expire(now)
        self.nextID = self.nextID + 1
        local swing = { id = self.nextID, at = now, seal = seal, sealExpiresAt = sealExpiresAt,
            target = self.targetGeneration, revision = revision,
            previousCount = tracker:GetCount(now), previousSeal = tracker.seal, previousExpiry = tracker.expiresAt }
        if #self.pending >= 8 then table.remove(self.pending, 1) end
        self.pending[#self.pending + 1] = swing
        return swing
    end
    function matcher:Match(now, action)
        self:Expire(now)
        local found, candidates = nil, 0
        for index, swing in ipairs(self.pending) do
            local elapsed = now - swing.at
            if swing.target == self.targetGeneration and elapsed >= MIN_DELAY - TIMING_EPSILON
                and elapsed <= MAX_DELAY + TIMING_EPSILON then
                candidates, found = candidates + 1, index
            end
        end
        if candidates == 0 then return nil, "no matching swing" end
        if candidates > 1 then
            -- Fast or hasted swings can overlap. Do not assign another unit's
            -- feedback to whichever of the two happens to be newest.
            for index = #self.pending, 1, -1 do
                local elapsed = now - self.pending[index].at
                if elapsed >= MIN_DELAY - TIMING_EPSILON and elapsed <= MAX_DELAY + TIMING_EPSILON then
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
        table.remove(self.pending, found)
        if swing.contested then return nil, "another cast overlapped the swing" end
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

function iST:CancelPendingWrathHits(changeTarget)
    if self.WrathHitMatcher then self.WrathHitMatcher:Clear(changeTarget) end
end

function iST:QueueWrathSwing(now)
    if not iSTSettings.enabled or not self:IsWrathTrackingEnabled() then return end
    local state = self.State
    if not state.CurrentSealName or (state.SealExpiresAt or 0) <= now then return end
    local pending = matcher():Add(now, state.CurrentSealName, state.SealExpiresAt,
        state.WrathAuraRevision or 0, self.WrathTracker)
    log(string.format("swing #%d pending; %d/3 unchanged; seal=%s.", pending.id, self.WrathTracker.count, pending.seal))
    C_Timer.After(MAX_DELAY + 0.01, function()
        if not iST.WrathHitMatcher then return end
        for _, candidate in ipairs(iST.WrathHitMatcher.pending) do
            if candidate == pending then
                log(string.format("swing #%d timed out without usable feedback; count unchanged.", pending.id))
                break
            end
        end
        iST.WrathHitMatcher:Expire(GetTime())
    end)
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
        if outcome ~= "no matching swing" then log(outcome .. "; count unchanged.") end
        return false
    end
    if outcome ~= "hit" then
        log(string.format("swing #%d %s at +%.3fs; %d/3 unchanged.",
            pending.id, action, now - pending.at, self.WrathTracker:GetCount(now)))
        self:ScheduleWrathAuraCheck()
        return true
    end
    if state.CurrentSealName ~= pending.seal or (state.SealExpiresAt or 0) <= now then
        log(string.format("swing #%d seal changed or expired before feedback; count unchanged.", pending.id))
        return false
    end
    -- A readable buff snapshot takes precedence over hit tracking. A snapshot
    -- received since the swing must not be followed by another synthetic stack.
    local observed = not iSTSettings.fakeUnsealedWrath and self:ObserveWrathAura(nil, true)
    if observed or pending.revision ~= (state.WrathAuraRevision or 0) then
        if pending.previousCount > 0 and pending.previousSeal ~= pending.seal
            and pending.previousExpiry > now and self.WrathTracker:GetCount(now) == 0 then self:ShowTwistResult() end
        log(string.format("swing #%d matched WOUND; readable buff state takes precedence.", pending.id))
        self:ScheduleWrathAuraCheck()
        return true
    end
    local before = self.WrathTracker:GetCount(now)
    local consumed = self.WrathTracker:Attack(pending.seal, now)
    if consumed > 0 then self:ShowTwistResult() end
    log(string.format("swing #%d WOUND at +%.3fs; %d -> %d/3%s.", pending.id, now - pending.at,
        before, self.WrathTracker.count, consumed > 0 and "; released stored stacks" or ""))
    self:UpdateWrathDisplay(now)
    self:ScheduleWrathAuraCheck()
    return true
end
