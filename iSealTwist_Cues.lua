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
    if iSTSettings.stackCountPoint then
        local point = iSTSettings.stackCountPoint
        stackFrame:SetPoint("CENTER", UIParent, "CENTER", point[1], point[2])
    else
        stackFrame:SetPoint("BOTTOM", bar, "TOP", 0, 9)
    end
    stackFrame:SetSize(104, 26)
    stackFrame:SetFrameLevel(bar:GetFrameLevel() + 6)
    stackFrame:SetMovable(true)
    stackFrame:EnableMouse(not iSTSettings.barLocked)
    stackFrame:RegisterForDrag("LeftButton")
    stackFrame:SetScript("OnDragStart", function(self)
        if not iSTSettings.barLocked and not CombatLocked() then
            self.isDragging = true
            self:StartMoving()
        end
    end)
    stackFrame:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        self:StopMovingOrSizing()
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
    bar.stackSealIconStrip = self:CreateStackSealIcons(bar, 20, 5)
    bar.stackSealIconStrip:SetPoint("BOTTOM", bar, "TOP", 0, 7)
    bar.stackSealIconStrip:SetFrameLevel(bar:GetFrameLevel() + 5)
    bar.stackSealIconStrip:Hide()
    self:ApplyWrathCircleSize()
    self:CreatePlayerWrathFrame()
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
    local offset = iSTSettings.showStackCounter and not iSTSettings.stackCountPoint
        and (iSTSettings.stackCounterTextSize or 16) + 28 or 7
    local function Place(frame)
        if frame and frame.pipOffset ~= offset then
            local ok = pcall(function()
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", bar, "TOP", 0, offset)
            end)
            if ok then frame.pipOffset = offset end
        end
    end
    Place(bar.wrathCircles)
    Place(bar.stackSealIconStrip)
    for _, row in ipairs(bar.nativeStageMainRows or {}) do Place(row.circles) end
    if bar.nativeSealIconsMain then
        for _, row in ipairs(bar.nativeSealIconsMain.iconRows or {}) do Place(row.strip) end
    end
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
    return { includeSpellIDs = { [slot.spellID] = true } }
end

local function StackFilterKey()
    return "echo"
end

function iST:UpdateEchoTimerDisplay()
    local bar = self.BarFrame
    if not bar then return end
    -- Build the native buff icon before combat even for combat-only bars.
    -- The parent bar controls visibility; an Echo button appears only while
    -- its matching aura exists.
    local wanted = iSTSettings.showEchoTimer and self:IsWrathTrackingEnabled()
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
            frame:SetSize(38, 38)
            frame:SetPoint("LEFT", bar, "RIGHT", 7, 0)
            frame:SetFrameLevel(bar:GetFrameLevel() + 6)
            frame:EnableMouse(false)
            local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
            container:SetAllPoints(frame)
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
                        shadow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                        shadow:SetPoint("CENTER", button, "CENTER", 1, -1)
                        shadow:SetVertexColor(0, 0, 0, 0.75)
                        local ring = button:CreateTexture(nil, "BORDER")
                        ring:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                        ring:SetPoint("CENTER", button, "CENTER")
                        ring:SetVertexColor(0.20, 0.25, 0.30, 0.95)
                        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                        cooldown:SetAllPoints(ring)
                        cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
                        cooldown:SetSwipeTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
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
                        textLayer:SetAllPoints(button)
                        textLayer:SetFrameLevel(portrait:GetFrameLevel() + 1)
                        textLayer:EnableMouse(false)
                        local label = textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        label:SetPoint("BOTTOM", button, "TOP", 0, 1)
                        label:SetText(L["EchoLabel"])
                        label:SetTextColor(0.35, 0.82, 1, 1)
                        local time = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        time:SetPoint("CENTER", button, "CENTER", 0, 0)
                        time:SetJustifyH("CENTER")
                        time:SetJustifyV("MIDDLE")
                        time:SetWordWrap(false)
                        time:SetFont(self:GetBarFontPath(), 12, "THICKOUTLINE")
                        local color = iSTSettings.echoTimerTextColor
                        time:SetTextColor(color.r, color.g, color.b, color.a or 1)
                        time:SetShadowOffset(1, -1)
                        time:SetShadowColor(0, 0, 0, 1)
                        assert(type(button.SetDurationText) == "function", "native aura duration text is unavailable")
                        button:SetDurationText(time, {})
                        frame.texts[#frame.texts + 1] = time
                        frame.rows[#frame.rows + 1] = {
                            button = button, icon = icon, ring = ring, shadow = shadow,
                            cooldown = cooldown, text = time, label = label,
                        }
                    end,
                })
            end
            container:SetEnabled(true)
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
        end
        if updated then host.filterKey = filterKey end
    end
    local iconSize = math.max(16, math.min(64, iSTSettings.sealIconSize or 25))
    if host.iconSize ~= iconSize or host.fontPath ~= self:GetBarFontPath() then
        host:SetSize(iconSize + 8, iconSize + 8)
        local fontPath = self:GetBarFontPath()
        local textSize = math.max(8, math.floor(iconSize * 0.46 + 0.5))
        for _, row in ipairs(host.rows) do
            row.shadow:SetSize(iconSize + 10, iconSize + 10)
            row.ring:SetSize(iconSize + 8, iconSize + 8)
            row.icon:SetSize(iconSize, iconSize)
            row.text:SetSize(iconSize, iconSize)
            row.text:SetFont(fontPath, textSize, "THICKOUTLINE")
            row.label:SetFont(fontPath, math.max(8, math.floor(iconSize * 0.23 + 0.5)), "OUTLINE")
        end
        host.iconSize, host.fontPath = iconSize, fontPath
    end
    if not CombatLocked() then
        local color = iSTSettings.echoTimerTextColor
        local colorKey = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
        if host.textColorKey ~= colorKey then
            local updated = true
            for _, label in ipairs(host.texts or {}) do
                if not pcall(label.SetTextColor, label, color.r, color.g, color.b, color.a or 1) then
                    updated = false
                end
            end
            if updated then host.textColorKey = colorKey end
        end
    end
    pcall(host.Show, host)
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
            host:SetSize(90, 24)
            host:SetFrameStrata("HIGH")
            host:EnableMouse(false)
            local container = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")
            container:SetAllPoints(host)
            container:SetUnit("player")
            host.container, host.slots = container, {}
            host.glows, host.dots, host.sealPips = {}, {}, {}
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
                        local icon = button:CreateTexture(nil, "OVERLAY")
                        icon:SetSize(18, 18)
                        icon:SetPoint("LEFT", button, "LEFT", 0, 0)
                        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        if type(button.SetIcon) == "function" then button:SetIcon(icon)
                        else
                            icon:SetTexture(self.BarFrame.stackSealIcons[slotInfo.seal])
                        end
                        local progress = CreateFrame("StatusBar", nil, button)
                        progress:SetPoint("LEFT", button, "LEFT", 23, 0)
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
                        for index = 1, 3 do
                            local glow = clip:CreateTexture(nil, "ARTWORK")
                            glow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                            glow:SetSize(22, 22)
                            glow:SetPoint("LEFT", progress, "LEFT", (index - 1) * 22 - 1, 0)
                            glow:SetBlendMode("ADD")
                            glow:SetVertexColor(color.r, color.g, color.b,
                                iSTSettings.nameplateEchoGlow and (color.a or 1) * 0.38 or 0)
                            host.glows[#host.glows + 1] = glow
                            local dot = clip:CreateTexture(nil, "OVERLAY")
                            dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                            dot:SetSize(15, 15)
                            dot:SetPoint("LEFT", progress, "LEFT", (index - 1) * 22 + 2, 0)
                            dot:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * 0.95)
                            dot:SetShown(not iconStyle)
                            host.dots[#host.dots + 1] = dot
                            local sealPip = clip:CreateTexture(nil, "OVERLAY")
                            sealPip:SetTexture(self.BarFrame.stackSealIcons[slotInfo.seal]
                                or "Interface\\Icons\\INV_Misc_QuestionMark")
                            sealPip:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                            sealPip:SetSize(18, 18)
                            sealPip:SetPoint("LEFT", progress, "LEFT", (index - 1) * 22 + 1, 0)
                            sealPip:SetShown(iconStyle)
                            host.sealPips[#host.sealPips + 1] = sealPip
                        end
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

local function AllStackSpellFilter()
    local spellIDs = {}
    for _, spell in ipairs(iST.WrathEchoSpells) do spellIDs[spell.id] = true end
    return { includeSpellIDs = spellIDs }
end

local function CenterSwitchPhrase()
    if iSTSettings.centerSwitchVisual == "RADIANT" then
        return "|TInterface\\SpellActivationOverlay\\IconAlert:96:96|t"
    end
    return iSTSettings.centerSwitchText or "Switch now"
end

local function CenterMessageFormatter(message, target)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "" },
        { threshold = target, format = message },
    }) then return formatter end
end

local function WorldCueGateFormatter(target)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "" },
        { threshold = target, format = string.rep("W", 70) },
    }) then return formatter end
end

local WORLD_GLOW_STYLES = { GLOW = true, WINGS = true, SPARKS = true, FRAME = true }
local WORLD_ALERT = "Interface\\SpellActivationOverlay\\IconAlert"
local WORLD_SPARK = "Interface\\ItemSocketingFrame\\UI-ItemSockets"
local WORLD_WHITE = "Interface\\BUTTONS\\WHITE8X8"

local function CreateWorldGlowEffects(parent, anchor)
    local effects, all = {}, {}
    local color = iSTSettings.worldEchoCueColor
    local function Add(style, path, width, height, point, relative, x, y, opacity, coords, pulse)
        local art = parent:CreateTexture(nil, "ARTWORK")
        art:SetTexture(path)
        art:SetSize(width, height)
        art:SetPoint(point, anchor, relative, x, y)
        art:SetBlendMode("ADD")
        if coords then art:SetTexCoord(unpack(coords)) end
        art:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * opacity)
        art:Hide()
        effects[style] = effects[style] or {}
        effects[style][#effects[style] + 1] = art
        all[#all + 1] = { texture = art, opacity = opacity }
        if pulse then
            -- The animation runs on a prebuilt texture; no combat-time layout or aura reads.
            pcall(function()
                local animation = art:CreateAnimationGroup()
                animation:SetLooping("BOUNCE")
                local fade = animation:CreateAnimation("Alpha")
                fade:SetFromAlpha(0.35)
                fade:SetToAlpha(1)
                fade:SetDuration(pulse)
                fade:SetSmoothing("IN_OUT")
                animation:Play()
            end)
        end
        return art
    end
    local alert = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 }
    local sparkle = { 0.3984375, 0.4453125, 0.40234375, 0.44921875 }
    Add("GLOW", WORLD_ALERT, 174, 105, "CENTER", "CENTER", 0, 0, 0.88, alert, 0.85)
    Add("WINGS", WORLD_ALERT, 82, 108, "RIGHT", "CENTER", -3, 0, 0.9, alert, 1.1)
    Add("WINGS", WORLD_ALERT, 82, 108, "LEFT", "CENTER", 3, 0, 0.9,
        { alert[2], alert[1], alert[3], alert[4] }, 1.1)
    Add("SPARKS", WORLD_ALERT, 150, 94, "CENTER", "CENTER", 0, 0, 0.28, alert, 1.3)
    for index, position in ipairs({
        { "TOPLEFT", 8, -7 }, { "TOPRIGHT", -8, -7 },
        { "BOTTOMLEFT", 8, 7 }, { "BOTTOMRIGHT", -8, 7 },
    }) do
        Add("SPARKS", WORLD_SPARK, 30, 30, position[1], position[1], position[2], position[3],
            0.95, sparkle, 0.7 + index * 0.13)
    end
    for _, edge in ipairs({
        { 166, 2, "TOP", 0, -5 }, { 166, 2, "BOTTOM", 0, 5 },
        { 2, 94, "LEFT", 7, 0 }, { 2, 94, "RIGHT", -7, 0 },
    }) do
        Add("FRAME", WORLD_WHITE, edge[1], edge[2], edge[3], edge[3], edge[4], edge[5], 0.8, nil, 0.9)
    end
    return effects, all
end

function iST:UpdateWorldEchoCue(preview)
    local wanted = preview or (iSTSettings.showWorldEchoCue and self:IsWrathTrackingEnabled()
        and self:ShouldShowAuxiliaryCues())
    local host = self.WorldEchoCueFrame
    if not wanted and not (host and host.moving) then
        if host and host.cueShown and pcall(host.Hide, host) then host.cueShown = false end
        return
    end
    if not host then
        if CombatLocked() or not NativeContainerReady() or self.State.WorldEchoCueFailed then return end
        local ok, result = pcall(function()
            local frame = CreateFrame("Frame", nil, UIParent)
            frame:SetSize(180, 110)
            frame:SetFrameStrata("HIGH")
            frame:SetMovable(true)
            frame:RegisterForDrag("LeftButton")
            frame:EnableMouse(false)
            if iSTSettings.worldEchoCuePoint then
                local point = iSTSettings.worldEchoCuePoint
                frame:SetPoint("CENTER", UIParent, "CENTER", point[1], point[2])
            else
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
            end
            frame:SetScript("OnDragStart", function(self)
                if self.moving and not CombatLocked() then self:StartMoving() end
            end)
            frame:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local x, y = self:GetCenter()
                local rootX, rootY = UIParent:GetCenter()
                if x and y and rootX and rootY then
                    iSTSettings.worldEchoCuePoint = { x - rootX, y - rootY }
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", UIParent, "CENTER",
                        iSTSettings.worldEchoCuePoint[1], iSTSettings.worldEchoCuePoint[2])
                end
            end)
            local preview = frame:CreateTexture(nil, "BACKGROUND")
            preview:SetAllPoints(frame)
            preview:SetColorTexture(0.17, 0.12, 0.04, 0.45)
            preview:Hide()
            frame.preview = preview
            frame.previewEffects, frame.previewArts = CreateWorldGlowEffects(frame, frame)
            frame.rows, frame.slots = {}, {}
            for _, spell in ipairs(self.WrathEchoSpells) do
                frame.slots[#frame.slots + 1] = {
                    key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal,
                }
            end
            local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
            container:SetAllPoints(frame)
            container:SetUnit("player")
            frame.container = container
            for _, slot in ipairs(frame.slots) do
                local slotInfo = slot
                container:AddAuraSlot(slotInfo.key, "HELPFUL", {
                    candidateFilters = StackSpellFilter(slotInfo),
                    initializeFrame = function(button)
                        button:SetAllPoints(frame)
                        button:EnableMouse(false)
                        local gate = button:CreateFontString(nil, "BACKGROUND")
                        gate:SetFont(STANDARD_TEXT_FONT, 64, "")
                        gate:SetWidth(0)
                        gate:SetWordWrap(false)
                        gate:SetPoint("LEFT", button, "LEFT")
                        gate:SetAlpha(0)
                        local clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
                        clip:SetClipsChildren(true)
                        clip:EnableMouse(false)
                        clip:SetPoint("TOPLEFT", button, "TOPLEFT")
                        clip:SetPoint("BOTTOM", button, "BOTTOM")
                        clip:SetPoint("RIGHT", gate, "RIGHT")
                        local effects, allEffects = CreateWorldGlowEffects(clip, button)
                        local target = self:GetTwistStackTarget(slotInfo.seal)
                        button:SetApplicationCount(gate, { formatter = assert(WorldCueGateFormatter(target)) })
                        frame.rows[#frame.rows + 1] = {
                            button = button, gate = gate, effects = effects, allEffects = allEffects,
                            seal = slotInfo.seal,
                        }
                    end,
                })
            end
            container:SetEnabled(true)
            return frame
        end)
        if not ok then
            self.State.WorldEchoCueFailed = true
            self:DebugMsg("Floating Echo cue is unavailable: " .. tostring(result), 2)
            return
        end
        host = result
        self.WorldEchoCueFrame = host
        host.filterKey = StackFilterKey()
    end
    if not CombatLocked() then
        local filterKey = StackFilterKey()
        if host.filterKey ~= filterKey then
            local updated = true
            for _, slot in ipairs(host.slots) do
                if not pcall(host.container.SetAuraSlotCandidateFilters, host.container,
                    slot.key, StackSpellFilter(slot)) then updated = false end
            end
            if updated then host.filterKey = filterKey end
        end
        local style = WORLD_GLOW_STYLES[iSTSettings.worldEchoCueStyle]
            and iSTSettings.worldEchoCueStyle or "WINGS"
        for _, row in ipairs(host.rows) do
            local target = self:GetTwistStackTarget(row.seal)
            if row.target ~= target then
                local formatter = WorldCueGateFormatter(target)
                if formatter and pcall(row.button.SetApplicationCount, row.button, row.gate,
                    { formatter = formatter }) then row.target = target end
            end
            if row.style ~= style then
                for name, arts in pairs(row.effects) do
                    for _, art in ipairs(arts) do art:SetShown(name == style) end
                end
                row.style = style
            end
        end
        local color = iSTSettings.worldEchoCueColor
        local colorKey = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
        if host.colorKey ~= colorKey then
            local updated = true
            for _, row in ipairs(host.rows) do
                for _, effect in ipairs(row.allEffects) do
                    if not pcall(effect.texture.SetVertexColor, effect.texture, color.r, color.g, color.b,
                        (color.a or 1) * effect.opacity) then updated = false end
                end
            end
            for _, effect in ipairs(host.previewArts) do
                if not pcall(effect.texture.SetVertexColor, effect.texture, color.r, color.g, color.b,
                    (color.a or 1) * effect.opacity) then updated = false end
            end
            if updated then host.colorKey = colorKey end
        end
        local scale = iSTSettings.worldEchoCueScale or 1
        if host.displayScale ~= scale then host:SetScale(scale); host.displayScale = scale end
        if host.moving then
            for name, arts in pairs(host.previewEffects) do
                for _, art in ipairs(arts) do art:SetShown(name == style) end
            end
        end
    end
    if not host.cueShown and pcall(host.Show, host) then host.cueShown = true end
end

function iST:SetWorldEchoCueMoveMode(moving)
    if CombatLocked() then return end
    if moving and not self.WorldEchoCueFrame then self:UpdateWorldEchoCue(true) end
    local frame = self.WorldEchoCueFrame
    if not frame then return end
    frame.moving = moving and true or false
    frame:EnableMouse(frame.moving)
    frame.preview:SetShown(frame.moving)
    if not frame.moving then
        for _, effect in ipairs(frame.previewArts) do effect.texture:Hide() end
    end
    self:UpdateWorldEchoCue()
end

function iST:ResetWorldEchoCuePosition()
    if CombatLocked() then return end
    iSTSettings.worldEchoCuePoint = nil
    local frame = self.WorldEchoCueFrame
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
end

function iST:UpdateCenterSwitchSealGate()
    local frame = self.CenterSwitchFrame
    if not frame or not frame.phaseSlotFrames or self.State.CenterSwitchPhaseBlocked then return end
    local current = self.State.CurrentSealName
    local cast = self.State.WrathLastSealCastName
    if (issecretvalue and (issecretvalue(current) or issecretvalue(cast))) then return end
    if frame.gateValid and frame.gateSeal == current and frame.gateCast == cast
        and frame.gateMoving == frame.moving then return end
    for _, slot in ipairs(frame.slots) do
        -- The buff slot identifies the Seal behind its own three-stack text.
        local source = slot.seal
        local switched = source and current and current ~= source and cast == current
        local phase = switched and "attack" or "switch"
        for _, name in ipairs({ "switch", "attack" }) do
            -- These parents are plain frames; the buff buttons cannot be
            -- changed safely during combat.
            local parent = frame.phaseSlotFrames[name][slot.key]
            local alpha = not frame.moving and phase == name and 1 or 0
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
    frame.gateValid = true
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
    local wanted = self:ShouldShowAuxiliaryCues() and self:IsWrathTrackingEnabled()
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
            host:SetSize(360, iSTSettings.centerSwitchVisual == "RADIANT" and 110 or 68)
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
                    slotFrame:SetAllPoints(host)
                    slotFrame:SetAlpha(phaseName == "switch" and 1 or 0)
                    host.phaseSlotFrames[phaseName][slotInfo.key] = slotFrame
                    local container = CreateFrame("AuraContainer", nil, slotFrame, "CustomAuraContainerTemplate")
                    container:SetAllPoints(slotFrame)
                    container:SetUnit("player")
                    host.phaseContainers[phaseName][slotInfo.key] = container
                    container:AddAuraSlot(slotInfo.key, "HELPFUL", {
                        candidateFilters = StackSpellFilter(slotInfo),
                        initializeFrame = function(button)
                            button:SetAllPoints(slotFrame)
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
        self.CenterSwitchFrame = frame
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
    local height = iSTSettings.centerSwitchVisual == "RADIANT" and 110 or 68
    if frame:GetHeight() ~= height then frame:SetHeight(height) end
    if frame:IsShown() ~= visible then frame:SetShown(visible) end
    self:UpdateCenterSwitchSealGate()
end

local function NativeCountFormatter(target)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local points = { { threshold = 0, format = "" } }
    target = type(target) == "number" and target or 3
    for stage = 1, 3 do
        local color = iST:GetWrathCueColor(stage)
        local code = string.format("|c%02x%02x%02x%02x", math.floor((color.a or 1) * 255 + 0.5),
            math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5))
        points[#points + 1] = { threshold = stage, format = code .. "%d / " .. target .. "|r" }
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
            local formatter = NativeCountFormatter(self:GetTwistStackTarget(row.seal))
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

local function ReadyGateFormatter(target)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    if pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = "" },
        { threshold = target, format = string.rep("W", 70) },
    }) then return formatter end
end

function iST:UpdateNativeReadyDisplay()
    local bar = self.BarFrame
    if not bar or CombatLocked() then return end
    local wanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and iSTSettings.showThreeStackReadyText
    if not wanted then
        if bar.nativeReadyContainer then bar.nativeReadyContainer:Hide() end
        return
    end
    if not NativeContainerReady() then return end
    if bar.nativeReadyFailed then return end
    if not bar.nativeReadyContainer then
        if not ReadyGateFormatter(3) then
            bar.nativeReadyFailed = true
            return
        end
        local ok, result = pcall(function()
            local frame = CreateFrame("AuraContainer", nil, bar, "CustomAuraContainerTemplate")
            frame:SetSize(250, 32)
            frame:SetPoint("BOTTOM", bar, "TOP", 0, 35)
            frame:SetFrameLevel(bar:GetFrameLevel() + 7)
            frame:SetUnit("player")
            bar.nativeReadySlots, bar.nativeReadyRows = {}, {}
            for _, spell in ipairs(self.WrathEchoSpells) do
                bar.nativeReadySlots[#bar.nativeReadySlots + 1] = {
                    key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal,
                }
            end
            for _, slot in ipairs(bar.nativeReadySlots) do
                local slotInfo = slot
                frame:AddAuraSlot(slotInfo.key, "HELPFUL", {
                    candidateFilters = StackSpellFilter(slotInfo),
                    initializeFrame = function(button)
                    button:SetAllPoints(frame)
                    button:EnableMouse(false)
                    -- The native count changes this hidden text's width. Its clip
                    -- reveals the fixed message at the chosen switch count.
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
                    local target = self:GetTwistStackTarget(slotInfo.seal)
                    button:SetApplicationCount(gate, { formatter = assert(ReadyGateFormatter(target)) })
                    bar.nativeReadyRows[#bar.nativeReadyRows + 1] = {
                        button = button, text = text, gate = gate, clip = clip,
                        seal = slotInfo.seal,
                    }
                end,
            })
            end
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
        for _, row in ipairs(bar.stackManagedRows or {}) do self:ApplyThreeStackGate(row) end
    end
    if bar.nativeReadyFilterKey ~= StackFilterKey() then
        local updated = true
        for _, slot in ipairs(bar.nativeReadySlots or {}) do
            if not pcall(bar.nativeReadyContainer.SetAuraSlotCandidateFilters,
                bar.nativeReadyContainer, slot.key, StackSpellFilter(slot)) then updated = false end
        end
        if updated then bar.nativeReadyFilterKey = StackFilterKey() end
    end
    local font, size = self:GetBarFontPath(), iSTSettings.stackCounterTextSize or 16
    for _, row in ipairs(bar.nativeReadyRows or {}) do
        local target = self:GetTwistStackTarget(row.seal)
        local key = tostring(target)
        if row.targetKey ~= key then
            local formatter = ReadyGateFormatter(target)
            if formatter and pcall(row.button.SetApplicationCount, row.button, row.gate,
                { formatter = formatter }) then row.targetKey = key end
        end
        if row.message ~= iSTSettings.wrathReadyText then
            row.text:SetText(iSTSettings.wrathReadyText or "Switch now")
            row.message = iSTSettings.wrathReadyText
        end
        if row.font ~= font or row.size ~= size then
            row.text:SetFont(font, size, "THICKOUTLINE")
            row.font, row.size = font, size
        end
        local color = self:GetWrathCueColor(target)
        local colorKey = table.concat({ color.r, color.g, color.b, color.a or 1 }, ":")
        if row.colorKey ~= colorKey then
            row.text:SetTextColor(color.r, color.g, color.b, color.a or 1)
            row.colorKey = colorKey
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

local function BuildSealIconContainer(parent, bar, player)
    local frame = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    frame:SetAllPoints(parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 12)
    frame:SetUnit("player")
    frame.slotInfos, frame.iconRows = {}, {}
    for _, spell in ipairs(iST.WrathEchoSpells) do
        frame.slotInfos[#frame.slotInfos + 1] = {
            key = "echo" .. spell.id, spellID = spell.id, seal = spell.seal,
        }
    end
    for _, slot in ipairs(frame.slotInfos) do
        local slotInfo = slot
        frame:AddAuraSlot(slotInfo.key, "HELPFUL", {
            candidateFilters = StackSpellFilter(slotInfo),
            initializeFrame = function(button)
                button:SetAllPoints(frame)
                button:EnableMouse(false)
                local texture = bar.stackSealIcons[slotInfo.seal]
                local strip = iST:CreateStackSealIcons(button,
                    player and 21 or 20, 5, texture, button)
                if player then strip:SetPoint("CENTER", parent, "CENTER")
                else strip:SetPoint("BOTTOM", bar, "TOP", 0, 7) end
                frame.iconRows[#frame.iconRows + 1] = {
                    strip = strip, seal = slotInfo.seal,
                }
            end,
        })
    end
    frame:SetEnabled(true)
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
    local stackBarColor = iSTSettings.showStackBarColor and not iSTSettings.barColorBySeal
    local mainWanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and (stackBarColor or iSTSettings.showStackSwordImages
            or (iSTSettings.showStackCircles and iSTSettings.stackBubbleStyle == "CIRCLES"))
    local playerWanted = self:IsWrathTrackingEnabled() and not self.State.TestMode
        and iSTSettings.showPlayerWrathBubbles and iSTSettings.stackBubbleStyle == "CIRCLES"
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
    local visualParts = { tostring(stackBarColor),
        tostring(iSTSettings.showStackSwordImages), tostring(iSTSettings.showStackCircles),
        tostring(iSTSettings.stackBubbleStyle),
        tostring(iSTSettings.wrathColorScheme),
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
            row.overlay:SetShown(stackBarColor)
            self:UpdateNativeSwordStage(bar, row.sword, color)
            row.sword:SetShown(iSTSettings.showStackSwordImages)
            self:RenderStackBubbles(row.circles, stage, color)
            row.circles:SetShown(iSTSettings.showStackCircles and iSTSettings.stackBubbleStyle == "CIRCLES")
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
        local target = self:GetTwistStackTarget(row.seal)
        if row.threeStackGate.target ~= target and pcall(row.button.SetApplicationBar,
            row.button, row.threeStackGate.bar, { maxApplications = target }) then
            row.threeStackGate.target = target
        end
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
        local target = self:GetTwistStackTarget(row.seal)
        row.threeStackGate = { bar = bar, clip = clip, text = text, target = target }
        LayoutThreeStackGate(row)
        button:SetApplicationBar(bar, { maxApplications = target })
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
        count:ClearAllPoints()
        count:SetPoint("CENTER", button, "CENTER", 0, 0)
        count:SetSize(layout.rowWidth, layout.rowHeight)
        count:SetJustifyH("CENTER")
        total:Hide()
        if row.icon then
            row.icon:SetSize(layout.iconSize, layout.iconSize)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("RIGHT", button, "CENTER", -layout.countWidth - 8, 0)
        end
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
    if not bar or not self:IsWrathTrackingEnabled() or not iSTSettings.showStackCounter
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

                    local total = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    total:SetPoint("LEFT", button, "CENTER", 0, 0)
                    total:SetSize(64, 26)
                    total:SetShadowOffset(1, -1)
                    total:SetShadowColor(0, 0, 0, 1)
                    total:SetText("/ " .. self:GetTwistStackTarget(slot.seal))
                    local icon
                    local texture = slot.seal and bar.stackSealIcons[slot.seal]
                    if texture then
                        icon = button:CreateTexture(nil, "OVERLAY")
                        icon:SetTexture(texture)
                        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        icon:Show()
                    end
                    bar.stackManagedRows[#bar.stackManagedRows + 1] = {
                        button = button, count = count, total = total, icon = icon,
                        seal = slot.seal,
                    }
                    bar.stackManagedTexts[#bar.stackManagedTexts + 1] = count
                    bar.stackManagedTexts[#bar.stackManagedTexts + 1] = total
                    bar.stackManagedButtons[#bar.stackManagedButtons + 1] = button
                    self:LayoutManagedStackReadout(true)
                    button:SetApplicationCount(count, { formatter = NativeCountFormatter(self:GetTwistStackTarget(slot.seal)) or formatter })
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

function iST:UpdateWrathDisplay(now)
    local bar = self.BarFrame
    if not bar or not bar.wrathCueFrame then return end
    now = now or GetTime()
    -- Previews supply their own count; drawing the cue does not change live stacks.
    local count, active, armed = self:GetWrathDisplayState(now)
    count = math.max(0, math.min(3, math.floor(count or 0)))
    local color = self:GetWrathCueColor(count)
    self:UpdateStackCountDisplay(now, active and iSTSettings.showStackCounter, count)
    self:UpdateEchoTimerDisplay()
    self:UpdateNameplateEchoDisplay()
    if active and iSTSettings.showStackCounter and (not bar.stackManagedContainer or self.State.TestMode) then
        bar.stackCountValue:SetTextColor(color.r, color.g, color.b, color.a or 1)
        bar.stackCountTotal:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
    self:UpdateNativeReadyDisplay()
    self:UpdateWorldEchoCue()
    self:UpdateCenterSwitchText()
    self:UpdateCenterSwitchSealGate()
    self:UpdateNativeStageVisuals()
    self:LayoutStackPips()
    local nativeMain = bar.nativeStageMainVisible == true

    -- Stack colors belong on the fill for this cue. The other cues, and
    -- characters without the talent, keep the chosen normal bar color.
    local fillColor = active and self.State.TestMode and iSTSettings.showStackBarColor
        and color or self:GetBarFillColor()
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

    local imagesVisible = active and iSTSettings.showStackSwordImages
        and (nativeMain or self.State.TestMode)
    self:UpdateSwordImageCue(bar, self.State.TestMode and count or 0, imagesVisible,
        self.State.TestMode and color or self:GetWrathCueColor(0))
    -- Leave room for the image sword's hilt, then restore the usual icon gap.
    local iconOffset = imagesVisible and -(bar.wrathSwordImages.leftOverhang + 7) or -7
    if bar.sealIconFrame and not iSTSettings.sealIconPoint and bar.wrathIconOffset ~= iconOffset then
        bar.sealIconFrame:ClearAllPoints()
        bar.sealIconFrame:SetPoint("RIGHT", bar, "LEFT", iconOffset, 0)
        bar.wrathIconOffset = iconOffset
    end

    local ready = iSTSettings.wrathReadyText or "Switch now"
    -- Once the replacement seal is active, the next attack releases the stored stacks.
    if armed and ready == "Switch now" then ready = L["WrathAttackNow"] end
    local cueText
    if active and self.State.TestMode and iSTSettings.showThreeStackReadyText
        and count >= self:GetTwistStackTarget(iSTSettings.twistFromSeal)
        then
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
    local circlesVisible = active and iSTSettings.showStackCircles
        and iSTSettings.stackBubbleStyle == "CIRCLES" and self.State.TestMode
    if circlesVisible then self:RenderStackBubbles(bar.wrathCircles,
        count, color) end
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
        if showIcons then self:RenderStackSealIcons(iconStrip, count, texture) end
    end
    self:UpdatePlayerWrathBubbles(now)
end
