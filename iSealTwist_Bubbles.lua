local _, iST = ...
local CIRCLE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function Circle(frame, layer, size, r, g, b, a)
    local texture = frame:CreateTexture(nil, layer)
    texture:SetTexture(CIRCLE_TEXTURE)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER", frame, "CENTER")
    texture:SetVertexColor(r, g, b, a)
    return texture
end

function iST:CreateStackBubbles(parent, name, size, gap)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(size * 3 + gap * 2, size + 12)
    frame:EnableMouse(false)
    frame.orbs = {}
    -- Use the same three sockets for the swing-bar cue and the player-frame cue.
    for index = 1, 3 do
        local socket = CreateFrame("Frame", nil, frame)
        socket:SetSize(size, size)
        socket:SetPoint("CENTER", frame, "CENTER", (index - 2) * (size + gap), 0)
        local halo = Circle(socket, "BACKGROUND", size + 12, 1, 0.8, 0.2, 0)
        halo:SetBlendMode("ADD")
        local glow = Circle(socket, "BACKGROUND", size + 6, 1, 0.8, 0.2, 0)
        glow:SetBlendMode("ADD")
        Circle(socket, "BORDER", size + 1, 0.05, 0.035, 0.015, 1)
        local ring = Circle(socket, "ARTWORK", size, 0.64, 0.48, 0.18, 1)
        local core = Circle(socket, "OVERLAY", size - 4, 1, 0.8, 0.2, 0.16)
        local shine = Circle(socket, "OVERLAY", math.max(3, size * 0.22), 1, 1, 0.82, 0.1)
        shine:ClearAllPoints()
        shine:SetPoint("CENTER", socket, "CENTER", -size * 0.16, size * 0.18)
        frame.orbs[index] = { core = core, ring = ring, glow = glow, halo = halo, shine = shine }
    end
    frame:Hide()
    return frame
end

function iST:RenderStackBubbles(frame, count, color)
    -- Both displays update regularly. Leave the textures alone when nothing changed.
    if frame.lastCount == count and frame.lastR == color.r and frame.lastG == color.g
        and frame.lastB == color.b and frame.lastA == color.a then return end
    frame.lastCount, frame.lastR, frame.lastG, frame.lastB, frame.lastA =
        count, color.r, color.g, color.b, color.a
    local alpha = color.a or 1
    for index, orb in ipairs(frame.orbs) do
        local filled = index <= count
        orb.core:SetVertexColor(color.r, color.g, color.b, alpha * (filled and 1 or 0.16))
        orb.ring:SetVertexColor(filled and 1 or 0.64, filled and 0.84 or 0.48, 0.24, alpha)
        orb.glow:SetVertexColor(color.r, color.g, color.b, filled and alpha * 0.24 or 0)
        orb.halo:SetVertexColor(color.r, color.g, color.b, filled and alpha * 0.08 or 0)
        orb.shine:SetVertexColor(1, 1, 0.82, alpha * (filled and 0.75 or 0.08))
    end
end

function iST:CreateStackSealIcons(parent, size, gap, texture, nativeButton)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(size * 3 + gap * 2, size + 8)
    strip:EnableMouse(false)
    strip.dimIcons, strip.brightIcons = {}, {}
    local clip
    if nativeButton then
        local progress = CreateFrame("StatusBar", nil, nativeButton)
        progress:SetAllPoints(strip)
        progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        progress:SetAlpha(0)
        clip = CreateFrame("Frame", nil, nativeButton, "DisableUntrustedLayoutScriptsTemplate")
        clip:SetClipsChildren(true)
        clip:EnableMouse(false)
        clip:SetPoint("TOPLEFT", progress, "TOPLEFT")
        clip:SetPoint("BOTTOMRIGHT", progress:GetStatusBarTexture(), "BOTTOMRIGHT")
        nativeButton:SetApplicationBar(progress, { maxApplications = 3 })
        strip.progress, strip.clip = progress, clip
    end
    for index = 1, 3 do
        local x = (index - 2) * (size + gap)
        local dim = strip:CreateTexture(nil, "ARTWORK")
        dim:SetSize(size, size)
        dim:SetPoint("CENTER", strip, "CENTER", x, 0)
        dim:SetTexture(texture)
        dim:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        dim:SetVertexColor(0.45, 0.42, 0.34, 0.42)
        local bright = (clip or strip):CreateTexture(nil, "OVERLAY")
        bright:SetSize(size, size)
        bright:SetPoint("CENTER", strip, "CENTER", x, 0)
        bright:SetTexture(texture)
        bright:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        strip.dimIcons[index], strip.brightIcons[index] = dim, bright
    end
    strip.texture = texture
    return strip
end

function iST:RenderStackSealIcons(strip, count, texture)
    if not strip then return end
    if texture and strip.texture ~= texture then
        for index = 1, 3 do
            strip.dimIcons[index]:SetTexture(texture)
            strip.brightIcons[index]:SetTexture(texture)
        end
        strip.texture = texture
    end
    if strip.progress then return end
    if strip.lastCount == count then return end
    strip.lastCount = count
    for index, icon in ipairs(strip.brightIcons) do
        icon:SetAlpha(index <= count and 1 or 0)
    end
end

local function GetPlayerManaAnchor()
    if not PlayerFrame then return end
    -- Prefer the getter, with the current player-frame layout as a fallback.
    if type(PlayerFrame_GetManaBar) == "function" then
        local ok, anchor = pcall(PlayerFrame_GetManaBar)
        if ok and anchor then return anchor end
    end
    local content = PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    return main and main.ManaBarArea and main.ManaBarArea.ManaBar
end

local function IsVisible(frame)
    if not frame or type(frame.IsVisible) ~= "function" then return false end
    local ok, visible = pcall(frame.IsVisible, frame)
    if not ok or (issecretvalue and issecretvalue(visible)) then return false end
    return visible == true
end

function iST:CreatePlayerWrathFrame()
    if self.PlayerWrathFrame then return end
    -- Anchor our own frame to the mana bar without changing Blizzard's frame or
    -- its scripts. The dark inset and gold rim use standard WoW panel textures.
    local frame = CreateFrame("Frame", "iSTPlayerWrathFrame", UIParent, "BackdropTemplate")
    frame:SetSize(108, 34)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(false)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.12, 0.09, 0.04, 0.95)
    frame:SetBackdropBorderColor(0.86, 0.68, 0.28, 1)
    local inset = frame:CreateTexture(nil, "BACKGROUND")
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    inset:SetColorTexture(0.025, 0.02, 0.012, 0.85)
    frame.inset = inset
    local orbs = self:CreateStackBubbles(frame, nil, 19, 10)
    orbs:SetPoint("CENTER", frame, "CENTER")
    orbs:Show()
    frame.orbs, frame.bubbles = orbs.orbs, orbs
    local icons = self:CreateStackSealIcons(frame, 21, 5)
    icons:SetPoint("CENTER", frame, "CENTER")
    icons:Hide()
    frame.sealIcons = icons
    frame.updateAccum = 0
    -- The swing bar can be hidden between attacks, so the bubbles need their own
    -- update timer to clear expired stacks.
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.updateAccum = self.updateAccum + elapsed
        if self.updateAccum >= 0.1 then
            self.updateAccum = 0
            iST:UpdatePlayerWrathBubbles(GetTime())
        end
    end)
    frame:Hide()
    self.PlayerWrathFrame = frame
end

function iST:UpdatePlayerWrathBubbles(now)
    local frame = self.PlayerWrathFrame
    if not frame then return end
    local count, active = 0, self:IsWrathTrackingEnabled()
    if self.State.TestMode then count, active = self:GetWrathDisplayState(now or GetTime()) end
    if not iSTSettings.showPlayerWrathBubbles or not active or not self:ShouldShowAuxiliaryCues() then
        frame:Hide()
        return
    end
    local iconStyle = iSTSettings.stackBubbleStyle == "SEAL_ICONS"
    local bar = self.BarFrame
    local native = bar and (iconStyle and bar.nativeSealIconsPlayerVisible == true
        or not iconStyle and bar.nativeStagePlayerVisible == true)
    if not self.State.TestMode and not native then frame:Hide() return end
    local mana = GetPlayerManaAnchor()
    if not IsVisible(PlayerFrame) or not IsVisible(mana) then frame:Hide() return end
    if UnitHasVehicleUI then
        local ok, vehicle = pcall(UnitHasVehicleUI, "player")
        if not ok or (issecretvalue and issecretvalue(vehicle)) or vehicle then frame:Hide() return end
    end
    -- Re-anchor if Blizzard has replaced the mana bar, and match its effective
    -- scale even though our frame belongs to UIParent.
    if frame.manaAnchor ~= mana then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", mana, "BOTTOM", 0, -5)
        frame.manaAnchor = mana
    end
    local manaScale = 1
    if mana.GetEffectiveScale then manaScale = mana:GetEffectiveScale() end
    local parentScale = UIParent:GetEffectiveScale()
    if not (issecretvalue and (issecretvalue(manaScale) or issecretvalue(parentScale)))
        and type(manaScale) == "number" and type(parentScale) == "number"
        and parentScale > 0 then
        local scale = manaScale / parentScale
        if frame.anchorScale ~= scale then frame:SetScale(scale); frame.anchorScale = scale end
    end
    local icons = iconStyle
    if frame.iconStyle ~= icons then
        local ok = pcall(function()
            frame:SetBackdropColor(0.12, 0.09, 0.04, icons and 0 or 0.95)
            frame:SetBackdropBorderColor(0.86, 0.68, 0.28, icons and 0 or 1)
            frame.inset:SetAlpha(icons and 0 or 1)
        end)
        if ok then frame.iconStyle = icons end
    end
    frame.bubbles:SetShown(not icons)
    if icons then
        local source = self.State.TestMode and iSTSettings.twistFromSeal
        local texture = source and bar and bar.stackSealIcons[source]
        frame.sealIcons:SetShown(self.State.TestMode and count > 0 and texture ~= nil)
        if self.State.TestMode and texture then self:RenderStackSealIcons(frame.sealIcons, count, texture) end
    else
        frame.sealIcons:Hide()
        local stage = self.State.TestMode and count or 0
        self:RenderStackBubbles(frame.bubbles, stage, self:GetWrathCueColor(stage))
    end
    frame:Show()
end
