local UnitLinkProbe = {}
UnitLinkProbe.__index = UnitLinkProbe

function UnitLinkProbe.new(gs, synchronizer, units)
    return setmetatable({ gs = gs or {}, synchronizer = synchronizer or {},
        units = units or {}, done = false }, UnitLinkProbe)
end

function UnitLinkProbe:reset()
    self.done = false
end

function UnitLinkProbe:read(session, sample)
    if self.done or type(sample) ~= "table" or sample.active ~= true or
        sample.seated_fire or not sample.goid or not sample.slot then return nil end
    self.done = true
    local prefix = "UNIT_LINK known_goid=" .. tostring(sample.goid) ..
        " slot=" .. tostring(sample.slot)
    if type(self.gs.unit_synchronizer) ~= "function" or
        type(self.synchronizer.game_object_id_to_unit) ~= "function" then
        return prefix .. " result=api-unavailable"
    end
    local sync_ok, sync = pcall(self.gs.unit_synchronizer, session)
    if not sync_ok or sync == nil then return prefix .. " result=no-synchronizer" end
    local link_ok, unit = pcall(self.synchronizer.game_object_id_to_unit,
        sync, sample.goid)
    if not link_ok then return prefix .. " result=link-error" end
    if unit == nil then return prefix .. " result=no-unit" end
    if type(self.units.alive) ~= "function" then
        return prefix .. " result=unit-alive-unavailable"
    end
    local alive_ok, alive = pcall(self.units.alive, unit)
    if not alive_ok or alive ~= true then return prefix .. " result=unit-not-alive" end
    local roundtrip = "unavailable"
    if type(self.synchronizer.unit_to_game_object_id) == "function" then
        local id_ok, id = pcall(self.synchronizer.unit_to_game_object_id, sync, unit)
        roundtrip = id_ok and tostring(id == sample.goid) or "error"
    end
    local name = "unavailable"
    if type(self.units.debug_name) == "function" then
        local name_ok, value = pcall(self.units.debug_name, unit)
        name = name_ok and type(value) == "string" and value:sub(1, 48) or "error"
    end
    return prefix .. " result=unit roundtrip=" .. roundtrip .. " name=" .. name
end

return UnitLinkProbe
