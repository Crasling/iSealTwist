local _, iST = ...

-- Changing seals or leaving combat does not clear stored stacks. Keep them
-- until they expire, are consumed, or the caller resets tracking.
function iST:NewWrathTracker()
    local tracker = { count = 0, seal = nil, expiresAt = 0, estimated = true }

    function tracker:Reset()
        self.count, self.seal, self.expiresAt = 0, nil, 0
        self.estimated = true
    end

    function tracker:GetCount(now)
        if self.count > 0 and now >= self.expiresAt then self:Reset() end
        return self.count
    end

    function tracker:Attack(seal, now)
        self:GetCount(now)
        if not seal then return 0 end
        if self.count > 0 and self.seal ~= seal then
            -- Tell the caller how many stacks were spent. This attack does not
            -- also start a new stack for the replacement seal.
            local consumed = self.count
            self:Reset()
            return consumed
        end
        -- Swing events do not tell us whether the attack hit. Estimate one stack
        -- per swing and a refreshed 15-second duration until a readable aura
        -- supplies the actual count and expiry.
        self.seal = seal
        self.count = math.min(3, self.count + 1)
        self.expiresAt = now + 15
        self.estimated = true
        return 0
    end

    -- The caller must check aura fields for secret values before passing them in.
    -- A readable aura replaces the estimate; allow a small expiry-time margin.
    function tracker:Observe(count, expiresAt, seal, now)
        if type(count) ~= "number" or count ~= count or count < 1 or count > 3
            or count ~= math.floor(count) or type(expiresAt) ~= "number"
            or expiresAt ~= expiresAt or expiresAt <= now or expiresAt > now + 15.5 then
            return false
        end
        -- Expire the old estimate before reusing its seal, so a stale seal cannot
        -- be attached to newly observed stacks.
        self:GetCount(now)
        self.count, self.expiresAt = count, expiresAt
        self.seal = self.seal or seal
        self.estimated = false
        return true
    end

    return tracker
end
