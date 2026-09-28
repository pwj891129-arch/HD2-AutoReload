-- HD2-Addon: mods/hd2_helper/auto_reload
local VERSION = "0.3.7-test"
local Policy = (function()
-- @POLICY@
end)()
local Native = (function()
-- @NATIVE@
end)()
local TankProbe = (function()
-- @TANK_PROBE@
end)()
local Reader = {}
Reader.__index = Reader

local function boolean(value)
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    return nil
end

local function valid_count(value)
    return type(value) == "number" and value == value and value >= 0 and
        value < math.huge and value == math.floor(value)
end

function Reader.new(parts, fragment)
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
        provider = parts.Provider.new(generated) }, Reader)
end

function Reader:sample(session, world, peer)
    local resolved = self.identity:resolve(session, world, peer)
    if not resolved or not resolved.avatar or resolved.status ~= "resolved" then
        return { active = false, avatar = resolved and resolved.avatar and resolved.avatar.goid,
            grip = resolved and resolved.grip },
            resolved and resolved.reason or "no-avatar"
    end
    local in_control = boolean(self.identity:in_control(session, resolved.avatar))
    local rotation_free = boolean(self.identity:rotation_free(session, resolved.avatar))
    if in_control ~= true or rotation_free ~= true then
        return { active = false, avatar = resolved.avatar.goid, grip = resolved.grip,
            in_control = in_control, rotation_free = rotation_free }, "no-player-control"
    end
    local hand = resolved.hand_weapon
    if not hand then return { active = true }, "no-held-weapon" end
    local spec = self.generated.identity.equipment[hand.type]
    local resource = spec and spec.resource or ""
    if not string.find(resource, "/equipment/primary_weapons/", 1, true) and
        not string.find(resource, "/equipment/sidearm_weapons/", 1, true) and
        not string.find(resource, "/equipment/support_weapons/", 1, true) then
        return { active = false }, "unsupported-held-item"
    end
    if resolved.underbarrel and resolved.underbarrel.goid == hand.goid then
        return { active = false }, "underbarrel-not-supported"
    end
    local cells = self.provider:provide(resolved, session).cells
    local declared = self.provider:declared_of(hand.type) or ""
    local heat_base = self.generated.authored_base["WeaponHeatComponentData.overheat_temperature"] or {}
    local heat = heat_base[hand.type] ~= nil or
        string.find(declared, "0xa5023836", 1, true) ~= nil or cells.heat_shown ~= nil
    local reserve = cells.reserve
    if spec.spare_pack then
        local pack = resolved.backpack
        reserve = pack and spec.spare_pack[pack.type] and cells.pack_spare or nil
    end
    local weapon = tostring(hand.goid) .. ":" .. tostring(hand.type)
    if heat then
        local overheated = boolean(cells.overheated)
        return { active = true, mode = "heat", weapon = weapon,
            overheated = overheated, reserve = reserve,
            heat_shown = cells.heat_shown, heat_max = cells.heat_max,
            reloading = boolean(cells.reloading), avatar = resolved.avatar.goid },
            overheated == nil and "overheat-unavailable" or "ready"
    end
    local ammo = cells.ammo
    if string.find(declared, "0x4a893e74", 1, true) and
        boolean(cells.raw_chamber) == nil then ammo = nil end
    if string.find(declared, "0xe525fa9c", 1, true) then
        if not valid_count(cells.raw_slot0) or not valid_count(cells.raw_slot1) or
            (cells.raw_selected ~= 0 and cells.raw_selected ~= 1) then
            ammo = nil
        else
            local icons = spec.ammo_icon
            -- Identical feeds (e.g. Punisher) still have usable ammo in the other tube.
            if icons and icons["0"] and icons["0"] == icons["1"] and ammo ~= nil then
                ammo = ammo + (cells.raw_selected == 0 and cells.raw_slot1 or cells.raw_slot0)
            end
        end
    end
    if not valid_count(ammo) then ammo = nil end
    return { active = true, mode = "ammo", weapon = weapon,
        ammo = ammo, reserve = reserve, reloading = boolean(cells.reloading),
        avatar = resolved.avatar.goid }, ammo == nil and "ammo-unavailable" or "ready"
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
    return { Policy = Policy, Reader = Reader, Native = Native, boolean = boolean,
        TankProbe = TankProbe, recover_identity = recover_identity,
        install_hooks = install_hooks }
end
if rawget(_G, "HD2HelperAutoReload") then return end

local parts = (function()
-- @READER_CORE@
end)()
local fragment = (function()
-- @NUMBERS@
end)()
local ok, reader = pcall(Reader.new, parts, fragment)
local loader = rawget(_G, "CowboyBingusModLoader")
local log_ok, log_file = pcall(function()
    return loader and loader.open_log and loader.open_log("hd2_helper_auto_reload.log")
end)
if not log_ok then log_file = nil end
local function log(line)
    if log_file then pcall(function() log_file:write(tostring(line), "\n"); log_file:flush() end) end
end
if not ok then log("DISABLED reader initialization: " .. tostring(reader)); return end

local config = { fire_vk = 1, reload_vk = 82, pause_vk = 119, enabled = true }
local appdata = os.getenv("APPDATA")
local config_path = appdata and (appdata .. "\\HD2AutoReload.ini")
if config_path then
    local file = io.open(config_path, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("^%s*([%w_]+)%s*=%s*([^;]+)")
            if key == "enabled" then config.enabled = value:match("^%s*true%s*$") ~= nil
            elseif key and key:match("_vk$") and config[key] ~= nil then
                local number = tonumber(value)
                if number and number >= 1 and number <= 254 and number == math.floor(number) then
                    config[key] = number
                end
            end
        end
        file:close()
    else
        file = io.open(config_path, "w")
        if file then
            file:write("; Windows virtual-key codes. F8 pauses/resumes.\n",
                "enabled=true\nfire_vk=1\nreload_vk=82\npause_vk=119\n")
            file:close()
        end
    end
end
if config.reload_vk <= 6 or config.reload_vk == config.fire_vk or
    config.reload_vk == config.pause_vk then
    log("DISABLED conflicting/unsupported reload key"); return
end
local ffi_ok, ffi = pcall(require, "ffi")
if not ffi_ok then log("DISABLED LuaJIT FFI unavailable"); return end
local native_ok, native = pcall(Native.create, ffi, config)
if not native_ok then log("DISABLED input initialization: " .. tostring(native)); return end

local sr = rawget(_G, "stingray") or {}
local Net, GS, App = sr.Network or {}, sr.GameSession or {}, sr.Application or {}
if type(App.time_since_launch) ~= "function" then log("DISABLED monotonic clock unavailable"); return end
local policy, state = Policy.new(), { paused = not config.enabled, keys = {} }
local tank_probe = TankProbe.new(GS)
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
        " mode=" .. tostring(sample and sample.mode)
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
    local keys = { enter = down(13), escape = down(27), tab = down(9), pause = down(config.pause_vk) }
    if focused then
        if keys.pause and not state.keys.pause then
            state.paused = not state.paused
            log(state.paused and "PAUSED" or "RESUMED")
        end
        -- Keep chat blocked until its close/send key; control gates also guard mouse-opened menus.
        if keys.enter and not state.keys.enter then state.chat = not state.chat end
        if keys.escape and not state.keys.escape then state.chat = false end
    end
    state.keys = keys
    local fire = focused and down(config.fire_vk)
    local aim = focused and down(2)
    local aim_edge = aim and not state.aim
    state.aim = aim
    if aim_edge then state.aim_pending = true end
    if fire and not state.fire then state.fire_pending = true end
    state.fire = fire
    if not focused or state.paused or state.failed or state.chat or keys.enter or keys.escape or keys.tab then
        policy:reset(); state.fire_pending, state.aim_pending = nil, nil; release(); return
    end
    if state.next_read and now < state.next_read then return end
    state.next_read = now + 0.02
    local session, world, peer = scope()
    if not session then
        policy:reset(); reader.identity:invalidate(); state.avatar = nil
        state.avatar_missing, state.unresolved_since, state.next_recovery = nil, nil, nil
        if state.context then
            tank_probe:reset(); state.context = nil; state.seat_aim_lines = nil
        end
        state.fire_pending = nil; status("no-session"); return
    end
    local context = tostring(session) .. ":" .. tostring(world) .. ":" .. tostring(peer)
    if state.context ~= context then
        policy:reset(); reader.identity:invalidate(); state.context = context; state.avatar = nil
        state.avatar_missing, state.unresolved_since, state.next_recovery = nil, nil, nil
        tank_probe:reset(); state.seat_aim_lines = nil
    end
    local sample, reason = reader:sample(session, world, peer)
    local seat_mod = rawget(_G, "Hd2TankSeatSwitch")
    local seat_hint = type(seat_mod) == "table" and seat_mod.last or nil
    if type(seat_hint) ~= "string" or seat_hint:sub(1, 5) ~= "seat:" then
        seat_hint = nil
    end
    local control_blocked = reason == "no-player-control" or
        (type(reason) == "string" and reason:find("^avatar%-not%-in%-control"))
    local unknown_grip70 = sample.grip == 70 and type(reason) == "string" and
        reason:find("^no%-on%-body%-object%-of%-grip=70")
    local aim_event = state.aim_pending == true
    state.aim_pending = nil
    if unknown_grip70 and (aim_event or state.fire_pending) then
        tank_probe:reset()
        state.probe_until = now + 20
    end
    if aim_event and control_blocked and (state.seat_aim_lines or 0) < 20 then
        state.seat_aim_lines = (state.seat_aim_lines or 0) + 1
        log("SEAT_AIM seat_hint=" .. tostring(seat_hint or "unconfirmed") ..
            " reason=" .. tostring(reason) ..
            " grip=" .. tostring(sample.grip) ..
            " control=" .. tostring(sample.in_control) ..
            " rotation=" .. tostring(sample.rotation_free))
    end
    if control_blocked or (unknown_grip70 and state.probe_until and
        now <= state.probe_until) then
        local probe_ok, probe_line = pcall(tank_probe.read, tank_probe,
            session, peer, now, seat_hint or
                (unknown_grip70 and "unconfirmed-grip70" or "unconfirmed"))
        if probe_ok and probe_line then log(probe_line) end
    end
    if recover_identity(reader.identity, state, sample, reason, now) then
        local raw_owned = reader.identity.counters and reader.identity.counters.owned_seen
        log("IDENTITY_RECOVERY reason=" .. tostring(reason) ..
            " raw_owned=" .. tostring(raw_owned))
        policy:reset(); state.fire_pending = nil; status("identity-recovery", sample); return
    end
    sample.fire = fire or state.fire_pending == true
    sample.manual_reload = down(config.reload_vk) or state.release_at ~= nil
    state.fire_pending = nil
    status(reason, sample)
    local trigger = policy:step(sample, now)
    if trigger and not state.release_at and foreground() then
        native.input[0].value.key.flags = native.flags
        if native.user32.SendInput(1, native.input, native.size) == 1 then
            state.release_at = now + 0.04
            policy:sent(now)
            log("RELOAD " .. trigger .. " " .. tostring(sample.weapon))
        else
            log("INPUT_FAILED " .. trigger)
            policy:sent(now)
        end
    end
end
local function guarded_tick()
    local success, failure = pcall(tick)
    if not success then
        pcall(release); policy:reset(); state.failed = true
        log("DISABLED runtime error: " .. tostring(failure))
    end
end
if not install_hooks(_G, guarded_tick, function() pcall(release) end) then
    log("DISABLED update callback unavailable"); rawset(_G, "HD2HelperAutoReload", nil); return
end
log("START " .. VERSION .. " fire_vk=" .. config.fire_vk .. " reload_vk=" .. config.reload_vk)
