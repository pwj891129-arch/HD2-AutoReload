HD2_AUTO_RELOAD_TEST = true
local api = dofile("dist/auto_reload.generated.lua")
local count = 0
local function equal(actual, expected, name)
    assert(actual == expected, (name or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    count = count + 1
end
dofile("native_reader.test.lua")(api, equal)
dofile("backpack_reserve.test.lua")(api, equal)
dofile("reload_movement.test.lua")(api, equal)
dofile("charge_policy.test.lua")(api, equal)
local flags = {enabled = true, charge90 = true}
local option_app = {can_get = function(_, resource) return flags[resource:match("autoreload_setting_(.+)$")] ~= nil end}
local function load_option(resource) return flags[resource:match("autoreload_setting_(.+)$")] end
local arsenal = api.Options.read(option_app, load_option)
equal(arsenal.enabled, true, "checked automatic reload checkbox is on")
equal(arsenal.charge90, true, "checked charge release checkbox is on")
equal(arsenal.diagnostics, nil, "diagnostic setting removed")
equal(api.Options.allow(arsenal, {mode = "ammo"}), true)
equal(api.Options.allow(arsenal, {mode = "heat"}), true)
equal(api.Options.allow(arsenal, {mode = "unknown"}), false)
equal(api.Options.allow(arsenal, nil), false)
flags.enabled = false
arsenal = api.Options.read(option_app, load_option)
equal(arsenal.enabled, false, "explicit OFF setting is honored")
equal(api.Options.allow(arsenal, {mode = "ammo"}), false)
equal(api.Options.allow(arsenal, {mode = "heat"}), false)
flags.charge90 = true
arsenal = api.Options.read(option_app, load_option)
equal(arsenal.charge90, true, "charge release can run independently")
equal(arsenal.enabled, false)
flags.enabled, flags.charge90 = true, false
arsenal = api.Options.read(option_app, load_option)
equal(arsenal.enabled, true, "explicit ON setting")
equal(arsenal.charge90, false, "explicit charge OFF setting")
flags.enabled = "true"
equal(api.Options.read(option_app, load_option).enabled, false, "invalid option payload fails closed")
equal(api.Options.read({can_get = function() error("unavailable") end}, load_option).enabled, false,
    "option API errors fail closed")
equal(api.Options.read({can_get = function() return true end}, function() error("unavailable") end).enabled,
    false, "option loading errors fail closed")
equal(api.Options.read({}, load_option).enabled, false, "no option API cannot enable a checkbox")
equal(api.Options.read({}, load_option).charge90, false, "no option API cannot enable charge release")
equal(api.Options.read({can_get = function() error("unavailable") end}, load_option).charge90,
    false, "charge option API errors fail closed")
equal(api.Options.read({can_get = function() return true end}, function() error("unavailable") end).charge90,
    false, "charge option loading errors fail closed")
flags.charge90 = "true"
equal(api.Options.read(option_app, load_option).charge90, false, "invalid charge option is not enabled")
local obsolete = {can_get = function(_, resource)
    return resource == "mods/hd2_helper/autoreload_option_ammo_off" or
        resource == "mods/hd2_helper/autoreload_option_heat_off" or
        resource == "mods/hd2_helper/autoreload_option_diagnostics"
end}
local defaults = api.Options.read(obsolete, function() error("obsolete flag must not load") end)
equal(defaults.enabled, false, "obsolete flags cannot enable an unchecked checkbox")
equal(defaults.charge90, false, "old diagnostic flags cannot enable charge release")
local unchecked = api.Options.read({can_get = function() return false end}, load_option)
equal(unchecked.enabled, false, "missing reload marker means unchecked/OFF")
equal(unchecked.charge90, false, "missing charge marker means unchecked/OFF")
equal(api.Options.allow(unchecked, {mode = "ammo"}), false)
equal(api.Options.allow(unchecked, {mode = "heat"}), false)
-- Research modules are tested offline only; none is embedded in the addon.
for name, file in pairs({TankProbe = "tank_probe.lua", SelfProbe = "self_probe.lua",
    CatalogProbe = "catalog_probe.lua", UnitLinkProbe = "unit_link_probe.lua",
    HashTypeProbe = "hash_type_probe.lua"}) do
    equal(api[name], nil, "research module absent from packaged API")
    api[name] = dofile(file)
end
local function sample(weapon, ammo, fire)
    return { active = true, mode = "ammo", weapon = weapon, ammo = ammo, reserve = 5,
        reloading = false, fire = fire or false }
end
local function heat_sample(weapon, overheated, fire)
    return { active = true, mode = "heat", weapon = weapon,
        overheated = overheated, ammo = 0, reserve = 2,
        reloading = false, fire = fire or false }
end
local raw_tank = { [1] = 0, [2] = 30, [3] = false, [4] = 99,
    [5] = 0.5, [6] = { [1] = 1, [2] = 0 } }
local probe = api.TankProbe.new({
    objects_owned_by = function() return { 32, 31 } end,
    game_object_field_batched = function(_, goid)
        if goid == 31 then return raw_tank end
        return { [1] = true }
    end,
})
local probe_line = probe:read(1, 2, 0, "seat:bastion:1")
equal(probe_line:find("seat_hint=bastion", 1, true) ~= nil, false, "seat hint preserved")
equal(probe_line:find("seat_hint=seat:bastion:1", 1, true) ~= nil, true)
equal(probe_line:find("31[1=0,2=30,3=false,6.1=1,6.2=0]", 1, true) ~= nil, true,
    "bounded tank numeric fields")
equal(probe_line:find("4=99", 1, true) == nil, true, "unrelated large value omitted")
equal(probe:read(1, 2, 0.5, "seat:bastion:1"), nil, "probe throttled")
equal(probe:read(1, 2, 1.1, "seat:bastion:1"), nil, "unchanged fields not logged")
equal(probe:read(1, 2, 2.2, "seat:bastion:2"):find(
    "seat_hint=seat:bastion:2", 1, true) ~= nil, true, "seat hint change logged")
raw_tank[2] = 29
equal(probe:read(1, 2, 3.3, "seat:bastion:2"):find("2=29", 1, true) ~= nil,
    true, "changed tank reserve logged")
probe:reset()
equal(probe:read(1, 2, 3.4, "seat:bastion:2") ~= nil, true,
    "new session probe resets timing and fingerprint")
local pages_seen = {}
probe = api.TankProbe.new({
    objects_owned_by = function()
        local owned = {}
        for i = 1, 25 do owned[i] = i end
        return owned
    end,
    game_object_field_batched = function(_, goid) return { [1] = goid % 10 } end,
})
for i = 0, 2 do
    local line = probe:read(1, 2, i * 0.25, "seat:bastion:1")
    equal(line:find("page=" .. tostring(i + 1) .. "/3", 1, true) ~= nil,
        true, "tank probe visits each bounded page")
    pages_seen[i + 1] = line
end
equal(probe:read(1, 2, 0.75, "seat:bastion:1"), nil,
    "unchanged tank page is not logged again")
equal(pages_seen[1]:find("13[", 1, true) == nil, true,
    "first page stays within 12 objects")
equal(pages_seen[2]:find("13[", 1, true) ~= nil, true,
    "second page reaches later objects")
probe = api.TankProbe.new({})
equal(probe:read(1, 2, 0), "TANK_PROBE unavailable", "no unsupported field calls")
local own_raw = { [1] = 4, [2] = false, [3] = { [2] = 2 } }
local self_probe = api.SelfProbe.new({
    objects_owned_by = function() return { 18 } end,
    game_object_field_batched = function() return own_raw end,
    game_object_field = function(_, _, name)
        if name == "4fqtox" then return own_raw[1] end
    end,
})
local baseline_lines = self_probe:read(1, 2, 0, false, false)
equal(#baseline_lines, 1, "independent probe establishes a baseline")
equal(baseline_lines[1]:find("SELF_BASELINE", 1, true) ~= nil, true)
own_raw[1] = 3
local own_lines = self_probe:read(1, 2, 0.1, true, false, "primary")
equal(#own_lines, 2, "fire edge and changed object logged")
equal(own_lines[2]:find("goid=18 fields=1:4>3", 1, true) ~= nil, true,
    "own-object ammo change is correlated with fire")
equal(own_lines[2]:find("direct=rounds=3", 1, true) ~= nil, true,
    "independent direct field read labels a candidate")
equal(#self_probe:read(1, 2, 0.12, true, false), 0,
    "independent probe is rate limited")
own_raw[2], own_raw[3][2] = true, 1
own_lines = self_probe:read(1, 2, 0.2, false, true, "primary")
equal(own_lines[2]:find("2:false>true", 1, true) ~= nil, true,
    "boolean transitions are logged")
equal(own_lines[2]:find("3.2:2>1", 1, true) ~= nil, true,
    "nested reserve candidates are logged")
equal(#self_probe:read(1, 2, 0.3, false, true), 0,
    "held reload key does not create another input edge")
own_raw[2] = 1
equal(#self_probe:read(1, 2, 0.4, false, false), 1,
    "field type changes remain diagnostic-only")
self_probe.lines = 600
equal(#self_probe:read(1, 2, 0.5, true, false), 0,
    "bounded probe stops collecting after the session log limit")
self_probe:reset()
equal(#self_probe:read(1, 2, 0.6, false, false), 1,
    "reset discards previous session fields")
equal(#self_probe:read(1, 2, 0.7, false, false), 0,
    "idle probe scans without extra log entries")
equal(self_probe.next_scan >= 1.0, true,
    "idle probe backs off after the baseline")
local catalog = api.CatalogProbe.new({
    game_object_is_type = function(_, goid, kind)
        return goid == 18 and kind == "id:2df95dfe"
    end,
    game_object_field = function(_, _, kind)
        if kind == "id:d7a5d63e" or kind == "4fqtox" then return 7 end
    end,
    unit_synchronizer = function() return "sync" end,
}, { object_info = function(kind) return kind == "id:2df95dfe" and {} end },
    { from_hex = function(hex) return "id:" .. hex end },
    { game_object_id_to_unit = function(sync, goid)
        if sync == "sync" and goid == 18 then return "unit" end
    end }, { debug_name = function(unit)
        if unit == "unit" then return "0x12345678" end
    end })
local catalog_line = catalog:read(1, { goid = 18, type_hash = "0x2df95dfe" })
equal(catalog_line:find("type_hex=true", 1, true) ~= nil, true,
    "catalog checks a known type hash")
equal(catalog_line:find("info_hex=table", 1, true) ~= nil, true,
    "catalog checks network metadata")
equal(catalog_line:find("field_hex=7 field_string=7", 1, true) ~= nil, true,
    "catalog compares hashed and string field access")
equal(catalog_line:find("unit_link=string:string:0x12345678", 1, true) ~= nil, true,
    "catalog checks unit mapping")
equal(catalog:read(1, { goid = 18, type_hash = "0x2df95dfe" }), nil,
    "catalog probe logs once per session")
catalog:reset()
equal(catalog:read(1, { goid = 18, type_hash = "0x2df95dfe" }) ~= nil,
    true, "catalog probe resets with session")
local no_catalog = api.CatalogProbe.new({}, {}, {}, {}, {})
equal(no_catalog:read(1, { goid = 18, type_hash = "0x2df95dfe" }),
    "CATALOG_API id32=unavailable", "missing API cannot authorize input")
equal(api.CatalogProbe.new({}, {}, {}, {}, {}):read(1, {}), nil,
    "unresolved weapon is never guessed")
local unit_link = api.UnitLinkProbe.new({ unit_synchronizer = function() return "sync" end },
    { game_object_id_to_unit = function(sync, goid)
        if sync == "sync" and goid == 18 then return "unit" end
    end, unit_to_game_object_id = function() return 18 end },
    { alive = function() return true end,
        debug_name = function() return "known-weapon" end })
equal(unit_link:read(1, { active = true, slot = "sidearm", goid = 18 })
    :find("result=unit roundtrip=true name=known-weapon", 1, true) ~= nil,
    true, "known held weapon can validate a unit link")
equal(unit_link:read(1, { active = true, slot = "sidearm", goid = 18 }), nil,
    "unit link is checked only once per session")
unit_link:reset()
equal(unit_link:read(1, { active = true, slot = "sidearm", goid = 18 }) ~= nil,
    true, "unit link probe resets with session")
equal(api.UnitLinkProbe.new({}, {}, {}):read(1,
    { active = true, slot = "primary", goid = 18 }),
    "UNIT_LINK known_goid=18 slot=primary result=api-unavailable",
    "missing engine API is diagnostic only")
equal(api.UnitLinkProbe.new({}, {}, {}):read(1,
    { active = false, slot = "primary", goid = 18 }), nil,
    "unresolved weapon never triggers the unit-link API")
local hash_calls = 0
local hash_probe = api.HashTypeProbe.new({ game_object_is_type = function(_, goid, kind)
    hash_calls = hash_calls + 1
    return goid == 18 and (kind == "known-call" or kind == "id:2df95dfe")
end }, { from_hex = function(hex) return "id:" .. hex end })
equal(hash_probe:read(1, { active = false, goid = 18 }, "known-call"),
    "HASH_TYPE skipped=no-recognized-held-weapon", "unresolved probe does no engine reads")
equal(hash_calls, 0, "unresolved probe has no engine calls")
local known_sample = { active = true, goid = 18, slot = "sidearm",
    type_hash = "0x2df95dfe" }
equal(hash_probe:read(1, known_sample, "known-call"),
    "HASH_TYPE goid=18 slot=sidearm type=0x2df95dfe baseline=true hash=true",
    "hash ID identifies a known held weapon")
equal(hash_calls, 2, "one baseline and one hashed type lookup")
equal(hash_probe:read(1, known_sample, "known-call"),
    "HASH_TYPE already-checked", "one hash lookup per session")
equal(hash_calls, 2, "repeat key does not query engine")
hash_probe:reset()
equal(hash_probe:read(1, known_sample, "known-call"):find("hash=true", 1, true) ~= nil,
    true, "new session permits one lookup")
equal(api.HashTypeProbe.new({ game_object_is_type = function() return false end },
    { from_hex = function() error("must not run") end }):read(1, known_sample,
        "known-call"):find("baseline=false hash=not-run", 1, true) ~= nil,
    true, "invalid baseline never reaches new hashed API")
local baseline_ready = false
local retry_probe = api.HashTypeProbe.new({ game_object_is_type = function()
    return baseline_ready
end }, { from_hex = function() return "hash-id" end })
equal(retry_probe:read(1, known_sample, "known-call"):find(
    "hash=not-run", 1, true) ~= nil, true, "premature F9 skips hash lookup")
baseline_ready = true
equal(retry_probe:read(1, known_sample, "known-call"):find(
    "hash=true", 1, true) ~= nil, true, "baseline failure permits retry")
equal(api.HashTypeProbe.new({ game_object_is_type = function() return true end },
    {}):read(1, known_sample, "known-call"):find("hash=api-unavailable", 1, true) ~= nil,
    true, "missing hash constructor remains diagnostic")
local discovery_reads, discovery_mode = 0, "known"
local discovery_ids = {}
for i = 1, 25 do discovery_ids[i] = i end
local Discovery = dofile("weapon_discovery_probe.lua")
local discovery = Discovery.new({
    objects_owned_by = function() return discovery_ids end,
    game_object_field_batched = function(_, goid)
        discovery_reads = discovery_reads + 1
        if goid == 18 then return { [1] = discovery_mode == "known" and 1 or 0 } end
        if goid == 19 then return { [1] = discovery_mode == "known" and 0 or 1,
            [2] = { [3] = true } } end
        return { [1] = goid }
    end,
})
equal(discovery:step(1, 0), nil, "discovery is idle without F10")
equal(discovery_reads, 0, "idle discovery does no engine reads")
equal(discovery:request(1, 2, { active = false, grip = 70 },
    "no-on-body-object-of-grip=70"),
    "DISCOVERY skipped=hold-recognized-weapon-first",
    "unknown weapon cannot establish baseline")
equal(discovery:request(1, 2, known_sample, "ready"):find(
    "baseline-start owned=25", 1, true) ~= nil, true,
    "recognized weapon starts bounded baseline")
equal(discovery:step(1, 0), nil, "first page is incomplete")
equal(discovery_reads, 12, "first page reads twelve objects")
equal(discovery:step(1, 0.05), nil, "page pacing prevents a burst")
equal(discovery_reads, 12, "paced step performs no reads")
equal(discovery:step(1, 0.25), nil, "second page is incomplete")
local discovery_lines = discovery:step(1, 0.5)
equal(discovery_lines[1]:find("baseline-ready objects=25", 1, true) ~= nil,
    true, "baseline completes after every page")
equal(discovery_reads, 25, "baseline reads each owned object once")
equal(discovery:request(1, 2, known_sample, "ready"),
    "DISCOVERY skipped=hold-unrecognized-grip70-weapon-second",
    "comparison requires unknown held weapon")
discovery_mode = "unknown"
equal(discovery:request(1, 2, { active = false, grip = 70 },
    "no-on-body-object-of-grip=70 owned=25"):find(
    "compare-start owned=25", 1, true) ~= nil, true,
    "unknown grip70 starts comparison")
equal(discovery:step(1, 0.75), nil, "comparison is also paged")
equal(discovery:step(1, 1.0), nil, "comparison second page")
discovery_lines = discovery:step(1, 1.25)
equal(discovery_lines[1]:find("compare-ready", 1, true) ~= nil, true,
    "comparison completes")
local found_19 = false
for _, line in ipairs(discovery_lines) do
    if line:find("candidate goid=19 state=changed", 1, true) and
        line:find("1:0>1", 1, true) then found_19 = true end
end
equal(found_19, true, "changed unknown candidate and raw field are logged")
equal(discovery:step(1, 1.5), nil, "completed scan is one-shot")
equal(discovery_reads, 50, "comparison reads only the second snapshot")
discovery:reset()
equal(discovery:step(1, 1), nil, "context reset discards discovery state")
equal(Discovery.new({}):request(1, 2, known_sample, "ready"),
    "DISCOVERY skipped=api-unavailable", "missing APIs never enable a scan")
local many_probe = api.SelfProbe.new({
    objects_owned_by = function()
        local rows = {}
        for i = 1, 25 do rows[i] = i end
        return rows
    end,
    game_object_field_batched = function(_, goid) return { [1] = goid } end,
})
equal(#many_probe:read(1, 2, 0, false, false), 0,
    "first page alone is not a complete baseline")
equal(many_probe:read(1, 2, 0.1, false, false)[1]:find(
    "SELF_BASELINE", 1, true) ~= nil, true,
    "baseline marker waits for every owned-object page")
equal(#api.SelfProbe.new({}):read(1, 2, 0, true, false), 1,
    "unavailable game API never fabricates weapon values")
local p = api.Policy.new()
equal(p:step(sample("A", 3), 0), nil, "baseline")
equal(p:step(sample("A", 1, true), 0.1), nil, "one round remains")
equal(p:step(sample("A", 0, true), 0.2), "ammo-exhausted", "last round just fired")
p:sent(0.2)
equal(p:step(sample("A", 0, true), 0.6), nil, "held fire does not repeat")
equal(p:step(sample("A", 0, false), 0.7), nil)
equal(p:step(sample("A", 0, true), 0.8), "fire-attempt")
p:sent(0.8)
equal(p:step(sample("B", 0), 1.2), "weapon-swapped")
p:sent(1.2)
equal(p:step(sample("C", 3), 1.6), nil, "loaded swap")
equal(p:step(sample("C", 0, true), 1.7), "ammo-exhausted", "coalesce fire and exhaustion")
p:sent(1.7)
equal(p:step(sample("C", 0), 2.1), nil)
for _, ammo in ipairs({ 1, 2, 0/0, math.huge, -1 }) do
    p = api.Policy.new()
    equal(p:step(sample("A", ammo, true), 0), nil, "not known zero")
end
p = api.Policy.new()
equal(p:step(sample("A", 0), 0), nil, "initial empty is not a swap")
equal(p:step(sample("A", nil, true), 0.1), nil, "unknown is not zero")
equal(p:step(sample("A", 0, false), 0.2), "fire-attempt", "short read gap")
p:sent(0.2)
equal(p:step(sample("B", nil), 0.3), nil)
equal(p:step(sample("B", 0), 0.7), "weapon-swapped", "identity recovered during swap")
p = api.Policy.new()
p:step(sample("A", 1), 0)
local reloading = sample("A", 0)
reloading.reloading = true
equal(p:step(reloading, 0.1), nil, "already reloading")
equal(p:step(sample("A", 0), 0.5), nil, "no duplicate after reload state")
p = api.Policy.new()
p:step(sample("A", 1), 0)
reloading = sample("A", 0, true)
reloading.reloading, reloading.unconfirmed = true, true
equal(p:step(reloading, 0.1), nil, "active reload blocks unconfirmed fire attempt")
reloading.reloading, reloading.unconfirmed, reloading.fire = false, nil, false
equal(p:step(reloading, 0.2), nil, "active reload clears pending fire attempt")
p = api.Policy.new()
reloading = sample("A", 1)
reloading.reloading = true
equal(p:step(reloading, 0), nil, "loaded weapon does not reload while busy")
equal(p.empty, false, "known loaded state stays false while reloading")
equal(p:step(sample("A", 0), 0.2), "ammo-exhausted",
    "new exhaustion can be detected after reload finishes")
for _, reserve in ipairs({ 0, -1, math.huge, 0/0 }) do
    p = api.Policy.new()
    local s = sample("A", 0, true); s.reserve = reserve
    equal(p:step(s, 0), nil, "no usable reserve")
end
p = api.Policy.new()
p:step(sample("A", 1), 0)
local spareless = sample("A", 0, true); spareless.reserve = 0
equal(p:step(spareless, 0.1), nil, "exhaustion cannot reload without spare ammo")
p = api.Policy.new()
p:step(sample("A", 2), 0)
spareless = sample("B", 0); spareless.reserve = nil
equal(p:step(spareless, 0.1), nil, "swap cannot reload with unknown spare ammo")
p = api.Policy.new()
local s = sample("A", 0, true); s.reserve = nil; s.reloading = nil
equal(p:step(s, 0), nil, "unknown reload and reserve")
equal(p:step(sample("A", 0, true), 0.1), "fire-attempt", "late eligibility")
p = api.Policy.new()
p:step(s, 0)
equal(p:step(sample("A", 0, true), 0.4), nil, "expired trigger")
p = api.Policy.new()
p:step(sample("A", 2), 0)
equal(p:step({ active = false }, 0.1), nil, "menu/death resets")
equal(p:step(sample("B", 0), 0.2), nil, "no stale swap after menu")
p:reset()
s = sample("B", 0, true); s.manual_reload = true
equal(p:step(s, 0.5), nil, "manual reload not duplicated")
p = api.Policy.new()
p:step(sample("A", 2), 0)
p:step(sample("B", nil), 1)
equal(p:step(sample("B", 0), 1.1), nil, "long identity gap is not guessed")
p = api.Policy.new()
p:step(sample("A", nil, true), 0)
p:reset()
equal(p:step(sample("A", 0), 0.1), nil, "reset removes pending fire")

p = api.Policy.new()
p:step(sample("A", 2), 0)
local held_fire = sample("A", 0, true)
held_fire.fire_held, held_fire.fire_pressed = true, true
equal(p:step(held_fire, 0.1), nil, "empty press waits for fire release")
held_fire.fire_pressed = false
equal(p:step(held_fire, 2), nil, "long fire hold never requests reload")
held_fire.fire_held, held_fire.fire_released = false, true
equal(p:step(held_fire, 2.01), "fire-released", "release rereads a still-empty weapon")
p:sent(2.01)
held_fire.fire, held_fire.fire_released = false, false
equal(p:step(held_fire, 2.5), nil, "consumed release does not repeat")
p = api.Policy.new()
local release_wait = sample("A", 0, true)
release_wait.fire_released, release_wait.reserve = true, nil
equal(p:step(release_wait, 0), nil, "release waits for complete reserve data")
equal(p:step(release_wait, 0.95), nil, "release can keep waiting within its window")
release_wait.fire, release_wait.fire_released, release_wait.reserve = false, false, 2
equal(p:step(release_wait, 1.01), nil, "expired release does not send a late request")
p = api.Policy.new()
p:step(sample("A", 1), 0)
release_wait = sample("A", 0, true)
release_wait.fire_released, release_wait.reserve = true, nil
equal(p:step(release_wait, 0.95), nil, "release exhaustion waits for reserve data")
release_wait.fire, release_wait.fire_released, release_wait.reserve = false, false, 2
equal(p:step(release_wait, 1.01), nil, "release exhaustion also ends with the window")
p = api.Policy.new()
p:step(heat_sample("H", false), 0)
local held_heat = heat_sample("H", true, true)
held_heat.fire_held, held_heat.fire_pressed, held_heat.reloading = true, true, true
equal(p:step(held_heat, 0.1), nil, "overheated press waits for fire release")
held_heat.fire_pressed = false
equal(p:step(held_heat, 2), nil, "overheated hold never requests reload")
held_heat.fire_held, held_heat.fire_released = false, true
equal(p:step(held_heat, 2.01), nil, "heat dwell starts with the released trigger")
equal(p:step(held_heat, 2.17), "fire-released", "released overheat can reload after dwell")

p = api.Policy.new()
equal(p:step(heat_sample("H", false), 0), nil, "heat weapon baseline")
equal(p:step(heat_sample("H", false, true), 0.1), nil, "empty ammo does not imply overheat")
local hot = heat_sample("H", true, true)
hot.ammo = 3
equal(p:step(hot, 0.2), "overheated", "actual overheat ignores ammo count")
p:sent(0.2)
equal(p:step(heat_sample("H", true, true), 0.6), nil, "held fire does not repeat on heat")
equal(p:step(heat_sample("H", false), 0.7), nil, "cooling clears heat state")
equal(p:step(heat_sample("H", true), 0.8), "overheated", "later overheat retriggers")
p:sent(0.8)
equal(p:step(heat_sample("H", false), 0.9), nil)
equal(p:step(heat_sample("H", nil, true), 1.0), nil, "unknown overheat blocks reload")
equal(p:step(heat_sample("H", false), 1.1), nil, "unknown is not inferred as overheat")
p = api.Policy.new()
equal(p:step(heat_sample("H", true), 0), nil, "initial overheated is not an event")
equal(p:step(heat_sample("H", true, true), 0.1), "fire-attempt", "fire while overheated")
p = api.Policy.new()
p:step(sample("A", 3), 0)
equal(p:step(heat_sample("H", false), 0.1), nil, "swap to cool heat weapon")
equal(p:step(sample("A", 3), 0.2), nil)
equal(p:step(heat_sample("H", true), 0.3), "weapon-swapped", "swap to overheated weapon")
p = api.Policy.new()
p:step(heat_sample("H", false), 0)
local blocked_heat = heat_sample("H", true)
blocked_heat.reserve = nil
equal(p:step(blocked_heat, 0.1), nil, "unknown heat reserve blocks")
blocked_heat = heat_sample("H", true)
blocked_heat.reloading = true
equal(p:step(blocked_heat, 0.2), nil, "active heat reload blocks")
equal(p:step(heat_sample("H", true), 0.3), nil, "heat reload does not repeat")
p = api.Policy.new()
p:step(heat_sample("H", false), 0)
blocked_heat = heat_sample("H", true)
blocked_heat.manual_reload = true
equal(p:step(blocked_heat, 0.1), nil, "manual heat reload blocks")
blocked_heat.manual_reload = false
blocked_heat.reloading = nil
equal(p:step(blocked_heat, 0.2), nil, "unknown heat reload state blocks")
p = api.Policy.new()
p:step(heat_sample("H", false), 0)
blocked_heat = heat_sample("H", true)
blocked_heat.reserve = 0
equal(p:step(blocked_heat, 0.1), nil, "no spare heat sink blocks")
equal(p:step(heat_sample("H", true), 0.2), "overheated", "late heat reserve remains eligible")
p = api.Policy.new()
p:step(heat_sample("H", false), 0)
equal(p:step(heat_sample("H", true), 0.1), "overheated")
equal(p:step(heat_sample("H", false), 0.2), nil, "cooling cancels pending heat reload")
equal(p:step(heat_sample("H", true), 0.3), "overheated", "new overheat event after cooling")
p = api.Policy.new()
p:step(sample("primary", 2), 0)
local pending_switch = sample("sidearm", 0)
pending_switch.switch_wait = true
equal(p:step(pending_switch, 0.1), nil, "switch wait blocks early reload")
pending_switch.switch_wait, pending_switch.switch_ready = nil, true
equal(p:step(pending_switch, 1.2), "weapon-swapped",
    "empty target reloads after switch delay")
p:sent(1.2)
equal(p:step(pending_switch, 1.3), nil, "switch repeat guard")
p = api.Policy.new()
p:step(sample("primary", 2), 0)
pending_switch = sample("sidearm", 3)
pending_switch.switch_wait = true
equal(p:step(pending_switch, 0.1), nil)
pending_switch.switch_wait, pending_switch.switch_ready = nil, true
equal(p:step(pending_switch, 1.2), nil, "loaded switched weapon stays loaded")
p = api.Policy.new()
p:step(heat_sample("dagger", false), 0)
local hot_reloading = heat_sample("dagger", true)
hot_reloading.reloading = true
equal(p:step(hot_reloading, 0.1), nil, "heat reload flag needs dwell")
equal(p:step(hot_reloading, 0.24), nil, "heat reload flag still settling")
equal(p:step(hot_reloading, 0.26), "overheated", "persistent heat with reload flag")
p:sent(0.26)
equal(p:step(hot_reloading, 0.7), nil, "one attempt per overheat event")
p:reset()
hot_reloading.fire = true
equal(p:step(hot_reloading, 0.8), nil, "identity gap cannot repeat heat reload")
hot_reloading.fire = false
equal(p:step(heat_sample("dagger", false), 0.9), nil, "cooling clears heat latch")
equal(p:step(heat_sample("dagger", true), 1.0), "overheated", "new overheat can reload")
p = api.Policy.new()
p:step(heat_sample("dagger", false), 0)
equal(p:step(hot_reloading, 0.1), nil)
hot_reloading.reserve = 1
equal(p:step(hot_reloading, 0.3), nil, "reserve change cancels pending heat reload")
hot_reloading.reserve = 2
equal(p:step(hot_reloading, 0.31), nil, "cancelled heat attempt stays cancelled")
p = api.Policy.new()
p:step(heat_sample("dagger", false), 0)
hot_reloading.manual_reload = nil
equal(p:step(hot_reloading, 0.1), nil)
hot_reloading.manual_reload = true
equal(p:step(hot_reloading, 0.2), nil, "manual heat reload cancels pending")
hot_reloading.manual_reload = false
equal(p:step(hot_reloading, 0.3), nil, "manual heat reload is not duplicated")
hot_reloading.reloading, hot_reloading.manual_reload = false, nil

-- Native adapter contracts, with no engine calls or actual input.
local cells, resolved, control, rotation, declaration
local equipment = { A = { resource = "content/fac_helldivers/equipment/primary_weapons/test/test" } }
local identity = {
    resolve = function() return resolved end,
    in_control = function() return control end,
    rotation_free = function() return rotation end,
}
local parts = { GeneratedCommon = { identity = { equipment = equipment } },
    IdentityCore = { new = function() return identity end },
    Provider = { new = function() error("legacy provider must not be constructed") end } }
local native_calls, native_avatar = 0, 100
local adapter_native = {sample = function()
    native_calls = native_calls + 1
    local copy = {}; for key, value in pairs(cells) do copy[key] = value end
    copy.active, copy.native, copy.avatar, copy.weapon = true, true, native_avatar, "native:100:5"
    return copy, "ready"
end}
local reader = api.Reader.new(parts, { snapshot = {} }, adapter_native)
resolved = { status = "resolved", reason = "wield-node-named-the-hand:first-person-node",
    grip = 15, avatar = { goid = 100 }, hand_weapon = { goid = 5, type = "A" } }
control, rotation = true, true
cells = { mode = "ammo", ammo = 0, reserve = 2, reloading = false }
equal(reader:sample().ammo, 0, "known empty")
equal(reader:sample().weapon, "native:100:5", "native weapon identity")
equal(reader:sample().unconfirmed, false, "second coherent empty read confirmed")
cells.ammo = 1
equal(reader:sample().unconfirmed, nil, "loaded weapon clears confirmation")
cells.ammo = 0
equal(reader:sample().unconfirmed, true, "new empty episode requires confirmation")
cells.reserve = 1
equal(reader:sample().unconfirmed, true, "changed reserve restarts confirmation")
equal(reader:sample().unconfirmed, false)
control = false
equal(reader:sample().active, false, "non-player control blocks")
equal(reader:sample().in_control, false)
rotation = false
equal(reader:sample(nil, nil, nil, true).active, true, "seated personal fire remains supported")
equal(reader:sample(nil, nil, nil, true).seated_fire, true)
resolved.grip = 70
equal(reader:sample(nil, nil, nil, true).active, false, "unresolved seated grip is blocked")
control, rotation = true, true
equal(reader:sample().active, true, "controlled grip70 uses held native weapon")
resolved.grip = 40
local before = native_calls
equal(reader:sample().active, false, "mounted cannon stays excluded")
equal(native_calls, before, "unsupported grip is not sampled")
resolved.grip = 15
resolved.underbarrel = { goid = 5 }
equal(reader:sample().active, false, "underbarrel cannot use main ammo")
equal(native_calls, before)
resolved.underbarrel = nil
resolved.avatar = nil
equal(reader:sample().active, false, "missing avatar blocks")
equal(native_calls, before)
resolved.avatar = { goid = 100 }
native_avatar = 101
local mismatch, mismatch_reason = reader:sample()
equal(mismatch.active, false, "another avatar cannot authorize input")
equal(mismatch_reason, "avatar-mismatch")
native_avatar = 100
cells = {mode = "heat", overheated = false, reserve = 2, reloading = false}
equal(reader:sample().mode, "heat", "native heat component selects mode")
equal(reader:sample().overheated, false, "warm is not overheated")
cells.overheated = true
equal(reader:sample().unconfirmed, true, "overheat requires two coherent reads")
equal(reader:sample().unconfirmed, false)
reader.native = nil
local unavailable, unavailable_reason = reader:sample()
equal(unavailable.active, false, "missing native reader fails closed")
equal(unavailable_reason, "native-unavailable", "no legacy diagnostic fallback")
equal(reader.sample_legacy, nil, "legacy diagnostic reader removed")
equal(api.boolean(0), false); equal(api.boolean(1), true); equal(api.boolean(nil), nil)

local invalidations = 0
local cache = { invalidate = function() invalidations = invalidations + 1 end }
local recovery = {}
equal(api.recover_identity(cache, recovery, { avatar = 100 }, "ready", 0), false)
equal(api.recover_identity(cache, recovery, {}, "no-avatar:no-avatar-right-now", 0.1), false)
equal(api.recover_identity(cache, recovery, { avatar = 100 },
    "no-on-body-object-of-grip=15", 0.2), true, "same-id avatar recovered in new game")
equal(invalidations, 1)
equal(api.recover_identity(cache, recovery, { avatar = 100 },
    "no-on-body-object-of-grip=15", 0.3), false, "brief weapon gap tolerated")
equal(api.recover_identity(cache, recovery, { avatar = 100 },
    "no-on-body-object-of-grip=1", 1.1), true, "persistent secondary gap resets cache")
equal(api.recover_identity(cache, recovery, { avatar = 100 },
    "hand-empty:nothing-at-the-wield-node", 1.2), false, "recovery throttled")
equal(api.recover_identity(cache, recovery, { avatar = 100 },
    "no-on-body-object-of-grip=70", 3.2), true, "support weapon can retry cache")
equal(invalidations, 3)
equal(api.recover_identity(cache, recovery, { avatar = 100 }, "ready", 3.3), false)
equal(api.recover_identity(cache, recovery, { avatar = 100 },
    "no-player-control", 5), false, "vehicle control does not reset identity")
equal(api.recover_identity(cache, recovery, { avatar = 101 }, "ready", 5.1), true,
    "new avatar goid resets identity")
equal(invalidations, 4)

local calls = {}
local env = { update = function(a, b) calls[#calls+1] = "original"; return a, nil, b end,
    shutdown = function(a) return a end }
equal(api.install_hooks(env, function() calls[#calls+1] = "tick" end,
    function() calls[#calls+1] = "stop" end), true)
local a, b, c = env.update(1, 3)
equal(a, 1); equal(b, nil); equal(c, 3)
equal(calls[1], "original"); equal(calls[2], "tick")
equal(env.shutdown(9), 9); equal(calls[3], "stop")
equal(api.install_hooks({}, function() end, function() end), false)

-- Load the actual embedded reader and exercise its real batched ammo provider.
local field_ids = { "d7a5d63e", "4a893e74", "ec64918b", "cd889dbc", "f6275c53" }
local raw = { 0, false, 4, false, false }
stingray = { Network = { object_info = function()
    local fields = {}
    for i, id in ipairs(field_ids) do fields[i] = { id = id } end
    return { fields = fields }
end }, GameSession = {
    game_object_exists = function() return true end,
    game_object_field_batched = function() return raw end,
} }
local real_parts = dofile("dist/reader_core.lua")
local real_fragment = dofile("dist/numbers.lua")
local generated = real_parts.GeneratedCommon
for _, key in ipairs({ "snapshot", "signals", "role_tables", "authored_base", "authored_delta", "network_fields", "relations" }) do
    generated[key] = real_fragment[key] or {}
end
generated.snapshot.reloading = { from = "0xcd889dbc", relation = "hand-weapon" }
local real_provider = real_parts.Provider.new(generated)
local real_type
for key, row in pairs(generated.identity.equipment) do
    if row.resource:find("/primary_weapons/assault_rifle/", 1, true) then real_type = key; break end
end
assert(real_type, "known rifle type missing")
local missile_type
for key, row in pairs(generated.identity.equipment) do
    if row.resource:find("/sidearm_weapons/smart_pistol_missile/", 1, true) then
        missile_type = key; break
    end
end
equal(missile_type, "0xfd585726", "missile pistol is classified as a sidearm")
local id = { hand_weapon = { goid = 5, type = real_type } }
equal(real_provider:provide(id, 1).cells.ammo, 1, "actual provider adds chambered round")
raw[2] = true
equal(real_provider:provide(id, 1).cells.ammo, 0, "actual provider empty chamber")
equal(real_provider:provide(id, 1).cells.reserve, 4, "actual reserve reader")
equal(real_provider:provide(id, 1).cells.reloading, false)
equal(real_provider:provide(id, 1).cells.overheated, false, "actual overheat field false")
raw[5] = true
equal(real_provider:provide(id, 1).cells.overheated, true, "actual overheat field true")
raw[1] = 3
equal(real_provider:provide(id, 1).cells.ammo, 3)
raw[4] = true
equal(real_provider:provide(id, 1).cells.reloading, true)
raw[1] = nil
equal(real_provider:provide(id, 1).cells.ammo, nil, "failed read remains unknown")

local ffi = require("ffi")
ffi.cdef[[
typedef struct { unsigned short vk, scan; unsigned int flags, time; uintptr_t extra; } ARTEST_KEY;
typedef struct { int x, y; unsigned int data, flags, time; uintptr_t extra; } ARTEST_MOUSE;
typedef union { ARTEST_KEY key; ARTEST_MOUSE mouse; } ARTEST_UNION;
typedef struct { unsigned int type; ARTEST_UNION value; } ARTEST_INPUT;
]]
equal(ffi.sizeof("ARTEST_INPUT"), 40, "native INPUT ABI")

-- Execute the full runtime with a fake Win32 API. SendInput only records events.
local original_require, original_getenv = require, os.getenv
local keys, inputs, logs, now, focused = {}, {}, {}, 0, true
local user32 = {
    GetAsyncKeyState = function(vk) return keys[vk] and -32768 or 0 end,
    GetForegroundWindow = function() return 1 end,
    GetWindowThreadProcessId = function(_, pid) pid[0] = focused and 42 or 7 end,
    MapVirtualKeyW = function() return 0x13 end,
    SendInput = function(_, input, size)
        equal(size, 40, "runtime ABI")
        inputs[#inputs+1] = { type = input[0].type, flags = input[0].value.key.flags,
            mouse_flags = input[0].value.mouse.flags,
            scan = input[0].value.key.scan, time = now, fire_held = keys[1] == true }
        if input[0].type == 0 and input[0].value.mouse.flags == 4 then keys[1] = false end
        return 1
    end,
}
local fake_ffi = {
    cdef = function() end,
    load = function(name)
        if name ~= "user32" then return { HD2AR_GetCurrentProcessId = function() return 42 end } end
        return setmetatable({}, { __index = function(_, key)
            return user32[key:gsub("^HD2AR_", "")]
        end })
    end,
    sizeof = function() return 40 end,
    abi = function() return true end,
    new = function(name)
        if name == "unsigned int[1]" then return { [0] = 0 } end
        return { [0] = { type = 0, value = { key = {}, mouse = {} } } }
    end,
}
require = function(name)
    if name == "ffi" then return fake_ffi end
    if name == "mods/hd2_helper/autoreload_setting_enabled" or
        name == "mods/hd2_helper/autoreload_setting_charge90" then return true end
    return original_require(name)
end
os.getenv = function() return nil end
CowboyBingusModLoader = { open_log = function()
    return { write = function(_, text) logs[#logs+1] = text end, flush = function() end }
end }
equipment.A.spare_pack, equipment.A.ammo_icon = nil, nil
equipment["0x2df95dfe"] = { call = "known-call",
    resource = "content/fac_helldivers/equipment/primary_weapons/test/test" }
resolved = { status = "resolved", reason = "wield-node-named-the-hand:first-person-node",
    avatar = { goid = 100 }, grip = 15,
    hand_weapon = { goid = 5, type = "0x2df95dfe" } }
control, rotation, declaration = true, true, ""
cells = { ammo = 1, reserve = 3, reloading = false, reload_allow_move = true }
identity.invalidate = function() end
local live_type_calls, research_reads = 0, 0
stingray = {
    Network = { game_session = function() return 1 end, peer_id = function() return 2 end },
    GameSession = { in_session = function() return true end,
        objects_owned_by = function() research_reads = research_reads + 1; return { 42 } end,
        game_object_field_batched = function() research_reads = research_reads + 1; return { [1] = 1 } end,
        game_object_is_type = function(_, goid, kind)
            live_type_calls = live_type_calls + 1
            return goid == 5 and (kind == "known-call" or kind == "id:2df95dfe")
        end },
    IdString32 = { from_hex = function(hash) return "id:" .. hash end },
    Application = { time_since_launch = function() return now end,
        can_get = function(_, name)
            return name == "mods/hd2_helper/autoreload_setting_enabled" or
                name == "mods/hd2_helper/autoreload_setting_charge90"
        end,
        main_world = function() return 3 end, worlds = function() return {3} end },
}
TEST_READER_PARTS = parts
TEST_NATIVE_READER = { sample = function()
    if resolved.status ~= "resolved" then return nil, "no-held-weapon" end
    return { active = true, native = true, avatar = resolved.avatar.goid,
        weapon = "native:100:" .. resolved.hand_weapon.goid,
        mode = "ammo", ammo = cells.ammo, reserve = cells.reserve,
        reloading = cells.reloading, feed = "magazine", reload_allow_move = cells.reload_allow_move }, "ready"
end }
HD2_AUTO_RELOAD_TEST = nil
local file = assert(io.open("addon.lua", "r")); local source = file:read("*a"); file:close()
for _, marker in ipairs({"Probe", "probe_pending", "sample_legacy", "diagnostics",
    "TANK_PROBE", "HASH_TYPE", "SEAT_AIM", "PROBE_INPUT"}) do
    equal(source:find(marker, 1, true), nil, "removed runtime path: " .. marker)
end
file = assert(io.open("policy.lua", "r")); local policy_source = file:read("*a"); file:close()
file = assert(io.open("native.lua", "r")); local native_source = file:read("*a"); file:close()
file = assert(io.open("native_reader.lua", "r")); local native_reader_source = file:read("*a"); file:close()
file = assert(io.open("options.lua", "r")); local options_source = file:read("*a"); file:close()
file = assert(io.open("charge_policy.lua", "r")); local charge_source = file:read("*a"); file:close()
source = source:gsub("\r\n", "\n")
source = source:gsub("%-%- @POLICY@", function() return policy_source end)
    :gsub("%-%- @OPTIONS@", function() return options_source end)
    :gsub("%-%- @CHARGE@", function() return charge_source end)
    :gsub("%-%- @NATIVE@", function() return native_source end)
    :gsub("%-%- @NATIVE_READER@", function() return native_reader_source end)
    :gsub("%-%- @READER_CORE@", "return TEST_READER_PARTS")
    :gsub("%-%- @NUMBERS@", "return {snapshot={}}")
    :gsub("pcall%(Reader%.new, parts, fragment, NativeReader%.new%(%)%)",
        "pcall(Reader.new, parts, fragment, TEST_NATIVE_READER)")
update = function() return 123, nil, 321 end
local chunk = assert(loadstring(source, "@addon-runtime-test"))
chunk()
equal(HD2HelperAutoReload ~= nil, true, "runtime initialized")
equal(HD2HelperAutoReload.config.enabled, true, "installed default reload is on")
equal(HD2HelperAutoReload.config.charge90, true, "runtime charge release defaults on")
local function frame(time) now = time; return update() end
a, b, c = frame(0)
equal(a, 123); equal(b, nil); equal(c, 321)
keys[120] = true; frame(0.005)
equal(live_type_calls, 0, "F9 makes no diagnostic type calls")
frame(0.051)
equal(live_type_calls, 0, "F9 still does nothing on a reader tick")
equal(research_reads, 0, "no research field scans at startup")
keys[120] = false; frame(0.102)
local logs_before_f10 = #logs
keys[121] = true; frame(0.103); frame(0.153)
equal(#logs, logs_before_f10, "F10 no longer starts live discovery")
equal(#inputs, 0, "disabled F10 sends no reload input")
keys[121] = false
cells.ammo = 0; keys[1] = true
frame(0.204)
equal(#inputs, 0, "first native empty reading is unconfirmed")
frame(0.255)
equal(#inputs, 0, "held fire sends no reload key")
frame(0.3)
equal(#inputs, 0, "held fire keeps reload deferred")
frame(0.5); equal(#inputs, 0, "long held fire sends no reload key")
keys[1] = false; frame(0.51)
equal(#inputs, 1, "release immediately reloads a confirmed empty weapon")
equal(inputs[1].flags, 8, "scan-code down")
keys[120] = true; frame(0.525)
frame(0.561)
equal(#inputs, 2, "scheduled up")
equal(inputs[2].flags, 10, "scan-code up")
equal(live_type_calls, 0, "repeated F9 has no game type calls")
keys[120] = false; frame(0.57)
Hd2TankSeatSwitch = { last = "seat:16474112801385b6:3" }
resolved.grip, control, keys[2] = 15, false, true
frame(0.61)
frame(0.612)
equal(#inputs, 2, "seated aim without fire never reloads")
equal(research_reads, 0, "seated control block no longer scans tank fields")
Hd2TankSeatSwitch = nil; keys[2] = false; frame(0.67)
keys[2] = true; frame(0.74)
equal(research_reads, 0, "aim without a seat addon does not trigger scanning")
resolved.grip, control, keys[2], Hd2TankSeatSwitch = nil, true, false, nil
keys[1] = false; frame(0.75)
resolved.grip, cells.ammo = 15, 1
frame(0.8)
resolved.hand_weapon.goid, cells.ammo = 6, 0
frame(0.9); equal(#inputs, 2, "new native weapon requires a second empty reading")
frame(0.96); equal(#inputs, 3, "runtime actual swap trigger")
frame(1.02)
keys[1] = true; frame(1.1); frame(1.26); frame(1.32)
equal(#inputs, 4, "empty fire press waits without sending R")
keys[1] = false; frame(1.33)
equal(#inputs, 5, "empty fire press reloads on release")
keys[13] = true; frame(1.35)
keys[13], keys[1] = false, false; frame(1.4)
keys[1] = true; frame(1.7)
equal(#inputs, 6, "chat blocks empty fire")
keys[27] = true; frame(1.75)
keys[27], keys[1] = false, false; frame(1.8)
focused = false; keys[1] = true; frame(2)
equal(#inputs, 6, "another application blocks input")
focused, keys[1], keys[119] = true, false, true; frame(2.1)
keys[119], keys[1] = false, true; frame(2.2)
equal(#inputs, 6, "F8 pause blocks")
keys[119], keys[1] = true, false; frame(2.3)
keys[119], keys[1] = false, false; frame(2.35)
cells.ammo = 3; frame(2.4)
cells.ammo = 0; frame(2.5)
equal(#inputs, 6, "resume empty reading first waits for confirmation")
frame(2.56)
equal(#inputs, 7, "resume exhaustion")
resolved.status, resolved.reason, resolved.grip = "absent", "no-on-body-object-of-grip=70", 70
keys[2] = true; frame(2.57); frame(2.62)
equal(research_reads, 0, "unresolved grip70 aim does not start a tank probe")
for _, line in ipairs(logs) do
    for _, marker in ipairs({"TANK_PROBE", "HASH_TYPE", "SEAT_AIM", "PROBE_INPUT"}) do
        equal(line:find(marker, 1, true), nil, "no live research log: " .. marker)
    end
end
resolved.status, resolved.reason, resolved.grip = "resolved", nil, 15
resolved.hand_weapon.goid = 7
keys[2], keys[49] = false, true
frame(2.7)
equal(#inputs, 8, "digit switch waits for the draw animation")
keys[49] = false
frame(3.6)
equal(#inputs, 8, "digit switch does not reload before 1.1 seconds")
frame(3.9)
equal(#inputs, 9, "digit switch reloads an empty drawn weapon")
resolved.reason, resolved.grip = "wield-node-named-the-hand:first-person-node", 1
control, rotation, cells.ammo, keys[2], keys[1] = false, false, 1, true, true
frame(4.0)
equal(#inputs, 10, "seated lean reads a loaded personal weapon")
cells.ammo = 0; frame(4.05); frame(4.2); frame(4.3)
equal(#inputs, 10, "seated lean never reloads while fire is held")
keys[1] = false; frame(4.31)
equal(#inputs, 11, "seated lean reloads the personal weapon on release")
keys[1], keys[2], control, rotation, cells.ammo = false, false, true, true, 1
frame(4.4)
equal(#inputs, 12, "seated reload key is released")
keys[1] = true; frame(4.5)
control, keys[1] = false, false; frame(4.56)
control, cells.ammo = true, 0
frame(5.62); frame(5.68)
equal(#inputs, 12, "fire attempt expires one second after release")
cells.ammo = 1; frame(5.8)
keys[1] = true; frame(5.9)
frame(7.5)
control, keys[1] = false, false; frame(7.56)
control, cells.ammo = true, 0
frame(8.3)
equal(#inputs, 12, "first post-release empty reading is unconfirmed")
frame(8.36)
equal(#inputs, 13, "held fire remains eligible for one second after release")
frame(8.42)
equal(#inputs, 14, "post-release reload key is released")
cells.ammo = 1; frame(8.5)
keys[1] = true; frame(8.6)
frame(10.1)
cells.ammo = 0; frame(10.16)
equal(#inputs, 14, "empty reading during long fire hold is unconfirmed")
frame(10.22)
equal(#inputs, 14, "long held fire cannot consume a reload attempt")
keys[1] = false; frame(10.28)
equal(#inputs, 15, "long held fire reloads only after release")
frame(10.34)
equal(#inputs, 16, "reload key is released after long fire hold")
cells.ammo = 1; frame(10.4)
keys[1] = true; frame(10.45)
cells.ammo, cells.reloading = 0, true; frame(10.5)
keys[1] = false; frame(10.56)
equal(#inputs, 16, "release does not interrupt an active magazine reload")
cells.reloading = false; frame(10.62); frame(10.68)
equal(#inputs, 16, "active reload discarded the release request")
cells.ammo = 1; frame(10.74)
keys[1] = true; frame(10.8)
keys[1], cells.ammo = false, 0; frame(10.81)
equal(#inputs, 16, "fast release waits for the second empty reading")
keys[1] = true; frame(10.82); frame(11.2)
equal(#inputs, 16, "repress pauses the release check before it sends R")
keys[1] = false; frame(11.21)
equal(#inputs, 17, "second release rechecks the empty weapon immediately")
frame(11.27)
equal(#inputs, 18, "second release finishes its R pulse")
cells.ammo = 1; frame(11.33)
keys[164], keys[49] = true, true
frame(11.4)
equal(HD2HelperAutoReload.switch, nil, "Alt+number is not a weapon switch")
cells.ammo = 0; frame(11.6)
equal(#inputs, 18, "Alt blocks reload input")
keys[164], keys[49] = false, false
HD2StratagemHotkeys = {blocking_inputs = true}
keys[50] = true; frame(11.7)
equal(HD2HelperAutoReload.switch, nil, "configured stratagem modifier blocks switch tracking")
equal(#inputs, 18, "command input blocks reload")
keys[50], HD2StratagemHotkeys = false, nil
shutdown()
equal(#inputs, 18, "shutdown leaves released key alone")
equal(inputs[18].flags, 10)
for _, input in ipairs(inputs) do
    if input.flags == 8 then
        equal(input.fire_held, false, "every reload down has the physical fire key up")
    end
end
inputs, keys, logs = {}, {}, {}
HD2HelperAutoReload, shutdown = nil, nil
update = function() return 123 end
local default_heat = {active = true, native = true, avatar = 100, weapon = "native:100:heat",
    mode = "heat", overheated = false, reserve = 2, reloading = false, feed = "heat", reload_allow_move = true}
TEST_NATIVE_READER.sample = function()
    local copy = {}; for key, value in pairs(default_heat) do copy[key] = value end
    return copy, "ready"
end
resolved.avatar.goid, resolved.grip, control, rotation = 100, 15, true, true
chunk()
equal(HD2HelperAutoReload.config.enabled, true, "default heat reload is enabled")
frame(15)
keys[1] = true; default_heat.overheated = true; frame(15.1); frame(15.16)
equal(#inputs, 0, "default heat reload waits for fire release")
keys[1] = false; frame(15.17)
equal(#inputs, 1, "default heat reload sends a key after confirmed overheat")
equal(inputs[1].flags, 8)
frame(15.22); equal(#inputs, 2, "default heat reload releases its key")
equal(inputs[2].flags, 10)
shutdown()
inputs, keys, logs = {}, {}, {}
HD2HelperAutoReload, shutdown = nil, nil
update = function() return 123 end
stingray.Application.can_get = function(_, resource)
    return resource == "mods/hd2_helper/autoreload_setting_charge90" or
        resource == "mods/hd2_helper/autoreload_setting_enabled"
end
require = function(name)
    if name == "ffi" then return fake_ffi end
    if name == "mods/hd2_helper/autoreload_setting_charge90" then return true end
    if name == "mods/hd2_helper/autoreload_setting_enabled" then return false end
    return original_require(name)
end
local charge_sample = {active = true, native = true, avatar = 100, weapon = "native:100:8",
    mode = "ammo", ammo = 1, reserve = 0, reloading = false, feed = "magazine", reload_allow_move = true,
    charge_kind = "epoch", charge_elapsed = 2.6, charge_limit = 2.7, charge_max = 2.8, charging = true,
    charge_reason = "ready", charge_source = "instance"}
TEST_NATIVE_READER.sample = function()
    local copy = {}; for key, value in pairs(charge_sample) do copy[key] = value end
    return copy, "ready"
end
resolved.avatar.goid, resolved.grip, control, rotation = 100, 15, true, true
assert(loadstring(source, "@charge-runtime-test"))()
equal(HD2HelperAutoReload.config.enabled, false, "charge feature runs with reload off")
equal(HD2HelperAutoReload.config.charge90, true)
keys[1] = true; frame(20)
equal(#inputs, 0, "initial charge reading cannot fire")
charge_sample.charge_elapsed = 2.7; frame(20.1)
equal(#inputs, 1, "Epoch full charge sends a release even without spare ammo")
equal(inputs[1].type, 0); equal(inputs[1].mouse_flags, 4, "only MOUSEEVENTF_LEFTUP sent")
frame(20.2); frame(20.3)
equal(#inputs, 1, "held physical button does not repeat the automatic release")
keys[1] = false; charge_sample.charge_elapsed, charge_sample.charging = 0, false
charge_sample.ammo = 0; frame(20.4); frame(20.5)
equal(#inputs, 1, "charge-only option cannot send a reload key")
charge_sample.ammo, charge_sample.charging, charge_sample.charge_elapsed = 1, true, 2.6
keys[1], keys[164] = true, true; frame(21)
charge_sample.charge_elapsed = 2.7; frame(21.1)
equal(#inputs, 1, "stratagem modifier blocks charge release")
keys[164], keys[1] = false, false
charge_sample.charge_elapsed = 0; frame(21.2)
keys[1] = true; charge_sample.charge_elapsed = 2.6; frame(23.8)
focused = false; charge_sample.charge_elapsed = 2.7; frame(23.9)
equal(#inputs, 1, "focus loss blocks charge release")
focused, keys[1], charge_sample.charge_elapsed = true, false, 0; frame(24)
keys[1] = true; charge_sample.charge_elapsed = 2.6; frame(26.6)
charge_sample.reloading, charge_sample.charge_elapsed = true, 2.7; frame(26.7)
equal(#inputs, 1, "active reload blocks charge release")
charge_sample.reloading, charge_sample.charge_elapsed, keys[1] = false, 0, false
frame(26.8)
keys[1] = true; charge_sample.charge_elapsed = 2.6; frame(29.4)
charge_sample.charge_elapsed = 2.7; frame(29.5)
equal(#inputs, 2, "new manual charge rearms release")
for _, input in ipairs(inputs) do
    equal(input.type, 0, "charge-only module never sends keyboard input")
    equal(input.mouse_flags, 4, "charge module never sends a mouse press")
end
keys[1], charge_sample.charge_elapsed = false, 0; frame(29.6)
keys[13] = true; frame(30); keys[13] = false
keys[1], charge_sample.charge_elapsed = true, 2.6; frame(32.6)
charge_sample.charge_elapsed = 2.7; frame(32.7)
equal(#inputs, 2, "chat blocks charge release")
keys[27] = true; frame(32.8); keys[27], keys[1] = false, false
charge_sample.charge_elapsed = 0; frame(32.9)
keys[119] = true; frame(33); keys[119] = false
keys[1], charge_sample.charge_elapsed = true, 2.6; frame(35.6)
charge_sample.charge_elapsed = 2.7; frame(35.7)
equal(#inputs, 2, "F8 pauses charge release")
keys[119] = true; frame(35.8); keys[119], keys[1] = false, false
charge_sample.charge_elapsed = 0; frame(35.9)
HD2HelperAutoReload.config.enabled = true
keys[1], charge_sample.charge_elapsed = true, 2.6; frame(38.5)
charge_sample.charge_elapsed = 2.7; frame(38.6)
equal(#inputs, 3, "charge release coexists with reload enabled")
equal(inputs[3].mouse_flags, 4)
keys[1], charge_sample.ammo, charge_sample.reserve, charge_sample.charge_elapsed = false, 0, 2, 0
frame(38.61); equal(#inputs, 3, "post-charge empty reading waits for confirmation")
frame(38.67); equal(#inputs, 4, "post-charge release keeps automatic reload working")
equal(inputs[4].type, 1); equal(inputs[4].flags, 8)
frame(38.72); equal(inputs[5].flags, 10, "post-charge reload key is released")
shutdown()
require, os.getenv = original_require, original_getenv
dofile("compatibility.test.lua")(api, equal)
print("PASS " .. count .. " assertions; actual LuaJIT, no game inputs sent")
