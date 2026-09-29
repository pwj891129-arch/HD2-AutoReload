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
}
local COMPONENTS = {
    equipment = { map = 32, back = 56 },
    wielder = { map = 48, back = 72, rows = 96, stride = 464 },
    magazine = { map = 32, back = 56, rows = 80, stride = 12 },
    rounds = { map = 40, back = 64, rows = 88, stride = 20 },
    heat = { map = 40, back = 64, rows = 88, stride = 12 },
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
        { map = 96, rows = 160, stride = 160, flag = 156,
            chamber_rows = 72, chamber_stride = 16, chamber_offset = 8 } or
        { map = 104, rows = 168, stride = 136, flag = 104,
            chamber_rows = 80, chamber_stride = 24, chamber_offset = 16 }
    local seat = self:lookup(component.manager + spec.map, component.entity)
    local rows = self:ptr(component.manager + spec.rows)
    if not seat or seat == 0xffffffff or seat > 1000000 or not rows then return nil end
    local flag = self:read(rows + seat * spec.stride + spec.flag, 1)
    if not flag or (flag:byte(1) ~= 0 and flag:byte(1) ~= 1) then return nil end
    if flag:byte(1) == 0 then return false end
    local chambers = self:ptr(component.manager + spec.chamber_rows)
    local loaded = chambers and self:word(chambers + component.index *
        spec.chamber_stride + spec.chamber_offset)
    if not count(loaded) then return nil end
    return loaded > 0
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
        return { active = true, mode = "heat", weapon = "native:" .. avatar .. ":" .. held,
            avatar = avatar_goid, goid = goid, reserve = reserve,
            overheated = flag == 1, reloading = reloading,
            native = true }, "ready"
    end
    local magazine, mag_fault = self:component("magazine", held, record)
    local rounds, rounds_fault = self:component("rounds", held, record)
    if mag_fault or rounds_fault then return nil, "stale-ammo-component" end
    if magazine and rounds then return nil, "ambiguous-feed" end
    if magazine then magazine.entity = held end
    if rounds then rounds.entity = held end
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
        local chamber = self:chambered(magazine or rounds,
            magazine and "magazine" or "rounds")
        if chamber == nil then return nil, "chamber-unavailable" end
        if chamber then ammo = 1 end
    end
    return { active = true, mode = "ammo", weapon = "native:" .. avatar .. ":" .. held,
        avatar = avatar_goid, goid = goid, reserve = reserve,
        ammo = ammo, reloading = reloading, native = true }, "ready"
end

return Reader
