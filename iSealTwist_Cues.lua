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
    local color = iSTSettings.stackCounterColor or self.SettingsDefault.stackCounterColor
    local function ColorText(fontString)
        if fontString then fontString:SetTextColor(color.r, color.g, color.b, color.a or 1) end
    end
    ColorText(bar.stackCountValue)
    ColorText(bar.stackCountTotal)
    if bar.stackManagedTexts then
        for _, fontString in ipairs(bar.stackManagedTexts) do ColorText(fontString) end
    end
    self.State.PendingStackCounterColor = nil
end

function iST:SetWrathColorScheme(scheme)
    if not COLOR_SCHEMES[scheme] and scheme ~= "CUSTOM" then return end
    iSTSettings.wrathColorScheme = scheme
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

    -- The counter stays visible when the combat-only swing bar fades out.
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
    self:CreatePlayerWrathFrame()
    self:ApplyStackCounterColor()
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

function iST:LayoutManagedStackReadout(initial)
    local bar = self.BarFrame
    if not bar or not bar.stackManagedRows or not bar.stackCountLayout or CombatLocked() then return end
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
                    button:SetApplicationCount(count, { formatter = formatter })
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

    -- Stack colors belong on the fill for this cue. The other cues, and
    -- characters without the talent, keep the chosen normal bar color.
    local fillColor = active and style == "BAR_COLOR" and color or iSTSettings.barColor
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
    self:UpdateSwordImageCue(bar, count, imagesVisible, color)
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
    if active and style == "TEXT" and count == 3 then
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
    if circlesVisible then self:RenderStackBubbles(bar.wrathCircles, count, color) end
    bar.wrathCircles:SetShown(circlesVisible)
    self:UpdatePlayerWrathBubbles(now)
end
