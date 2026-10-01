return function(api, equal)
    local zero = string.char(0)
    local function word(n)
        local out = {}; for i = 1, 4 do out[i], n = string.char(n % 256), math.floor(n / 256) end
        return table.concat(out)
    end
    local function pointer(n) return word(n) .. word(0) end
    local segments, fault, reads = {}, nil, 0
    local function put(at, raw) segments[#segments + 1] = {at, raw} end
    local function map(at, key, value, rows)
        put(at, pointer(rows) .. word(1) .. word(0xffffffff) .. word(1))
        put(rows, word(key) .. word(value))
    end
    local fake = {base = 0x100000}
    function fake:read(at, size)
        reads = reads + 1
        if fault and fault(at, size) then return nil end
        for i = #segments, 1, -1 do
            local part = segments[i]
            if at >= part[1] and at + size <= part[1] + #part[2] then
                return part[2]:sub(at - part[1] + 1, at - part[1] + size)
            end
        end
    end
    local reader = api.NativeReader.new(fake)
    local avatar, weapon, pack = 500, 900, 1000
    local avatar_record, weapon_record, pack_record = 0x200000, 0x200100, 0x200200
    local weapon_type, pack_type = word(0x33333333) .. word(0x44444444), word(0xaaaa1111) .. word(0xffff2222)
    local owner = zero:rep(8) .. word(avatar) .. word(0) .. word(100) .. word(0)
    local weapon_identity = weapon_type .. word(weapon) .. word(0) .. word(123) .. word(0)
    local pack_identity = pack_type .. word(pack) .. word(0) .. word(124) .. word(0)
    put(avatar_record, owner); put(weapon_record, weapon_identity); put(pack_record, pack_identity)
    local assisted, inventory, deposit, equipment, wielder, authored =
        0x300000, 0x310000, 0x320000, 0x330000, 0x340000, 0x350000
    for name, address in pairs({assisted = assisted, inventory = inventory, deposit = deposit,
        equipment = equipment, wielder = wielder, authored = authored}) do
        local rva = ({assisted = 0x3326be8, inventory = 0x3326738, deposit = 0x33265e8,
            equipment = 53636544, wielder = 53634080, authored = 0x346bf98})[name]
        put(fake.base + rva, pointer(address))
    end
    local function component(manager, spec, entity, record, at)
        map(manager + spec.map, entity, 0, at)
        put(manager + spec.back, pointer(at + 32)); put(at + 32, pointer(record))
    end
    component(assisted, {map = 24, back = 48}, weapon, weapon_record, 0x400000)
    component(inventory, {map = 40, back = 64}, avatar, avatar_record, 0x400100)
    component(deposit, {map = 32, back = 56}, pack, pack_record, 0x400200)
    component(equipment, {map = 32, back = 56}, pack, pack_record, 0x400300)
    component(wielder, {map = 48, back = 72}, avatar, avatar_record, 0x400400)
    put(inventory + 80, pointer(0x500000)); put(0x500000 + 12, word(pack))
    put(deposit + 80, pointer(0x500100)); put(0x500100, word(20))
    put(wielder + 96, pointer(0x500200)); put(0x500200, word(weapon))
    local function authored_config(offset, capacity, stride, type_bytes, rows)
        put(authored + offset, pointer(rows)); put(rows, zero:rep(capacity * 16))
        local function decode(at) local a,b,c,d = type_bytes:byte(at, at + 3); return a+b*256+c*65536+d*16777216 end
        local lo, hi = decode(1), decode(5)
        local seed = (hi % capacity * (4294967296 % capacity) + lo % capacity) % capacity
        put(rows + seed * 16, type_bytes .. word(0) .. word(0))
        return rows + capacity * 16, rows + seed * 16
    end
    local required_at, assisted_bucket = authored_config(0xf12658, 12, 104, weapon_type, 0x600000)
    put(required_at + 20, word(5))
    local deposit_config = authored_config(0xf12a00, 58, 152, pack_type, 0x610000)
    put(deposit_config + 136, weapon_type)
    local equipment_config = authored_config(0xf12bc0, 688, 232, pack_type, 0x620000)
    put(equipment_config + 128, word(17))
    map(deposit + 0x60, pack, 0xffffffff, 0x400500)
    map(equipment + 0x50, pack, 0xffffffff, 0x400600)
    local wield = reader:component("wielder", avatar, avatar_record)
    local function sample(reserve, mode)
        return reader:backpack_reserve({reserve = reserve or 0, mode = mode or "ammo"},
            weapon, weapon_record, wield, avatar, owner)
    end
    local s = sample()
    equal(s.reserve, 20, "actual equipped compatible backpack supplies spare ammo")
    equal(s.reserve_source, "backpack"); equal(s.reserve_token, "1000:124:5")
    equal(s.backpack_required, 5, "native per-reload ammo requirement is respected")
    equal(s.backpack_reason, "ready")
    reads = 0; s = sample(2)
    equal(s.reserve, 2, "own reserve takes native precedence")
    equal(s.reserve_source, "weapon"); equal(reads, 0, "no backpack reads with own spare ammo")
    put(0x500100, word(4)); s = sample()
    equal(s.reserve, 0, "pack has ammo but not enough for the game's reload requirement")
    equal(s.backpack_ammo, 4); equal(s.backpack_reason, "backpack-insufficient-ammo")
    put(0x500100, word(0)); equal(sample().reserve, 0, "empty backpack never authorizes reload")
    put(0x500100, word(5)); equal(sample().reserve, 5, "exact required ammo permits reload")
    put(deposit_config + 136, zero:rep(8)); equal(sample().reserve, 5, "native wildcard support pack is allowed")
    put(equipment_config + 128, word(18)); equal(sample().reserve, 0, "supply or unrelated pack class is rejected")
    put(equipment_config + 128, word(17)); put(deposit_config + 136, pack_type)
    equal(sample().reserve, 0, "another weapon's ammo backpack is rejected")
    put(deposit_config + 136, weapon_type)
    for _, invalid in ipairs({0, 0x7fff, 0x800000, 0xffffffff, pack + 1}) do
        put(0x500000 + 12, word(invalid)); equal(sample().reserve, 0, "absent, ground or teammate pack is never searched")
    end
    put(0x500000 + 12, word(pack))
    put(assisted_bucket, weapon_type .. word(12) .. word(0)); equal(sample().reserve, 0, "authored assisted index is bounded")
    put(assisted_bucket, weapon_type .. word(0) .. word(0)); put(required_at + 20, word(0))
    equal(sample().reserve, 0, "unknown or zero reload cost fails closed")
    put(required_at + 20, word(5))
    for _, address in ipairs({0x400020, 0x400120, 0x400220, 0x400320}) do
        local original = fake:read(address, 8)
        put(address, pointer(weapon_record + 8)); equal(sample().reserve, 0, "stale component ownership blocks pack reload")
        put(address, original)
    end
    map(deposit + 0x60, pack, 0, 0x400500)
    put(deposit + 4, word(1)); put(deposit + 0xa0, pointer(0x630000))
    put(0x630000 + 136, pack_type); equal(sample().reserve, 0, "instance compatibility overrides authored config")
    put(0x630000 + 136, weapon_type); equal(sample().reserve, 5, "compatible instance deposit config is accepted")
    put(deposit + 4, word(0)); equal(sample().reserve, 0, "override slot must fit allocation")
    put(deposit + 4, word(1))
    map(equipment + 0x50, pack, 0, 0x400600)
    put(equipment + 4, word(1)); put(equipment + 0x90, pointer(0x640000)); put(0x640000 + 128, word(18))
    equal(sample().reserve, 0, "equipment instance class overrides authored support class")
    put(0x640000 + 128, word(17)); equal(sample().reserve, 5, "equipment instance support class is accepted")
    put(deposit + 0x60, zero:rep(20)); put(equipment + 0x50, zero:rep(20))
    equal(sample().reserve, 5, "readable empty override maps use native authored configs")
    fault = function(at) return at == deposit + 0x60 end
    equal(sample().reserve, 0, "unreadable override map is not mistaken for an empty map")
    fault = nil
    map(deposit + 0x60, pack, 0, 0x400500); map(equipment + 0x50, pack, 0, 0x400600)
    for _, at in ipairs({required_at + 20, 0x500000 + 12, 0x500100, pack_record, 0x630000 + 136, 0x640000 + 128}) do
        fault = function(address) return address == at end
        equal(sample().reserve, 0, "unreadable backpack data cannot authorize reload")
    end
    fault = nil
    for _, change in ipairs({"drop", "goid", "held", "count"}) do
        local calls = 0
        fault = function(at)
            if at == 0x500100 then
                calls = calls + 1
                if calls == 1 then
                    if change == "drop" then put(0x500000 + 12, word(0))
                    elseif change == "goid" then put(pack_record, pack_type .. word(pack) .. word(0) .. word(125) .. word(0))
                    elseif change == "held" then put(0x500200, word(weapon + 1))
                    else put(0x500100, word(4)) end
                end
            end
        end
        s = sample(); equal(s.reserve, 0, "mid-read " .. change .. " cannot authorize reload")
        fault = nil; put(0x500000 + 12, word(pack)); put(pack_record, pack_identity)
        put(0x500200, word(weapon)); put(0x500100, word(5))
    end
    s = sample(0, "heat"); equal(s.reserve, 5, "compatible future heat-sink backpack needs no weapon list")
    s = reader:with_metadata({reserve = 0, mode = "ammo"}, weapon, weapon_record, wield, avatar, owner)
    equal(s.reserve, 5, "normal held-reader metadata pipeline includes backpack reserve")
    equal(s.reserve_source, "backpack")
    local p = api.Policy.new()
    s.active, s.native, s.weapon, s.mode, s.ammo, s.reload_allow_move = true, true, "pack-weapon", "ammo", 0, false
    s.reloading = false
    s.fire_held, s.fire_pressed, s.fire = true, true, true
    local trigger, action = p:step(s, 0)
    equal(trigger, "fire-attempt"); equal(action, "release-fire", "stationary empty click works with backpack reserve")
    p:released_fire(0); s.fire_held, s.fire_pressed, s.fire = false, false, false
    s.reserve = 0; equal(p:step(s, 0.1), nil, "pack removed after authorized click cancels reload")
end
