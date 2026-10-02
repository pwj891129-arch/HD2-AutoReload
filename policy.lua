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
    self.press_wait = nil
    self.fire = false
end

function Policy:step(sample, now)
    local vehicle = sample and sample.vehicle == true
    local stationary = sample and not vehicle and sample.reload_allow_move == false
    local press_reload = stationary or vehicle
    local released = sample and sample.fire_released == true
    local block_release = released and not vehicle and sample.reload_allow_move ~= true and
        (stationary or sample.native == true)
    if press_reload and sample.fire_pressed == true then
        self.press_wait = {weapon = sample.weapon, until_time = now + 0.25}
    end
    local waiting_press = press_reload and self.press_wait and
        self.press_wait.weapon == sample.weapon and now <= self.press_wait.until_time
    local pending_press = press_reload and self.pending and self.pending.press_intent and
        self.pending.weapon == sample.weapon and now <= self.pending.until_time
    -- The game ignores reload while firing; inspect only the initial press until release.
    if sample and sample.fire_held == true and sample.fire_pressed ~= true and
        not waiting_press and not pending_press then
        return nil
    end
    if sample and sample.active == true and sample.mode == "ammo" and
        sample.reloading == true then
        self.weapon, self.mode, self.seen_at = sample.weapon, sample.mode, now
        self.empty = nil
        if finite(sample.ammo) then self.empty = sample.ammo == 0 end
        self.pending, self.fire_wait_until = nil, nil
        self.press_wait = nil
        self.fire = sample.fire == true
        return nil
    end
    if sample and sample.unconfirmed then
        if sample.fire == true and not block_release and not self.fire then
            self.fire_wait_until = now + 0.25
        end
        self.fire = sample.fire == true and not block_release
        return nil
    end
    if not sample or sample.active ~= true then
        self:reset()
        return nil
    end
    local firing = sample.fire == true and not block_release
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
    local entered_vehicle = vehicle and self.weapon ~= weapon
    local exhausted = self.weapon == weapon and self.mode == mode and
        self.empty == false and empty
    self.weapon, self.mode, self.empty, self.seen_at = weapon, mode, empty, now
    if sample.switch_wait then
        self.pending, self.fire_wait_until = nil, nil
        self.press_wait = nil
        return nil
    end
    if not empty then
        if vehicle then self.vehicle_sent_weapon = nil end
        self.pending, self.fire_wait_until = nil, nil
        self.press_wait = nil
        return nil
    end
    if mode == "heat" and self.heat_sent_weapon == weapon then return nil end
    if vehicle and self.vehicle_sent_weapon == weapon and not waiting_press and not fire_edge then return nil end
    if self.pending and (self.pending.weapon ~= weapon or self.pending.mode ~= mode or
        now > self.pending.until_time or
        (self.pending.fire_release and (sample.fire_released ~= true or block_release)) or
        (self.pending.press_intent and not press_reload)) then
        self.pending = nil
    end
    local reason = waiting_press and "fire-attempt" or
        entered_vehicle and "vehicle-empty" or
        not block_release and exhausted and (mode == "heat" and "overheated" or "ammo-exhausted") or
        swapped and "weapon-swapped" or
        sample.switch_ready and "weapon-swapped" or
        not block_release and sample.fire_released and "fire-released" or
        not block_release and (fire_edge or (self.fire_wait_until and now <= self.fire_wait_until))
            and "fire-attempt" or nil
    self.fire_wait_until = nil
    if reason and not (self.pending and self.pending.weapon == weapon and
        self.pending.mode == mode and self.pending.reason == reason) then
        self.pending = { weapon = weapon, mode = mode, reason = reason,
            vehicle = vehicle,
            since = now, reserve = sample.reserve, until_time = now + 0.35,
            fire_release = sample.fire_released == true and not block_release,
            press_intent = press_reload and waiting_press and true or nil }
    end
    if not self.pending then return nil end
    if sample.manual_reload then
        self.pending = nil
        self.press_wait = nil
        return nil
    end
    if sample.reloading == true then
        if vehicle then self.pending = nil; return nil end
        if mode ~= "heat" or self.pending.reserve ~= sample.reserve then
            self.pending = nil
            return nil
        end
        if now - self.pending.since < 0.15 then return nil end
    end
    if sample.reloading == nil or not finite(sample.reserve) or
        sample.reserve <= 0 or
        now - self.last_sent < 0.35 then return nil end
    if self.pending.release_due and now < self.pending.release_due then return nil end
    if sample.fire_held == true then
        if self.pending.press_intent and not self.pending.release_due then
            return self.pending.reason, "release-fire"
        end
        return nil
    end
    return self.pending.reason
end

function Policy:released_fire(now)
    if not self.pending or not self.pending.press_intent then return end
    self.pending.release_due = now + 0.06
    self.press_wait, self.fire_wait_until = nil, nil
end

function Policy:sent(now)
    if self.pending and self.pending.vehicle then
        self.vehicle_sent_weapon = self.weapon
    end
    if self.pending and self.pending.mode == "heat" then
        self.heat_sent_weapon = self.pending.weapon
    end
    self.last_sent, self.pending = now, nil
    self.press_wait = nil
end

return Policy
