local checks = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
    checks = checks + 1
end
local function read(name)
    local file = assert(io.open(name, "rb"))
    local text = file:read("*a"); file:close(); return text:gsub("\r\n", "\n")
end
local function expand(text, files)
    for marker, name in pairs(files) do
        text = text:gsub("%-%- @" .. marker .. "@", function() return read(name) end)
    end
    return text
end
assert(loadstring(read("dist/combined.generated.lua")))
local ffi = require("ffi")
ffi.cdef(dofile("native.lua").declarations)
ffi.cdef(dofile("stratagem/platform.lua").declarations)
equal(ffi.sizeof("HD2AR_INPUT"), 40, "reload input layout in shared VM")
equal(ffi.sizeof("HD2SH_INPUT"), 40, "stratagem input layout in shared VM")
local reload_source = expand(read("addon.lua"), {OPTIONS = "options.lua", POLICY = "policy.lua", CHARGE = "charge_policy.lua"})
reload_source = reload_source:gsub("%-%- @NATIVE@", "return TEST_NATIVE")
    :gsub("%-%- @NATIVE_READER@", "return {new=function() if FAIL_RELOAD then error('reload init') end; return TEST_READER end}")
    :gsub("%-%- @READER_CORE@", "return TEST_PARTS")
    :gsub("%-%- @NUMBERS@", "return {}")
local stratagem_source = expand(read("stratagem/addon.lua"), {POLICY = "stratagem/policy.lua",
    VISIBILITY = "stratagem/dist/visibility.generated.lua"})
stratagem_source = stratagem_source:gsub("%-%- @PLATFORM@", "return {create=function() return TEST_CHANNEL end}")
    :gsub("%-%- @READER@", "return {new=function() if FAIL_STRATAGEM then error('stratagem init') end; return TEST_MENU end}")
    :gsub("%-%- @RADIAL@", "return {new=function() return TEST_RADIAL end}")
local combined_source = read("combined.lua")
    :gsub("%-%- @AUTORELOAD@", function() return reload_source end)
    :gsub("%-%- @STRATAGEM@", function() return stratagem_source end)

local function fixture(flags, list_vk, fail_reload, fail_stratagem, start_mode)
    flags, list_vk = flags or {}, list_vk or 5
    local selected = {autoreload_setting_enabled = true, autoreload_setting_charge90 = true,
        stratagem_option_radial = true, stratagem_option_hotkeys = true}
    for key, value in pairs(flags) do
        if value == false then selected[key] = nil else selected[key] = value end
    end
    flags = selected
    local keys, events, order, logs = {}, {}, {}, {}
    local now, focused, hover, base, reads, stops = 0, true, 1, 0, 0, 0
    local latch, observed = nil, true
    if start_mode == "toggle" then latch = false end
    local shot = {active = true, native = true, avatar = 100, weapon = "native:100:ammo",
        mode = "ammo", ammo = 1, reserve = 2, reloading = false, feed = "magazine"}
    local binding = {start_vk = list_vk, start_mode = start_mode, directions = {38, 39, 40, 37}, owner = 1}
    local env = setmetatable({}, {__index = _G}); env._G = env
    env.FAIL_RELOAD, env.FAIL_STRATAGEM = fail_reload, fail_stratagem
    env.os = setmetatable({getenv = function() return nil end}, {__index = os})
    env.update = function() base = base + 1; order[#order + 1] = "base"; return 123, nil, 321 end
    env.shutdown = function() stops = stops + 1; return "closed" end
    env.CowboyBingusModLoader = {api = 1, open_log = function()
        return {write = function(_, line) logs[#logs + 1] = line end, flush = function() end, close = function() end}
    end}
    env.require = function(name)
        local suffix = name:match("^mods/hd2_helper/(.+)$")
        if suffix then return flags[suffix] end
        return require(name)
    end
    env.stingray = {Network = {game_session = function() return 1 end, peer_id = function() return 2 end},
        GameSession = {in_session = function() return true end},
        Application = {time_since_launch = function() return now end,
            main_world = function() return 3 end, worlds = function() return {3} end,
            can_get = function(_, name) return flags[name:match("^mods/hd2_helper/(.+)$")] ~= nil end}}
    env.TEST_PARTS = {GeneratedCommon = {}, IdentityCore = {new = function()
        return {invalidate = function() end, in_control = function() return true end,
            rotation_free = function() return true end, resolve = function()
                return {avatar = {goid = 100}, grip = 15, status = "resolved", hand_weapon = {goid = 5}}
            end}
    end}}
    env.TEST_READER = {sample = function()
        reads = reads + 1; order[#order + 1] = "reload"
        local copy = {}; for key, value in pairs(shot) do copy[key] = value end
        return copy, "ready"
    end}
    env.TEST_NATIVE = {create = function()
        return {process = 42, pid = {[0] = 0}, flags = 8, size = 40,
            input = {[0] = {type = 1, value = {key = {}}}}, mouse = {[0] = {type = 0}},
            user32 = {GetAsyncKeyState = function(vk) return keys[vk] and -32768 or 0 end,
                GetForegroundWindow = function() return 1 end,
                GetWindowThreadProcessId = function(_, pid) pid[0] = focused and 42 or 7 end,
                SendInput = function(_, input)
                    events[#events + 1] = {route = input[0].type == 0 and "charge" or "reload",
                        down = input[0].type == 1 and input[0].value.key.flags == 8}
                    if input[0].type == 0 then keys[1] = false end
                    return 1
                end}}
    end}
    local function active() if latch ~= nil then return latch end; return keys[list_vk] == true end
    env.TEST_CHANNEL = {foreground = function() return focused end,
        down = function(vk) return keys[vk] == true end,
        key = function(vk, down)
            events[#events + 1] = {route = "list", vk = vk, down = down}; keys[vk] = down
            if start_mode == "toggle" then
                if down then latch = not latch end
            elseif latch ~= nil then latch = down end
            return true
        end,
        command_key = function(vk, down)
            events[#events + 1] = {route = "command", vk = vk, down = down}; keys[vk] = down; return true
        end}
    local function request()
        return {kind = 1, keys = {38, 39}, directions = {1, 2}, token = "LOADOUT", bindings = binding}
    end
    env.TEST_MENU = {bindings = function() return binding, "ready" end,
        idle = function() order[#order + 1] = "stratagem"; return true end,
        game_menu = function() return {active = active(), token = "CHARACTER"}, "ready" end,
        menu_active = active, command_state = function()
            if not observed then return nil end
            return {start = active(), directions = {keys[38] == true, keys[39] == true, false, false}}
        end,
        radial = function() return {token = "LOADOUT", rows = {{kind = 1, ready = true, status = "READY"}}}, "ready" end,
        loadout = function() return {token = "LOADOUT"} end, request = request, request_kind = request}
    env.TEST_RADIAL = {restore = function() end, dispose = function() end,
        open = function(self, inventory) self.opened, self.inventory, self.selected = true, inventory, hover; return true end,
        draw = function(self) self.selected = hover; return true end,
        close = function(self) self.opened, self.inventory, self.selected = false, nil, nil end}
    local chunk = assert(loadstring(combined_source)); setfenv(chunk, env); chunk()
    return {env = env, keys = keys, shot = shot, events = events, logs = logs, chunk = chunk,
        step = function(dt) now = now + dt; return env.update() end,
        counts = function() return base, reads, stops end,
        reset_order = function() for i = #order, 1, -1 do order[i] = nil end end,
        order = order, focus = function(value) focused = value end,
        center = function() hover = nil end, latch = function(value) latch = value end,
        observation = function(value) observed = value end}
end
local function finish(f) for i = 1, 30 do f.step(0.02) end end
local function charge(f, kind)
    f.shot.charge_kind, f.shot.charging, f.shot.charge_limit = kind, true, 3
    if kind == "epoch" then f.shot.charge_limit, f.shot.charge_max = 2.7, 2.8 end
    f.shot.charge_elapsed, f.keys[1] = 2.6, true; f.step(0.06)
    f.shot.charge_elapsed = 2.7; f.step(0.1)
end
local function assert_command(f)
    equal(#f.events, 4, "one two-direction command")
    for _, event in ipairs(f.events) do equal(event.route, "command", "only command directions sent") end
end

local f = fixture()
equal(f.env.HD2HelperAutoReload.config.enabled, true, "combined default reload on")
equal(f.env.HD2HelperAutoReload.config.charge90, true, "combined default charge on")
equal(f.env.HD2StratagemHotkeys.config.radial, true, "combined default radial on")
equal(f.env.HD2StratagemHotkeys.config.hotkeys, true, "combined default hotkeys on")
local a, b, c = f.step(0.06)
equal(a, 123, "base return value"); equal(b, nil, "base nil return"); equal(c, 321, "base final return")
equal(table.concat(f.order, ","), "stratagem,base,reload", "stratagem gate updated before reload")
f.chunk(); f.reset_order(); f.step(0.06)
equal(table.concat(f.order, ","), "stratagem,base,reload", "duplicate combined startup adds no wrappers")
equal(f.env.shutdown(), "closed", "shutdown return preserved")
local base, reads, stops = f.counts(); equal(base, 2, "base updated once per frame"); equal(stops, 1, "base shutdown once")

f = fixture(nil, 5, nil, nil, "toggle"); f.step(0.06)
f.latch(true); f.step(0.02)
equal(f.env.TEST_RADIAL.opened, true, "native toggle opens combined wheel without a held physical button")
charge(f, "epoch")
equal(#f.events, 0, "native toggle blocks charge release during a held selection click")
f.keys[27] = true; f.step(0.02); f.keys[27] = false
f.keys[1] = false; f.shot.ammo = 0; f.step(0.06); f.step(0.06)
equal(#f.events, 0, "native toggle also blocks automatic reload without a held modifier")
f.latch(false); f.shot.ammo = 1; f.step(0.06)
charge(f, "epoch")
equal(#f.events, 1, "charge resumes after actual toggle menu closes")
equal(f.events[1].route, "charge", "resumed charge only releases left mouse")
f.env.shutdown()

f = fixture(nil, 6, nil, nil, "toggle"); f.step(0.06)
f.latch(true); f.step(0.02); f.keys[1] = true
f.shot.ammo, f.shot.charge_kind, f.shot.charging = 0, "epoch", true
f.shot.charge_limit, f.shot.charge_elapsed, f.shot.charge_max = 2.7, 2.7, 2.8
f.step(0.2); f.step(0.2)
equal(#f.events, 0, "held selection click blocks empty-ammo reload and full-charge auto-release")
equal(f.env.TEST_RADIAL.opened, true, "combined selection retains the wheel while click is held")
f.keys[1] = false; f.step(0.02); finish(f)
local directions, list_events = 0, 0
for _, event in ipairs(f.events) do
    equal(event.route ~= "reload" and event.route ~= "charge", true, "selection cannot trigger weapon automation")
    if event.route == "command" then directions = directions + 1 end
    if event.route == "list" then list_events = list_events + 1 end
    equal(event.vk ~= 1, true, "combined selection never injects a fire/throw click")
end
equal(directions, 4, "combined click enters one command")
equal(list_events, 5, "combined click releases stale input, closes and reopens List once")
f.env.shutdown()

f = fixture(nil, 6, nil, nil, "toggle"); f.step(0.06)
f.latch(true); f.step(0.02); f.keys[2] = true
f.shot.ammo, f.shot.charge_kind, f.shot.charging = 0, "epoch", true
f.shot.charge_limit, f.shot.charge_elapsed, f.shot.charge_max = 2.7, 2.7, 2.8
f.step(0.2); f.step(0.2)
equal(#f.events, 0, "held right cancellation blocks reload and charge automation")
equal(f.env.HD2StratagemHotkeys.blocking_inputs, true, "right cancel retains the combined input gate")
f.shot.ammo, f.shot.charging = 1, false
f.keys[2] = false; f.step(0.02); finish(f)
equal(#f.events, 3, "right cancel releases stale input and closes List without reopening")
for _, event in ipairs(f.events) do
    equal(event.route, "list", "right cancel sends no directions or weapon input")
    equal(event.vk, 6, "right cancel sends only the configured List binding")
end
equal(f.env.TEST_MENU.menu_active(), false, "right cancel closes the actual native toggle in the combined mod")
equal(f.env.HD2StratagemHotkeys.blocking_inputs, false, "right cancel releases the combined gate after native closure")
f.env.shutdown()

for _, kind in ipairs({"railgun", "epoch"}) do
    f = fixture(); f.step(0.06); charge(f, kind)
    equal(#f.events, 1, "checked charge checkbox uses the weapon-specific threshold")
    equal(f.events[1].route, "charge", "weapon-specific threshold sends release only")
    f.env.shutdown()
    f = fixture({autoreload_setting_charge90 = false}); f.step(0.06); charge(f, kind)
    equal(#f.events, 0, "explicit charge OFF honored")
    f.env.shutdown()
end

for _, vk in ipairs({5, 6}) do
    f = fixture(nil, vk); f.step(0.06)
    f.keys[vk] = true; f.step(0.02)
    equal(f.env.HD2StratagemHotkeys.blocking_inputs, true, "thumb radial blocks reload in same frame")
    f.shot.ammo = 0; f.step(0.06)
    equal(#f.events, 0, "empty ammo does not reload inside radial")
    f.center(); f.step(0.02); f.latch(true); f.keys[vk] = false; f.step(0.02)
    finish(f)
    equal(#f.events, 1, "center cancel repairs thumb release without reload or directions")
    equal(f.events[1].route, "list", "repair route"); equal(f.events[1].down, false, "repair is up only")
    f.shot.ammo = 1; f.step(0.06); f.shot.ammo = 0; f.step(0.06); f.step(0.06)
    equal(f.events[2].route, "reload", "reload resumes after native release")
    f.env.shutdown()
end

f = fixture(); f.step(0.06)
f.keys[5], f.keys[49] = true, true; f.step(0.02); finish(f)
assert_command(f)
f.keys[5], f.keys[49] = false, false; f.step(0.02)
charge(f, "epoch")
equal(f.events[5].route, "charge", "charge resumes after hotkey command")
f.env.shutdown()

f = fixture(); f.step(0.06); f.keys[5] = true; charge(f, "epoch")
equal(#f.events, 0, "stratagem hold blocks high-charge mouse release")
f.env.shutdown()

f = fixture({autoreload_setting_enabled = false, autoreload_setting_charge90 = false})
equal(f.env.HD2HelperAutoReload, nil, "reload and charge can both be disabled")
equal(f.env.HD2StratagemHotkeys ~= nil, true, "stratagem startup independent of disabled reload")
f.step(0.06); f.keys[5], f.keys[49] = true, true; f.step(0.02); finish(f); assert_command(f); f.env.shutdown()

f = fixture({stratagem_option_radial = false, stratagem_option_hotkeys = false})
equal(f.env.HD2StratagemHotkeys, nil, "both stratagem features can be disabled")
charge(f, "railgun"); equal(f.events[1].route, "charge", "reload feature independent of disabled stratagems")
f.env.shutdown()

f = fixture({stratagem_option_radial = false})
equal(f.env.HD2StratagemHotkeys.config.radial, false, "radial OFF honored independently")
f.step(0.06); f.keys[5], f.keys[49] = true, true; f.step(0.02); finish(f); assert_command(f); f.env.shutdown()
f = fixture({stratagem_option_hotkeys = false})
equal(f.env.HD2StratagemHotkeys.config.hotkeys, false, "number hotkeys OFF honored independently")
f.step(0.06); f.keys[5], f.keys[49] = true, true; f.step(0.02); finish(f)
equal(f.env.TEST_RADIAL.opened, true, "radial still available with hotkeys OFF")
equal(#f.events, 0, "hotkey OFF does not send number shortcut"); f.env.shutdown()
f = fixture({autoreload_setting_enabled = false, autoreload_setting_charge90 = false,
    stratagem_option_radial = false, stratagem_option_hotkeys = false})
equal(f.env.HD2HelperAutoReload, nil, "all-off reload absent")
equal(f.env.HD2StratagemHotkeys, nil, "all-off stratagems absent")
f.step(0.06); equal(#f.events, 0, "all-off sends no input")
equal(f.env.shutdown(), "closed", "all-off preserves base shutdown")

f = fixture(nil, 5, true)
equal(f.env.HD2HelperCombined.autoreload_error ~= nil, true, "reload init failure isolated")
f.step(0.06); f.keys[5], f.keys[49] = true, true; f.step(0.02); finish(f); assert_command(f); f.env.shutdown()
f = fixture(nil, 5, false, true)
equal(f.env.HD2HelperCombined.stratagem_error ~= nil, true, "stratagem init failure isolated")
charge(f, "epoch"); equal(f.events[1].route, "charge", "charge survives stratagem init failure"); f.env.shutdown()
print("PASS " .. checks .. " combined startup/input checks; no OS input sent")
