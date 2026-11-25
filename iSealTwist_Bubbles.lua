local _, iST = ...
local CIRCLE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local PORTRAIT_SOCKET_DROP = 1
local IDLE_PIP_ALPHA = 0.35

local function PlaceStackPip(pip, strip, x)
    pip:ClearAllPoints()
    pip:SetPoint("CENTER", strip, "CENTER", x, 0)
end

local function SetStackPipSpacing(strip, step)
    if strip.pipStep == step then return end
    for index = 1, 3 do
        local x = (index - 2) * step
        if strip.orbs then
            PlaceStackPip(strip.orbs[index].socket, strip, x)
        else
            PlaceStackPip(strip.dimIcons[index], strip, x)
            PlaceStackPip(strip.brightIcons[index], strip, x)
        end
    end
    strip.pipStep = step
end

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
    SetStackPipSpacing(frame, size + gap)
    for _, orb in ipairs(frame.orbs) do
        orb.socket:SetSize(size, size)
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

function iST:CreateStackSealIcons(parent, size, gap, texture)
    local strip = CreateFrame("Frame", nil, parent)
    strip.pipGap, strip.pipSize = gap, size
    strip:SetSize(size * 3 + gap * 2, size + 8)
    strip:EnableMouse(false)
    strip.dimIcons, strip.brightIcons = {}, {}
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
        local bright = strip:CreateTexture(nil, "OVERLAY")
        bright:SetSize(size, size)
        bright:SetPoint("CENTER", strip, "CENTER", x, 0)
        bright:SetTexture(texture)
        bright:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local brightMask = strip:CreateMaskTexture()
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
    SetStackPipSpacing(strip, size + gap)
    for index = 1, 3 do
        strip.dimIcons[index]:SetSize(size, size)
        strip.brightIcons[index]:SetSize(size, size)
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

function iST:GetPlayerPipSize()
    return math.max(10, math.min(50, tonumber(iSTSettings.playerPipSize) or 18) - 2)
end

function iST:GetStackPipCenterOffset(strip)
    local visible = math.max(1, math.min(3, strip.visiblePips or 3))
    local step = strip.pipStep or (strip.pipSize or 18) + (strip.pipGap or 5)
    return (3 - visible) * step / 2
end

local function UsesPortraitSockets()
    return iSTSettings.showPlayerPipFrame ~= false and iSTSettings.playerPipFrameStyle == "PORTRAIT"
end

function iST:LayoutPlayerPipRow(strip, host, portrait)
    if not host then
        host = self.PlayerWrathFrame
        portrait = UsesPortraitSockets()
    end
    if not host or not strip then return end
    local size = self:GetPlayerPipSize()
    if portrait then
        -- Reserve space for three sockets and both ends so the row can grow
        -- without changing the size of existing pips.
        size = math.min(size, math.max(10, math.floor(((host.pipManaWidth or 106) - 3) * 0.22)))
    end
    if size ~= strip.pipSize then
        if strip.orbs then self:ResizeStackBubbles(strip, size)
        else self:ResizeStackSealIcons(strip, size) end
    end
    -- The inner opening spans about 70% of the square socket tile.
    local socketSize = math.floor(size / 0.70 + 0.5)
    local step = portrait and math.floor(socketSize * 0.94 + 0.5) or size + strip.pipGap
    SetStackPipSpacing(strip, step)
    local offset = self:GetStackPipCenterOffset(strip)
    local radius = socketSize / 2
    local y = portrait and -(radius + PORTRAIT_SOCKET_DROP) or 0
    if strip.playerPipHost ~= host or strip.playerPipXOffset ~= offset or strip.playerPipY ~= y then
        local ok = pcall(function()
            strip:ClearAllPoints()
            strip:SetPoint("CENTER", host, portrait and "TOP" or "CENTER", offset, y)
        end)
        if ok then strip.playerPipHost, strip.playerPipXOffset, strip.playerPipY = host, offset, y end
    end

    local visible = portrait and math.max(1, math.min(3, strip.visiblePips or 3)) or 0
    local art = strip.portraitArt
    if not art then
        if visible == 0 then return end
        local function AddPiece(layer, left, right, top, bottom)
            local texture = strip:CreateTexture(nil, "BACKGROUND", nil, layer)
            texture:SetTexture(self.AddonPath .. "Images\\Player_PipSockets.blp")
            texture:SetTexCoord(left / 128, right / 128, top / 64, bottom / 64)
            return texture
        end
        art = {
            sockets = {
                AddPiece(0, 0.5, 63.5, 0.5, 63.5),
                AddPiece(0, 0.5, 63.5, 0.5, 63.5),
                AddPiece(0, 0.5, 63.5, 0.5, 63.5),
            },
            rail = AddPiece(-2, 69.5, 122.5, 8.5, 55.5),
            left = AddPiece(-1, 0.5, 31.5, 28.5, 55.5),
            right = AddPiece(-1, 31.5, 0.5, 28.5, 55.5),
        }
        strip.portraitArt = art
    end
    if visible > 0 and art.size ~= socketSize then
        for index, texture in ipairs(art.sockets) do
            texture:SetSize(socketSize, socketSize)
            texture:SetPoint("CENTER", strip, "CENTER", (index - 2) * step, 0)
        end
    end
    if visible > 0 and (art.size ~= socketSize or art.visible ~= visible) then
        local shoulderWidth = math.max(10, math.floor(socketSize * 0.44 + 0.5))
        local shoulderHeight = math.max(6, math.floor(socketSize * 0.38 + 0.5)) + PORTRAIT_SOCKET_DROP
        local first, last = -step, (visible - 2) * step
        local top, overhang = radius + PORTRAIT_SOCKET_DROP, shoulderWidth * 0.3
        art.rail:SetSize(last - first + socketSize - shoulderWidth * 0.25,
            math.max(4, socketSize * 0.19) + PORTRAIT_SOCKET_DROP)
        art.rail:SetPoint("TOP", strip, "CENTER", (first + last) / 2, top)
        art.left:SetSize(shoulderWidth, shoulderHeight)
        art.left:SetPoint("TOPLEFT", strip, "CENTER", first - radius - overhang, top)
        art.right:SetSize(shoulderWidth, shoulderHeight)
        art.right:SetPoint("TOPRIGHT", strip, "CENTER", last + radius + overhang, top)
        art.size = socketSize
    end
    if art.visible ~= visible then
        for index, texture in ipairs(art.sockets) do texture:SetShown(index <= visible) end
        art.rail:SetShown(visible > 0)
        art.left:SetShown(visible > 0)
        art.right:SetShown(visible > 0)
        art.visible = visible
    end
end

function iST:CreateClassicPlayerPipFrame(frame, anchor)
    local artwork = CreateFrame("Frame", nil, frame)
    artwork:SetAllPoints(anchor or frame)
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
    return artwork
end

local function CreatePlayerPipDisplay(parent, host)
    local display = {
        bubbles = iST:CreateStackBubbles(parent, nil, 16, 10),
        sealIcons = iST:CreateStackSealIcons(parent, 16, 5),
        artwork = iST:CreateClassicPlayerPipFrame(parent, host),
    }
    display.bubbles:SetPoint("CENTER", host, "CENTER")
    display.sealIcons:SetPoint("CENTER", host, "CENTER")
    return display
end

local function CreatePlayerPipLayer(host)
    local layer = CreateFrame("Frame", nil, host)
    layer:SetAllPoints(host)
    layer:SetFrameLevel(host:GetFrameLevel())
    layer:EnableMouse(false)
    return layer
end

local function BuildPlayerPipPresence(host)
    local width = 1024
    local container = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")
    container:EnableMouse(false)
    container:SetUnit("player")
    iST:AddEchoPresenceGroup(container, host, width)

    -- The native group expands when an Echo exists. With no Echo only the
    -- empty row fits through its clip; with an Echo only the live gold frame
    -- fits. The existing native stack rows keep owning the filled pips.
    local function CreateClip(parent)
        local clip = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
        clip:SetClipsChildren(true)
        clip:SetFrameLevel(host:GetFrameLevel())
        clip:EnableMouse(false)
        return clip
    end
    local idleLayer = CreatePlayerPipLayer(host)
    local idleClip = CreateClip(idleLayer)
    idleClip:SetPoint("TOPLEFT", container, "TOPRIGHT", -1, 0)
    idleClip:SetPoint("BOTTOMRIGHT", host, "TOP", width / 2, -100)
    local goldLayer = CreatePlayerPipLayer(host)
    local activeClip = CreateClip(goldLayer)
    activeClip:SetPoint("TOPLEFT", host, "TOP", -width / 2, 0)
    activeClip:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", -1, -100)
    iST:CreateClassicPlayerPipFrame(activeClip, host)
    local idle = CreatePlayerPipDisplay(idleClip, host)
    container:SetEnabled(true)
    return { idle = idle, idleLayer = idleLayer, goldLayer = goldLayer }
end

local function RenderPlayerPips(display, host, count, texture, target, showGold, portrait)
    local useIcons = texture ~= nil
    if display.useIcons ~= useIcons then
        display.bubbles:SetShown(not useIcons)
        display.sealIcons:SetShown(useIcons)
        display.useIcons = useIcons
    end
    if display.showGold ~= showGold then
        display.artwork:SetShown(showGold)
        display.showGold = showGold
    end
    local row = useIcons and display.sealIcons or display.bubbles
    if useIcons then
        iST:RenderStackSealIcons(row, count, texture, target)
    else
        iST:RenderStackBubbles(row, count, iST:GetWrathCueColor(count), target)
    end
    iST:LayoutPlayerPipRow(row, host, portrait)
end

function iST:CreatePlayerWrathFrame()
    if self.PlayerWrathFrame then return end
    -- Keep the pip panel behind Blizzard's player frame artwork and allow
    -- the frame art to be hidden independently of the pips.
    local frame = CreateFrame("Frame", "iSTPlayerWrathFrame", UIParent)
    frame:SetSize(106, 28)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(0)
    frame:EnableMouse(false)
    frame.manualLayer = CreatePlayerPipLayer(frame)
    frame.manualDisplay = CreatePlayerPipDisplay(frame.manualLayer, frame)
    -- Keep checking the mana anchor while its pips are temporarily hidden.
    local updater = CreateFrame("Frame", nil, UIParent)
    updater:EnableMouse(false)
    updater:Hide()
    local elapsed = 0
    updater:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            iST:UpdatePlayerWrathBubbles(GetTime())
        end
    end)
    frame.updater = updater
    frame:Hide()
    self.PlayerWrathFrame = frame
end

function iST:UpdatePlayerWrathBubbles(now)
    local frame = self.PlayerWrathFrame
    if not frame then return end
    if not iSTSettings.showPlayerWrathBubbles or not self:ShouldShowBar() then
        frame.updater:Hide()
        frame:Hide()
        return
    end
    frame.updater:Show()
    local locked = InCombatLockdown and InCombatLockdown()
    local inCombat = self.State.InCombat or (issecretvalue and issecretvalue(locked)) or locked == true
    local preview = self.State.TestMode
    local iconStyle = iSTSettings.stackBubbleStyle == "SEAL_ICONS"
    local bar = self.BarFrame
    local native = not preview and bar and (iconStyle and bar.nativeSealIconsPlayerVisible == true
        or not iconStyle and bar.nativeStagePlayerVisible == true)
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
    if not inCombat and mana.GetWidth then
        local ok, width = pcall(mana.GetWidth, mana)
        if ok and not (issecretvalue and issecretvalue(width))
            and type(width) == "number" and width > 0 then
            local pipSize = math.max(10, math.min(50, tonumber(iSTSettings.playerPipSize) or 18))
            local desired = math.max(width + 6, pipSize * 3 + 18)
            if frame.layoutWidth ~= desired then
                frame:SetWidth(desired)
                frame.layoutWidth = desired
            end
            if frame.pipManaWidth ~= width then
                frame.pipManaWidth = width
                if UsesPortraitSockets() then self:LayoutStackPips() end
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
    local portrait = UsesPortraitSockets()
    local showGold = iSTSettings.showPlayerPipFrame ~= false and not portrait
    if native and not inCombat and not frame.presence and not frame.presenceFailed then
        local ok, presence = pcall(BuildPlayerPipPresence, frame)
        if ok then frame.presence = presence
        else
            frame.presenceFailed = true
            self:DebugMsg("Empty player pips could not attach to the Echo buff: " .. tostring(presence), 2)
        end
    end
    local presence = frame.presence
    local live = not not (native and presence)
    local showManual = not live and (not native or not self:HasConfirmedWrathStacks())
    if frame.manualShown ~= showManual then
        frame.manualLayer:SetShown(showManual)
        frame.manualShown = showManual
    end
    if presence then
        if presence.idleShown ~= live then
            presence.idleLayer:SetShown(live)
            presence.idleShown = live
        end
        local showActiveGold = live and showGold
        if presence.goldShown ~= showActiveGold then
            presence.goldLayer:SetShown(showActiveGold)
            presence.goldShown = showActiveGold
        end
    end
    if live or showManual then
        local layer = live and presence.idleLayer or frame.manualLayer
        local alpha = (inCombat or preview) and 1 or IDLE_PIP_ALPHA
        if layer.pipAlpha ~= alpha then
            layer:SetAlpha(alpha)
            layer.pipAlpha = alpha
        end
        if not live or not inCombat then
            local source = iSTSettings.twistFromSeal
            if not preview and self:HasActiveSeal() then source = self.State.CurrentSealName end
            local texture = iconStyle and bar and bar.stackSealIcons[source] or nil
            local target = self:GetTwistStackTarget(source)
            local count = preview and self:GetWrathDisplayState(now or GetTime()) or 0
            RenderPlayerPips(live and presence.idle or frame.manualDisplay, frame,
                count, texture, target, showGold, portrait)
        end
    end
    frame:Show()
end
