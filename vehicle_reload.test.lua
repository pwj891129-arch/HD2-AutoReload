return function(api, equal)
    local memory = {}
    local function put(at, bytes)
        for i = 1, #bytes do memory[at + i - 1] = bytes:byte(i) end
    end
    local function word(value)
        local bytes = {}
        for i = 1, 4 do bytes[i] = string.char(value % 256); value = math.floor(value / 256) end
        return table.concat(bytes)
    end
    local function ptr(value) return word(value) .. word(0) end
    local channel = {base = 0x100000}
    function channel:read(at, size)
        local out = {}
        for i = 1, size do
            if memory[at + i - 1] == nil then return nil end
            out[i] = string.char(memory[at + i - 1])
        end
        return table.concat(out)
    end
    local zero = string.char(0)
    local next_at = 0x1100000
    local function allocate(size)
        local at = next_at; next_at = next_at + size + 256
        put(at, zero:rep(size)); return at
    end
    local function map(at, entity, index)
        local rows = allocate(8)
        put(at, ptr(rows) .. word(1) .. word(0xffffffff) .. word(1))
        put(rows, word(entity) .. word(index))
    end
    local avatar, held = 500, 900
    local players, owner, avatars = 0x200000, 0x300000, 0x400000
    local avatar_record = owner + 15937304
    local weapon_record, animation_record = allocate(24), allocate(24)
    local identity = word(10) .. word(20) .. word(avatar) .. word(0) .. word(100) .. word(0)
    put(avatar_record, identity)
    put(weapon_record, word(30) .. word(40) .. word(held) .. word(0) .. word(123) .. word(0))
    put(animation_record, word(50) .. word(60) .. word(700) .. word(0) .. word(124) .. word(0))
    put(channel.base + 53634152, ptr(players)); put(channel.base + 54968216, ptr(owner))
    put(channel.base + 53636384, ptr(avatars)); put(players + 936, word(42))
    map(owner + 15871688, 42, 0); map(avatars + 248, avatar, 0)
    put(avatars + 108, word(1)); put(avatars + 5495040 + 2948, word(avatar))
    put(avatars + 5535792 + 23, zero)
    local gunner_control, pilot_control = avatars + 0x53e88c, avatars + 0x53e88c
    put(gunner_control, word(262144)); put(pilot_control, word(262144))
    local function component(rva, key, record, spec)
        local manager = allocate(256)
        put(channel.base + rva, ptr(manager)); map(manager + spec.map, key, 0)
        local back = allocate(8); put(manager + spec.back, ptr(back)); put(back, ptr(record))
        put(manager + 12, word(1)); put(manager + 16, word(1))
        local rows
        if spec.rows then rows = allocate(spec.stride); put(manager + spec.rows, ptr(rows)) end
        return manager, rows, back
    end
    local _, wield_rows, wield_back = component(53634080, avatar, avatar_record,
        {map = 48, back = 72, rows = 96, stride = 464})
    put(wield_rows, word(held))
    component(53636544, held, weapon_record, {map = 32, back = 56})
    local mag, ammo_rows = component(53634632, held, weapon_record,
        {map = 32, back = 56, rows = 80, stride = 12})
    put(ammo_rows, word(2) .. word(0))
    local chambers = allocate(16); put(mag + 72, ptr(chambers))
    local seater, seat_rows, seat_back = component(0x3326d78, avatar, avatar_record,
        {map = 32, back = 56, rows = 72, stride = 64})
    local function seat(kind, role, index)
        put(seat_rows, zero:rep(64))
        put(seat_rows, word(600) .. word(kind or 0x2b) .. word(role or 2))
        put(seat_rows + 28, word(index or 5))
    end
    seat()
    local reload = component(0x3326a70, held, weapon_record, {map = 32, back = 56})
    put(reload + 4, word(1)); map(reload + 0x60, held, 0)
    local config = allocate(80); put(reload + 0xa0, ptr(config))
    put(config, string.char(0, 0) .. zero:rep(2) .. word(77))
    local _, owner_rows = component(0x3326730, held, weapon_record,
        {map = 24, back = 48, rows = 56, stride = 4})
    put(owner_rows, word(700))
    local animation, animation_rows = component(0x3326640, 700, animation_record,
        {map = 24, back = 48, rows = 56, stride = 224})
    put(animation_rows, word(77))
    local reader = api.NativeReader.new(channel)
    local shot = assert(reader:sample())
    equal(shot.vehicle, true, "tank primary is classified independently of personal grip")
    equal(shot.weapon, "vehicle:600:43:2:5:500:900:123", "seat, vehicle and weapon generation are bound")
    equal(shot.ammo, 0); equal(shot.reserve, 2); equal(shot.reloading, false)
    equal(shot.reload_allow_move, nil, "personal stationary rule is not substituted for mounted reload")
    equal(shot.charge_kind, nil, "mounted weapons never trigger personal charge release")
    put(gunner_control, word(0))
    local blocked, blocked_reason = reader:sample()
    equal(blocked, nil); equal(blocked_reason, "vehicle-input-blocked", "native vehicle weapon control is required")
    put(gunner_control, word(262144))
    put(avatars + 0x53e884, word(0))
    equal(reader:sample().vehicle, true, "firing-only permission is not required by native mounted reload")
    put(animation_rows + 16, string.char(1))
    equal(reader:sample().reloading, true, "mounted reload uses native animation, not avatar flag")
    put(animation_rows, word(78))
    equal(reader:sample().reloading, false, "different animation is not reload")
    put(animation_rows + 16, string.char(2))
    local absent, reason = reader:sample()
    equal(absent, nil); equal(reason, "vehicle-reload-animation-unavailable")
    put(animation_rows + 16, zero)
    put(owner_rows, word(0xffffffff))
    equal(reader:sample(), nil, "missing animation owner blocks vehicle reload")
    put(owner_rows, word(700))
    put(config + 4, word(0))
    equal(reader:sample().reloading, false, "zero native reload-state ID means no reload animation")
    put(config + 4, word(77))
    put(chambers + 8, word(1))
    equal(reader:sample().ammo, 1, "mounted chambered shell prevents premature reload")
    put(chambers + 8, word(0)); put(ammo_rows, word(0))
    equal(reader:sample().reserve, 0, "no mounted reserve is not replaced by backpack ammo")
    put(ammo_rows, word(2)); put(reload + 12, word(0))
    equal(reader:sample(), nil, "non-reloadable mounts are excluded")
    put(reload + 12, word(1))
    for _, kind in ipairs({0x1a, 0x2b, 0x2c}) do
        for _, role in ipairs({2, 4}) do
            seat(kind, role, 5)
            equal(reader:sample().vehicle, true, "FRV/tank gunner and pilot primary")
            local control = role == 2 and gunner_control or pilot_control
            put(control, word(0)); equal(reader:sample(), nil, "each seated role requires its native control flag")
            put(control, word(262144))
        end
    end
    seat(0x2b, 3)
    equal(reader:sample().vehicle, nil, "passenger personal weapon stays on personal path")
    seat(0x2b, 1)
    equal(reader:sample(), nil, "non-firing driver excluded")
    seat(0x99, 2)
    equal(reader:sample(), nil, "unknown vehicle types are not guessed")
    seat(0x2b, 2, 0xffffffff)
    equal(reader:sample(), nil, "unsettled current seat is not confused with requested role")
    seat(); put(seat_rows + 48, string.char(1))
    equal(reader:sample(), nil, "seat transition blocks reload")
    seat(); put(seat_back, ptr(weapon_record))
    equal(reader:sample(), nil, "wrong seat owner blocks reload")
    put(seat_back, ptr(avatar_record)); put(wield_back, ptr(weapon_record))
    equal(reader:sample(), nil, "wielder must belong to local avatar")
    put(wield_back, ptr(avatar_record))
    local original = channel.read
    function channel:read(at, size)
        local raw = original(self, at, size)
        if at == ammo_rows and size == 8 then put(seat_rows + 28, word(6)) end
        return raw
    end
    equal(reader:sample(), nil, "seat changing during read invalidates whole sample")
    channel.read = original; seat()
    function channel:read(at, size)
        local raw = original(self, at, size)
        if at == ammo_rows and size == 8 then put(players + 936, word(43)) end
        return raw
    end
    local changed, changed_reason = reader:sample()
    equal(changed, nil); equal(changed_reason, "vehicle-identity-changed", "local actor changing during read blocks mounted input")
    channel.read = original; put(players + 936, word(42))

    local config_options = {enabled = false, vehicle = true}
    equal(api.Options.allow(config_options, shot), true, "vehicle-only automatic reload")
    equal(api.Options.allow(config_options, {mode = "ammo"}), false, "vehicle toggle cannot enable personal reload")
    equal(api.Options.allow({enabled = true, vehicle = false}, shot), false, "personal toggle cannot enable vehicle reload")
    equal(api.Options.allow({vehicle = true}, {vehicle = true, mode = "heat"}), false)
    for _, enabled in ipairs({false, true}) do
        for _, vehicle in ipairs({false, true}) do
            local flags = {enabled = enabled, vehicle = vehicle}
            local options = api.Options.read({can_get = function(_, resource)
                return flags[resource:match("autoreload_setting_(.+)$")] ~= nil
            end}, function(resource) return flags[resource:match("autoreload_setting_(.+)$")] end)
            equal(options.vehicle, vehicle, "Arsenal vehicle checkbox is independently read")
            equal(options.enabled, enabled)
            equal(api.Options.allow(options, shot), vehicle)
            equal(api.Options.allow(options, {mode = "ammo"}), enabled)
        end
    end
    equal(api.Options.read({}, function() return true end).vehicle, false, "missing API cannot enable vehicles")
    equal(api.Options.read({can_get = function() return false end}, function() return true end).vehicle,
        false, "missing vehicle marker is OFF")
    local function sample(ammo)
        return {active = true, vehicle = true, native = true, weapon = shot.weapon,
            mode = "ammo", ammo = ammo, reserve = 2, reloading = false}
    end
    local p = api.Policy.new()
    local empty = sample(0); empty.unconfirmed = true
    equal(p:step(empty, 0), nil, "vehicle empty needs confirmation")
    empty.unconfirmed = false
    equal(p:step(empty, 0.05), "vehicle-empty", "already empty upon seating can reload")
    p:sent(0.05)
    equal(p:step(empty, 0.5), nil, "vehicle empty does not generate repeated pulses")
    p:reset(); equal(p:step(empty, 1), nil, "focus/identity gaps do not repeat an empty episode")
    p:step(sample(1), 1.1)
    equal(p:step(empty, 1.2), "ammo-exhausted", "refilled mounted weapon rearms")
    p:sent(1.2)
    p = api.Policy.new(); p:step(sample(1), 0)
    empty.fire_held = true
    equal(p:step(empty, 0.1), nil, "held vehicle fire does not reload")
    empty.fire_held, empty.fire_released, empty.fire = false, true, true
    equal(p:step(empty, 0.2), "ammo-exhausted", "vehicle reload ignores personal movement setting")
    for _, field in ipairs({"reserve", "reloading", "active", "manual_reload"}) do
        p = api.Policy.new(); local blocked = sample(0)
        if field == "reserve" then blocked.reserve = 0
        elseif field == "active" then blocked.active = false
        else blocked[field] = true end
        equal(p:step(blocked, 0), nil, "vehicle guard: " .. field)
    end
    p = api.Policy.new(); empty = sample(0); empty.fire_held, empty.fire_pressed, empty.fire = true, true, true
    local trigger, action = p:step(empty, 0)
    equal(trigger, "fire-attempt"); equal(action, "release-fire", "empty vehicle click releases fire first")
    p:released_fire(0); empty.fire_held, empty.fire_pressed, empty.fire = false, false, false
    equal(p:step(empty, 0.05), nil, "vehicle fire release settles before R")
    equal(p:step(empty, 0.07), "fire-attempt", "vehicle empty click then reloads")

    local identity_core = {in_control = function() return false end,
        rotation_free = function() return false end}
    local wrapper = setmetatable({identity = identity_core,
        native = {sample = function() return reader:sample() end}}, api.Reader)
    local resolved = {avatar = {goid = 100}, grip = 0}
    equal(wrapper:sample_native(resolved, 1).unconfirmed, true, "vehicle accepts settled native seat despite personal grip")
    equal(wrapper:sample_native(resolved, 1).unconfirmed, false, "mounted empty confirmation is coherent")
    equal(wrapper:sample_native(nil, 1).vehicle, true, "native local seat does not depend on personal hand resolver")
    local mismatch, mismatch_reason = wrapper:sample_native({avatar = {goid = 101}, grip = 0}, 1)
    equal(mismatch, nil); equal(mismatch_reason, "avatar-mismatch", "vehicle cannot bypass disagreeing avatar identity")
    identity_core.resolve = function() return {status = "absent", reason = "grip=0-nothing-held"} end
    equal(wrapper:sample(1).vehicle, true, "full adapter accepts independently verified mounted weapon")
    put(gunner_control, word(0))
    local failed, failed_reason = wrapper:sample(1)
    equal(failed.active, false); equal(failed_reason, "vehicle-input-blocked", "vehicle refusal is not hidden by personal-grip text")
    put(gunner_control, word(262144))
    seat(0x2b, 3); resolved.grip = 15
    local no_control = wrapper:sample_native(resolved, 1, false)
    equal(no_control, nil, "passenger cannot bypass personal control gate")
    equal(wrapper:sample_native(resolved, 1, true).vehicle, nil, "lean-out remains personal")
end
