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
    return {enabled = setting("enabled", true), charge90 = setting("charge90", false)}
end
function Options.allow(config, sample)
    return config.enabled == true and sample ~= nil and
        (sample.mode == "ammo" or sample.mode == "heat")
end
return Options
