local Options = {}
function Options.read(app, load)
    local function setting(name, fallback)
        if not app.can_get then return fallback end
        local resource = "mods/hd2_helper/autoreload_setting_" .. name
        local good, present = pcall(app.can_get, "lua", resource)
        if not good then return false end
        if not present then return fallback end
        local loaded, value = pcall(load, resource)
        return loaded and value == true
    end
    local railgun_threshold = 0.95
    if app.can_get then
        local resource = "mods/hd2_helper/autoreload_setting_railgun_threshold"
        local good, present = pcall(app.can_get, "lua", resource)
        if not good then railgun_threshold = false
        elseif present then
            local loaded, value = pcall(load, resource)
            railgun_threshold = loaded and (value == 0.9 or value == 0.95) and value or false
        end
    end
    -- Unchecked Arsenal checkboxes deploy no marker; absence must mean OFF.
    return {enabled = setting("enabled", false), charge90 = setting("charge90", false),
        vehicle = setting("vehicle", false), railgun_threshold = railgun_threshold}
end
function Options.allow(config, sample)
    if not sample then return false end
    if sample.vehicle == true then return config.vehicle == true and sample.mode == "ammo" end
    return config.enabled == true and (sample.mode == "ammo" or sample.mode == "heat")
end
return Options
