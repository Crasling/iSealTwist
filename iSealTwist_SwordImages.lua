local _, iST = ...
local ASSET_PATH = "Interface\\AddOns\\iSealTwist\\Images\\Frames\\"
local SOURCE_SIZE = 1024
-- The timer fits inside this opening in the original artwork.
local OPEN_LEFT, OPEN_RIGHT = 246, 890
local OPEN_TOP, OPEN_BOTTOM = 475, 545
local Tint

local function AddRegion(frame, asset, x1, y1, x2, y2)
    local texture = frame:CreateTexture(nil, "BORDER")
    texture:SetTexture(ASSET_PATH .. asset .. ".blp")
    texture:SetTexCoord(x1 / SOURCE_SIZE, x2 / SOURCE_SIZE, y1 / SOURCE_SIZE, y2 / SOURCE_SIZE)
    texture:AddMaskTexture(frame.glowMask)
    frame.regions[#frame.regions + 1] = { texture = texture, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
    return texture
end

local function LayoutImages(bar, frame)
    frame = frame or bar.wrathSwordImages
    local width, height = bar:GetWidth(), bar:GetHeight()
    if frame.layoutWidth == width and frame.layoutHeight == height then return end
    frame.layoutWidth, frame.layoutHeight = width, height
    -- Fit the opening to the bar; the hilt and tip extend beyond its ends.
    local scaleX = width / (OPEN_RIGHT - OPEN_LEFT)
    local scaleY = height / (OPEN_BOTTOM - OPEN_TOP)
    frame.leftOverhang = OPEN_LEFT * scaleX
    for _, region in ipairs(frame.regions) do
        region.texture:ClearAllPoints()
        region.texture:SetPoint("TOPLEFT", bar, "TOPLEFT",
            (region.x1 - OPEN_LEFT) * scaleX, (OPEN_TOP - region.y1) * scaleY)
        region.texture:SetSize((region.x2 - region.x1) * scaleX, (region.y2 - region.y1) * scaleY)
    end
end

function iST:CreateNativeSwordStage(bar, parent, stage)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(bar)
    frame:EnableMouse(false)
    frame.regions = {}
    local glowMask = frame:CreateMaskTexture()
    glowMask:SetTexture(ASSET_PATH .. "Sword_GlowEdgeMask.tga")
    frame.glowMask = glowMask
    frame.regions[#frame.regions + 1] = {
        texture = glowMask, x1 = 0, y1 = 0, x2 = SOURCE_SIZE, y2 = SOURCE_SIZE,
    }
    frame.pieces = {}
    for index = 1, stage do
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

function iST:UpdateNativeSwordStage(bar, frame, color)
    LayoutImages(bar, frame)
    local nativeGold = iSTSettings.wrathColorScheme == "GOLD"
    for _, pieces in ipairs(frame.pieces) do
        for _, texture in ipairs(pieces) do Tint(texture, color, nativeGold, 1) end
    end
end

function iST:CreateSwordImageCue(bar)
    if bar.wrathSwordImages then return end
    local frame = CreateFrame("Frame", nil, bar)
    frame:SetAllPoints(bar)
    frame:SetFrameLevel(bar:GetFrameLevel() + 1)
    frame:EnableMouse(false)
    frame.regions, frame.pieces = {}, {}

    -- Feather both layers over a wider margin. The mask protects the solid
    -- pommel and blade tip so only the surrounding halo fades into the world.
    local glowMask = frame:CreateMaskTexture()
    glowMask:SetTexture(ASSET_PATH .. "Sword_GlowEdgeMask.tga")
    frame.glowMask = glowMask
    frame.regions[#frame.regions + 1] = {
        texture = glowMask, x1 = 0, y1 = 0, x2 = SOURCE_SIZE, y2 = SOURCE_SIZE,
    }
    frame.base = AddRegion(frame, "Sword_Base", 0, 0, SOURCE_SIZE, SOURCE_SIZE)

    -- Cut the glow into thirds from the same full-size image as the base so the
    -- joins stay aligned. Draw above and below the timer to keep its text clear.
    for stage = 1, 3 do
        local x1 = OPEN_LEFT + (OPEN_RIGHT - OPEN_LEFT) * (stage - 1) / 3
        local x2 = OPEN_LEFT + (OPEN_RIGHT - OPEN_LEFT) * stage / 3
        local piece = {
            AddRegion(frame, "Sword_Glow", x1, 0, x2, OPEN_TOP),
            AddRegion(frame, "Sword_Glow", x1, OPEN_BOTTOM, x2, SOURCE_SIZE),
        }
        -- The hilt lights with the first stack; the tip lights with the third.
        if stage == 1 then
            piece[#piece + 1] = AddRegion(frame, "Sword_Glow", 0, 0, OPEN_LEFT, SOURCE_SIZE)
        elseif stage == 3 then
            piece[#piece + 1] = AddRegion(frame, "Sword_Glow", OPEN_RIGHT, 0, SOURCE_SIZE, SOURCE_SIZE)
        end
        frame.pieces[stage] = piece
    end
    frame:Hide()
    bar.wrathSwordImages = frame
    LayoutImages(bar)
end

Tint = function(texture, color, nativeGold, opacity)
    -- Keep the artwork's own gold, but remove it before applying another palette.
    texture:SetDesaturated(not nativeGold)
    if nativeGold then texture:SetVertexColor(1, 1, 1, (color.a or 1) * opacity)
    else texture:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * opacity) end
end

function iST:UpdateSwordImageCue(bar, count, visible, color)
    local frame = bar.wrathSwordImages
    if not frame then return end
    if not visible then frame:Hide() return end
    LayoutImages(bar)
    local nativeGold = iSTSettings.wrathColorScheme == "GOLD"
    -- Keep the unlit outline visible while each stack adds another glowing third.
    Tint(frame.base, self:GetWrathCueColor(0), nativeGold, 0.45)
    frame.base:Show()
    for stage, piece in ipairs(frame.pieces) do
        for _, texture in ipairs(piece) do
            texture:SetShown(stage <= count)
            if stage <= count then Tint(texture, color, nativeGold, 1) end
        end
    end
    frame:Show()
    bar:SetBackdropBorderColor(0, 0, 0, 0)
end
