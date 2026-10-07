return function(api, equal)
    local input = {runtime_rearm = true, recovery_fire = true}
    local resumed, fresh = api.resume_on_press(input, true)
    equal(resumed, false, "already held fire cannot resume stale input")
    equal(fresh, false)
    resumed = api.resume_on_press(input, false)
    equal(resumed, false, "releasing fire does not resume weapon actions")
    resumed, fresh = api.resume_on_press(input, true)
    equal(resumed, true, "fresh fire press resumes in the same tick")
    equal(fresh, true, "new press remains available for empty-weapon reload checks")
    equal(input.runtime_rearm, nil, "press consumes only the recovery gate")
    resumed, fresh = api.resume_on_press(input, true)
    equal(resumed, true, "held charge remains enabled after the resume press")
    equal(fresh, false, "continued hold is not another synthetic press")
    input = {runtime_rearm = true, recovery_fire = false}
    equal(api.resume_on_press(input, true), true, "an initially released button resumes on first press")
    for _, threshold in ipairs({0.9, 0.95}) do
        input = {runtime_rearm = true, recovery_fire = true}
        local charge = api.Charge.new()
        local shot = {active = true, native = true, weapon = "railgun:recovery", mode = "ammo",
            ammo = 1, reloading = false, charge_kind = "railgun", charging = true,
            charge_elapsed = 3 * threshold - 0.01, charge_limit = 3, charge_max = 3}
        equal(api.resume_on_press(input, false), false, "release only prepares the next real press")
        equal(api.resume_on_press(input, true), true, "fresh press enables Railgun charge checks")
        equal(charge:step(shot, 1, true, threshold), false, "resumed charge needs coherent readings")
        shot.charge_elapsed = 3 * threshold
        equal(charge:step(shot, 1.05, true, threshold), true, "continued hold auto-fires at selected threshold")
    end
    local state, time, calls, cleanups, resets = {}, 10, 0, 0, 0
    local fail, ready, bad_clock, bad_reset = true, true, false, false
    local notes = {}
    local guarded = api.make_runtime_guard(state, function()
        calls = calls + 1
        if fail then error("transient weapon read") end
    end, function() cleanups = cleanups + 1 end, function()
        resets = resets + 1
        if bad_reset then error("reset unavailable") end
        return ready
    end, function()
        if bad_clock then error("clock unavailable") end
        return time
    end, function(message) notes[#notes + 1] = message end)
    guarded()
    equal(state.failed, true, "runtime exception suspends weapon inputs")
    equal(cleanups, 1, "failure releases owned inputs")
    equal(state.retry_at, 11, "first retry waits one second")
    guarded()
    equal(calls, 1, "cooldown does not retry each frame")
    time, fail = 11, false
    guarded()
    equal(resets, 1, "retry invalidates stale identity and input history")
    equal(calls, 2, "weapon callback runs again after transient error")
    equal(state.failed, nil, "success is not permanently disabled")
    equal(notes[#notes]:find("RUNTIME_RECOVERY", 1, true) ~= nil, true, "recovery is logged")
    fail, time = true, 12
    guarded()
    local before = #notes
    time = 13
    guarded()
    equal(state.runtime_failures, 2, "repeated errors increase backoff")
    equal(state.retry_at, 15, "repeated failures remain bounded")
    equal(#notes, before, "identical error logs are deduplicated")
    ready, time = false, 15
    local old_calls = calls
    guarded()
    equal(calls, old_calls, "pending key release blocks resumed input")
    equal(state.failed, true, "failed cleanup remains suspended")
    bad_reset, ready, time = true, true, 17
    guarded()
    equal(calls, old_calls, "reset exceptions never execute weapon callback")
    bad_reset, fail, bad_clock = false, false, true
    guarded()
    equal(calls, old_calls, "unreadable clock does not bypass cooldown")
    bad_clock, time = false, 1
    guarded()
    equal(state.retry_at, 2, "clock reset cannot cause an indefinite old deadline")
    time = 2
    guarded()
    equal(state.failed, nil, "new session resumes after a valid reset")
    equal(state.runtime_failures, nil, "success clears retry escalation")
    for _ = 1, 7 do
        fail = true; guarded(); time = state.retry_at
    end
    equal(state.runtime_failures, 5, "retry backoff is capped at five seconds")
end
