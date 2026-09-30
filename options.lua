local Options = {}
function Options.read(app, load)
    local function selected(name, fallback)
        if not app.can_get then return fallback end
        local resource = "mods/hd2_helper/autoreload_option_" .. name
        local good, present = pcall(app.can_get, "lua", resource)
        if not good or not present then return false end
        local loaded, value = pcall(load, resource)
        return loaded and value == true
    end
    return {enabled = selected("enabled", true), ammo = not selected("ammo_off", false),
        heat = not selected("heat_off", false), diagnostics = selected("diagnostics", true)}
end
function Options.allow(config, sample)
    return config.enabled and sample and ((sample.mode == "ammo" and config.ammo) or
        (sample.mode == "heat" and config.heat)) == true
end
return Options
