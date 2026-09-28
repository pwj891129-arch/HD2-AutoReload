local Policy = {}
Policy.__index = Policy

local function finite(value)
    return type(value) == "number" and value == value and
        value >= 0 and value < math.huge
end

function Policy.new()
    return setmetatable({ fire = false, last_sent = -math.huge }, Policy)
end

function Policy:reset()
    self.weapon, self.mode, self.empty, self.seen_at, self.pending = nil, nil, nil, nil, nil
    self.fire_wait_until = nil
    self.fire = false
end

function Policy:step(sample, now)
    if not sample or sample.active ~= true then
        self:reset()
        return nil
    end
    local firing = sample.fire == true
    local fire_edge = firing and not self.fire
    self.fire = firing
    local weapon = sample.weapon
    local mode = sample.mode
    local known = (mode == "ammo" and finite(sample.ammo)) or
        (mode == "heat" and type(sample.overheated) == "boolean")
    if weapon == nil or not known then
        -- Keep a short swap transition, but never use stale weapon state to reload.
        if self.seen_at and now - self.seen_at > 0.5 then
            self.weapon, self.mode, self.empty, self.pending = nil, nil, nil, nil
        end
        if fire_edge then self.fire_wait_until = now + 0.25 end
        return nil
    end
    local empty
    if mode == "heat" then empty = sample.overheated
    else empty = sample.ammo == 0 end
    if self.heat_sent_weapon and (weapon ~= self.heat_sent_weapon or not empty) then
        self.heat_sent_weapon = nil
    end
    local swapped = self.weapon ~= nil and self.weapon ~= weapon
    local exhausted = self.weapon == weapon and self.mode == mode and
        self.empty == false and empty
    self.weapon, self.mode, self.empty, self.seen_at = weapon, mode, empty, now
    if not empty then
        self.pending, self.fire_wait_until = nil, nil
        return nil
    end
    if mode == "heat" and self.heat_sent_weapon == weapon then return nil end
    if self.pending and (self.pending.weapon ~= weapon or self.pending.mode ~= mode or
        now > self.pending.until_time) then self.pending = nil end
    local reason = exhausted and (mode == "heat" and "overheated" or "ammo-exhausted") or
        swapped and "weapon-swapped" or
        (fire_edge or (self.fire_wait_until and now <= self.fire_wait_until))
            and "fire-attempt" or nil
    self.fire_wait_until = nil
    if reason then
        self.pending = { weapon = weapon, mode = mode, reason = reason,
            since = now, reserve = sample.reserve, until_time = now + 0.35 }
    end
    if not self.pending then return nil end
    if sample.manual_reload then
        self.pending = nil
        return nil
    end
    if sample.reloading == true then
        if mode ~= "heat" or self.pending.reserve ~= sample.reserve then
            self.pending = nil
            return nil
        end
        if now - self.pending.since < 0.15 then return nil end
    end
    if sample.reloading == nil or not finite(sample.reserve) or
        sample.reserve <= 0 or
        now - self.last_sent < 0.35 then return nil end
    return self.pending.reason
end

function Policy:sent(now)
    if self.pending and self.pending.mode == "heat" then
        self.heat_sent_weapon = self.pending.weapon
    end
    self.last_sent, self.pending = now, nil
end

return Policy
