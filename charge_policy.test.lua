return function(api, equal)
    local function sample(kind, elapsed)
        return {active = true, native = true, weapon = kind .. ":1", mode = "ammo",
            ammo = 1, reloading = false, charge_kind = kind, charging = true,
            charge_elapsed = elapsed, charge_limit = 3}
    end
    for _, kind in ipairs({"railgun", "epoch"}) do
        local policy, shot = api.Charge.new(), sample(kind, 2.6)
        equal(policy:step(shot, 1, true), false, "first charge reading waits")
        shot.charge_elapsed = 2.69
        equal(policy:step(shot, 1.1, true), false, "below 90 percent stays manual")
        shot.charge_elapsed = 2.7
        equal(policy:step(shot, 1.15, true), true, kind .. " fires at full-gauge 90 percent")
        shot.charge_elapsed = 2.75
        equal(policy:step(shot, 1.2, true), false, "one release per charge")
        policy:reset()
        equal(policy:step(shot, 1.25, false), false, "release does not rearm the latch")
        equal(policy:step(shot, 1.3, true), false, "injected release cannot repeat fire")
        shot.charge_elapsed = 0.05
        equal(policy:step(shot, 2, true), false, "new observed charge clears the latch")
        shot.charge_elapsed = 2.6
        equal(policy:step(shot, 4.55, true), false, "large read gap needs confirmation")
        shot.charge_elapsed = 2.7
        equal(policy:step(shot, 4.65, true), true, "new manually initiated charge can fire")
    end
    local policy, safe = api.Charge.new(), sample("railgun", 0.5)
    equal(policy:step(safe, 0, true), false)
    equal(policy:step(safe, 0.05, true), false, "safe mode capped below danger remains manual")
    for _, change in ipairs({
        {active = false}, {native = false}, {charge_kind = "quasar"},
        {charge_limit = 0}, {charge_limit = 0 / 0}, {charge_limit = math.huge},
        {charge_elapsed = -1}, {charge_elapsed = 3}, {charge_elapsed = 0 / 0},
        {charging = false}, {reloading = true}, {reloading = "unknown"},
        {manual_reload = true}, {switch_wait = true}, {ammo = 0}, {mode = "heat"},
    }) do
        local shot = sample("epoch", 2.7)
        for key, value in pairs(change) do shot[key] = value end
        policy = api.Charge.new()
        equal(policy:step(shot, 0, true), false)
        equal(policy:step(shot, 0.05, true), false, "invalid charge cannot send input")
    end
    local shot = sample("railgun", 2.7)
    policy = api.Charge.new()
    equal(policy:step(shot, 0, false), false)
    equal(policy:step(shot, 0.05, false), false, "no held fire means no release")
    equal(policy:step(shot, 0.1, true), false)
    equal(policy:step(shot, 0.151, true), true, "already-high charge needs two coherent reads")
    policy, shot = api.Charge.new(), sample("railgun", 2.6)
    policy:step(shot, 0, true)
    shot.weapon = "railgun:2"; shot.charge_elapsed = 2.7
    equal(policy:step(shot, 0.05, true), false, "swap does not reuse another weapon's reading")
    equal(policy:step(shot, 0.1, true), true)
    policy, shot = api.Charge.new(), sample("epoch", 0.5)
    policy:step(shot, 0, true); shot.charge_elapsed = 2.7
    equal(policy:step(shot, 0.05, true), false, "impossible charge jump fails closed")
end
