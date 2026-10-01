return function(equal, read_file)
    local function fixture(vk)
        local now, active, focused, idle, available, token = 0, false, true, true, true, "CHARACTER"
        local keys, events = {}, {}
        local hover, ready, lost, acknowledge, close_on_command = 1, true, false, true, true
        local binding = {start_vk = vk, start_mode = "toggle", owner = 1, directions = {38, 39, 40, 37}}
        local radial = {restore = function() end, dispose = function() end}
        function radial:open(inventory)
            self.opened, self.inventory, self.selected = true, inventory, hover
            return true
        end
        function radial:draw() self.selected = hover; return true end
        function radial:close() self.opened, self.inventory, self.selected = false, nil, nil end
        local channel = {foreground = function() return focused end, down = function(key) return keys[key] == true end,
            key = function(key, down)
                events[#events + 1] = {route = "list", vk = key, down = down}
                keys[key] = down
                if key == vk and down then active = not active end
                return true
            end,
            command_key = function(key, down)
                events[#events + 1] = {route = "command", vk = key, down = down}
                keys[key] = down
                if key == 39 and not down and close_on_command then active = false end
                return true
            end}
        local function request()
            if ready then return {kind = 1, token = "LOADOUT", bindings = binding,
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
            radial = function() return {token = "LOADOUT", rows = {{kind = 1, ready = ready, status = "READY"}}}, "ready" end,
            loadout = function() return {token = "LOADOUT"} end, request = request, request_kind = request}
        local env = setmetatable({CHANNEL = channel, READER = reader, RADIAL = radial}, {__index = _G}); env._G = env
        env.CowboyBingusModLoader = {api = 1, open_log = function()
            return {write = function() end, flush = function() end, close = function() end}
        end}
        env.stingray = {Application = {time_since_launch = function() return now end}}
        local source = read_file("addon.lua")
            :gsub("%-%- @PLATFORM@", "return {create=function() return CHANNEL end}")
            :gsub("%-%- @READER@", "return {new=function() return READER end}")
            :gsub("%-%- @RADIAL@", "return {new=function() return RADIAL end}")
            :gsub("%-%- @POLICY@", function() return read_file("policy.lua") end)
            :gsub("%-%- @VISIBILITY@", function() return read_file("dist/visibility.generated.lua") end)
        local chunk = assert(loadstring(source)); setfenv(chunk, env); chunk()
        local f = {env = env, radial = radial, events = events, binding = binding, keys = keys}
        function f.step(dt) now = now + (dt or 0.02); env.update() end
        function f.finish() for i = 1, 70 do f.step() end end
        function f.press(key)
            keys[key] = true
            if key == vk and not (lost and radial.opened) then active = not active end
            f.step()
        end
        function f.release(key) keys[key] = false; f.step() end
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
            elseif name == "focused" then focused = value
            elseif name == "idle" then idle = value
            elseif name == "available" then available = value
            elseif name == "active" then active = value
            elseif name == "token" then token = value
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
            local f = fixture(vk); f.open(); f.set("lost", true)
            if cancel then f.set("hover", nil); f.step() end
            f.press(vk); f.release(vk); f.finish()
            equal(count(f, "list"), cancel and 2 or 4, "lost thumb close is replayed once after cursor restore")
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
