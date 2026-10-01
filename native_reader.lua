local Reader = {}
Reader.__index = Reader

-- These offsets are valid only for the two pinned game binaries below.
local PIN = {
    exe = "f5fee03dcfdb2e553a4752c283590950ac13316b376d8196aa556ff0400d5f06",
    game = "2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e",
}
local RVA = {
    players = 53634152, owner = 54968216, avatars = 53636384,
    equipment = 53636544, wielder = 53634080,
    magazine = 53634632, rounds = 53636336, heat = 53636424,
    charge = 53636128, authored = 0x346bf98,
}
local COMPONENTS = {
    equipment = { map = 32, back = 56 },
    wielder = { map = 48, back = 72, rows = 96, stride = 464 },
    magazine = { map = 32, back = 56, rows = 80, stride = 12 },
    rounds = { map = 40, back = 64, rows = 88, stride = 20 },
    heat = { map = 40, back = 64, rows = 88, stride = 12 },
    charge = { map = 32, back = 56, rows = 64, stride = 40 },
}
local CHARGE_WEAPONS = {
    ["2e9d0bdc48b09e60"] = "railgun",
    ["e8d5f49ad7780e54"] = "epoch",
}

local function u32(raw, at)
    if not raw or #raw < at + 4 then return nil end
    local a, b, c, d = raw:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end

local function address(raw, at)
    local low, high = u32(raw, at), u32(raw, at + 4)
    if not low or not high then return nil end
    local value = high * 4294967296 + low
    if value < 65536 or value >= 140737488355328 then return nil end
    return value
end

local function float(raw, at)
    local bits = u32(raw, at)
    if not bits then return nil end
    local exponent = math.floor(bits / 8388608) % 256
    if exponent == 255 then return nil end
    local mantissa = bits % 8388608
    local value = exponent == 0 and mantissa * 2 ^ -149 or
        (1 + mantissa / 8388608) * 2 ^ (exponent - 127)
    return bits >= 2147483648 and -value or value
end

local function hash64(raw)
    local low, high = u32(raw, 0), u32(raw, 4)
    return low and high and string.format("%08x%08x", high, low) or nil
end

local function count(value)
    return type(value) == "number" and value >= 0 and value <= 100000 and
        value == math.floor(value)
end

local function open_channel()
    local ok, ffi = pcall(require, "ffi")
    if not ok or not ffi.abi("64bit") then return nil, "ffi-unavailable" end
    pcall(ffi.cdef, [[
        void *GetModuleHandleA(const char *);
        uint32_t GetModuleFileNameW(void *, uint16_t *, uint32_t);
        void *GetCurrentProcess(void);
        int ReadProcessMemory(void *, const void *, void *, size_t, size_t *);
        void *CreateFileW(const uint16_t *, uint32_t, uint32_t, void *, uint32_t, uint32_t, void *);
        int ReadFile(void *, void *, uint32_t, uint32_t *, void *);
        int CloseHandle(void *);
        int32_t BCryptOpenAlgorithmProvider(void **, const uint16_t *, const uint16_t *, uint32_t);
        int32_t BCryptCloseAlgorithmProvider(void *, uint32_t);
        int32_t BCryptCreateHash(void *, void **, void *, uint32_t, const void *, uint32_t, uint32_t);
        int32_t BCryptHashData(void *, const void *, uint32_t, uint32_t);
        int32_t BCryptFinishHash(void *, void *, uint32_t, uint32_t);
        int32_t BCryptDestroyHash(void *);
    ]])
    local kernel = ffi.load("kernel32")
    local bcrypt = ffi.load("bcrypt")
    local exe = kernel.GetModuleHandleA(nil)
    local game = kernel.GetModuleHandleA("game.dll")
    if exe == nil or game == nil then return nil, "game-module-unavailable" end

    local function sha256(module)
        local path = ffi.new("uint16_t[32768]")
        local length = kernel.GetModuleFileNameW(module, path, 32768)
        if length == 0 or length >= 32768 then return nil end
        local file = kernel.CreateFileW(path, 0x80000000, 7, nil, 3, 0, nil)
        if file == ffi.cast("void *", -1) then return nil end
        local algorithm, hash = ffi.new("void *[1]"), ffi.new("void *[1]")
        local name = ffi.new("uint16_t[7]", { 83, 72, 65, 50, 53, 54, 0 })
        local buffer, read = ffi.new("uint8_t[65536]"), ffi.new("uint32_t[1]")
        local digest, good = ffi.new("uint8_t[32]"), false
        if bcrypt.BCryptOpenAlgorithmProvider(algorithm, name, nil, 0) == 0 and
            bcrypt.BCryptCreateHash(algorithm[0], hash, nil, 0, nil, 0, 0) == 0 then
            good = true
            while true do
                if kernel.ReadFile(file, buffer, 65536, read, nil) == 0 then
                    good = false; break
                end
                if read[0] == 0 then break end
                if bcrypt.BCryptHashData(hash[0], buffer, read[0], 0) ~= 0 then
                    good = false; break
                end
            end
            if good then good = bcrypt.BCryptFinishHash(hash[0], digest, 32, 0) == 0 end
        end
        if hash[0] ~= nil then bcrypt.BCryptDestroyHash(hash[0]) end
        if algorithm[0] ~= nil then bcrypt.BCryptCloseAlgorithmProvider(algorithm[0], 0) end
        kernel.CloseHandle(file)
        if not good then return nil end
        local hex = {}
        for i = 0, 31 do hex[#hex + 1] = string.format("%02x", digest[i]) end
        return table.concat(hex)
    end

    if sha256(exe) ~= PIN.exe or sha256(game) ~= PIN.game then
        return nil, "binary-version-mismatch"
    end
    local process = kernel.GetCurrentProcess()
    local actual = ffi.new("size_t[1]")
    return {
        base = tonumber(ffi.cast("uintptr_t", game)),
        read = function(_, at, size)
            if type(at) ~= "number" or at < 65536 or
                at >= 140737488355328 or size < 1 or size > 256 then return nil end
            local buffer = ffi.new("uint8_t[?]", size)
            if kernel.ReadProcessMemory(process, ffi.cast("void *", at),
                buffer, size, actual) == 0 or tonumber(actual[0]) ~= size then return nil end
            return ffi.string(buffer, size)
        end,
    }
end

function Reader.new(channel)
    return setmetatable({ channel = channel, disabled = false }, Reader)
end

function Reader:ready()
    if self.disabled then return nil, self.refusal end
    if self.channel then return self.channel end
    local ok, channel, why = pcall(open_channel)
    if not ok then channel, why = nil, tostring(channel) end
    if not channel then
        self.refusal = why
        if why ~= "game-module-unavailable" then self.disabled = true end
        return nil, why
    end
    self.channel = channel
    return channel
end

function Reader:read(at, size)
    return self.channel:read(at, size)
end

function Reader:ptr(at)
    return address(self:read(at, 8), 0)
end

function Reader:word(at)
    return u32(self:read(at, 4), 0)
end

function Reader:root(name)
    return self:ptr(self.channel.base + RVA[name])
end

function Reader:lookup(at, key)
    local header = self:read(at, 20)
    local rows = address(header, 0)
    local capacity, empty, mult = u32(header, 8), u32(header, 12), u32(header, 16)
    if not rows or not capacity or capacity < 1 or capacity > 1048576 or
        not empty or not mult then return nil end
    local power = capacity
    while power > 1 and power % 2 == 0 do power = power / 2 end
    if power ~= 1 then return nil end
    local a, b, c, d = key % 65536, math.floor(key / 65536),
        mult % 65536, math.floor(mult / 65536)
    local seed = (a * c + ((a * d + b * c) % 65536) * 65536) % 4294967296
    for probe = 0, math.min(capacity, 128) - 1 do
        local row = self:read(rows + ((seed + probe) % capacity) * 8, 8)
        local found = u32(row, 0)
        if found == nil or found == empty then return nil end
        if found == key then return u32(row, 4) end
    end
end

function Reader:component(name, entity, record)
    local spec = COMPONENTS[name]
    local manager = self:root(name)
    if not manager then return nil end
    local index = self:lookup(manager + spec.map, entity)
    if not index or index == 0xffffffff or index > 1000000 then return nil end
    local back = self:ptr(manager + spec.back)
    local member = back and self:ptr(back + index * 8)
    if not member or (record and member ~= record) then return nil, "stale-component" end
    return { manager = manager, index = index, record = member, spec = spec }
end

function Reader:field(component, offset, size)
    local spec = component.spec
    local rows = spec.rows and self:ptr(component.manager + spec.rows)
    if not rows then return nil end
    return self:read(rows + component.index * spec.stride + offset, size)
end

function Reader:held_record(held)
    for _, name in ipairs({ "equipment", "heat", "magazine", "rounds" }) do
        local component = self:component(name, held)
        local at = component and component.record
        local row = at and self:read(at, 24)
        local goid = u32(row, 16)
        if row and u32(row, 8) == held and goid and goid ~= 0 and
            goid ~= 0x7fff then return at, goid end
    end
end

function Reader:chambered(component, kind)
    local spec = kind == "magazine" and
        { rows = 72, stride = 16, offset = 8 } or
        { rows = 80, stride = 24, offset = 16 }
    -- The optional instance map is absent on some weapons; the component's
    -- chamber count is still indexed by the verified held-weapon component.
    local chambers = self:ptr(component.manager + spec.rows)
    if not chambers then return nil, "chamber-array-unavailable" end
    local loaded = self:word(chambers + component.index *
        spec.stride + spec.offset)
    if not count(loaded) then return nil, "chamber-count-unavailable" end
    return loaded > 0
end

function Reader:charge_config(component, held, type_bytes)
    local manager = component.manager
    local index = self:lookup(manager + 80, held)
    if index and index ~= 0xffffffff then
        local length, rows = self:word(manager + 136), self:ptr(manager + 144)
        if not length or not rows or index >= length or length > 1000000 then return nil end
        return self:read(rows + index * 216, 216), "instance"
    end
    -- The game uses its authored type registry when no instance override exists.
    local registry = self:root("authored")
    local rows = registry and self:ptr(registry + 0xf12ad8)
    local low, high = u32(type_bytes, 0), u32(type_bytes, 4)
    if not rows or not low or not high then return nil end
    local seed = (high % 20 * 16 + low % 20) % 20
    for probe = 0, 19 do
        local row = self:read(rows + ((seed + probe) % 20) * 16, 16)
        if not row or row:sub(1, 8) == string.rep("\0", 8) then return nil end
        if row:sub(1, 8) == type_bytes then
            local slot = u32(row, 8)
            if not slot or slot >= 20 then return nil end
            return self:read(rows + 320 + slot * 216, 216), "authored"
        end
    end
end

function Reader:with_charge(sample, held, record, wield)
    if not self.charge_enabled then return sample end
    local identity = self:read(record, 24)
    local kind = CHARGE_WEAPONS[hash64(identity)]
    if not kind then return sample end
    sample.charge_kind = kind
    local component = self:component("charge", held, record)
    local length = component and self:word(component.manager + 12)
    local raw = component and length and component.index < length and length <= 1000000 and
        self:field(component, 0, 40)
    local config, source
    if raw then config, source = self:charge_config(component, held, identity:sub(1, 8)) end
    local elapsed, over = float(raw, 4), float(config, 48)
    local minimum, full = float(config, 0), float(config, 24)
    local charging = raw and raw:byte(13)
    local explodes = config and config:byte(186)
    if not elapsed or not over or not minimum or not full or minimum < 0 or
        full < minimum or full < 0.1 or full > 30 or over < full or over > 30 or
        elapsed < 0 or elapsed > over or (explodes ~= 0 and explodes ~= 1) or
        (kind == "railgun" and (explodes ~= 1 or full >= over)) or
        (charging ~= 0 and charging ~= 1) then
        sample.charge_reason = "charge-data-unavailable"; return sample
    end
    if self:read(record, 24) ~= identity or u32(identity, 8) ~= held or
        u32(self:field(wield, 0, 4), 0) ~= held or
        self:component("charge", held, record) == nil then
        sample.charge_reason = "charge-identity-changed"; return sample
    end
    -- Epoch completes a firing charge; Railgun releases before unsafe explosion.
    sample.charge_elapsed = elapsed
    sample.charge_limit = kind == "epoch" and full or over
    sample.charge_max, sample.charge_full = over, full
    sample.charge_basis = kind == "epoch" and "full" or "danger"
    sample.charging, sample.charge_source = charging == 1, source
    sample.charge_reason = "ready"
    return sample
end

function Reader:sample()
    local channel, why = self:ready()
    if not channel then return nil, why end
    local players, owner, avatars = self:root("players"),
        self:root("owner"), self:root("avatars")
    if not players or not owner or not avatars then return nil, "world-unavailable" end
    local unit = self:word(players + 936)
    if not unit or unit == 0x7fff then return nil, "no-local-unit" end
    local index = self:lookup(owner + 15871688, unit)
    if not index or index == 0xffffffff or index > 1000000 then
        return nil, "no-avatar-index"
    end
    local avatar_record = self:read(owner + 15937304 + index * 24, 24)
    local avatar = u32(avatar_record, 8)
    local avatar_goid = u32(avatar_record, 16)
    if not avatar or avatar == 0 or not avatar_goid then return nil, "no-avatar" end
    local seat = self:lookup(avatars + 248, avatar)
    local seats = self:word(avatars + 108)
    if not seat or not seats or seat >= seats or seat > 1000000 or
        self:word(avatars + 5495040 + seat * 4664 + 2948) ~= avatar then
        return nil, "avatar-identity-mismatch"
    end
    local wield = self:component("wielder", avatar)
    local held = wield and u32(self:field(wield, 0, 4), 0)
    if not held or held == 0 or held == 0x7fff or held == 0xffffffff then
        return nil, "no-held-weapon"
    end
    local record, goid = self:held_record(held)
    if not record or not goid then return nil, "held-record-unavailable" end
    local reload_byte = self:read(avatars + 5535792 + seat * 120 + 23, 1)
    if not reload_byte then return nil, "reload-state-unavailable" end
    local reloading = math.floor(reload_byte:byte(1) / 2) % 2 == 1
    local heat, heat_fault = self:component("heat", held, record)
    if heat_fault then return nil, heat_fault end
    if heat then
        local raw = self:field(heat, 0, 12)
        local reserve, flag = u32(raw, 0), raw and raw:byte(9)
        if not count(reserve) or (flag ~= 0 and flag ~= 1) then
            return nil, "heat-state-unavailable"
        end
        return self:with_charge({ active = true, mode = "heat", weapon = "native:" .. avatar .. ":" .. held,
            avatar = avatar_goid, goid = goid, reserve = reserve,
            overheated = flag == 1, reloading = reloading,
            native = true, feed = "heat" }, held, record, wield), "ready"
    end
    local magazine, mag_fault = self:component("magazine", held, record)
    local rounds, rounds_fault = self:component("rounds", held, record)
    if mag_fault or rounds_fault then return nil, "stale-ammo-component" end
    if magazine and rounds then return nil, "ambiguous-feed" end
    local raw = magazine and self:field(magazine, 0, 8) or
        rounds and self:field(rounds, 0, 16)
    local reserve, ammo = u32(raw, 0), u32(raw, 4)
    if rounds then
        local selected = u32(raw, 4)
        ammo = selected == 0 and u32(raw, 8) or
            selected == 1 and u32(raw, 12) or nil
        local other = selected == 0 and u32(raw, 12) or
            selected == 1 and u32(raw, 8) or nil
        if ammo == 0 and other and other > 0 then
            return nil, "alternate-feed-unknown"
        end
    end
    if not count(reserve) or not count(ammo) then return nil, "ammo-unavailable" end
    if ammo == 0 then
        local chamber, chamber_reason = self:chambered(magazine or rounds,
            magazine and "magazine" or "rounds")
        if chamber == nil then return nil, chamber_reason end
        if chamber then ammo = 1 end
    end
    return self:with_charge({ active = true, mode = "ammo", weapon = "native:" .. avatar .. ":" .. held,
        avatar = avatar_goid, goid = goid, reserve = reserve,
        ammo = ammo, reloading = reloading, native = true,
        feed = magazine and "magazine" or "rounds" }, held, record, wield), "ready"
end

return Reader
