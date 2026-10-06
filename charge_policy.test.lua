return function(api, equal)
    local function sample(kind, elapsed)
        return {active = true, native = true, weapon = kind .. ":1", mode = "ammo",
            ammo = 1, reloading = false, charge_kind = kind, charging = true,
            charge_elapsed = elapsed, charge_limit = kind == "epoch" and 2.5 or 3,
            charge_max = kind == "epoch" and 2.6 or 3}
    end
    for _, kind in ipairs({"railgun", "epoch"}) do
        local target = kind == "epoch" and 2.5 or 3 * 0.95
        local policy, shot = api.Charge.new(), sample(kind, target - 0.1)
        equal(policy:step(shot, 1, true), false, "first charge reading waits")
        shot.charge_elapsed = target - 0.01
        equal(policy:step(shot, 1.1, true), false, "below weapon-specific threshold stays manual")
        shot.charge_elapsed = target
        equal(policy:step(shot, 1.15, true), true, kind .. " fires at its exact threshold")
        shot.charge_elapsed = target + 0.05
        equal(policy:step(shot, 1.2, true), false, "one release per charge")
        policy:reset()
        equal(policy:step(shot, 1.25, false), false, "release does not rearm the latch")
        equal(policy:step(shot, 1.3, true), false, "injected release cannot repeat fire")
        shot.charge_elapsed = 0.05
        equal(policy:step(shot, 2, true), false, "new observed charge clears the latch")
        shot.charge_elapsed = target - 0.1
        equal(policy:step(shot, 4.55, true), false, "large read gap needs confirmation")
        shot.charge_elapsed = target
        equal(policy:step(shot, 4.65, true), true, "new manually initiated charge can fire")
    end
    local policy, safe = api.Charge.new(), sample("railgun", 0.5)
    equal(policy:step(safe, 0, true), false)
    equal(policy:step(safe, 0.05, true), false, "safe mode capped below danger remains manual")
    for _, change in ipairs({
        {active = false}, {native = false}, {charge_kind = "quasar"},
        {charge_limit = 0}, {charge_limit = 0 / 0}, {charge_limit = math.huge},
        {charge_elapsed = -1}, {charge_elapsed = 3}, {charge_elapsed = 0 / 0},
        {charge_max = 0}, {charge_max = 31}, {charge_max = 0 / 0},
        {charging = false}, {reloading = true}, {reloading = "unknown"},
        {manual_reload = true}, {switch_wait = true}, {ammo = 0}, {mode = "heat"},
    }) do
        local shot = sample("epoch", 2.5)
        for key, value in pairs(change) do shot[key] = value end
        policy = api.Charge.new()
        equal(policy:step(shot, 0, true), false)
        equal(policy:step(shot, 0.05, true), false, "invalid charge cannot send input")
    end
    local shot = sample("railgun", 3 * 0.95)
    policy = api.Charge.new()
    equal(policy:step(shot, 0, false), false)
    equal(policy:step(shot, 0.05, false), false, "no held fire means no release")
    equal(policy:step(shot, 0.1, true), false)
    equal(policy:step(shot, 0.151, true), true, "already-high charge needs two coherent reads")
    policy, shot = api.Charge.new(), sample("railgun", 2.6)
    policy:step(shot, 0, true)
    shot.weapon = "railgun:2"; shot.charge_elapsed = 3 * 0.95
    equal(policy:step(shot, 0.05, true), false, "swap does not reuse another weapon's reading")
    equal(policy:step(shot, 0.1, true), true)
    for _, limit in ipairs({3, 5}) do
        policy, shot = api.Charge.new(), sample("railgun", limit * 0.9)
        shot.charge_limit, shot.charge_max = limit, limit
        equal(policy:step(shot, 1, true), false, "Railgun first reading waits")
        equal(policy:step(shot, 1.05, true), false, "Railgun 90 percent must not fire")
        shot.charge_elapsed = limit * 0.949
        equal(policy:step(shot, 1.25, true), false, "Railgun below 95 percent stays manual")
        shot.charge_elapsed = limit * 0.95
        equal(policy:step(shot, 1.30, true), true, "Railgun fires at 95 percent of native limit")
        equal(policy:step(shot, 1.35, true), false, "Railgun 95 percent plateau fires once")
    end
    for _, threshold in ipairs({0.9, 0.95}) do
        for _, limit in ipairs({3, 5}) do
            local target = limit * threshold
            policy, shot = api.Charge.new(), sample("railgun", target - 0.01)
            shot.charge_limit, shot.charge_max = limit, limit
            equal(policy:step(shot, 1, true, threshold), false, "selected Railgun threshold first read waits")
            equal(policy:step(shot, 1.05, true, threshold), false, "selected threshold does not release early")
            shot.charge_elapsed = target
            equal(policy:step(shot, 1.1, true, threshold), true, "selected 90 or 95 percent threshold fires exactly")
            equal(policy:step(shot, 1.15, true, threshold), false, "selected threshold releases only once")
        end
        policy, shot = api.Charge.new(), sample("epoch", 2.5 * threshold)
        policy:step(shot, 1, true, threshold)
        equal(policy:step(shot, 1.05, true, threshold), false, "Railgun choice never lowers Epoch full-charge threshold")
        shot.charge_elapsed = 2.5
        equal(policy:step(shot, 1.22, true, threshold), true, "Epoch remains at 100 percent for either Railgun choice")
    end
    for _, threshold in ipairs({false, true, "0.9", 0.91, 0 / 0, math.huge}) do
        policy, shot = api.Charge.new(), sample("railgun", 2.9)
        equal(policy:step(shot, 1, true, threshold), false, "invalid threshold cannot release Railgun")
        equal(policy:step(shot, 1.05, true, threshold), false, "invalid threshold remains blocked")
        policy, shot = api.Charge.new(), sample("epoch", 2.5)
        policy:step(shot, 1, true, threshold)
        equal(policy:step(shot, 1.05, true, threshold), true, "invalid Railgun choice does not disable Epoch")
    end
    policy, shot = api.Charge.new(), sample("epoch", 0.5)
    policy:step(shot, 0, true); shot.charge_elapsed = 2.5
    equal(policy:step(shot, 0.05, true), false, "impossible charge jump fails closed")
    policy, shot = api.Charge.new(), sample("epoch", 2.25)
    policy:step(shot, 0, true)
    equal(policy:step(shot, 0.05, true), false, "Epoch 90 percent must not fire")
    shot.charge_elapsed = 2.499
    equal(policy:step(shot, 0.25, true), false, "Epoch does not fire early using a tolerance")
    shot.charge_elapsed = 2.5
    equal(policy:step(shot, 0.30, true), true, "Epoch accepts a gauge clamped exactly to full")
    equal(policy:step(shot, 0.35, true), false, "full-charge plateau fires once")
    policy, shot = api.Charge.new(), sample("epoch", 2.55)
    policy:step(shot, 0, true)
    equal(policy:step(shot, 0.05, true), true, "Epoch delayed sample above full still fires")
    policy, shot = api.Charge.new(), sample("railgun", 3)
    policy:step(shot, 0, true)
    equal(policy:step(shot, 0.05, true), false, "Railgun explosion limit is not a usable charge")
    policy, shot = api.Charge.new(), sample("epoch", 2.5)
    policy:step(shot, 0, true); shot.charge_max = 2.7
    equal(policy:step(shot, 0.05, true), false, "changed charge configuration needs confirmation")
end
