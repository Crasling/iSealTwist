-- Shareable setup codes and account-wide saved profiles. Codes contain data only;
-- they are never evaluated as Lua.
local _, iST = ...

local PREFIX = "iST1"
local MAX_CODE_LENGTH = 32000
local MAX_FIELDS = 300
local MAX_PROFILES = 30
local MAIN_NAME = "Main"
local PREVIOUS_NAME = "Previous setup"
local POSITION_TEMPLATES = {
    sealIconPoint = { 0, 0 },
    echoTimerPoint = { 0, 0 },
    stackCountPoint = { 0, 0 },
    verticalSwordPoint = { 0, 0 },
}
local ANCHORS = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
local NUMBER_LIMITS = {
    barWidth = { 100, 500 }, barHeight = { 15, 50 }, sealIconSize = { 16, 64 },
    swingTextSize = { 8, 28 }, stackCounterTextSize = { 10, 50 },
    wrathCircleSize = { 10, 50 }, playerPipSize = { 10, 50 },
    verticalSwordHeight = { 80, 280 }, verticalSwordOpacity = { 0, 100 },
    verticalSwordCorrectGlowScale = iST.CONSTANTS.VERTICAL_SWORD_GLOW_SCALE_RANGE,
    verticalSwordWrongGlowScale = iST.CONSTANTS.VERTICAL_SWORD_GLOW_SCALE_RANGE,
    sealTextSize = { 8, 24 }, latencyTextSize = { 8, 20 },
    nameplateEchoScale = { 0.5, 2 },
    nameplateEchoPipSize = { 10, 40 },
    nameplateEchoOffsetY = iST.CONSTANTS.NAMEPLATE_ECHO_OFFSET_RANGE, twistFromStacks = { 0, 3 },
    twistIntoStacks = { 0, 3 }, ["MinimapButton.minimapPos"] = { 0, 360 },
}
-- Accept the retired Wings fields in older setup codes without restoring them.
local RETIRED_WINGS_FIELDS = {
    showWorldEchoCue = "boolean",
    worldEchoCueStyle = "string", worldEchoCuePhase = "string", worldEchoCueScale = "number",
    ["worldEchoCueColor.r"] = "number", ["worldEchoCueColor.g"] = "number",
    ["worldEchoCueColor.b"] = "number", ["worldEchoCueColor.a"] = "number",
    ["worldEchoCuePoint.1"] = "number", ["worldEchoCuePoint.2"] = "number",
}

local function Schema()
    local schema = {}
    local function add(path, value, optional)
        if type(value) == "table" then
            for key, child in pairs(value) do
                add(path .. "." .. tostring(key), child, optional)
            end
        else
            schema[path] = { kind = type(value), default = value, optional = optional }
        end
    end
    for key, value in pairs(iST.SettingsDefault) do add(key, value, false) end
    add("sealBarColors", iST.SealBarColorDefaults, false)
    add("reminders", iST.ReminderDefaults, false)
    for key, value in pairs(POSITION_TEMPLATES) do add(key, value, true) end
    return schema
end

local function GetPath(root, path)
    local value = root
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[tonumber(part) or part]
    end
    return value
end

local function SetPath(root, path, value)
    local node = root
    local parts = {}
    for part in path:gmatch("[^%.]+") do parts[#parts + 1] = tonumber(part) or part end
    for index = 1, #parts - 1 do
        local key = parts[index]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[parts[#parts]] = value
end

local function ValidValue(path, value, kind)
    if type(value) ~= kind then return false end
    if kind == "string" then return #value <= 256 end
    if kind ~= "number" then return true end
    if value ~= value or value <= -math.huge or value >= math.huge
        or value < -10000 or value > 10000 then return false end
    local limits = NUMBER_LIMITS[path]
    if limits and (value < limits[1] or value > limits[2]) then return false end
    if path:match("%.[rgba]$") and (value < 0 or value > 1) then return false end
    return true
end

local function CleanSnapshot(data, requireValues)
    if type(data) ~= "table" then return nil, "Invalid settings data." end
    local schema, clean = Schema(), {}
    for path, spec in pairs(schema) do
        local value = GetPath(data, path)
        if value == nil and not spec.optional then
            if requireValues then return nil, "Missing setting: " .. path end
            value = spec.default
        end
        if value ~= nil then
            if not ValidValue(path, value, spec.kind) then
                return nil, "Invalid setting: " .. path
            end
            SetPath(clean, path, value)
        end
    end
    clean.swordFrameStyle = iST:NormalizeSwordStyle(clean.swordFrameStyle)
    iST:NormalizeVerticalSwordSettings(clean)
    for key in pairs(POSITION_TEMPLATES) do
        local point = clean[key]
        if point and (type(point[1]) ~= "number" or type(point[2]) ~= "number") then
            return nil, "Invalid position: " .. key
        end
    end
    for _, key in ipairs({ "barPoint", "centerSwitchPoint" }) do
        local point = clean[key]
        if not ANCHORS[point[1]] or not ANCHORS[point[3]] then
            return nil, "Invalid position: " .. key
        end
    end
    for kind, reminder in pairs(clean.reminders) do
        if not ANCHORS[reminder.point[1]] or not ANCHORS[reminder.point[2]] then
            return nil, "Invalid reminder position: " .. kind
        end
    end
    -- Accept older share codes with narrower bars, then use the current range.
    clean.barWidth = math.max(150, clean.barWidth)
    if not iST.SEAL_SPELL_IDS[clean.twistFromSeal]
        or not iST.SEAL_SPELL_IDS[clean.twistIntoSeal]
        or clean.twistFromSeal == clean.twistIntoSeal then
        return nil, "Invalid Seal pair."
    end
    return clean
end

local function Escape(value)
    return value:gsub("([^%w%-%._])", function(character)
        return string.format("%%%02X", character:byte())
    end)
end

local function Unescape(value)
    if value:gsub("%%%x%x", ""):find("%", 1, true) then return nil end
    local decoded = value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return decoded
end

local function Checksum(value)
    local sum = 0
    for index = 1, #value do sum = (sum * 31 + value:byte(index)) % 65521 end
    return sum
end

local function Encode(snapshot)
    local schema, fields = Schema(), {}
    for path, spec in pairs(schema) do
        local value = GetPath(snapshot, path)
        if value ~= nil then
            local encoded
            if spec.kind == "boolean" then encoded = value and "1" or "0"
            elseif spec.kind == "number" then encoded = string.format("%.17g", value)
            else encoded = Escape(value) end
            fields[#fields + 1] = Escape(path) .. "=" .. spec.kind:sub(1, 1) .. ":" .. encoded
        end
    end
    table.sort(fields)
    local body = table.concat(fields, ";")
    return PREFIX .. ":" .. #fields .. ":" .. Checksum(body) .. ";" .. body
end

local function ImportError(code, message)
    return string.format("[IST-IMP-%02d] %s", code, message)
end

local function Decode(code)
    if type(code) ~= "string" then return nil, ImportError(1, "Paste an iST settings code.") end
    code = code:gsub("%s+", "")
    if code == "" then return nil, ImportError(1, "Paste an iST settings code.") end
    if #code > MAX_CODE_LENGTH then return nil, ImportError(2, "Settings code is too long.") end
    local countText, checksumText, body = code:match("^" .. PREFIX .. ":(%d+):(%d+);(.+)$")
    local count = tonumber(countText)
    if not count or count < 1 or count > MAX_FIELDS or Checksum(body) ~= tonumber(checksumText) then
        return nil, ImportError(3, "Invalid or incomplete iST settings code.")
    end
    local schema, values, seen, found = Schema(), {}, {}, 0
    for field in body:gmatch("[^;]+") do
        local encodedPath, kind, encodedValue = field:match("^([^=]+)=([bns]):(.*)$")
        local path = encodedPath and Unescape(encodedPath)
        local spec = path and schema[path]
        local fieldType = spec and spec.kind or RETIRED_WINGS_FIELDS[path]
        if not fieldType or fieldType:sub(1, 1) ~= kind or seen[path] then
            return nil, ImportError(4, "Unsupported or duplicate setting in code.")
        end
        local value
        if kind == "b" then
            if encodedValue ~= "0" and encodedValue ~= "1" then
                return nil, ImportError(5, "Invalid setting: " .. path)
            end
            value = encodedValue == "1"
        elseif kind == "n" then value = tonumber(encodedValue)
        else value = Unescape(encodedValue) end
        if not ValidValue(path, value, fieldType) then
            return nil, ImportError(5, "Invalid setting: " .. path)
        end
        if spec then SetPath(values, path, value) end
        seen[path], found = true, found + 1
    end
    if found ~= count then return nil, ImportError(6, "Incomplete iST settings code.") end
    local snapshot, err = CleanSnapshot(values, false)
    if not snapshot then return nil, ImportError(5, err) end
    return snapshot
end

local function BaselineCode()
    local code = iSTSettings.activeProfileBaselineCode
    if not code then return nil end
    local snapshot = Decode(code)
    return snapshot and Encode(snapshot) or code
end

local function ProfileStore()
    if type(iSTAccountSettings) ~= "table" then iSTAccountSettings = {} end
    if type(iSTAccountSettings.profiles) ~= "table" then iSTAccountSettings.profiles = {} end
    local profiles = iSTAccountSettings.profiles
    if type(profiles[MAIN_NAME]) == "table" then
        local name, index = "Saved Main", 2
        while profiles[name] do
            name, index = "Saved Main " .. index, index + 1
        end
        profiles[name], profiles[MAIN_NAME] = profiles[MAIN_NAME], nil
    end
    -- Old versions stored the last setup as a shared, named profile.
    if type(profiles[PREVIOUS_NAME]) == "table" and type(iSTAccountSettings.legacyPreviousSetup) ~= "table" then
        iSTAccountSettings.legacyPreviousSetup = profiles[PREVIOUS_NAME]
    end
    profiles[PREVIOUS_NAME] = nil
    return profiles
end

local function PreviousSetup()
    local previous = iSTSettings.previousSetup
    if type(previous) == "table" and type(previous.settings) == "table" then
        local name = previous.profileName
        return previous.settings, type(name) == "string" and name or nil
    end
    ProfileStore()
    local legacy = iSTAccountSettings.legacyPreviousSetup
    if type(legacy) == "table" then return legacy end
end

local function SnapshotCode(data)
    local snapshot = CleanSnapshot(data, false)
    return snapshot and Encode(snapshot) or nil
end

local function MigratePortraitSockets()
    local style = iST.SettingsDefault.playerPipFrameStyle
    if not iSTAccountSettings.portraitSocketsMigrated then
        for _, profile in pairs(ProfileStore()) do
            if type(profile) == "table" then profile.playerPipFrameStyle = style end
        end
        local previous = iSTAccountSettings.legacyPreviousSetup
        if type(previous) == "table" then previous.playerPipFrameStyle = style end
        iSTAccountSettings.portraitSocketsMigrated = true
    end
    if iSTSettings.portraitSocketsMigrated then return end

    iSTSettings.playerPipFrameStyle = style
    if type(iSTSettings.mainProfile) == "table" then iSTSettings.mainProfile.playerPipFrameStyle = style end
    -- Migrate the baseline too so this change cannot look like a profile conflict.
    local baseline = iSTSettings.activeProfileBaselineCode and Decode(iSTSettings.activeProfileBaselineCode)
    if baseline then
        baseline.playerPipFrameStyle = style
        iSTSettings.activeProfileBaselineCode = Encode(baseline)
    end
    iSTSettings.portraitSocketsMigrated = true
end

local function StoreRecoveredProfile(profiles, oldName, snapshot)
    local base = ("Recovered " .. oldName):sub(1, 25)
    local name, index = base, 2
    while profiles[name] do
        name, index = base .. " " .. index, index + 1
    end
    profiles[name] = snapshot
    return name
end

local function RecoverProfile(profiles, oldName, snapshot)
    local name = StoreRecoveredProfile(profiles, oldName, snapshot)
    iSTSettings.activeProfileName = name
    iSTSettings.activeProfileBaselineCode = Encode(snapshot)
    return name
end

local function InstallSnapshot(snapshot, name, mainProfile)
    snapshot.mainProfile = mainProfile
    snapshot.previousSetup = iSTSettings.previousSetup
    snapshot.activeProfileName = name
    snapshot.activeProfileBaselineCode = name ~= MAIN_NAME and Encode(snapshot) or nil
    snapshot.generatedMacroBody = iSTSettings.generatedMacroBody
    snapshot.macroCreated = iSTSettings.macroCreated
    snapshot.hitDebugCapture = iSTSettings.hitDebugCapture
    snapshot.indicatorsMigrated = true
    snapshot.portraitSocketsMigrated = iSTSettings.portraitSocketsMigrated
    iSTSettings = snapshot
    iST:InitializeSettings()
end

function iST:ExportSettings()
    local snapshot, err = CleanSnapshot(iSTSettings, false)
    if not snapshot then return nil, err end
    return Encode(snapshot)
end

local function ResolveProfileName(name, profiles)
    local renames = iSTAccountSettings.profileRenames
    if type(renames) == "table" then
        for _ = 1, 10 do
            local updated = renames[name]
            if type(updated) ~= "string" or type(profiles[updated]) ~= "table" then break end
            name = updated
        end
    end
    return name
end

local function RestoredProfileName(name, snapshot)
    if name == MAIN_NAME then return name end
    local profiles = ProfileStore()
    local code = Encode(snapshot)
    if name then
        name = ResolveProfileName(name, profiles)
        if SnapshotCode(profiles[name]) == code then return name end
    elseif SnapshotCode(iSTSettings.mainProfile) == code then
        return MAIN_NAME
    end
    -- Keep the exact setup even if its saved profile changed or was deleted.
    return StoreRecoveredProfile(profiles, name or "setup", CleanSnapshot(snapshot, false))
end

function iST:GetActiveProfileName()
    local name = iSTSettings and iSTSettings.activeProfileName
    if type(name) ~= "string" or name == "" then return MAIN_NAME end
    local profiles = ProfileStore()
    if name == PREVIOUS_NAME then
        local snapshot = CleanSnapshot(iSTSettings, false)
        if snapshot and Encode(snapshot) ~= SnapshotCode(iSTSettings.mainProfile) then
            return RecoverProfile(profiles, "setup", snapshot)
        end
        iSTSettings.activeProfileName = MAIN_NAME
        iSTSettings.activeProfileBaselineCode = nil
        return MAIN_NAME
    end
    name = ResolveProfileName(name, profiles)
    iSTSettings.activeProfileName = name
    -- Preserve a character's current setup when another character deleted
    -- its active account profile. Its separate Main setup stays intact.
    if name ~= MAIN_NAME and type(profiles[name]) ~= "table" then
        local snapshot = CleanSnapshot(iSTSettings, false)
        if snapshot then return RecoverProfile(profiles, name, snapshot) end
    end
    return name
end

function iST:ReconcileActiveProfileOnLoad()
    MigratePortraitSockets()
    local active = self:GetActiveProfileName()
    if active == MAIN_NAME then return end
    local profiles = ProfileStore()
    local localSnapshot = CleanSnapshot(iSTSettings, false)
    local sharedSnapshot = CleanSnapshot(profiles[active], false)
    if not localSnapshot or not sharedSnapshot then return end
    local currentCode, sharedCode = Encode(localSnapshot), Encode(sharedSnapshot)
    local baseline = BaselineCode()
    if currentCode == sharedCode then
        iSTSettings.activeProfileBaselineCode = sharedCode
    elseif baseline and currentCode == baseline then
        -- The account copy changed while this character was offline.
        InstallSnapshot(sharedSnapshot, active, iSTSettings.mainProfile)
    elseif not baseline or sharedCode ~= baseline then
        -- Both copies may contain useful changes. Keep this character's
        -- settings under a separate name instead of overwriting either copy.
        RecoverProfile(profiles, active, localSnapshot)
    end
end

function iST:GetSavedProfileNames(includePrevious)
    local names = { MAIN_NAME }
    for name, profile in pairs(ProfileStore()) do
        if type(name) == "string" and name ~= MAIN_NAME and type(profile) == "table" then
            names[#names + 1] = name
        end
    end
    if includePrevious and PreviousSetup() then names[#names + 1] = PREVIOUS_NAME end
    table.sort(names, function(a, b)
        if a == MAIN_NAME then return true end
        if b == MAIN_NAME then return false end
        return a:lower() < b:lower()
    end)
    return names
end

local function NewProfileName(name, profiles, oldName)
    if type(name) ~= "string" then return nil, "Enter a profile name." end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 32 or name:find("[%c]") then
        return nil, "Use a name of 1-32 characters."
    end
    if name:lower() == MAIN_NAME:lower() or name:lower() == PREVIOUS_NAME:lower() then
        return nil, "This profile name is reserved."
    end
    for existing in pairs(profiles) do
        if existing ~= oldName and type(existing) == "string" and existing:lower() == name:lower() then
            return nil, "A profile with that name already exists."
        end
    end
    return name
end

function iST:RenameProfile(oldName, newName)
    if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before renaming profiles." end
    if oldName == MAIN_NAME or oldName == PREVIOUS_NAME then
        return false, "Main and Previous setup cannot be renamed."
    end
    local profiles = ProfileStore()
    if type(oldName) ~= "string" or type(profiles[oldName]) ~= "table" then
        return false, "Select a saved profile."
    end
    local validName, nameError = NewProfileName(newName, profiles, oldName)
    if not validName then return false, nameError end
    if validName == oldName then return false, "Choose a different name." end

    local snapshot = profiles[oldName]
    if self:GetActiveProfileName() == oldName then
        local current, err = CleanSnapshot(iSTSettings, false)
        if not current then return false, err end
        snapshot = current
        iSTSettings.activeProfileName = validName
        iSTSettings.activeProfileBaselineCode = Encode(current)
    end
    profiles[validName], profiles[oldName] = snapshot, nil
    if type(iSTAccountSettings.profileRenames) ~= "table" then
        iSTAccountSettings.profileRenames = {}
    end
    local renames = iSTAccountSettings.profileRenames
    for source, target in pairs(renames) do
        if target == oldName then renames[source] = validName end
    end
    renames[oldName] = validName
    renames[validName] = nil
    return true, validName
end

function iST:SaveActiveProfile()
    local snapshot, err = CleanSnapshot(iSTSettings, false)
    if not snapshot then return false, err end
    local active = self:GetActiveProfileName()
    if active == MAIN_NAME then
        iSTSettings.mainProfile = snapshot
        iSTSettings.activeProfileBaselineCode = nil
        return true
    end
    local profiles = ProfileStore()
    local currentCode, sharedCode = Encode(snapshot), SnapshotCode(profiles[active])
    local baseline = BaselineCode()
    if currentCode == sharedCode then
        iSTSettings.activeProfileBaselineCode = currentCode
    elseif currentCode == baseline then
        -- An unchanged character must not revert a newer shared profile.
        return true
    elseif not baseline or sharedCode ~= baseline then
        RecoverProfile(profiles, active, snapshot)
    else
        profiles[active] = snapshot
        iSTSettings.activeProfileBaselineCode = currentCode
    end
    return true
end

function iST:SaveProfile(name)
    if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before changing profiles." end
    local profiles = ProfileStore()
    local validName, nameError = NewProfileName(name, profiles)
    if not validName then return false, nameError end
    if #self:GetSavedProfileNames() - 1 >= MAX_PROFILES then return false, "Profile limit reached." end
    local snapshot, err = CleanSnapshot(iSTSettings, false)
    if not snapshot then return false, err end
    local saved, saveError = self:SaveActiveProfile()
    if not saved then return false, saveError end
    profiles[validName] = snapshot
    if type(iSTAccountSettings.profileRenames) == "table" then
        iSTAccountSettings.profileRenames[validName] = nil
    end
    iSTSettings.activeProfileName = validName
    iSTSettings.activeProfileBaselineCode = Encode(snapshot)
    return true, validName
end

function iST:DeleteProfile(name)
    if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before changing profiles." end
    local profiles = ProfileStore()
    if name == MAIN_NAME then return false, "Main cannot be deleted." end
    if name == PREVIOUS_NAME then return false, self.L["SettingsPreviousProfileDelete"] end
    if name == self:GetActiveProfileName() then return false, "Switch profiles before deleting the active one." end
    if type(name) ~= "string" or not profiles[name] then return false, "Select a saved profile." end
    profiles[name] = nil
    local renames = iSTAccountSettings.profileRenames
    if type(renames) == "table" then
        for source, target in pairs(renames) do
            if source == name or target == name then renames[source] = nil end
        end
    end
    return true
end

function iST:ApplyProfile(snapshot, targetName, restorePrevious)
    if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before changing settings." end
    local clean, err = CleanSnapshot(snapshot, false)
    if not clean then return false, err end
    local previous, backupError = CleanSnapshot(iSTSettings, false)
    if not previous then return false, backupError end
    local saved, saveError = self:SaveActiveProfile()
    if not saved then return false, saveError end
    local previousName = self:GetActiveProfileName()
    if restorePrevious then targetName = RestoredProfileName(targetName, clean) end
    InstallSnapshot(clean, targetName or MAIN_NAME, iSTSettings.mainProfile)
    iSTSettings.previousSetup = { settings = previous, profileName = previousName }
    return true
end

function iST:LoadProfile(name)
    if name == PREVIOUS_NAME then
        local snapshot, previousName = PreviousSetup()
        if not snapshot then return false, "There is no previous setup to restore." end
        return self:ApplyProfile(snapshot, previousName, true)
    end
    if name == self:GetActiveProfileName() then return false, "This profile is already active." end
    local profile = name == MAIN_NAME and iSTSettings.mainProfile or ProfileStore()[name]
    if type(profile) ~= "table" then return false, "Select a saved profile." end
    return self:ApplyProfile(profile, name)
end

iST.StarterProfiles = {
    { key = "MINIMAL", label = "StarterMinimal", settings = {
        barStyle = "BLOCK", barTexture = "SOLID", barWidth = 210, barHeight = 18,
        showStackCounter = true, showStackCircles = false, showStackSwordImages = false,
        showCenterSwitchText = false, showEchoTimer = false, showSealName = false, showLatency = false,
    } },
    { key = "PIPS", label = "StarterPips", settings = {
        barStyle = "CLASSIC", barTexture = "BLIZZARD", barWidth = 250, barHeight = 25,
        showStackCounter = false, showStackCircles = true, showStackSwordImages = false,
        stackBubbleStyle = "SEAL_ICONS", showCenterSwitchText = true, showEchoTimer = true,
        showSealName = true, showLatency = true,
    } },
    { key = "SWORD", label = "StarterSword", settings = {
        barStyle = "CLASSIC", barTexture = "BLIZZARD", barWidth = 250, barHeight = 25,
        showStackCounter = true, showStackCircles = false, showStackSwordImages = true,
        showCenterSwitchText = true, showEchoTimer = true,
        showSealName = true, showLatency = true,
    } },
}

local function CreateProfileFromSnapshot(self, snapshot, name)
    local profiles = ProfileStore()
    local validName, err = NewProfileName(name, profiles)
    if not validName then return false, err, 8 end
    if #self:GetSavedProfileNames() - 1 >= MAX_PROFILES then
        return false, "Profile limit reached.", 9
    end
    local applied, applyError = self:ApplyProfile(snapshot, validName)
    if not applied then return false, applyError, 10 end
    profiles[validName] = snapshot
    if type(iSTAccountSettings.profileRenames) == "table" then
        iSTAccountSettings.profileRenames[validName] = nil
    end
    return true, validName
end

function iST:ApplyStarterProfile(key)
    if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before changing profiles." end
    local starter
    for _, option in ipairs(self.StarterProfiles) do
        if option.key == key then starter = option; break end
    end
    if not starter then return false, "Select a display preset." end
    local snapshot, err = CleanSnapshot(iSTSettings, false)
    if not snapshot then return false, err end
    for setting, value in pairs(starter.settings) do snapshot[setting] = value end
    snapshot.showSwingBar = true
    snapshot.showStackBarColor = false
    snapshot.showVerticalSword = false
    snapshot.showPlayerWrathBubbles = false
    snapshot.showNameplateEcho = false
    snapshot.showSealIcon = true
    snapshot.showSealTimer = true
    snapshot.showWeaponSpeed = true
    snapshot.showSwingRemaining = true
    snapshot.barLocked = true
    snapshot.stackCountPoint, snapshot.sealIconPoint, snapshot.echoTimerPoint = nil, nil, nil

    local profiles = ProfileStore()
    local base = self.L[starter.label]
    for index = 1, MAX_PROFILES + 1 do
        local name = index == 1 and base or base .. " " .. index
        if NewProfileName(name, profiles) then
            return CreateProfileFromSnapshot(self, snapshot, name)
        end
    end
    return false, "No available name for this preset."
end

function iST:ImportSettings(code, requestedName)
    if InCombatLockdown and InCombatLockdown() then
        return false, ImportError(7, "Leave combat before importing settings.")
    end
    local snapshot, err = Decode(code)
    if not snapshot then return false, err end
    local profiles = ProfileStore()
    local name = requestedName
    if type(name) ~= "string" or name:match("^%s*$") then
        local index = 1
        repeat
            name = "Imported " .. index
            index = index + 1
        until not profiles[name] or index > MAX_PROFILES + 2
    end
    local ok, result, errorCode = CreateProfileFromSnapshot(self, snapshot, name)
    if not ok then return false, ImportError(errorCode, result) end
    return true, result
end
