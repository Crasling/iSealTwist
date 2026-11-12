-- Run from the addon directory. These checks use no game or network access.
unpack = unpack or table.unpack
local now, timers, frames, chatMessages = 100, {}, {}, {}
local playerClass, playerDead, inCombat, grouped = "PALADIN", false, false, false
local inInstance, instanceType = false, "none"
local function widget(parent)
    local object = { parent = parent, widgetWidth = 250, widgetHeight = 25, shown = false, alpha = 1,
        Text = false, ScrollBar = false, ScrollUpButton = false, ScrollDownButton = false }
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = object
    end
    local methods = {}
    function methods:SetSize(w, h) self.widgetWidth, self.widgetHeight = w, h end
    function methods:SetWidth(w) self.widgetWidth = w end
    function methods:SetHeight(h) self.widgetHeight = h end
    function methods:GetWidth() return self.widgetWidth end
    function methods:GetHeight() return self.widgetHeight end
    function methods:GetLeft() return self.left or 0 end
    function methods:Show()
        if self.shown then return end
        self.shown = true
        if self.OnShow then self.OnShow(self) end
    end
    function methods:Hide()
        if not self.shown then return end
        self.shown = false
        if self.OnHide then self.OnHide(self) end
    end
    function methods:IsShown() return self.shown end
    function methods:IsVisible()
        return self.shown and (not self.parent or self.parent:IsVisible())
    end
    function methods:SetShown(value) if value then self:Show() else self:Hide() end end
    function methods:GetParent() return self.parent end
    function methods:GetChildren() return table.unpack(self.frameChildren or {}) end
    function methods:IsObjectType(kind) return self.objectType == kind end
    function methods:SetScrollChild(value) self.scrollChild = value end
    function methods:SetVerticalScroll(value) self.verticalScroll = value end
    function methods:GetVerticalScroll() return self.verticalScroll or 0 end
    function methods:Disable() self.enabled = false; if self.OnDisable then self.OnDisable(self) end end
    function methods:Enable() self.enabled = true; if self.OnEnable then self.OnEnable(self) end end
    function methods:IsEnabled() return self.enabled ~= false end
    function methods:SetAlpha(value) self.alpha = value end
    function methods:SetText(value) self.text = value end
    function methods:SetTextColor(...) self.textColor = { ... } end
    function methods:SetTexture(value) self.texture = value end
    function methods:SetTexCoord(...) self.texCoord = { ... } end
    function methods:SetDesaturated(value) self.desaturated = value end
    function methods:GetText() return self.text or "" end
    function methods:GetName() return self.name end
    function methods:GetStringHeight() return math.max(12, math.ceil(#(self.text or "") / 60) * 12) end
    function methods:GetStringWidth() return #(self.text or "") * (self.font and self.font[2] or 12) * 0.5 end
    function methods:GetFontString() return self.fontString end
    function methods:SetFontString(value) self.fontString = value end
    function methods:GetChecked() return self.checked end
    function methods:SetChecked(value) self.checked = value end
    function methods:HookScript(event, callback)
        local previous = self[event]
        self[event] = function(...) if previous then previous(...) end; callback(...) end
    end
    function methods:SetColorTexture(...) self.color = { ... } end
    function methods:SetVertexColor(...) self.color = { ... } end
    function methods:SetBackdrop(value) self.backdrop = value end
    function methods:SetBackdropColor(...) self.backdropColor = { ... } end
    function methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
    function methods:SetPoint(...) self.point = { ... } end
    function methods:GetPoint() return table.unpack(self.point or { "CENTER", nil, "CENTER", 0, 0 }) end
    function methods:GetFrameLevel() return self.frameLevel or 1 end
    function methods:SetFrameLevel(value) self.frameLevel = value end
    function methods:SetAllPoints(target) self.allPointsTarget = target end
    function methods:SetCooldown(start, duration)
        self.cooldownStart, self.cooldownDuration = start, duration
        self.cooldownSets = (self.cooldownSets or 0) + 1
    end
    function methods:Clear() self.cooldownStart, self.cooldownDuration = nil, nil end
    function methods:SetSwipeTexture(value) self.swipeTexture = value end
    function methods:SetSwipeColor(...) self.swipeColor = { ... } end
    function methods:SetReverse(value) self.reverse = value end
    function methods:SetDrawSwipe(value) self.drawSwipe = value end
    function methods:SetDrawEdge(value) self.drawEdge = value end
    function methods:SetDrawBling(value) self.drawBling = value end
    function methods:SetHideCountdownNumbers(value) self.hideCountdownNumbers = value end
    function methods:GetEffectiveScale() return 1 end
    function methods:GetScale() return self.scale or 1 end
    function methods:SetScale(value) self.scale = value end
    function methods:SetFrameStrata(value) self.strata = value end
    function methods:EnableMouse(value) self.mouseEnabled = value end
    function methods:StartMoving() self.moving = true end
    function methods:StopMovingOrSizing() self.moving = false end
    function methods:SetScript(event, callback) self[event] = callback end
    function methods:RegisterEvent(event)
        self.registeredEvents = self.registeredEvents or {}
        self.registeredEvents[event] = true
    end
    function methods:CreateFontString() return widget(self) end
    function methods:CreateTexture() return widget(self) end
    function methods:CreateMaskTexture() return widget(self) end
    function methods:AddMaskTexture(mask)
        self.masks = self.masks or {}
        self.masks[#self.masks + 1] = mask
    end
    function methods:CreateLine() return widget(self) end
    for _, kind in ipairs({ "Normal", "Pushed", "Highlight", "Checked", "Thumb" }) do
        local textureKind = kind
        methods["Set" .. textureKind .. "Texture"] = function(self, path)
            self[textureKind .. "Texture"] = widget(self)
            self[textureKind .. "Texture"]:SetTexture(path)
        end
        methods["Get" .. textureKind .. "Texture"] = function(self) return self[textureKind .. "Texture"] end
    end
    function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "OUTLINE" end
    function methods:SetFont(path, size, flags) self.font = { path, size, flags } end
    return setmetatable(object, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^[A-Z]") then return function() end end
    end })
end

UIParent = widget()
UIParent:Show()
PlayerFrame = widget(UIParent)
PlayerFrame:Show()
PlayerFrame.PlayerFrameContent = false
PlayerFrame.manabar = widget(PlayerFrame)
PlayerFrame.manabar:Show()
function PlayerFrame_GetManaBar() return PlayerFrame and PlayerFrame.manabar end
ChatFrame1 = { AddMessage = function(_, message) chatMessages[#chatMessages + 1] = message end }
function CreateFrame(kind, name, parent, template)
    local frame = widget(parent)
    frame.objectType = kind
    if parent then
        parent.frameChildren = parent.frameChildren or {}
        parent.frameChildren[#parent.frameChildren + 1] = frame
    end
    frame.name = name
    if template == "UIPanelScrollFrameTemplate" then
        frame.ScrollBar = widget(frame)
        frame.ScrollBar.objectType = "Slider"
        frame.ScrollBar.frameChildren = { CreateFrame("Button", nil, frame.ScrollBar),
            CreateFrame("Button", nil, frame.ScrollBar) }
        frame.ScrollBar.frameChildren[1]:Show()
        frame.ScrollBar.frameChildren[2]:Show()
    end
    frames[#frames + 1] = frame
    return frame
end
function GetTime() return now end
function GetBuildInfo() return "1.60.1", "70753", "", 16001 end
function UnitClass() return "Paladin", playerClass end
function UnitIsDeadOrGhost() return playerDead end
function UnitHealth() return playerDead and 0 or 100 end
function UnitPowerType() return 0, "MANA" end
function UnitAttackSpeed() return 3.6 end
function InCombatLockdown() return inCombat end
function UnitAffectingCombat() return inCombat end
function IsInGroup() return grouped end
function IsInInstance() return inInstance, instanceType end
function LibStub() return nil end
function tostringall(...) return ... end
local secret = {}
function issecretvalue(value) return rawequal(value, secret) end
C_AddOns = { GetAddOnMetadata = function() return "0.8.1" end }
C_EventUtils = { IsEventValid = function() return true end }
C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { at = now + delay, run = callback }
end }
Enum = { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
local talentName, talentRank, configAvailable = "Unsealed Wrath", 1, true
C_ClassTalents = { GetActiveConfigID = function() return configAvailable and 1 or nil end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeNodes = function() return { 1 } end,
    GetNodeInfo = function() return { activeRank = talentRank, activeEntry = { entryID = 1 } } end,
    GetEntryInfo = function() return { definitionID = 1 } end,
    GetDefinitionInfo = function() return { spellID = 999999 } end,
}
C_Spell = {
    GetSpellName = function(id)
        if id == 999999 then return talentName end
        return ({ [1311703] = "Echo of Command", [1311701] = "Echo of Fury",
            [1311705] = "Echo of Justice", [1328198] = "Echo of Light",
            [1311704] = "Echo of Righteousness", [1328206] = "Echo of Wisdom" })[id]
    end,
    GetSpellTexture = function() return 1 end,
}
local auraResult
C_UnitAuras = { GetAuraDataBySpellName = function(unit, spellName, filter)
    assert(unit == "player" and filter == "HELPFUL",
        "aura lookup uses the documented unit, spellName, filter argument order")
    if spellName ~= "Echo of Command" then return nil end
    if type(auraResult) == "table" and not issecretvalue(auraResult) then
        auraResult.name = auraResult.name or "Echo of Command"
        auraResult.spellId = auraResult.spellId or 1311703
    end
    return auraResult
end }

local iST = {}
for _, file in ipairs({ "Localization/enUS.lua", "iSealTwist_Stacks.lua",
    "iSealTwist_Main.lua", "iSealTwist_HitTracking.lua", "iSealTwist_HitDebug.lua", "iSealTwist_Bubbles.lua", "iSealTwist_SwordImages.lua", "iSealTwist_Cues.lua", "iSealTwist_Reminders.lua" }) do
    assert(loadfile(file))("iSealTwist", iST)
end
local events = frames[1]
iST:InitializeSettings()
assert(iSTSettings.fakeUnsealedWrath == false and iSTSettings.debugMode == false,
    "fake talent and debug diagnostics start disabled")
assert(iSTSettings.wrathCue == "COUNTER", "new characters default to the buff stack counter")
iSTSettings.wrathCue, iSTSettings.stackCounterDefaultMigrated = "BAR_COLOR", nil
iST:InitializeSettings()
assert(iSTSettings.wrathCue == "COUNTER", "the previous default moves to the buff counter once")
iSTSettings.wrathCue = "BAR_COLOR"
iST:InitializeSettings()
assert(iSTSettings.wrathCue == "BAR_COLOR", "a later bar-color choice remains saved")
iSTSettings.wrathCue = "COUNTER"
iST:CreateSwingBar()
assert(iST.BarFrame.stackCountValue.font[2] == iSTSettings.stackCounterTextSize,
    "the buff counter uses its own text size")
iST:RefreshUnsealedWrathState()
local function event(name, ...) events.OnEvent(events, name, ...) end
local function attack()
    now = now + 1
    event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.MainHand)
    now = now + 0.5
    event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
end
local function count() return iST.WrathTracker:GetCount(now) end
local function runDue()
    local queued = timers
    timers = {}
    for _, timer in ipairs(queued) do
        if timer.at <= now then timer.run() else timers[#timers + 1] = timer end
    end
end

assert(iST:HasUnsealedWrath(), "selected replacement talent enables tracking")
iST:SetCurrentSeal(20154)
for expected = 1, 3 do attack(); assert(count() == expected, "three swings build three stacks") end
attack(); assert(count() == 3, "stacks cap at three")
local expiresAt = iST.WrathTracker.expiresAt
assert(expiresAt == now + 14.5, "another buildup swing refreshes the fifteen-second window")
iST:SetCurrentSeal(20375)
assert(count() == 3, "casting a different seal alone preserves stacks")
iST:SetCurrentSeal(20154)
assert(count() == 3, "switching back before the attack preserves stacks")
iST:SetCurrentSeal(20375)
attack()
assert(count() == 0, "the next attack with another seal consumes stored stacks")
attack(); assert(count() == 1, "subsequent attacks build the replacement seal")
iST:SetCurrentSeal(20154)
attack(); assert(count() == 0, "switching early consumes partial stacks too")

attack()
local before = count()
event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.OffHand)
event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.Ranged)
iST:ResetSwingTimer(3.6, false)
assert(count() == before, "off-hand, ranged, and cast-based timer resets never add stacks")
event("PLAYER_REGEN_ENABLED")
assert(count() == before, "leaving combat does not erase a valid stored seal")
now = iST.WrathTracker.expiresAt
assert(count() == 0, "expiry works even while the bar is hidden")

iST:SetCurrentSeal(20154)
attack()
auraResult = { applications = 3, expirationTime = now + 8, auraInstanceID = 99 }
event("UNIT_AURA", "player", {})
assert(count() == 3 and iST.WrathTracker.expiresAt == now + 8,
    "public buff stacks and expiry correct the counter")
assert(not iST.WrathTracker.countUnconfirmed, "readable buff state is identified as authoritative")

inCombat = true
assert(iST.WrathTracker:Observe(2, now + 8, iST.State.CurrentSealName, now))
auraResult = { applications = 3, expirationTime = secret, auraInstanceID = secret }
event("UNIT_AURA", "player", {})
assert(count() == 3, "readable combat stacks must correct 2 to 3 even when expiry and instance ID are secret")
inCombat = false
auraResult = { applications = 3, expirationTime = now + 8, auraInstanceID = 99 }
event("UNIT_AURA", "player", {})
event("UNIT_AURA", secret, secret)
assert(count() == 3, "secret event tokens are ignored")
for _, hidden in ipairs({ secret, { applications = secret, expirationTime = now + 5 } }) do
    auraResult = hidden
    event("UNIT_AURA", "player", {})
    assert(count() == 3, "a secret stack count never changes the counter")
end
local preservedExpiry = iST.WrathTracker.expiresAt
auraResult = { applications = 2, expirationTime = secret, auraInstanceID = secret }
event("UNIT_AURA", "player", {})
assert(count() == 2 and iST.WrathTracker.expiresAt == preservedExpiry,
    "readable lower counts are authoritative too; hidden expiry does not restart the timer")
auraResult = { applications = 3, expirationTime = now + 8, auraInstanceID = 99 }
event("UNIT_AURA", "player", {})
auraResult = nil
event("UNIT_AURA", "player", {})
assert(count() == 3, "an unavailable buff lookup is not treated as confirmed zero")
event("UNIT_AURA", "player", { removedAuraInstanceIDs = { 99 } })
assert(count() == 0, "a public removal of the observed buff clears stacks")

inCombat = true
local currentWrathAura
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
    assert(unit == "player" and not issecretvalue(id), "aura instance checks use public player IDs")
    if id == 200 then return currentWrathAura end
    return { name = "Holy Shield", spellId = 20925, applications = 3, expirationTime = now + 10, auraInstanceID = id }
end
event("UNIT_AURA", "player", { addedAuras = {
    { name = "Echo of Command", spellId = 1311703, applications = secret, expirationTime = secret, auraInstanceID = 200 },
} })
assert(iST.State.WrathAuraInstanceID == 200 and count() == 0,
    "public identity can be learned before the combat stack count becomes readable")
assert(iST.WrathTracker:Observe(2, now + 7, iST.State.CurrentSealName, now))
currentWrathAura = { name = secret, spellId = secret, applications = 3, expirationTime = secret, auraInstanceID = 200 }
event("UNIT_AURA", "player", { updatedAuraInstanceIDs = { secret, 200 } })
assert(count() == 3 and iST.WrathTracker.expiryUnconfirmed and not iST.WrathTracker.countUnconfirmed,
    "a targeted instance update confirms three stacks without requiring a readable clock or name")
assert(iST.BarFrame.fill.color[1] == iST:GetWrathCueColor(3).r,
    "a confirmed combat count repaints the cue immediately")
inCombat = false
currentWrathAura = { name = "Echo of Command", spellId = 1311703, applications = 3,
    expirationTime = now + 7, auraInstanceID = 200 }
event("PLAYER_REGEN_ENABLED")
assert(count() == 3 and iST.WrathTracker.expiresAt == now + 7
    and not iST.WrathTracker.expiryUnconfirmed,
    "the readable buff expiry replaces a provisional timer after combat")
inCombat = true
local confirmedCountExpiry = iST.WrathTracker.expiresAt
auraResult = { applications = 2, expirationTime = now + 8, auraInstanceID = 200 }
iST:ScheduleWrathAuraCheck()
now = now + 0.35
runDue()
assert(count() == 3 and iST.WrathTracker.expiresAt == confirmedCountExpiry,
    "follow-up checks prefer the known instance over an older name lookup and do not keep extending hidden expiry")
currentWrathAura, auraResult = secret, nil
event("UNIT_AURA", "player", {})
local queuedChecks = #timers
for _ = 1, 25 do event("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 201 } }) end
assert(#timers == queuedChecks and count() == 3, "unrelated buffs and repeated hidden updates cannot grow the pending check queue")
event("UNIT_AURA", "player", { removedAuraInstanceIDs = { 200 }, addedAuras = {
    { name = "Echo of Command", spellId = 1311703, applications = 3, expirationTime = now + 10, auraInstanceID = 202 },
} })
assert(count() == 3 and iST.State.WrathAuraInstanceID == 202, "a replacement aura is processed before removal of the old instance")
C_UnitAuras.GetAuraDataByAuraInstanceID = nil
event("UNIT_AURA", "player", { removedAuraInstanceIDs = { 202 } })
assert(count() == 0, "a genuine removal still clears confirmed combat stacks")
event("UNIT_AURA", "player", { addedAuras = {
    { name = "Unsealed Wrath", spellId = 1310735, applications = 3,
        expirationTime = now + 10, auraInstanceID = 299 },
} })
assert(count() == 0 and iST.State.WrathAuraInstanceID == nil,
    "the passive talent is not mistaken for an Echo stack buff")
for index, spell in ipairs(iST.WrathEchoSpells) do
    local instanceID = 300 + index
    event("UNIT_AURA", "player", { addedAuras = {
        { name = spell.name, spellId = spell.id, applications = 2,
            expirationTime = now + 10, auraInstanceID = instanceID },
    } })
    assert(count() == 2 and iST.State.WrathAuraInstanceID == instanceID
        and iST.WrathTracker.seal == spell.seal,
        spell.name .. " confirms its own stack count")
    event("UNIT_AURA", "player", { removedAuraInstanceIDs = { instanceID } })
    assert(count() == 0, spell.name .. " removal clears its stacks")
end

-- The aura API may return the previous stack count until after melee feedback.
-- Re-reading that unchanged snapshot must not hide the hit or the release.
iST:SetCurrentSeal(20154)
auraResult = { applications = 1, expirationTime = now + 8, auraInstanceID = 300 }
event("UNIT_AURA", "player", {})
assert(count() == 1)
event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.MainHand)
local beforeRepeatedRead = iST.State.WrathAuraRevision
event("UNIT_AURA", "player", {})
assert(iST.State.WrathAuraRevision == beforeRepeatedRead,
    "reading the same aura again is not a new stack update")
now = now + 0.5
event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
assert(count() == 2, "a delayed hit advances the counter despite an unchanged aura read")
event("UNIT_AURA", "player", {})
assert(count() == 2, "an old aura snapshot cannot undo the matched hit")
local buffExpiresAt = auraResult.expirationTime
assert(iST.WrathTracker.expiresAt > buffExpiresAt, "the tracked hit advanced the provisional timer")
inCombat = false
event("PLAYER_REGEN_ENABLED")
assert(count() == 1 and iST.WrathTracker.expiresAt == buffExpiresAt
    and not iST.WrathTracker.countUnconfirmed,
    "leaving combat reconciles a provisional hit with the readable buff count and expiry")
auraResult = { applications = 2, expirationTime = now + 15, auraInstanceID = 300 }
event("UNIT_AURA", "player", {})
assert(count() == 2, "a later buff update can confirm the next stack")
inCombat = true
iST:SetCurrentSeal(20375)
event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.MainHand)
event("UNIT_AURA", "player", {})
now = now + 0.5
event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
assert(count() == 0, "a repeated aura read cannot hide the next seal's release")
event("UNIT_AURA", "player", {})
assert(count() == 0, "an old aura snapshot cannot restore released stacks")
event("UNIT_AURA", "player", { removedAuraInstanceIDs = { 300 } })
auraResult = nil
iST:CancelWrathAuraChecks()
inCombat = false
print("PASS: readable combat stack corrections with hidden metadata, instance updates, cue repainting, delayed reconciliation, bounded retries, and aura replacement/removal")

iST:SetCurrentSeal(20154)
attack()
local liveCount, liveExpiry = count(), iST.WrathTracker.expiresAt
iST:StartStackTestMode()
for _ = 1, 3 do
    now = iST.State.NextSwingTime
    iST:OnBarUpdate(1)
end
assert(iST.State.PreviewStacks == 3, "stack preview reaches three")
assert(iST.WrathTracker.count == liveCount and iST.WrathTracker.expiresAt == liveExpiry,
    "previews never alter live stack state")
iSTSettings.wrathCue = "SWORD"
iST:InitializeSettings()
assert(iSTSettings.wrathCue == "BAR_COLOR", "saved drawn-sword selections move to swing bar colors")
iST:UpdateWrathDisplay()
assert(not iST.BarFrame.wrathSword, "the removed drawn sword is no longer constructed")
assert(iST.BarFrame.fill.color[1] == iST:GetWrathCueColor(3).r, "the swing fill uses the three-stack color")
assert(iST.BarFrame.borderColor[4] == iSTSettings.borderNormalColor.a, "bar colors preserve the normal border")
iST.State.PreviewStacks = 1
iST:UpdateWrathDisplay()
assert(iST.BarFrame.fill.color[2] == iST:GetWrathCueColor(1).g, "the fill follows changes in stack count")
iSTSettings.wrathCue = "COUNTER"
iST:UpdateWrathDisplay()
assert(iST.BarFrame.stackCountFrame.shown and not iST.BarFrame.wrathCueFrame.shown,
    "counter style uses the buff readout instead of the old cue text")
assert(iST.BarFrame.fill.color[2] == iSTSettings.barColor.g, "counter style restores the normal fill color")
assert(iST.BarFrame.borderColor[1] == iSTSettings.borderNormalColor.r,
    "counter style restores the configured normal border")
iSTSettings.wrathCue = "TEXT"
iST:UpdateWrathDisplay()
assert(not iST.BarFrame.wrathCueFrame.shown, "ready text stays hidden before three")
iST.State.PreviewStacks = 3
iST:UpdateWrathDisplay()
assert(iST.BarFrame.wrathCueText.text == "Switch now", "three stacks show the selected ready phrase")
iSTSettings.wrathCue = "OFF"
iST:UpdateWrathDisplay()
assert(not iST.BarFrame.wrathCueFrame.shown,
    "off hides every stack cue")

iSTSettings.wrathCue = "SWORD_IMAGES"
iST:InitializeSettings()
assert(iSTSettings.wrathCue == "SWORD_IMAGES", "the image sword remains a saved cue choice")
local imageSword = assert(iST.BarFrame.wrathSwordImages, "the image sword cue is constructed")
assert(imageSword.base.texture:find("Sword_Base", 1, true), "image cue uses the unlit sword asset")
assert(imageSword.glowMask.texture:find("Sword_GlowEdgeMask.tga", 1, true),
    "the glow has a dedicated soft edge mask")
assert(imageSword.base.masks and imageSword.base.masks[1] == imageSword.glowMask,
    "the base artwork and glow use the same feathered outer margin")
for stage = 0, 3 do
    iST.State.PreviewStacks = stage
    iST:UpdateWrathDisplay()
    assert(imageSword.shown and imageSword.base.shown, "the image cue keeps its base visible")
    assert(not iST.BarFrame.wrathSword, "image cue does not construct the removed drawn sword")
    for index, piece in ipairs(imageSword.pieces) do
        assert(#piece > 0, "each image stack has drawable textures")
        for _, texture in ipairs(piece) do
            assert(texture.masks and texture.masks[1] == imageSword.glowMask,
                "every glowing sword section shares the same aligned feather mask")
            assert(texture.shown == (index <= stage), "image sword sections light up left to right")
            if texture.texCoord then
                for _, coordinate in ipairs(texture.texCoord) do
                    assert(coordinate >= 0 and coordinate <= 1, "image crops stay inside their texture")
                end
            end
        end
    end
    if imageSword.fullGlow then
        assert(imageSword.fullGlow.texture:find("Sword_Glow", 1, true),
            "full-stack glow uses the glowing sword asset")
    end
end
local maskFile = assert(io.open("Images/Frames/Sword_GlowEdgeMask.tga", "rb"))
local maskData = maskFile:read("*a"); maskFile:close()
assert(#maskData == 18 + 256 * 256 * 4 and maskData:byte(3) == 2 and maskData:byte(17) == 32,
    "the shaped edge mask is a valid uncompressed RGBA TGA")
local function maskAlpha(x, y) return maskData:byte(18 + ((y or 128) * 256 + x) * 4 + 4) end
assert(maskAlpha(0) == 0 and maskAlpha(255) == 0 and maskAlpha(128) == 255 and maskAlpha(248) == 255,
    "the halo fades completely away at both outer edges while the blade and tip remain opaque")
assert(maskAlpha(235, 100) > maskAlpha(240, 100) and maskAlpha(240, 100) > maskAlpha(245, 100)
    and maskAlpha(245, 100) > maskAlpha(250, 100) and maskAlpha(250, 100) > maskAlpha(254, 100),
    "the right halo has a broad gradual fade away from the blade")
assert(maskAlpha(20, 100) > maskAlpha(15, 100) and maskAlpha(15, 100) > maskAlpha(10, 100)
    and maskAlpha(10, 100) > maskAlpha(5, 100), "the left halo has the same broad fade")
assert(maskAlpha(6, 128) == 255 and maskAlpha(12, 120) == 255,
    "the solid pommel remains opaque inside the left fade")
for index = 0, 255 do
    assert(maskAlpha(0, index) == 0 and maskAlpha(255, index) == 0
        and maskAlpha(index, 0) == 0 and maskAlpha(index, 255) == 0,
        "all four canvas boundaries are fully transparent")
end
local previousWidth, previousHeight = iST.BarFrame:GetWidth(), iST.BarFrame:GetHeight()
iST.BarFrame:SetSize(400, 30)
iST:UpdateWrathDisplay()
assert(math.abs(imageSword.glowMask:GetWidth() - 1024 * 400 / (890 - 246)) < 0.00001,
    "the feather mask stays aligned to the full artwork when the bar is resized")
iST.BarFrame:SetSize(previousWidth, previousHeight)
iST:UpdateWrathDisplay()
for _, style in ipairs({ "BAR_COLOR", "COUNTER", "CIRCLES", "OFF" }) do
    iSTSettings.wrathCue = style
    iST:UpdateWrathDisplay()
    assert(not imageSword.shown, "other cues hide the sword images")
end
iSTSettings.wrathCue = "OFF"

local function matchesColor(actual, expected, brightness, alpha)
    brightness = brightness or 1
    local tolerance = 0.000001
    return math.abs(actual[1] - expected.r * brightness) < tolerance
        and math.abs(actual[2] - expected.g * brightness) < tolerance
        and math.abs(actual[3] - expected.b * brightness) < tolerance
        and math.abs(actual[4] - (alpha or expected.a or 1)) < tolerance
end

-- The same stage palette drives the bar, images, bubbles, and ready text.
iSTSettings.wrathCue = "CIRCLES"
iST:InitializeSettings()
assert(iSTSettings.wrathCue == "CIRCLES", "the circles cue survives saved-setting initialization")
for _, scheme in ipairs({ "GOLD", "TRAFFIC", "BLUE" }) do
    iST:SetWrathColorScheme(scheme)
    for stage = 0, 3 do
        iST.State.PreviewStacks = stage
        local color = iST:GetWrathCueColor(stage)
        assert(type(color) == "table" and type(color.r) == "number"
            and type(color.g) == "number" and type(color.b) == "number",
            "every preset supplies all four stack-stage colors")
        iSTSettings.wrathCue = "COUNTER"
        iST:UpdateWrathDisplay()
        assert(iST.BarFrame.stackCountFrame.shown and not iST.BarFrame.wrathCueFrame.shown,
            scheme .. " counter uses the buff readout at " .. stage .. "/3")
        assert(matchesColor(iST.BarFrame.borderColor, iSTSettings.borderNormalColor),
            "stage-specific counter colors preserve the normal border")
        iSTSettings.wrathCue = "BAR_COLOR"
        iST:UpdateWrathDisplay()
        assert(matchesColor(iST.BarFrame.fill.color, color), scheme .. " bar uses the chosen " .. stage .. "/3 color")
        assert(matchesColor(iST.BarFrame.borderColor, iSTSettings.borderNormalColor), "bar colors preserve the normal border")
        iSTSettings.wrathCue = "CIRCLES"
        iST:UpdateWrathDisplay()
        assert(iST.BarFrame.wrathCircles.shown and not iST.BarFrame.wrathCueFrame.shown,
            "circles replace the counter")
        assert(matchesColor(iST.BarFrame.fill.color, iSTSettings.barColor), "circles restore the configured normal fill")
        assert(matchesColor(iST.BarFrame.borderColor, iSTSettings.borderNormalColor),
            "the circles cue preserves the configured normal border")
        for index, orb in ipairs(iST.BarFrame.wrathCircles.orbs) do
            local filled = stage >= index
            assert(matchesColor(orb.core.color, color, 1, color.a * (filled and 1 or 0.16)),
                scheme .. " circles illuminate left to right at " .. stage .. "/3")
            if not filled then assert(orb.glow.color[4] == 0, "empty circles never glow") end
        end
    end
end

iST:SetWrathColorScheme("TRAFFIC")
local presetBefore = iST:GetWrathCueColor(2)
local presetCopy = { r = presetBefore.r, g = presetBefore.g, b = presetBefore.b, a = presetBefore.a }
local customColors = {
    { r = 0.12, g = 0.23, b = 0.34, a = 0.45 },
    { r = 0.26, g = 0.37, b = 0.48, a = 0.59 },
    { r = 0.41, g = 0.52, b = 0.63, a = 0.74 },
    { r = 0.67, g = 0.78, b = 0.89, a = 0.95 },
}
for stage = 0, 3 do
    iST:SetWrathStageColor(stage, customColors[stage + 1])
    assert(iSTSettings.wrathColorScheme == "CUSTOM", "editing a stage enables custom colors")
end
for stage = 0, 3 do
    iST.State.PreviewStacks = stage
    local color = iST:GetWrathCueColor(stage)
    assert(matchesColor({ color.r, color.g, color.b, color.a }, customColors[stage + 1]),
        "custom colors remain independent for all four stages")
    assert(color ~= customColors[stage + 1], "saved colors do not alias the input color table")
    iSTSettings.wrathCue = "COUNTER"
    iST:UpdateWrathDisplay()
    assert(iST.BarFrame.stackCountFrame.shown and not iST.BarFrame.wrathCueFrame.shown,
        "the buff counter stays separate from experimental stage colors")
    iSTSettings.wrathCue = "BAR_COLOR"
    iST:UpdateWrathDisplay()
    assert(matchesColor(iST.BarFrame.fill.color, color), "custom stack colors and opacity reach the swing fill at every stage")
    iSTSettings.wrathCue = "CIRCLES"
    iST:UpdateWrathDisplay()
    for index, orb in ipairs(iST.BarFrame.wrathCircles.orbs) do
        assert(matchesColor(orb.core.color, color, 1, color.a * (stage >= index and 1 or 0.16)),
            "custom colors and opacity reach every circle stage")
    end
end
assert(iSTSettings.wrathColor0 ~= iSTSettings.wrathColor1
    and iSTSettings.wrathColor1 ~= iSTSettings.wrathColor2
    and iSTSettings.wrathColor2 ~= iSTSettings.wrathColor3,
    "custom stages use independent saved color tables")
iST:InitializeSettings()
assert(iSTSettings.wrathColorScheme == "CUSTOM"
    and iSTSettings.wrathColor2.b == customColors[3].b,
    "initializing an existing character preserves its custom palette")
iSTSettings.wrathCue = "TEXT"
iST.State.PreviewStacks = 3
iST:UpdateWrathDisplay()
assert(matchesColor(iST.BarFrame.wrathCueText.textColor, customColors[4]),
    "ready text uses the custom three-stack color")
iST:SetWrathColorScheme("TRAFFIC")
local presetAfter = iST:GetWrathCueColor(2)
assert(matchesColor({ presetAfter.r, presetAfter.g, presetAfter.b, presetAfter.a }, presetCopy),
    "editing custom colors never mutates a preset")
iST:SetWrathColorScheme("CUSTOM")
for stage = 0, 3 do
    local color = iST:GetWrathCueColor(stage)
    assert(matchesColor({ color.r, color.g, color.b, color.a }, customColors[stage + 1]),
        "returning to Custom restores the previous custom palette")
end
iST:SetWrathColorScheme("GOLD")
local goldColors = {}
for stage = 0, 3 do
    local color = iST:GetWrathCueColor(stage)
    goldColors[stage + 1] = { r = color.r, g = color.g, b = color.b, a = color.a }
end
iST:SetWrathStageColor(2, customColors[3])
for stage = 0, 3 do
    local expected = stage == 2 and customColors[3] or goldColors[stage + 1]
    local color = iST:GetWrathCueColor(stage)
    assert(matchesColor({ color.r, color.g, color.b, color.a }, expected),
        "editing one preset stage keeps the other three displayed colors")
end

local savedSettings = iSTSettings
local legacyColor = { r = 0.19, g = 0.38, b = 0.57, a = 0.76 }
iSTSettings = { wrathCueColor = legacyColor }
iST:InitializeSettings()
assert(iSTSettings.wrathColorScheme == "CUSTOM", "a saved legacy cue color migrates to custom")
for stage = 0, 3 do
    local color = iST:GetWrathCueColor(stage)
    assert(matchesColor({ color.r, color.g, color.b, color.a }, legacyColor),
        "legacy custom color is preserved at every stage")
    assert(color ~= legacyColor, "legacy migration copies rather than aliases its color")
end
iST:ResetWrathColors()
assert(iSTSettings.wrathColorScheme == "GOLD", "reset restores the default color scheme")
iSTSettings = { wrathCueColor = { r = 1, g = 0.78, b = 0.24, a = 1 } }
iST:InitializeSettings()
assert(iSTSettings.wrathColorScheme == "GOLD", "the old default gold uses the new default scheme")
for stage = 0, 3 do
    local key = "wrathColor" .. stage
    assert(iSTSettings[key] ~= iST.SettingsDefault[key], "new color saves never alias the defaults")
end
iSTSettings = savedSettings
iSTSettings.wrathCue = "OFF"
iST:StopTestMode()
assert(iST.WrathTracker.count == liveCount, "stopping preview preserves live tracking")

iST:SetCurrentSeal(20154)
iST.WrathTracker:Reset()
for _ = 1, 3 do attack() end
iSTSettings.wrathCue = "TEXT"
iST.State.TwistResultDuration = 0
iST:SetCurrentSeal(20375)
iST:UpdateWrathDisplay()
assert(iST.BarFrame.wrathCueText.text == "Attack now",
    "a completed seal switch asks for an attack rather than another switch")

local resynced = iST:NewWrathTracker()
resynced:Attack("first seal", 0)
assert(resynced:Observe(1, 31, "second seal", 16))
assert(resynced:Attack("second seal", 17) == 0 and resynced.count == 2,
    "authoritative data after expiry cannot inherit the previous stored seal")

-- Player-frame bubbles update independently of the swing timer and its cue.
iSTSettings.wrathCue = "OFF"
iSTSettings.showPlayerWrathBubbles = true
iST.State.InCombat = true
iST.State.TwistResultDuration = 0
iST.WrathTracker:Reset()
iST:CreatePlayerWrathFrame()
local playerBubbles = assert(iST.PlayerWrathFrame, "the player-frame bubbles are constructed")
for stage = 0, 3 do
    if stage > 0 then iST.WrathTracker:Attack("Seal of Righteousness", now) end
    iST:UpdateWrathDisplay()
    iST:UpdatePlayerWrathBubbles(now)
    assert(playerBubbles.shown, "player-frame bubbles remain available while the main cue is Off")
    local color = iST:GetWrathCueColor(stage)
    for index, orb in ipairs(playerBubbles.orbs) do
        assert(matchesColor(orb.core.color, color, 1, color.a * (stage >= index and 1 or 0.16)),
            "player-frame bubbles use the same four-stage custom palette")
    end
end
assert(playerBubbles.parent == PlayerFrame.manabar
    or playerBubbles.point and playerBubbles.point[2] == PlayerFrame.manabar,
    "the player-frame bubbles anchor to the mana bar")

iST:HideBar()
now = iST.WrathTracker.expiresAt + 0.1
assert(type(playerBubbles.OnUpdate) == "function", "player-frame bubbles have their own update loop")
playerBubbles.OnUpdate(playerBubbles, 1)
assert(count() == 0 and matchesColor(playerBubbles.orbs[1].core.color,
    iST:GetWrathCueColor(0), 1, iST:GetWrathCueColor(0).a * 0.16),
    "player-frame bubbles expire stacks even with the main bar hidden")

PlayerFrame:Hide()
iST:UpdatePlayerWrathBubbles(now)
assert(not playerBubbles.shown, "player-frame bubbles follow the hidden player frame")
PlayerFrame:Show()
PlayerFrame.manabar:Hide()
iST:UpdatePlayerWrathBubbles(now)
assert(not playerBubbles.shown, "player-frame bubbles do not cover a hidden mana bar")
PlayerFrame.manabar:Show()
local manaBar = PlayerFrame.manabar
PlayerFrame.manabar = nil
iST:UpdatePlayerWrathBubbles(now)
assert(not playerBubbles.shown, "a missing mana bar disables the player-frame attachment gracefully")
PlayerFrame.manabar = manaBar
playerClass = "WARRIOR"
iST:UpdatePlayerWrathBubbles(now)
assert(not playerBubbles.shown, "the Paladin-only setting also controls player-frame bubbles")
playerClass = "PALADIN"
iST.State.InCombat = false
iST:UpdatePlayerWrathBubbles(now)
assert(not playerBubbles.shown, "the combat-only setting also controls player-frame bubbles")
iST.State.InCombat = true
iSTSettings.enabled = false
iST:UpdatePlayerWrathBubbles(now)
assert(not playerBubbles.shown, "disabling iST hides the player-frame bubbles")
iSTSettings.enabled = true
iSTSettings.showPlayerWrathBubbles = false
iST:UpdatePlayerWrathBubbles(now)
assert(not playerBubbles.shown, "the player-frame option can be disabled independently")
iST.State.InCombat = false

talentRank = 0
iST:RefreshUnsealedWrathState()
attack()
assert(not iST:HasUnsealedWrath() and count() == 0, "an unselected talent disables buildup")

iSTSettings.wrathCue = "COUNTER"
iST:UpdateWrathDisplay()
assert(not imageSword.shown, "unselected talent hides the image cue")
iST:SetFakeUnsealedWrath(true)
assert(iSTSettings.fakeUnsealedWrath and iST:IsWrathTrackingEnabled(), "fake talent enables only addon tracking")
assert(not iST:HasUnsealedWrath(), "fake talent does not change the real selected talent")
assert(iST.BarFrame.stackCountFrame.shown and iST.BarFrame.stackCountValue.text == "?",
    "the stack readout waits for a real test aura")
assert(iST.BarFrame.stackCountTotal.text == "/ 3", "the stack readout shows the three-stack goal")
local originalAuraReader = C_UnitAuras.GetAuraDataBySpellName
local vengeanceAura = { name = "Vengeance", auraInstanceID = 444 }
C_UnitAuras.GetAuraDataBySpellName = function(unit, spellName, filter)
    if spellName == "Vengeance" then return vengeanceAura end
    return originalAuraReader(unit, spellName, filter)
end
C_UnitAuras.GetAuraApplicationDisplayCount = function(unit, instanceID, minimum, maximum)
    assert(unit == "player" and instanceID == 444 and minimum == 1 and maximum == 5,
        "the display API reads Vengeance's player aura instance")
    return secret
end
event("UNIT_AURA", "player", { addedAuras = { vengeanceAura } })
assert(iST.BarFrame.stackCountValue.text == secret,
    "the protected application count goes directly to the text widget")
assert(count() == 0, "the Vengeance readout does not change stored Seal stacks")
local originalCreateFrame = CreateFrame
local originalLoadAddOn, originalIsAddOnLoaded = C_AddOns.LoadAddOn, C_AddOns.IsAddOnLoaded
local originalAuraUtil, originalStringUtil = C_AuraContainerUtil, C_StringUtil
local originalContainerMixin = CustomAuraContainerInboundMixin
C_AddOns.LoadAddOn = function() return true end
C_AddOns.IsAddOnLoaded = function() return true end
C_AuraContainerUtil = {}
CustomAuraContainerInboundMixin = {}
C_StringUtil = { CreateAbbreviatedNumberFormatter = function() return { kind = "count" } end }
CreateFrame = function(frameType, name, parent, template)
    if frameType ~= "AuraContainer" then return originalCreateFrame(frameType, name, parent, template) end
    assert(template == "CustomAuraContainerTemplate", "the Blizzard managed aura template is selected")
    local container = widget(parent)
    container.slots = {}
    function container:AddAuraSlot(key, filter, options)
        assert(filter == "HELPFUL" and not self.slots[key], "each helpful buff gets its own slot")
        local button = widget(self)
        function button:SetApplicationCount(fontString, countOptions)
            self.applicationCount = fontString
            self.countFormatter = countOptions.formatter
        end
        options.initializeFrame(button)
        self.slots[key] = { button = button, filters = options.candidateFilters }
        return button
    end
    function container:SetAuraSlotCandidateFilters(key, filters) self.slots[key].filters = filters end
    function container:ShowAura(spellID)
        for _, slot in pairs(self.slots) do
            slot.button:SetShown(slot.filters.includeSpellIDs[spellID] == true)
        end
    end
    return container
end
iST:CreateStackManagedDisplay()
local managed = assert(iST.BarFrame.stackManagedContainer, "the secure buff display is created")
assert(#iST.BarFrame.stackManagedSlots == #iST.WrathEchoSpells + 1,
    "every Echo and the Vengeance test buff have independent display slots")
managed.slot = managed.slots.vengeance.button
assert(managed.slots.vengeance.filters.includeSpellIDs[20050],
    "Vengeance's known buff ID is in its own filter")
assert(managed.slot.applicationCount and managed.slot.countFormatter,
    "the secure button owns its count text and a formatter that also shows one stack")
assert(managed.slot.applicationCount.font[2] == iSTSettings.stackCounterTextSize,
    "the managed buff count matches the stack indicator text size")
local originalCounterSize = iSTSettings.stackCounterTextSize
iSTSettings.stackCounterTextSize = 28
iST:ApplyBarTypography()
assert(managed.slot.applicationCount.font[2] == 28
    and iST.BarFrame.stackCountValue.font[2] == 28
    and iST.BarFrame.twistResultText.font[2] == iSTSettings.twistTextSize,
    "counter size changes without resizing release text")
iSTSettings.stackCounterTextSize = originalCounterSize
iST:ApplyBarTypography()
local originalCounterColor = iSTSettings.stackCounterColor
iSTSettings.stackCounterColor = { r = 0.25, g = 0.5, b = 0.75, a = 0.9 }
iST:ApplyStackCounterColor()
assert(managed.slot.applicationCount.textColor[1] == 0.25
    and managed.slot.applicationCount.textColor[4] == 0.9
    and iST.BarFrame.stackCountValue.textColor[3] == 0.75,
    "the custom counter color reaches the buff count and the zero fallback")
iSTSettings.stackCounterColor = originalCounterColor
iST:ApplyStackCounterColor()
assert(managed.slot.applicationCount.widgetWidth >= 32,
    "the managed count has enough width to show its full digit")
assert(iST.BarFrame.stackCountFrame.point[5] == iST.BarFrame.wrathCueFrame.point[5],
    "the buff count occupies the original counter's position")
iST:UpdateWrathDisplay()
assert(not iST.BarFrame.stackCountValue.shown,
    "the fallback cannot overlap a present buff")
local recordedVengeanceAura = vengeanceAura
vengeanceAura = nil
iST.BarFrame.nextStackPresenceCheck = nil
iST:UpdateWrathDisplay()
assert(iST.BarFrame.stackCountValue.text == "0" and iST.BarFrame.stackCountValue.shown,
    "the counter shows zero outside combat while the buff is absent")
inCombat = true
iST:UpdateWrathDisplay()
assert(not iST.BarFrame.stackCountValue.shown,
    "the fallback never overlaps the managed buff count in combat")
inCombat = false
vengeanceAura = recordedVengeanceAura
iST.BarFrame.nextStackPresenceCheck = nil
iST:UpdateWrathDisplay()
assert(not iST.BarFrame.stackCountValue.shown,
    "the buff count replaces zero when the buff returns")
vengeanceAura.spellId = 20052
iST:RefreshVengeanceStackAura()
assert(managed.slots.vengeance.filters.includeSpellIDs[20052],
    "a buff spell ID learned out of combat updates the secure filter")
iSTSettings.fakeUnsealedWrath = false
iST:UpdateStackManagedFilter()
for _, spell in ipairs(iST.WrathEchoSpells) do
    local slot = managed.slots["echo" .. spell.id]
    assert(slot.filters.includeSpellIDs[spell.id],
        "the real talent has a separate slot for " .. spell.name)
    for _, other in ipairs(iST.WrathEchoSpells) do
        if other.id ~= spell.id then
            assert(not slot.filters.includeSpellIDs[other.id],
                "the " .. spell.name .. " slot cannot display another Echo")
        end
    end
    managed:ShowAura(spell.id)
    for _, other in ipairs(iST.WrathEchoSpells) do
        assert(managed.slots["echo" .. other.id].button.shown == (other.id == spell.id),
            "only the active Echo's box is visible")
    end
end
assert(not managed.slots.vengeance.filters.includeSpellIDs[20050],
    "the Vengeance test box is disabled for the real talent")
managed:ShowAura(nil)
for _, slot in pairs(managed.slots) do
    assert(not slot.button.shown, "all buff boxes disappear when the Echo expires")
end
local commandKey = "echo" .. iST.WrathEchoSpells[1].id
managed:ShowAura(iST.WrathEchoSpells[1].id)
assert(managed.slots[commandKey].button.shown,
    "the matching Echo box reappears when its buff returns")
iSTSettings.fakeUnsealedWrath = true
iST:UpdateStackManagedFilter()
assert(managed.slots.vengeance.filters.includeSpellIDs[20050],
    "Vengeance's box returns when the fake talent is enabled")
for _, spell in ipairs(iST.WrathEchoSpells) do
    assert(not managed.slots["echo" .. spell.id].filters.includeSpellIDs[spell.id],
        "real Echo boxes are disabled in fake mode")
end
CreateFrame = originalCreateFrame
C_AddOns.LoadAddOn, C_AddOns.IsAddOnLoaded = originalLoadAddOn, originalIsAddOnLoaded
C_AuraContainerUtil, C_StringUtil = originalAuraUtil, originalStringUtil
CustomAuraContainerInboundMixin = originalContainerMixin
iST.BarFrame.stackManagedContainer = nil
iST.BarFrame.stackManagedFilterKey = nil
iST.BarFrame.stackManagedButtons = nil
iST.BarFrame.stackManagedRows = nil
iST.BarFrame.stackManagedSlots = nil
iST.BarFrame.stackManagedTexts = nil
iSTSettings.vengeanceDisplaySpellID = nil
C_UnitAuras.GetAuraDataBySpellName = originalAuraReader
C_UnitAuras.GetAuraApplicationDisplayCount = nil
iST.State.VengeanceStackAuraID = nil
iST.State.InCombat = true
iST:SetCurrentSeal(20154)
for expected = 1, 3 do attack(); assert(count() == expected, "real swings build simulated talent stacks") end
iSTSettings.wrathCue = "SWORD_IMAGES"
iST:UpdateWrathDisplay()
assert(imageSword.shown, "fake talent can exercise the image sword during real swings")
auraResult = { applications = 1, expirationTime = now + 5, auraInstanceID = 127 }
iST:ObserveWrathAura()
assert(count() == 3, "real buff observations cannot overwrite fake talent simulation")
auraResult = nil
iST:StartStackTestMode()
iST:SetFakeUnsealedWrath(false)
assert(not iST.State.TestMode and count() == 0, "disabling fake talent ends preview and resets its stacks")
assert(not iST:IsWrathTrackingEnabled() and not imageSword.shown,
    "disabling fake talent without the real talent hides its cues")
assert(not iST.BarFrame.stackCountFrame.shown,
    "the buff readout hides when neither the fake nor real talent is enabled")
talentRank = 1
iST:RefreshUnsealedWrathState()
iST:SetFakeUnsealedWrath(true)
attack()
auraResult = { applications = 3, expirationTime = now + 5, auraInstanceID = 128 }
iST:ObserveWrathAura()
assert(count() == 1, "fake simulation ignores live buffs even when the real talent is learned")
auraResult = nil
iST:SetFakeUnsealedWrath(false)
assert(iST:HasUnsealedWrath() and iST:IsWrathTrackingEnabled() and count() == 0,
    "disabling fake mode preserves a real talent with fresh tracking")
attack()
assert(count() == 1, "the real talent continues tracking after fake mode ends")
iST.State.InCombat = false

local beforeDebug = #chatMessages
iSTSettings.debugMode = false
iST:DebugMsg("silent debug", 3)
assert(#chatMessages == beforeDebug, "debug diagnostics stay silent while disabled")
iSTSettings.debugMode = true
for _, sample in ipairs({ { 1, "DebugError" }, { 2, "DebugWarning" }, { 3, "DebugInfo" } }) do
    iST:DebugMsg("diagnostic sample", sample[1])
    local message = chatMessages[#chatMessages]
    assert(message:find(iST.L[sample[2]], 1, true) == 1
        and message:find("diagnostic sample", 1, true), "debug severity uses the normalized addon prefix")
end
iSTSettings.debugMode = false
talentRank, talentName = 1, "Twist of Light"
iST:RefreshUnsealedWrathState()
assert(not iST:HasUnsealedWrath(), "the removed talent cannot enable the new mechanic")
talentName, configAvailable = "Unsealed Wrath", false
iST:RefreshUnsealedWrathState()
assert(not iST:HasUnsealedWrath(), "an unreadable config stays neutral")
configAvailable, now = true, now + 2
assert(iST:HasUnsealedWrath(), "a temporarily unavailable talent config is retried")
iST:SetCurrentSeal(20154)
attack()
event("PLAYER_DEAD")
assert(count() == 0 and iST.State.CurrentSealID == nil, "death clears stored and active seals")
runDue()

-- Command's triggered damage has the same name as the seal itself.
-- Only casting the seal should start another thirty-second countdown.
local originalSpellName = C_Spell.GetSpellName
local spellNames = {
    [20424] = "Seal of Command", [20916] = "Seal of Command",
    [20921] = "Seal of Command", [20922] = "Seal of Command", [20923] = "Seal of Command",
    [20187] = "Seal of Righteousness", [20467] = "Judgement of Command",
    [600001] = "Seal of Command", [600002] = "Seal of Command",
    [600003] = "Seal of Command", [600004] = secret,
}
C_Spell.GetSpellName = function(id) return spellNames[id] or originalSpellName(id) end
Enum.SpellBookSpellBank = { Player = 0 }
local spellbookResult = true
C_SpellBook = { IsSpellInSpellBook = function(id, bank, includeOverrides)
    assert(bank == Enum.SpellBookSpellBank.Player and includeOverrides == false,
        "new seal IDs require an exact player-spellbook match")
    return id == 600001 and spellbookResult or false
end }
iST:StopTestMode()
inCombat = true
event("PLAYER_REGEN_DISABLED")
iST:SetCurrentSeal(20375)
local sealExpiry, sealGeneration = iST.State.SealExpiresAt, iST.State.SealGeneration
local oldSealReader, combatAuraReads = C_UnitAuras.GetPlayerAuraBySpellID, 0
C_UnitAuras.GetPlayerAuraBySpellID = function() combatAuraReads = combatAuraReads + 1; return secret end
event("UNIT_AURA", "player", {})
assert(combatAuraReads == 0 and iST.State.SealExpiresAt == sealExpiry,
    "combat leaves seal aura scans blocked while cast-event tracking remains active")
for _, procID in ipairs({20424, 20916, 20921, 20922, 20923, 20467, 20424}) do
    now = now + 1
    event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-proc", procID)
    assert(iST.State.CurrentSealID == 20375 and iST.State.SealExpiresAt == sealExpiry
        and iST.State.SealGeneration == sealGeneration, "Command damage and Judgement cannot refresh the seal")
    assert(iST.SEALS[procID] == nil, "a proc cannot teach the addon a seal-cast ID")
end
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-recast", 20375)
assert(iST.State.SealExpiresAt == now + 30 and iST.State.SealExpiresAt > sealExpiry,
    "a genuine recast refreshes the timer")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-righteousness", 20154)
sealExpiry = iST.State.SealExpiresAt
now = now + 1
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-righteousness-proc", 20187)
event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.MainHand)
assert(iST.State.CurrentSealID == 20154 and iST.State.SealExpiresAt == sealExpiry,
    "Righteousness damage and normal swings also preserve the countdown")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-secret", secret)
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-unavailable")
assert(iST.State.SealExpiresAt == sealExpiry, "hidden or missing spell IDs do not change the timer")
spellbookResult = secret
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hidden-book", 600001)
assert(iST.State.CurrentSealID == 20154, "hidden spellbook results do not confirm a new seal")
spellbookResult = true
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-new-rank", 600001)
assert(iST.State.CurrentSealID == 600001 and iST.State.CurrentSealName == "Seal of Command",
    "an actual spellbook seal can still teach an unlisted rank")
local savedSpellbook = C_SpellBook
C_SpellBook = nil
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-no-book", 600002)
C_SpellBook = { IsSpellInSpellBook = function() error("spellbook unavailable") end }
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-book-error", 600003)
C_SpellBook = savedSpellbook
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-secret-name", 600004)
event("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-other-player", 20154)
assert(iST.State.CurrentSealID == 600001, "unavailable APIs, hidden spell names and other units cannot change the seal")
iSTSettings.debugMode = true
local diagnosticCount = #chatMessages
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-proc-debug", 20424)
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-proc-debug", 20424)
assert(#chatMessages == diagnosticCount + 1 and chatMessages[#chatMessages]:find("20424", 1, true),
    "Debug Mode identifies an ignored proc once without flooding chat")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-real-debug", 20375)
local resetMessage = chatMessages[#chatMessages]
assert(resetMessage:find("Seal timer reset by Seal of Command", 1, true)
    and resetMessage:find("spell ID: 20375", 1, true)
    and resetMessage:find("UNIT_SPELLCAST_SUCCEEDED", 1, true)
    and resetMessage:find("combat: yes", 1, true)
    and resetMessage:find("30.0s", 1, true), "seal reset diagnostics name the spell, ID, event and countdown")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-repentance-debug", 20066)
resetMessage = chatMessages[#chatMessages]
assert(resetMessage:find("Weapon swing timer reset by Repentance", 1, true)
    and resetMessage:find("spell ID: 20066", 1, true)
    and resetMessage:find("UNIT_SPELLCAST_SUCCEEDED", 1, true), "swing-reset spells log their own identity")
event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.MainHand)
resetMessage = chatMessages[#chatMessages]
assert(resetMessage:find("Main-hand auto attack", 1, true) and resetMessage:find("event: PLAYER_SWING", 1, true)
    and resetMessage:find("spell ID: none", 1, true), "normal attacks identify their event without inventing a spell ID")
iSTSettings.debugMode = false
local silentResets = #chatMessages
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-silent-debug", 20375)
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-silent-repentance", 20066)
event("PLAYER_SWING", 3.6, Enum.PlayerSwingType.MainHand)
assert(#chatMessages == silentResets, "all timer-reset diagnostics stay silent with Debug Mode disabled")
local nextSwing = iST.State.NextSwingTime
now = now + 0.1
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-other", 20467, 20066)
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hidden", secret, 20066)
assert(iST.State.NextSwingTime == nextSwing, "a cast-bar ID cannot be mistaken for a swing-reset spell ID")
inCombat = false
C_UnitAuras.GetPlayerAuraBySpellID = oldSealReader
event("PLAYER_REGEN_ENABLED")

local observedSeal
C_UnitAuras.GetPlayerAuraBySpellID = function(id)
    if id == 20375 then return observedSeal end
end
iST:SetCurrentSeal(20375)
sealExpiry, sealGeneration = iST.State.SealExpiresAt, iST.State.SealGeneration
for _, expiry in ipairs({secret, 0, false}) do
    now = now + 1
    observedSeal = { expirationTime = expiry }
    event("UNIT_AURA", "player", {})
    assert(iST.State.SealExpiresAt == sealExpiry and iST.State.SealGeneration == sealGeneration,
        "aura updates without a readable expiry never restart the timer")
end
observedSeal = { expirationTime = sealExpiry }
event("UNIT_AURA", "player", {})
assert(iST.State.SealGeneration == sealGeneration, "unchanged aura expiry does not reschedule the timer")
observedSeal = { expirationTime = now + 12 }
iSTSettings.debugMode = true
event("UNIT_AURA", "player", {})
assert(iST.State.SealExpiresAt == now + 12, "a readable buff expiry corrects the timer")
resetMessage = chatMessages[#chatMessages]
assert(resetMessage:find("Seal timer synced by Seal of Command", 1, true)
    and resetMessage:find("spell ID: 20375", 1, true) and resetMessage:find("event: UNIT_AURA", 1, true),
    "aura corrections identify their source separately from successful casts")
iSTSettings.debugMode = false
local correctedExpiry = iST.State.SealExpiresAt
now = correctedExpiry
runDue()
assert(iST.State.CurrentSealID == nil, "old callbacks cannot prevent the corrected seal from expiring")
iST:SetCurrentSeal(20154)
sealExpiry = iST.State.SealExpiresAt
now = now + 5
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-switch", 20375)
now = sealExpiry
runDue()
assert(iST.State.CurrentSealID == 20375, "the previous seal's expiry cannot clear a newer cast")
now = iST.State.SealExpiresAt
runDue()
assert(iST.State.CurrentSealID == nil, "the new seal expires at its own deadline")
print("PASS: Unsealed Wrath tracking, restricted auras, isolated previews, all cue modes, and per-stage color schemes")
print("PASS: seal casts, same-name damage procs, Judgement, spellbook confirmation, and aura countdown corrections")

-- Defensive parries advance the existing swing; they are not attacks or casts.
local function close(actual, expected, message)
    assert(math.abs(actual - expected) < 0.00001, message)
end
local function seedSwing(speed, remaining)
    iST:ClearParryAnimation()
    iST.State.ParryTimingCheck = nil
    iST.State.TestMode, iST.State.Idle = false, false
    iST.State.WeaponSpeed = speed
    iST.State.NextSwingTime = now + remaining
    iST.State.LastSwingTime = now + remaining - speed
end
iSTSettings.enabled, iSTSettings.onlyInCombat = true, false
iSTSettings.debugMode = true
-- First check the engine's parry bands independently of notification delay.
local liveParryDelay = iST.CONSTANTS.PARRY_EVENT_DELAY
iST.CONSTANTS.PARRY_EVENT_DELAY = 0
assert(events.registeredEvents.UNIT_COMBAT, "parry detection is registered on the actual event frame")
for _, test in ipairs({
    { 3, 1.8 }, { 2.5, 1.3 }, { 2, 0.8 }, { 1.5, 0.6 }, { 0.8, 0.6 },
    { 0.6, 0.6 }, { 0.1, 0.1 }, { 0, 0 }, { -1, -1 },
}) do
    seedSwing(3, test[1])
    event("UNIT_COMBAT", "player", "PARRY", "", secret, 1)
    close(iST.State.NextSwingTime - now, test[2], "parry applies the full cut, floor, or no change as appropriate")
    close(iST.State.WeaponSpeed, 3, "parry haste does not change the normal weapon speed")
    close(iST.State.LastSwingTime + 3, iST.State.NextSwingTime, "start, duration, and deadline stay consistent")
end
local floorExplained = false
for _, message in ipairs(chatMessages) do
    if message:find("parry-haste floor", 1, true) then floorExplained = true end
end
assert(floorExplained, "debug explains parries too close to the next attack")
seedSwing(3, 2.8)
local unchanged = iST.State.NextSwingTime
for _, args in ipairs({ { "target", "PARRY" }, { "party1", "PARRY" }, { "player", "DODGE" },
    { "player", "BLOCK" }, { "player", "WOUND" }, { secret, "PARRY" }, { "player", secret } }) do
    event("UNIT_COMBAT", table.unpack(args))
    assert(iST.State.NextSwingTime == unchanged, "other defenders, other outcomes, and secret tokens cannot advance the player's swing")
end
iST.State.WeaponSpeed = secret
assert(not iST:ApplyParryHaste() and iST.State.NextSwingTime == unchanged,
    "an unreadable speed is never compared or used in arithmetic")
seedSwing(3, 2.8)
iST:SetCurrentSeal(20154)
iST.WrathTracker:Reset()
iST.WrathTracker:Attack("Seal of Righteousness", now)
local savedCount, savedExpiry, savedGeneration = count(), iST.State.SealExpiresAt, iST.State.SealGeneration
local originalSpeedReader = UnitAttackSpeed
UnitAttackSpeed = function() error("parry must use its already-known weapon speed") end
event("UNIT_COMBAT", "player", "PARRY", "", secret, 1)
UnitAttackSpeed = originalSpeedReader
close(iST.State.NextSwingTime - now, 1.6, "the countdown uses the corrected deadline immediately")
assert(count() == savedCount and iST.State.SealExpiresAt == savedExpiry and iST.State.SealGeneration == savedGeneration,
    "a defensive parry cannot create seal stacks, consume stacks, or reset the seal timer")
assert(chatMessages[#chatMessages]:find("Parry haste (UNIT_COMBAT/player/PARRY)", 1, true),
    "debug identifies the event and the before/after swing timing")
local bar = iST.BarFrame
local inset = bar.contentInset
local fillWidth = bar:GetWidth() - inset * 2
iST:OnBarUpdate(1)
close(bar.fill:GetWidth() / fillWidth, 0.2 / 3, "the animation starts at the old visible progress")
assert(bar.timeText:GetText() == "1.6s" and bar.parrySpark:IsShown(), "the countdown is immediate while the forward sweep animates")
now = now + 0.08
iST:OnBarUpdate(1)
local visual = bar.fill:GetWidth() / fillWidth
local target = (now - iST.State.LastSwingTime) / 3
assert(visual > 0.2 / 3 and visual < target and bar.parryTrail:GetWidth() > 1,
    "fill eases forward with a gold trail instead of jumping or delaying the deadline")
assert(bar.parrySpark.alpha > 0 and bar.parrySpark.alpha < 0.9, "the spark fades during its sweep")
local beforeSecond = iST:GetSwingBarProgress(now)
event("UNIT_COMBAT", "player", "PARRY")
close(iST:GetSwingBarProgress(now), beforeSecond, "a second parry continues smoothly from the currently visible fill")
close(iST.State.NextSwingTime - now, 0.6, "consecutive parries respect the floor")
local floorDeadline = iST.State.NextSwingTime
event("UNIT_COMBAT", "player", "PARRY")
assert(iST.State.NextSwingTime == floorDeadline, "a parry at the floor cannot postpone the attack")
now = now + 0.2
iST:OnBarUpdate(1)
close(bar.fill:GetWidth() / fillWidth, (now - iST.State.LastSwingTime) / 3,
    "the eased fill rejoins the corrected timer before the next attack")
now = now + 0.2
iST:OnBarUpdate(1)
assert(not iST.State.ParryAnimation and not bar.parrySpark:IsShown() and not bar.parryTrail:IsShown(),
    "the glow clears after its short fade")
assert(bar.fill.color[1] == iSTSettings.barColor.r and bar.fill.color[4] == iSTSettings.barColor.a,
    "the effect preserves the configured fill color and opacity")
seedSwing(3, 2.5); event("UNIT_COMBAT", "player", "PARRY")
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(not iST.State.ParryAnimation and not bar.parrySpark:IsShown(), "the actual swing clears the previous parry effect")
seedSwing(3, 2.5); event("UNIT_COMBAT", "player", "PARRY")
UnitAttackSpeed = function() return 2 end
iST:OnAttackSpeedChanged()
UnitAttackSpeed = originalSpeedReader
assert(not iST.State.ParryAnimation and iST.State.WeaponSpeed == 2,
    "a real attack-speed change clears obsolete animation offsets")
close(iST.State.NextSwingTime - now, 1.3 / 3 * 2, "ordinary haste still rescales the parry-shortened swing")
iSTSettings.debugMode = false
seedSwing(3, 2.5)
local quiet = #chatMessages
event("UNIT_COMBAT", "player", "PARRY")
assert(#chatMessages == quiet, "parry diagnostics respect Debug Mode")
iST:HideBar()
assert(not iST.State.ParryAnimation, "a hidden bar does not retain an old speedup animation")
seedSwing(3, 2.5)
local realStart, realNext = iST.State.LastSwingTime, iST.State.NextSwingTime
savedCount = count()
iST:StartParryHasteTestMode()
now = now + 0.71; runDue()
assert(iST.State.TestMode and iST.State.ParryAnimation and count() == savedCount,
    "parry preview animates without changing real seal stacks")
iST:StopTestMode()
assert(iST.State.LastSwingTime == realStart and iST.State.NextSwingTime == realNext and not iST.State.ParryAnimation,
    "stopping the parry preview restores the live timer")
iST:StartParryHasteTestMode()
iST:StartTestMode()
now = now + 0.71; runDue()
assert(not iST.State.ParryAnimation, "a cancelled preview callback cannot alter a newer preview")
iST:StopTestMode()
seedSwing(3, 2.5)
iSTSettings.enabled = false
unchanged = iST.State.NextSwingTime
event("UNIT_COMBAT", "player", "PARRY")
assert(iST.State.NextSwingTime == unchanged, "disabled tracking does not apply parry haste")
iSTSettings.enabled = true
event("UNIT_COMBAT", "player", "PARRY")
event("PLAYER_DEAD")
assert(not iST.State.ParryAnimation and iST.State.NextSwingTime == 0, "death clears the speedup effect and stops the swing")
event("UNIT_COMBAT", "player", "PARRY")
assert(iST.State.NextSwingTime == 0 and not iST.State.ParryAnimation, "a late parry event cannot restart the timer after death or a combat reload")
local optionsFile = assert(io.open("iSealTwist_OptionsPanel.lua", "rb"))
local optionsSource = optionsFile:read("*a"); optionsFile:close()
assert(optionsSource:find('L["PreviewParryHaste"]', 1, true) and optionsSource:find("iST:StartParryHasteTestMode()", 1, true),
    "Customization exposes the new parry-haste preview")
print("PASS: player parries, 40% reduction and 20% floor, secret guards, immediate countdown, eased golden sweep, cleanup, and isolated preview")

-- Forever's defensive notification can belong to the preceding swing. On a
-- fast one-hander this is longer than the 20% floor itself (2.6s * .2 = .52s).
iST.CONSTANTS.PARRY_EVENT_DELAY = liveParryDelay
iSTSettings.debugMode = true
for _, test in ipairs({ {2.4, 2.4}, {1.95, 1.95}, {1.9, 0.86}, {1.6, 0.56}, {1.3, 0.26}, {0.8, 0}, {0.4, 0} }) do
    seedSwing(2.6, test[1])
    event("UNIT_COMBAT", "player", "PARRY", "", secret, 1)
    close(iST.State.NextSwingTime - now, test[2], "2.6s parry correction uses the parry's adjusted time, not its delivery time")
    close(iST.State.LastSwingTime + 2.6, iST.State.NextSwingTime,
        "corrected fast-weapon deadlines remain consistent with the progress bar")
    if test[1] == test[2] then
        assert(not iST.State.ParryAnimation and not iST.State.ParryTimingCheck,
            "a previous swing's delayed parry cannot animate a false speedup on the new swing")
    end
    iST:OnBarUpdate(1)
    if test[2] == 0 then assert(not iST.State.ParryAnimation, "an already-due swing cannot leave a zero-duration animation active") end
end
seedSwing(3.6, 0.05)
event("UNIT_COMBAT", "player", "PARRY")
close(iST.State.NextSwingTime - now, 0.05, "a genuinely sub-floor parry does not delay a slower weapon's imminent attack")
seedSwing(2.6, 2.4)
event("UNIT_COMBAT", "player", "PARRY")
assert(chatMessages[#chatMessages]:find("adjusted event belongs before this swing", 1, true),
    "debug explains why a late previous-cycle parry is ignored")
seedSwing(2.6, 1.6)
event("UNIT_COMBAT", "player", "PARRY")
assert(iST.State.ParryTimingCheck, "debug tracks the expected next swing after a valid parry")
local unchangedPrediction, unchangedAnimation = iST.State.ParryTimingCheck, iST.State.ParryAnimation
UnitAttackSpeed = function() return 2.6 end
iST:OnAttackSpeedChanged()
UnitAttackSpeed = originalSpeedReader
assert(iST.State.ParryTimingCheck == unchangedPrediction and iST.State.ParryAnimation == unchangedAnimation,
    "an unchanged attack-speed notification cannot erase the parry animation or its timing sample")
local resultLogStart = #chatMessages
now = iST.State.NextSwingTime
event("PLAYER_SWING", 2.6, Enum.PlayerSwingType.MainHand)
local resultLogged = false
for index = resultLogStart + 1, #chatMessages do
    if chatMessages[index]:find("Next main-hand swing after parry", 1, true)
        and chatMessages[index]:find("-1.040s from original deadline", 1, true) then resultLogged = true end
end
assert(resultLogged and not iST.State.ParryTimingCheck,
    "debug compares the next actual swing against both the corrected and unchanged deadlines")
seedSwing(2.6, 1.6); event("UNIT_COMBAT", "player", "PARRY")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-reset-timing-check", 20066)
assert(not iST.State.ParryTimingCheck, "a swing-resetting spell invalidates the timing comparison")
seedSwing(2.6, 1.6); event("UNIT_COMBAT", "player", "PARRY")
UnitAttackSpeed = function() return 2.4 end
iST:OnAttackSpeedChanged()
UnitAttackSpeed = originalSpeedReader
assert(not iST.State.ParryTimingCheck, "a real speed change invalidates the timing comparison")
iSTSettings.debugMode = false
seedSwing(2.6, 1.6)
quiet = #chatMessages
event("UNIT_COMBAT", "player", "PARRY")
assert(#chatMessages == quiet and not iST.State.ParryTimingCheck, "live parry timing diagnostics stay off when Debug Mode is off")
iST:ClearParryAnimation()
iST.State.LastSwingTime, iST.State.NextSwingTime = 0, 0
print("PASS: Forever event-delay compensation, 2.6s one-hander cases, previous-cycle rejection, due-swing animation cleanup, and actual-swing timing diagnostics")

iSTSettings.wrathCue = "BAR_COLOR"
iST:StartStackTestMode()
for stage = 0, 3 do
    iST.State.PreviewStacks = stage
    iST:OnBarUpdate(1)
    assert(matchesColor(bar.fill.color, iST:GetWrathCueColor(stage)),
        "the real bar update retains the selected color at every preview stack stage")
end
now = now + 0.8
assert(iST:ApplyParryHaste(true), "parry preview works with the colored swing bar")
iST:OnBarUpdate(1)
assert(matchesColor(bar.fill.color, iST:GetWrathCueColor(3)) and bar.parrySpark:IsShown(),
    "the parry animation leaves the three-stack fill color intact")
iST:StopTestMode()
talentRank, talentName, inCombat = 0, "Unsealed Wrath", false
iST.State.InCombat = false
iST:SetFakeUnsealedWrath(false)
iST:OnBarUpdate(1)
assert(matchesColor(bar.fill.color, iSTSettings.barColor, 1, iSTSettings.barColor.a * 0.18),
    "without Unsealed Wrath, the idle timer uses its normal bar color")
iST:SetFakeUnsealedWrath(true)
iST:SetCurrentSeal(20154)
for _ = 1, 3 do iST.WrathTracker:Attack("Seal of Righteousness", now) end
iST:OnBarUpdate(1)
local idleStackColor = iST:GetWrathCueColor(3)
assert(matchesColor(bar.fill.color, idleStackColor, 1, idleStackColor.a * 0.18),
    "idle stack colors preserve custom opacity and the normal dimming")
iSTSettings.wrathCue = "OFF"
iST:UpdateWrathDisplay()
assert(matchesColor(bar.fill.color, iSTSettings.barColor, 1, iSTSettings.barColor.a * 0.18),
    "turning the cue off immediately restores the normal idle fill")
print("PASS: swing-bar palettes and custom opacity at all four stages, saved cue migration, normal-color fallback, idle dimming, and parry animation coexistence")

local savedIconSize = iSTSettings.sealIconSize
local smallCorrection
for _, size in ipairs({ 16, 25, 64 }) do
    iSTSettings.sealIconSize = size
    bar:UpdateModernDimensions(iSTSettings.barHeight)
    assert(bar.sealTimerText.parent == bar.sealTimerOverlay,
        "the countdown belongs to a dedicated overlay above the seal artwork")
    local point, relative, relativePoint, x, y = bar.sealTimerText:GetPoint()
    assert(point == "CENTER" and relative == bar.sealTimerOverlay and relativePoint == "CENTER",
        "the text area stays centered on the icon overlay")
    assert(bar.sealTimerText:GetWidth() == size and bar.sealTimerText:GetHeight() == size,
        "the countdown text area follows both dimensions of the icon")
    if size == 16 then smallCorrection = x end
    if size == 64 then assert(x > smallCorrection * 3 and y < 0,
        "large icons receive a proportional visual correction instead of the small-icon pixel nudge") end
    for _, seconds in ipairs({20, 11, 7, 1}) do
        iST.State.SealExpiresAt = now + seconds
        iST:UpdateSealTimer(now)
        local _, target, _, nextX, nextY = bar.sealTimerText:GetPoint()
        assert(target == relative and nextX == x and nextY == y,
            "single- and double-digit countdowns retain the same visual center")
    end
end
iSTSettings.sealIconSize = savedIconSize
bar:UpdateModernDimensions(iSTSettings.barHeight)
print("PASS: dedicated seal-countdown overlay, proportional font correction at 16/25/64px, and stable single/double-digit anchoring")

iSTSettings.showSealIcon, iSTSettings.showSealTimer = true, true
iST:SetCurrentSeal(20154)
local ring = bar.sealRingCountdown
local function ringFraction()
    return math.max(0, math.min(1, (ring.cooldownStart + ring.cooldownDuration - now) / ring.cooldownDuration))
end
assert(ring:IsShown() and ring.drawSwipe and ring.reverse == false and not ring.drawEdge and not ring.drawBling,
    "the seal ring uses a smooth draining swipe without edge flashes")
assert(ring.hideCountdownNumbers and ring.noCooldownCount, "the ring does not add another number over the centered timer")
assert(bar.sealIcon.parent == bar.sealPortraitFrame and bar.sealPortraitFrame:GetFrameLevel() > ring:GetFrameLevel()
    and bar.sealTimerOverlay:GetFrameLevel() > bar.sealPortraitFrame:GetFrameLevel(),
    "the portrait and countdown stay above the swipe so the icon itself is never darkened")
assert(ring.allPointsTarget == bar.sealIconRing, "the countdown follows the outer circle when it is resized")
close(ringFraction(), 1, "a fresh seal starts with a full ring")
assert(bar.sealIconRing.color[1] == bar.sealIconRing.color[2] and bar.sealIconRing.color[2] == bar.sealIconRing.color[3],
    "elapsed time reveals a neutral gray ring underneath")
local ringSets = ring.cooldownSets
now = iST.State.SealExpiresAt - 15
for _ = 1, 20 do iST:UpdateSealTimer(now) end
close(ringFraction(), 0.5, "half the seal duration leaves half the ring")
assert(ring.cooldownSets == ringSets and bar.sealTimerText:GetText() == "15",
    "normal updates keep number and ring synchronized without restarting the native animation")
now = now + 10.1
iST:UpdateSealTimer(now)
assert(ring.swipeColor[2] == 0.08 and bar.sealTimerText.textColor[2] == 0.12,
    "the remaining arc and number turn red below five actual seconds")
iSTSettings.showSealTimer = false
iST:UpdateSealTimer(now)
assert(not ring:IsShown() and not ring.cooldownStart and bar.sealIconRing.color[2] == 0.59,
    "turning off the seal timer restores the static gold circle")
iSTSettings.showSealTimer = true
iST:UpdateSealTimer(now)
close(ringFraction(), 4.9 / 30, "re-enabling the ring resumes the actual remaining fraction")
iSTSettings.showSealIcon = false
iST:UpdateSealDisplay()
assert(not ring:IsShown() and not bar.sealTimerText:IsShown(), "hiding the icon also clears its countdown")
iSTSettings.showSealIcon = true
iST:SetCurrentSeal(20375, now + 12, "UNIT_AURA")
close(ringFraction(), 12 / 30, "a recovered partly expired seal uses its full duration scale")
ringSets = ring.cooldownSets
local ringExpiry = bar.sealRingExpiresAt
event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-command-proc", 20424)
assert(ring.cooldownSets == ringSets and bar.sealRingExpiresAt == ringExpiry,
    "Seal of Command damage cannot refill the ring")
iST:SetCurrentSeal(20375)
close(ringFraction(), 1, "casting the seal again refills the ring")
ringSets = ring.cooldownSets
for _, size in ipairs({16, 64}) do
    iSTSettings.sealIconSize = size
    bar:UpdateModernDimensions(iSTSettings.barHeight)
    iST:UpdateSealTimer(now)
end
assert(ring.cooldownSets == ringSets, "resizing does not restart the countdown")
iSTSettings.sealIconSize = savedIconSize
bar:UpdateModernDimensions(iSTSettings.barHeight)
iST:ClearCurrentSeal()
assert(not ring:IsShown() and not bar.sealRingExpiresAt and not ring.cooldownStart,
    "seal removal clears the ring and its cached deadline")
print("PASS: circular seal countdown, gray elapsed arc, final-five-second warning, unchanged portrait, partial recovery, recasts, resize, and disable/removal cleanup")

-- Seal-pair guidance must not change what the real tracker observes.
playerClass, playerDead, inCombat = "PALADIN", false, false
iST.State.TestMode, iST.State.StackTestMode = false, false
iSTSettings.twistFromSeal, iSTSettings.twistIntoSeal = "Seal of Righteousness", "Seal of Command"
iST:SetFakeUnsealedWrath(true)
iST.State.TwistResultDuration = 0
iST:SetSealStackMode("ALTERNATE")
iST:SetCurrentSeal(20154)
for _ = 1, 3 do attack() end
iST:SetCurrentSeal(20375)
local stacks, tracking, armed, wrong = iST:GetWrathDisplayState(now)
assert(stacks == 3 and tracking and armed and not wrong, "alternating mode allows releasing From stacks")
attack()
attack()
assert(count() == 1 and not select(4, iST:GetWrathDisplayState(now)), "alternating mode builds the other seal normally")
iST:SetCurrentSeal(20154)
attack()
assert(count() == 0 and not select(4, iST:GetWrathDisplayState(now)), "alternating mode releases in either direction")

iST:SetSealStackMode("FROM_ONLY")
for _ = 1, 3 do attack() end
iST:SetCurrentSeal(20375)
assert(not select(4, iST:GetWrathDisplayState(now)), "selecting Into for the release is not a wrong-seal warning")
attack()
assert(count() == 0 and select(4, iST:GetWrathDisplayState(now)), "From-only mode asks to return after the release swing")
iST.State.TwistResultDuration = 0
for _, style in ipairs({ "BAR_COLOR", "SWORD_IMAGES", "CIRCLES", "COUNTER", "TEXT" }) do
    iSTSettings.wrathCue = style
    iST:UpdateWrathDisplay(now)
    assert(bar.wrathCueFrame:IsShown() and bar.wrathCueText:GetText() == "Wrong seal",
        "each enabled cue can show the return-to-From warning")
    assert(bar.wrathCueText.textColor[2] == 0.12 and not bar.wrathCircles:IsShown(), "wrong-seal text is red and does not overlap circles")
end
iSTSettings.wrathCue = "OFF"
iST:UpdateWrathDisplay(now)
assert(not bar.wrathCueFrame:IsShown(), "Off also hides wrong-seal cues")
iSTSettings.wrathCue = "COUNTER"
iST.State.TwistResultDuration = 0.5
iST:UpdateWrathDisplay(now)
assert(not bar.wrathCueFrame:IsShown(), "the release message keeps priority until its fade ends")
iST.State.TwistResultDuration = 0
attack()
assert(count() == 1 and select(4, iST:GetWrathDisplayState(now)), "wrong-seal guidance never hides actual stacks built on Into")
iST:SetCurrentSeal(20154)
assert(not select(4, iST:GetWrathDisplayState(now)), "returning to From clears the warning")
iST:SetCurrentSeal(20164)
assert(select(4, iST:GetWrathDisplayState(now)), "an unrelated seal is not the preferred buildup seal")
iST.State.TestMode, iST.State.StackTestMode, iST.State.PreviewStacks = true, true, 2
assert(not select(4, iST:GetWrathDisplayState(now)), "bar previews cannot inherit live wrong-seal warnings")
iST.State.TestMode, iST.State.StackTestMode = false, false
iSTSettings.fakeUnsealedWrath, iST.State.UnsealedWrathKnown = false, false
inCombat = true
assert(not select(4, iST:GetWrathDisplayState(now)), "the rotation warning requires the talent or explicit fake mode")
inCombat = false
iST:SetFakeUnsealedWrath(true)
print("PASS: alternating and From-only guidance, release timing, all cue styles, preview isolation, talent gating, and unchanged live stacks")

-- Exercise the actual reminder module, including its independent event frame.
local furyAura, furyReads, specReads = nil, 0, 0
local points = { 5, 31, 0 }
C_UnitAuras.GetPlayerAuraBySpellID = function(id)
    assert(id == 25780, "the reminder only queries its own Righteous Fury buff")
    furyReads = furyReads + 1
    return furyAura
end
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    assert(unit == "player" and filter == "HELPFUL" and not inCombat, "only scan the player's readable buffs outside combat")
    if index > 1 then return nil end
    if not issecretvalue(furyAura) and type(furyAura) == "table" then
        return { spellId = 25780, expirationTime = furyAura.expirationTime,
            duration = furyAura.duration, auraInstanceID = furyAura.auraInstanceID }
    end
    return furyAura
end
C_SpecializationInfo = { GetSpecializationInfo = function(index, inspect, pet)
    assert(not inCombat, "reminder talent reads must never run in combat")
    assert(inspect == false and pet == false, "use the local player's applied talent points")
    specReads = specReads + 1
    return index, "Tree", "", 1, "", 0, points[index], "", 99 -- preview points must be ignored
end }
local function reminderEvent(name, ...)
    for _, frame in ipairs(frames) do
        if frame.registeredEvents and frame.registeredEvents[name] and frame.OnEvent and frame ~= events then
            frame.OnEvent(frame, name, ...)
        end
    end
end
local function tickReminders(seconds)
    now = now + seconds
    for _, frame in ipairs(frames) do
        if frame.OnUpdate and frame:IsShown() and frame ~= bar then frame.OnUpdate(frame, seconds) end
    end
end
iSTSettings.enabled, iSTSettings.onlyAsPaladin, iSTSettings.onlyInCombat = true, true, true
iST:InitializeReminders()
local fury, seal = iST.ReminderFrames.FURY, iST.ReminderFrames.SEAL
local furySettings, sealSettings = iSTSettings.reminders.FURY, iSTSettings.reminders.SEAL
assert(not furySettings.enabled and not sealSettings.enabled and not fury:IsShown() and not seal:IsShown(), "reminders are opt-in")
assert(furySettings.warningSeconds == 60 and sealSettings.warningSeconds == 5, "independent warning defaults")
assert(furySettings.point ~= iST.ReminderDefaults.FURY.point, "saved positions do not alias defaults")
sealSettings.enabled = true
iST:SetSealStackMode("ALTERNATE")
iST:ClearCurrentSeal()
iST:ApplyReminderSettings()
assert(seal:IsShown() and seal.title:GetText() == "Cast a seal", "missing seals warn even while the combat-only bar is hidden")
iST:SetCurrentSeal(20154)
iST:UpdateReminders()
assert(not seal:IsShown(), "a fresh seal hides its reminder")
tickReminders(25)
assert(seal:IsShown() and seal.title:GetText() == "Refresh Seal of Righteousness" and seal.timer:GetText() == "5s left", "the chosen threshold triggers without requiring a visible swing bar")
sealSettings.warningSeconds = 0
iST:ApplyReminderSettings()
assert(not seal:IsShown(), "zero disables advance expiry warnings")
tickReminders(5)
assert(seal:IsShown() and seal.title:GetText() == "Cast a seal" and seal.timer:GetText() == "", "zero still warns on expiry, without inventing a time left")
sealSettings.showIcon, sealSettings.showTime, sealSettings.scale = false, false, 1.6
sealSettings.warningSeconds = 5
iST:SetCurrentSeal(20154, now + 3)
iST:ApplyReminderSettings()
assert(seal:IsShown() and not seal.icon:IsShown() and seal.timer:GetText() == "" and seal:GetScale() == 1.6, "icon, countdown, and scale are independent options")
assert(seal.title.point[4] == 0, "text reclaims the icon space when the icon is hidden")
sealSettings.showTime = true
iST:SetSealStackMode("FROM_ONLY")
iST.WrathTracker:Reset()
iST:SetCurrentSeal(20375)
iST:UpdateReminders()
assert(seal:IsShown() and seal.title:GetText() == "Switch to Seal of Righteousness", "the standalone seal reminder also supports the preferred buildup seal")

sealSettings.hideAfterIdle = true
reminderEvent("PLAYER_REGEN_ENABLED")
tickReminders(299)
assert(seal:IsShown(), "the seal reminder remains available during the first five idle minutes")
tickReminders(1.1)
assert(not seal:IsShown(), "the optional idle filter hides the seal reminder after five minutes")
inCombat = true
reminderEvent("PLAYER_REGEN_DISABLED")
assert(seal:IsShown(), "combat immediately restores the seal reminder after a long idle")
inCombat = false
reminderEvent("PLAYER_REGEN_ENABLED")
assert(seal:IsShown(), "combat end starts a new five-minute idle period")
sealSettings.hideAfterIdle = false

local currentReminderMap = 1454
local reminderFaction = "Horde"
function UnitFactionGroup(unit) assert(unit == "player"); return reminderFaction end
C_Map = {
    GetBestMapForUnit = function(unit) assert(unit == "player"); return currentReminderMap end,
    GetMapInfo = function(mapID)
        if mapID == 9999 then return { parentMapID = 1458 } end
        return { parentMapID = 0 }
    end,
}
sealSettings.hideInCapitals = true
reminderEvent("ZONE_CHANGED_NEW_AREA")
assert(not seal:IsShown(), "the seal reminder hides in a friendly capital city")
iST:PreviewReminder("SEAL")
assert(seal:IsShown(), "preview still allows positioning in a capital city")
iST:PreviewReminder("SEAL")
currentReminderMap = 9999
reminderEvent("ZONE_CHANGED_INDOORS")
assert(not seal:IsShown(), "friendly capital indoor maps inherit the city filter")
currentReminderMap = 1453
reminderEvent("ZONE_CHANGED_NEW_AREA")
assert(seal:IsShown(), "an enemy capital does not hide the seal reminder")
reminderFaction = "Alliance"
currentReminderMap = 1455
reminderEvent("ZONE_CHANGED_NEW_AREA")
assert(not seal:IsShown(), "Alliance capitals hide the seal reminder for Alliance players")
currentReminderMap = 1454
reminderEvent("ZONE_CHANGED_NEW_AREA")
assert(seal:IsShown(), "Horde capitals do not hide the seal reminder for Alliance players")
currentReminderMap = 1420
reminderEvent("ZONE_CHANGED_NEW_AREA")
assert(seal:IsShown(), "leaving a capital restores the seal reminder")
sealSettings.hideInCapitals = false

furySettings.enabled, furySettings.protOnly = true, true
iST:ApplyReminderSettings()
assert(fury:IsShown() and iST.State.ReminderProtection == true, "Protection majority allows a missing Fury warning")
furyAura = { expirationTime = now + 1680, duration = 1800, auraInstanceID = 6 }
reminderEvent("UNIT_AURA", "player", {})
local confirmedFuryExpiry = iST.State.FuryExpiresAt
assert(not fury:IsShown(), "Fury with 28 minutes left does not need a reminder")
furyAura = nil
reminderEvent("UNIT_AURA", "player", {})
assert(iST.State.FuryPresent and iST.State.FuryExpiresAt == confirmedFuryExpiry,
    "a transient nil just before combat must not discard a confirmed Fury timer")
inCombat = true
furyAura = nil
reminderEvent("PLAYER_REGEN_DISABLED")
reminderEvent("UNIT_AURA", "player", {})
tickReminders(2)
assert(iST.State.FuryPresent and iST.State.FuryExpiresAt == confirmedFuryExpiry and not fury:IsShown(),
    "nil combat lookups cannot turn a confirmed 28-minute Fury buff into Missing")
local savedFuryID = iST.State.FuryAuraID
iST.State.FuryKnown, iST.State.FuryPresent, iST.State.FuryExpiresAt, iST.State.FuryAuraID = nil, nil, nil, nil
reminderEvent("UNIT_AURA", "player", {})
assert(iST.State.FuryKnown == nil and not fury:IsShown(), "a combat reload with unknown Fury data cannot invent a Missing warning")
iST.State.FuryKnown, iST.State.FuryPresent, iST.State.FuryExpiresAt, iST.State.FuryAuraID = true, true, confirmedFuryExpiry, savedFuryID
tickReminders(1620)
assert(fury:IsShown() and fury.title:GetText() == "Refresh Righteous Fury" and fury.timer:GetText() == "58s left",
    "the preserved countdown still reaches the warning threshold during combat")
inCombat = false
furyAura = { expirationTime = confirmedFuryExpiry, duration = 1800, auraInstanceID = 6 }
reminderEvent("PLAYER_REGEN_ENABLED")
assert(iST.State.FuryExpiresAt == confirmedFuryExpiry and fury.title:GetText() == "Refresh Righteous Fury", "leaving combat confirms the original deadline without refreshing it")
furyAura = { expirationTime = now + 300, duration = 600, auraInstanceID = 7 }
reminderEvent("UNIT_AURA", "player", {})
assert(not fury:IsShown(), "Fury is hidden above its threshold")
furyAura.expirationTime = now + 60
reminderEvent("UNIT_AURA", "player", {})
assert(fury:IsShown() and fury.title:GetText() == "Refresh Righteous Fury" and fury.timer:GetText() == "1m 00s left", "Fury shows its remaining duration at the configured threshold")
furyAura = { expirationTime = 0, duration = 0, auraInstanceID = 8 }
reminderEvent("UNIT_AURA", "player", {})
assert(not fury:IsShown(), "a permanent Fury buff is not treated as expired")
points = { 0, 5, 31 }
furyAura = nil
reminderEvent("PLAYER_TALENT_UPDATE")
tickReminders(0.31)
assert(not fury:IsShown() and iST.State.ReminderProtection == false, "Retribution hides the Protection-only reminder")
for _, distribution in ipairs({ { 10, 10, 0 }, { 0, 0, 0 }, { 0, 10, 10 } }) do
    points = distribution
    reminderEvent("PLAYER_TALENT_UPDATE")
    assert(not fury:IsShown(), "ties and no talents do not count as Protection")
end
points = { 5, 31, 0 }
reminderEvent("PLAYER_TALENT_UPDATE")
assert(fury:IsShown(), "a talent change updates the filter")

inCombat = true
local previousReads = specReads
iST.State.ReminderProtection = nil
reminderEvent("PLAYER_TALENT_UPDATE")
tickReminders(2)
assert(specReads == previousReads and not fury:IsShown(), "unknown Protection after a combat reload waits for safe talent data")
reminderEvent("UNIT_SPELLCAST_SUCCEEDED", secret, "", secret)
reminderEvent("UNIT_AURA", secret, secret)
assert(specReads == previousReads, "restricted event values never trigger a talent read")
inCombat = false
reminderEvent("PLAYER_REGEN_ENABLED")
tickReminders(1)
assert(fury:IsShown() and specReads > previousReads, "leaving combat resolves the pending Protection filter")

furyAura = { expirationTime = now + 40, duration = 600, auraInstanceID = 9 }
reminderEvent("UNIT_AURA", "player", {})
local expiry = iST.State.FuryExpiresAt
inCombat = true
furyAura = secret
reminderEvent("UNIT_AURA", "player", {})
assert(iST.State.FuryExpiresAt == expiry, "a completely restricted aura preserves known expiry")
furyAura = { expirationTime = secret, duration = secret, auraInstanceID = secret }
reminderEvent("UNIT_AURA", "player", {})
assert(iST.State.FuryExpiresAt == expiry, "restricted fields do not enter timer arithmetic")
tickReminders(41)
reminderEvent("UNIT_AURA", "player", {})
assert(iST.State.FuryPresent and not iST.State.FuryExpiresAt and not fury:IsShown(), "a confirmed present buff with a hidden new duration is not reported missing from a stale expiry")
furyAura = nil
reminderEvent("UNIT_AURA", "player", { removedAuraInstanceIDs = { secret, 9 } })
tickReminders(0.31)
assert(fury:IsShown() and fury.title:GetText() == "Cast Righteous Fury", "readable removal or absence clears Fury")
reminderEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-fury", 25780)
assert(not fury:IsShown(), "the cast waits briefly for the aura update instead of immediately reporting it missing")
tickReminders(1)
assert(iST.State.FuryPresent and not fury:IsShown(), "a hidden lookup after a Fury cast cannot undo its confirmation in combat")
inCombat = false
reminderEvent("PLAYER_REGEN_ENABLED")
tickReminders(0.31)
assert(fury:IsShown() and not iST.State.FuryPresent, "an absent Fury buff is confirmed missing after combat")
inCombat = true
furyAura = { expirationTime = now + 50, duration = 600, auraInstanceID = 10 }
reminderEvent("UNIT_AURA", "player", {})
assert(fury:IsShown() and fury.timer:GetText() == "50s left", "a later readable aura restores its actual countdown")
inCombat = false

points = { 0, 0, 31 }
reminderEvent("PLAYER_TALENT_UPDATE")
assert(not fury:IsShown(), "Protection filter still applies after safe refresh")
iST:PreviewReminder("FURY")
assert(fury:IsShown() and fury.strata == "DIALOG" and fury.mouseEnabled, "preview can be moved above the settings window even with the filter off")
fury.OnDragStart(fury)
assert(fury.moving, "preview permits dragging a locked reminder")
fury:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 45, -70)
fury.OnDragStop(fury)
assert(not fury.moving and furySettings.point[1] == "TOPLEFT" and furySettings.point[3] == 45, "dragging saves this character's position")
iST:PreviewReminder("FURY")
assert(not fury:IsShown(), "the preview button toggles off")
iST:PreviewReminder("FURY")
tickReminders(30)
assert(not fury:IsShown(), "the preview expires without changing real buff state")
iST:ResetReminderPosition("FURY")
assert(furySettings.point[1] == "CENTER" and furySettings.point[3] == -180, "reset restores only this reminder's position")
furySettings.protOnly = false
furyAura = nil
iST:ApplyReminderSettings()
assert(fury:IsShown(), "Protection-only can be disabled independently")
furySettings.dungeonsOnly = true
iST:UpdateReminders()
assert(not fury:IsShown(), "the dungeon filter hides Fury outdoors")
inInstance, instanceType = true, "party"
iST:UpdateReminders()
assert(fury:IsShown(), "the dungeon filter allows a five-player dungeon even while solo")
instanceType = "raid"
iST:UpdateReminders()
assert(fury:IsShown(), "the dungeon filter also allows raid instances")
instanceType = "pvp"
iST:UpdateReminders()
assert(not fury:IsShown(), "the dungeon filter excludes battlegrounds")
inInstance, instanceType = false, "none"
furySettings.dungeonsOnly, furySettings.partyOnly, grouped = false, true, true
iST:UpdateReminders()
assert(fury:IsShown(), "the party filter allows a party outdoors")
inInstance, instanceType = true, "raid"
iST:UpdateReminders()
assert(fury:IsShown(), "the party filter also allows raid groups")
inInstance, instanceType, grouped = false, "none", false
iST:UpdateReminders()
assert(not fury:IsShown(), "the party filter excludes solo play")
furySettings.dungeonsOnly, grouped = true, true
iST:UpdateReminders()
assert(not fury:IsShown(), "both filters require a party inside a dungeon")
inInstance, instanceType = true, "party"
iST:UpdateReminders()
assert(fury:IsShown(), "both filters allow a party inside a dungeon")
instanceType = "raid"
iST:UpdateReminders()
assert(fury:IsShown(), "both filters allow a raid group inside a raid")
instanceType = secret
iST:UpdateReminders()
assert(not fury:IsShown(), "restricted instance data cannot pass the dungeon filter")
inInstance, instanceType, grouped = false, "none", false
furySettings.dungeonsOnly, furySettings.partyOnly = false, false
iST:UpdateReminders()
assert(fury:IsShown(), "turning the new filters off restores the usual reminder")
playerDead = true
iST:UpdateBarVisibility()
assert(not fury:IsShown() and not seal:IsShown(), "death hides both reminders")
playerDead, playerClass = false, "WARRIOR"
iST:UpdateBarVisibility()
assert(not fury:IsShown() and not seal:IsShown(), "the Paladin-only setting applies to reminders")
playerClass = "PALADIN"
iSTSettings.enabled = false
iST:UpdateBarVisibility()
assert(not fury:IsShown() and not seal:IsShown(), "disabling the addon hides reminders too")
iSTSettings.enabled = true
furySettings.enabled, sealSettings.enabled = false, false
iST:ApplyReminderSettings()
local readsBefore = furyReads
reminderEvent("UNIT_AURA", "player", {})
assert(furyReads == readsBefore and not fury:IsShown() and not seal:IsShown(), "disabled reminders do not poll aura data")
print("PASS: optional buff reminders, expiry thresholds, permanent buffs, preferred seal, Protection points, combat reloads, secret guards, previews, drag/scale settings, and cleanup")

-- Recover the real buff when a convenience lookup or an aura event is incomplete.
furySettings.enabled, furySettings.protOnly = true, false
furyAura = { expirationTime = now + 1440, duration = 1800, auraInstanceID = 50 }
iST:ApplyReminderSettings()
local stableExpiry = iST.State.FuryExpiresAt
inCombat = true
reminderEvent("PLAYER_REGEN_DISABLED")
furyAura = nil
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
    assert(unit == "player" and id == 50, "instance recovery uses only the previously confirmed public ID")
    return { expirationTime = stableExpiry, duration = secret, auraInstanceID = 50 }
end
reminderEvent("UNIT_AURA", "player", {})
assert(iST.State.FuryPresent and iST.State.FuryExpiresAt == stableExpiry and not fury:IsShown(),
    "a readable cached instance recovers Fury while the spell lookup is hidden")
C_UnitAuras.GetAuraDataByAuraInstanceID = function() return secret end
tickReminders(1.1)
assert(iST.State.FuryExpiresAt == stableExpiry and not fury:IsShown(), "a restricted instance lookup cannot erase its timer")
C_UnitAuras.GetAuraDataByAuraInstanceID = nil
reminderEvent("UNIT_AURA", "player", { removedAuraInstanceIDs = { 50 } })
assert(iST.State.FuryPresent and iST.State.FuryExpiresAt == stableExpiry, "removal leaves time for a replacement event")
tickReminders(0.1)
reminderEvent("UNIT_AURA", "player", { addedAuras = {
    { spellId = 25780, expirationTime = stableExpiry, duration = 1800, auraInstanceID = 51 },
} })
tickReminders(0.3)
assert(iST.State.FuryPresent and iST.State.FuryAuraID == 51 and iST.State.FuryExpiresAt == stableExpiry and not fury:IsShown(),
    "a replacement event keeps the original deadline without inventing another thirty minutes")

reminderEvent("UNIT_AURA", "player", { removedAuraInstanceIDs = { 51 }, addedAuras = { secret } })
tickReminders(0.4)
assert(iST.State.FuryPresent and iST.State.FuryExpiresAt == stableExpiry,
    "a hidden replacement is uncertain rather than confirmed removal")
inCombat = false
local originalScan = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    assert(unit == "player" and filter == "HELPFUL" and not inCombat, "recovery scans stay out of combat")
    if index == 1 then return { spellId = 465, name = "Devotion Aura" } end
    if index == 2 then return { spellId = 25780, expirationTime = stableExpiry, duration = 1800, auraInstanceID = 51 } end
end
reminderEvent("PLAYER_REGEN_ENABLED")
assert(iST.State.FuryPresent and iST.State.FuryExpiresAt == stableExpiry and not fury:IsShown(),
    "a complete buff scan finds Fury even when its spell lookup still returns nil")
iST.State.FuryKnown, iST.State.FuryPresent, iST.State.FuryExpiresAt, iST.State.FuryAuraID = true, false, nil, nil
tickReminders(1.1)
assert(iST.State.FuryPresent and iST.State.FuryExpiresAt == stableExpiry and not fury:IsShown(),
    "periodic checks recover a missed aura event and a stale Missing state")
C_UnitAuras.GetAuraDataByIndex = originalScan
reminderEvent("UNIT_AURA", "player", {})
tickReminders(0.31)
assert(fury:IsShown() and iST.State.FuryPresent == false, "two complete scans still detect a genuinely removed buff")
furySettings.enabled = false
iST:ApplyReminderSettings()
print("PASS: transient combat-entry reads, cached-instance recovery, split removal/replacement events, hidden replacements, complete buff scans, and automatic stale-state recovery")

-- Build and operate the real settings controls, not a second implementation.
UISpecialFrames = {}
C_AddOns.IsAddOnLoaded = function() return false end
iST:SetSealStackMode("ALTERNATE")
assert(loadfile("iSealTwist_OptionsPanel.lua"))("iSealTwist", iST)
iST:CreateOptionsPanel()
assert(iST.SettingsFrame and UISpecialFrames[#UISpecialFrames] == "iSTSettingsFrame", "the full settings panel builds and keeps Escape support")
assert(iST.SettingsFrame:GetWidth() == 820 and iST.SettingsFrame:GetHeight() == 580
    and iST.SettingsFrame.backdrop.edgeSize == 1,
    "the settings window uses the wider layout and thin border")
assert(iST.SettingsFrame.pageHeader.title:GetText() == iST.L.TabGeneral
    and iST.SettingsFrame.pageHeader.subtitle:GetText() == iST.L.SettingsGeneralSummary,
    "the selected page has its own title and summary")
local lockCheckbox = iST.SettingsFrame.barLockCheckbox
assert(lockCheckbox, "bar lock control is available in settings")
iST:ToggleBarLock()
assert(lockCheckbox:GetChecked() == iSTSettings.barLocked,
    "the minimap and slash lock action updates an already built settings checkbox")
lockCheckbox:SetChecked(not iSTSettings.barLocked)
lockCheckbox.OnClick(lockCheckbox)
assert(lockCheckbox:GetChecked() == iSTSettings.barLocked,
    "the settings checkbox changes the same bar lock state")
iSTSettings.barLocked = not iSTSettings.barLocked
iST:SettingsOpen()
assert(lockCheckbox:GetChecked() == iSTSettings.barLocked,
    "opening settings refreshes the bar lock control from saved state")
iST:SettingsClose()
local reminderTab, modeDropdown
for _, frame in ipairs(frames) do
    if type(frame.text) == "table" and frame.text.GetText and frame.text:GetText() == "Reminders" then reminderTab = frame end
    if frame.menu and frame.text:GetText() == "Back and forth" then modeDropdown = frame end
end
assert(reminderTab and modeDropdown, "the new reminder page and seal-mode dropdown are reachable")
modeDropdown.OnClick(modeDropdown)
assert(modeDropdown.menu:IsShown() and modeDropdown.menu.dismiss:IsShown(),
    "opening a dropdown enables its outside-click dismissal")
modeDropdown.menu.dismiss.OnClick(modeDropdown.menu.dismiss)
assert(not modeDropdown.menu:IsShown() and not modeDropdown.menu.dismiss:IsShown(),
    "clicking outside closes both the choices and the transparent blocker")
modeDropdown.OnEnter(modeDropdown)
modeDropdown.OnMouseDown(modeDropdown)
modeDropdown.OnLeave(modeDropdown)
modeDropdown.OnMouseUp(modeDropdown)
assert(modeDropdown.backdropColor[1] == 0.035, "releasing outside does not leave a button highlighted")
modeDropdown:Disable()
assert(modeDropdown.alpha == 0.45, "disabled settings controls stay visibly dimmed")
modeDropdown:Enable()
assert(modeDropdown.alpha == 1, "enabling a settings control restores its opacity")
modeDropdown.OnClick(modeDropdown)
modeDropdown.menu.buttons[2].OnClick()
assert(iSTSettings.sealStackMode == "FROM_ONLY" and modeDropdown.text:GetText() == "Always stack From", "the styled dropdown saves and refreshes the mode")
reminderTab.OnClick(reminderTab)
assert(iST.SettingsFrame.pageHeader.title:GetText() == iST.L.TabReminders
    and iST.SettingsFrame.pageHeader.subtitle:GetText() == iST.L.SettingsRemindersSummary,
    "navigation updates the fixed page header")
for _, button in ipairs(frames) do
    if button.parent == iST.SettingsFrame.sidebar and button.bg then
        assert(button.bg:IsShown() == (button == reminderTab),
            "only the selected navigation row has an amber background")
    end
end
local reminderContent
for _, frame in ipairs(frames) do
    if frame.Text and frame.Text:GetText() == "Enable Reminder" then reminderContent = frame.parent; break end
end
assert(reminderContent and reminderContent.parent.parent:IsShown(), "selecting Reminders opens its own scroll page")
local checkboxes, tracks, previews = {}, {}, {}
for _, frame in ipairs(frames) do
    if frame.parent == reminderContent then
        if frame.Text and frame.OnClick then checkboxes[frame.Text:GetText()] = checkboxes[frame.Text:GetText()] or {}; table.insert(checkboxes[frame.Text:GetText()], frame) end
        if frame.OnMouseWheel and frame:GetWidth() == 420 then tracks[#tracks + 1] = frame end
        if frame.text == "Preview / Move" then previews[#previews + 1] = frame end
    end
end
assert(#checkboxes["Enable Reminder"] == 2 and #tracks == 4 and #previews == 2, "both reminders have independent controls")
local circularThumb
for _, candidate in ipairs(frames) do
    if candidate.parent == tracks[1] and candidate.OnMouseDown and candidate:GetWidth() == 14 then
        circularThumb = candidate
        break
    end
end
assert(circularThumb and circularThumb.children[1].texture == "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    and circularThumb.children[2].texture == "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    "the slider keeps both original circular handle textures and its 14px size")
local oldCursorReader = GetCursorPosition
GetCursorPosition = function() return 420, 0 end
local beforeDrag = furySettings.warningSeconds
circularThumb.OnMouseDown(circularThumb)
tracks[1].OnUpdate(tracks[1])
assert(furySettings.warningSeconds > beforeDrag, "dragging the circular handle still updates the live setting")
circularThumb.OnMouseUp(circularThumb)
local afterDrag = furySettings.warningSeconds
GetCursorPosition = function() return 0, 0 end
tracks[1].OnUpdate(tracks[1])
assert(furySettings.warningSeconds == afterDrag, "releasing the handle stops changing the setting")
furySettings.warningSeconds = beforeDrag
GetCursorPosition = oldCursorReader
local reminderScroll = reminderContent.parent
reminderContent.parent.parent.OnMouseWheel(reminderContent.parent.parent, -1)
assert(reminderScroll:GetVerticalScroll() == 30 and reminderScroll.ScrollBar:GetWidth() == 8
    and reminderScroll.ScrollBar:GetThumbTexture().color[1] == 0.72,
    "wheel scrolling and the visible thin gold scrollbar remain usable")
for _, arrow in ipairs({ reminderScroll.ScrollBar:GetChildren() }) do
    if arrow:IsObjectType("Button") then
        assert(not arrow:IsShown() and arrow.alpha == 0 and arrow.mouseEnabled == false,
            "unnamed template arrows are hidden and cannot intercept clicks")
        arrow:Show()
        assert(not arrow:IsShown(), "template refreshes cannot restore the arrows")
    end
end
assert(reminderScroll.ScrollBar:GetThumbTexture():GetWidth() == 8,
    "removing arrow buttons preserves the scrollbar handle")
modeDropdown.OnClick(modeDropdown)
reminderTab.OnClick(reminderTab)
assert(not modeDropdown.menu:IsShown() and not modeDropdown.menu.dismiss:IsShown()
    and reminderScroll:GetVerticalScroll() == 30,
    "switching pages dismisses floating menus without resetting the page scroll")
local enableFury = checkboxes["Enable Reminder"][1]
enableFury:SetChecked(true)
enableFury.OnClick(enableFury)
assert(furySettings.enabled and fury:IsShown(), "the enable control applies the saved reminder state")
local dungeonOnly = assert(checkboxes["Dungeons / Raids Only"])[1]
local partyOnly = assert(checkboxes["Party / Raid Only"])[1]
dungeonOnly:SetChecked(true)
dungeonOnly.OnClick(dungeonOnly)
partyOnly:SetChecked(true)
partyOnly.OnClick(partyOnly)
assert(furySettings.dungeonsOnly and furySettings.partyOnly and not fury:IsShown(),
    "the Fury dungeon and party controls save separately and apply immediately")
dungeonOnly:SetChecked(false)
dungeonOnly.OnClick(dungeonOnly)
partyOnly:SetChecked(false)
partyOnly.OnClick(partyOnly)
assert(not furySettings.dungeonsOnly and not furySettings.partyOnly and fury:IsShown(),
    "turning both controls off restores the reminder")
local oldThreshold, oldSealThreshold, oldScale = furySettings.warningSeconds, sealSettings.warningSeconds, sealSettings.scale
tracks[1].OnMouseWheel(tracks[1], 1)
tracks[3].OnMouseWheel(tracks[3], 1)
tracks[4].OnMouseWheel(tracks[4], 1)
assert(furySettings.warningSeconds == oldThreshold + 5 and sealSettings.warningSeconds == oldSealThreshold + 1,
    "threshold controls change each reminder independently")
assert(math.abs(sealSettings.scale - oldScale - 0.05) < 0.0001 and seal:GetScale() == sealSettings.scale,
    "the scale control applies immediately")
previews[2].OnClick()
assert(seal:IsShown() and seal.strata == "DIALOG", "the preview button opens the correct movable reminder above settings")
previews[2].OnClick()
assert(not seal:IsShown(), "closing the preview preserves its disabled setting")
local sealCombatOnly = assert(checkboxes["Only Show In Combat"])[1]
assert(sealCombatOnly and not sealSettings.onlyInCombat, "the seal reminder has its own opt-in combat setting")
local sealIdle = assert(checkboxes["Hide After 5 Minutes Out of Combat"])[1]
local sealCapital = assert(checkboxes["Hide in Friendly Capital Cities"])[1]
assert(not sealSettings.hideAfterIdle and not sealSettings.hideInCapitals,
    "the new seal visibility filters are opt-in")
sealIdle:SetChecked(true)
sealIdle.OnClick(sealIdle)
sealCapital:SetChecked(true)
sealCapital.OnClick(sealCapital)
assert(sealSettings.hideAfterIdle and sealSettings.hideInCapitals,
    "the seal visibility controls save their options independently")
sealIdle:SetChecked(false)
sealIdle.OnClick(sealIdle)
sealCapital:SetChecked(false)
sealCapital.OnClick(sealCapital)
iST:ClearCurrentSeal()
local enableSeal = checkboxes["Enable Reminder"][2]
enableSeal:SetChecked(true)
enableSeal.OnClick(enableSeal)
assert(seal:IsShown(), "the seal reminder can still warn outside combat when the option is off")
sealCombatOnly:SetChecked(true)
sealCombatOnly.OnClick(sealCombatOnly)
assert(not seal:IsShown() and fury:IsShown(), "combat-only hides the seal reminder without affecting Fury")
inCombat = true
reminderEvent("PLAYER_REGEN_DISABLED")
assert(seal:IsShown(), "entering combat shows an eligible seal warning immediately")
inCombat = false
reminderEvent("PLAYER_REGEN_ENABLED")
assert(not seal:IsShown(), "leaving combat hides the seal warning immediately")
previews[2].OnClick()
assert(seal:IsShown(), "the movable seal preview remains available outside combat")
previews[2].OnClick()
assert(not seal:IsShown(), "closing the preview restores combat-only visibility")
sealCombatOnly:SetChecked(false)
sealCombatOnly.OnClick(sealCombatOnly)
assert(seal:IsShown(), "turning off combat-only restores normal reminder visibility")
print("PASS: settings construction, sidebar navigation, styled mode dropdown, independent reminder controls, live scale/threshold changes, and preview buttons")
iST:SettingsOpen()
modeDropdown.OnClick(modeDropdown)
iST:SettingsClose()
assert(not iST.SettingsFrame:IsShown() and not modeDropdown.menu:IsShown()
    and not modeDropdown.menu.dismiss:IsShown(), "closing settings also removes floating dropdowns and click blockers")
print("PASS: page headings, thin surfaces, active navigation, circular slider drag/release, scrollbar, outside clicks, and menu cleanup")

SlashCmdList = {}
string.trim = string.trim or function(value) return value:match("^%s*(.-)%s*$") end
iST:RegisterSlashCommands()
assert(iST.HitDebug and not iST.HitDebug:IsActive() and type(iST.HandleHitDebugCommand) == "function",
    "the live hit recorder loads idle and leaves combat events unregistered")
SlashCmdList.ISEALTWIST("hitdebug status")
assert(chatMessages[#chatMessages]:find("Hit capture: stopped", 1, true),
    "the live hit command is available without starting a capture")
local wasLocked = iSTSettings.barLocked
SlashCmdList.ISEALTWIST("lock")
assert(iSTSettings.barLocked ~= wasLocked and iST.SettingsFrame.barLockCheckbox:GetChecked() == iSTSettings.barLocked,
    "the slash lock command and settings checkbox remain in sync")
print("PASS: live hit recorder loads idle; hit and normal slash commands work")

-- Keep the cue responsive while delayed feedback checks individual swings.
playerDead, inCombat = false, true
iSTSettings.enabled, iSTSettings.wrathCue = true, "COUNTER"
iSTSettings.sealStackMode = "ALTERNATE"
iST:SetFakeUnsealedWrath(true)
iST:SetCurrentSeal(20375)
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(count() == 1 and bar.stackCountFrame:IsShown() and not bar.wrathCueFrame:IsShown(),
    "the selected counter uses the buff readout instead of the old cue text")
now = now + .5
event("UNIT_COMBAT", "target", "WOUND", "BLOCK_REDUCED", secret, 1)
assert(count() == 1, "delayed hit feedback cannot add the same stack twice")
now = now + 2.5
local beforeDodgeExpiry = iST.WrathTracker.expiresAt
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(count() == 2, "the next swing also updates immediately")
now = now + .5
event("UNIT_COMBAT", "target", "DODGE", "", secret, 1)
assert(count() == 1 and iST.WrathTracker.expiresAt == beforeDodgeExpiry,
    "a matched solo dodge restores the count and timer")
now = now + 2.5
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(count() == 2, "a swing remains visible while its target changes")
event("PLAYER_TARGET_CHANGED")
now = now + .5
event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
assert(count() == 2, "new-target feedback cannot add another stack")
now = now + 2.5
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
iST:SetFakeUnsealedWrath(false)
iST:SetFakeUnsealedWrath(true)
now = now + .5
event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
assert(count() == 0, "switching Fake mode cancels in-flight feedback")
spellNames[1866] = "Holy Strike"
iST:SetCurrentSeal(20375)
local sealDeadline = iST.State.SealExpiresAt
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
local swingDeadline = iST.State.NextSwingTime
assert(count() == 1, "a new swing updates the counter before delayed feedback")
now = now + .185
event("UNIT_SPELLCAST_SUCCEEDED", "player", "holy-strike-cast", 1866)
event("UNIT_COMBAT", "target", "WOUND", "", secret, 2)
assert(count() == 1 and iST.State.SealExpiresAt == sealDeadline
    and iST.State.NextSwingTime == swingDeadline,
    "Holy Strike neither adds a second stack nor resets the seal or swing timer")
now = now + .807
event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
assert(count() == 1 and bar.stackCountFrame:IsShown() and not bar.wrathCueFrame:IsShown(),
    "a later melee hit after Holy Strike keeps the buff readout selected")
spellNames[20271] = "Judgement"
now = now + 2.008
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
local judgementSwingDeadline = iST.State.NextSwingTime
assert(count() == 2, "the swing after Judgement is ready before feedback")
now = now + .2
event("UNIT_SPELLCAST_SUCCEEDED", "player", "judgement-cast", 20271)
event("UNIT_COMBAT", "target", "WOUND", "", secret, 2)
assert(count() == 2 and iST.State.SealExpiresAt == sealDeadline
    and iST.State.NextSwingTime == judgementSwingDeadline,
    "Judgement neither adds a second stack nor resets the seal or swing timer")
now = now + .3
event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
assert(count() == 2, "Judgement does not prevent the melee hit from being confirmed")
iST:SetCurrentSeal(20154)
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(count() == 0 and iST.State.TwistResultDuration > 0,
    "the release cue appears on the swing instead of waiting for target feedback")
playerDead = true
event("PLAYER_DEAD")
assert(#iST.WrathHitMatcher.pending == 0, "death cancels pending swing feedback")
playerDead, grouped = false, true
iST:SetFakeUnsealedWrath(true)
iST:SetCurrentSeal(20375)
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(count() == 1, "a group swing remains responsive")
now = now + .5
event("UNIT_COMBAT", "target", "MISS", "", secret, 1)
assert(count() == 1, "unattributed group feedback cannot erase a player's stack")
grouped = false
iST:CancelPendingWrathHits()
iST.WrathTracker:Reset()
iST:SetCurrentSeal(20375)
event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(count() == 1 and iST.WrathTracker.seal == "Seal of Command")
iST:SetCurrentSeal(20154)
now = now + .5
event("UNIT_COMBAT", "target", "WOUND", "", secret, 1)
assert(count() == 1 and iST.WrathTracker.seal == "Seal of Command",
    "feedback keeps the seal captured at swing time after the player switches")
print("PASS: real Fake-mode swing/feedback dispatch, cue update, missed-hit deadline, Holy Strike/Judgement overlap without timer resets, target changes, mode switches, and death")
