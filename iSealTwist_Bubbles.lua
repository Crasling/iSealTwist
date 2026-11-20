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
    frame.pipGap, frame.pipSize = gap, size
    frame:SetSize(size * 3 + gap * 2, size + 12)
    frame:EnableMouse(false)
    frame.orbs = {}
    -- Use the same three sockets for the swing-bar cue and the player-frame cue.
    for index = 1, 3 do
        local socket = CreateFrame("Frame", nil, frame)
        socket:SetSize(size, size)
        socket:EnableMouse(false)
        socket:SetPoint("CENTER", frame, "CENTER", (index - 2) * (size + gap), 0)
        local halo = Circle(socket, "BACKGROUND", size + 12, 1, 0.8, 0.2, 0)
        halo:SetBlendMode("ADD")
        local glow = Circle(socket, "BACKGROUND", size + 6, 1, 0.8, 0.2, 0)
        glow:SetBlendMode("ADD")
        local border = Circle(socket, "BORDER", size + 1, 0.05, 0.035, 0.015, 1)
        local ring = Circle(socket, "ARTWORK", size, 0.64, 0.48, 0.18, 1)
        local core = Circle(socket, "OVERLAY", size - 4, 1, 0.8, 0.2, 0.16)
        local shine = Circle(socket, "OVERLAY", math.max(3, size * 0.22), 1, 1, 0.82, 0.1)
        shine:ClearAllPoints()
        shine:SetPoint("CENTER", socket, "CENTER", -size * 0.16, size * 0.18)
        frame.orbs[index] = { socket = socket, border = border, core = core,
            ring = ring, glow = glow, halo = halo, shine = shine }
    end
    frame:Hide()
    return frame
end

function iST:ResizeStackBubbles(frame, size)
    if not frame then return end
    frame.pipSize = size
    local gap = frame.pipGap or 9
    frame:SetSize(size * 3 + gap * 2, size + 12)
    for index, orb in ipairs(frame.orbs) do
        orb.socket:SetSize(size, size)
        orb.socket:ClearAllPoints()
        orb.socket:SetPoint("CENTER", frame, "CENTER", (index - 2) * (size + gap), 0)
        orb.halo:SetSize(size + 12, size + 12)
        orb.glow:SetSize(size + 6, size + 6)
        orb.border:SetSize(size + 1, size + 1)
        orb.ring:SetSize(size, size)
        orb.core:SetSize(size - 4, size - 4)
        orb.shine:SetSize(math.max(3, size * 0.22), math.max(3, size * 0.22))
        orb.shine:ClearAllPoints()
        orb.shine:SetPoint("CENTER", orb.socket, "CENTER", -size * 0.16, size * 0.18)
    end
end

function iST:RenderStackBubbles(frame, count, color, target)
    -- Both displays update regularly. Leave the textures alone when nothing changed.
    local visiblePips = math.max(count, math.max(1, math.min(3, tonumber(target) or 3)))
    if frame.lastCount == count and frame.lastR == color.r and frame.lastG == color.g
        and frame.lastB == color.b and frame.lastA == color.a
        and frame.visiblePips == visiblePips then return end
    frame.lastCount, frame.lastR, frame.lastG, frame.lastB, frame.lastA =
        count, color.r, color.g, color.b, color.a
    frame.visiblePips = visiblePips
    local alpha = color.a or 1
    for index, orb in ipairs(frame.orbs) do
        orb.socket:SetShown(index <= visiblePips)
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
    strip.pipGap, strip.pipSize = gap, size
    strip:SetSize(size * 3 + gap * 2, size + 8)
    strip:EnableMouse(false)
    strip.dimIcons, strip.brightIcons = {}, {}
    local clip
    if nativeButton then
        local progress = CreateFrame("StatusBar", nil, nativeButton)
        progress:SetAllPoints(strip)
        progress:EnableMouse(false)
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
        local dimMask = strip:CreateMaskTexture()
        dimMask:SetTexture(CIRCLE_TEXTURE)
        dimMask:SetAllPoints(dim)
        dim:AddMaskTexture(dimMask)
        local bright = (clip or strip):CreateTexture(nil, "OVERLAY")
        bright:SetSize(size, size)
        bright:SetPoint("CENTER", strip, "CENTER", x, 0)
        bright:SetTexture(texture)
        bright:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local brightMask = (clip or strip):CreateMaskTexture()
        brightMask:SetTexture(CIRCLE_TEXTURE)
        brightMask:SetAllPoints(bright)
        bright:AddMaskTexture(brightMask)
        strip.dimIcons[index], strip.brightIcons[index] = dim, bright
    end
    strip.texture = texture
    return strip
end

function iST:ResizeStackSealIcons(strip, size)
    if not strip then return end
    strip.pipSize = size
    local gap = strip.pipGap or 5
    strip:SetSize(size * 3 + gap * 2, size + 8)
    for index = 1, 3 do
        local x = (index - 2) * (size + gap)
        for _, icon in ipairs({ strip.dimIcons[index], strip.brightIcons[index] }) do
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", strip, "CENTER", x, 0)
        end
    end
end

function iST:SetStackSealIconTarget(strip, target)
    if not strip then return end
    target = math.max(1, math.min(3, tonumber(target) or 3))
    if strip.targetPips == target then return end
    strip.targetPips = target
    strip.visiblePips = math.max(target, strip.lastCount or 0)
    for index, icon in ipairs(strip.dimIcons) do
        icon:SetShown(index <= target)
    end
end

function iST:RenderStackSealIcons(strip, count, texture, target)
    if not strip then return end
    self:SetStackSealIconTarget(strip, target)
    if texture and strip.texture ~= texture then
        for index = 1, 3 do
            strip.dimIcons[index]:SetTexture(texture)
            strip.brightIcons[index]:SetTexture(texture)
        end
        strip.texture = texture
    end
    if strip.progress then return end
    strip.visiblePips = math.max(strip.targetPips or 3, count)
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
    -- Anchor our own frame to the mana bar without changing Blizzard's frame
    -- or its scripts. Keep the supplied artwork separate from the pips so the
    -- frame can be hidden without hiding the stack display.
    local frame = CreateFrame("Frame", "iSTPlayerWrathFrame", UIParent)
    frame:SetSize(106, 28)
    -- Keep the pip panel behind Blizzard's player frame artwork.
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(0)
    frame:EnableMouse(false)
    local artwork = CreateFrame("Frame", nil, frame)
    artwork:SetAllPoints(frame)
    artwork:SetFrameLevel(frame:GetFrameLevel())
    artwork:EnableMouse(false)
    local fill = artwork:CreateTexture(nil, "BACKGROUND")
    -- Fill to the frame edge except for the four beveled corner squares.
    fill:SetPoint("TOPLEFT", artwork, "TOPLEFT", 0, -6)
    fill:SetPoint("BOTTOMRIGHT", artwork, "BOTTOMRIGHT", 0, 6)
    fill:SetColorTexture(0.025, 0.020, 0.015, 0.95)
    local function EndFill(top)
        local part = artwork:CreateTexture(nil, "BACKGROUND")
        part:SetColorTexture(0.025, 0.020, 0.015, 0.95)
        if top then
            part:SetPoint("TOPLEFT", artwork, "TOPLEFT", 6, 0)
            part:SetPoint("BOTTOMRIGHT", artwork, "TOPRIGHT", -6, -6)
        else
            part:SetPoint("TOPLEFT", artwork, "BOTTOMLEFT", 6, 6)
            part:SetPoint("BOTTOMRIGHT", artwork, "BOTTOMRIGHT", -6, 0)
        end
    end
    EndFill(true)
    EndFill(false)
    -- The source image is 2:1. Slice its gold edge so it keeps its shape when
    -- stretched to the much wider, shallow player mana bar.
    local texture = self.AddonPath .. "Images\\Player_PipFrame.blp"
    local corner = 6
    local u, v = 24 / 512, 24 / 256
    local function Piece(coords, maskX, maskY)
        local piece = artwork:CreateTexture(nil, "BORDER")
        piece:SetTexture(texture)
        piece:SetTexCoord(unpack(coords))
        -- Preserve the source colors and its dark inner corner while clipping
        -- the opaque black pixels outside the rounded bevel.
        if maskX then
            local mask = artwork:CreateMaskTexture()
            mask:SetTexture(CIRCLE_TEXTURE)
            mask:SetSize(corner + 3, corner + 3)
            mask:SetPoint("CENTER", piece, "CENTER", maskX, maskY)
            piece:AddMaskTexture(mask)
        end
        return piece
    end
    local topLeft = Piece({ 0, u, 0, v }, 1, -1)
    topLeft:SetSize(corner, corner)
    topLeft:SetPoint("TOPLEFT")
    local topRight = Piece({ 1 - u, 1, 0, v }, -1, -1)
    topRight:SetSize(corner, corner)
    topRight:SetPoint("TOPRIGHT")
    local bottomLeft = Piece({ 0, u, 1 - v, 1 }, 1, 1)
    bottomLeft:SetSize(corner, corner)
    bottomLeft:SetPoint("BOTTOMLEFT")
    local bottomRight = Piece({ 1 - u, 1, 1 - v, 1 }, -1, 1)
    bottomRight:SetSize(corner, corner)
    bottomRight:SetPoint("BOTTOMRIGHT")
    local top = Piece({ u, 1 - u, 0, v })
    top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
    top:SetPoint("TOPRIGHT", topRight, "TOPLEFT")
    top:SetHeight(corner)
    local bottom = Piece({ u, 1 - u, 1 - v, 1 })
    bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
    bottom:SetHeight(corner)
    local left = Piece({ 0, u, v, 1 - v })
    left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT")
    left:SetWidth(corner)
    local right = Piece({ 1 - u, 1, v, 1 - v })
    right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")
    right:SetWidth(corner)
    frame.artwork = artwork
    local orbs = self:CreateStackBubbles(frame, nil, 16, 10)
    orbs:SetPoint("CENTER", frame, "CENTER")
    orbs:Show()
    frame.orbs, frame.bubbles = orbs.orbs, orbs
    local icons = self:CreateStackSealIcons(frame, 16, 5)
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
        -- Tuck the panel's top edge behind the default mana-bar border so the
        -- two frames meet without a separate gold line or gap.
        frame:SetPoint("TOP", mana, "BOTTOM", -1, 1)
        frame.manaAnchor = mana
    end
    if not (InCombatLockdown and InCombatLockdown()) and mana.GetWidth then
        local ok, width = pcall(mana.GetWidth, mana)
        if ok and not (issecretvalue and issecretvalue(width))
            and type(width) == "number" and width > 0 then
            local pipSize = math.max(10, math.min(50, tonumber(iSTSettings.playerPipSize) or 18))
            local desired = math.max(width + 6, pipSize * 3 + 18)
            if frame.layoutWidth ~= desired then
                frame:SetWidth(desired)
                frame.layoutWidth = desired
            end
        end
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
    local showFrame = iSTSettings.showPlayerPipFrame ~= false
    if frame.frameStyleKey ~= tostring(icons) .. ":" .. tostring(showFrame) then
        local ok = pcall(frame.artwork.SetShown, frame.artwork, showFrame)
        if ok then frame.frameStyleKey = tostring(icons) .. ":" .. tostring(showFrame) end
    end
    frame.bubbles:SetShown(not icons)
    if icons then
        local source = self.State.TestMode and iSTSettings.twistFromSeal
        local texture = source and bar and bar.stackSealIcons[source]
        frame.sealIcons:SetShown(self.State.TestMode and count > 0 and texture ~= nil)
        if self.State.TestMode and texture then
            self:RenderStackSealIcons(frame.sealIcons, count, texture,
                self:GetTwistStackTarget(source))
        end
    else
        frame.sealIcons:Hide()
        local stage = self.State.TestMode and count or 0
        local source = self.State.TestMode and iSTSettings.twistFromSeal
            or self.State.WrathEchoSeal or self.WrathTracker.seal or iSTSettings.twistFromSeal
        self:RenderStackBubbles(frame.bubbles, stage, self:GetWrathCueColor(stage),
            self:GetTwistStackTarget(source))
    end
    frame:Show()
end
