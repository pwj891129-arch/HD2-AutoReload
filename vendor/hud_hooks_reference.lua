-- Test-only callback reference derived from HD2 HUD+ 0.1.2 by DDRK1NG.
local __module_registry = {}
local __module_errors = {}
local function __module_log(line)
__module_errors[#__module_errors + 1] = tostring(line)
end
local function __module_environment(name, ambient_global)
local allowed = {}
allowed["assert"] = rawget(_G, "assert")
allowed["collectgarbage"] = rawget(_G, "collectgarbage")
allowed["error"] = rawget(_G, "error")
allowed["getmetatable"] = rawget(_G, "getmetatable")
allowed["io"] = rawget(_G, "io")
allowed["ipairs"] = rawget(_G, "ipairs")
allowed["load"] = rawget(_G, "load")
allowed["loadstring"] = rawget(_G, "loadstring")
allowed["math"] = rawget(_G, "math")
allowed["next"] = rawget(_G, "next")
allowed["os"] = rawget(_G, "os")
allowed["pairs"] = rawget(_G, "pairs")
allowed["pcall"] = rawget(_G, "pcall")
allowed["rawget"] = rawget(_G, "rawget")
allowed["rawset"] = rawget(_G, "rawset")
allowed["select"] = rawget(_G, "select")
allowed["setmetatable"] = rawget(_G, "setmetatable")
allowed["string"] = rawget(_G, "string")
allowed["table"] = rawget(_G, "table")
allowed["tonumber"] = rawget(_G, "tonumber")
allowed["tostring"] = rawget(_G, "tostring")
allowed["type"] = rawget(_G, "type")
allowed["unpack"] = rawget(_G, "unpack")
if ambient_global then allowed._G = _G end
return setmetatable(allowed, {__index=function(_, key) error(name .. ": undeclared global " .. tostring(key), 0) end,__newindex=function(_, key) error(name .. ": global write " .. tostring(key), 0) end})
end
local __module_run = (function()
return function(name, factory, imports, log)
local ok, exports = pcall(factory, imports)
if not ok then log("MODULE " .. name .. " ERROR " .. tostring(exports)) return nil end
if type(exports) ~= "table" then log("MODULE " .. name .. " ERROR exports") return nil end
return exports
end
end)()
do
local __imports = {}
local __factory = (function()
return function(imports)
if type(imports) ~= "table" then error("00-boot-state: imports must be a table", 0) end
local BootState = (function()
  local State = { VERSION = "boot-state-v1", result = false }
  local sr = rawget(_G, "stingray")
  local App = sr and rawget(sr, "Application") or nil
  local BRACKET_WINDOWS = 5
  State.BRACKET_WINDOWS = BRACKET_WINDOWS
  local sink, log_path = nil, nil
  local written, suppressed = 0, 0
  function State.log(line)
    if sink == nil then return end
    sink(line)
    written = written + 1
  end
  function State.attach(fn, path)
    sink, log_path = fn, path
  end
  function State.begin()
    return sink ~= nil
  end
  function State.brackets(window)
    if sink == nil then return false end
    if window ~= nil and window > BRACKET_WINDOWS then
      suppressed = suppressed + 1
      return false
    end
    return true
  end
  function State.globals()
    if type(_G) ~= "table" then return "not-a-table" end
    local names, total = {}, 0
    for key in pairs(_G) do
      total = total + 1
      if type(key) == "string" and #names < 12 then
        names[#names + 1] = key
      end
    end
    table.sort(names)
    return tostring(total) .. ":" .. table.concat(names, ",")
  end
  function State.log_state()
    return { path = log_path, written = written, suppressed = suppressed }
  end
  function State.clock()
    if App == nil or type(rawget(App, "time_since_launch")) ~= "function" then
      return nil
    end
    local ok, value = pcall(App.time_since_launch)
    if ok and type(value) == "number" then return App.time_since_launch end
    return nil
  end
  function State.install(worker)
    if State.installed then return false end
    local original = rawget(_G, "update")
    if type(original) ~= "function" then
      State.log("RUN product install=refused reason=no-global-update" ..
                " g=" .. type(_G) ..
                " update=" .. type(rawget(_G, "update")) ..
                " shutdown=" .. type(rawget(_G, "shutdown")) ..
                " stingray=" .. type(rawget(_G, "stingray")) ..
                " names=" .. tostring(State.globals()))
      return false
    end
    State.installed = true
    State.faults = 0
    rawset(_G, "update", function(...)
      if State.armed ~= false then
        local ok, why = pcall(function() worker:update() end)
        if not ok then
          State.faults = State.faults + 1
          State.armed = false
          State.log("RUN product worker=disarmed faults=" ..
                    tostring(State.faults) ..
                    " why=" .. string.format("%q", tostring(why)))
        end
      end
      return original(...)
    end)
    State.armed = true
    State.result = true
    State.log("RUN product install=ok hook=global-update")
    return true
  end
  return State
end)()
local __contract_ok_1, __contract_export_1 = pcall(function() return BootState end)
if not __contract_ok_1 or __contract_export_1 == nil then error("00-boot-state: missing export BootState", 0) end
return {["BootState"]=__contract_export_1}
end
end)()
setfenv(__factory, __module_environment("00-boot-state", true))
local __exports = __module_run("00-boot-state", __factory, __imports, __module_log)
if __exports ~= nil then
__module_registry["BootState"] = __exports["BootState"]
end
end
return __module_registry.BootState
