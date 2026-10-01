return function(api, equal)
    local function word(n)
        local out = {}
        for i = 1, 4 do
            out[i] = string.char(n % 256)
            n = math.floor(n / 256)
        end
        return table.concat(out)
    end
    local function pointer(n) return word(n) .. word(0) end
    local zero = string.char(0)
    local segments = {}
    local function put(at, data)
        segments[#segments + 1] = { at = at, data = data }
    end
    local function map(at, key, value, rows)
        put(at, pointer(rows) .. word(1) .. word(0xffffffff) .. word(1))
        put(rows, word(key) .. word(value))
    end
    local fake = { base = 0x100000 }
    function fake:read(at, size)
        for i = #segments, 1, -1 do
            local part = segments[i]
            if at >= part.at and at + size <= part.at + #part.data then
                local start = at - part.at + 1
                return part.data:sub(start, start + size - 1)
            end
        end
    end
    local player, owner, avatars = 0x200000, 0x300000, 0x400000
    local wielder, equipment, heat, mag, rounds =
        0x500000, 0x600000, 0x700000, 0x800000, 0x850000
    local avatar_record, weapon_record = owner + 15937304, 0x900000
    put(fake.base + 53634152, pointer(player))
    put(fake.base + 54968216, pointer(owner))
    put(fake.base + 53636384, pointer(avatars))
    put(fake.base + 53634080, pointer(wielder))
    put(fake.base + 53636544, pointer(equipment))
    put(fake.base + 53636424, pointer(heat))
    put(player + 936, word(42))
    map(owner + 15871688, 42, 0, 0xa00000)
    put(avatar_record, zero:rep(8) .. word(500) .. word(0) .. word(100) .. word(0))
    map(avatars + 248, 500, 0, 0xa00020)
    put(avatars + 108, word(1))
    put(avatars + 5495040 + 2948, word(500))
    put(avatars + 5535792 + 23, zero)
    map(wielder + 48, 500, 0, 0xa00040)
    put(wielder + 72, pointer(0xa00100))
    put(0xa00100, pointer(avatar_record))
    put(wielder + 96, pointer(0xb00000))
    put(0xb00000, word(900))
    put(weapon_record, zero:rep(8) .. word(900) .. word(0) .. word(123) .. word(0))
    map(equipment + 32, 900, 0, 0xa00060)
    put(equipment + 56, pointer(0xa00120))
    put(0xa00120, pointer(weapon_record))
    map(heat + 40, 900, 0, 0xa00080)
    put(heat + 64, pointer(0xa00140))
    put(0xa00140, pointer(weapon_record))
    put(heat + 88, pointer(0xc00000))
    put(0xc00000, word(2) .. word(0) .. string.char(1) .. zero:rep(3))

    local reader = api.NativeReader.new(fake)
    local no_game = api.NativeReader.new()
    local absent, reason = no_game:ready()
    equal(absent, nil, "native reader cannot open outside the game")
    equal(reason, "game-module-unavailable", "missing game module does not start reads")
    local hot = reader:sample()
    equal(hot.mode, "heat", "unlisted held weapon uses heat component")
    equal(hot.feed, "heat", "native heat source is identified")
    equal(hot.overheated, true, "complete overheat is read from held weapon")
    equal(hot.reserve, 2, "held weapon spare heat sinks")
    equal(hot.avatar, 100, "native avatar matches game-object identity")
    equal(hot.weapon, "native:500:900", "native weapon token follows held entity")
    put(0xc00000, word(2) .. word(0) .. string.char(0) .. zero:rep(3))
    equal(reader:sample().overheated, false, "cooling heat does not reload")

    local reload = 0x880000
    local weapon_type = word(0x33333333) .. word(0x44444444)
    put(weapon_record, weapon_type .. word(900) .. word(0) .. word(123) .. word(0))
    put(fake.base + 0x3326a70, pointer(reload))
    map(reload + 32, 900, 0, 0xa00300)
    put(reload + 56, pointer(0xa00320)); put(0xa00320, pointer(weapon_record))
    put(reload + 0xc, word(1)); put(reload + 4, word(1))
    map(reload + 0x60, 900, 0, 0xa00340)
    put(reload + 0xa0, pointer(0xe02000))
    put(0xe02000, string.char(0, 1))
    equal(reader:sample().reload_allow_move, true, "moving reload is read from the held entity override")
    equal(reader:sample().reload_source, "instance", "override reload config takes priority")
    put(0xe02000, string.char(1, 0))
    equal(reader:sample().reload_allow_move, false, "manual-clearing byte is not movement permission")
    put(0xe02000, string.char(0, 2))
    equal(reader:sample().reload_allow_move, nil, "invalid movement flag is not guessed")
    equal(reader:sample().overheated, false, "invalid reload metadata does not disable ammunition reading")

    map(reload + 0x60, 900, 0xffffffff, 0xa00340)
    put(owner + 0xf12800, pointer(0xe03000))
    put(0xe03000, zero:rep(498 * 16))
    local reload_seed = (0x44444444 % 498 * (4294967296 % 498) + 0x33333333 % 498) % 498
    put(0xe03000 + reload_seed * 16, weapon_type .. word(0) .. word(0))
    put(0xe03000 + 498 * 16, string.char(0, 0))
    equal(reader:sample().reload_allow_move, false, "unregistered weapon resolves its native authored reload config")
    equal(reader:sample().reload_source, "authored", "authored fallback does not need a weapon list")
    put(0xe03000 + 498 * 16, string.char(0, 1))
    equal(reader:sample().reload_allow_move, true, "live authored movement changes are reread")
    map(reload + 0x60, 901, 0, 0xa00340)
    equal(reader:sample().reload_allow_move, nil, "bounded instance probe failure cannot hide an override")
    map(reload + 0x60, 900, 0, 0xa00340)
    put(0xe02000, string.char(0, 0)); put(reload + 4, word(0))
    equal(reader:sample().reload_allow_move, nil, "instance config index must fit its allocation")
    put(reload + 4, word(1)); put(reload + 0xc, word(0))
    equal(reader:sample().reload_allow_move, nil, "component index must fit the live component count")
    put(reload + 0xc, word(1))
    put(0xa00320, pointer(weapon_record + 0x100))
    equal(reader:sample().reload_allow_move, nil, "stale reload component is never used")
    put(0xa00320, pointer(weapon_record))
    map(reload + 0x60, 900, 0xffffffff, 0xa00340)
    put(0xe03000 + reload_seed * 16, weapon_type .. word(498) .. word(0))
    equal(reader:sample().reload_allow_move, nil, "authored reload record index is bounded")
    put(fake.base + 0x3326a70, pointer(0))

    put(heat + 64, pointer(0xa00160))
    put(0xa00160, pointer(0x900100))
    equal(reader:sample(), nil, "stale component back-reference fails closed")
    put(fake.base + 53636424, pointer(0))
    put(fake.base + 53634632, pointer(mag))
    map(mag + 32, 900, 0, 0xa000a0)
    put(mag + 56, pointer(0xa00180))
    put(0xa00180, pointer(weapon_record))
    put(mag + 80, pointer(0xd00000))
    put(0xd00000, word(2) .. word(0) .. word(0))
    put(mag + 72, pointer(0xf00000))
    put(0xf00000 + 8, word(1))
    local chambered = reader:sample()
    equal(chambered.feed, "magazine", "native magazine source is identified")
    equal(chambered.ammo, 1, "chambered round prevents early reload without instance metadata")
    put(0xf00000 + 8, word(0))
    equal(reader:sample().ammo, 0, "empty magazine and chamber are empty")
    put(mag + 72, pointer(0))
    local missing_chamber, missing_reason = reader:sample()
    equal(missing_chamber, nil, "missing chamber count blocks reload")
    equal(missing_reason, "chamber-array-unavailable", "missing chamber array is diagnosed")
    put(fake.base + 53634632, pointer(0))
    put(fake.base + 53636336, pointer(rounds))
    map(rounds + 40, 900, 0, 0xa000e0)
    put(rounds + 64, pointer(0xa001a0))
    put(0xa001a0, pointer(weapon_record))
    put(rounds + 88, pointer(0xd00100))
    put(0xd00100, word(2) .. word(0) .. word(0) .. word(0) .. word(0))
    put(rounds + 80, pointer(0xf00100))
    put(0xf00100 + 16, word(0))
    local empty_rounds = reader:sample()
    equal(empty_rounds.feed, "rounds", "dual-feed weapon uses rounds component")
    equal(empty_rounds.ammo, 0, "rounds weapon with empty chamber is empty")
    put(0xf00100 + 16, word(1))
    equal(reader:sample().ammo, 1, "rounds weapon chamber prevents early reload")
    put(avatars + 5495040 + 2948, word(501))
    equal(reader:sample(), nil, "avatar identity mismatch fails closed")

    put(avatars + 5495040 + 2948, word(500))
    local ffi = require("ffi")
    local function float(n) return ffi.string(ffi.new("float[1]", n), 4) end
    local charge = 0x870000
    local rail = word(0x48b09e60) .. word(0x2e9d0bdc)
    local epoch = word(0xd7780e54) .. word(0xe8d5f49a)
    local function set_type(bytes)
        put(weapon_record, bytes .. word(900) .. word(0) .. word(123) .. word(0))
    end
    local function config(limit, explodes, full, minimum)
        return float(minimum or 0.1) .. zero:rep(20) .. float(full or 0.5) .. zero:rep(20) ..
            float(limit) .. zero:rep(133) .. string.char(explodes or 1) .. zero:rep(30)
    end
    local function charging(elapsed, flag)
        put(0xd00200, float(0.5) .. float(elapsed) .. zero:rep(4) ..
            string.char(flag or 1) .. zero:rep(27))
    end
    set_type(rail)
    put(fake.base + 53636128, pointer(charge))
    map(charge + 32, 900, 0, 0xa00200)
    put(charge + 56, pointer(0xa00220)); put(0xa00220, pointer(weapon_record))
    put(charge + 12, word(1)); put(charge + 64, pointer(0xd00200))
    map(charge + 80, 900, 0, 0xa00240)
    put(charge + 136, word(1)); put(charge + 144, pointer(0xe00000))
    put(0xe00000, config(3)); charging(2.7)
    equal(reader:sample().charge_elapsed, nil, "charge reader is opt in")
    reader.charge_enabled = true
    local charged = reader:sample()
    equal(charged.charge_kind, "railgun", "railgun native resource hash")
    equal(math.abs(charged.charge_elapsed - 2.7) < 0.00001, true, "runtime elapsed float decoded")
    equal(charged.charge_limit, 3, "explosion limit is not full-damage charge time")
    equal(charged.charge_basis, "danger"); equal(charged.charge_full, 0.5)
    equal(charged.charge_source, "instance"); equal(charged.charging, true)
    set_type(epoch)
    equal(reader:sample().charge_kind, "epoch", "epoch native resource hash")
    put(0xe00000, config(2.6, 0, 2.5, 1)); charging(2.49)
    local charge_policy = api.Charge.new()
    charged = reader:sample()
    equal(charged.charge_limit, 2.5, "Epoch uses full firing charge, not overcharge time")
    equal(charged.charge_basis, "full")
    equal(charged.charge_reason, "ready", "nonexplosive Epoch is a valid firing charge")
    equal(charge_policy:step(charged, 0, true), false)
    charging(2.5)
    equal(charge_policy:step(reader:sample(), 0.05, true), true, "native nonexplosive Epoch fires at full charge")
    charging(2.55)
    equal(reader:sample().charge_reason, "ready", "Epoch reading above full but below maximum remains valid")
    charging(2.7)
    equal(reader:sample().charge_elapsed, nil, "elapsed above configured maximum is rejected")
    put(0xe00000, config(3));
    charging(2.7, 0)
    equal(reader:sample().charging, false, "native charging flag is required")
    charging(0 / 0)
    equal(reader:sample().charge_elapsed, nil, "NaN charge float fails closed")
    equal(reader:sample().ammo, 1, "invalid charge does not break ammunition reader")
    charging(2.7); put(0xe00000, config(0))
    equal(reader:sample().charge_limit, nil, "maximum below full rejected")
    set_type(rail)
    put(0xe00000, config(3, 0))
    equal(reader:sample().charge_limit, nil, "nonexplosive charge is not a danger gauge")
    set_type(epoch)
    put(0xe00000, config(3, 0, 0))
    equal(reader:sample().charge_limit, nil, "Epoch zero full-charge time rejected")
    put(0xe00000, config(3, 0, 0 / 0))
    equal(reader:sample().charge_limit, nil, "Epoch NaN full-charge time rejected")
    put(0xe00000, config(3))
    put(0xa00220, pointer(0x900100))
    equal(reader:sample().charge_elapsed, nil, "stale charge component rejected")
    put(0xa00220, pointer(weapon_record))
    map(charge + 80, 900, 0xffffffff, 0xa00240)
    put(owner + 0xf12ad8, pointer(0xe01000))
    put(0xe01000, zero:rep(320))
    local seed = (0xe8d5f49a % 20 * 16 + 0xd7780e54 % 20) % 20
    put(0xe01000 + seed * 16, epoch .. word(0) .. word(0))
    put(0xe01000 + 320, config(4, 0, 3))
    charged = reader:sample()
    equal(charged.charge_limit, 3, "authored Epoch fallback supplies full charge rather than maximum")
    equal(charged.charge_max, 4)
    equal(charged.charge_source, "authored")
    put(0xe01000 + seed * 16, epoch .. word(99) .. word(0))
    equal(reader:sample().charge_elapsed, nil, "authored record index bounded")
    set_type(zero:rep(8))
    equal(reader:sample().charge_kind, nil, "unrelated weapons are never charged automatically")

    local native = { sample = function()
        return { active = true, native = true, avatar = 100, weapon = "native:500:900",
            mode = "heat", overheated = true, reserve = 2, reloading = false }
    end }
    local known = false
    local underbarrel = false
    local grip, control = 15, true
    local identity = { resolve = function()
        return { status = known and "resolved" or "unknown",
            avatar = { goid = 100 }, grip = grip,
            underbarrel = underbarrel and { goid = 900 } or nil,
            hand_weapon = known and { goid = 900, type = "known-weapon" } or nil }
    end, in_control = function() return control end,
        rotation_free = function() return true end }
    local parts = { GeneratedCommon = { identity = { equipment = {} } },
        IdentityCore = { new = function() return identity end },
        Provider = { new = function() return {} end } }
    local adapter = api.Reader.new(parts, { snapshot = {} }, native)
    local first = adapter:sample()
    equal(first.unconfirmed, true, "first empty native sample cannot reload")
    local second = adapter:sample()
    equal(second.unconfirmed, false, "matching second sample confirms empty")
    local policy = api.Policy.new()
    second.fire = true
    equal(policy:step(first, 0), nil, "unconfirmed state never sends input")
    equal(policy:step(second, 0.05), "fire-attempt", "confirmed empty weapon reloads")
    local exhaustion = api.Policy.new()
    local cooling = { active = true, mode = "heat", weapon = "native:500:900",
        overheated = false, reserve = 2, reloading = false }
    equal(exhaustion:step(cooling, 0), nil)
    first.fire, second.fire = false, false
    equal(exhaustion:step(first, 0.05), nil, "single overheat sample is ignored")
    equal(exhaustion:step(second, 0.1), "overheated",
        "confirmed overheat keeps the prior cooling state")
    known = true
    native.sample = function() return { active = true, native = true,
        avatar = 100, weapon = "native:500:900", mode = "ammo", ammo = 4,
        reserve = 2, reloading = false, feed = "magazine" } end
    local listed = adapter:sample()
    equal(listed.native, true, "registered weapons also use the held-object reader")
    equal(listed.ammo, 4, "registered weapon ammunition comes from the held object")
    grip, known = 70, false
    local unlisted_grip70 = adapter:sample()
    equal(unlisted_grip70.active, true, "unlisted grip 70 weapon is read while controlled")
    equal(unlisted_grip70.grip, 70, "native sample retains the observed grip")
    known = true
    equal(adapter:sample().active, true, "listed grip 70 weapon is read while controlled")
    control = false
    local blocked_grip70, blocked_control = adapter:sample()
    equal(blocked_grip70.active, false, "grip 70 without player control stays blocked")
    equal(blocked_control, "no-player-control", "grip 70 control gate is explicit")
    grip, control = 15, true
    underbarrel = true
    local blocked, blocked_reason = adapter:sample()
    equal(blocked.active, false, "underbarrel remains excluded after native switch")
    equal(blocked_reason, "underbarrel-not-supported", "underbarrel exclusion is explicit")
    underbarrel = false
    native.sample = function() return nil, "ammo-unavailable" end
    local unreadable, unreadable_reason = adapter:sample()
    equal(unreadable.active, false, "registered weapons do not fall back to old readings")
    equal(unreadable_reason, "ammo-unavailable", "native failure remains visible")
    native.sample = function() return { active = true, native = true,
        avatar = 101, weapon = "native:501:900", mode = "ammo", ammo = 0,
        reserve = 2, reloading = false } end
    equal(adapter:sample().active, false, "wrong avatar never authorizes reload")
    local pack_token, source = "1000:124:5", "backpack"
    native.sample = function() return {active = true, native = true,
        avatar = 100, weapon = "native:500:900", mode = "ammo", ammo = 0,
        reserve = 5, reloading = false, reserve_source = source, reserve_token = pack_token} end
    equal(adapter:sample().unconfirmed, true, "new backpack reserve needs two coherent reads")
    equal(adapter:sample().unconfirmed, false)
    pack_token = "1001:125:5"
    equal(adapter:sample().unconfirmed, true, "same ammo count in a different pack cannot reuse confirmation")
    equal(adapter:sample().unconfirmed, false)
    pack_token = "1001:126:5"
    equal(adapter:sample().unconfirmed, true, "reused pack entity with new GOID resets confirmation")
    equal(adapter:sample().unconfirmed, false)
    source, pack_token = "weapon", nil
    equal(adapter:sample().unconfirmed, true, "changing ammo source resets confirmation")
    equal(adapter:sample().unconfirmed, false)
end
