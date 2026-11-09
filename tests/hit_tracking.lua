-- Replay the captured outcomes against the production matcher and stack tracker.
local unpack = unpack or table.unpack
local now, timers, messages = 100, {}, {}
local secret = setmetatable({}, {
    __tostring = function() error("secret converted to text") end,
    __lt = function() error("secret compared") end,
    __eq = function() error("secret compared") end,
})
function issecretvalue(value) return rawequal(value, secret) end
function GetTime() return now end
C_Timer = { After = function(delay, run) timers[#timers + 1] = { at = now + delay, run = run } end }
C_Spell = { GetSpellName = function(id)
    if id == 20424 then return "Seal of Command" end
    if id == 1866 or id == 9991866 then return "Holy Strike" end
    if id == 20271 or id == 99920271 then return "Judgement" end
    return "Unknown physical ability"
end }
iSTSettings = { enabled = true, fakeUnsealedWrath = true }
local iST = {
    State = {}, SEALS = { [20375] = "Seal of Command", [20154] = "Seal of Righteousness" },
    SEAL_NAME_ALIASES = { ["Seal of Command"] = true, ["Seal of Righteousness"] = true },
}
function iST:IsWrathTrackingEnabled() return iSTSettings.fakeUnsealedWrath or self.talent end
function iST:DebugMsg(text) messages[#messages + 1] = text end
function iST:UpdateWrathDisplay() self.displayCount = self.WrathTracker:GetCount(now) end
function iST:ScheduleWrathAuraCheck() self.checks = (self.checks or 0) + 1 end
function iST:ObserveWrathAura()
    if not self.observed then return end
    self.State.WrathAuraRevision = self.State.WrathAuraRevision + 1
    self.WrathTracker:Observe(self.observed, now + 15, self.State.CurrentSealName, now)
    return true
end
function iST:ShowTwistResult() self.releases = self.releases + 1 end
assert(loadfile("iSealTwist_Stacks.lua"))("iSealTwist", iST)
assert(loadfile("iSealTwist_HitTracking.lua"))("iSealTwist", iST)
local function reset()
    now = now + 100
    timers = {}
    iSTSettings.enabled, iSTSettings.fakeUnsealedWrath = true, true
    iST.State = { CurrentSealName = "Seal of Command", SealExpiresAt = now + 300, WrathAuraRevision = 0 }
    iST.WrathTracker, iST.WrathHitMatcher = iST:NewWrathTracker(), nil
    iST.talent, iST.observed, iST.releases, iST.displayCount = false, nil, 0, 0
end
local function count() return iST.WrathTracker:GetCount(now) end
local function swing() iST:QueueWrathSwing(now) end
local function feedback(delay, action, flags)
    now = now + delay
    return iST:ObserveWrathHitFeedback("target", action or "WOUND", flags or "", secret, 1)
end

reset()
-- Command swings 21-24 in the 90-second capture: hit, dodge, hit, hit.
for index, sample in ipairs({ { .558, "WOUND", 1 }, { .562, "DODGE", 1 },
    { .991, "WOUND", 2 }, { .496, "WOUND", 3 } }) do
    now = now + 3 - sample[1]
    local before, expiry = count(), iST.WrathTracker.expiresAt
    swing()
    assert(count() == before and iST.WrathTracker.expiresAt == expiry,
        "a swing alone neither adds a stack nor refreshes the deadline")
    if index == 3 then
        iST:ObserveWrathFeedbackCast(20424)
        assert(not iST:ObserveWrathHitFeedback("target", "WOUND", "", secret, 2),
            "the Command Holy proc is not the melee hit")
    end
    assert(feedback(sample[1], sample[2], "BLOCK_REDUCED"))
    assert(count() == sample[3], "the capture replay must progress 1, 1, 2, 3")
end
assert(iST.displayCount == 3 and #messages > 0, "matched hits update the cue and normal debug messages")
print("PASS: captured Command replay yields 1, 1, 2, 3; secret damage is unused")

for _, action in ipairs({ "MISS", "DODGE", "PARRY" }) do
    reset()
    swing(); feedback(.5)
    local expiry = iST.WrathTracker.expiresAt
    now = now + 2
    iST.State.CurrentSealName = "Seal of Righteousness"
    swing(); feedback(.5, action)
    assert(count() == 1 and iST.WrathTracker.expiresAt == expiry and iST.releases == 0,
        action .. " must not add, refresh, or release the stored Command stack")
    now = now + 2
    swing(); feedback(.5)
    assert(count() == 0 and iST.releases == 1, "only the landed replacement attack releases")
end
for _, flags in ipairs({ "", "CRITICAL", "GLANCING", "BLOCK_REDUCED" }) do
    reset()
    swing(); feedback(.5, "WOUND", flags)
    assert(count() == 1, "all physical WOUND outcomes count regardless of damage flags")
    assert(not feedback(.16) and count() == 1, "later unrelated feedback cannot count the same swing twice")
end
print("PASS: avoided replacement attacks preserve stacks; landed, glancing, critical, and partially blocked attacks count")

for _, separateEvents in ipairs({ false, true }) do
    reset()
    swing()
    if separateEvents then now = now + .02; swing() end
    assert(#iST.WrathHitMatcher.pending == 1 and #timers == 1,
        "closely spaced native events use one burst and one cleanup timer")
    assert(feedback(.5) and count() == 1)
    assert(feedback(.02) and count() == 2, "two close physical hits award two stacks")
    assert(not feedback(.01) and count() == 2, "the burst cannot count a third hit")
    now = now + 3
    swing(); assert(feedback(.5) and count() == 3, "ordinary swings still work after the burst")
end
reset()
swing()
assert(feedback(.5) and count() == 1)
local firstHitExpiry = iST.WrathTracker.expiresAt
assert(not iST:ObserveWrathHitFeedback("target", "WOUND", "", secret, 2))
assert(not iST:ObserveWrathHitFeedback("target", "WOUND", "", secret, 32))
assert(count() == 1 and iST.WrathTracker.expiresAt == firstHitExpiry,
    "Holy and Shadow procs cannot supply the extra physical hit")
assert(feedback(.02, "DODGE") and count() == 1 and iST.WrathTracker.expiresAt == firstHitExpiry,
    "an avoided extra attack neither adds a stack nor refreshes its deadline")
for _, action in ipairs({ "MISS", "DODGE", "PARRY" }) do
    reset()
    swing(); now = now + .02; swing()
    assert(feedback(.5, action) and count() == 0)
    assert(feedback(.02) and count() == 1, "two explicit swings can contain one avoided and one landed attack")
end
reset()
swing(); feedback(.5)
iST:CancelPendingWrathHits(true)
assert(not feedback(.02) and count() == 1, "target changes cancel the extra-hit window")
reset()
swing(); feedback(.5)
iST:ObserveWrathFeedbackCast(123456)
assert(not feedback(.02) and count() == 1, "unknown casts still invalidate the extra-hit window")
reset()
iST.WrathTracker:Attack("Seal of Command", now)
iST.State.CurrentSealName = "Seal of Righteousness"
swing()
assert(feedback(.5) and count() == 0 and iST.releases == 1)
assert(feedback(.02) and count() == 1 and iST.releases == 1,
    "a landed extra attack can build the replacement seal after the first hit releases stacks")
reset()
iSTSettings.fakeUnsealedWrath, iST.talent = false, true
iST.WrathTracker:Attack("Seal of Command", now)
iST.State.CurrentSealName = "Seal of Righteousness"
swing()
iST.WrathTracker:Reset()
iST.State.WrathAuraRevision = 1
assert(feedback(.5) and count() == 0 and iST.releases == 1)
assert(feedback(.02) and count() == 0 and iST.releases == 1,
    "a readable aura removal wins across the burst and shows release only once")
reset()
swing()
assert(feedback(1.19) and feedback(.1) and count() == 2,
    "a late first hit still gets its bounded extra-hit window")
reset()
swing(); feedback(.5)
now = now + 2
for _, timer in ipairs(timers) do timer.run() end
assert(#iST.WrathHitMatcher.pending == 0, "cleanup removes an unused extra-hit opportunity")
print("PASS: one/two swing events with two physical hits, avoided extras, burst limit, proc filtering, cancellation, release, aura precedence, and cleanup")

reset()
swing()
assert(not feedback(0, "DODGE"), "zero-delay proc-adjacent feedback cannot consume the pending swing")
assert(feedback(.991) and count() == 1, "the later physical hit still matches")
reset()
swing()
now = now + .5
for _, sample in ipairs({
    { "player", "WOUND", "", secret, 1 }, { "focus", "WOUND", "", secret, 1 },
    { "target", "WOUND", "", secret, 2 }, { "target", "WOUND", "", secret, 32 },
    { "target", "RESIST", "", secret, 1 }, { secret, "WOUND", "", secret, 1 },
    { "target", secret, "", secret, 1 }, { "target", "WOUND", "", secret, secret },
}) do
    assert(not iST:ObserveWrathHitFeedback(unpack(sample)), "unusable metadata cannot affect the counter")
end
assert(count() == 0 and feedback(0), "discarded feedback leaves the real candidate pending")
reset()
swing()
assert(not feedback(1.21) and count() == 0, "late feedback cannot invent a stack")
for _, timer in ipairs(timers) do timer.run() end
assert(#iST.WrathHitMatcher.pending == 0, "timeouts remove pending candidates")
reset()
swing(); iST:CancelPendingWrathHits(true)
assert(not feedback(.5) and count() == 0, "switching targets invalidates the previous swing")
reset()
swing(); iST.State.CurrentSealName = "Seal of Righteousness"
assert(not feedback(.5) and count() == 0, "a seal change during dispatch is ambiguous")
reset()
swing(); iST.State.SealExpiresAt = now + .1
assert(not feedback(.5) and count() == 0, "an expired seal cannot gain a stack")
print("PASS: target changes, proc timing, secret metadata, unrelated schools, expiry, and timeouts")

reset()
swing(); now = now + .4; swing()
assert(not feedback(.4) and count() == 0 and #iST.WrathHitMatcher.pending == 0,
    "overlapping swing windows are discarded instead of guessing which attack landed")
for _, spellID in ipairs({ 123456, secret }) do
    reset()
    swing(); now = now + .2
    iST:ObserveWrathFeedbackCast(spellID)
    assert(not feedback(.3) and count() == 0, "other casts can produce ambiguous physical outcomes")
end
for _, spellID in ipairs({ 20375, 20424, 6603, 6803 }) do
    reset()
    swing(); iST:ObserveWrathFeedbackCast(spellID)
    assert(feedback(.5) and count() == 1, "known seal effects and autoattacks do not cancel the match")
end
print("PASS: ambiguous swing windows and unrelated casts are skipped; known seal procs remain usable")

-- Replay the Holy Strike overlap: Holy damage at +0.185, melee at +0.992.
for _, spellID in ipairs({ 1866, 9991866 }) do
    reset()
    swing(); now = now + .185
    iST:ObserveWrathFeedbackCast(spellID)
    assert(not iST:ObserveWrathHitFeedback("target", "WOUND", "", secret, 2) and count() == 0,
        "Holy Strike's Holy hit is ignored without cancelling the autoattack")
    assert(feedback(.807) and count() == 1, "the later physical autoattack still adds its stack")
end
for _, action in ipairs({ "MISS", "DODGE", "PARRY" }) do
    reset()
    swing(); now = now + .458
    iST:ObserveWrathFeedbackCast(1866)
    assert(not feedback(0, action) and count() == 0 and #iST.WrathHitMatcher.pending == 1,
        "Holy Strike avoidance cannot consume the pending autoattack")
    assert(feedback(.5) and count() == 1, "the later physical hit remains eligible")
    reset()
    swing(); now = now + .458
    iST:ObserveWrathFeedbackCast(1866)
    assert(not feedback(0, action))
    assert(not feedback(1, "WOUND") and count() == 0,
        "ambiguous avoidance followed by a timeout never invents a stack")
end
reset()
iST.WrathTracker:Attack("Seal of Command", now)
iST.State.CurrentSealName = "Seal of Righteousness"
swing(); now = now + .4
iST:ObserveWrathFeedbackCast(1866)
assert(not feedback(0, "PARRY") and count() == 1 and iST.releases == 0,
    "a Holy Strike parry must not release the stored seal")
assert(feedback(.5) and count() == 0 and iST.releases == 1,
    "a subsequent landed replacement autoattack releases once")
reset()
swing()
iST:ObserveWrathFeedbackCast(secret)
iST:ObserveWrathFeedbackCast(1866)
assert(not feedback(.5) and count() == 0, "Holy Strike cannot override an unknown-cast safeguard")
local spellNameReader = C_Spell.GetSpellName
C_Spell.GetSpellName = function() return secret end
reset()
swing(); iST:ObserveWrathFeedbackCast(123456)
assert(not feedback(.5) and count() == 0, "secret spell names are not compared to identify Holy Strike")
C_Spell.GetSpellName = spellNameReader
print("PASS: Holy Strike overlap, localized rank identity, avoided Holy casts, timeout, release timing, and secret-name guards")

for _, spellID in ipairs({ 20271, 99920271 }) do
    reset()
    iST.WrathTracker:Attack("Seal of Command", now)
    iST.State.CurrentSealName = "Seal of Righteousness"
    swing(); now = now + .2
    iST:ObserveWrathFeedbackCast(spellID)
    assert(not iST:ObserveWrathHitFeedback("target", "WOUND", "", secret, 2)
        and count() == 1 and iST.releases == 0,
        "Judgement's Holy damage neither adds nor releases melee stacks")
    assert(feedback(.3) and count() == 0 and iST.releases == 1,
        "Judgement must not cancel the subsequent landed replacement autoattack")
end
print("PASS: Judgement overlap preserves the pending autoattack and melee-only release")

reset()
iSTSettings.enabled = false; swing()
assert(not iST.WrathHitMatcher, "disabled addon does not start matching")
iSTSettings.enabled, iSTSettings.fakeUnsealedWrath = true, false
swing()
assert(not iST.WrathHitMatcher, "a missing talent does not start matching")
iST.talent = true
swing(); assert(feedback(.5) and count() == 1, "the real talent uses the same feedback path as Fake")
reset()
iSTSettings.fakeUnsealedWrath, iST.talent = false, true
swing(); iST.observed = 1
assert(feedback(.5) and count() == 1 and not iST.WrathTracker.countUnconfirmed,
    "a readable buff at feedback time wins without double-counting")
reset()
iSTSettings.fakeUnsealedWrath, iST.talent = false, true
swing()
iST.WrathTracker:Observe(1, now + 15, iST.State.CurrentSealName, now)
iST.State.WrathAuraRevision = 1
assert(feedback(.5) and count() == 1 and not iST.WrathTracker.countUnconfirmed,
    "a buff update between attempt and feedback must not gain a second synthetic stack")
reset()
iSTSettings.fakeUnsealedWrath, iST.talent = false, true
iST.WrathTracker:Attack("Seal of Command", now)
iST.State.CurrentSealName = "Seal of Righteousness"
swing()
iST.WrathTracker:Reset()
iST.State.WrathAuraRevision = 1
assert(feedback(.5) and count() == 0 and iST.releases == 1,
    "a readable removal on release must not start a replacement-seal stack")
print("PASS: talent gating, shared Fake path, authoritative buff updates, and release deduplication")
