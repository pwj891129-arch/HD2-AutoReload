-- HD2-Addon: mods/hd2_helper/auto_reload
if rawget(_G, "HD2HelperCombined") then return end
local state = {version = "0.3.34-test"}
rawset(_G, "HD2HelperCombined", state)
local function start_feature(name, run)
    local good, why = pcall(run)
    if not good then
        state[name .. "_error"] = tostring(why)
        pcall(function()
            local loader = rawget(_G, "CowboyBingusModLoader")
            local file = loader and loader.open_log("hd2_helper_combined.log")
            if file then
                file:write("START_FAILED " .. name .. " " .. tostring(why) .. "\n")
                file:flush(); file:close()
            end
        end)
    end
end
-- Stratagem blocking must be current before the reload/charge update runs.
start_feature("stratagem", function()
-- @STRATAGEM@
end)
start_feature("autoreload", function()
-- @AUTORELOAD@
end)
