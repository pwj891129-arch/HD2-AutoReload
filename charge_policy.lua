local Charge = {}
Charge.__index = Charge

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Charge.new()
    return setmetatable({}, Charge)
end

function Charge:reset()
    self.previous = nil
    -- Keep the one-shot latch across focus, menu and read gaps.
end

function Charge:step(sample, now, fire)
    if not sample or not sample.active or not sample.native or not sample.weapon or
        (sample.charge_kind ~= "railgun" and sample.charge_kind ~= "epoch") or
        not finite(now) or not finite(sample.charge_elapsed) or
        not finite(sample.charge_limit) or sample.charge_limit < 0.1 or
        sample.charge_limit > 30 or sample.charge_elapsed < 0 or
        (sample.charge_kind == "railgun" and sample.charge_elapsed >= sample.charge_limit) or
        (sample.charge_kind == "epoch" and (not finite(sample.charge_max) or
            sample.charge_max < sample.charge_limit or sample.charge_max > 30 or
            sample.charge_elapsed > sample.charge_max)) then
        self:reset(); return false
    end
    local elapsed, limit = sample.charge_elapsed, sample.charge_limit
    if self.fired and (self.fired.weapon ~= sample.weapon or elapsed <= 0.1) then
        self.fired = nil
    end
    if not fire or sample.charging ~= true or sample.reloading ~= false or
        sample.manual_reload or sample.switch_wait or sample.mode ~= "ammo" or
        not finite(sample.ammo) or sample.ammo <= 0 then
        self:reset(); return false
    end
    local previous = self.previous
    self.previous = { weapon = sample.weapon, kind = sample.charge_kind,
        elapsed = elapsed, limit = limit, maximum = sample.charge_max, at = now }
    if self.fired or not previous or previous.weapon ~= sample.weapon or
        previous.kind ~= sample.charge_kind or previous.limit ~= limit or
        previous.maximum ~= sample.charge_max or now <= previous.at or now - previous.at > 0.2 or
        elapsed < previous.elapsed or elapsed - previous.elapsed > now - previous.at + 0.1 or
        elapsed < limit * (sample.charge_kind == "epoch" and 1 or 0.9) then return false end
    self.fired = { weapon = sample.weapon }
    return true
end

return Charge
