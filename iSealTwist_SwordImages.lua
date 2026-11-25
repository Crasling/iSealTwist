local _, iST = ...
local ASSET_PATH = "Interface\\AddOns\\iSealTwist\\Images\\Frames\\"
local FIRST_SWORD_FILL_SECONDS = 0.65
local SOURCE_SIZE = 1024
-- The timer fits inside this opening in the original artwork.
local OPEN_LEFT, OPEN_RIGHT = 246, 890
local OPEN_TOP, OPEN_BOTTOM = 475, 545
local swordStyles = { "Ashbringer", "Frostmourne", "Lightbringer" }
local frameStyles = {
    Ashbringer = { r = 1, g = 0.70, b = 0.44 },
    Frostmourne = { r = 0.62, g = 0.86, b = 1 },
    Lightbringer = { r = 1, g = 0.95, b = 0.72 },
    CorruptedAshbringer = { r = 0.52, g = 1, b = 0.34 },
}
local bladeStyles = { CorruptedAshbringer = 0.5 }
local legacyBladeStyles = {}
for _, name in ipairs(swordStyles) do
    local forged = name .. "_Forged"
    bladeStyles[forged] = 0.25
    legacyBladeStyles[name] = forged
end

local ashbringerVariants = {
    { value = "RadiantAshbringer", label = "SwordStyleRadiantAshbringer", color = { r = 1, g = 0.80, b = 0.24 } },
    { value = "EmberforgedAshbringer", label = "SwordStyleEmberforgedAshbringer", color = { r = 1, g = 0.27, b = 0.15 } },
    { value = "FrostboundAshbringer", label = "SwordStyleFrostboundAshbringer", color = { r = 0.22, g = 0.72, b = 1 } },
}
local variantColors = {}
for _, variant in ipairs(ashbringerVariants) do
    bladeStyles[variant.value] = bladeStyles.CorruptedAshbringer
    variantColors[variant.value] = variant.color
end

-- Bounds of the glow on the Corrupted Ashbringer atlas, from one-third to full.
local corruptedBladeTop = { 102, 77, 51, 0 }
local corruptedBladeBottom = 154
-- Blade bounds in the 256px atlas tiles, excluding the grip.
local bladeBounds = {
    V_CorruptedAshbringer = { 0, corruptedBladeBottom },
    V_Ashbringer_Forged = { 16, 146 },
    V_Frostmourne_Forged = { 16, 152 },
    V_Lightbringer_Forged = { 16, 150 },
}
-- Eye sockets and crossguard details relative to the center of each atlas tile.
local hiltGlowLayout = {
    Ashbringer_Forged = { { 2, 156, 12 }, { 2, 167, 12 } },
    CorruptedAshbringer = { { -4, 178, 12 }, { 5, 178, 12 } },
    Frostmourne_Forged = { { -1, 170, 17 } },
    Lightbringer_Forged = { { -1, 164, 19 } },
}
local hiltGlowColors = {
    ACTIVE = { 0.24, 1, 0.31 },
    SWITCH = { 1, 0.11, 0.08 },
}
-- Crops of the skull, flame, and Ashbringer crossguard.
-- Reuse the sword art so the phase tint aligns with every blade size.
local swordWarningLayouts = {
    CorruptedAshbringer = { asset = "V_CorruptedAshbringer", width = 128,
        { 10, 21, 67, 93 }, { 28, 40, 82, 97 } },
    Ashbringer_Forged = { asset = "V_Ashbringer_Forged", width = 64, { 15, 147, 49, 180 } },
}

function iST:NormalizeSwordStyle(style, vertical, fallback)
    local styles = vertical and bladeStyles or frameStyles
    if styles[style] then return style end
    if vertical then return legacyBladeStyles[style] or fallback or self.SettingsDefault.verticalSwordStyle end
    return self.SettingsDefault.swordFrameStyle
end

function iST:NormalizeVerticalSwordSettings(settings)
    if settings.verticalSwordMode ~= "PER_SEAL" then
        settings.verticalSwordMode = self.SettingsDefault.verticalSwordMode
    end
    settings.verticalSwordStyle = self:NormalizeSwordStyle(settings.verticalSwordStyle, true)
    settings.verticalSwordSecondStyle = self:NormalizeSwordStyle(settings.verticalSwordSecondStyle, true,
        self.SettingsDefault.verticalSwordSecondStyle)
    local range = self.CONSTANTS.VERTICAL_SWORD_GLOW_SCALE_RANGE
    for _, key in ipairs({ "verticalSwordCorrectGlowScale", "verticalSwordWrongGlowScale" }) do
        local scale = tonumber(settings[key])
        if not scale or scale ~= scale then scale = self.SettingsDefault[key] end
        settings[key] = math.floor(math.max(range[1], math.min(range[2], scale)) + 0.5)
    end
end

function iST:GetSwordStyleChoices(vertical)
    local choices = {}
    if not vertical then
        choices[1] = { value = "Original", text = self.L["SwordStyleOriginal"] }
        for _, name in ipairs(swordStyles) do
            choices[#choices + 1] = { value = name, text = name }
        end
    end
    choices[#choices + 1] = { value = "CorruptedAshbringer", text = "Corrupted Ashbringer" }
    if vertical then
        for _, variant in ipairs(ashbringerVariants) do
            choices[#choices + 1] = { value = variant.value, text = self.L[variant.label] }
        end
        for _, name in ipairs(swordStyles) do
            choices[#choices + 1] = {
                value = name .. "_Forged", text = self.L["SwordStyleForged"]:format(name),
            }
        end
    end
    return choices
end

local function SetVerticalSwordTile(texture, asset, tile, top, bottom)
    if texture.swordAsset == asset and texture.swordTile == tile then return end
    if texture.swordAsset ~= asset then
        texture:SetTexture(ASSET_PATH .. "Swords\\" .. asset .. ".blp")
        texture.swordAsset = asset
    end
    texture.swordTile = tile
    local column, row = tile % 4, math.floor(tile / 4)
    local tileWidth = asset == "V_CorruptedAshbringer" and 128 or 64
    texture:SetTexCoord((tileWidth * column + 0.5) / (4 * tileWidth),
        (tileWidth * (column + 1) - 0.5) / (4 * tileWidth),
        (256 * row + 0.5 + 255 * (top or 0) / 256) / 512,
        (256 * row + 0.5 + 255 * (bottom or 256) / 256) / 512)
end

function iST:GetVerticalSwordAspectRatio(style)
    return bladeStyles[style]
end

function iST:CreateVerticalSwordArtwork(parent, anchor)
    local artwork = parent:CreateTexture(nil, "ARTWORK")
    artwork:SetPoint("CENTER", anchor, "CENTER")
    local fill = parent:CreateTexture(nil, "OVERLAY")
    fill:SetBlendMode("ADD")
    fill:SetDesaturated(true)
    fill:Hide()
    artwork.swordFill = fill
    return artwork
end

local function SetSwordOpacity(texture, opacity)
    if texture.swordOpacity == opacity then return end
    texture:SetAlpha(opacity)
    texture.swordOpacity = opacity
end

local function RenderLightbringerMedallion(artwork, style, height, opacity, lit)
    local medallion = artwork.lightbringerMedallion
    if style ~= "Lightbringer_Forged" or not lit or opacity <= 0 then
        if medallion and medallion.swordVisible then
            medallion:Hide()
            medallion.swordVisible = false
        end
        return
    end

    -- The medallion sits below the blade, so it needs its own stack glow.
    local left, top, right, bottom = 18, 152, 44, 178
    if not medallion then
        local parent = artwork:GetParent()
        medallion = parent:CreateTexture(nil, "OVERLAY", nil, 1)
        medallion:SetTexture(ASSET_PATH .. "Swords\\V_Lightbringer_Forged.blp")
        medallion:SetTexCoord((left + 0.5) / 256, (right - 0.5) / 256,
            (256 + top + 0.5) / 512, (256 + bottom - 0.5) / 512)
        medallion:SetDesaturated(true)
        medallion:SetBlendMode("ADD")
        medallion:SetVertexColor(1, 0.83, 0.30, 0.58)
        local mask = parent:CreateMaskTexture()
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        mask:SetAllPoints(medallion)
        medallion:AddMaskTexture(mask)
        artwork.lightbringerMedallion = medallion
    end
    if medallion.swordHeight ~= height then
        local scale = height / 256
        medallion:SetSize((right - left) * scale, (bottom - top) * scale)
        medallion:SetPoint("TOPLEFT", artwork, "TOPLEFT", left * scale, -top * scale)
        medallion.swordHeight = height
    end
    SetSwordOpacity(medallion, opacity)
    if not medallion.swordVisible then
        medallion:Show()
        medallion.swordVisible = true
    end
end

local function GetVerticalSwordStyle(seal)
    local settings = iSTSettings
    if settings.verticalSwordMode == "PER_SEAL" and seal == settings.twistIntoSeal then
        return settings.verticalSwordSecondStyle
    end
    return settings.verticalSwordStyle
end

function iST:GetVerticalSwordHiltLayout(seal)
    local style = GetVerticalSwordStyle(seal)
    if variantColors[style] then style = "CorruptedAshbringer" end
    return hiltGlowLayout[style]
end

function iST:GetVerticalSwordWarningLayout(seal, includeDisabled)
    if iSTSettings.showVerticalSwordPhaseMarker == false and not includeDisabled then return end
    local style = GetVerticalSwordStyle(seal)
    if variantColors[style] then style = "CorruptedAshbringer" end
    return swordWarningLayouts[style]
end

function iST:CreateVerticalSwordWarning(parent, anchor)
    return { parent = parent, anchor = anchor, textures = {} }
end

local function SwordGlowOpacity(opacity)
    if iSTSettings.fadeVerticalSwordGlow == false then return 1 end
    return opacity or iSTSettings.verticalSwordOpacity / 100
end

local function SetVerticalSwordWarningColor(warning, status)
    if warning.status == status then return end
    local color = hiltGlowColors[status]
    for _, texture in ipairs(warning.textures) do
        texture:SetVertexColor(color[1], color[2], color[3])
    end
    warning.status = status
end

function iST:RenderVerticalSwordWarning(warning, layout, height, status, swordOpacity)
    local opacity = SwordGlowOpacity(swordOpacity)
    local shown = status ~= nil and layout ~= nil and opacity > 0
    if shown then SetVerticalSwordWarningColor(warning, status) end
    if warning.layout == layout and warning.height == height and warning.shown == shown
        and warning.opacity == opacity then return end
    if shown then
        local scale = height / 256
        for index, bounds in ipairs(layout) do
            local texture = warning.textures[index]
            local newTexture = not texture
            if not texture then
                texture = warning.parent:CreateTexture(nil, "OVERLAY", nil, 2)
                texture:SetDesaturated(true)
                local color = hiltGlowColors[status]
                texture:SetVertexColor(color[1], color[2], color[3])
                local mask = warning.parent:CreateMaskTexture()
                mask:SetTexture(ASSET_PATH .. "Sword_WarningMask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(texture)
                texture:AddMaskTexture(mask)
                warning.textures[index] = texture
            end
            if newTexture or warning.drawnLayout ~= layout or warning.drawnHeight ~= height then
                local left, top, right, bottom = unpack(bounds)
                texture:SetTexture(ASSET_PATH .. "Swords\\" .. layout.asset .. ".blp")
                texture:SetTexCoord((left + 0.5) / (4 * layout.width), (right - 0.5) / (4 * layout.width),
                    (256 + top + 0.5) / 512, (256 + bottom - 0.5) / 512)
                texture:SetSize((right - left) * scale, (bottom - top) * scale)
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", warning.anchor, "CENTER",
                    (left - layout.width / 2) * scale, (128 - top) * scale)
            end
            SetSwordOpacity(texture, opacity)
        end
        warning.drawnLayout, warning.drawnHeight = layout, height
    end
    for index, texture in ipairs(warning.textures) do texture:SetShown(shown and layout[index] ~= nil) end
    warning.layout, warning.height, warning.shown, warning.opacity = layout, height, shown, opacity
end

function iST:CreateVerticalSwordHiltGlow(parent, anchor)
    local glow = { anchor = anchor, lights = {} }
    for index = 1, 2 do
        local light = parent:CreateTexture(nil, "OVERLAY", nil, 3)
        light:SetTexture(ASSET_PATH .. "Sword_HiltGlow.tga")
        light:SetBlendMode("ADD")
        light:Hide()
        glow.lights[index] = light
    end
    return glow
end

function iST:RenderVerticalSwordHiltGlow(glow, layout, height, status, opacity)
    local settings = iSTSettings
    local scale = (status == "SWITCH" and settings.verticalSwordWrongGlowScale
        or settings.verticalSwordCorrectGlowScale) / 100
    opacity = SwordGlowOpacity(opacity)
    if not settings.showVerticalSwordSealGlow or opacity == 0 then status = nil end
    if glow.layout == layout and glow.height == height and glow.status == status
        and glow.scale == scale and glow.opacity == opacity then return end
    glow.layout, glow.height, glow.status, glow.scale, glow.opacity = layout, height, status, scale, opacity
    local color = hiltGlowColors[status]
    for index, light in ipairs(glow.lights) do
        local detail = layout and layout[index]
        if detail and color then
            local size = detail[3] * height / 256 * scale
            light:SetSize(size, size)
            light:ClearAllPoints()
            light:SetPoint("CENTER", glow.anchor, "CENTER", detail[1] * height / 256, (128 - detail[2]) * height / 256)
            light:SetVertexColor(color[1], color[2], color[3], opacity * 0.9)
            light:Show()
        else
            light:Hide()
        end
    end
end

function iST:RenderVerticalSword(texture, count, seal, height, previewOpacity)
    local settings = iSTSettings
    local style = GetVerticalSwordStyle(seal)
    local target = math.max(1, self:GetTwistStackTarget(seal))
    -- The atlas holds unlit, one-third, half, two-thirds, and fully lit artwork.
    local tile = 0
    if count >= target then tile = 4
    elseif count > 0 then tile = target == 2 and 2 or (count == 2 and 3 or 1) end
    local color = variantColors[style]
    local asset = color and "V_CorruptedAshbringer" or "V_" .. style
    local showFill = color ~= nil and count > 0
    SetVerticalSwordTile(texture, asset, showFill and 0 or tile)

    local width = height * self:GetVerticalSwordAspectRatio(style)
    if texture.swordWidth ~= width or texture.swordHeight ~= height then
        texture:SetSize(width, height)
        texture.swordWidth, texture.swordHeight = width, height
    end

    local opacity = previewOpacity or (count == 0 and 0.10 or settings.verticalSwordOpacity / 100)
    SetSwordOpacity(texture, opacity)
    RenderLightbringerMedallion(texture, style, height, opacity, count > 0)

    local fill = texture.swordFill
    if fill.swordVisible ~= showFill then
        fill:SetShown(showFill)
        fill.swordVisible = showFill
    end
    if not showFill then return end

    local top, bottom = corruptedBladeTop[tile], corruptedBladeBottom
    SetVerticalSwordTile(fill, asset, tile, top, bottom)
    if fill.swordHeight ~= height or fill.swordTop ~= top or fill.swordBottom ~= bottom then
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", texture, "TOPLEFT", 0, -height * top / 256)
        fill:SetPoint("BOTTOMRIGHT", texture, "TOPRIGHT", 0, -height * bottom / 256)
        fill.swordHeight, fill.swordTop, fill.swordBottom = height, top, bottom
    end
    if fill.swordColor ~= color then
        fill:SetVertexColor(color.r, color.g, color.b, 1)
        fill.swordColor = color
    end
    SetSwordOpacity(fill, opacity)
end

function iST:CreateAnimatedVerticalSword(parent, anchor)
    local base = parent:CreateTexture(nil, "ARTWORK")
    base:SetPoint("CENTER", anchor, "CENTER")

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:EnableMouse(false)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local barTexture = bar:GetStatusBarTexture()
    barTexture:SetAlpha(0)

    -- Let Blizzard move the clip's upper edge. The sword texture stays at
    -- its full size, so the atlas never stretches as the blade fills.
    local clip = CreateFrame("Frame", nil, bar, "DisableUntrustedLayoutScriptsTemplate")
    clip:EnableMouse(false)
    clip:SetClipsChildren(true)
    clip:SetPoint("TOPLEFT", barTexture, "TOPLEFT")
    clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    local glow = clip:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints(base)
    return { base = base, bar = bar, clip = clip, glow = glow }
end

function iST:CreateVerticalSwordFillSweep(sword)
    local mask = sword.clip:CreateMaskTexture()
    mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(sword.clip)
    local group = sword.clip:CreateAnimationGroup()
    local sweep = group:CreateAnimation("Scale")
    sweep:SetTarget(mask)
    sweep:SetOrigin("BOTTOM", 0, 0)
    sweep:SetScaleFrom(1, 0)
    sweep:SetScaleTo(1, 1)
    sweep:SetDuration(FIRST_SWORD_FILL_SECONDS)
    sweep:SetSmoothing("IN_OUT")
    sword.glow:AddMaskTexture(mask)
    return group
end

function iST:RenderAnimatedVerticalSword(sword, seal, height, previewCount)
    local settings = iSTSettings
    local style = GetVerticalSwordStyle(seal)
    local tint = variantColors[style]
    local asset = tint and "V_CorruptedAshbringer" or "V_" .. style
    if sword.asset ~= asset or sword.height ~= height then
        local bounds = bladeBounds[asset]
        local base, bar = sword.base, sword.bar
        base:SetSize(height * self:GetVerticalSwordAspectRatio(style), height)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", base, "TOPLEFT", 0, -height * bounds[1] / 256)
        bar:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT", 0, -height * bounds[2] / 256)
        SetVerticalSwordTile(base, asset, 0)
        SetVerticalSwordTile(sword.glow, asset, 4)
        sword.asset, sword.height = asset, height
    end
    if sword.tint ~= tint then
        sword.glow:SetDesaturated(tint ~= nil)
        sword.glow:SetBlendMode(tint and "ADD" or "BLEND")
        sword.glow:SetVertexColor(tint and tint.r or 1, tint and tint.g or 1, tint and tint.b or 1)
        sword.tint = tint
    end
    local opacity = previewCount == 0 and 0.10 or settings.verticalSwordOpacity / 100
    SetSwordOpacity(sword.base, opacity)
    SetSwordOpacity(sword.glow, opacity)
    RenderLightbringerMedallion(sword.base, style, height, opacity, previewCount ~= 0)
    if previewCount ~= nil then
        local target = self:GetTwistStackTarget(seal)
        local count = math.min(previewCount, target)
        local targetChanged = sword.previewTarget ~= target
        if targetChanged then
            sword.bar:SetMinMaxValues(0, target)
            sword.previewTarget = target
        end
        if sword.previewCount ~= count or targetChanged then
            local interpolation = Enum.StatusBarInterpolation
            local first = count > 0 and (sword.previewCount or 0) == 0
            if first and not sword.previewSweep and not sword.previewSweepFailed then
                local ok, sweep = pcall(self.CreateVerticalSwordFillSweep, self, sword)
                if ok then sword.previewSweep = sweep else sword.previewSweepFailed = true end
            end
            local sweep = sword.previewSweep
            if sweep and (first or count == 0) then sweep:Stop() end
            local smooth = count > 0 and not (first and sweep)
            sword.bar:SetValue(count, smooth and interpolation.ExponentialEaseOut or interpolation.Immediate)
            sword.previewCount = count
            if first and sweep then sweep:Play() end
        end
    end
end

function iST:UsesSwordImages()
    return iSTSettings.showSwingBar and iSTSettings.showStackSwordImages
end

-- Fill the three sword sections by the selected number of Echo stacks.
-- A >0 selection uses the same first-stack cue as a target of one.
function iST:GetSwordImageGlowStage(count, target)
    if count <= 0 then return 0 end
    if target <= 1 then return 3 end
    if target == 2 and count >= 2 then return 3 end
    return math.min(3, count)
end

function iST:GetSwordImageTextOffset(bar, visible)
    return visible and math.ceil(bar:GetHeight() * 0.65) + 3 or 2
end

function iST:GetSwordImagePipLift()
    return self:UsesSwordImages() and 8 or 0
end

function iST:GetSwordImageOverhangRatios()
    local width = OPEN_RIGHT - OPEN_LEFT
    return OPEN_LEFT / width, (SOURCE_SIZE - OPEN_RIGHT) / width
end

local function AddRegion(frame, asset, x1, y1, x2, y2)
    local texture = frame:CreateTexture(nil, "BORDER")
    texture:SetTexture(ASSET_PATH .. asset .. ".blp")
    texture:SetTexCoord(x1 / SOURCE_SIZE, x2 / SOURCE_SIZE, y1 / SOURCE_SIZE, y2 / SOURCE_SIZE)
    texture:AddMaskTexture(frame.glowMask)
    frame.regions[#frame.regions + 1] = { texture = texture, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
    return texture
end

local function LayoutImages(bar, frame)
    local width, height = bar:GetWidth(), bar:GetHeight()
    if frame.layoutWidth == width and frame.layoutHeight == height then return end
    frame.layoutWidth, frame.layoutHeight = width, height
    -- Fit the opening to the bar; the hilt and tip extend beyond its ends.
    local scaleX = width / (OPEN_RIGHT - OPEN_LEFT)
    local scaleY = height / (OPEN_BOTTOM - OPEN_TOP)
    frame.leftOverhang = OPEN_LEFT * scaleX
    frame.rightOverhang = (SOURCE_SIZE - OPEN_RIGHT) * scaleX
    for _, region in ipairs(frame.regions) do
        region.texture:ClearAllPoints()
        region.texture:SetPoint("TOPLEFT", bar, "TOPLEFT",
            (region.x1 - OPEN_LEFT) * scaleX, (OPEN_TOP - region.y1) * scaleY)
        region.texture:SetSize((region.x2 - region.x1) * scaleX, (region.y2 - region.y1) * scaleY)
    end
end

local function Tint(texture, color, tint, opacity)
    texture:SetDesaturated(tint ~= nil)
    local alpha = (color.a or 1) * opacity
    if tint then texture:SetVertexColor(tint.r, tint.g, tint.b, alpha)
    else texture:SetVertexColor(1, 1, 1, alpha) end
end

local function RenderSwordFrame(bar, frame, color, litStage)
    LayoutImages(bar, frame)
    local baseColor = iST:GetWrathCueColor(0)
    local baseTint, glowTint
    if iSTSettings.wrathColorScheme == "GOLD" then
        -- The default palette keeps Original's gold and the other styles' tints.
        glowTint = frameStyles[iSTSettings.swordFrameStyle]
        baseTint = glowTint
    else
        baseTint, glowTint = baseColor, color
    end
    if frame.base then Tint(frame.base, baseColor, baseTint, 0.45) end
    for index, pieces in ipairs(frame.pieces) do
        for _, texture in ipairs(pieces) do
            local visible = index <= litStage
            texture:SetShown(visible)
            if visible then Tint(texture, color, glowTint, 1) end
        end
    end
end

local function CreateSwordFrame(bar, parent, showBase)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(bar)
    frame:EnableMouse(false)
    if showBase then frame:SetFrameLevel(bar:GetFrameLevel() + 1) end
    frame.regions, frame.pieces = {}, {}

    -- Feather the pommel and tip halo on every style.
    local glowMask = frame:CreateMaskTexture()
    glowMask:SetTexture(ASSET_PATH .. "Sword_GlowEdgeMask.tga")
    frame.glowMask = glowMask
    frame.regions[#frame.regions + 1] = {
        texture = glowMask, x1 = 0, y1 = 0, x2 = SOURCE_SIZE, y2 = SOURCE_SIZE,
    }
    if showBase then
        frame.base = AddRegion(frame, "Sword_Base", 0, 0, SOURCE_SIZE, SOURCE_SIZE)
        frame.base:Show()
    end

    -- Cut the same glow into thirds for preview and native aura stages.
    for index = 1, 3 do
        local x1 = OPEN_LEFT + (OPEN_RIGHT - OPEN_LEFT) * (index - 1) / 3
        local x2 = OPEN_LEFT + (OPEN_RIGHT - OPEN_LEFT) * index / 3
        local pieces = {
            AddRegion(frame, "Sword_Glow", x1, 0, x2, OPEN_TOP),
            AddRegion(frame, "Sword_Glow", x1, OPEN_BOTTOM, x2, SOURCE_SIZE),
        }
        if index == 1 then
            pieces[#pieces + 1] = AddRegion(frame, "Sword_Glow", 0, 0, OPEN_LEFT, SOURCE_SIZE)
        elseif index == 3 then
            pieces[#pieces + 1] = AddRegion(frame, "Sword_Glow", OPEN_RIGHT, 0, SOURCE_SIZE, SOURCE_SIZE)
        end
        frame.pieces[index] = pieces
    end
    LayoutImages(bar, frame)
    frame:Hide()
    return frame
end

function iST:CreateNativeSwordStage(bar, parent)
    return CreateSwordFrame(bar, parent, false)
end

function iST:UpdateNativeSwordStage(bar, frame, color, litStage)
    RenderSwordFrame(bar, frame, color, litStage)
end

function iST:CreateSwordImageCue(bar)
    if bar.wrathSwordImages then return end
    bar.wrathSwordImages = CreateSwordFrame(bar, bar, true)
end

function iST:UpdateSwordImageCue(bar, count, visible, color, target)
    local frame = bar.wrathSwordImages
    if not frame then return end
    if not visible then frame:Hide() return end
    RenderSwordFrame(bar, frame, color, self:GetSwordImageGlowStage(count, target or 3))
    frame:Show()
    local artwork = bar.artwork or bar
    artwork:SetBackdropBorderColor(0, 0, 0, 0)
end
