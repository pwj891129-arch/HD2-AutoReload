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
    local wielder, equipment, heat, mag = 0x500000, 0x600000, 0x700000, 0x800000
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
    equal(hot.overheated, true, "complete overheat is read from held weapon")
    equal(hot.reserve, 2, "held weapon spare heat sinks")
    equal(hot.avatar, 100, "native avatar matches game-object identity")
    equal(hot.weapon, "native:500:900", "native weapon token follows held entity")
    put(0xc00000, word(2) .. word(0) .. string.char(0) .. zero:rep(3))
    equal(reader:sample().overheated, false, "cooling heat does not reload")
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
    map(mag + 96, 900, 0, 0xa000c0)
    put(mag + 160, pointer(0xe00000))
    put(0xe00000 + 156, string.char(1))
    put(mag + 72, pointer(0xf00000))
    put(0xf00000 + 8, word(1))
    equal(reader:sample().ammo, 1, "chambered round prevents early reload")
    put(0xf00000 + 8, word(0))
    equal(reader:sample().ammo, 0, "empty magazine and chamber are empty")
    put(avatars + 5495040 + 2948, word(501))
    equal(reader:sample(), nil, "avatar identity mismatch fails closed")

    local native = { sample = function()
        return { active = true, native = true, avatar = 100, weapon = "native:500:900",
            mode = "heat", overheated = true, reserve = 2, reloading = false }
    end }
    local identity = { resolve = function()
        return { status = "unknown", avatar = { goid = 100 }, grip = 15 }
    end, in_control = function() return true end,
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
    native.sample = function() return { active = true, native = true,
        avatar = 101, weapon = "native:501:900", mode = "ammo", ammo = 0,
        reserve = 2, reloading = false } end
    equal(adapter:sample().active, false, "wrong avatar never authorizes reload")
end
