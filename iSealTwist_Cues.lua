local _, iST = ...
local L = iST.L or {}

local function CopyColor(color)
    return { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
end

local function CombatLocked()
    if type(InCombatLockdown) ~= "function" then return false end
    local locked = InCombatLockdown()
    return (issecretvalue and issecretvalue(locked)) or locked == true
end

local nextNativeContainerLoad = 0
local function NativeContainerReady()
    if C_AuraContainerUtil then return true end
    local now = GetTime()
    if now >= nextNativeContainerLoad and C_AddOns and C_AddOns.LoadAddOn then
        nextNativeContainerLoad = now + 5
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    return C_AuraContainerUtil ~= nil
end
iST.EnsureNativeAuraContainer = NativeContainerReady

function iST:AddEchoPresenceGroup(container, anchor, width)
    local spellIDs = {}
    for _, spell in ipairs(self.WrathEchoSpells) do
        spellIDs[spell.id] = true
    end
    container:SetPoint("TOPLEFT", anchor, "TOP", -width / 2, 0)
    container:AddAuraGroup("activeEcho", "HELPFUL", {
        candidateFilters = { includeSpellIDs = spellIDs },
        maxFrameCount = 1,
        layout = { elementWidth = width + 1, elementHeight = 1 },
        initializeFrame = function(button)
            button:SetSize(width + 1, 1)
            button:EnableMouse(false)
        end,
    })
end

function iST:RequestWrathDisplayUpdate()
    if self.State.WrathDisplayPending then return end
    self.State.WrathDisplayPending = true
    C_Timer.After(0, function()
        self.State.WrathDisplayPending = nil
        self:UpdateWrathDisplay()
    end)
end

-- Each palette runs from no stacks to three stacks.
local COLOR_SCHEMES = {
    GOLD = {
        { r = 0.50, g = 0.45, b = 0.34, a = 1 },
        { r = 1, g = 0.52, b = 0.12, a = 1 },
        { r = 1, g = 0.68, b = 0.17, a = 1 },
        { r = 1, g = 0.78, b = 0.24, a = 1 },
    },
    TRAFFIC = {
        { r = 0.95, g = 0.18, b = 0.18, a = 1 },
        { r = 1, g = 0.45, b = 0.10, a = 1 },
        { r = 1, g = 0.85, b = 0.15, a = 1 },
        { r = 0.20, g = 1, b = 0.30, a = 1 },
    },
    BLUE = {
        { r = 0.35, g = 0.40, b = 0.52, a = 1 },
        { r = 0.25, g = 0.50, b = 0.90, a = 1 },
        { r = 0.20, g = 0.75, b = 1, a = 1 },
        { r = 0.40, g = 1, b = 0.90, a = 1 },
    },
}

function iST:InitializeWrathColors(legacyColor)
    if not COLOR_SCHEMES[iSTSettings.wrathColorScheme] and iSTSettings.wrathColorScheme ~= "CUSTOM" then
        iSTSettings.wrathColorScheme = "GOLD"
    end
    for stage = 0, 3 do
        local key = "wrathColor" .. stage
        local color = iSTSettings[key]
        if type(color) ~= "table" or type(color.r) ~= "number"
            or type(color.g) ~= "number" or type(color.b) ~= "number" then
            color = self.SettingsDefault[key]
        end
        iSTSettings[key] = CopyColor(color)
    end
    -- Older settings had one cue color. Keep a custom choice for every stage,
    -- but let the old default gold use the new palette.
    if type(legacyColor) == "table" and type(legacyColor.r) == "number"
        and type(legacyColor.g) == "number" and type(legacyColor.b) == "number"
        and (legacyColor.r ~= 1 or legacyColor.g ~= 0.78 or legacyColor.b ~= 0.24
            or (legacyColor.a or 1) ~= 1) then
        for stage = 0, 3 do iSTSettings["wrathColor" .. stage] = CopyColor(legacyColor) end
        iSTSettings.wrathColorScheme = "CUSTOM"
    end
end

function iST:GetWrathCueColor(stage)
    stage = math.max(0, math.min(3, math.floor(tonumber(stage) or 0)))
    local scheme = COLOR_SCHEMES[iSTSettings.wrathColorScheme]
    return scheme and scheme[stage + 1] or iSTSettings["wrathColor" .. stage]
end

function iST:ApplyStackCounterColor()
    local bar = self.BarFrame
    if not bar then return end
    if CombatLocked() then
        self.State.PendingStackCounterColor = true
        return
    end
    local baseColor = self:GetWrathCueColor(0)
    local function ColorText(fontString, color)
        if fontString then fontString:SetTextColor(color.r, color.g, color.b, color.a or 1) end
    end
    ColorText(bar.stackCountValue, baseColor)
    ColorText(bar.stackCountTotal, baseColor)
    for _, row in ipairs(bar.stackManagedRows or {}) do
        -- WoW colors the live digit through the native stack formatter.
        ColorText(row.count, { r = 1, g = 1, b = 1, a = 1 })
    end
    self.State.PendingStackCounterColor = nil
end

function iST:SetWrathColorScheme(scheme)
    if not COLOR_SCHEMES[scheme] and scheme ~= "CUSTOM" then return end
    iSTSettings.wrathColorScheme = scheme
    self:ApplyStackStageFormatter()
    self:ApplyStackCounterColor()
    self:UpdateWrathDisplay()
end

function iST:SetWrathStageColor(stage, color)
    if type(stage) ~= "number" or stage < 0 or stage > 3 or stage ~= math.floor(stage) then return end
    -- Editing one preset color should leave the other three looking the same.
    if iSTSettings.wrathColorScheme ~= "CUSTOM" then
        for index = 0, 3 do
            iSTSettings["wrathColor" .. index] = CopyColor(self:GetWrathCueColor(index))
        end
        iSTSettings.wrathColorScheme = "CUSTOM"
    end
    iSTSettings["wrathColor" .. stage] = CopyColor(color)
    self:ApplyStackStageFormatter()
    self:ApplyStackCounterColor()
    self:UpdateWrathDisplay()
end

function iST:ResetWrathColors()
    for stage = 0, 3 do
        local key = "wrathColor" .. stage
        iSTSettings[key] = CopyColor(self.SettingsDefault[key])
    end
    self:SetWrathColorScheme("GOLD")
end

function iST:CreateWrathCue(bar)
    if bar.stackCountFrame then return end

    -- Keep the buff counter outside the bar so the bar can fade on its own.
    local stackFrame = CreateFrame("Frame", nil, UIParent)
    if iSTSettings.stackCountPoint then
        local point = iSTSettings.stackCountPoint
        stackFrame:SetPoint("CENTER", UIParent, "CENTER", point[1], point[2])
    else
        stackFrame:SetPoint("BOTTOM", bar, "TOP", 0, self:GetAttachedStackCounterOffset())
    end
    stackFrame:SetSize(104, 26)
    stackFrame:SetFrameLevel(bar:GetFrameLevel() + 6)
    stackFrame:SetMovable(true)
    stackFrame:EnableMouse(false)
    stackFrame:RegisterForDrag("LeftButton")
    stackFrame:SetScript("OnDragStart", function(self)
        if iST.State.EditMode and not iSTSettings.barLocked and not CombatLocked() then
            self.isDragging = true
            iST:BeginMoveGuides(self)
        end
    end)
    stackFrame:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        iST:EndMoveGuides(self)
        self.isDragging = nil
        local x, y = self:GetCenter()
        local rootX, rootY = UIParent:GetCenter()
        if x and y and rootX and rootY then
            iSTSettings.stackCountPoint = { x - rootX, y - rootY }
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", iSTSettings.stackCountPoint[1],
                iSTSettings.stackCountPoint[2])
            iST:LayoutStackPips()
        end
    end)
    stackFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and iST:CanResetMovePosition(self) then
            iST:ResetStackCountPosition()
        end
    end)
    stackFrame:Hide()
    bar.stackCountFrame = stackFrame

    local stackValue = stackFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackValue:SetPoint("RIGHT", stackFrame, "CENTER", -4, 0)
    stackValue:SetText("?")
    stackValue:SetShadowOffset(1, -1)
    stackValue:SetShadowColor(0, 0, 0, 1)
    bar.stackCountValue = stackValue

    local stackTotal = stackFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackTotal:SetPoint("LEFT", stackFrame, "CENTER", 0, 0)
    stackTotal:SetText("/ 3")
    stackTotal:SetShadowOffset(1, -1)
    stackTotal:SetShadowColor(0, 0, 0, 1)
    bar.stackCountTotal = stackTotal

    bar.stackSealIcons = {}
    for seal, spellID in pairs(self.SEAL_SPELL_IDS) do
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and texture and not (issecretvalue and issecretvalue(texture)) then
            bar.stackSealIcons[seal] = texture
        end
    end

    self:CreateSwordImageCue(bar)
    bar.wrathCircles = self:CreateStackBubbles(bar, nil, 18, 9)
    bar.wrathCircles:SetPoint("BOTTOM", bar, "TOP", 0, self:GetStackPipYOffset())
    bar.wrathCircles:SetFrameLevel(bar:GetFrameLevel() + 4)
    bar.stackSealIconStrip = self:CreateStackSealIcons(bar, 20, 5)
    bar.stackSealIconStrip:SetPoint("BOTTOM", bar, "TOP", 0, self:GetStackPipYOffset())
    bar.stackSealIconStrip:SetFrameLevel(bar:GetFrameLevel() + 5)
    bar.stackSealIconStrip:Hide()
    self:CreatePlayerWrathFrame()
    self:ApplyWrathCircleSize()
    self:ApplyStackCounterColor()
end

function iST:ResetStackCountPosition()
    iSTSettings.stackCountPoint = nil
    self:AnchorAttachedIndicators()
    self:LayoutStackPips()
end

function iST:LayoutStackPips()
    local bar = self.BarFrame
    if not bar or CombatLocked() then return end
    -- Match the settings preview: pips sit just above the bar, with the
    -- attached counter above them. A separately moved counter keeps its spot.
    local offset = self:GetStackPipYOffset()
    local counterOffset = self:GetAttachedStackCounterOffset()
    if bar.stackPipCounterOffset ~= counterOffset then
        self:AnchorAttachedIndicators()
        bar.stackPipCounterOffset = counterOffset
    end
    local function Place(frame)
        if not frame then return end
        local x = self:GetStackPipCenterOffset(frame)
        if frame.pipOffset ~= offset or frame.pipXOffset ~= x then
            local ok = pcall(function()
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", bar, "TOP", x, offset)
            end)
            if ok then frame.pipOffset, frame.pipXOffset = offset, x end
        end
    end
    Place(bar.wrathCircles)
    Place(bar.stackSealIconStrip)
    for _, row in ipairs(bar.nativeStageMainRows or {}) do Place(row.circles) end
    if bar.nativeSealIconsMain then
        for _, row in ipairs(bar.nativeSealIconsMain.iconRows or {}) do Place(row.strip) end
    end
    if self.PlayerWrathFrame then
        for _, row in ipairs(bar.nativeStagePlayerRows or {}) do self:LayoutPlayerPipRow(row.bubbles) end
        if bar.nativeSealIconsPlayer then
            for _, row in ipairs(bar.nativeSealIconsPlayer.iconRows or {}) do self:LayoutPlayerPipRow(row.strip) end
        end
    end
end

function iST:ApplyWrathCircleSize()
    local bar = self.BarFrame
    if not bar then return end
    if CombatLocked() then
        self.State.PendingWrathCircleSize = true
        return
    end
    local size = math.max(10, math.min(50, tonumber(iSTSettings.wrathCircleSize) or 18))
    local playerSize = self:GetPlayerPipSize()
    -- Resize around each pip's fixed bottom anchor. Scaling the whole frame
    -- also scales its anchor offset and makes the pips climb above the bar.
    self:ResizeStackBubbles(bar.wrathCircles, size)
    self:ResizeStackSealIcons(bar.stackSealIconStrip, size)
    for _, row in ipairs(bar.nativeStageMainRows or {}) do
        self:ResizeStackBubbles(row.circles, size)
    end
    if bar.nativeSealIconsMain then
        for _, row in ipairs(bar.nativeSealIconsMain.iconRows or {}) do
            self:ResizeStackSealIcons(row.strip, size)
        end
    end
    if self.PlayerWrathFrame then
        self.PlayerWrathFrame:SetHeight(math.max(28, playerSize + 12))
        self.PlayerWrathFrame.layoutWidth = nil
    end
    self:LayoutStackPips()
    self.State.PendingWrathCircleSize = nil
end

local function StackSpellFilter(slot)
    return { includeSpellIDs = { [slot.spellID] = true } }
end

local function StackFilterKey()
    return "echo"
end

local ECHO_RING_RED = iST.AddonPath .. "Images\\Cues\\Echo_Ring_Red.tga"
local ECHO_RING_BLUE = iST.AddonPath .. "Images\\Cues\\Echo_Ring.tga"
local ECHO_RING_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function EchoSecondsFormatter(color)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local normal = string.format("|c%02x%02x%02x%02x%%.0f|r",
        math.floor((color.a or 1) * 255 + 0.5), math.floor(color.r * 255 + 0.5),
        math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5))
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "|cffff3028%.0f|r" },
        { threshold = 5.01, format = normal },
    }) then return formatter end
end

local function EchoUrgentRingFormatter(size)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "|T" .. ECHO_RING_RED .. ":" .. size .. ":" .. size .. "|t" },
        { threshold = 5.01, format = "" },
    }) then return formatter end
end

local SEAL_TIMER_TEXT = { r = 1, g = 1, b = 1, a = 1 }
local PLAYER_SEAL_FILTER = "HELPFUL|PLAYER"

local function SealTimerSpellIDs()
    local ids = {}
    for id in pairs(iST.SEALS) do ids[id] = true end
    return ids
end

local function ShowSealBuffCountdown(artwork, shown)
    if artwork.timerShown == shown then return end
    artwork.cooldown:SetAlpha(shown and 1 or 0)
    artwork.overlay:SetShown(shown)
    local color = shown and 0.28
    artwork.ring:SetVertexColor(color or 1, color or 0.59, color or 0.09, 0.95)
    artwork.timerShown = shown
end

local function CreateSealBuffContainer(parent, spellIDs, initialize)
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:SetAllPoints(parent)
    container:EnableMouse(false)
    container:SetUnit("player")
    container:AddAuraSlot("seal", PLAYER_SEAL_FILTER, {
        candidateFilters = { includeSpellIDs = spellIDs },
        initializeFrame = function(button)
            button:SetAllPoints(parent)
            button:EnableMouse(false)
            initialize(button)
        end,
    })
    container:SetEnabled(true)
    return container
end

local function BuildNativeSealTimer(layer)
    local native = { layer = layer, spellIDs = SealTimerSpellIDs() }
    -- Match any of our Seal ranks in one slot. WoW supplies the icon and
    -- duration directly, including when the aura is protected in combat.
    native.container = CreateSealBuffContainer(layer, native.spellIDs, function(button)
        assert(type(button.SetIcon) == "function" and type(button.SetDurationCooldown) == "function"
            and type(button.SetDurationText) == "function", "native Seal timer bindings are unavailable")
        local artwork = iST:CreateSealTimerArtwork(button)
        iST:LayoutSealTimerArtwork(artwork)
        button:SetIcon(artwork.icon)
        button:SetDurationCooldown(artwork.cooldown)
        local formatter = EchoSecondsFormatter(SEAL_TIMER_TEXT)
        button:SetDurationText(artwork.text, formatter and { textFormatter = formatter } or {})
        artwork.cooldown:Show()
        artwork.text:Show()
        ShowSealBuffCountdown(artwork, iSTSettings.showSealTimer)
        native.artwork = artwork
    end)
    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
        local iconSize = math.max(16, iSTSettings.sealIconSize or iSTSettings.barHeight or 25)
        native.urgent = CreateSealBuffContainer(layer, native.spellIDs, function(button)
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetAllPoints(button)
            text:SetJustifyH("CENTER")
            text:SetJustifyV("MIDDLE")
            local formatter = EchoUrgentRingFormatter(iconSize + 8)
            if formatter then button:SetDurationText(text, { textFormatter = formatter }) end
            native.urgentButton, native.urgentText, native.urgentSize = button, text, iconSize
        end)
        native.urgent:SetFrameLevel(native.container:GetFrameLevel() + 5)
    end
    return native
end

function iST:UpdateNativeSealTimer()
    local bar = self.BarFrame
    if not bar or not bar.sealIconFrame then return end
    local native = bar.nativeSealTimer
    if CombatLocked() or not iSTSettings.showSealIcon or not self:ShouldShowBar() then return native end
    if not native then
        if bar.nativeSealTimerFailed or not NativeContainerReady() then return end
        local layer = CreateFrame("Frame", nil, bar.sealIconFrame)
        layer:SetAllPoints(bar.sealIconFrame)
        layer:EnableMouse(false)
        layer:Hide()
        local ok, result = pcall(BuildNativeSealTimer, layer)
        if not ok then
            bar.nativeSealTimerFailed = true
            self:DebugMsg("Seal buff timer is unavailable: " .. tostring(result), 2)
            return
        end
        native = result
        bar.nativeSealTimer = native
    end
    local id = self.State.CurrentSealID
    if id and not native.spellIDs[id] then
        local ids = SealTimerSpellIDs()
        local filter = { includeSpellIDs = ids }
        if pcall(native.container.SetAuraSlotCandidateFilters, native.container, "seal", filter) then
            native.spellIDs = ids
            if native.urgent then pcall(native.urgent.SetAuraSlotCandidateFilters, native.urgent, "seal", filter) end
        end
    end
    if native.artwork then
        pcall(self.LayoutSealTimerArtwork, self, native.artwork)
        pcall(ShowSealBuffCountdown, native.artwork, iSTSettings.showSealTimer)
    end
    if native.urgent then
        if native.urgentShown ~= iSTSettings.showSealTimer
            and pcall(native.urgent.SetShown, native.urgent, iSTSettings.showSealTimer) then
            native.urgentShown = iSTSettings.showSealTimer
        end
        local size = native.artwork and native.artwork.iconSize
        if size and native.urgentButton and size ~= native.urgentSize then
            local formatter = EchoUrgentRingFormatter(size + 8)
            if formatter and pcall(native.urgentButton.SetDurationText, native.urgentButton,
                native.urgentText, { textFormatter = formatter }) then native.urgentSize = size end
        end
    end
    return native
end

function iST:UpdateEchoTimerDisplay()
    local bar = self.BarFrame
    if not bar then return end
    -- Build the native buff icon before combat even for combat-only bars.
    -- The parent bar controls visibility; an Echo button appears only while
    -- its matching aura exists.
    local wanted = iSTSettings.showEchoTimer and (self:IsWrathTrackingEnabled() or self.State.EditMode)
    local host = bar.echoTimerFrame
    if not wanted then
        if host and not CombatLocked() then pcall(host.Hide, host) end
        return
    end
    if CombatLocked() then return end
    if not NativeContainerReady() or bar.echoTimerFailed then return end
    if not host then
        local ok, result = pcall(function()
            local frame = CreateFrame("Frame", nil, bar)
            frame:SetSize(31, 31)
            if iSTSettings.echoTimerPoint then
                local point = iSTSettings.echoTimerPoint
                frame:SetPoint("CENTER", UIParent, "CENTER", point[1], point[2])
            else
                frame:SetPoint("LEFT", bar, "RIGHT", bar.wrathEchoOffset or 7, 0)
            end
            frame:SetFrameLevel(bar:GetFrameLevel() + 6)
            frame:SetMovable(true)
            frame:EnableMouse(false)
            frame:RegisterForDrag("LeftButton")
            frame:SetScript("OnDragStart", function(self)
                if iST.State.EditMode and not iSTSettings.barLocked and not CombatLocked() then
                    self.isDragging = true
                    iST:BeginMoveGuides(self)
                end
            end)
            frame:SetScript("OnDragStop", function(self)
                if not self.isDragging then return end
                iST:EndMoveGuides(self)
                self.isDragging = nil
                local x, y = self:GetCenter()
                local rootX, rootY = UIParent:GetCenter()
                local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
                if x and y and rootX and rootY and scale ~= 0 then
                    iSTSettings.echoTimerPoint = { (x * scale - rootX) / scale,
                        (y * scale - rootY) / scale }
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", UIParent, "CENTER",
                        iSTSettings.echoTimerPoint[1], iSTSettings.echoTimerPoint[2])
                end
            end)
            frame:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and iST:CanResetMovePosition(self) then
                    iST:ResetEchoTimerPosition()
                end
            end)
            local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
            container:SetAllPoints(frame)
            container:EnableMouse(false)
            container:SetUnit("player")
            frame.container = container
            frame.slots = {}
            frame.texts = {}
            frame.rows = {}
            for _, spell in ipairs(self.WrathEchoSpells) do
                frame.slots[#frame.slots + 1] = {
                    key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal,
                }
            end
            for _, slot in ipairs(frame.slots) do
                local slotInfo = slot
                container:AddAuraSlot(slotInfo.key, "HELPFUL", {
                    candidateFilters = StackSpellFilter(slotInfo),
                    initializeFrame = function(button)
                        button:SetAllPoints(frame)
                        button:EnableMouse(false)
                        local shadow = button:CreateTexture(nil, "BACKGROUND")
                        shadow:SetTexture(ECHO_RING_TEXTURE)
                        shadow:SetPoint("CENTER", button, "CENTER", 1, -1)
                        shadow:SetVertexColor(0, 0, 0, 0.75)
                        local ring = button:CreateTexture(nil, "BORDER")
                        ring:SetTexture(ECHO_RING_TEXTURE)
                        ring:SetPoint("CENTER", button, "CENTER")
                        ring:SetVertexColor(0.08, 0.30, 0.46, 0.95)
                        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                        cooldown:SetAllPoints(ring)
                        cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
                        cooldown:SetSwipeTexture(ECHO_RING_TEXTURE)
                        cooldown:SetSwipeColor(0.20, 0.72, 1, 0.95)
                        cooldown:SetDrawSwipe(true)
                        cooldown:SetDrawEdge(false)
                        cooldown:SetDrawBling(false)
                        cooldown:SetUseCircularEdge(true)
                        cooldown:SetReverse(false)
                        cooldown:SetHideCountdownNumbers(true)
                        cooldown.noCooldownCount = true
                        cooldown:EnableMouse(false)
                        if type(button.SetDurationCooldown) == "function" then
                            button:SetDurationCooldown(cooldown)
                        end
                        local portrait = CreateFrame("Frame", nil, button)
                        portrait:SetAllPoints(button)
                        portrait:SetFrameLevel(cooldown:GetFrameLevel() + 1)
                        portrait:EnableMouse(false)
                        local icon = portrait:CreateTexture(nil, "ARTWORK")
                        icon:SetPoint("CENTER", button, "CENTER")
                        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                        if icon.AddMaskTexture and portrait.CreateMaskTexture then
                            local mask = portrait:CreateMaskTexture()
                            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                            mask:SetAllPoints(icon)
                            icon:AddMaskTexture(mask)
                        end
                        if type(button.SetIcon) == "function" then button:SetIcon(icon)
                        else icon:SetTexture(bar.stackSealIcons[slotInfo.seal]) end
                        local textLayer = CreateFrame("Frame", nil, button)
                        textLayer:SetAllPoints(icon)
                        textLayer:SetFrameLevel(portrait:GetFrameLevel() + 1)
                        textLayer:EnableMouse(false)
                        local label = textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        label:SetPoint("BOTTOM", button, "TOP", 0, 1)
                        label:SetText(L["EchoLabel"])
                        label:SetTextColor(0.35, 0.82, 1, 1)
                        local time = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        time:SetPoint("CENTER", textLayer, "CENTER")
                        time:SetJustifyH("CENTER")
                        time:SetJustifyV("MIDDLE")
                        time:SetWordWrap(false)
                        time:SetNonSpaceWrap(false)
                        time:SetMaxLines(1)
                        time:SetFont(self:GetBarFontPath(), 12, "THICKOUTLINE")
                        local color = iSTSettings.echoTimerTextColor
                        time:SetTextColor(color.r, color.g, color.b, color.a or 1)
                        time:SetShadowOffset(0, 0)
                        time:SetShadowColor(0, 0, 0, 0)
                        assert(type(button.SetDurationText) == "function", "native aura duration text is unavailable")
                        local secondsFormatter = EchoSecondsFormatter(color)
                        button:SetDurationText(time, secondsFormatter and { textFormatter = secondsFormatter } or {})
                        frame.texts[#frame.texts + 1] = time
                        frame.rows[#frame.rows + 1] = {
                            button = button, icon = icon, ring = ring, shadow = shadow,
                            cooldown = cooldown, text = time, label = label,
                        }
                    end,
                })
            end
            container:SetEnabled(true)
            local urgentContainer = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
            urgentContainer:SetAllPoints(frame)
            urgentContainer:EnableMouse(false)
            urgentContainer:SetFrameLevel(container:GetFrameLevel() + 3)
            urgentContainer:SetUnit("player")
            frame.urgentContainer = urgentContainer
            frame.urgentRows = {}
            for _, slot in ipairs(frame.slots) do
                local slotInfo = slot
                urgentContainer:AddAuraSlot(slotInfo.key, "HELPFUL", {
                    candidateFilters = StackSpellFilter(slotInfo),
                    initializeFrame = function(button)
                        button:SetAllPoints(frame)
                        button:EnableMouse(false)
                        local redRing = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        redRing:SetAllPoints(button)
                        redRing:SetJustifyH("CENTER")
                        redRing:SetJustifyV("MIDDLE")
                        redRing:SetTextColor(1, 1, 1, 1)
                        assert(type(button.SetDurationText) == "function", "native aura duration text is unavailable")
                        local urgentFormatter = EchoUrgentRingFormatter(33)
                        if urgentFormatter then
                            button:SetDurationText(redRing, { textFormatter = urgentFormatter })
                        end
                        frame.urgentRows[#frame.urgentRows + 1] = { button = button, text = redRing }
                    end,
                })
            end
            urgentContainer:SetEnabled(true)
            local editPreview = CreateFrame("Frame", nil, frame)
            editPreview:SetAllPoints(frame)
            editPreview:SetFrameLevel(urgentContainer:GetFrameLevel() + 2)
            editPreview:EnableMouse(false)
            local editRing = editPreview:CreateTexture(nil, "BORDER")
            editRing:SetPoint("CENTER", editPreview, "CENTER")
            editRing:SetTexture(ECHO_RING_TEXTURE)
            editRing:SetVertexColor(0.20, 0.72, 1, 1)
            local editIcon = editPreview:CreateTexture(nil, "ARTWORK")
            editIcon:SetPoint("CENTER", editPreview, "CENTER")
            editIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local editMask = editPreview:CreateMaskTexture()
            editMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            editMask:SetAllPoints(editIcon)
            editIcon:AddMaskTexture(editMask)
            local editTime = editPreview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            editTime:SetPoint("CENTER", editPreview, "CENTER")
            editTime:SetText("12")
            local editLabel = editPreview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            editLabel:SetPoint("BOTTOM", editPreview, "TOP", 0, 1)
            editLabel:SetText(L["EchoLabel"])
            editLabel:SetTextColor(0.35, 0.82, 1, 1)
            editPreview.ring, editPreview.icon = editRing, editIcon
            editPreview.time, editPreview.label = editTime, editLabel
            editPreview:Hide()
            frame.editPreview = editPreview
            return frame
        end)
        if not ok then
            bar.echoTimerFailed = true
            self:DebugMsg("Echo timer is unavailable: " .. tostring(result), 2)
            return
        end
        host = result
        bar.echoTimerFrame = host
        host.filterKey = StackFilterKey()
    end
    local filterKey = StackFilterKey()
    if host.filterKey ~= filterKey then
        local updated = true
        for _, slot in ipairs(host.slots) do
            if not pcall(host.container.SetAuraSlotCandidateFilters,
                host.container, slot.key, StackSpellFilter(slot)) then updated = false end
            if not pcall(host.urgentContainer.SetAuraSlotCandidateFilters,
                host.urgentContainer, slot.key, StackSpellFilter(slot)) then updated = false end
        end
        if updated then host.filterKey = filterKey end
    end
    local iconSize = math.max(16, math.min(64, iSTSettings.sealIconSize or 25))
    if host.iconSize ~= iconSize or host.fontPath ~= self:GetBarFontPath() then
        host:SetSize(iconSize + 6, iconSize + 6)
        local fontPath = self:GetBarFontPath()
        local textSize = math.max(8, math.floor(iconSize * 0.46 + 0.5))
        local opticalOffset = textSize * 0.1
        for _, row in ipairs(host.rows) do
            row.shadow:SetSize(iconSize + 10, iconSize + 10)
            row.ring:SetSize(iconSize + 8, iconSize + 8)
            row.icon:SetSize(iconSize, iconSize)
            row.text:ClearAllPoints()
            row.text:SetSize(iconSize, iconSize)
            row.text:SetPoint("CENTER", row.icon, "CENTER", opticalOffset - 1, -opticalOffset)
            row.text:SetFont(fontPath, textSize, "THICKOUTLINE")
            row.label:SetFont(fontPath, math.max(8, math.floor(iconSize * 0.23 + 0.5)), "OUTLINE")
        end
        host.editPreview.ring:SetSize(iconSize + 8, iconSize + 8)
        host.editPreview.icon:SetSize(iconSize, iconSize)
        host.editPreview.time:ClearAllPoints()
        host.editPreview.time:SetSize(iconSize, iconSize)
        host.editPreview.time:SetPoint("CENTER", host.editPreview.icon, "CENTER",
            opticalOffset - 1, -opticalOffset)
        host.editPreview.time:SetFont(fontPath, textSize, "THICKOUTLINE")
        host.editPreview.label:SetFont(fontPath,
            math.max(8, math.floor(iconSize * 0.23 + 0.5)), "OUTLINE")
        local urgentFormatter = EchoUrgentRingFormatter(iconSize + 8)
        if urgentFormatter then
            for _, row in ipairs(host.urgentRows) do
                pcall(row.button.SetDurationText, row.button, row.text,
                    { textFormatter = urgentFormatter })
            end
        end
        host.iconSize, host.fontPath = iconSize, fontPath
    end
    if not CombatLocked() then
        local color = iSTSettings.echoTimerTextColor
        local colorKey = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
        if host.textColorKey ~= colorKey then
            local updated = true
            local formatter = EchoSecondsFormatter(color)
            for _, row in ipairs(host.rows) do
                if not formatter or not pcall(row.button.SetDurationText, row.button, row.text,
                    { textFormatter = formatter }) then updated = false end
            end
            if updated then host.textColorKey = colorKey end
        end
        host.editPreview.time:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
    if self.State.EditMode then
        local source = iSTSettings.twistFromSeal
        host.editPreview.icon:SetTexture(bar.stackSealIcons[source])
        host.editPreview:Show()
    else
        host.editPreview:Hide()
    end
    pcall(host.Show, host)
end

local function SizeNameplatePipRow(row, size)
    local step = size + 4
    row.progress:SetSize(step * 3, size)
    for index = 1, 3 do
        local x = (index - 1) * step
        local glow = row.glows[index]
        glow:SetSize(size + 4, size + 4)
        glow:ClearAllPoints()
        glow:SetPoint("LEFT", row.progress, "LEFT", x, 0)
        local dot = row.dots[index]
        dot:SetSize(math.max(7, size - 3), math.max(7, size - 3))
        dot:ClearAllPoints()
        dot:SetPoint("LEFT", row.progress, "LEFT", x + 3.5, 0)
        local sealPip = row.sealPips[index]
        sealPip:SetSize(size, size)
        sealPip:ClearAllPoints()
        sealPip:SetPoint("LEFT", row.progress, "LEFT", x + 2, 0)
    end
end

function iST:UpdateNameplateEchoDisplay()
    local wanted = iSTSettings.showNameplateEcho and self:IsWrathTrackingEnabled()
        and self:ShouldShowAuxiliaryCues() and not self.State.TestMode
    local frame = self.NameplateEchoFrame
    if not wanted or not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        if frame then pcall(frame.Hide, frame) end
        return
    end
    if not frame and not CombatLocked() and NativeContainerReady() and not self.State.NameplateEchoFailed then
        local ok, result = pcall(function()
            local host = CreateFrame("Frame", nil, UIParent)
            host:SetSize(92, 26)
            host:SetFrameStrata("HIGH")
            host:EnableMouse(false)
            local container = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")
            container:SetAllPoints(host)
            container:EnableMouse(false)
            container:SetUnit("player")
            host.container, host.slots = container, {}
            host.glows, host.dots, host.sealPips, host.pipRows = {}, {}, {}, {}
            local sealsIcon = C_Spell.GetSpellTexture(1323522)
                or "Interface\\Icons\\Ability_Paladin_EmpoweredSealsTruth"
            for _, spell in ipairs(self.WrathEchoSpells) do
                host.slots[#host.slots + 1] = {
                    key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal,
                }
            end
            for _, slot in ipairs(host.slots) do
                local slotInfo = slot
                container:AddAuraSlot(slotInfo.key, "HELPFUL", {
                    candidateFilters = StackSpellFilter(slotInfo),
                    initializeFrame = function(button)
                        button:SetAllPoints(host)
                        button:EnableMouse(false)
                        local icon = button:CreateTexture(nil, "ARTWORK")
                        icon:SetSize(18, 18)
                        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -4)
                        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        icon:SetTexture(sealsIcon)
                        local ringLayer = CreateFrame("Frame", nil, button)
                        ringLayer:SetAllPoints(button)
                        ringLayer:SetFrameLevel(button:GetFrameLevel() + 2)
                        ringLayer:EnableMouse(false)
                        local echoRing = ringLayer:CreateTexture(nil, "ARTWORK")
                        echoRing:SetTexture(ECHO_RING_BLUE)
                        echoRing:SetSize(26, 26)
                        echoRing:SetPoint("CENTER", icon, "CENTER")
                        echoRing:SetVertexColor(0.08, 0.30, 0.46, 0.95)
                        local cooldown = CreateFrame("Cooldown", nil, ringLayer, "CooldownFrameTemplate")
                        cooldown:SetAllPoints(echoRing)
                        cooldown:SetFrameLevel(ringLayer:GetFrameLevel() + 1)
                        cooldown:SetSwipeTexture(ECHO_RING_BLUE)
                        cooldown:SetSwipeColor(0.20, 0.72, 1, 0.95)
                        cooldown:SetDrawSwipe(true)
                        cooldown:SetDrawEdge(false)
                        cooldown:SetDrawBling(false)
                        cooldown:SetUseCircularEdge(true)
                        cooldown:SetReverse(false)
                        cooldown:SetHideCountdownNumbers(true)
                        cooldown.noCooldownCount = true
                        cooldown:EnableMouse(false)
                        assert(type(button.SetDurationCooldown) == "function", "native Echo duration ring is unavailable")
                        button:SetDurationCooldown(cooldown)
                        local progress = CreateFrame("StatusBar", nil, button)
                        progress:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                        progress:SetSize(66, 18)
                        progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                        progress:SetAlpha(0)
                        local clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
                        clip:SetClipsChildren(true)
                        clip:EnableMouse(false)
                        clip:SetPoint("TOPLEFT", progress, "TOPLEFT")
                        clip:SetPoint("BOTTOMRIGHT", progress:GetStatusBarTexture(), "BOTTOMRIGHT")
                        local color = iSTSettings.nameplateEchoColor
                        local iconStyle = iSTSettings.nameplateEchoStyle == "SEAL_ICONS"
                        local row = { progress = progress, glows = {}, dots = {}, sealPips = {} }
                        host.pipRows[#host.pipRows + 1] = row
                        for index = 1, 3 do
                            local glow = clip:CreateTexture(nil, "ARTWORK")
                            glow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                            glow:SetSize(22, 22)
                            glow:SetPoint("LEFT", progress, "LEFT", (index - 1) * 22 - 1, 0)
                            glow:SetBlendMode("ADD")
                            glow:SetVertexColor(color.r, color.g, color.b,
                                iSTSettings.nameplateEchoGlow and (color.a or 1) * 0.38 or 0)
                            host.glows[#host.glows + 1] = glow
                            row.glows[index] = glow
                            local dot = clip:CreateTexture(nil, "OVERLAY")
                            dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                            dot:SetSize(15, 15)
                            dot:SetPoint("LEFT", progress, "LEFT", (index - 1) * 22 + 2, 0)
                            dot:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * 0.95)
                            dot:SetShown(not iconStyle)
                            host.dots[#host.dots + 1] = dot
                            row.dots[index] = dot
                            local sealPip = clip:CreateTexture(nil, "OVERLAY")
                            sealPip:SetTexture(self.BarFrame.stackSealIcons[slotInfo.seal]
                                or "Interface\\Icons\\INV_Misc_QuestionMark")
                            sealPip:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                            sealPip:SetSize(18, 18)
                            sealPip:SetPoint("LEFT", progress, "LEFT", (index - 1) * 22 + 1, 0)
                            local pipMask = clip:CreateMaskTexture()
                            pipMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                            pipMask:SetAllPoints(sealPip)
                            sealPip:AddMaskTexture(pipMask)
                            sealPip:SetShown(iconStyle)
                            host.sealPips[#host.sealPips + 1] = sealPip
                            row.sealPips[index] = sealPip
                        end
                        SizeNameplatePipRow(row, math.max(10, math.min(40,
                            tonumber(iSTSettings.nameplateEchoPipSize) or 18)))
                        assert(type(button.SetApplicationBar) == "function", "native aura stack bar is unavailable")
                        button:SetApplicationBar(progress, { maxApplications = 3 })
                    end,
                })
            end
            container:SetEnabled(true)
            return host
        end)
        if not ok then
            self.State.NameplateEchoFailed = true
            self:DebugMsg("Nameplate Echo display is unavailable: " .. tostring(result), 2)
            return
        end
        frame = result
        self.NameplateEchoFrame = frame
        frame.filterKey = StackFilterKey()
    end
    if not frame then return end
    if not CombatLocked() and frame.filterKey ~= StackFilterKey() then
        local updated = true
        for _, slot in ipairs(frame.slots) do
            if not pcall(frame.container.SetAuraSlotCandidateFilters,
                frame.container, slot.key, StackSpellFilter(slot)) then updated = false end
        end
        if updated then frame.filterKey = StackFilterKey() end
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if not ok or (issecretvalue and issecretvalue(plate)) or not plate then
        pcall(frame.Hide, frame)
        return
    end
    local anchorOK, anchor = pcall(function()
        local platerAnchor = plate.PlaterAnchorFrame
        if type(platerAnchor) == "table" or type(platerAnchor) == "userdata" then
            return platerAnchor
        end
        return plate
    end)
    if not anchorOK or (issecretvalue and issecretvalue(anchor)) then
        pcall(frame.Hide, frame)
        return
    end
    if frame.anchor ~= anchor or frame.offsetY ~= iSTSettings.nameplateEchoOffsetY then
        local positioned = pcall(function()
            frame:ClearAllPoints()
            frame:SetPoint("TOP", anchor, "BOTTOM", 0, iSTSettings.nameplateEchoOffsetY or -5)
        end)
        if not positioned then pcall(frame.Hide, frame); return end
        frame.anchor, frame.offsetY = anchor, iSTSettings.nameplateEchoOffsetY
    end
    local scale = iSTSettings.nameplateEchoScale or 1
    if frame.displayScale ~= scale and pcall(frame.SetScale, frame, scale) then
        frame.displayScale = scale
    end
    if not CombatLocked() then
        local pipSize = math.max(10, math.min(40, tonumber(iSTSettings.nameplateEchoPipSize) or 18))
        if frame.pipSize ~= pipSize then
            local resized = pcall(function()
                frame:SetSize(26 + (pipSize + 4) * 3, math.max(26, pipSize + 4))
                for _, row in ipairs(frame.pipRows) do SizeNameplatePipRow(row, pipSize) end
            end)
            if resized then frame.pipSize = pipSize end
        end
        local color = iSTSettings.nameplateEchoColor
        local iconStyle = iSTSettings.nameplateEchoStyle == "SEAL_ICONS"
        local visualKey = table.concat({ color.r, color.g, color.b, color.a or 1,
            tostring(iSTSettings.nameplateEchoGlow), tostring(iconStyle) }, ":")
        if frame.visualKey ~= visualKey then
            local updated = true
            for _, glow in ipairs(frame.glows) do
                if not pcall(glow.SetVertexColor, glow, color.r, color.g, color.b,
                    iSTSettings.nameplateEchoGlow and (color.a or 1) * 0.38 or 0) then updated = false end
            end
            for _, dot in ipairs(frame.dots) do
                if not pcall(dot.SetVertexColor, dot, color.r, color.g, color.b,
                    (color.a or 1) * 0.95) then updated = false end
                if not pcall(dot.SetShown, dot, not iconStyle) then updated = false end
            end
            for _, sealPip in ipairs(frame.sealPips) do
                if not pcall(sealPip.SetShown, sealPip, iconStyle) then updated = false end
            end
            if updated then frame.visualKey = visualKey end
        end
    end
    pcall(frame.Show, frame)
end

local function CenterSwitchPhrase()
    return iSTSettings.centerSwitchText or "Switch now"
end

local function CenterMessageFormatter(message, target)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local safeMessage = message:gsub("%%", "%%%%")
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "" },
        { threshold = target, format = safeMessage },
    }) then return formatter end
end

function iST:IsEchoSwitchPhase(source)
    if not source then return nil end
    local current = self.State.CurrentSealName
    local cast = self.State.WrathLastSealCastName
    if issecretvalue and (issecretvalue(current) or issecretvalue(cast)) then return nil end
    return not (current and current ~= source and cast == current)
end

local function EchoSwitchBackPending(self)
    local source = self.State.EchoSwitchBackSeal
    local current = self.State.CurrentSealName
    if issecretvalue and (issecretvalue(source) or issecretvalue(current)) then return false end
    return source ~= nil and self:GetTwistStackSelection(source) == 0
        and (current == nil or current == source)
end

function iST:ShouldShowEchoSwitchBack()
    return EchoSwitchBackPending(self) and not self.State.EditMode and self:IsWrathTrackingEnabled()
        and self:ShouldShowAuxiliaryCues()
        and (self.State.InCombat == true or self:HasActiveSeal())
end

function iST:UpdateCenterSwitchSealGate()
    local frame = self.CenterSwitchFrame
    if not frame or not frame.phaseSlotFrames or self.State.CenterSwitchPhaseBlocked then return end
    local current = self.State.CurrentSealName
    local cast = self.State.WrathLastSealCastName
    local mode = iSTSettings.centerSwitchMode or "BOTH"
    if (issecretvalue and (issecretvalue(current) or issecretvalue(cast))) then return end
    if frame.gateValid and frame.gateSeal == current and frame.gateCast == cast
        and frame.gateMoving == frame.moving and frame.gateMode == mode then return end
    for _, slot in ipairs(frame.slots) do
        -- The buff slot identifies the Seal behind its own three-stack text.
        local source = slot.seal
        local phase = self:IsEchoSwitchPhase(source) and "switch" or "attack"
        for _, name in ipairs({ "switch", "attack" }) do
            -- These parents are plain frames; the buff buttons cannot be
            -- changed safely during combat.
            local parent = frame.phaseSlotFrames[name][slot.key]
            local allowed = mode == "BOTH" or mode == "SWITCH" and name == "switch"
                or mode == "ATTACK" and name == "attack"
            local alpha = not frame.moving and phase == name and allowed and 1 or 0
            local accessible, forbidden = pcall(function()
                return type(parent.IsForbidden) == "function" and parent:IsForbidden() or false
            end)
            if not accessible or forbidden then
                frame.gateValid = false
                self.State.CenterSwitchPhaseBlocked = true
                self:DebugMsg("The center message phase frame is unavailable during combat.", 2)
                return
            end
            local ok = pcall(function() parent:SetAlpha(alpha) end)
            if not ok then
                frame.gateValid = false
                self.State.CenterSwitchPhaseBlocked = true
                self:DebugMsg("The center message could not change phases during combat.", 2)
                return
            end
        end
    end
    frame.gateSeal, frame.gateCast = current, cast
    frame.gateMoving = frame.moving
    frame.gateMode = mode
    frame.gateValid = true
end

function iST:SetCenterSwitchMoveMode(enabled)
    if enabled and CombatLocked() then return end
    if enabled and (not self.State.EditMode or iSTSettings.barLocked) then self:SetBarLocked(false) end
    if enabled and (not self.State.EditMode or iSTSettings.barLocked) then return end
    if enabled and not self.CenterSwitchFrame then self:UpdateCenterSwitchText(true) end
    local frame = self.CenterSwitchFrame
    if not frame then return end
    frame.moving = enabled == true
    local handle = frame.dragHandle
    if CombatLocked() then
        pcall(frame.EnableMouse, frame, false)
        if handle then
            pcall(handle.EnableMouse, handle, false)
            pcall(handle.Hide, handle)
        end
        pcall(frame.preview.Hide, frame.preview)
        pcall(frame.moveBackdrop.Hide, frame.moveBackdrop)
        frame.restoreStrata = true
        return
    end
    frame:EnableMouse(false)
    if handle then
        handle:EnableMouse(frame.moving)
        handle:SetShown(frame.moving)
    end
    frame.preview:SetShown(frame.moving)
    frame.moveBackdrop:SetShown(frame.moving)
    if frame.moving then
        frame:SetFrameStrata("DIALOG")
    else
        frame:SetFrameStrata("MEDIUM")
    end
    self:UpdateCenterSwitchText()
end

function iST:ResetCenterSwitchPosition()
    if CombatLocked() then return end
    iSTSettings.centerSwitchPoint = { "CENTER", nil, "CENTER", 0, 0 }
    local frame = self.CenterSwitchFrame
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function iST:UpdateEchoSwitchBackText()
    local frame = self.CenterSwitchBackFrame
    if not frame then return end
    local visible = iSTSettings.showCenterSwitchText and iSTSettings.centerSwitchMode ~= "ATTACK"
        and self:ShouldShowEchoSwitchBack()
    if not CombatLocked() then
        local color = iSTSettings.centerSwitchColor
        local font = self:GetBarFontPath()
        local colorKey = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
        local phrase = CenterSwitchPhrase()
        if frame.font ~= font then
            frame.text:SetFont(font, 32, "THICKOUTLINE")
            frame.font = font
        end
        if frame.colorKey ~= colorKey then
            frame.text:SetTextColor(color.r, color.g, color.b, color.a or 1)
            frame.colorKey = colorKey
        end
        if frame.phrase ~= phrase then
            frame.text:SetText(phrase)
            frame.phrase = phrase
        end
    end
    pcall(frame.SetShown, frame, visible == true)
end

function iST:UpdateCenterSwitchText(forceCreate)
    if CombatLocked() then return end
    local frame = self.CenterSwitchFrame
    local wanted = self:ShouldShowAuxiliaryCues() and self:IsWrathTrackingEnabled()
        and iSTSettings.showCenterSwitchText
    if frame and frame.restoreStrata then
        frame:SetFrameStrata("MEDIUM")
        frame.restoreStrata = nil
    end
    if not wanted and not forceCreate and not (frame and frame.moving) then
        if frame then frame:Hide() end
        self:UpdateEchoSwitchBackText()
        return
    end
    if self.State.CenterSwitchFailed then return end
    if not NativeContainerReady()
        or not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    if not frame then
        local ok, result = pcall(function()
            local host = CreateFrame("Frame", nil, UIParent)
            host:SetSize(360, 68)
            host:Hide()
            local point = iSTSettings.centerSwitchPoint or { "CENTER", nil, "CENTER", 0, 0 }
            host:SetPoint(point[1], UIParent, point[3], point[4], point[5])
            host:SetFrameStrata("MEDIUM")
            host:SetClampedToScreen(true)
            host:SetMovable(true)
            host:EnableMouse(false)
            local dragHandle = CreateFrame("Frame", nil, UIParent)
            dragHandle:SetSize(260, 48)
            dragHandle:SetPoint("CENTER", host, "CENTER")
            dragHandle:SetFrameStrata("DIALOG")
            dragHandle:SetFrameLevel(host:GetFrameLevel() + 10)
            dragHandle:EnableMouse(false)
            dragHandle:RegisterForDrag("LeftButton")
            dragHandle:SetScript("OnDragStart", function()
                if host.moving and not CombatLocked() then
                    iST:BeginMoveGuides(host)
                end
            end)
            dragHandle:SetScript("OnDragStop", function()
                iST:EndMoveGuides(host)
                local point, _, relativePoint, x, y = host:GetPoint()
                iSTSettings.centerSwitchPoint = { point, nil, relativePoint, x, y }
            end)
            dragHandle:SetScript("OnMouseUp", function(_, button)
                if button == "RightButton" and iST:CanResetMovePosition(host) then
                    iST:ResetCenterSwitchPosition()
                end
            end)
            dragHandle:Hide()
            host.dragHandle = dragHandle
            host.moveBackdrop = host:CreateTexture(nil, "BACKGROUND")
            host.moveBackdrop:SetAllPoints(host)
            host.moveBackdrop:SetColorTexture(0.10, 0.07, 0.025, 0.75)
            host.moveBackdrop:Hide()
            host.preview = host:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            host.preview:SetAllPoints(host)
            host.preview:SetJustifyH("CENTER")
            host.preview:Hide()

            host.rows, host.slots = {}, {}
            host.phaseContainers, host.phaseSlotFrames = {}, {}
            for _, spell in ipairs(self.WrathEchoSpells) do
                host.slots[#host.slots + 1] = { key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal }
            end
            for _, phase in ipairs({ "switch", "attack" }) do
                local phaseName = phase
                host.phaseContainers[phaseName] = {}
                host.phaseSlotFrames[phaseName] = {}
                for _, slot in ipairs(host.slots) do
                    local slotInfo = slot
                    local slotFrame = CreateFrame("Frame", nil, host)
                    slotFrame:SetSize(1, 1)
                    slotFrame:SetPoint("TOPLEFT", host, "TOPLEFT")
                    slotFrame:EnableMouse(false)
                    slotFrame:SetAlpha(phaseName == "switch" and 1 or 0)
                    host.phaseSlotFrames[phaseName][slotInfo.key] = slotFrame
                    local container = CreateFrame("AuraContainer", nil, slotFrame, "CustomAuraContainerTemplate")
                    container:SetAllPoints(slotFrame)
                    container:EnableMouse(false)
                    container:SetUnit("player")
                    host.phaseContainers[phaseName][slotInfo.key] = container
                    container:AddAuraSlot(slotInfo.key, "HELPFUL", {
                        candidateFilters = StackSpellFilter(slotInfo),
                        initializeFrame = function(button)
                            button:SetAllPoints(slotFrame)
                            button:EnableMouse(false)
                            local message = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                            message:SetSize(360, 68)
                            message:SetPoint("CENTER", host, "CENTER")
                            message:SetJustifyH("CENTER")
                            message:SetJustifyV("MIDDLE")
                            message:SetShadowOffset(2, -2)
                            message:SetShadowColor(0, 0, 0, 1)
                            message:SetFont(self:GetBarFontPath(), 32, "THICKOUTLINE")
                            local messageColor = phaseName == "attack"
                                and iSTSettings.centerAttackColor or iSTSettings.centerSwitchColor
                            message:SetTextColor(messageColor.r, messageColor.g, messageColor.b,
                                messageColor.a or 1)
                            local text = phaseName == "attack" and (iSTSettings.centerAttackText or L["WrathAttackNow"])
                                or CenterSwitchPhrase()
                            local target = self:GetTwistStackTarget(slotInfo.seal)
                            button:SetApplicationCount(message,
                                { formatter = assert(CenterMessageFormatter(text, target)) })
                            host.rows[#host.rows + 1] = {
                                button = button, message = message, phase = phaseName,
                                seal = slotInfo.seal,
                            }
                        end,
                    })
                    container:SetEnabled(true)
                end
            end
            return host
        end)
        if not ok then
            self.State.CenterSwitchFailed = true
            self:DebugMsg("Three-stack message could not be shown: " .. tostring(result), 2)
            return
        end
        frame = result
        -- A newly created cue must be click-through before any move command.
        frame.moving = false
        frame:EnableMouse(false)
        frame.dragHandle:EnableMouse(false)
        frame.dragHandle:Hide()
        self.CenterSwitchFrame = frame
        local fallback = CreateFrame("Frame", nil, UIParent)
        fallback:SetAllPoints(frame)
        fallback:SetFrameStrata("HIGH")
        fallback:EnableMouse(false)
        fallback.text = fallback:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fallback.text:SetAllPoints(fallback)
        fallback.text:SetJustifyH("CENTER")
        fallback.text:SetJustifyV("MIDDLE")
        fallback.text:SetShadowOffset(2, -2)
        fallback.text:SetShadowColor(0, 0, 0, 1)
        fallback:Hide()
        self.CenterSwitchBackFrame = fallback
    end
    local filterKey = StackFilterKey()
    if frame.filterKey ~= filterKey then
        local updated = true
        for _, slot in ipairs(frame.slots) do
            for _, phase in ipairs({ "switch", "attack" }) do
                local container = frame.phaseContainers[phase][slot.key]
                if not pcall(container.SetAuraSlotCandidateFilters, container,
                    slot.key, StackSpellFilter(slot)) then updated = false end
            end
        end
        if updated then frame.filterKey = filterKey end
    end
    local phrase = CenterSwitchPhrase()
    local attackPhrase = iSTSettings.centerAttackText or L["WrathAttackNow"]
    for _, row in ipairs(frame.rows) do
        local message = row.phase == "switch" and phrase or attackPhrase
        local target = self:GetTwistStackTarget(row.seal)
        local ruleKey = message .. ":" .. target
        if row.ruleKey ~= ruleKey then
            local formatter = CenterMessageFormatter(message, target)
            if formatter and pcall(row.button.SetApplicationCount,
                row.button, row.message, { formatter = formatter }) then
                row.ruleKey = ruleKey
            end
        end
    end
    local font = self:GetBarFontPath()
    local switchColor = iSTSettings.centerSwitchColor
    local attackColor = iSTSettings.centerAttackColor
    local colorKey = table.concat({ switchColor.r, switchColor.g, switchColor.b, switchColor.a or 1,
        attackColor.r, attackColor.g, attackColor.b, attackColor.a or 1 }, ":")
    if frame.font ~= font or frame.colorKey ~= colorKey then
        for _, row in ipairs(frame.rows) do
            local color = row.phase == "attack" and attackColor or switchColor
            row.message:SetFont(font, 32, "THICKOUTLINE")
            row.message:SetTextColor(color.r, color.g, color.b, color.a or 1)
        end
        frame.font, frame.colorKey = font, colorKey
    end
    if frame.previewFont ~= font then
        frame.preview:SetFont(font, 32, "THICKOUTLINE")
        frame.previewFont = font
    end
    local previewPhrase = iSTSettings.centerSwitchMode == "ATTACK" and attackPhrase or phrase
    local previewColor = iSTSettings.centerSwitchMode == "ATTACK" and attackColor or switchColor
    local previewColorKey = iSTSettings.centerSwitchMode .. ":" .. colorKey
    if frame.previewPhrase ~= previewPhrase then
        frame.preview:SetText(previewPhrase)
        frame.previewPhrase = previewPhrase
    end
    if frame.previewColorKey ~= previewColorKey then
        frame.preview:SetTextColor(previewColor.r, previewColor.g, previewColor.b, previewColor.a or 1)
        frame.previewColorKey = previewColorKey
    end
    local visible = wanted or frame.moving
    local height = 68
    if frame:GetHeight() ~= height then frame:SetHeight(height) end
    if frame:IsShown() ~= visible then frame:SetShown(visible) end
    self:UpdateCenterSwitchSealGate()
    self:UpdateEchoSwitchBackText()
end

local function NativeCountFormatter(target, label)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local points = { { threshold = 0, format = "" } }
    target = type(target) == "number" and target or 3
    label = label or tostring(target)
    for stage = 1, 3 do
        local color = iST:GetWrathCueColor(stage)
        local code = string.format("|c%02x%02x%02x%02x", math.floor((color.a or 1) * 255 + 0.5),
            math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5))
        points[#points + 1] = { threshold = stage, format = code .. "%d / " .. label .. "|r" }
    end
    if pcall(formatter.SetBreakpoints, formatter, points) then return formatter end
end

function iST:ApplyStackStageFormatter()
    local bar = self.BarFrame
    if not bar or not bar.stackManagedRows then return end
    if CombatLocked() then
        self.State.PendingStackStageFormatter = true
        return
    end
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local allUpdated = true
    for _, row in ipairs(bar.stackManagedRows) do
        if row.button and row.count then
            local formatter = NativeCountFormatter(self:GetTwistStackTarget(row.seal),
                self:GetTwistStackTargetLabel(row.seal))
            local ok = formatter and pcall(row.button.SetApplicationCount, row.button, row.count, { formatter = formatter })
            if ok then row.count:SetTextColor(1, 1, 1, 1) end
            if not ok then allUpdated = false end
        end
    end
    self.State.PendingStackStageFormatter = not allUpdated
    if not allUpdated and not bar.stackStageFormatterWarningShown then
        bar.stackStageFormatterWarningShown = true
        self:DebugMsg("Stack colors could not be applied to the buff counter.", 2)
    end
end

local function StageGateFormatter(stage)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local points = {
        { threshold = 0, format = "" },
        { threshold = stage, format = string.rep("W", 70) },
    }
    if stage < 3 then points[#points + 1] = { threshold = stage + 1, format = "" } end
    local ok = pcall(formatter.SetBreakpoints, formatter, points)
    return ok and formatter or nil
end

local function CreateStageButton(button, host, stage)
    button:SetSize(1600, 1000)
    button:ClearAllPoints()
    button:SetPoint("CENTER", host, "CENTER")
    button:SetFrameLevel(host:GetFrameLevel() + 10 + stage)
    button:EnableMouse(false)
    local gate = button:CreateFontString(nil, "BACKGROUND")
    gate:SetFont(STANDARD_TEXT_FONT, 64, "")
    gate:SetWidth(0)
    gate:SetWordWrap(false)
    gate:SetPoint("LEFT", button, "LEFT")
    gate:SetAlpha(0)
    gate:SetTextColor(0, 0, 0, 0)
    local clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    clip:SetPoint("LEFT", gate, "LEFT")
    clip:SetPoint("RIGHT", gate, "RIGHT")
    clip:SetPoint("TOP", button, "TOP")
    clip:SetPoint("BOTTOM", button, "BOTTOM")
    button:SetApplicationCount(gate, { formatter = assert(StageGateFormatter(stage)) })
    return clip, gate
end

local function BuildStageContainer(parent, host, build, initialize)
    local frame = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    frame:EnableMouse(false)
    frame:SetUnit("player")
    if initialize then initialize(frame) else frame:SetAllPoints(host) end
    local rows = {}
    frame.slotInfos = {}
    -- Each row belongs to one Echo spell, so the number of unfilled pips can
    -- follow that Seal's chosen switch target without reading protected stacks.
    for _, spell in ipairs(iST.WrathEchoSpells) do
        for stage = 1, 3 do
            local slot = { key = "echo" .. spell.id .. "stage" .. stage,
                spellID = spell.id, seal = spell.seal, stage = stage }
            frame.slotInfos[#frame.slotInfos + 1] = slot
            frame:AddAuraSlot(slot.key, "HELPFUL", {
                candidateFilters = StackSpellFilter(slot),
                initializeFrame = function(button)
                    local clip, gate = CreateStageButton(button, host, slot.stage)
                    local row = build(clip, slot.stage, slot.seal, gate)
                    row.stage, row.seal = slot.stage, slot.seal
                    rows[#rows + 1] = row
                    if iST.BarFrame then iST.BarFrame.nativeStageVisualKey = nil end
                    if not CombatLocked() then iST:RequestWrathDisplayUpdate() end
                end,
            })
        end
    end
    frame:SetEnabled(true)
    return frame, rows
end

local function BuildSealIconContainer(parent, bar, player)
    -- One native row per stack count lets each visible row center its pips.
    -- The count itself stays in Blizzard's aura formatter during combat.
    local frame, rows = BuildStageContainer(parent, parent, function(clip, stage, seal)
        local texture = bar.stackSealIcons[seal]
        local size = player and iST:GetPlayerPipSize()
            or math.max(10, math.min(50, tonumber(iSTSettings.wrathCircleSize) or 18))
        local strip = iST:CreateStackSealIcons(clip, size, 5, texture)
        iST:RenderStackSealIcons(strip, stage, texture, iST:GetTwistStackTarget(seal))
        if player then iST:LayoutPlayerPipRow(strip)
        else strip:SetPoint("BOTTOM", bar, "TOP", 0, iST:GetStackPipYOffset()) end
        return { strip = strip }
    end)
    frame:SetFrameLevel(parent:GetFrameLevel() + 12)
    frame.iconRows = rows
    return frame
end

function iST:UpdateNativeSealIconStrips()
    local bar = self.BarFrame
    if not bar or CombatLocked() then return end
    local active = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and iSTSettings.stackBubbleStyle == "SEAL_ICONS"
    local mainWanted = active and iSTSettings.showStackCircles
    local playerWanted = active and iSTSettings.showPlayerWrathBubbles
    if not (mainWanted or playerWanted or bar.nativeSealIconsMain or bar.nativeSealIconsPlayer) then return end
    if not NativeContainerReady() then return end
    for _, spec in ipairs({
        { wanted = mainWanted, parent = bar, key = "nativeSealIconsMain",
            visible = "nativeSealIconsMainVisible", filter = "nativeSealIconsMainFilter", player = false },
        { wanted = playerWanted, parent = self.PlayerWrathFrame, key = "nativeSealIconsPlayer",
            visible = "nativeSealIconsPlayerVisible", filter = "nativeSealIconsPlayerFilter", player = true },
    }) do
        local frame = bar[spec.key]
        if spec.wanted and spec.parent and not frame and not bar[spec.key .. "Failed"] then
            local ok, result = pcall(BuildSealIconContainer, spec.parent, bar, spec.player)
            if ok then
                frame = result
                bar[spec.key] = frame
                bar[spec.filter] = StackFilterKey()
                bar[spec.visible] = true
            else
                bar[spec.key .. "Failed"] = true
                self:DebugMsg("Seal icon stack display is unavailable: " .. tostring(result), 2)
            end
        end
        if frame then
            for _, row in ipairs(frame.iconRows or {}) do
                self:SetStackSealIconTarget(row.strip, self:GetTwistStackTarget(row.seal))
            end
            local filterKey = StackFilterKey()
            if bar[spec.filter] ~= filterKey then
                local updated = true
                for _, slot in ipairs(frame.slotInfos) do
                    if not pcall(frame.SetAuraSlotCandidateFilters, frame,
                        slot.key, StackSpellFilter(slot)) then updated = false end
                end
                if updated then bar[spec.filter] = filterKey end
            end
            if bar[spec.visible] ~= spec.wanted then
                frame:SetShown(spec.wanted)
                bar[spec.visible] = spec.wanted
            end
        end
    end
end

function iST:UpdateNativeStageVisuals()
    local bar = self.BarFrame
    if not bar or CombatLocked() then return end
    self:UpdateNativeSealIconStrips()
    local stackBarColor = iSTSettings.showSwingBar and iSTSettings.showStackBarColor and not iSTSettings.barColorBySeal
    local swordImages = self:UsesSwordImages()
    local mainWanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and (stackBarColor or swordImages
            or (iSTSettings.showStackCircles and iSTSettings.stackBubbleStyle == "CIRCLES"))
    local playerWanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and iSTSettings.showPlayerWrathBubbles and iSTSettings.stackBubbleStyle == "CIRCLES"
    if not mainWanted and not playerWanted
        and not bar.nativeStageMain and not bar.nativeStagePlayer then return end
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    if not NativeContainerReady() then return end
    if mainWanted and not bar.nativeStageMain and not bar.nativeStageFailed then
        local ok, frame, rows = pcall(BuildStageContainer, bar, bar, function(clip, stage, seal)
            local overlay = clip:CreateTexture(nil, "ARTWORK")
            overlay:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
            overlay:SetAllPoints(bar.fill)
            local sword = self:CreateNativeSwordStage(bar, clip)
            if self:UsesSwordImages() then
                self:UpdateNativeSwordStage(bar, sword, self:GetWrathCueColor(stage),
                    self:GetSwordImageGlowStage(stage, self:GetTwistStackTarget(seal)))
                sword:Show()
            end
            local circles = self:CreateStackBubbles(clip, nil,
                math.max(10, math.min(50, tonumber(iSTSettings.wrathCircleSize) or 18)), 9)
            circles:SetPoint("BOTTOM", bar, "TOP", 0, self:GetStackPipYOffset())
            return { overlay = overlay, sword = sword, circles = circles }
        end)
        if ok then
            bar.nativeStageMain, bar.nativeStageMainRows = frame, rows
            bar.nativeStageMainKey = StackFilterKey()
            frame:Hide()
            bar.nativeStageMainVisible = false
            bar.nativeStageVisualKey = nil
            self:ApplyWrathCircleSize()
        else
            bar.nativeStageFailed = true
            self:DebugMsg("Stack graphics could not attach to the buff: " .. tostring(frame), 2)
        end
    end
    if playerWanted and self.PlayerWrathFrame and not bar.nativeStagePlayer and not bar.nativePlayerStageFailed then
        local ok, frame, rows = pcall(BuildStageContainer, self.PlayerWrathFrame,
            self.PlayerWrathFrame, function(clip, stage, seal)
                local bubbles = self:CreateStackBubbles(clip, nil, self:GetPlayerPipSize(), 10)
                self:RenderStackBubbles(bubbles, stage, self:GetWrathCueColor(stage),
                    self:GetTwistStackTarget(seal))
                self:LayoutPlayerPipRow(bubbles)
                bubbles:Show()
                return { bubbles = bubbles }
            end)
        if ok then
            bar.nativeStagePlayer, bar.nativeStagePlayerRows = frame, rows
            bar.nativeStagePlayerKey = StackFilterKey()
            frame:Hide()
            bar.nativeStagePlayerVisible = false
            bar.nativeStageVisualKey = nil
            self:ApplyWrathCircleSize()
        else
            bar.nativePlayerStageFailed = true
            self:DebugMsg("Player stack bubbles could not attach to the buff: " .. tostring(frame), 2)
        end
    end
    local filterKey = StackFilterKey()
    for _, entry in ipairs({ { bar.nativeStageMain, "nativeStageMainKey" },
        { bar.nativeStagePlayer, "nativeStagePlayerKey" } }) do
        local frame, key = entry[1], entry[2]
        if frame and bar[key] ~= filterKey then
            local updated = true
            for _, slot in ipairs(frame.slotInfos or {}) do
                if not pcall(frame.SetAuraSlotCandidateFilters, frame,
                    slot.key, StackSpellFilter(slot)) then updated = false end
            end
            if updated then bar[key] = filterKey end
        end
    end
    if bar.nativeStageMain and bar.nativeStageMainVisible ~= mainWanted then
        bar.nativeStageMain:SetShown(mainWanted)
        bar.nativeStageMainVisible = mainWanted
    end
    if bar.nativeStagePlayer and bar.nativeStagePlayerVisible ~= playerWanted then
        bar.nativeStagePlayer:SetShown(playerWanted)
        bar.nativeStagePlayerVisible = playerWanted
    end
    if not mainWanted and not playerWanted then return end
    local visualParts = { tostring(stackBarColor),
        tostring(swordImages), tostring(iSTSettings.showStackCircles),
        tostring(iSTSettings.swordFrameStyle),
        tostring(iSTSettings.stackBubbleStyle),
        tostring(iSTSettings.wrathColorScheme),
        tostring(iSTSettings.twistFromSeal), tostring(iSTSettings.twistIntoSeal),
        tostring(iSTSettings.twistFromStacks), tostring(iSTSettings.twistIntoStacks),
        tostring(bar:GetWidth()), tostring(bar:GetHeight()) }
    for stage = 0, 3 do
        local color = self:GetWrathCueColor(stage)
        visualParts[#visualParts + 1] = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
    end
    local visualKey = table.concat(visualParts, ":")
    if bar.nativeStageVisualKey == visualKey then return end
    bar.nativeStageVisualKey = visualKey
    if bar.nativeStageMain then
        for _, row in ipairs(bar.nativeStageMainRows or {}) do
            local stage = row.stage
            local color = self:GetWrathCueColor(stage)
            row.overlay:SetVertexColor(color.r, color.g, color.b, color.a or 1)
            row.overlay:SetShown(stackBarColor)
            self:UpdateNativeSwordStage(bar, row.sword, color,
                self:GetSwordImageGlowStage(stage, self:GetTwistStackTarget(row.seal)))
            row.sword:SetShown(swordImages)
            self:RenderStackBubbles(row.circles, stage, color,
                self:GetTwistStackTarget(row.seal))
            row.circles:SetShown(iSTSettings.showStackCircles and iSTSettings.stackBubbleStyle == "CIRCLES")
        end
    end
    if bar.nativeStagePlayer then
        for _, row in ipairs(bar.nativeStagePlayerRows or {}) do
            local stage = row.stage
            self:RenderStackBubbles(row.bubbles, stage, self:GetWrathCueColor(stage),
                self:GetTwistStackTarget(row.seal))
            row.bubbles:Show()
        end
    end
end

local function SwordFillInterpolation()
    return Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
end

local function CreateVerticalSwordHost()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)

    local liveLayer = CreateFrame("Frame", nil, frame)
    liveLayer:SetAllPoints(frame)
    liveLayer:EnableMouse(false)

    -- Keep the drag surface and preview outside the native aura hierarchy so
    -- combat can always clear them, even when an Echo is already active.
    local handle = CreateFrame("Frame", nil, UIParent)
    handle:SetAllPoints(frame)
    handle:SetFrameStrata("MEDIUM")
    handle:SetFrameLevel(frame:GetFrameLevel() + 20)
    handle:EnableMouse(false)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if iST:IsLayoutUnlocked() then iST:BeginMoveGuides(frame) end
    end)
    handle:SetScript("OnDragStop", function()
        if not iST.MoveGuides or iST.MoveGuides.movingFrame ~= frame then return end
        iST:EndMoveGuides(frame)
        if not iST:IsLayoutUnlocked() then return end
        local _, _, _, x, y = frame:GetPoint()
        iSTSettings.verticalSwordPoint = { x, y }
        frame.position = iSTSettings.verticalSwordPoint
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" or not iST:CanResetMovePosition(frame) then return end
        iSTSettings.verticalSwordPoint = nil
        iST:UpdateVerticalSword(iST.State.PreviewStacks)
    end)
    if SwordFillInterpolation() then
        frame.previewSword = iST:CreateAnimatedVerticalSword(handle, handle)
    else
        frame.artwork = iST:CreateVerticalSwordArtwork(handle, handle)
    end
    handle:Hide()
    frame.liveLayer, frame.handle = liveLayer, handle
    return frame
end

local function BindVerticalSwordFill(row, target)
    row.button:SetApplicationBar(row.sword.bar, {
        minApplications = 0,
        maxApplications = target,
        interpolation = SwordFillInterpolation(),
    })
    row.target = target
end

function iST:ObserveVerticalSwordEcho(instanceID, seal, newlyAdded)
    local frame = self.VerticalSwordFrame
    if not frame or not frame.animated or frame.swordEchoInstanceID == instanceID then return end
    -- A temporary absence during a refresh can clear the tracker, but it
    -- must not rearm the sweep for the same Echo instance.
    frame.swordEchoInstanceID = instanceID
    if not newlyAdded or not frame.nativeWanted or frame.preview then return end
    for _, row in ipairs(frame.rows) do
        if row.seal == seal then
            local sweep = row.sword.fillSweep
            if sweep then
                local ok = pcall(function()
                    sweep:Stop()
                    sweep:Play()
                end)
                if not ok then
                    row.sword.fillSweep = nil
                    self:DebugMsg("Sword fill animation could not play.", 3)
                end
            end
            return
        end
    end
end

local SWORD_CLIP_WIDTH = 256
local SWORD_BUILDING_GATE_TEXT = string.rep("W", 16)

local function BindSwordWarningThreshold(frame, row, target)
    local gate = row.warningGate
    if not gate then
        gate = row.button:CreateFontString(nil, "BACKGROUND")
        gate:SetFont(STANDARD_TEXT_FONT, 64, "")
        gate:SetWordWrap(false)
        gate:SetWidth(0)
        gate:SetPoint("LEFT", frame, "CENTER", -SWORD_CLIP_WIDTH / 2, 0)
        gate:SetAlpha(0)
        -- Measure the public marker before the client binds the native count.
        gate:SetText(SWORD_BUILDING_GATE_TEXT)
        local width = gate:GetStringWidth()
        assert(width >= SWORD_CLIP_WIDTH, "sword gate marker is too narrow")
        gate:SetText("")
        row.warningOffset = -width
        row.warningGate = gate
    end
    local points = { { threshold = 0, format = "" } }
    if target > 1 then points[#points + 1] = { threshold = 1, format = SWORD_BUILDING_GATE_TEXT } end
    points[#points + 1] = { threshold = target, format = SWORD_BUILDING_GATE_TEXT:rep(2) }
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints(points)
    row.button:SetApplicationCount(gate, { formatter = formatter })
    row.warningTarget = target
end

local function BuildAnimatedSwordContainer(frame, container)
    container:EnableMouse(false)
    container:SetUnit("player")
    local rows = {}
    for _, spell in ipairs(iST.WrathEchoSpells) do
        local slot = { spellID = spell.id, seal = spell.seal }
        container:AddAuraSlot("swordEcho" .. slot.spellID, "HELPFUL", {
            candidateFilters = StackSpellFilter(slot),
            initializeFrame = function(button)
                button:SetAllPoints(frame)
                button:EnableMouse(false)
                local sword = iST:CreateAnimatedVerticalSword(button, frame)
                local row = { button = button, sword = sword, seal = slot.seal }
                iST:RenderAnimatedVerticalSword(sword, row.seal, frame.height)
                local target = iST:GetTwistStackTarget(row.seal)
                BindVerticalSwordFill(row, target)
                if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
                    local ok, err = pcall(BindSwordWarningThreshold, frame, row, target)
                    if not ok then iST:DebugMsg("The sword switch cue could not attach to the Echo: " .. tostring(err), 2) end
                end
                -- The native bar owns the stack value. The startup sweep runs
                -- only for a newly added Echo, even if its button is shown again.
                local ok, sweep = pcall(iST.CreateVerticalSwordFillSweep, iST, sword)
                if ok then sword.fillSweep = sweep
                else iST:DebugMsg("Sword fill animation could not attach: " .. tostring(sweep), 3) end
                rows[#rows + 1] = row
            end,
        })
    end
    return rows
end

local function CreateEmptySwordClip(host, container, parent)
    -- A matching Echo fills the group and closes the empty sword's clip.
    local clip = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    clip:SetPoint("TOPLEFT", container, "TOPRIGHT", -1, 0)
    clip:SetPoint("BOTTOMRIGHT", host, "BOTTOM", SWORD_CLIP_WIDTH / 2, 0)
    return clip
end

local function CreateEmptySwordArtwork(host, container)
    iST:AddEchoPresenceGroup(container, host, SWORD_CLIP_WIDTH)
    local clip = CreateEmptySwordClip(host, container, host.liveLayer)
    return iST:CreateVerticalSwordArtwork(clip, host)
end

local function InitializeEmptySword(frame, container)
    local ok, artwork = pcall(CreateEmptySwordArtwork, frame, container)
    if ok then frame.emptyArtwork = artwork
    else iST:DebugMsg("Empty sword could not attach to the Echo buff: " .. tostring(artwork), 2) end
end

local function CreateSwordVisualLayer(parent, frame)
    local layer = CreateFrame("Frame", nil, parent)
    layer:SetAllPoints(frame)
    layer:EnableMouse(false)
    layer:SetAlpha(0)
    return { layer = layer, active = false }
end

local function CreateSwordWarningLayer(parent, frame)
    local visual = CreateSwordVisualLayer(parent, frame)
    visual.artwork = iST:CreateVerticalSwordWarning(visual.layer, frame)
    return visual
end

local function SetSwordVisualActive(visual, active)
    if visual and visual.active ~= active then
        visual.layer:SetAlpha(active and 1 or 0)
        visual.active = active
    end
end

local function RefreshSwordPhaseThreshold(frame, row, target)
    if not row.stage and row.warningTarget ~= target then
        local ok, err = pcall(BindSwordWarningThreshold, frame, row, target)
        if not ok then
            iST:DebugMsg("The sword switch cue could not attach to the Echo: " .. tostring(err), 2)
            return false
        end
    end
    return row.warningGate ~= nil
end

local function CreateSwordPhaseClip(parent, frame, row, phase)
    -- Native marker widths represent absent, building, and ready. Only
    -- geometry follows the protected count. Combat changes our plain parent.
    local gate = row.warningGate
    local clip = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    if phase == "BUILDING" then
        clip:SetPoint("LEFT", gate, "RIGHT", row.warningOffset, 0)
        clip:SetWidth(SWORD_CLIP_WIDTH)
    else
        local offset = phase == "SWITCH" and row.warningOffset or 0
        clip:SetPoint("LEFT", gate, "LEFT", offset, 0)
        clip:SetPoint("RIGHT", gate, "RIGHT", offset, 0)
    end
    clip:SetPoint("TOP", frame, "TOP")
    clip:SetPoint("BOTTOM", frame, "BOTTOM")
    return clip
end

local function ConfigureSwordPhaseWarning(frame, row, field, height, layout, color, atTarget)
    local warning = row[field]
    if not warning then
        warning = CreateSwordWarningLayer(frame.liveLayer, frame)
        warning.layer:SetFrameLevel(frame:GetFrameLevel() + 20)
        -- The marker follows the Echo threshold across the whole sword.
        -- Some Ashbringer crossguards sit below the blade's reveal.
        warning.artwork.parent = CreateSwordPhaseClip(warning.layer, frame, row, atTarget and "SWITCH" or "ACTIVE")
        row[field] = warning
    end
    iST:RenderVerticalSwordWarning(warning.artwork, layout, height, color)
end

local function ConfigureSwordWarnings(frame, row, height, ready, bound, layout)
    row.warnAtTarget = ready and layout ~= nil
    row.hasWarning = bound and layout ~= nil
    if not row.hasWarning then return end
    ConfigureSwordPhaseWarning(frame, row, "forcedWarning", height, layout, "SWITCH", false)
    if row.warnAtTarget then
        -- Both colors use the native stack threshold. Combat only changes the
        -- opacity of their addon-owned parents.
        ConfigureSwordPhaseWarning(frame, row, "switchWarning", height, layout, "SWITCH", true)
        ConfigureSwordPhaseWarning(frame, row, "attackWarning", height, layout, "ACTIVE", true)
    end
end

local function UpdateSwordHiltPhase(frame, row, field, phase, layout, height)
    local visual = row[field]
    if not visual then
        visual = CreateSwordVisualLayer(frame.liveLayer, frame)
        visual.layer:SetFrameLevel(frame:GetFrameLevel() + 23)
        local clip = CreateSwordPhaseClip(visual.layer, frame, row, phase)
        visual.glow = iST:CreateVerticalSwordHiltGlow(clip, frame)
        row[field] = visual
    end
    local artwork = row.sword and row.sword.base or row.texture
    iST:RenderVerticalSwordHiltGlow(visual.glow, layout, height, phase == "SWITCH" and "SWITCH" or "ACTIVE",
        artwork.swordOpacity)
end

local function ConfigureSwordHiltGlows(frame, row, height, ready, bound)
    row.hiltAtTarget = ready
    row.hiltEnabled = bound and iSTSettings.showVerticalSwordSealGlow
    if not row.hiltEnabled then return end
    local layout = iST:GetVerticalSwordHiltLayout(row.seal)
    UpdateSwordHiltPhase(frame, row, "activeHilt", "ACTIVE", layout, height)
    if ready then UpdateSwordHiltPhase(frame, row, "switchHilt", "SWITCH", layout, height) end
    if not row.stage then UpdateSwordHiltPhase(frame, row, "buildingHilt", "BUILDING", layout, height) end
end

local function ConfigureEmptySwordHilt(frame, field, layout, status)
    local visual = frame[field]
    if not visual then
        visual = CreateSwordVisualLayer(frame.liveLayer, frame)
        visual.layer:SetFrameLevel(frame:GetFrameLevel() + 23)
        local clip = CreateEmptySwordClip(frame, frame.native, visual.layer)
        visual.glow = iST:CreateVerticalSwordHiltGlow(clip, frame)
        frame[field] = visual
    end
    iST:RenderVerticalSwordHiltGlow(visual.glow, layout, frame.height, status, frame.emptyArtwork.swordOpacity)
end

local function UpdateSwordLayerVisibility(frame, live, preview, confirmedEcho)
    local visible = live and not preview and iST:MatchesDisplayVisibility(iSTSettings.verticalSwordVisibility, confirmedEcho)
    local alpha = visible and 1 or 0
    if frame.liveAlpha ~= alpha then
        frame.liveLayer:SetAlpha(alpha)
        frame.liveAlpha = alpha
    end
    local hasSeal = visible and iST:HasActiveSeal()
    local switchBack = visible and EchoSwitchBackPending(iST)
    local forceWarning = visible and (not hasSeal or switchBack) or false
    if frame.emptyWarning then
        SetSwordVisualActive(frame.emptyWarning, forceWarning and frame.emptyWarning.artwork.shown == true)
    end
    local showGlow = hasSeal and iSTSettings.showVerticalSwordSealGlow
    SetSwordVisualActive(frame.emptyActiveHilt, (showGlow and not switchBack) == true)
    SetSwordVisualActive(frame.emptySwitchHilt, (showGlow and switchBack) == true)
    for _, row in ipairs(frame.rows or {}) do
        local phase = iST:IsEchoSwitchPhase(row.seal)
        local switch = phase == true
        local ready = (visible and not forceWarning and row.warnAtTarget and phase ~= nil) == true
        SetSwordVisualActive(row.switchWarning, ready and switch)
        SetSwordVisualActive(row.attackWarning, ready and not switch)
        SetSwordVisualActive(row.forcedWarning, (forceWarning and row.hasWarning) == true)
        local glow = showGlow and row.hiltEnabled
        SetSwordVisualActive(row.activeHilt, (glow and (not switch or not row.hiltAtTarget)) == true)
        SetSwordVisualActive(row.buildingHilt, (glow and switch) == true)
        SetSwordVisualActive(row.switchHilt, (glow and switch and row.hiltAtTarget) == true)
    end
end

function iST:UpdateVerticalSword(count, confirmedEcho)
    local frame = self.VerticalSwordFrame
    local selected = iSTSettings.showVerticalSword and self:ShouldShowBar()
    if not selected and not frame then return end
    local preview = selected and self.State.TestMode and self.State.StackTestMode
    if CombatLocked() then
        if frame and frame.preview then
            frame.handle:EnableMouse(false)
            frame.handle:Hide()
            frame.preview = false
        end
        if frame then UpdateSwordLayerVisibility(frame, selected and frame.nativeWanted, false, confirmedEcho) end
        return
    end
    local live = selected and self:IsWrathTrackingEnabled()
    if not frame and not preview and not live then return end
    if not frame then
        frame = CreateVerticalSwordHost()
        self.VerticalSwordFrame = frame
    end
    local settings = iSTSettings
    local point = settings.verticalSwordPoint
    if not frame.positioned or frame.position ~= point then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", point and point[1] or 200, point and point[2] or 0)
        frame.positioned, frame.position = true, point
    end
    local height = math.max(80, math.min(280, tonumber(settings.verticalSwordHeight) or 176))
    local aspect = self:GetVerticalSwordAspectRatio(settings.verticalSwordStyle)
    if settings.verticalSwordMode == "PER_SEAL" then
        aspect = math.max(aspect, self:GetVerticalSwordAspectRatio(settings.verticalSwordSecondStyle))
    end
    local width = height * aspect
    if frame.height ~= height or frame.width ~= width then
        frame:SetSize(width, height)
        frame.width, frame.height = width, height
    end
    if frame.preview ~= preview then
        frame.handle:SetShown(preview == true)
        frame.handle:EnableMouse(preview == true and self:IsLayoutUnlocked())
        frame.preview = preview
        frame.previewEchoSeal = nil
    end
    if preview then
        count = count or 0
        if count == 0 then
            frame.previewEchoSeal = nil
        elseif not frame.previewEchoSeal then
            frame.previewEchoSeal = self.State.CurrentSealName == settings.twistIntoSeal
                and settings.twistIntoSeal or settings.twistFromSeal
        end
        local seal = frame.previewEchoSeal or settings.twistFromSeal
        if frame.previewSword then self:RenderAnimatedVerticalSword(frame.previewSword, seal, height, count)
        else self:RenderVerticalSword(frame.artwork, count, seal, height) end
        local artwork = frame.previewSword and frame.previewSword.base or frame.artwork
        local hasSeal = self:HasActiveSeal()
        local switchBack = EchoSwitchBackPending(self)
        local ready = count >= self:GetTwistStackTarget(seal)
        local phase = self:IsEchoSwitchPhase(seal)
        local status
        if not hasSeal or switchBack then status = "SWITCH"
        elseif ready and phase ~= nil then status = phase and "SWITCH" or "ACTIVE" end
        local warning = self:GetVerticalSwordWarningLayout(seal)
        if warning and not frame.previewWarning then
            frame.previewWarning = self:CreateVerticalSwordWarning(frame.handle, frame.handle)
        end
        if frame.previewWarning then
            self:RenderVerticalSwordWarning(frame.previewWarning, warning, height, status, artwork.swordOpacity)
        end
        if settings.showVerticalSwordSealGlow and not frame.previewHilt then
            frame.previewHilt = self:CreateVerticalSwordHiltGlow(frame.handle, frame.handle)
        end
        if frame.previewHilt then
            self:RenderVerticalSwordHiltGlow(frame.previewHilt, self:GetVerticalSwordHiltLayout(seal),
                height, hasSeal and (status or "ACTIVE") or nil, artwork.swordOpacity)
        end
    end

    if live and not frame.native and not frame.nativeFailed and NativeContainerReady() then
        if SwordFillInterpolation() and C_AuraContainerUtil
            and type(C_AuraContainerUtil.ProcessCustomAuraButtonApplicationBarOptions) == "function" then
            local container
            local ok, rows = pcall(function()
                container = CreateFrame("AuraContainer", nil, frame.liveLayer, "CustomAuraContainerTemplate")
                local builtRows = BuildAnimatedSwordContainer(frame, container)
                InitializeEmptySword(frame, container)
                container:SetEnabled(true)
                return builtRows
            end)
            if ok then
                frame.native, frame.rows, frame.animated = container, rows, true
            else
                if frame.emptyArtwork then
                    frame.emptyArtwork:Hide()
                    frame.emptyArtwork = nil
                end
                if container then pcall(container.Hide, container) end
                self:DebugMsg("Animated sword could not attach to the Echo buff: " .. tostring(rows), 2)
            end
        end
        if not frame.native and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
            local ok, native, rows = pcall(BuildStageContainer, frame.liveLayer, frame, function(clip, stage, seal, gate)
                local texture = self:CreateVerticalSwordArtwork(clip, frame)
                self:RenderVerticalSword(texture, stage, seal, frame.height)
                return { texture = texture, warningGate = gate }
            end, function(container) InitializeEmptySword(frame, container) end)
            if ok then
                frame.native, frame.rows = native, rows
            else
                frame.nativeFailed = true
                frame.liveLayer:Hide()
                self:DebugMsg("Vertical sword could not attach to the Echo buff: " .. tostring(native), 2)
            end
        end
    end
    if not frame.native then
        UpdateSwordLayerVisibility(frame, false, preview, confirmedEcho)
        return
    end
    -- Keep the native display ready through Edit Layout and combat transitions.
    if frame.nativeWanted ~= live then
        frame.liveLayer:SetShown(live)
        frame.nativeWanted = live
    end
    if not live then
        UpdateSwordLayerVisibility(frame, false, preview, confirmedEcho)
        return
    end
    local visualKey = table.concat({ settings.verticalSwordMode, settings.verticalSwordStyle, settings.verticalSwordSecondStyle,
        settings.twistFromSeal, settings.twistIntoSeal, settings.twistFromStacks, settings.twistIntoStacks,
        settings.verticalSwordOpacity, tostring(settings.showVerticalSwordPhaseMarker),
        tostring(settings.showVerticalSwordSealGlow), tostring(settings.fadeVerticalSwordGlow),
        settings.verticalSwordCorrectGlowScale, settings.verticalSwordWrongGlowScale, height }, ":")
    if frame.visualKey ~= visualKey then
        if frame.emptyArtwork then self:RenderVerticalSword(frame.emptyArtwork, 0, settings.twistFromSeal, height) end
        local emptyLayout = self:GetVerticalSwordWarningLayout(settings.twistFromSeal)
        if frame.emptyArtwork and emptyLayout and not frame.emptyWarning then
            frame.emptyWarning = CreateSwordWarningLayer(frame.liveLayer, frame)
            frame.emptyWarning.layer:SetFrameLevel(frame:GetFrameLevel() + 20)
            frame.emptyWarning.artwork.parent = CreateEmptySwordClip(frame, frame.native, frame.emptyWarning.layer)
        end
        if frame.emptyWarning then
            self:RenderVerticalSwordWarning(frame.emptyWarning.artwork, emptyLayout, height, "SWITCH",
                frame.emptyArtwork.swordOpacity)
        end
        if frame.emptyArtwork and settings.showVerticalSwordSealGlow then
            local layout = self:GetVerticalSwordHiltLayout(settings.twistFromSeal)
            ConfigureEmptySwordHilt(frame, "emptyActiveHilt", layout, "ACTIVE")
            ConfigureEmptySwordHilt(frame, "emptySwitchHilt", layout, "SWITCH")
        end
        for _, row in ipairs(frame.rows) do
            local target = self:GetTwistStackTarget(row.seal)
            if frame.animated then
                self:RenderAnimatedVerticalSword(row.sword, row.seal, height)
                if row.target ~= target then
                    local ok, err = pcall(BindVerticalSwordFill, row, target)
                    if not ok then self:DebugMsg("Sword fill target could not be updated: " .. tostring(err), 2) end
                end
            else
                self:RenderVerticalSword(row.texture, row.stage, row.seal, height)
            end
            local warning = self:GetVerticalSwordWarningLayout(row.seal)
            local bound = (warning or settings.showVerticalSwordSealGlow) and RefreshSwordPhaseThreshold(frame, row, target)
            local ready = bound and (not row.stage or row.stage >= target)
            ConfigureSwordWarnings(frame, row, height, ready, bound, warning)
            ConfigureSwordHiltGlows(frame, row, height, ready, bound)
        end
        frame.visualKey = visualKey
    end
    UpdateSwordLayerVisibility(frame, live, preview, confirmedEcho)
end

function iST:LayoutManagedStackReadout(initial)
    local bar = self.BarFrame
    if not bar or not bar.stackManagedRows or not bar.stackCountLayout then return end
    if CombatLocked() then
        self.State.PendingStackTypography = true
        return
    end
    self.State.PendingStackTypography = nil
    local layout = bar.stackCountLayout
    local function layoutRow(row)
        local button, count = row.button, row.count
        button:SetSize(layout.rowWidth, layout.rowHeight)
        count:SetFont(layout.fontPath, layout.fontSize, "THICKOUTLINE")
        count:ClearAllPoints()
        count:SetPoint("CENTER", button, "CENTER", 0, 0)
        count:SetSize(layout.rowWidth, layout.rowHeight)
        count:SetJustifyH("CENTER")
        if row.icon then
            row.icon:SetSize(layout.iconSize, layout.iconSize)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("RIGHT", button, "CENTER", layout.iconOffset, 0)
            row.icon:SetShown(iSTSettings.showStackCounterIcon)
        end
    end
    if initial then
        -- A slot is still editable while its own initialization callback runs.
        layoutRow(bar.stackManagedRows[#bar.stackManagedRows])
    else
        for _, row in ipairs(bar.stackManagedRows) do pcall(layoutRow, row) end
    end
end

function iST:CreateStackManagedDisplay()
    local bar = self.BarFrame
    if not bar or not self:IsWrathTrackingEnabled() or not iSTSettings.showStackCounter
        or bar.stackManagedContainerFailed or CombatLocked() then return end
    if bar.stackManagedContainer then
        self:UpdateStackManagedFilter()
        return
    end
    if not (C_AddOns and C_AddOns.LoadAddOn) and not C_AuraContainerUtil then
        self:DebugMsg("Stack display: WoW's aura container API is unavailable.", 2)
        return
    end

    local ok, container = pcall(function()
        if C_AddOns and C_AddOns.LoadAddOn and C_AddOns.IsAddOnLoaded
            and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
        assert(C_AuraContainerUtil, "Blizzard's custom aura container API is unavailable")
        local frame = CreateFrame("AuraContainer", nil, bar.stackCountFrame, "CustomAuraContainerTemplate")
        frame:SetAllPoints(bar.stackCountFrame)
        frame:EnableMouse(false)
        frame:SetFrameLevel(bar.stackCountFrame:GetFrameLevel() + 1)
        frame:SetUnit("player")
        local formatter = C_StringUtil and C_StringUtil.CreateAbbreviatedNumberFormatter
            and C_StringUtil.CreateAbbreviatedNumberFormatter() or nil
        bar.stackManagedSlots = {}
        bar.stackManagedRows = {}
        for _, spell in ipairs(self.WrathEchoSpells) do
            bar.stackManagedSlots[#bar.stackManagedSlots + 1] = {
                key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal,
            }
        end
        for _, slot in ipairs(bar.stackManagedSlots) do
            frame:AddAuraSlot(slot.key, "HELPFUL", {
                candidateFilters = StackSpellFilter(slot),
                initializeFrame = function(button)
                    button:SetSize(104, 26)
                    button:SetPoint("CENTER", button:GetParent(), "CENTER", 0, 0)
                    button:EnableMouse(false)

                    local count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    count:SetPoint("RIGHT", button, "CENTER", -4, 0)
                    count:SetSize(32, 26)
                    count:SetJustifyH("RIGHT")
                    count:SetJustifyV("MIDDLE")
                    count:SetShadowOffset(1, -1)
                    count:SetShadowColor(0, 0, 0, 1)

                    local icon
                    local texture = slot.seal and bar.stackSealIcons[slot.seal]
                    if texture then
                        icon = button:CreateTexture(nil, "OVERLAY")
                        icon:SetTexture(texture)
                        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        local mask = button:CreateMaskTexture()
                        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                        mask:SetAllPoints(icon)
                        icon:AddMaskTexture(mask)
                    end
                    bar.stackManagedRows[#bar.stackManagedRows + 1] = {
                        button = button, count = count, icon = icon,
                        seal = slot.seal,
                    }
                    self:LayoutManagedStackReadout(true)
                    button:SetApplicationCount(count, { formatter = NativeCountFormatter(
                        self:GetTwistStackTarget(slot.seal), self:GetTwistStackTargetLabel(slot.seal)) or formatter })
                end,
            })
        end
        frame:SetEnabled(true)
        return frame
    end)
    if ok then
        bar.stackManagedContainer = container
        bar.stackManagedContainerVisible = true
        bar.stackManagedFilterKey = StackFilterKey()
        self:ApplyStackCounterColor()
        self:ApplyStackStageFormatter()
        self:DebugMsg("Stack counter is using WoW's buff display.", 3)
    else
        bar.stackManagedContainerFailed = true
        self:DebugMsg("Stack counter failed: " .. tostring(container), 2)
    end
end

function iST:UpdateStackManagedFilter()
    local bar = self.BarFrame
    if not bar or not bar.stackManagedContainer or CombatLocked() then return end
    local filterKey = StackFilterKey()
    if bar.stackManagedFilterKey == filterKey then return end
    local allUpdated = true
    for _, slot in ipairs(bar.stackManagedSlots or {}) do
        local ok = pcall(bar.stackManagedContainer.SetAuraSlotCandidateFilters,
            bar.stackManagedContainer, slot.key, StackSpellFilter(slot))
        if not ok then
            allUpdated = false
            self:DebugMsg("Stack counter buff filter could not be updated.", 2)
        end
    end
    if allUpdated then bar.stackManagedFilterKey = filterKey end
end

function iST:UpdateStackCountDisplay(now, active, count)
    local bar = self.BarFrame
    if not bar or not bar.stackCountFrame then return end
    if bar.stackManagedContainer and not CombatLocked() then
        local shouldShow = active and not self.State.TestMode
        if bar.stackManagedContainerVisible ~= shouldShow then
            local ok = pcall(bar.stackManagedContainer.SetShown, bar.stackManagedContainer, shouldShow)
            if ok then bar.stackManagedContainerVisible = shouldShow end
        end
    end
    -- Live stack digits come from the native AuraContainer. The swing tracker
    -- is only used for the explicit preview mode.
    local visible = active and self:ShouldShowAuxiliaryCues()
        and (bar.stackManagedContainer ~= nil or self.State.TestMode)
    local shown = bar.stackCountFrame:IsShown()
    if not (issecretvalue and issecretvalue(shown)) and shown ~= visible then
        bar.stackCountFrame:SetShown(visible)
    end
    if not visible then return end
    local managed = bar.stackManagedContainer and not self.State.TestMode
    if managed then
        -- The aura button supplies a number only while an Echo buff exists.
        bar.stackCountValue:Hide()
        bar.stackCountTotal:Hide()
        return
    end
    if self.State.TestMode then
        bar.stackCountValue:SetShown(count > 0)
        bar.stackCountTotal:SetShown(count > 0)
        if count == 0 then return end
        bar.stackCountValue:SetText(count)
    end
end

function iST:UpdateSwingFillColor(previewColor)
    local fillColor = previewColor or self:GetBarFillColor()
    self.BarFrame.fill:SetVertexColor(fillColor.r, fillColor.g, fillColor.b,
        (fillColor.a or 1) * (self.State.Idle and 0.18 or 1))
end

function iST:UpdateWrathDisplay(now, confirmedEcho)
    local bar = self.BarFrame
    if not bar or not bar.stackCountFrame then return end
    now = now or GetTime()
    -- Previews supply their own count; drawing the cue does not change live stacks.
    local count, active = self:GetWrathDisplayState(now)
    count = math.max(0, math.min(3, math.floor(count or 0)))
    local color = self:GetWrathCueColor(count)
    self:UpdateStackCountDisplay(now, active and iSTSettings.showStackCounter, count)
    self:UpdateEchoTimerDisplay()
    self:UpdateNameplateEchoDisplay()
    if active and iSTSettings.showStackCounter and (not bar.stackManagedContainer or self.State.TestMode) then
        bar.stackCountValue:SetTextColor(color.r, color.g, color.b, color.a or 1)
        bar.stackCountTotal:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
    self:UpdateCenterSwitchText()
    self:UpdateEchoSwitchBackText()
    self:UpdateCenterSwitchSealGate()
    self:UpdateNativeStageVisuals()
    self:UpdateVerticalSword(count, confirmedEcho)
    self:LayoutStackPips()
    local nativeMain = bar.nativeStageMainVisible == true

    -- Stack colors belong on the fill for this cue. The other cues, and
    -- characters without the talent, keep the chosen normal bar color.
    local previewColor = active and self.State.TestMode and iSTSettings.showStackBarColor and color
    self:UpdateSwingFillColor(previewColor)
    local border = iSTSettings.borderNormalColor
    bar.artwork:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)

    local imagesVisible = active and self:UsesSwordImages()
        and (nativeMain or self.State.TestMode)
    self:UpdateSwordImageCue(bar, self.State.TestMode and count or 0, imagesVisible,
        self.State.TestMode and color or self:GetWrathCueColor(0),
        self:GetTwistStackTarget(iSTSettings.twistFromSeal))
    -- Leave room for the image sword's hilt, then restore the usual icon gap.
    local iconOffset = imagesVisible and -(bar.wrathSwordImages.leftOverhang + 7) or -7
    if bar.sealIconFrame and not iSTSettings.sealIconPoint and bar.wrathIconOffset ~= iconOffset then
        bar.sealIconFrame:ClearAllPoints()
        bar.sealIconFrame:SetPoint("RIGHT", bar, "LEFT", iconOffset, 0)
        bar.wrathIconOffset = iconOffset
    end
    local echoOffset = imagesVisible and (bar.wrathSwordImages.rightOverhang + 7) or 7
    if bar.echoTimerFrame and not iSTSettings.echoTimerPoint and bar.wrathEchoOffset ~= echoOffset then
        bar.echoTimerFrame:ClearAllPoints()
        bar.echoTimerFrame:SetPoint("LEFT", bar, "RIGHT", echoOffset, 0)
        bar.wrathEchoOffset = echoOffset
    end
    local textOffset = self:GetSwordImageTextOffset(bar, imagesVisible)
    if bar.wrathTextOffset ~= textOffset then
        bar.sealText:ClearAllPoints()
        bar.sealText:SetPoint("TOP", bar, "BOTTOM", 0, -textOffset)
        bar.latencyText:ClearAllPoints()
        bar.latencyText:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -2, -textOffset)
        bar.wrathTextOffset = textOffset
    end

    local circlesVisible = active and iSTSettings.showStackCircles
        and iSTSettings.stackBubbleStyle == "CIRCLES" and self.State.TestMode
    if circlesVisible then self:RenderStackBubbles(bar.wrathCircles,
        count, color, self:GetTwistStackTarget(iSTSettings.twistFromSeal)) end
    bar.wrathCircles:SetShown(circlesVisible)
    local iconStrip = bar.stackSealIconStrip
    if iconStrip then
        local nativeIcons = bar.nativeSealIconsMainVisible == true and not self.State.TestMode
        local source = iSTSettings.twistFromSeal
        local texture = source and bar.stackSealIcons[source]
        local showIcons = active and iSTSettings.showStackCircles
            and iSTSettings.stackBubbleStyle == "SEAL_ICONS" and not nativeIcons
            and self.State.TestMode and count > 0 and texture ~= nil
        iconStrip:SetShown(showIcons)
        if showIcons then self:RenderStackSealIcons(iconStrip, count, texture,
            self:GetTwistStackTarget(source)) end
    end
    self:UpdatePlayerWrathBubbles(now)
    if self.State.TestMode then self:LayoutStackPips() end
    if self.State.EditMode then self:UpdateMoveOutlines() end
end
