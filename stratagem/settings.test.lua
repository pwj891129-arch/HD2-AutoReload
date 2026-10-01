return function(equal, read_file)
    local filters = dofile("dist/visibility.generated.lua")
    local source = read_file("addon.lua")
        :gsub('%-%- @PLATFORM@', function() return "return {create=function() return {} end}" end)
        :gsub('%-%- @READER@', function() return "return {new=function() return {} end}" end)
        :gsub('%-%- @POLICY@', function() return "return {new=function() return {} end}" end)
        :gsub('%-%- @RADIAL@', function() return "return {new=function() return {} end}" end)
        :gsub('%-%- @VISIBILITY@', function() return read_file("dist/visibility.generated.lua") end)
    local function configure(values, query_error, load_error, unchecked_features)
        local selected = {}; for key, value in pairs(values) do selected[key] = value end
        if not unchecked_features then
            if selected.radial == nil then selected.radial = true end
            if selected.hotkeys == nil then selected.hotkeys = true end
        end
        values = selected
        local env = setmetatable({}, {__index = _G}); env._G = env
        env.CowboyBingusModLoader = {api = 1, open_log = function() end}
        env.stingray = {Application = {time_since_launch = function() return 0 end,
            can_get = function(_, resource)
                local name = resource:match("stratagem_option_(.+)$")
                if name == query_error then error("query failed") end
                return values[name] ~= nil
            end}}
        env.require = function(resource)
            if resource == "ffi" then return {} end
            local name = resource:match("stratagem_option_(.+)$")
            if name == load_error then error("load failed") end
            return values[name]
        end
        local initialize = assert(loadstring(source)); setfenv(initialize, env); initialize()
        return env.HD2StratagemHotkeys and env.HD2StratagemHotkeys.config
    end
    equal(configure({}, nil, nil, true), nil, "unchecked feature checkboxes do not silently enable the addon")
    local initial = configure({})
    equal(initial.radial, true); equal(initial.hotkeys, true); equal(initial.scale, 1)
    equal(initial.shared.other, false)
    for _, filter in ipairs(filters) do
        equal(filter.group, filter.id:match("^(%a+)_"), "registered category matches its stable ID")
        for _, kind in ipairs(filter.kinds) do equal(initial.shared[kind], false, "individual visibility defaults unchanged") end
    end
    local choices = {"omitted", "individual", "on", "off"}
    local function value(choice)
        if choice == "on" then return true end
        if choice == "off" then return false end
        if choice == "individual" then return choice end
    end
    local function expected(combined, group, individual)
        if combined == "on" then return true end
        if combined == "off" then return false end
        if group == "on" then return true end
        if group == "off" then return false end
        return individual
    end
    for _, combined in ipairs(choices) do
        for _, shared in ipairs(choices) do
            for _, mission in ipairs(choices) do
                for _, pattern in ipairs({"on", "off", "mixed"}) do
                    local saved = {shared_mission_all = value(combined), shared_all = value(shared),
                        mission_all = value(mission), shared_other = pattern ~= "off"}
                    for index, filter in ipairs(filters) do
                        saved[filter.id] = pattern == "on" or pattern == "mixed" and index % 2 == 0
                    end
                    local result = configure(saved)
                    equal(result.shared.other, expected(combined, shared, saved.shared_other), "bulk unknown-call fallback")
                    for _, filter in ipairs(filters) do
                        local group = filter.group == "mission" and mission or shared
                        for _, kind in ipairs(filter.kinds) do
                            equal(result.shared[kind], expected(combined, group, saved[filter.id]), "combined > group > individual")
                        end
                    end
                    -- Returning to individual mode must restore, not rewrite, saved per-kind values.
                    saved.shared_all, saved.mission_all, saved.shared_mission_all = "individual", "individual", "individual"
                    result = configure(saved)
                    for _, filter in ipairs(filters) do
                        equal(result.shared[filter.kinds[1]], saved[filter.id], "bulk does not reset individual choices")
                    end
                    equal(result.radial, true); equal(result.hotkeys, true)
                end
            end
        end
    end
    for _, scale in ipairs({1, 1.5, 2, 3, 4}) do equal(configure({scale = scale}).scale, scale, "exact size setting") end
    for _, invalid in ipairs({true, false, "2", 0, -1, 1.3, 2.5, math.huge, 0 / 0, {}}) do
        equal(configure({scale = invalid}).scale, 1, "invalid size falls back to 100%")
        equal(configure({shared_mission_all = invalid == false and "bad" or invalid}).shared[124],
            invalid == true, "invalid master cannot enable hidden calls")
    end
    for _, id in ipairs({"shared_all", "mission_all", "shared_mission_all"}) do
        local saved = {shared_reinforce = true, mission_hellbomb = true, [id] = "bad"}
        local group = id == "mission_all" and 42 or 124
        equal(configure(saved).shared[group], false, "invalid bulk value hides its group")
        equal(configure(saved, id).shared[group], false, "failed bulk query hides its group")
        equal(configure(saved, nil, id).shared[group], false, "failed bulk load hides its group")
    end
    equal(configure({scale = 4}, "scale").scale, 1)
    equal(configure({scale = 4}, nil, "scale").scale, 1)
    equal(configure({large = true}).scale, 1, "retired 130% marker cannot override the new selector")
    equal(configure({radial = false}).radial, false, "unchecked radial stays disabled with hotkeys enabled")
    equal(configure({hotkeys = false}).hotkeys, false, "unchecked hotkeys stay disabled with radial enabled")
end
