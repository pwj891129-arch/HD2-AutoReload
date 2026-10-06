local ffi = require('ffi')
ffi.cdef[[
void* OpenProcess(unsigned int, int, unsigned int);
int ReadProcessMemory(void*, const void*, void*, size_t, size_t*);
int CloseHandle(void*);
]]
local kernel = ffi.load('kernel32')
local handle = kernel.OpenProcess(0x410, 0, target_pid)
assert(handle ~= nil, 'Read-only game access unavailable')
local started, bytes = os.clock(), 0
local channel = {base=game_base, exe_base=exe_base}
function channel:read(at, size)
    if type(at) ~= 'number' or at < 65536 or at >= 140737488355328 or size < 1 or
        size > 262144 or bytes + size > 16777216 or os.clock() - started > 10 then return nil end
    bytes = bytes + size
    local buffer, actual = ffi.new('unsigned char[?]', size), ffi.new('size_t[1]')
    if kernel.ReadProcessMemory(handle, ffi.cast('const void*', at), buffer, size, actual) == 0 or
        tonumber(actual[0]) ~= size then return nil end
    return ffi.string(buffer, size)
end
local function display(value)
    if type(value) == 'table' then return table.concat(value, ',') end
    return tostring(value)
end
local function run()
    local reader = dofile('reader.lua').new(channel)
    local here = reader:local_position()
    print('READ-ONLY local-position=' .. display(here))
    local inventory, why = reader:inventory(true)
    assert(inventory, why)
    local definitions = assert(reader:definitions())
    for _, row in ipairs(inventory.rows) do
        local call = definitions[row.kind]
        print('CALL kind=' .. row.kind .. ' shared=' .. tostring(row.shared) .. ' region=' ..
            tostring(reader:word(call.record + 0x7c)) .. ' location=' ..
            tostring(reader:mission_location(call, row.kind, here)))
    end
    local root = reader:root('objectives')
    local count = root and reader:word(root + 0x24)
    assert(count and count <= 1024, 'Objective count unavailable')
    print('OBJECTIVES count=' .. count)
    local wrappers, runtime, states = reader:ptr(root + 0x50), reader:ptr(root + 0x60), reader:ptr(root + 0x68)
    for i = 0, count - 1 do
        local wrapper = reader:ptr(wrappers + i * 8)
        local key = wrapper and reader:read(wrapper, 8)
        local definition = key and reader:objective_definition(key)
        local stage = reader:word(states + i * 0x64 + 0x18)
        local live = runtime + i * 0x1078
        print('OBJECTIVE index=' .. i .. ' definition=' .. tostring(definition ~= nil) ..
            ' stage=' .. tostring(stage) .. ' key=' .. tostring(wrapper and reader:hash(wrapper)))
        if definition and stage and stage < 8 then
            local zone = definition + 0x130 + stage * 0x120
            local call_kinds = {}
            for entry = 0, 3 do call_kinds[#call_kinds + 1] = reader:word(definition + entry * 16) or -1 end
            local radius_raw = reader:read(zone + 16, 4)
            local radius = radius_raw and tonumber(ffi.cast('const float*', radius_raw)[0])
            local target = reader:unit_position(reader:word(wrapper + 12))
            local flags = reader:read(zone + 4, 4)
            print('OBJECTIVE index=' .. i .. ' calls=' .. display(call_kinds) .. ' stage=' .. stage ..
                ' status=' .. tostring(reader:word(live + 0x1018)) .. ' region=' .. tostring(reader:word(zone)) ..
                ' radius=' .. tostring(radius) .. ' flags=' .. (flags and table.concat({flags:byte(1,4)}, ',') or 'nil') ..
                ' target=' .. display(target) .. ' children=' .. tostring(reader:word(live + 8)))
            for s = 0, 7 do
                local row = definition + 0x130 + s * 0x120
                local region = reader:word(row)
                if region and region ~= 0 then
                    local raw = reader:read(row + 16, 4)
                    local r = raw and tonumber(ffi.cast('const float*', raw)[0])
                    print('AREA index=' .. i .. ' stage=' .. s .. ' region=' .. region ..
                        ' radius=' .. tostring(r) .. ' passive=' .. tostring(reader:read(definition + 8, 1):byte(1)))
                end
            end
        end
    end
    print('READ-ONLY bytes=' .. bytes)
end
local good, error_message = pcall(run)
kernel.CloseHandle(handle)
assert(good, error_message)
