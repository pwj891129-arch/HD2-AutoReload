return function(api, equal)
    local function sample(ammo, held, pressed, released)
        return {active = true, native = true, mode = "ammo", weapon = "stationary",
            ammo = ammo, reserve = 2, reloading = false, reload_allow_move = false,
            fire_held = held, fire_pressed = pressed, fire_released = released,
            fire = pressed or released or false}
    end
    local p = api.Policy.new()
    equal(p:step(sample(1, false), 0), nil)
    equal(p:step(sample(1, true, true), 0.1), nil, "loaded stationary press does not interrupt firing")
    equal(p:step(sample(0, true, false), 0.2), nil, "last shot while held never starts stationary reload")
    for i = 1, 20 do
        local s = sample(0, false, false, true)
        s.unconfirmed = i == 1
        equal(p:step(s, 0.2 + i * 0.05), nil, "stationary release window never starts or arms reload")
    end
    equal(p:step(sample(0, false), 1.3), nil, "blocked release has no late pending attempt")
    local trigger, action = p:step(sample(0, true, true), 1.4)
    equal(trigger, "fire-attempt", "new empty stationary click requests reload")
    equal(action, "release-fire", "only the new empty click may release fire input")
    p:released_fire(1.4)
    equal(p:step(sample(0, false), 1.45), nil, "reload waits for the game's firing release to settle")
    equal(p:step(sample(0, false), 1.47), "fire-attempt", "authorized click reloads after fire release")
    p:sent(1.47)
    equal(p:step(sample(0, false), 1.9), nil, "stationary press authorization is consumed once")

    p = api.Policy.new()
    local s = sample(0, true, true); s.unconfirmed = true
    equal(p:step(s, 0), nil, "initial empty click still requires confirmation")
    s.fire_pressed, s.fire = false, false
    s.unconfirmed = false
    trigger, action = p:step(s, 0.05)
    equal(trigger, "fire-attempt", "two coherent empty reads retain the original stationary click")
    equal(action, "release-fire", "confirmation while held can release only the authorized click")
    p:released_fire(0.05)
    equal(p:step(s, 0.12), nil, "failed game release observation never emits reload or another fire release")
    equal(p:step(s, 0.5), nil, "stuck held click expires without repetition")

    for _, fault in ipairs({"reserve", "manual_reload", "reloading", "active", "ammo", "reload_allow_move", "weapon"}) do
        p = api.Policy.new()
        p:step(sample(0, true, true), 0); p:released_fire(0)
        s = sample(0, false)
        if fault == "reserve" then s.reserve = 0
        elseif fault == "manual_reload" or fault == "reloading" then s[fault] = true
        elseif fault == "active" then s.active = false
        elseif fault == "ammo" then s.ammo = 1
        elseif fault == "reload_allow_move" then s.reload_allow_move = nil
        else s.weapon = "other"; s.ammo = 2 end
        equal(p:step(s, 0.1), nil, fault .. " prevents stale click reload")
    end
    p = api.Policy.new(); p:step(sample(0, true, true), 0); p:released_fire(0); p:reset()
    equal(p:step(sample(0, false), 0.1), nil, "focus/menu reset discards click authorization")

    for _, allow in ipairs({false, true}) do
        p = api.Policy.new()
        s = sample(2, false); s.reload_allow_move = allow; p:step(s, 0)
        s.weapon, s.ammo, s.switch_ready = "swapped", 0, true
        equal(p:step(s, 1.2), "weapon-swapped", "swap-triggered reload is retained for both reload styles")
    end
    p = api.Policy.new(); p:step(sample(1, false), 0)
    s = sample(0, false, false, true); s.reload_allow_move = true
    equal(p:step(s, 0.1), "ammo-exhausted", "moving reload keeps exhaustion at release")
    p = api.Policy.new(); s = sample(0, false, false, true); s.reload_allow_move = nil
    equal(p:step(s, 0), nil, "unknown native reload style cannot force an immobile release reload")
    equal(p:step(s, 0.1), nil, "unknown release never turns into a fire edge")

    p = api.Policy.new(); s = sample(nil, false)
    s.mode, s.overheated = "heat", false; p:step(s, 0)
    s.overheated, s.fire_released, s.fire = true, true, true
    equal(p:step(s, 0.1), nil, "stationary complete-overheat release is also suppressed")
    s.fire_held, s.fire_pressed, s.fire_released = true, true, false
    trigger, action = p:step(s, 0.2)
    equal(trigger, "fire-attempt", "overheated stationary weapon accepts the next click")
    equal(action, "release-fire")
end
