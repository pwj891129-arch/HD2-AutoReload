-- HD2-Addon: mods/hd2_helper/auto_reload
local VERSION = "0.3.47-test"
local Options = (function()
-- @OPTIONS@
end)()
local Policy = (function()
-- @POLICY@
end)()
local Charge = (function()
-- @CHARGE@
end)()
local Native = (function()
-- @NATIVE@
end)()
local NativeReader = (function()
-- @NATIVE_READER@
end)()
local Reader = {}
Reader.__index = Reader

local function boolean(value)
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    return nil
end

function Reader.new(parts, fragment, native_reader)
    local generated = {}
    for key, value in pairs(parts.GeneratedCommon) do generated[key] = value end
    for _, name in ipairs({ "snapshot", "signals", "role_tables", "authored_base",
        "authored_delta", "network_fields", "relations" }) do
        generated[name] = fragment[name] or {}
    end
    local fields = {}
    for key, value in pairs(generated.snapshot) do fields[key] = value end
    generated.snapshot = fields
    for name, hash in pairs({ raw_slot0 = "0x04ec5b95", raw_slot1 = "0xe525fa9c",
        raw_selected = "0xa74ef0d5", raw_chamber = "0x4a893e74",
        reloading = "0xcd889dbc" }) do
        fields[name] = { from = hash, relation = "hand-weapon" }
    end
    return setmetatable({ generated = generated,
        identity = parts.IdentityCore.new(generated.identity),
        native = native_reader }, Reader)
end

function Reader:sample_native(resolved, session, allow_seated_fire)
    if not self.native or not resolved or not resolved.avatar then
        self.native_pending = nil
        return nil, "no-avatar"
    end
    local ok, sample, reason = pcall(self.native.sample, self.native)
    if not ok or not sample or sample.avatar ~= resolved.avatar.goid then
        if self.native.disabled then
            self.native_refusal = ok and reason or tostring(sample)
        end
        self.native_pending = nil
        return nil, not ok and "native-read-error" or
            (not sample and (reason or "native-unavailable") or "avatar-mismatch")
    end
    local in_control = boolean(self.identity:in_control(session, resolved.avatar))
    local rotation_free = boolean(self.identity:rotation_free(session, resolved.avatar))
    local seated_fire = allow_seated_fire and in_control == false and
        rotation_free == false and resolved.grip ~= 70
    if sample.vehicle ~= true and (type(resolved.grip) ~= "number" or
        resolved.grip == 0 or resolved.grip == 40) then
        self.native_pending = nil
        return nil, "unsupported-grip"
    end
    if sample.vehicle ~= true and (in_control ~= true or rotation_free ~= true) and not seated_fire then
        self.native_pending = nil
        return nil, "no-player-control", { in_control = in_control,
            rotation_free = rotation_free, held_reason = resolved.reason }
    end
    sample.seated_fire = sample.vehicle ~= true and seated_fire or false
    sample.grip = resolved.grip
    sample.slot = nil
    local empty = (sample.mode == "heat" and sample.overheated == true) or
        (sample.mode == "ammo" and sample.ammo == 0)
    if empty then
        local stamp = sample.weapon .. ":" .. sample.mode .. ":" ..
            tostring(sample.reserve) .. ":" .. tostring(sample.reloading) .. ":" ..
            tostring(sample.reload_allow_move) .. ":" .. tostring(sample.reserve_source) .. ":" ..
            tostring(sample.reserve_token)
        sample.unconfirmed = self.native_pending ~= stamp
        self.native_pending = stamp
    else
        self.native_pending = nil
    end
    return sample, reason
end

function Reader:sample(session, world, peer, allow_seated_fire)
    local resolved = self.identity:resolve(session, world, peer)
    if self.native then
        if resolved and resolved.underbarrel and resolved.hand_weapon and
            resolved.underbarrel.goid == resolved.hand_weapon.goid then
            self.native_pending = nil
            return { active = false, avatar = resolved.avatar and resolved.avatar.goid,
                grip = resolved.grip }, "underbarrel-not-supported"
        end
        local sample, native_reason, control = self:sample_native(resolved, session,
            allow_seated_fire)
        if sample then return sample, native_reason end
        local inactive = { active = false,
            avatar = resolved and resolved.avatar and resolved.avatar.goid,
            grip = resolved and resolved.grip,
            in_control = control and control.in_control,
            rotation_free = control and control.rotation_free,
            held_reason = control and control.held_reason }
        if not resolved or resolved.status ~= "resolved" then
            return inactive, resolved and resolved.reason or native_reason
        end
        return inactive, native_reason
    end
    return { active = false }, "native-unavailable"
end

local function recover_identity(identity, state, sample, reason, now)
    if type(reason) == "string" and reason:find("^no%-avatar") then
        state.avatar_missing = true
    end
    if sample.avatar then
        local changed = state.avatar_missing or
            (state.avatar ~= nil and state.avatar ~= sample.avatar)
        state.avatar = sample.avatar
        state.avatar_missing = nil
        if changed then
            identity:invalidate()
            state.unresolved_since, state.next_recovery = nil, nil
            return true
        end
    end
    local unresolved = sample.avatar and type(reason) == "string" and
        (reason:find("^no%-on%-body%-object%-of%-grip") or
            reason:find("^hand%-empty"))
    if unresolved then
        state.unresolved_since = state.unresolved_since or now
        if now - state.unresolved_since >= 0.75 and
            now >= (state.next_recovery or 0) then
            identity:invalidate()
            state.next_recovery = now + 2
            return true
        end
    else
        state.unresolved_since, state.next_recovery = nil, nil
    end
    return false
end

local function install_hooks(env, tick, stop, on_error)
    local original_update = env.update
    if type(original_update) ~= "function" then return false end
    local function own_callback(callback, where)
        local success, failure = pcall(callback)
        if not success and on_error then pcall(on_error, where, failure) end
    end
    local function after_update(...)
        own_callback(tick, "update")
        return ...
    end
    env.update = function(...)
        return after_update(original_update(...))
    end
    local original_shutdown = env.shutdown
    env.shutdown = function(...)
        own_callback(stop, "shutdown")
        if type(original_shutdown) == "function" then return original_shutdown(...) end
    end
    return true
end

if rawget(_G, "HD2_AUTO_RELOAD_TEST") then
    return { Policy = Policy, Charge = Charge, Reader = Reader, Native = Native, boolean = boolean, Options = Options,
        NativeReader = NativeReader,
        recover_identity = recover_identity,
        install_hooks = install_hooks }
end
if rawget(_G, "HD2HelperAutoReload") then return end

local parts = (function()
-- @READER_CORE@
end)()
local fragment = (function()
-- @NUMBERS@
end)()
local ok, reader = pcall(Reader.new, parts, fragment, NativeReader.new())
local loader = rawget(_G, "CowboyBingusModLoader")
local log_ok, log_file = pcall(function()
    return loader and loader.open_log and loader.open_log("hd2_helper_auto_reload.log")
end)
if not log_ok then log_file = nil end
local function log(line)
    if log_file then pcall(function() log_file:write(tostring(line), "\n"); log_file:flush() end) end
end
if not ok then log("DISABLED reader initialization: " .. tostring(reader)); return end

local sr = rawget(_G, "stingray") or {}
local Net, GS, App = sr.Network or {}, sr.GameSession or {}, sr.Application or {}
local config = Options.read(App, require)
if not config.enabled and not config.charge90 and not config.vehicle then log("DISABLED Arsenal options off"); return end
config.fire_vk, config.reload_vk, config.pause_vk = 1, 82, 119
local appdata = os.getenv("APPDATA")
local config_path = appdata and (appdata .. "\\HD2AutoReload.ini")
if config_path then
    local file = io.open(config_path, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("^%s*([%w_]+)%s*=%s*([^;]+)")
            if key and key:match("_vk$") and config[key] ~= nil then
                local number = tonumber(value)
                if number and number >= 1 and number <= 254 and number == math.floor(number) then
                    config[key] = number
                end
            end
        end
        file:close()
    end
end
if config.charge90 and config.fire_vk ~= 1 then
    config.charge90 = false
    log("CHARGE_DISABLED requires left-mouse fire binding")
end
reader.native.charge_enabled = config.charge90
if config.reload_vk <= 6 or config.reload_vk == config.fire_vk or
    config.reload_vk == config.pause_vk then
    log("DISABLED conflicting/unsupported reload key"); return
end
local ffi_ok, ffi = pcall(require, "ffi")
if not ffi_ok then log("DISABLED LuaJIT FFI unavailable"); return end
local native_ok, native = pcall(Native.create, ffi, config)
if not native_ok then log("DISABLED input initialization: " .. tostring(native)); return end

if type(App.time_since_launch) ~= "function" then log("DISABLED monotonic clock unavailable"); return end
local policy, state = Policy.new(), { paused = false, keys = {}, config = config }
local charge = Charge.new()
rawset(_G, "HD2HelperAutoReload", state)

local function down(vk) return native.user32.GetAsyncKeyState(vk) < 0 end
local function release()
    if state.release_at then
        native.input[0].value.key.flags = native.flags + 2
        local sent = native.user32.SendInput(1, native.input, native.size)
        if sent == 1 then state.release_at = nil end
    end
end
local function foreground()
    native.user32.GetWindowThreadProcessId(native.user32.GetForegroundWindow(), native.pid)
    return native.pid[0] == native.process
end
local function scope()
    local session = Net.game_session and Net.game_session()
    if not session or not GS.in_session or GS.in_session(session) ~= true then return nil end
    local world, peer = App.main_world and App.main_world(), Net.peer_id and Net.peer_id()
    if not world or peer == nil or not App.worlds then return nil end
    local worlds = App.worlds()
    if type(worlds) ~= "table" then return nil end
    for _, value in pairs(worlds) do if value == world then return session, world, peer end end
end
local function status(reason, sample)
    local label = tostring(reason) .. " weapon=" .. tostring(sample and sample.weapon) ..
        " mode=" .. tostring(sample and sample.mode) ..
        " slot=" .. tostring(sample and sample.slot) ..
        " seated_fire=" .. tostring(sample and sample.seated_fire)
        .. " vehicle=" .. tostring(sample and sample.vehicle)
    if sample and sample.mode == "heat" then
        label = label .. " overheat=" .. tostring(sample.overheated) ..
            " reserve=" .. tostring(sample.reserve) ..
            " reloading=" .. tostring(sample.reloading)
    end
    local text = label ..
        " ammo=" .. tostring(sample and sample.ammo) ..
        " heat=" .. tostring(sample and sample.heat_shown) ..
        "/" .. tostring(sample and sample.heat_max)
    if label ~= state.status then log(text); state.status = label end
end
local function tick()
    local now = App.time_since_launch()
    if type(now) ~= "number" then return end
    if state.release_at and (now >= state.release_at or not foreground()) then release() end
    local focused = foreground()
    local keys = { enter = down(13), escape = down(27), tab = down(9),
        pause = down(config.pause_vk), primary = down(49),
        sidearm = down(50), support = down(51) }
    local hotkeys = rawget(_G, "HD2StratagemHotkeys")
    keys.stratagem = down(164) or down(165) or
        (type(hotkeys) == "table" and hotkeys.blocking_inputs == true)
    local previous_keys = state.keys
    if focused then
        if keys.pause and not state.keys.pause then
            state.paused = not state.paused
            log(state.paused and "PAUSED" or "RESUMED")
        end
        -- Keep chat blocked until its close/send key; control gates also guard mouse-opened menus.
        if keys.enter and not state.keys.enter then state.chat = not state.chat end
        if keys.escape and not state.keys.escape then state.chat = false end
    end
    if focused and not state.paused and not state.chat and not keys.stratagem and
        not keys.enter and not keys.escape and not keys.tab then
        for _, slot in ipairs({ "primary", "sidearm", "support" }) do
            if keys[slot] and not previous_keys[slot] then
                state.switch = { slot = slot, from_weapon = state.last_weapon,
                    ready_at = now + 1.1,
                    until_time = now + 2.2 }
                log("SWITCH_KEY slot=" .. slot)
            end
        end
    end
    state.keys = keys
    local fire = focused and down(config.fire_vk)
    local aim = focused and down(2)
    if fire and not state.fire then
        state.fire_pending, state.fire_released_at = true, nil
        state.fire_cycle, state.fire_release_pending, state.fire_attempt = true, nil, nil
    elseif not fire and state.fire and
        (state.fire_cycle or state.fire_attempt or state.fire_pending) then
        state.fire_cycle, state.fire_release_pending = nil, true
        state.fire_released_at = now
        if state.fire_attempt then state.fire_attempt.until_time = now + 1.0 end
    end
    state.fire = fire
    if aim and fire then state.lean_fire_until = now + 0.8 end
    if not focused or state.paused or state.failed or state.chat or keys.stratagem or keys.enter or keys.escape or keys.tab then
        policy:reset(); charge:reset(); state.fire_pending = nil
        state.fire_attempt, state.fire_released_at = nil, nil
        state.fire_cycle, state.fire_release_pending = nil, nil
        reader.native_pending = nil
        state.switch, state.lean_fire_until = nil, nil
        release(); return
    end
    if state.next_read and now < state.next_read and
        not state.fire_pending and not state.fire_release_pending then return end
    state.next_read = now + 0.05
    local session, world, peer = scope()
    if not session then
        policy:reset(); charge:reset(); reader.identity:invalidate(); state.avatar = nil
        reader.native_pending = nil
        state.last_weapon = nil
        state.last_weapon_at = nil
        state.avatar_missing, state.unresolved_since, state.next_recovery = nil, nil, nil
        state.context = nil
        state.fire_pending, state.switch, state.lean_fire_until = nil, nil, nil
        state.fire_attempt, state.fire_released_at = nil, nil
        state.fire_cycle, state.fire_release_pending = nil, nil
        status("no-session"); return
    end
    local context = tostring(session) .. ":" .. tostring(world) .. ":" .. tostring(peer)
    if state.context ~= context then
        policy:reset(); charge:reset(); reader.identity:invalidate(); state.context = context; state.avatar = nil
        reader.native_pending = nil
        state.last_weapon = nil
        state.last_weapon_at = nil
        state.avatar_missing, state.unresolved_since, state.next_recovery = nil, nil, nil
        state.switch, state.lean_fire_until = nil, nil
        state.fire_attempt, state.fire_released_at = nil, nil
        state.fire_cycle, state.fire_release_pending = nil, nil
    end
    local allow_seated_fire = aim and state.lean_fire_until and
        now <= state.lean_fire_until
    local sample, reason = reader:sample(session, world, peer, allow_seated_fire)
    if reader.native_refusal and not state.native_refusal_logged then
        log("NATIVE_READER unavailable=" .. reader.native_refusal)
        state.native_refusal_logged = true
    end
    if sample.native and sample.weapon then
        local source = sample.weapon .. ":" .. tostring(sample.feed) .. ":" ..
            tostring(sample.reload_allow_move) .. ":" .. tostring(sample.reload_reason) .. ":" ..
            tostring(sample.reserve_token) .. ":" .. tostring(sample.backpack_reason)
        if state.native_source ~= source then
            log("NATIVE_SOURCE weapon=" .. sample.weapon ..
                " feed=" .. tostring(sample.feed) ..
                " grip=" .. tostring(sample.grip) ..
                " ammo=" .. tostring(sample.ammo) ..
                " overheat=" .. tostring(sample.overheated) ..
                " reserve=" .. tostring(sample.reserve))
            log("RELOAD_MOVEMENT allow=" .. tostring(sample.reload_allow_move) ..
                " source=" .. tostring(sample.reload_source) ..
                " reason=" .. tostring(sample.reload_reason))
            if sample.backpack_reason then
                log("BACKPACK_RESERVE source=" .. tostring(sample.reserve_source) ..
                    " token=" .. tostring(sample.reserve_token) .. " ammo=" .. tostring(sample.backpack_ammo) ..
                    " required=" .. tostring(sample.backpack_required) .. " reason=" .. sample.backpack_reason)
            end
            state.native_source = source
        end
    else
        state.native_source = nil
    end
    if sample.active and sample.weapon then
        state.last_weapon, state.last_weapon_at = sample.weapon, now
    end
    if (state.fire_pending or state.fire_release_pending) and
        state.last_weapon and state.last_weapon_at and
        now - state.last_weapon_at <= 0.25 then
        state.fire_attempt = { weapon = state.last_weapon,
            until_time = not fire and (state.fire_released_at or now) + 1.0 or nil }
    end

    if recover_identity(reader.identity, state, sample, reason, now) then
        local raw_owned = reader.identity.counters and reader.identity.counters.owned_seen
        log("IDENTITY_RECOVERY reason=" .. tostring(reason) ..
            " raw_owned=" .. tostring(raw_owned))
        policy:reset(); charge:reset(); state.fire_pending, state.fire_attempt = nil, nil
        state.fire_released_at = nil
        state.fire_cycle, state.fire_release_pending = nil, nil
        status("identity-recovery", sample); return
    end
    local attempt = state.fire_attempt
    if attempt and ((attempt.until_time and now > attempt.until_time) or
        (sample.active and sample.weapon ~= attempt.weapon)) then
        state.fire_attempt, attempt = nil, nil
    end
    if sample.mode == "ammo" and sample.reloading == true then
        state.fire_attempt, attempt = nil, nil
        state.fire_cycle = nil
    end
    sample.fire_held, sample.fire_pressed = fire, state.fire_pending == true
    sample.fire_released = not fire and attempt ~= nil and
        attempt.until_time ~= nil and sample.weapon == attempt.weapon
    sample.fire = sample.fire_pressed or sample.fire_released
    sample.manual_reload = down(config.reload_vk) or state.release_at ~= nil
    if sample.manual_reload then state.fire_attempt, state.fire_cycle = nil, nil end
    state.fire_pending, state.fire_release_pending = nil, nil
    local switching = state.switch
    if switching and now > switching.until_time then
        state.switch = nil
        switching = nil
    end
    if switching and sample.active then
        local switched = sample.native and switching.from_weapon ~= nil and
            sample.weapon ~= switching.from_weapon or sample.slot == switching.slot
        if now < switching.ready_at or not switched then
            sample.switch_wait = true
        else
            sample.switch_ready = true
        end
    end
    if config.charge90 then
        if sample.charge_kind then
            local label = sample.weapon .. ":" .. tostring(sample.charge_reason)
            if state.charge_status ~= label then
                log("CHARGE_SOURCE kind=" .. sample.charge_kind ..
                    " reason=" .. tostring(sample.charge_reason) ..
                    " source=" .. tostring(sample.charge_source) ..
                    " basis=" .. tostring(sample.charge_basis) ..
                    " limit=" .. tostring(sample.charge_limit) ..
                    " full=" .. tostring(sample.charge_full) ..
                    " maximum=" .. tostring(sample.charge_max))
                state.charge_status = label
            end
        else
            state.charge_status = nil
        end
        if charge:step(sample, now, fire) and foreground() and down(1) then
            local sent = native.user32.SendInput(1, native.mouse, native.size)
            log(string.format("CHARGE_RELEASE kind=%s ratio=%.3f sent=%s t=%.3f",
                sample.charge_kind, sample.charge_elapsed / sample.charge_limit,
                tostring(sent == 1), now))
            if sent == 1 then
                state.fire, state.fire_cycle, state.fire_release_pending = false, nil, true
                state.fire_released_at = now
                state.fire_attempt = {weapon = sample.weapon, until_time = now + 1.0}
            end
        end
    end
    status(reason, sample)
    if not Options.allow(config, sample) then sample.active = false end
    local trigger, action = policy:step(sample, now)
    if trigger and action == "release-fire" and fire and not state.release_at and
        foreground() and down(config.fire_vk) then
        local sent = native.user32.SendInput(1, native.mouse, native.size)
        if sent == 1 then
            policy:released_fire(now)
            state.fire, state.fire_cycle, state.fire_pending = false, nil, nil
            state.fire_attempt, state.fire_released_at, state.fire_release_pending = nil, nil, nil
            log("RELOAD_PRESS_RELEASE weapon=" .. tostring(sample.weapon))
        else
            policy:reset()
            log("RELOAD_PRESS_RELEASE failed weapon=" .. tostring(sample.weapon))
        end
        return
    end
    if sample.switch_ready and (trigger or
        (sample.mode == "ammo" and type(sample.ammo) == "number" and sample.ammo > 0) or
        (sample.mode == "heat" and sample.overheated == false)) then
        state.switch = nil
    end
    if trigger and not fire and not state.release_at and foreground() and
        not down(config.fire_vk) then
        state.fire_attempt = nil
        native.input[0].value.key.flags = native.flags
        if native.user32.SendInput(1, native.input, native.size) == 1 then
            state.release_at = now + 0.04
            policy:sent(now)
            log(string.format("RELOAD %s %s t=%.3f fire_held=false", trigger,
                tostring(sample.weapon), now))
        else
            log("INPUT_FAILED " .. trigger)
            policy:sent(now)
        end
    end
end
local function guarded_tick()
    local success, failure = pcall(tick)
    if not success then
        pcall(release); policy:reset(); charge:reset(); state.failed = true
        log("DISABLED runtime error: " .. tostring(failure))
    end
end
if not install_hooks(_G, guarded_tick, function() pcall(release) end) then
    log("DISABLED update callback unavailable"); rawset(_G, "HD2HelperAutoReload", nil); return
end
log("START " .. VERSION .. " Arsenal-only options enabled=" .. tostring(config.enabled) ..
    " charge90=" .. tostring(config.charge90) ..
    " vehicle=" .. tostring(config.vehicle) ..
    " fire_vk=" .. config.fire_vk .. " reload_vk=" .. config.reload_vk)
