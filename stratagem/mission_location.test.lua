return function(equal)
    local Reader, ffi = dofile("reader.lua"), require("ffi")
    local memory, channel = {}, {base = 0x10000000, exe_base = 0x18000000}
    local function put(at, raw) for i = 1, #raw do memory[at + i - 1] = raw:sub(i, i) end end
    local function word(n)
        return string.char(n % 256, math.floor(n / 256) % 256,
            math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
    end
    local function ptr(n) return word(n % 4294967296) .. word(math.floor(n / 4294967296)) end
    local function number(n) return ffi.string(ffi.new("float[1]", n), 4) end
    function channel:read(at, size)
        local raw = {}
        for i = 0, size - 1 do if not memory[at + i] then return nil end; raw[#raw + 1] = memory[at + i] end
        return table.concat(raw)
    end
    local reader = Reader.new(channel)
    local function root(name, at) put(channel.base + Reader.RVA[name], ptr(at)) end
    local registry, objects, generations = 0x20000000, 0x21000000, 0x22000000
    put(channel.exe_base + 0x1a100f0, ptr(registry))
    put(registry + 0x88, ptr(objects) .. ptr(0) .. word(8) .. word(0) .. ptr(generations))
    local function unit(index, generation, x, y, z)
        local object, vtable, matrix = 0x23000000 + index * 512, 0x24000000 + index * 512, 0x25000000 + index * 512
        put(objects + index * 8, ptr(object)); put(generations + index, string.char(generation))
        put(object, ptr(vtable)); put(vtable + 0xe8, ptr(channel.exe_base + 0x2bd870))
        put(object + 0x88, ptr(matrix)); put(matrix + 48, number(x) .. number(y) .. number(z))
        return index + generation * 0x400000
    end
    local player = unit(1, 3, 0, 0, 0)
    local target = unit(2, 0, 10, 0, 100)
    equal(reader:unit_position(player)[1], 0, "engine translation can include zero coordinates")
    equal(reader:unit_position(1), nil, "stale engine generation rejected")
    equal(reader:unit_position(8), nil, "engine index bounded")
    put(generations + 1, "\4")
    equal(reader:unit_position(player), nil, "engine unit reuse rejected")
    put(generations + 1, "\3")
    put(0x24000000 + 512 + 0xe8, ptr(channel.exe_base + 1))
    equal(reader:unit_position(player), nil, "unrecognized native object layout rejected")
    put(0x24000000 + 512 + 0xe8, ptr(channel.exe_base + 0x2bd870))
    local players, authored = 0x26000000, 0x27000000
    root("players", players); root("authored", authored)
    put(players + 132, word(4) .. word(1)); put(players + 0x3a8, word(148))
    local function map(at, rows, key, index)
        put(at, ptr(rows) .. word(4) .. word(0xffffffff) .. word(1))
        put(rows, string.rep("\255", 32)); put(rows + key % 4 * 8, word(key) .. word(index))
    end
    map(authored + 0xf22ec8, 0x28000000, 148, 2)
    map(authored + 0xf1aeb0, 0x29000000, 224, 2)
    put(authored + 0xf32f20 + 2 * 24, word(224) .. word(player))
    equal(reader:local_position()[3], 0, "multiplayer local avatar bridges to engine unit")
    put(players + 136, word(2))
    equal(reader:local_position(), nil, "ambiguous local player fails closed")
    put(players + 136, word(1))
    local root_at, wrappers, live, states = 0x30000000, 0x31000000, 0x32000000, 0x33000000
    local wrapper, table_at = 0x34000000, 0x35000000
    local key = word(0x33333333) .. word(0x44444444)
    local hash = ((0x44444444 % 438) * (4294967296 % 438) + 0x33333333 % 438) % 438
    put(authored + 0xf12758, ptr(table_at))
    put(table_at + hash * 16, key .. word(7))
    local definition = table_at + 0x1b20 + 7 * 0xad0
    put(definition, string.rep("\0", 0xad0))
    root("objectives", root_at)
    put(root_at + 0x24, word(1)); put(root_at + 0x50, ptr(wrappers) .. ptr(0) .. ptr(live) .. ptr(states))
    put(wrappers, ptr(wrapper)); put(wrapper, key .. word(0) .. word(target))
    put(live, string.rep("\0", 0x1078)); put(states, string.rep("\0", 100))
    local record = 0x36000000
    put(record, string.rep("\0", 400)); put(record + 0x7c, word(1))
    put(channel.base + Reader.RVA.definitions + 42 * 8, ptr(record))
    put(definition, word(42)); put(definition + 0x130, word(1))
    put(definition + 0x140, number(10))
    local call = {record = record, command = {1, 2, 3}}
    equal(reader:objective_definition(key), definition, "unsigned 64-bit authored hash resolver")
    equal(reader:mission_location(call, 42), true, "native horizontal radius includes boundary regardless of height")
    unit(2, 0, 10.01, 0, 0)
    equal(reader:mission_location(call, 42), false, "outside location hidden even if loaded and ready")
    unit(2, 0, 9, 0, 100)
    equal(reader:mission_location(call, 42), true, "entering location becomes visible")
    put(states + 24, word(1))
    equal(reader:mission_location(call, 42), false, "completed objective stage no longer exposes old call")
    put(states + 24, word(0)); put(live + 0x1018, word(1))
    equal(reader:mission_location(call, 42), false, "inactive native objective blocks")
    put(live + 0x1018, word(2)); put(definition + 8, "\1")
    equal(reader:mission_location(call, 42), true, "passive native call supports objective state two")
    put(definition + 8, "\0")
    equal(reader:mission_location(call, 42), false, "nonpassive call never uses completed state two")
    put(live + 0x1018, word(0))
    put(definition + 0x134, "\1"); put(live + 8, word(1)); put(live + 16, word(player))
    unit(2, 0, 100, 100, 0)
    equal(reader:mission_location(call, 42), true, "child target radius used instead of parent position")
    put(live + 16, word(player + 0x400000))
    equal(reader:mission_location(call, 42), false, "destroyed or generation-mismatched child ignored")
    put(definition + 0x134, "\0"); put(definition + 0x136, "\1")
    put(live + 0x1058, word(player) .. word(1))
    equal(reader:mission_location(call, 42), true, "native call anchor override used")
    put(definition + 0x136, "\0"); unit(2, 0, 9, 0, 0)
    local party, peers, actors, avatars = 0x3d000000, 0x3e000000, 0x3f000000, 0x40000000
    local cache, coordinates, types = 0x41000000, 0x42000000, 0x43000000
    local actor = 0x44000000
    root("anchors", party); root("positions", cache)
    put(party + 16, word(1)); put(party + 0x38, ptr(actors) .. ptr(0) .. ptr(peers) .. ptr(avatars))
    put(peers, word(224) .. word(0) .. word(2) .. word(0)); put(avatars, word(148) .. ptr(0))
    put(actors, ptr(actor)); put(actor, key .. word(224))
    put(channel.base + 0x3483c4c, word(0xffffffff))
    map(cache + 0x40, 0x45000000, 224, 1); put(cache + 0x68, ptr(coordinates))
    put(coordinates + 0x308 + 0x2e0, number(0) .. number(0))
    put(authored + 0xf12a10, ptr(types)); put(types + (0x33333333 % 8) * 16, key .. word(2))
    put(types + 0x80 + 2 * 32, word(1))
    put(definition + 0x135, "\1"); unit(2, 0, 100, 0, 0)
    equal(reader:mission_location(call, 42), true, "reference-linked zone uses active target instead of distant objective")
    put(coordinates + 0x308 + 0x2e0, number(20) .. number(0))
    equal(reader:mission_location(call, 42), false, "local player outside reference-linked anchor is hidden")
    put(peers, word(0xffffffff)); put(coordinates + 0x308 + 0x2e0, number(0) .. number(0))
    equal(reader:mission_location(call, 42), true, "native reference falls back through the avatar bridge")
    put(peers, word(224)); put(types + 0x80 + 2 * 32, word(2))
    equal(reader:mission_location(call, 42), false, "reference anchor ignores ineligible entity types")
    put(types + 0x80 + 2 * 32, word(1)); put(peers + 8, word(1))
    equal(reader:mission_location(call, 42), false, "reference anchor ignores inactive targets")
    put(peers + 8, word(2)); put(definition + 0x134, "\1"); put(live + 16, word(player))
    equal(reader:mission_location(call, 42), true, "linked child requires both local and reference proximity")
    put(coordinates + 0x308 + 0x2e0, number(20) .. number(0))
    equal(reader:mission_location(call, 42), false, "linked child outside reference radius is hidden")
    put(definition + 0x134, "\0"); put(definition + 0x135, "\0"); unit(2, 0, 9, 0, 0)
    put(definition + 0x140, number(0 / 0))
    equal(reader:mission_location(call, 42), false, "nonfinite radius fails closed")
    put(definition + 0x140, number(-1))
    equal(reader:mission_location(call, 42), false, "negative radius fails closed")
    put(definition + 0x140, number(10)); put(states + 24, word(8))
    equal(reader:mission_location(call, 42), false, "native stage array bounded")
    put(states + 24, word(0))
    local original = channel.read
    channel.read = function(self, at, size)
        local raw = original(self, at, size)
        if at == definition and size == 0xad0 then put(states + 24, word(1)) end
        return raw
    end
    equal(reader:mission_location(call, 42), false, "stage change during snapshot rejected")
    channel.read = original; put(states + 24, word(0))
    local global = {record = record + 512, command = {1}}
    put(global.record, string.rep("\0", 400))
    equal(reader:mission_location(global, 28), true, "nonlocalized calls retain global behavior")
    local clock = 0x37000000
    root("clock", clock); put(clock + 24, ptr(1000000))
    local data = 0x38000000
    put(data, string.rep("\0", 48)); put(data + 24, ptr(2000000))
    reader.definitions = function() return {[42] = call, [113] = global, [124] = global} end
    reader.inventory = function()
        return {token = "same-loadout", slots = {113, 113, 113, 113}, rows = {
            {kind = 113, slot = 1, uses = 1, address = data},
            {kind = 124, shared = true, uses = 1, address = data},
            {kind = 42, shared = true, uses = 1, address = data}}}, "ready"
    end
    reader.idle = function() return true end
    reader.bindings = function() return {directions = {38, 39, 40, 37}} end
    local inventory = assert(reader:radial(true, false))
    equal(#inventory.rows, 3, "location eligibility separate from cooldown")
    equal(inventory.rows[3].status, "0:01", "visible cooldown retains minutes-seconds")
    equal(reader:request_kind(42, true), nil, "nearby cooldown cannot be invoked")
    put(data + 24, ptr(0))
    local request = assert(reader:request_kind(42, true))
    equal(request.location_required, true, "mission command retains location validation")
    equal(reader:request_location_valid(request, true), true, "nearby command valid")
    unit(2, 0, 100, 0, 0)
    inventory = assert(reader:radial(true, false))
    equal(#inventory.rows, 2, "mission disappears on leaving location")
    equal(inventory.rows[1].kind, 113, "equipped call preserved")
    equal(inventory.rows[2].kind, 124, "common call preserved")
    equal(inventory.token, request.token, "location changes do not replace loadout identity")
    equal(reader:request_kind(42, true), nil, "stale selection cannot start a mission command")
    equal(reader:request_location_valid(request, true), false, "moving away aborts command input")
    equal(reader:request_location_valid({kind = 113}, true), true, "personal command ignores mission position")
    unit(2, 0, 9, 0, 0)
    equal(#assert(reader:radial(true, false)).rows, 3, "mission reappears after reentering location")
    put(generations + 1, "\4")
    equal(#assert(reader:radial(true, false)).rows, 2, "position failure hides mission only")
    put(generations + 1, "\3")
    local discovery, wrappers2, settings2, states2 = 0x39000000, 0x3a000000, 0x3b000000, 0x3c000000
    root("discovery", discovery); put(discovery + 12, word(1))
    put(discovery + 0x30, ptr(wrappers2) .. ptr(settings2) .. ptr(states2)); put(wrappers2, ptr(wrapper))
    put(settings2, string.rep("\0", 44)); put(states2, string.rep("\0", 64))
    put(settings2 + 20, number(10)); put(settings2 + 38, "\1")
    unit(2, 0, 0, 0, 9)
    equal(reader:mission_location(global, 128), true, "discovery uses native local permission and 3D range")
    unit(2, 0, 0, 0, 10.01)
    equal(reader:mission_location(global, 128), false, "discovery rejects vertical out-of-range")
    unit(2, 0, 0, 0, 10)
    equal(reader:mission_location(global, 128), false, "discovery native radius is exclusive at its boundary")
    unit(2, 0, 0, 0, 9); put(settings2 + 38, "\0")
    equal(reader:mission_location(global, 128), false, "discovery permission off hides even at target")
    put(settings2 + 38, "\1"); put(states2 + 57, "\1")
    equal(reader:mission_location(global, 128), false, "completed discovery excluded")
end
