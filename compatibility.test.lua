return function(api, equal)
    local fixture = "vendor/hud_hooks_reference.lua"
    local function environment()
        local env = {}
        for key, value in pairs(_G) do env[key] = value end
        env._G = env
        return env
    end
    for _, order in ipairs({ "hud-first", "reload-first" }) do
        local env = environment()
        local base, hud, reload, stopping = 0, 0, 0, 0
        local init = function() return "init" end
        local render = function() return "render" end
        env.init, env.render = init, render
        env.update = function(a, b)
            base = base + 1
            return a, nil, b
        end
        env.shutdown = function(value) stopping = stopping + 1; return value end
        local state = setfenv(assert(loadfile(fixture)), env)()
        local worker = { update = function() hud = hud + 1 end }
        local function add_reload()
            equal(api.install_hooks(env, function() reload = reload + 1 end,
                function() stopping = stopping + 1 end), true, order .. " reload installed")
        end
        if order == "hud-first" then
            equal(state.install(worker), true); add_reload()
        else
            add_reload(); equal(state.install(worker), true)
        end
        for i = 1, 20 do
            local a, b, c = env.update(i, i + 1)
            equal(a, i); equal(b, nil); equal(c, i + 1)
        end
        equal(base, 20, order .. " game updated once per frame")
        equal(hud, 20, order .. " HUD updated once per frame")
        equal(reload, 20, order .. " reload updated once per frame")
        equal(env.init, init, "init not replaced")
        equal(env.render, render, "render not replaced")
        equal(env.shutdown("done"), "done", "shutdown return preserved")
        equal(stopping, 2, "both shutdown callbacks called")
        worker.update = function() error("mock HUD failure") end
        env.update(1, 2)
        equal(reload, 21, "HUD's error isolation preserves reload")
        equal(base, 21, "HUD's error isolation preserves game")
    end

    local original_snapshot = { hud_health = { from = "health" } }
    local fragment_snapshot = { ammo = { from = "signal:ammo" } }
    local original = { identity = {}, snapshot = original_snapshot, signals = { hud_only = true } }
    local parts = { GeneratedCommon = original, IdentityCore = { new = function() return {} end },
        Provider = { new = function() return {} end } }
    local reader = api.Reader.new(parts, { snapshot = fragment_snapshot })
    equal(original.snapshot, original_snapshot, "HUD snapshot object preserved")
    equal(original.signals.hud_only, true, "HUD signals preserved")
    equal(original_snapshot.reloading, nil, "HUD fields not extended")
    equal(fragment_snapshot.raw_slot0, nil, "fragment fields not mutated")
    equal(reader.generated == original, false, "generated tables are isolated")
    equal(reader.generated.snapshot == fragment_snapshot, false, "private field map")

    local errors, base, stopped = {}, 0, 0
    local env = { update = function() base = base + 1; return 1, nil, 3 end,
        shutdown = function() stopped = stopped + 1; return "stopped" end }
    api.install_hooks(env, function() error("reload failure") end,
        function() error("reload stop failure") end,
        function(where) errors[#errors+1] = where end)
    local a, b, c = env.update()
    equal(a, 1); equal(b, nil); equal(c, 3)
    equal(base, 1, "reload error does not block outer HUD wrapper")
    equal(errors[1], "update")
    equal(env.shutdown(), "stopped", "reload stop failure does not block other mods")
    equal(stopped, 1); equal(errors[2], "shutdown")

    -- Real DLL symbol resolution and declaration coexistence, without SendInput calls.
    local ffi = require("ffi")
    ffi.cdef[[ unsigned int SendInput(unsigned int, const void*, int); ]]
    local user32 = ffi.load("user32")
    local shared_type = tostring(ffi.typeof(user32.SendInput))
    local native = api.Native.create(ffi, { reload_vk = 82 })
    equal(tostring(ffi.typeof(user32.SendInput)), shared_type, "shared SendInput signature untouched")
    equal(native.size, 40, "actual private INPUT ABI")
    equal(native.process > 0, true, "aliased GetCurrentProcessId resolves")
    equal(native.input[0].value.key.scan > 0, true, "aliased MapVirtualKeyW resolves")
    equal(type(native.user32.SendInput), "cdata", "aliased SendInput resolves without calling")
    equal(native.mouse[0].type, 0, "separate mouse INPUT type")
    equal(native.mouse[0].value.mouse.flags, 4, "actual left-button release flag")
    equal(native.input[0].type, 1, "reload INPUT remains a keyboard event")
end
