-- HD2-Addon: mods/hd2_helper/auto_reload
if rawget(_G, "HD2HelperCombined") then return end
local state = {version = "0.3.61-test"}
rawset(_G, "HD2HelperCombined", state)
local Language = (function()
-- @LANGUAGE@
end)()
local LiveOptions = (function()
-- @MOD_OPTIONS@
end)()
LiveOptions.Tab = (function()
-- @OPTIONS_TAB@
end)()
local schema = (function()
-- @MENU_SCHEMA@
end)()
local options_file
local loader = rawget(_G, "CowboyBingusModLoader")
if loader and type(loader.open_log) == "function" then
    pcall(function() options_file = loader.open_log("hd2_helper_mod_options.log") end)
end
local function options_log(message)
    if options_file then pcall(function() options_file:write(message.."\n");options_file:flush() end) end
end
local sr = rawget(_G, "stingray") or {}
state.language = Language.new(options_log)
state.options = LiveOptions.new(_G,sr.Application or {},require,schema,state.language,options_log)
local previous_update = rawget(_G, "update")
rawset(_G, "update", function(...)
    local ok, why = pcall(state.options.tick,state.options)
    if not ok and state.options_error ~= tostring(why) then
        state.options_error = tostring(why);options_log("MOD_OPTIONS update "..tostring(why))
    end
    if type(previous_update) == "function" then return previous_update(...) end
end)
local previous_shutdown = rawget(_G, "shutdown")
rawset(_G, "shutdown", function(...)
    if options_file then pcall(function() options_file:close() end);options_file = nil end
    if type(previous_shutdown) == "function" then return previous_shutdown(...) end
end)
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
