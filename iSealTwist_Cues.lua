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
    local readyColor = self:GetWrathCueColor(3)
    local function ColorText(fontString, color)
        if fontString then fontString:SetTextColor(color.r, color.g, color.b, color.a or 1) end
    end
    ColorText(bar.stackCountValue, baseColor)
    ColorText(bar.stackCountTotal, baseColor)
    for _, row in ipairs(bar.stackManagedRows or {}) do
        -- WoW colors the live digit through the native stack formatter.
        ColorText(row.count, { r = 1, g = 1, b = 1, a = 1 })
        ColorText(row.total, baseColor)
        if row.threeStackGate then ColorText(row.threeStackGate.text, readyColor) end
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
    if bar.wrathCueFrame then return end

    -- Keep the buff counter outside the bar so the bar can fade on its own.
    local stackFrame = CreateFrame("Frame", nil, UIParent)
    stackFrame:SetPoint("BOTTOM", bar, "TOP", 0, 9)
    stackFrame:SetSize(104, 26)
    stackFrame:SetFrameLevel(bar:GetFrameLevel() + 6)
    stackFrame:EnableMouse(false)
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

    -- The icon stays on our own frame. Blizzard owns the live buff counter,
    -- so its button cannot be changed safely during combat.
    local sourceFrame = CreateFrame("Frame", nil, UIParent)
    sourceFrame:SetSize(18, 18)
    sourceFrame:SetPoint("RIGHT", stackFrame, "CENTER", -40, 0)
    sourceFrame:SetFrameLevel(stackFrame:GetFrameLevel() + 2)
    sourceFrame:EnableMouse(false)
    sourceFrame:Hide()
    local sourceIcon = sourceFrame:CreateTexture(nil, "OVERLAY")
    sourceIcon:SetAllPoints(sourceFrame)
    sourceIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.stackSourceIconFrame, bar.stackSourceIcon = sourceFrame, sourceIcon
    bar.stackSealIcons = {}
    for seal, spellID in pairs(self.SEAL_SPELL_IDS) do
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and texture and not (issecretvalue and issecretvalue(texture)) then
            bar.stackSealIcons[seal] = texture
        end
    end

    local cueFrame = CreateFrame("Frame", nil, bar)
    cueFrame:SetPoint("BOTTOM", bar, "TOP", 0, 9)
    cueFrame:SetHeight(24)
    cueFrame:SetFrameLevel(bar:GetFrameLevel() + 4)
    cueFrame:EnableMouse(false)
    cueFrame:Hide()
    bar.wrathCueFrame = cueFrame

    local text = cueFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", cueFrame, "CENTER")
    text:SetText("")
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    bar.wrathCueText = text
    self:CreateSwordImageCue(bar)
    bar.wrathCircles = self:CreateStackBubbles(bar, nil, 18, 9)
    bar.wrathCircles:SetPoint("BOTTOM", bar, "TOP", 0, 7)
    bar.wrathCircles:SetFrameLevel(bar:GetFrameLevel() + 4)
    self:ApplyWrathCircleSize()
    self:CreatePlayerWrathFrame()
    self:ApplyStackCounterColor()
end

function iST:ApplyWrathCircleSize()
    local bar = self.BarFrame
    if not bar then return end
    if CombatLocked() then
        self.State.PendingWrathCircleSize = true
        return
    end
    local size = math.max(10, math.min(40, tonumber(iSTSettings.wrathCircleSize) or 18))
    local scale = size / 18
    if bar.wrathCircles then bar.wrathCircles:SetScale(scale) end
    for _, row in ipairs(bar.nativeStageMainRows or {}) do
        if row.circles then row.circles:SetScale(scale) end
    end
    self.State.PendingWrathCircleSize = nil
end

local function StackSpellFilter(slot)
    local fake = iSTSettings.fakeUnsealedWrath
    local spellIDs = {}
    if slot.fake and fake then
        spellIDs[20050] = true
        local learnedID = iSTSettings.vengeanceDisplaySpellID
        if type(learnedID) == "number" and learnedID > 0 then spellIDs[learnedID] = true end
    elseif not slot.fake and not fake then
        spellIDs[slot.spellID] = true
    end
    return { includeSpellIDs = spellIDs }
end

local function StackFilterKey()
    if not iSTSettings.fakeUnsealedWrath then return "echo" end
    return "vengeance:" .. tostring(iSTSettings.vengeanceDisplaySpellID or 20050)
end

local function AllStackSpellFilter()
    if iSTSettings.fakeUnsealedWrath then
        return StackSpellFilter({ fake = true })
    end
    local spellIDs = {}
    for _, spell in ipairs(iST.WrathEchoSpells) do spellIDs[spell.id] = true end
    return { includeSpellIDs = spellIDs }
end

local function CenterMessageFormatter(message)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "" },
        { threshold = 3, format = message },
    }) then return formatter end
end

function iST:UpdateCenterSwitchSealGate()
    local frame = self.CenterSwitchFrame
    if not frame or not frame.phaseFrames or self.State.CenterSwitchPhaseBlocked then return end
    local current = self.State.CurrentSealName
    local cast = self.State.WrathLastSealCastName
    local source
    if iSTSettings.fakeUnsealedWrath then
        source = self.WrathTracker.seal
    else
        source = self.State.WrathEchoSeal or self.State.WrathLastSwitchFrom or self.WrathTracker.seal
    end
    if (issecretvalue and (issecretvalue(current) or issecretvalue(cast)
        or issecretvalue(source))) then return end
    if frame.gateSeal == current and frame.gateCast == cast
        and frame.gateSource == source
        and frame.gateMoving == frame.moving then return end
    local switched = source and current and current ~= source and cast == current
    local phase = switched and "attack" or "switch"
    for _, name in ipairs({ "switch", "attack" }) do
        -- These are our plain parent frames. Blizzard's aura buttons and their
        -- FontStrings are forbidden to addon code during combat.
        local parent = frame.phaseFrames[name]
        local alpha = not frame.moving and phase == name and 1 or 0
        local accessible, forbidden = pcall(function()
            return type(parent.IsForbidden) == "function" and parent:IsForbidden() or false
        end)
        if not accessible or forbidden then
            self.State.CenterSwitchPhaseBlocked = true
            self:DebugMsg("The center message phase frame is unavailable during combat.", 2)
            return
        end
        local ok = pcall(function() parent:SetAlpha(alpha) end)
        if not ok then
            self.State.CenterSwitchPhaseBlocked = true
            self:DebugMsg("The center message could not change phases during combat.", 2)
            return
        end
    end
    frame.gateSeal, frame.gateCast = current, cast
    frame.gateSource, frame.gateMoving = source, frame.moving
end

function iST:SetCenterSwitchMoveMode(enabled)
    if enabled and CombatLocked() then return end
    if enabled and not self.CenterSwitchFrame then self:UpdateCenterSwitchText(true) end
    local frame = self.CenterSwitchFrame
    if not frame then return end
    frame.moving = enabled == true
    frame:EnableMouse(frame.moving)
    frame.preview:SetShown(frame.moving)
    frame.moveBackdrop:SetShown(frame.moving)
    if CombatLocked() then
        frame.restoreStrata = true
        return
    end
    if frame.moving then
        frame:SetFrameStrata("DIALOG")
    else
        frame:StopMovingOrSizing()
        frame:SetFrameStrata("MEDIUM")
    end
    self:UpdateCenterSwitchText()
end

function iST:UpdateCenterSwitchText(forceCreate)
    if CombatLocked() then return end
    local frame = self.CenterSwitchFrame
    local wanted = self:ShouldShowBar() and self:IsWrathTrackingEnabled()
        and iSTSettings.showCenterSwitchText
    if frame and frame.restoreStrata then
        frame:SetFrameStrata("MEDIUM")
        frame.restoreStrata = nil
    end
    if not wanted and not forceCreate and not (frame and frame.moving) then
        if frame then frame:Hide() end
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
            host:SetScript("OnDragStart", function(self)
                if self.moving and not CombatLocked() then self:StartMoving() end
            end)
            host:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local point, _, relativePoint, x, y = self:GetPoint()
                iSTSettings.centerSwitchPoint = { point, nil, relativePoint, x, y }
            end)
            host:RegisterForDrag("LeftButton")
            host.moveBackdrop = host:CreateTexture(nil, "BACKGROUND")
            host.moveBackdrop:SetAllPoints(host)
            host.moveBackdrop:SetColorTexture(0.10, 0.07, 0.025, 0.75)
            host.moveBackdrop:Hide()
            host.preview = host:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            host.preview:SetAllPoints(host)
            host.preview:SetJustifyH("CENTER")
            host.preview:Hide()

            host.rows, host.slots = {}, {}
            host.phaseFrames, host.phaseContainers = {}, {}
            for _, spell in ipairs(self.WrathEchoSpells) do
                host.slots[#host.slots + 1] = { key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal }
            end
            host.slots[#host.slots + 1] = { key = "vengeance", fake = true }
            for _, phase in ipairs({ "switch", "attack" }) do
                local phaseName = phase
                local phaseFrame = CreateFrame("Frame", nil, host)
                phaseFrame:SetAllPoints(host)
                phaseFrame:SetAlpha(phaseName == "switch" and 1 or 0)
                host.phaseFrames[phaseName] = phaseFrame
                local container = CreateFrame("AuraContainer", nil, phaseFrame, "CustomAuraContainerTemplate")
                container:SetAllPoints(phaseFrame)
                container:SetUnit("player")
                host.phaseContainers[phaseName] = container
                for _, slot in ipairs(host.slots) do
                    local slotInfo = slot
                    container:AddAuraSlot(slotInfo.key, "HELPFUL", {
                        candidateFilters = StackSpellFilter(slotInfo),
                        initializeFrame = function(button)
                            button:SetAllPoints(phaseFrame)
                            button:EnableMouse(false)
                            local message = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                            message:SetAllPoints(button)
                            message:SetJustifyH("CENTER")
                            message:SetJustifyV("MIDDLE")
                            message:SetShadowOffset(2, -2)
                            message:SetShadowColor(0, 0, 0, 1)
                            message:SetFont(self:GetBarFontPath(), 32, "THICKOUTLINE")
                            local readyColor = self:GetWrathCueColor(3)
                            message:SetTextColor(readyColor.r, readyColor.g, readyColor.b,
                                readyColor.a or 1)
                            local text = phaseName == "attack" and (iSTSettings.centerAttackText or L["WrathAttackNow"])
                                or (iSTSettings.centerSwitchText or "Switch now")
                            button:SetApplicationCount(message,
                                { formatter = assert(CenterMessageFormatter(text)) })
                            host.rows[#host.rows + 1] = {
                                button = button, message = message, phase = phaseName,
                                seal = slotInfo.seal, fake = slotInfo.fake,
                            }
                        end,
                    })
                end
                container:SetEnabled(true)
            end
            return host
        end)
        if not ok then
            self.State.CenterSwitchFailed = true
            self:DebugMsg("Three-stack message could not be shown: " .. tostring(result), 2)
            return
        end
        frame = result
        self.CenterSwitchFrame = frame
    end
    local filterKey = StackFilterKey()
    if frame.filterKey ~= filterKey then
        local updated = true
        for _, slot in ipairs(frame.slots) do
            for _, phase in ipairs({ "switch", "attack" }) do
                local container = frame.phaseContainers[phase]
                if not pcall(container.SetAuraSlotCandidateFilters, container,
                    slot.key, StackSpellFilter(slot)) then updated = false end
            end
        end
        if updated then frame.filterKey = filterKey end
    end
    local phrase = iSTSettings.centerSwitchText or "Switch now"
    local attackPhrase = iSTSettings.centerAttackText or L["WrathAttackNow"]
    if frame.switchPhrase ~= phrase or frame.attackPhrase ~= attackPhrase then
        local switchFormatter = frame.switchPhrase ~= phrase and CenterMessageFormatter(phrase)
        local attackFormatter = frame.attackPhrase ~= attackPhrase and CenterMessageFormatter(attackPhrase)
        local switchUpdated = frame.switchPhrase == phrase or switchFormatter ~= nil
        local attackUpdated = frame.attackPhrase == attackPhrase or attackFormatter ~= nil
        for _, row in ipairs(frame.rows) do
            local formatter
            if row.phase == "switch" then formatter = switchFormatter else formatter = attackFormatter end
            if formatter and not pcall(row.button.SetApplicationCount,
                row.button, row.message, { formatter = formatter }) then
                if row.phase == "switch" then switchUpdated = false else attackUpdated = false end
            end
        end
        if switchUpdated then frame.switchPhrase = phrase end
        if attackUpdated then frame.attackPhrase = attackPhrase end
    end
    local color = self:GetWrathCueColor(3)
    local font = self:GetBarFontPath()
    local colorKey = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
    if frame.font ~= font or frame.colorKey ~= colorKey then
        for _, row in ipairs(frame.rows) do
            row.message:SetFont(font, 32, "THICKOUTLINE")
            row.message:SetTextColor(color.r, color.g, color.b, color.a or 1)
        end
        frame.font, frame.colorKey = font, colorKey
    end
    if frame.previewFont ~= font then
        frame.preview:SetFont(font, 32, "THICKOUTLINE")
        frame.previewFont = font
    end
    if frame.previewPhrase ~= phrase then frame.preview:SetText(phrase); frame.previewPhrase = phrase end
    if frame.previewColorKey ~= colorKey then
        frame.preview:SetTextColor(color.r, color.g, color.b, color.a or 1)
        frame.previewColorKey = colorKey
    end
    local visible = wanted or frame.moving
    if frame:IsShown() ~= visible then frame:SetShown(visible) end
    self:UpdateCenterSwitchSealGate()
end

local function NativeCountFormatter()
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local points = { { threshold = 0, format = "" } }
    for stage = 1, 3 do
        local color = iST:GetWrathCueColor(stage)
        local code = string.format("|c%02x%02x%02x%02x", math.floor((color.a or 1) * 255 + 0.5),
            math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5))
        points[#points + 1] = { threshold = stage, format = code .. "%d|r" }
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
    local formatter = NativeCountFormatter()
    if not formatter then return end
    local allUpdated = true
    for _, row in ipairs(bar.stackManagedRows) do
        if row.button and row.count then
            local ok = pcall(row.button.SetApplicationCount, row.button, row.count, { formatter = formatter })
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

local function ReadyGateFormatter()
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "" },
        { threshold = 3, format = string.rep("W", 70) },
    }) then return formatter end
end

function iST:UpdateNativeReadyDisplay()
    local bar = self.BarFrame
    if not bar or CombatLocked() then return end
    local wanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and iSTSettings.showThreeStackReadyText and iSTSettings.wrathCue ~= "OFF"
    if not wanted then
        if bar.nativeReadyContainer then bar.nativeReadyContainer:Hide() end
        return
    end
    if not NativeContainerReady() then return end
    if bar.nativeReadyFailed then return end
    if not bar.nativeReadyContainer then
        local formatter = ReadyGateFormatter()
        if not formatter then
            bar.nativeReadyFailed = true
            return
        end
        local ok, result = pcall(function()
            local frame = CreateFrame("AuraContainer", nil, bar, "CustomAuraContainerTemplate")
            frame:SetSize(250, 32)
            frame:SetPoint("BOTTOM", bar, "TOP", 0, 35)
            frame:SetFrameLevel(bar:GetFrameLevel() + 7)
            frame:SetUnit("player")
            frame:AddAuraSlot("ready", "HELPFUL", {
                candidateFilters = AllStackSpellFilter(),
                initializeFrame = function(button)
                    button:SetAllPoints(frame)
                    button:EnableMouse(false)
                    -- The native count changes this hidden text's width. Its clip
                    -- reveals the fixed message only when the buff has 3 stacks.
                    local gate = button:CreateFontString(nil, "BACKGROUND")
                    gate:SetFont(STANDARD_TEXT_FONT, 64, "")
                    gate:SetWordWrap(false)
                    gate:SetWidth(0)
                    gate:SetPoint("LEFT", button, "LEFT")
                    gate:SetAlpha(0)
                    gate:SetTextColor(0, 0, 0, 0)
                    local clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
                    clip:SetClipsChildren(true)
                    clip:EnableMouse(false)
                    clip:SetPoint("LEFT", button, "LEFT")
                    clip:SetPoint("RIGHT", gate, "RIGHT")
                    clip:SetPoint("TOP", button, "TOP")
                    clip:SetPoint("BOTTOM", button, "BOTTOM")
                    local text = clip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                    text:SetAllPoints(button)
                    text:SetJustifyH("CENTER")
                    text:SetFont(self:GetBarFontPath(), iSTSettings.stackCounterTextSize or 16, "THICKOUTLINE")
                    text:SetTextColor(1, 0.78, 0.24, 1)
                    text:SetText(iSTSettings.wrathReadyText or "Switch now")
                    button:SetApplicationCount(gate, { formatter = formatter })
                    bar.nativeReadyButton, bar.nativeReadyText = button, text
                    bar.nativeReadyGate, bar.nativeReadyClip = gate, clip
                end,
            })
            frame:SetEnabled(true)
            return frame
        end)
        if not ok then
            bar.nativeReadyFailed = true
            self:DebugMsg("Three-stack message could not be attached to the buff: " .. tostring(result), 2)
            return
        end
        bar.nativeReadyContainer = result
        bar.nativeReadyFilterKey = StackFilterKey()
        bar.nativeReadyMessage = iSTSettings.wrathReadyText
        for _, row in ipairs(bar.stackManagedRows or {}) do self:ApplyThreeStackGate(row) end
    end
    if bar.nativeReadyFilterKey ~= StackFilterKey() then
        local ok = pcall(bar.nativeReadyContainer.SetAuraSlotCandidateFilters,
            bar.nativeReadyContainer, "ready", AllStackSpellFilter())
        if ok then bar.nativeReadyFilterKey = StackFilterKey() end
    end
    if bar.nativeReadyMessage ~= iSTSettings.wrathReadyText and bar.nativeReadyText then
        bar.nativeReadyText:SetText(iSTSettings.wrathReadyText or "Switch now")
        bar.nativeReadyMessage = iSTSettings.wrathReadyText
    end
    if bar.nativeReadyText then
        local font, size = self:GetBarFontPath(), iSTSettings.stackCounterTextSize or 16
        if bar.nativeReadyFont ~= font or bar.nativeReadySize ~= size then
            bar.nativeReadyText:SetFont(font, size, "THICKOUTLINE")
            bar.nativeReadyFont, bar.nativeReadySize = font, size
        end
        local color = self:GetWrathCueColor(3)
        local colorKey = table.concat({color.r, color.g, color.b, color.a or 1}, ":")
        if bar.nativeReadyColorKey ~= colorKey then
            bar.nativeReadyText:SetTextColor(color.r, color.g, color.b, color.a or 1)
            bar.nativeReadyColorKey = colorKey
        end
    end
    if not bar.nativeReadyContainer:IsShown() then bar.nativeReadyContainer:Show() end
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
    return clip
end

local function BuildStageContainer(parent, host, build)
    local frame = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    frame:SetAllPoints(host)
    frame:SetUnit("player")
    local rows = {}
    for stage = 1, 3 do
        local index = stage
        frame:AddAuraSlot("stage" .. index, "HELPFUL", {
            candidateFilters = AllStackSpellFilter(),
            initializeFrame = function(button)
                local clip = CreateStageButton(button, host, index)
                rows[index] = build(clip, index)
                if iST.BarFrame then iST.BarFrame.nativeStageVisualKey = nil end
            end,
        })
    end
    frame:SetEnabled(true)
    return frame, rows
end

function iST:UpdateNativeStageVisuals()
    local bar = self.BarFrame
    if not bar or CombatLocked() then return end
    local style = iSTSettings.wrathCue
    local mainWanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and (style == "BAR_COLOR" or style == "SWORD_IMAGES" or style == "CIRCLES")
    local playerWanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and iSTSettings.showPlayerWrathBubbles
    if not mainWanted and not playerWanted
        and not bar.nativeStageMain and not bar.nativeStagePlayer then return end
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    if not NativeContainerReady() then return end
    if mainWanted and not bar.nativeStageMain and not bar.nativeStageFailed then
        local ok, frame, rows = pcall(BuildStageContainer, bar, bar, function(clip, stage)
            local overlay = clip:CreateTexture(nil, "ARTWORK")
            overlay:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
            overlay:SetAllPoints(bar.fill)
            local sword = self:CreateNativeSwordStage(bar, clip, stage)
            local circles = self:CreateStackBubbles(clip, nil, 18, 9)
            circles:SetPoint("BOTTOM", bar, "TOP", 0, 7)
            return { overlay = overlay, sword = sword, circles = circles }
        end)
        if ok then
            bar.nativeStageMain, bar.nativeStageMainRows = frame, rows
            bar.nativeStageMainKey = StackFilterKey()
            frame:Hide()
            bar.nativeStageMainVisible = false
            bar.nativeStageVisualKey = nil
            self:ApplyWrathCircleSize()
            if not bar.nativeStageTextLayer then
                local textLayer = CreateFrame("Frame", nil, bar)
                textLayer:SetAllPoints(bar)
                textLayer:SetFrameLevel(bar:GetFrameLevel() + 20)
                for _, label in ipairs({ bar.timeText, bar.speedText, bar.latencyText, bar.sealText }) do
                    if label then label:SetParent(textLayer) end
                end
                bar.nativeStageTextLayer = textLayer
            end
        else
            bar.nativeStageFailed = true
            self:DebugMsg("Stack graphics could not attach to the buff: " .. tostring(frame), 2)
        end
    end
    if playerWanted and self.PlayerWrathFrame and not bar.nativeStagePlayer and not bar.nativePlayerStageFailed then
        local ok, frame, rows = pcall(BuildStageContainer, self.PlayerWrathFrame,
            self.PlayerWrathFrame, function(clip, stage)
                local bubbles = self:CreateStackBubbles(clip, nil, 19, 10)
                bubbles:SetPoint("CENTER", self.PlayerWrathFrame, "CENTER")
                return { bubbles = bubbles }
            end)
        if ok then
            bar.nativeStagePlayer, bar.nativeStagePlayerRows = frame, rows
            bar.nativeStagePlayerKey = StackFilterKey()
            frame:Hide()
            bar.nativeStagePlayerVisible = false
            bar.nativeStageVisualKey = nil
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
            for stage = 1, 3 do
                if not pcall(frame.SetAuraSlotCandidateFilters, frame,
                    "stage" .. stage, AllStackSpellFilter()) then updated = false end
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
    local visualParts = { tostring(style), tostring(iSTSettings.wrathColorScheme),
        tostring(bar:GetWidth()), tostring(bar:GetHeight()) }
    for stage = 0, 3 do
        local color = self:GetWrathCueColor(stage)
        visualParts[#visualParts + 1] = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
    end
    local visualKey = table.concat(visualParts, ":")
    if bar.nativeStageVisualKey == visualKey then return end
    bar.nativeStageVisualKey = visualKey
    if bar.nativeStageMain then
        for stage, row in ipairs(bar.nativeStageMainRows or {}) do
            local color = self:GetWrathCueColor(stage)
            row.overlay:SetVertexColor(color.r, color.g, color.b, color.a or 1)
            row.overlay:SetShown(style == "BAR_COLOR")
            self:UpdateNativeSwordStage(bar, row.sword, color)
            row.sword:SetShown(style == "SWORD_IMAGES")
            self:RenderStackBubbles(row.circles, stage, color)
            row.circles:SetShown(style == "CIRCLES")
        end
    end
    if bar.nativeStagePlayer then
        for stage, row in ipairs(bar.nativeStagePlayerRows or {}) do
            self:RenderStackBubbles(row.bubbles, stage, self:GetWrathCueColor(stage))
            row.bubbles:Show()
        end
    end
end

local function LayoutThreeStackGate(row)
    local button, gate = row.button, row.threeStackGate
    if not gate then return end
    local layout = iST.BarFrame and iST.BarFrame.stackCountLayout
    if not layout then return end
    local margin = 6
    local fontSize = iSTSettings.stackCounterTextSize or 16
    local readyHeight = fontSize + 8
    -- The aura button's size can be secret even after combat. Use our own layout.
    local step = math.max(layout.rowWidth + margin * 2, fontSize * 11, 180)
    gate.bar:ClearAllPoints()
    gate.bar:SetSize(step * 3, layout.rowHeight + margin * 2 + readyHeight + 6)
    gate.bar:SetPoint("BOTTOMLEFT", button, "BOTTOM", -step * 2.5, -margin)
    gate.clip:ClearAllPoints()
    gate.clip:SetPoint("TOPLEFT", gate.bar, "TOPLEFT", step * 2, 0)
    gate.clip:SetPoint("BOTTOMRIGHT", gate.bar:GetStatusBarTexture(), "BOTTOMRIGHT")
    gate.text:SetSize(step - 4, readyHeight)
    gate.text:SetFont(iST:GetBarFontPath(), fontSize, "THICKOUTLINE")
    gate.text:SetText(iSTSettings.wrathReadyText or "Switch now")
end

local function ShowThreeStackChoices(row)
    local gate = row.threeStackGate
    if not gate then return end
    gate.text:SetShown(iSTSettings.showThreeStackReadyText and not iST.BarFrame.nativeReadyContainer)
    gate.clip:Show()
end

function iST:ApplyThreeStackGate(row)
    if CombatLocked() then return end
    if not iSTSettings.showThreeStackReadyText or self.BarFrame.nativeReadyContainer then
        if row.threeStackGate then row.threeStackGate.clip:Hide() end
        return
    end
    if row.threeStackGateFailed then return end
    if row.threeStackGate then
        LayoutThreeStackGate(row)
        ShowThreeStackChoices(row)
        return
    end
    if not (C_AuraContainerUtil and C_AuraContainerUtil.ProcessCustomAuraButtonApplicationBarOptions)
        or type(row.button.SetApplicationBar) ~= "function" then
        row.threeStackGateFailed = true
        if not self.BarFrame.threeStackGateWarningShown then
            self.BarFrame.threeStackGateWarningShown = true
            self:DebugMsg("Three-stack ready message is unavailable on this client; the counter still works.", 2)
        end
        return
    end

    local clip
    local ok, err = pcall(function()
        local button = row.button
        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetAlpha(0)
        clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
        clip:SetClipsChildren(true)
        clip:EnableMouse(false)
        local text = clip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        text:SetPoint("BOTTOM", button, "TOP", 0, 4)
        text:SetJustifyH("CENTER")
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)
        local color = self:GetWrathCueColor(3)
        text:SetTextColor(color.r, color.g, color.b, color.a or 1)
        row.threeStackGate = { bar = bar, clip = clip, text = text }
        LayoutThreeStackGate(row)
        button:SetApplicationBar(bar, { maxApplications = 3 })
    end)
    if not ok then
        row.threeStackGate = nil
        row.threeStackGateFailed = true
        if clip then clip:Hide() end
        if not self.BarFrame.threeStackGateWarningShown then
            self.BarFrame.threeStackGateWarningShown = true
            self:DebugMsg("Three-stack ready message could not bind to the buff: " .. tostring(err), 2)
        end
    else
        ShowThreeStackChoices(row)
    end
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
        local button, count, total = row.button, row.count, row.total
        button:SetSize(layout.rowWidth, layout.rowHeight)
        count:SetFont(layout.fontPath, layout.fontSize, "THICKOUTLINE")
        total:SetFont(layout.fontPath, layout.fontSize, "THICKOUTLINE")
        count:ClearAllPoints()
        count:SetPoint("RIGHT", button, "CENTER", -4, 0)
        count:SetSize(layout.countWidth, layout.rowHeight)
        count:SetJustifyH("RIGHT")
        total:ClearAllPoints()
        total:SetPoint("LEFT", button, "CENTER", 0, 0)
        total:SetSize(layout.totalWidth, layout.rowHeight)
        total:SetJustifyH("LEFT")
        LayoutThreeStackGate(row)
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
    if not bar or not self:IsWrathTrackingEnabled() or iSTSettings.wrathCue ~= "COUNTER"
        or bar.stackManagedContainerFailed or CombatLocked() then return end
    if bar.stackManagedContainer then
        self:UpdateStackManagedFilter()
        for _, row in ipairs(bar.stackManagedRows or {}) do self:ApplyThreeStackGate(row) end
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
        frame:SetFrameLevel(bar.stackCountFrame:GetFrameLevel() + 1)
        frame:SetUnit("player")
        local formatter = C_StringUtil and C_StringUtil.CreateAbbreviatedNumberFormatter
            and C_StringUtil.CreateAbbreviatedNumberFormatter() or nil
        bar.stackManagedSlots = {}
        bar.stackManagedRows = {}
        bar.stackManagedTexts = {}
        bar.stackManagedButtons = {}
        for _, spell in ipairs(self.WrathEchoSpells) do
            bar.stackManagedSlots[#bar.stackManagedSlots + 1] = {
                key = "echo" .. spell.id, spellID = spell.id,
            }
        end
        bar.stackManagedSlots[#bar.stackManagedSlots + 1] = { key = "vengeance", fake = true }
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

                    local total = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    total:SetPoint("LEFT", button, "CENTER", 0, 0)
                    total:SetSize(64, 26)
                    total:SetShadowOffset(1, -1)
                    total:SetShadowColor(0, 0, 0, 1)
                    total:SetText("/ 3")
                    bar.stackManagedRows[#bar.stackManagedRows + 1] = {
                        button = button, count = count, total = total,
                    }
                    bar.stackManagedTexts[#bar.stackManagedTexts + 1] = count
                    bar.stackManagedTexts[#bar.stackManagedTexts + 1] = total
                    bar.stackManagedButtons[#bar.stackManagedButtons + 1] = button
                    self:LayoutManagedStackReadout(true)
                    button:SetApplicationCount(count, { formatter = NativeCountFormatter() or formatter })
                    self:ApplyThreeStackGate(bar.stackManagedRows[#bar.stackManagedRows])
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

function iST:RefreshVengeanceStackAura(updateInfo)
    if not iSTSettings.fakeUnsealedWrath then return end
    if self.BarFrame and self.BarFrame.stackManagedContainer and CombatLocked() then return end
    local state = self.State
    local function IsSecret(value)
        return issecretvalue and issecretvalue(value) or false
    end
    if not IsSecret(updateInfo) and type(updateInfo) == "table" then
        local added = updateInfo.addedAuras
        if not IsSecret(added) and type(added) == "table" then
            for _, aura in ipairs(added) do
                if not IsSecret(aura) and type(aura) == "table" then
                    local name, instanceID = aura.name, aura.auraInstanceID
                    if not IsSecret(name) and name == "Vengeance"
                        and not IsSecret(instanceID) and type(instanceID) == "number" then
                        if state.VengeanceStackAuraID ~= instanceID then
                            self:DebugMsg("Vengeance stack display found its buff.", 3)
                        end
                        state.VengeanceStackAuraID = instanceID
                        break
                    end
                end
            end
        end
        local removed = updateInfo.removedAuraInstanceIDs
        if not IsSecret(removed) and type(removed) == "table" then
            for _, instanceID in ipairs(removed) do
                if not IsSecret(instanceID) and instanceID == state.VengeanceStackAuraID then
                    state.VengeanceStackAuraID = nil
                    break
                end
            end
        end
    end
    local reader = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if type(reader) ~= "function" then return end
    local ok, aura = pcall(reader, "player", "Vengeance", "HELPFUL")
    if not ok or IsSecret(aura) or type(aura) ~= "table" then return end
    local instanceID, spellID = aura.auraInstanceID, aura.spellId
    if not IsSecret(instanceID) and type(instanceID) == "number" then
        if state.VengeanceStackAuraID ~= instanceID then
            self:DebugMsg("Vengeance stack display found its buff.", 3)
        end
        state.VengeanceStackAuraID = instanceID
    end
    if not IsSecret(spellID) and type(spellID) == "number" and spellID > 0
        and iSTSettings.vengeanceDisplaySpellID ~= spellID then
        iSTSettings.vengeanceDisplaySpellID = spellID
        self:UpdateStackManagedFilter()
        self:DebugMsg("Vengeance buff spell ID recorded for the stack display: " .. spellID .. ".", 3)
    end
end

function iST:UpdateStackCountDisplay(now, active, count)
    local bar = self.BarFrame
    if not bar or not bar.stackCountFrame then return end
    now = now or GetTime()
    if bar.stackManagedContainer and not CombatLocked() then
        local shouldShow = active and not self.State.TestMode
        if bar.stackManagedContainerVisible ~= shouldShow then
            local ok = pcall(bar.stackManagedContainer.SetShown, bar.stackManagedContainer, shouldShow)
            if ok then bar.stackManagedContainerVisible = shouldShow end
        end
    end
    local visible = active and self:ShouldShowBar()
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
        return
    end
    local instanceID
    if iSTSettings.fakeUnsealedWrath then instanceID = self.State.VengeanceStackAuraID
    else instanceID = self.State.WrathAuraInstanceID end
    local showCount = count > 0 or type(instanceID) == "number"
    bar.stackCountValue:SetShown(showCount)
    bar.stackCountTotal:SetShown(showCount)
    if not showCount then return end
    if bar.nextStackCountDisplay and now < bar.nextStackCountDisplay then return end
    bar.nextStackCountDisplay = now + 0.1

    local displayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount
    if type(instanceID) == "number" and type(displayCount) == "function" then
        local maximum = iSTSettings.fakeUnsealedWrath and 5 or 3
        local ok, display = pcall(displayCount, "player", instanceID, 1, maximum)
        if ok then
            -- The string may be secret in combat. Pass it straight to the text widget.
            bar.stackCountValue:SetText(display)
            bar.stackCountDisplayFailed = nil
            return
        end
        if not bar.stackCountDisplayFailed then
            self:DebugMsg("Stack display could not read the buff count; showing ?.", 2)
            bar.stackCountDisplayFailed = true
        end
        if iSTSettings.fakeUnsealedWrath then self.State.VengeanceStackAuraID = nil end
    end

    if not iSTSettings.fakeUnsealedWrath and not self.WrathTracker.countUnconfirmed then
        bar.stackCountValue:SetText(count)
    else
        bar.stackCountValue:SetText("?")
    end
end

function iST:UpdateStackSourceIcon(active, count)
    local bar = self.BarFrame
    local frame = bar and bar.stackSourceIconFrame
    if not frame then return end
    if not active or iSTSettings.wrathCue ~= "COUNTER" or self.State.TestMode
        or not self:ShouldShowBar() or count < 1 or count > 3 then
        if frame:IsShown() then frame:Hide() end
        return
    end
    local fake = iSTSettings.fakeUnsealedWrath
    local source
    if fake then
        source = self.WrathTracker.seal or self.State.CurrentSealName
    else
        source = self.State.WrathEchoSeal or self.WrathTracker.seal
    end
    if issecretvalue and issecretvalue(source) then
        if frame:IsShown() then frame:Hide() end
        return
    end
    local texture = source and bar.stackSealIcons[source]
    if not texture then
        if frame:IsShown() then frame:Hide() end
        return
    end
    if bar.stackSourceTexture ~= texture then
        bar.stackSourceIcon:SetTexture(texture)
        bar.stackSourceTexture = texture
    end
    if not frame:IsShown() then frame:Show() end
end

function iST:UpdateWrathDisplay(now)
    local bar = self.BarFrame
    if not bar or not bar.wrathCueFrame then return end
    now = now or GetTime()
    -- Previews supply their own count; drawing the cue does not change live stacks.
    local count, active, armed = self:GetWrathDisplayState(now)
    count = math.max(0, math.min(3, math.floor(count or 0)))
    local style = iSTSettings.wrathCue or "COUNTER"
    local color = self:GetWrathCueColor(count)
    self:UpdateStackCountDisplay(now, active and style == "COUNTER", count)
    self:UpdateStackSourceIcon(active, count)
    if active and style == "COUNTER" and (not bar.stackManagedContainer or self.State.TestMode) then
        bar.stackCountValue:SetTextColor(color.r, color.g, color.b, color.a or 1)
        bar.stackCountTotal:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
    self:UpdateNativeReadyDisplay()
    self:UpdateCenterSwitchText()
    self:UpdateCenterSwitchSealGate()
    self:UpdateNativeStageVisuals()
    local nativeMain = bar.nativeStageMainVisible == true

    -- Stack colors belong on the fill for this cue. The other cues, and
    -- characters without the talent, keep the chosen normal bar color.
    local fillColor = active and style == "BAR_COLOR"
        and (nativeMain and self:GetWrathCueColor(0) or color) or iSTSettings.barColor
    bar.fill:SetVertexColor(fillColor.r, fillColor.g, fillColor.b,
        (fillColor.a or 1) * (self.State.Idle and 0.18 or 1))
    local border = iSTSettings.borderNormalColor
    if bar.SetBackdropBorderColor then
        bar:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)
    end
    local cueWidth = math.max(100, bar:GetWidth())
    if bar.wrathCueWidth ~= cueWidth then
        bar.wrathCueFrame:SetWidth(cueWidth)
        bar.wrathCueWidth = cueWidth
    end

    local imagesVisible = active and style == "SWORD_IMAGES"
    self:UpdateSwordImageCue(bar, nativeMain and 0 or count, imagesVisible,
        nativeMain and self:GetWrathCueColor(0) or color)
    -- Leave room for the image sword's hilt, then restore the usual icon gap.
    local iconOffset = imagesVisible and -(bar.wrathSwordImages.leftOverhang + 7) or -7
    if bar.sealIconFrame and bar.wrathIconOffset ~= iconOffset then
        bar.sealIconFrame:ClearAllPoints()
        bar.sealIconFrame:SetPoint("RIGHT", bar, "LEFT", iconOffset, 0)
        bar.wrathIconOffset = iconOffset
    end

    local ready = iSTSettings.wrathReadyText or "Switch now"
    -- Once the replacement seal is active, the next attack releases the stored stacks.
    if armed and ready == "Switch now" then ready = L["WrathAttackNow"] end
    local cueText
    if active and not self.State.TestMode and count == 0
        and now < (self.State.WrathUnleashedUntil or 0)
        and iSTSettings.showThreeStackReadyText and style ~= "OFF" then
        cueText = L["WrathSealUnleashed"]
    elseif active and iSTSettings.showThreeStackReadyText and style ~= "OFF" and count == 3
        and (self.State.TestMode or not bar.nativeReadyContainer) then
        cueText = ready
    end

    if cueText then
        bar.wrathCueText:SetText(cueText)
        bar.wrathCueText:SetTextColor(color.r, color.g, color.b, color.a or 1)
        bar.wrathCueFrame:Show()
    else
        bar.wrathCueText:SetText("")
        bar.wrathCueFrame:Hide()
    end
    local circlesVisible = active and style == "CIRCLES"
    if circlesVisible then self:RenderStackBubbles(bar.wrathCircles,
        nativeMain and 0 or count, nativeMain and self:GetWrathCueColor(0) or color) end
    bar.wrathCircles:SetShown(circlesVisible)
    self:UpdatePlayerWrathBubbles(now)
end
