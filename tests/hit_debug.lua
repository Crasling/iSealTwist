-- Diagnostic reads must stay isolated from gameplay and never inspect a secret.
local now, frames, messages = 100, {}, {}
local hidden = setmetatable({}, {
    __tostring = function() error("secret converted to string") end,
    __index = function() error("secret indexed") end,
    __len = function() error("secret length read") end,
    __add = function() error("secret arithmetic") end,
})
function issecretvalue(value) return rawequal(value, hidden) end
local function widget(name)
    local methods = {}
    function methods:SetScript(event, callback) self[event] = callback end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:UnregisterAllEvents() self.events = {} end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:SetText(value) assert(type(value) == "string"); self.text = value end
    function methods:SetFocus() self.focused = true end
    function methods:HighlightText() self.selected = true end
    function methods:CreateFontString() return widget() end
    return setmetatable({ name = name, events = {}, shown = false }, { __index = function(_, key)
        return methods[key] or function() end
    end })
end
UIParent, UISpecialFrames, ChatFontNormal = widget(), {}, {}
function CreateFrame(_, name)
    local result = widget(name)
    frames[#frames + 1] = result
    return result
end
function GetTime() return now end
local combat, auraRestricted, auraReads = false, false, 0
function InCombatLockdown() return combat end
function UnitGUID() return "Player-Test" end
function UnitExists() return true end
function UnitIsPlayer() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
C_Secrets = { ShouldAurasBeSecret = function() return auraRestricted end }
C_EventUtils = { IsEventValid = function() return true end }
C_UnitAuras = { GetAuraDataBySpellName = function()
    assert(not auraRestricted, "never query auras while the restriction predicate forbids it")
    auraReads = auraReads + 1
    return { applications = 2, expirationTime = 115, auraInstanceID = hidden }
end }
C_Spell = { GetSpellName = function(id)
    assert(not issecretvalue(id), "never pass a secret spell ID to a name lookup")
    return ({ [6603] = "Melee", [20424] = "Seal of Command", [20375] = "Seal of Command" })[id]
end }
local total, spellID, spellTotal = 100, 6603, 100
local sessionResult, sourceResult, spellResult
local meterCalls = 0
C_DamageMeter = {
    GetCombatSessionFromType = function(session, kind)
        meterCalls = meterCalls + 1
        assert(session == 1 and kind == 0)
        return sessionResult or { combatSources = {
            { isLocalPlayer = false, totalAmount = hidden },
            { isLocalPlayer = true, sourceGUID = hidden, totalAmount = total },
        } }
    end,
    GetCombatSessionSourceFromType = function(session, kind, guid)
        assert(session == 1 and kind == 0 and guid == "Player-Test", "only the cached public player GUID is passed")
        return sourceResult or { combatSpells = spellResult or {
            { spellID = spellID, totalAmount = spellTotal },
        } }
    end,
}
local iST = { Version = "0.8.5", GameVersion = "1.60.1", GameBuild = "70862",
    State = { CurrentSealName = "Seal of Command", WrathAuraInstanceID = 42, NextSwingTime = 103 },
    WrathTracker = { count = 2, countUnconfirmed = true, seal = "Seal of Command", expiresAt = 115 },
    SEALS = { [20375] = "Seal of Command" },
}
function iST:PrintToChat(message) messages[#messages + 1] = message end
iSTSettings = { enabled = true, debugMode = false, fakeUnsealedWrath = false }
assert(loadfile("Localization/enUS.lua"))("iSealTwist", iST)
assert(loadfile("tests/dev/iSealTwist_HitDebug.lua"))("iSealTwist", iST)
local debugFrame, hit = frames[1], iST.HitDebug
assert(not hit:IsActive() and not debugFrame.shown and next(debugFrame.events) == nil and meterCalls == 0,
    "diagnostics start off and do not query or register combat events")
assert(hit:GetReport():find("No hit capture", 1, true))
iST:HandleHitDebugCommand("start")
assert(hit:IsActive() and iSTSettings.hitDebugCapture.duration == 60 and debugFrame.events.UNIT_COMBAT,
    "the explicit command starts a bounded sixty-second capture")
assert(iSTSettings.debugMode == false, "hit capture does not change normal Debug Mode")
local function event(name, ...) debugFrame.OnEvent(debugFrame, name, ...) end
assert(hit:GetReport():find("Group at start: false", 1, true), "group context is preserved outside the capped event ring")
local beforeMeterEvents = iSTSettings.hitDebugCapture.count
for category = 0, 10 do event("DAMAGE_METER_COMBAT_SESSION_UPDATED", category, 42) end
assert(iSTSettings.hitDebugCapture.count == beforeMeterEvents + 1, "unrelated meter categories cannot fill the hit log")
event("PLAYER_SWING", 2.6, 0)
now = now + 0.45
event("UNIT_COMBAT", "target", "DODGE", "", hidden, 1)
event("UNIT_COMBAT", "player", "PARRY", "", hidden, 1)
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-proc", 20424)
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-seal", 20375)
event("UNIT_SPELLCAST_SUCCEEDED", "player", hidden, hidden)
event("UNIT_COMBAT", hidden, hidden, hidden, hidden, hidden)
event("UNIT_SPELLCAST_SUCCEEDED", hidden, hidden, hidden)
event("COMBAT_TEXT_UPDATE", hidden)
event("COMBAT_TEXT_UPDATE", "MISS")
event("PLAYER_TARGET_CHANGED")
iST:HandleHitDebugCommand("mark buff=3, saw dodge")
total, spellTotal = 125, 125
hit:SampleMeter(true)
local report = hit:GetReport()
assert(report:find("unit=target action=DODGE", 1, true) and report:find("sinceSwing=0.450", 1, true),
    "feedback retains defender direction and time since the player's main-hand swing")
assert(report:find("id=20424 name=Seal of Command knownSealCast=false", 1, true), "triggered spell IDs are recorded without treating them as seal casts")
assert(report:find("id=20375 name=Seal of Command knownSealCast=true", 1, true))
assert(report:find("delta=25", 1, true), "readable per-spell damage changes can be measured")
assert(report:find("buff=3, saw dodge", 1, true), "manual observations are timestamped alongside events")
event("DAMAGE_METER_CURRENT_SESSION_UPDATED")
total, spellTotal = 10, 10
hit:SampleMeter(true)
report = hit:GetReport()
assert(not report:find("delta=-115", 1, true), "a new fight cannot produce a negative delta against the previous fight")
total, spellTotal = 5, 5
hit:SampleMeter(true)
assert(hit:GetReport():find("delta=baseline reset", 1, true), "an unexpected meter reset is labelled instead of treated as negative damage")

combat, auraRestricted = true, true
local priorAuraReads = auraReads
event("PLAYER_REGEN_DISABLED")
total, spellID, spellTotal = hidden, hidden, hidden
spellResult = { hidden, { spellID = hidden, totalAmount = hidden }, { spellID = 6603, totalAmount = hidden } }
hit:SampleMeter(true)
event("UNIT_AURA", "player", hidden)
assert(auraReads == priorAuraReads, "restricted aura queries are skipped")
sessionResult, sourceResult = hidden, hidden
hit:SampleMeter(true)
sessionResult, sourceResult = { combatSources = hidden }, { combatSpells = hidden }
hit:SampleMeter(true)
report = hit:GetReport()
assert(report:find("selfTotal=<secret>", 1, true) and report:find("spells=<secret>", 1, true),
    "whole objects, fields, spell IDs, and totals are recorded only as secret placeholders")
assert(iST.WrathTracker.count == 2 and iST.WrathTracker.expiresAt == 115 and iST.State.NextSwingTime == 103,
    "capturing feedback, proc events, auras, and damage cannot change gameplay state")

for index = 1, 1100 do hit:Record("TEST", tostring(index)) end
local saved = iSTSettings.hitDebugCapture
assert(saved.count == 1000 and saved.dropped > 0 and hit:GetReport():find("TEST 1100", 1, true),
    "the report is a bounded chronological ring containing the latest observations")
local function publicOnly(value)
    assert(not issecretvalue(value), "a secret must never enter SavedVariables")
    if type(value) == "table" then
        for key, item in pairs(value) do publicOnly(key); publicOnly(item) end
    end
end
publicOnly(saved)
now = 161
debugFrame.OnUpdate(debugFrame, 0.3)
assert(not hit:IsActive() and not debugFrame.shown and next(debugFrame.events) == nil,
    "the time limit stops queries and unregisters every diagnostic event")
local stoppedCount, stoppedCalls = saved.count, meterCalls
event("PLAYER_SWING", 2.6, 0)
debugFrame.OnUpdate(debugFrame, 1)
assert(saved.count == stoppedCount and meterCalls == stoppedCalls, "stopped diagnostics do no further work")

hit:ShowReport()
assert(hit.window.shown and hit.window.edit.selected and hit.window.edit.focused,
    "the copy window selects its text for Ctrl+C")
assert(hit.window.edit.text:find("TEST 1100", 1, true) and UISpecialFrames[1] == "iSTHitDebugReport")
hit.window.edit.OnEscapePressed()
assert(not hit.window.shown, "Escape closes the report")

saved.status = "recording"
assert(loadfile("tests/dev/iSealTwist_HitDebug.lua"))("iSealTwist", iST)
hit = iST.HitDebug
assert(not hit:IsActive() and hit:GetReport():find("interrupted by reload", 1, true),
    "the saved report survives reload without restarting the capture")
iST:HandleHitDebugCommand("clear")
assert(iSTSettings.hitDebugCapture == nil)
iST:HandleHitDebugCommand("start 999")
assert(iSTSettings.hitDebugCapture.duration == 180)
iST:HandleHitDebugCommand("stop")
iST:HandleHitDebugCommand("start 1")
assert(iSTSettings.hitDebugCapture.duration == 10)
local newestFrame = frames[#frames]
newestFrame.OnEvent(newestFrame, "PLAYER_LOGOUT")
assert(not hit:IsActive() and iSTSettings.hitDebugCapture.status == "logout", "logout closes the capture before saving")
local sourceCalls = 0
UnitGUID = function() return hidden end
C_DamageMeter.GetCombatSessionSourceFromType = function() sourceCalls = sourceCalls + 1; error("no public GUID was available") end
sessionResult, sourceResult, spellResult = nil, nil, nil
iST:HandleHitDebugCommand("start 10")
assert(sourceCalls == 0 and hit:GetReport():find("skipped: no public player GUID", 1, true),
    "starting in combat cannot pass a secret GUID to a damage-meter query")
iST:HandleHitDebugCommand("stop")
print("PASS: opt-in hit capture, timestamps, defender feedback, proc IDs, readable damage deltas, secret guards, no gameplay changes, bounded storage, auto-stop, reload persistence, and copy UI")
