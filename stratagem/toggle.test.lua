return function(equal, read_file)
    local function fixture(vk)
        local now, active, focused, idle, available, token = 0, false, true, true, true, "CHARACTER"
        local keys, events = {}, {}
        local hover, ready, lost, acknowledge, close_on_command = 1, true, false, true, true
        local loadout_token, surface = "LOADOUT", true
        local native_list_down, lost_release = false, false
        local pulse_started, deferred_toggle, minimum_hold, event_delay = nil, nil, 0, 0
        local ignore_toggle, release_failure, press_failure = false, false, false
        local function native_toggle()
            if ignore_toggle then return end
            if event_delay > 0 then deferred_toggle = now + event_delay else active = not active end
        end
        local binding = {start_vk = vk, start_mode = "toggle", owner = 1, directions = {38, 39, 40, 37}}
        local radial = {restore = function() end, dispose = function() end}
        function radial:open(inventory)
            self.opened, self.inventory, self.selected = true, inventory, hover
            return true
        end
        function radial:draw() self.selected = hover; return surface end
        function radial:close() self.opened, self.inventory, self.selected = false, nil, nil end
        local channel = {foreground = function() return focused end, down = function(key) return keys[key] == true end,
            key = function(key, down)
                events[#events + 1] = {route = "list", vk = key, down = down}
                if down and press_failure or not down and release_failure then return false end
                keys[key] = down
                if key == vk then
                    if down and not native_list_down then
                        if minimum_hold > 0 then pulse_started = now else native_toggle() end
                    elseif not down and native_list_down and pulse_started then
                        if now - pulse_started >= minimum_hold then native_toggle() end
                        pulse_started = nil
                    end
                    native_list_down = down
                end
                return true
            end,
            command_key = function(key, down)
                events[#events + 1] = {route = "command", vk = key, down = down}
                keys[key] = down
                if key == 39 and not down and close_on_command then active = false end
                return true
            end}
        local function request()
            if ready then return {kind = 1, token = loadout_token, bindings = binding,
                keys = {38, 39}, directions = {1, 2}} end
        end
        local reader = {bindings = function() return binding, "ready" end,
            idle = function() return idle end, menu_active = function() return active end,
            game_menu = function() if available then return {active = active, token = token}, "ready" end end,
            command_state = function()
                if not available then return nil end
                return {start = active, directions = {acknowledge and keys[38] == true,
                    acknowledge and keys[39] == true, false, false}}
            end,
            radial = function() return {token = loadout_token, rows = {{kind = 1, ready = ready, status = "READY"}}}, "ready" end,
            loadout = function() return {token = loadout_token} end, request = request, request_kind = request}
        local env = setmetatable({CHANNEL = channel, READER = reader, RADIAL = radial}, {__index = _G}); env._G = env
        env.CowboyBingusModLoader = {api = 1, open_log = function()
            return {write = function() end, flush = function() end, close = function() end}
        end}
        env.require = function(name)
            if name == "mods/hd2_helper/stratagem_option_radial" or
                name == "mods/hd2_helper/stratagem_option_hotkeys" then return true end
            return require(name)
        end
        env.stingray = {Application = {time_since_launch = function() return now end,
            can_get = function(_, name)
                return name == "mods/hd2_helper/stratagem_option_radial" or
                    name == "mods/hd2_helper/stratagem_option_hotkeys"
            end}}
        local source = read_file("addon.lua")
            :gsub("%-%- @PLATFORM@", "return {create=function() return CHANNEL end}")
            :gsub("%-%- @READER@", "return {new=function() return READER end}")
            :gsub("%-%- @RADIAL@", "return {new=function() return RADIAL end}")
            :gsub("%-%- @POLICY@", function() return read_file("policy.lua") end)
            :gsub("%-%- @VISIBILITY@", function() return read_file("dist/visibility.generated.lua") end)
        local chunk = assert(loadstring(source)); setfenv(chunk, env); chunk()
        local f = {env = env, radial = radial, events = events, binding = binding, keys = keys}
        function f.step(dt)
            now = now + (dt or 0.02)
            if deferred_toggle and now >= deferred_toggle then active, deferred_toggle = not active, nil end
            env.update()
        end
        function f.finish() for i = 1, 70 do f.step() end end
        function f.press(key)
            keys[key] = true
            if key == vk and not (lost and radial.opened) then
                if not native_list_down then active = not active end
                native_list_down = true
            end
            f.step()
        end
        function f.release(key)
            keys[key] = false
            if key == vk and not (lost_release and radial.opened) then native_list_down = false end
            f.step()
        end
        function f.menu_active() return active end
        function f.native_list_down() return native_list_down end
        function f.open()
            f.step(); f.press(vk)
            equal(radial.opened, true, "native toggle activation opens the radial")
            f.release(vk)
            equal(radial.opened, true, "toggle release leaves the radial open")
        end
        function f.set(name, value)
            if name == "hover" then hover = value
            elseif name == "ready" then ready = value
            elseif name == "lost" then lost = value
            elseif name == "lost_release" then lost_release = value
            elseif name == "minimum_hold" then minimum_hold = value
            elseif name == "event_delay" then event_delay = value
            elseif name == "ignore_toggle" then ignore_toggle = value
            elseif name == "release_failure" then release_failure = value
            elseif name == "press_failure" then press_failure = value
            elseif name == "focused" then focused = value
            elseif name == "idle" then idle = value
            elseif name == "available" then available = value
            elseif name == "active" then active = value
            elseif name == "token" then token = value
            elseif name == "loadout_token" then loadout_token = value
            elseif name == "surface" then surface = value
            elseif name == "acknowledge" then acknowledge = value
            elseif name == "close_on_command" then close_on_command = value
            elseif name == "mode" then
                binding = {start_vk = vk, start_mode = value, owner = 1, directions = {38, 39, 40, 37}}
                f.binding = binding
            end
        end
        return f
    end
    local function count(f, route)
        local total = 0
        for _, event in ipairs(f.events) do if event.route == route then total = total + 1 end end
        return total
    end
    for _, vk in ipairs({164, 5, 6}) do
        local f = fixture(vk)
        f.open(); f.finish()
        equal(f.radial.opened, true, "toggle is not tied to physical hold duration")
        equal(#f.events, 0, "opening and holding toggle sends no synthetic input")
        equal(f.env.HD2StratagemHotkeys.blocking_inputs, true, "active toggle blocks reload without a held list key")
        f.press(vk); equal(f.radial.opened, false, "second toggle press closes the radial")
        f.release(vk); f.finish()
        equal(count(f, "list"), 2, "selected toggle command uses one bounded list-key pulse")
        equal(count(f, "command"), 4, "selected toggle enters one observed command")
        equal(f.keys[vk], false, "injected toggle press is released")
        equal(f.radial.opened, false, "injected menu reopening cannot reopen the wheel")
        equal(f.env.HD2StratagemHotkeys.blocking_inputs, false, "game menu closure unblocks reload")
        f.env.shutdown()

        for _, cancel in ipairs({false, true}) do
            f = fixture(vk); f.set("lost_release", true); f.open()
            f.set("minimum_hold", 0.05); f.set("event_delay", 0.06)
            if cancel then f.set("hover", nil); f.step() end
            f.press(1); f.release(1); f.finish()
            equal(count(f, "command"), cancel and 0 or 4, "delayed menu updates and release-triggered pulses need no extra physical press")
            equal(f.menu_active(), false, "delayed native closure completes center cancellation or selection")
            equal(f.native_list_down(), false, "delayed toggle processing leaves List released")
            equal(f.env.HD2StratagemHotkeys.blocking_inputs, false, "delayed native updates finish without indefinite blocking")
            f.env.shutdown()
        end

        for _, failure in ipairs({"release_failure", "press_failure", "ignore_toggle"}) do
            f = fixture(vk); f.open(); f.set(failure, true)
            f.press(1); f.release(1); f.finish()
            equal(count(f, "command"), 0, failure .. " cannot dispatch without confirmed native closure")
            equal(f.env.HD2StratagemHotkeys.toggle_close, nil, failure .. " has a bounded cancellation path")
            equal(f.keys[vk], false, failure .. " leaves no injected List hold")
            equal(f.env.HD2StratagemHotkeys.blocking_inputs, true, failure .. " keeps weapon automation blocked while the real menu is active")
            equal(count(f, "list") <= 3, true, failure .. " never repeatedly toggles the menu")
            f.set(failure, false); f.env.shutdown()
        end

        f = fixture(vk); f.set("lost_release", true); f.open()
        f.press(1); f.release(1); f.step(0.1)
        equal(#f.events, 1, "pre-close release is separated from the next press by an input interval")
        equal(f.events[1].down, false, "pre-close operation only releases stale input")
        f.set("focused", false); f.finish()
        equal(#f.events, 1, "focus loss after release prevents close/reopen/command input")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(1); f.finish()
        equal(f.radial.opened, true, "selection click retains cursor capture until physical release")
        equal(#f.events, 0, "held selection click cannot close or reopen the native menu")
        equal(f.env.HD2StratagemHotkeys.blocking_inputs, true, "selection click blocks automatic reload/charge release")
        f.release(1); f.finish()
        equal(f.radial.opened, false, "left click release confirms the hovered toggle sector")
        equal(count(f, "list"), 5, "click confirmation synchronizes release, closes and reopens with bounded List pulses")
        equal(count(f, "command"), 4, "click confirmation enters exactly one observed command")
        equal(f.keys[vk], false, "click selection releases injected List input")
        equal(f.env.HD2StratagemHotkeys.blocking_inputs, false, "completed click selection unblocks reload")
        for _, event in ipairs(f.events) do equal(event.vk ~= 1, true, "click confirmation never injects fire or throw") end
        f.env.shutdown()

        f = fixture(vk); f.open(); f.set("hover", nil); f.press(1)
        f.release(1); f.finish()
        equal(count(f, "list"), 3, "center click releases stale List input and closes the native menu once")
        equal(f.menu_active(), false, "center click closes the game menu, not just the wheel")
        equal(count(f, "command"), 0, "center click is cancellation, not call-in selection")
        f.env.shutdown()

        f = fixture(vk); f.set("lost_release", true); f.open(); f.press(2); f.finish()
        equal(f.radial.opened, true, "right-click retains capture until physical button release")
        equal(#f.events, 0, "held cancel click cannot synthesize aim or List input")
        f.release(2); f.finish()
        equal(count(f, "command"), 0, "right-click cancels even while hovering a ready sector")
        equal(count(f, "list"), 3, "right-click synchronizes release and closes native List once")
        equal(f.menu_active(), false, "right-click closes the real stratagem toggle")
        equal(f.native_list_down(), false, "right-click leaves no List button latched")
        equal(f.env.HD2StratagemHotkeys.blocking_inputs, false, "right-cancel completes after native closure")
        for _, event in ipairs(f.events) do
            equal(event.vk ~= 1 and event.vk ~= 2, true, "right cancellation never injects fire or aim")
        end
        f.env.shutdown()

        for _, released_first in ipairs({1, 2}) do
            f = fixture(vk); f.open(); f.press(1); f.press(2)
            f.release(released_first); f.finish()
            equal(#f.events, 0, "mixed clicks wait until both physical buttons are released")
            f.release(released_first == 1 and 2 or 1); f.finish()
            equal(count(f, "command"), 0, "right-click takes priority over an existing left-click selection")
            equal(f.menu_active(), false, "mixed-button cancellation closes native List")
            f.env.shutdown()
        end

        f = fixture(vk); f.open(); f.press(2); f.press(1); f.release(2); f.release(1); f.finish()
        equal(count(f, "command"), 0, "left click cannot revive an outstanding right-click cancellation")
        equal(f.menu_active(), false, "right-then-left cancellation closes native List")
        f.env.shutdown()

        f = fixture(vk); f.press(2); f.open(); f.finish()
        equal(f.radial.opened, true, "right button held before opening is not a fresh cancel click")
        equal(#f.events, 0, "pre-held right button cannot send guessed cancellation input")
        f.release(2); f.press(2); f.release(2); f.finish()
        equal(f.menu_active(), false, "a fresh right click after opening cancels normally")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(2); f.set("focused", false); f.release(2); f.finish()
        equal(#f.events, 0, "focus loss during right-click cancellation cannot send input")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(1); f.set("hover", nil); f.step(); f.release(1); f.finish()
        equal(count(f, "command"), 4, "click captures the sector at mouse-down, not release-time recentering")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.set("hover", nil); f.step(); f.set("hover", 1)
        f.press(1); f.release(1); f.finish()
        equal(count(f, "command"), 4, "click hit testing uses the current cursor rather than stale hover")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(1); f.press(50); f.release(50); f.release(1); f.finish()
        equal(count(f, "command"), 4, "number key during held confirmation cannot queue an extra command")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(1); f.set("ready", false); f.release(1); f.finish()
        equal(count(f, "list"), 3, "a newly unavailable call-in closes without reopening")
        equal(count(f, "command"), 0, "click selection revalidates readiness before input")
        f.env.shutdown()

        for _, fault in ipairs({"focused", "idle", "available", "active", "token", "loadout_token", "mode"}) do
            f = fixture(vk); f.open(); f.press(1)
            f.set(fault, (fault == "token" or fault == "loadout_token") and "REPLACED" or fault == "mode" and "hold" or false)
            f.step(0.3); f.release(1); f.finish()
            equal(f.radial.opened, false, fault .. " change cancels click selection")
            equal(#f.events, 0, fault .. " change before click release cannot send any command")
            f.env.shutdown()
        end
        f = fixture(vk); f.open(); f.set("surface", false); f.press(1); f.release(1); f.finish()
        equal(#f.events, 0, "failed click hit testing cannot select a stale sector")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(1); f.step(10.1); f.release(1); f.finish()
        equal(#f.events, 0, "unreleased click has a bounded cancellation timeout")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(1); f.press(vk); f.release(vk); f.release(1); f.finish()
        equal(#f.events, 0, "List close while a selection click is held cancels rather than double-confirms")
        f.env.shutdown()

        f = fixture(vk); f.step(); f.press(1); f.press(vk); f.release(vk); f.release(1); f.finish()
        equal(count(f, "command"), 0, "fire held before opening cannot count as a selection click")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(1); f.release(1); f.press(1); f.release(1); f.finish()
        equal(count(f, "command"), 0, "a second fire press during preparation cancels pending input")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.set("hover", nil); f.step()
        f.press(vk); f.release(vk); f.finish()
        equal(#f.events, 0, "center toggle cancellation never reopens menu or sends directions")
        f.env.shutdown()

        f = fixture(vk); f.open(); f.press(50); f.release(50); f.finish()
        equal(count(f, "command"), 4, "number shortcut works while toggle menu stays open without modifier")
        equal(count(f, "list"), 0, "toggle hotkey does not toggle an already-open menu")
        f.env.shutdown()

        for _, fault in ipairs({"focused", "idle", "available"}) do
            f = fixture(vk); f.open(); f.set(fault, false); f.step(); f.release(vk); f.finish()
            equal(f.radial.opened, false, fault .. " loss closes toggle radial")
            equal(#f.events, 0, fault .. " loss cannot select a hovered sector")
            f.env.shutdown()
        end
        f = fixture(vk); f.open(); f.set("active", false); f.step(); f.finish()
        equal(f.radial.opened, false, "external game menu closure closes wheel")
        equal(#f.events, 0, "external closure without user toggle cannot issue a command")
        f.env.shutdown()
        f = fixture(vk); f.open(); f.set("mode", "hold"); f.step(0.3); f.finish()
        equal(#f.events, 0, "binding trigger change cannot dispatch the old selection")
        equal(f.radial.opened, false, "binding trigger change closes the old wheel")
        f.env.shutdown()
    end
    for _, vk in ipairs({5, 6}) do
        for _, cancel in ipairs({false, true}) do
            local f = fixture(vk); f.set("lost_release", true); f.open()
            equal(f.keys[vk], false, "physical List key is released outside the captured game input")
            equal(f.native_list_down(), true, "cursor capture can leave the game's List button latched down")
            if cancel then f.set("hover", nil); f.step() end
            f.press(1); f.release(1); f.finish()
            equal(count(f, "command"), cancel and 0 or 4, "stale List latch needs no second physical List press")
            equal(f.menu_active(), false, "center cancel and completed click both close the actual native List menu")
            equal(f.native_list_down(), false, "click recovery leaves no native List button held")
            equal(f.env.HD2StratagemHotkeys.blocking_inputs, false, "native closure completes click recovery")
            equal(f.events[1].vk, vk, "recovery synchronizes the configured List key")
            equal(f.events[1].down, false, "recovery releases stale native List input before any press")
            for _, event in ipairs(f.events) do equal(event.vk ~= 1, true, "native closure never injects fire or throw") end
            f.env.shutdown()
        end
        for _, cancel in ipairs({false, true}) do
            local f = fixture(vk); f.open(); f.set("lost", true)
            if cancel then f.set("hover", nil); f.step() end
            f.press(vk); f.release(vk); f.finish()
            equal(count(f, "list"), cancel and 3 or 5, "lost thumb close is replayed once after synchronized release")
            equal(count(f, "command"), cancel and 0 or 4, "lost thumb toggle respects selection or center cancellation")
            equal(f.keys[vk], false, "no thumb key remains held after recovery")
            equal(f.env.HD2StratagemHotkeys.blocking_inputs, false, "recovered thumb toggle has settled")
            f.env.shutdown()
        end
    end
    local f = fixture(164); f.open(); f.set("ready", false); f.step(0.06)
    f.press(164); f.release(164); f.finish()
    equal(#f.events, 0, "cooldown toggle sector cannot send a command")
    f.env.shutdown()
    f = fixture(164); f.open(); f.press(164); f.set("token", "REPLACED"); f.release(164); f.finish()
    equal(#f.events, 0, "character change during toggle closure cancels selection")
    f.env.shutdown()
    f = fixture(164); f.open(); f.set("acknowledge", false)
    f.press(164); f.release(164); f.finish()
    equal(count(f, "command"), 2, "unobserved toggle command releases first direction and aborts")
    equal(f.keys[38], false, "failed toggle direction is not left held")
    f.env.shutdown()
end
