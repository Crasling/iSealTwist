-- Exchange installed versions through WoW's guild and group addon messages.
local _, iST = ...

local PREFIX = "iSTVersion"
local REPLY_COOLDOWN = 60
local channels = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }
local chat = C_ChatInfo

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function VersionNumber(version)
    if type(version) ~= "string" or #version > 11 then return end
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major or #major > 3 or #minor > 3 or #patch > 3 then return end
    return tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)
end

local version = VersionNumber(iST.Version)
if not version or not (chat and chat.SendAddonMessage and chat.RegisterAddonMessagePrefix
    and chat.IsAddonMessagePrefixRegistered) then return end
chat.RegisterAddonMessagePrefix(PREFIX)
if not chat.IsAddonMessagePrefixRegistered(PREFIX) then return end

local query, reply = "Q " .. iST.Version, "V " .. iST.Version
local groupChannel, guildQueried, groupQueried, queryPending
local firstNewerSender, notified
local replyStates = {}
local frame = CreateFrame("Frame")

local function IsMessagingLocked()
    local locked = chat.InChatMessagingLockdown and chat.InChatMessagingLockdown()
    return IsSecret(locked) or locked == true
end

local function GetGroupChannel()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function CancelPendingReply(channel)
    local state = replyStates[channel]
    if not state then return end
    if state.timer then state.timer:Cancel() end
    state.timer, state.waiting = nil, nil
end

local function TryPendingReply(channel, state)
    if not state.waiting or state.timer then return end
    local available = channel == "GUILD" and IsInGuild()
        or channel ~= "GUILD" and channel == GetGroupChannel()
    if not available then
        CancelPendingReply(channel)
        return
    end
    local now = GetTime()
    local delay = state.nextAt - now
    if delay > 0 then
        state.timer = C_Timer.NewTimer(delay, function()
            state.timer = nil
            TryPendingReply(channel, state)
        end)
        return
    end
    if IsMessagingLocked() then return end

    -- One broadcast answers everyone who asked while this channel was cooling down.
    state.nextAt = now + REPLY_COOLDOWN
    state.waiting = nil
    chat.SendAddonMessage(PREFIX, reply, channel)
end

local function QueueVersionReply(channel)
    local state = replyStates[channel]
    if not state then
        state = { nextAt = 0 }
        replyStates[channel] = state
    end
    if state.waiting then return end
    state.waiting = true
    TryPendingReply(channel, state)
end

local function QueryAvailableChannels()
    local currentGroup = GetGroupChannel()
    if currentGroup ~= groupChannel then
        if groupChannel then CancelPendingReply(groupChannel) end
        groupChannel = currentGroup
        groupQueried = false
    end

    local queryGuild = not guildQueried and IsInGuild()
    local queryGroup = groupChannel and not groupQueried
    queryPending = queryGuild or queryGroup
    if not queryPending or IsMessagingLocked() then return end

    -- Mark the attempt before sending. Roster updates and server errors do not
    -- trigger retries. A check held by lockdown can run when combat ends.
    queryPending = false
    if queryGuild then
        guildQueried = true
        chat.SendAddonMessage(PREFIX, query, "GUILD")
    end
    if queryGroup then
        groupQueried = true
        chat.SendAddonMessage(PREFIX, query, groupChannel)
    end
end

local function SenderKey(sender)
    sender = sender:lower()
    local name, realm = sender:match("^([^-]+)%-(.+)$")
    if not name then return sender end
    local localRealm = GetNormalizedRealmName()
    if IsSecret(localRealm) or not localRealm or localRealm == "" or realm == localRealm:lower() then
        return name
    end
    return sender
end

local function OnVersionMessage(prefix, message, channel, sender)
    if IsSecret(prefix) or prefix ~= PREFIX or IsSecret(channel) or not channels[channel] then return end
    if IsSecret(message) or type(message) ~= "string" or #message > 13 then return end
    if IsSecret(sender) or type(sender) ~= "string" or sender == "" then return end
    local kind, reported = message:match("^([QV]) (%S+)$")
    local remoteVersion = VersionNumber(reported)
    if not remoteVersion or remoteVersion == version then return end

    if remoteVersion > version then
        if notified then return end
        local senderKey = SenderKey(sender)
        if not firstNewerSender then
            firstNewerSender = senderKey
        elseif senderKey ~= firstNewerSender then
            notified = true
            frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
            iST:PrintToChat(iST.L["NewVersionAvailable"])
        end
        return
    end

    if kind == "Q" then QueueVersionReply(channel) end
end

local listening
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnVersionMessage(...)
        return
    end
    if not listening then
        listening = true
        self:RegisterEvent("CHAT_MSG_ADDON")
        self:RegisterEvent("PLAYER_GUILD_UPDATE")
        self:RegisterEvent("GROUP_LEFT")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    if event == "GROUP_LEFT" then
        if (...) == LE_PARTY_CATEGORY_INSTANCE then
            CancelPendingReply("INSTANCE_CHAT")
            if groupChannel == "INSTANCE_CHAT" then groupChannel = nil end
        else
            CancelPendingReply("PARTY")
            CancelPendingReply("RAID")
            if groupChannel == "PARTY" or groupChannel == "RAID" then groupChannel = nil end
        end
        return
    end
    if event == "PLAYER_GUILD_UPDATE" and replyStates.GUILD and not IsInGuild() then
        CancelPendingReply("GUILD")
    end
    if not notified and (event ~= "PLAYER_REGEN_ENABLED" or queryPending) then QueryAvailableChannels() end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        for channel, state in pairs(replyStates) do TryPendingReply(channel, state) end
    end
end)
