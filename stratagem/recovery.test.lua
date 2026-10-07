return function(equal, read_file, Radial)
    local Policy = dofile("policy.lua")
    local function fixture(mode, vk)
        local f = {now = 0, held = {}, events = {}, faults = {}, instances = {}, logs = {},
            focused = true, active = false, chained = 0}
        local binding = {owner = "OWNER", start_vk = vk or 164, start_mode = mode or "hold",
            directions = {38, 39, 40, 37}}
        local function fault(name) if f.faults[name] then error("temporary-" .. name) end end
        local channel = {foreground = function() return f.focused end,
            down = function(key) return f.held[key] == true end,
            key = function(key, down)
                fault("list-send")
                if not down and f.faults["list-release"] then return false end
                f.events[#f.events + 1] = {key, down}
                f.held[key] = down
                return true
            end,
            command_key = function(key, down)
                if not down then fault("direction-release") end
                f.events[#f.events + 1] = {key, down}
                f.held[key] = down
                return true
            end}
        local function active()
            if binding.start_mode == "toggle" then return f.active end
            return f.held[binding.start_vk] == true
        end
        local function request()
            return {token = "LOADOUT", kind = 1, keys = {38, 39}, directions = {1, 2}, bindings = binding}
        end
        local reader = {bindings = function() return binding end,
            game_menu = function() return {active = active(), token = "CHARACTER"} end,
            idle = function() fault("reader"); return true end,
            menu_active = active, request = request, request_kind = request,
            command_state = function() return {start = active(),
                directions = {f.held[38] == true, f.held[39] == true, false, false}} end,
            loadout = function() return {token = "LOADOUT"} end,
            radial = function() return {token = "LOADOUT", rows = {{kind = 1, ready = true, status = "READY"}}} end}
        local factory = {new = function()
            fault("factory")
            local radial = {opened = false}
            f.instances[#f.instances + 1] = radial
            function radial:open(inventory)
                fault("open")
                self.inventory, self.opened = inventory, true
                self.mouse = {show = false, focus = true}
                return true
            end
            function radial:draw() fault("draw"); self.selected = 1; return true end
            function radial:restore()
                fault("cursor")
                if f.focused then self.mouse = nil end
            end
            function radial:close()
                self.opened, self.selected, self.inventory = false, nil, nil
                self:restore()
                fault("close")
            end
            function radial:dispose()
                self:close(); fault("dispose"); self.disposed = true
            end
            return radial
        end}
        local env = setmetatable({TEST_CHANNEL = channel, TEST_READER = reader, TEST_RADIAL = factory,
            TEST_POLICY = {new = function(...)
                f.policy = Policy.new(...)
                return f.policy
            end}}, {__index = _G})
        env._G = env
        env.CowboyBingusModLoader = {api = 1, open_log = function()
            return {write = function(_, text) f.logs[#f.logs + 1] = text end, flush = function() end, close = function() end}
        end}
        env.stingray = {Application = {time_since_launch = function() fault("clock"); return f.now end,
            can_get = function(_, resource) return resource:match("stratagem_option_(.+)$") ~= nil end}}
        env.require = function(name)
            local option = name:match("stratagem_option_(.+)$")
            if option then return option == "radial" or option == "hotkeys" end
            return require(name)
        end
        env.update = function() f.chained = f.chained + 1; return "previous-update" end
        local glue = read_file("addon.lua")
            :gsub("%-%- @PLATFORM@", "return {create=function() return TEST_CHANNEL end}")
            :gsub("%-%- @READER@", "return {new=function() return TEST_READER end}")
            :gsub("%-%- @POLICY@", "return TEST_POLICY")
            :gsub("%-%- @VISIBILITY@", "return {}")
            :gsub("%-%- @RADIAL@", "return TEST_RADIAL")
        setfenv(assert(loadstring(glue)), env)()
        f.env, f.binding = env, binding
        f.state = env.HD2StratagemHotkeys
        function f:step(dt)
            self.now = self.now + (dt or 0.02)
            equal(env.update(), "previous-update", "recovery preserves chained update")
        end
        function f:open()
            self.held[binding.start_vk], self.active = true, true
            self:step()
            equal(self.instances[#self.instances].opened, true)
        end
        function f:fresh_open()
            self.held[binding.start_vk], self.active = false, false
            self:step()
            self:open()
        end
        f:step(0)
        return f
    end
    for _, mode in ipairs({"hold", "toggle"}) do
        for _, vk in ipairs({164, 5, 6}) do
            local f = fixture(mode, vk)
            f:open()
            f.faults.draw = true; f:step()
            equal(f.state.radial_failed, true, "temporary draw error starts recovery")
            equal(f.instances[1].disposed, true, "failed GUI is disposed")
            equal(f.instances[1].mouse, nil, "cursor released on failure")
            equal(f.state.pending, nil, "failed selection discarded")
            f.faults.draw = false
            if mode == "hold" and (vk == 5 or vk == 6) then
                f.held[vk] = false
            end
            f:step(0.49)
            equal(#f.instances, 1, "no GUI recreation within cooldown")
            f:step(0.02)
            equal(f.state.radial_failed, nil, "wheel failure is not permanent")
            equal(#f.instances, 2, "recovery creates a clean wheel")
            f.held[49] = true
            f:step()
            equal(f.instances[2].opened, false, "old held key or toggled menu cannot reopen")
            equal(#f.events, 0, "recovery never replays a stale selection or sends commands")
            f:fresh_open()
            equal(f.state.radial_rearm, nil, "fresh native activation rearms wheel")
            if mode == "hold" then
                f.held[vk] = false
                for _ = 1, 30 do f:step() end
                equal(#f.events, 6, "fresh selection sends exactly one command after recovery")
            end
            f.env.shutdown()
        end
    end
    local f = fixture()
    f:open(); f.faults.reader, f.faults.dispose = true, true; f:step()
    local attempts, retry = #f.instances, f.state.radial_retry_at
    f.faults.reader = false
    for _ = 1, 10 do f:step(0.02) end
    equal(f.state.radial_retry_at, retry, "cooldown prevents per-frame cleanup retries")
    for _, delay in ipairs({1, 2, 4, 4}) do
        f:step(f.state.radial_retry_at - f.now + 0.001)
        equal(f.state.radial_retry_delay, delay, "persistent errors use capped backoff")
        equal(#f.instances, attempts, "unclean GUI is never replaced")
    end
    f.faults.dispose = false; f:step(f.state.radial_retry_at - f.now + 0.001)
    equal(f.state.radial_failed, nil, "persistent cleanup error can recover later")
    f:fresh_open(); f.env.shutdown()

    f = fixture(); f:open(); f.faults.draw = true; f:step()
    f.faults.draw, f.faults.factory = false, true; f:step(0.51)
    equal(f.state.radial_failed, true, "GUI factory exceptions remain recoverable")
    equal(#f.instances, 1)
    f.faults.factory = false; f:step(1.01)
    equal(f.state.radial_failed, nil); equal(#f.instances, 2)
    f:fresh_open(); f.env.shutdown()

    f = fixture("hold", 5); f:open(); f.faults.draw = true; f:step()
    f.faults.draw = false; f:step(0.51)
    equal(f.state.radial_failed, true, "held thumb button delays input reconciliation")
    equal(#f.events, 0, "recovery never forces a physically held thumb button up")
    equal(#f.instances, 1, "unreconciled mouse input retains the old owner")
    f.held[5] = false; f:step(1.01)
    equal(f.state.radial_failed, nil); equal(f.state.mouse_release, nil)
    f:fresh_open(); f.env.shutdown()

    f = fixture(); f:open()
    f.policy.held, f.held[38], f.state.owned_start = 38, true, 164
    f.policy.job = {request = {kind = 1}}
    f.state.pending = {kind = 1}; f.state.open_pending = {}
    f.faults.reader, f.faults["direction-release"] = true, true
    f:step()
    equal(f.instances[1].disposed, true, "direction release exception cannot skip GUI disposal")
    equal(f.held[164], false, "direction release exception cannot skip list-key release")
    equal(f.state.pending, nil); equal(f.state.open_pending, nil)
    equal(f.policy.job, nil, "partial command is never resumed after recovery")
    equal(f.state.blocking_inputs, true, "unreleased owned direction keeps input blocked")
    f.faults.reader, f.faults["direction-release"] = false, false
    f:step(0.51)
    equal(f.held[38], false); equal(f.policy.held, nil)
    equal(f.state.radial_failed, nil); equal(f.state.blocking_inputs, false)
    f:fresh_open(); f.env.shutdown()

    f = fixture(); f:open(); f.state.owned_start = 164
    f.faults.reader, f.faults["list-release"] = true, true; f:step()
    equal(f.state.blocking_inputs, true, "unreleased list key cannot rearm")
    f.faults.reader = false; f:step(0.51)
    equal(f.state.radial_failed, true)
    f.faults["list-release"] = false; f:step(1.01)
    equal(f.state.owned_start, nil); equal(f.state.radial_failed, nil)
    f:fresh_open(); f.env.shutdown()

    f = fixture(); f:open(); f.focused, f.faults.reader = false, true
    -- Reader is bypassed when unfocused, so simulate a cursor restoration exception.
    f.faults.cursor = true; f:step()
    f.faults.cursor, f.faults.reader = false, false; f:step(0.51)
    equal(f.state.radial_failed, true, "focus loss defers cursor ownership release")
    equal(#f.instances, 1, "deferred cursor must not be abandoned in a replacement")
    f.focused = true; f:step(1.01)
    equal(f.instances[1].mouse, nil); equal(f.state.radial_failed, nil)
    f:fresh_open(); f.env.shutdown()

    f = fixture(); f:open(); f.faults.draw, f.faults.clock = true, true; f:step()
    local count = #f.logs
    for _ = 1, 5 do f:step() end
    equal(#f.logs, count, "clock exceptions do not flood recovery logs or reset cooldown")
    f.faults.draw, f.faults.clock = false, false; f:step(0.51)
    equal(f.state.radial_failed, nil); f:fresh_open(); f.env.shutdown()

    f = fixture("hold", 5); f:open()
    local owner, stranger = {}, {}
    f.policy.held, f.held[38], f.state.owned_start = 38, true, 164
    f.policy.job = {request = {kind = 1}}
    f.faults["direction-release"] = true
    equal(f.state.suspend_input(owner), false, "handoff waits for direction release")
    equal(f.instances[1].opened, false, "failed direction release still closes overlay")
    equal(f.instances[1].mouse, nil, "failed direction release still restores cursor")
    equal(f.state.pending, nil, "handoff cancels selections")
    equal(f.state.suspend_input(stranger), false, "handoff owner is exclusive")
    f.faults["direction-release"] = false
    equal(f.state.suspend_input(owner), true, "handoff retries and acknowledges direction up")
    equal(f.policy.held, nil)
    local sends = #f.events
    f:step(); f:step()
    equal(#f.events, sends, "held thumb is not forcibly released during suspension")
    equal(f.instances[1].opened, false, "suspended wheel cannot reopen")
    equal(f.state.resume_input(owner), true)
    f:step()
    equal(f.instances[1].opened, false, "resume does not select stale sector")
    f.held[5], f.active = false, false; f:step()
    equal(f.state.remote_rearm, nil, "physical release rearms wheel")
    f:open(); f.env.shutdown()

    local deleted, destroyed, cursor = {}, {}, {show = true, focus = false}
    local fail_shape, fail_font = true, true
    local function destroy_shape(_, id)
        if id == 2 and fail_shape then fail_shape = false; error("temporary-shape-delete") end
        equal(deleted[id], nil, "successful shape deletion is never repeated")
        deleted[id] = true
    end
    local sr = {Application = {worlds = function() return {7} end},
        Gui = {destroy_text = destroy_shape, destroy_triangle = destroy_shape, destroy_bitmap = destroy_shape},
        World = {destroy_gui = function(world, gui)
            equal(world, 7)
            if gui == 12 and fail_font then fail_font = false; error("temporary-font-delete") end
            equal(destroyed[gui], nil, "successful child GUI deletion is never repeated")
            destroyed[gui] = true
        end}, Window = {set_show_cursor = function(value) cursor.show = value end,
            set_mouse_focus = function(value) cursor.focus = value end}}
    local radial = Radial.new(sr, {foreground = function() return true end, center_cursor = function() end})
    radial.gui, radial.world, radial.opened = 10, 7, true
    radial.mouse = {show = false, focus = true}
    radial.ids = {{"text", 1, 12}, {"triangle", 2}, {"text", 3}}
    radial.icons = {{gui = 11, id = 20}}; radial.fonts = {{gui = 12}}
    equal(pcall(radial.dispose, radial), false, "partial shape cleanup retains ownership")
    equal(deleted[3], true); equal(#radial.ids, 2)
    equal(radial.icons[1].gui, 11); equal(radial.fonts[1].gui, 12)
    equal(cursor.show, false); equal(cursor.focus, true)
    equal(pcall(radial.dispose, radial), false, "partial child cleanup remains retryable")
    equal(destroyed[11], true); equal(radial.icons[1].gui, nil)
    equal(radial.fonts[1].gui, 12)
    equal(pcall(radial.dispose, radial), true)
    for _, id in ipairs({1, 2, 3, 20}) do equal(deleted[id], true) end
    for _, gui in ipairs({10, 11, 12}) do equal(destroyed[gui], true) end
    equal(radial.gui, nil); equal(radial.world, nil)
end
