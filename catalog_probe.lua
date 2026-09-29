local CatalogProbe = {}
CatalogProbe.__index = CatalogProbe

local function describe(ok, value)
    if not ok then return "error" end
    if value == nil then return "nil" end
    if type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end
    return type(value)
end

function CatalogProbe.new(gs, network, ids, synchronizer, units)
    return setmetatable({ gs = gs or {}, network = network or {}, ids = ids or {},
        synchronizer = synchronizer or {}, units = units or {}, done = false }, CatalogProbe)
end

function CatalogProbe:reset()
    self.done = false
end

function CatalogProbe:read(session, sample)
    if self.done or type(sample) ~= "table" or not sample.goid or
        type(sample.type_hash) ~= "string" then return nil end
    self.done = true
    local hash = sample.type_hash:match("^0x(%x%x%x%x%x%x%x%x)$")
    if not hash or type(self.ids.from_hex) ~= "function" then
        return "CATALOG_API id32=unavailable"
    end
    local made, type_id = pcall(self.ids.from_hex, hash)
    if not made or type_id == nil then return "CATALOG_API id32=error" end
    local type_ok, type_value = false, nil
    if type(self.gs.game_object_is_type) == "function" then
        type_ok, type_value = pcall(self.gs.game_object_is_type,
            session, sample.goid, type_id)
    end
    local info_ok, info_value = false, nil
    if type(self.network.object_info) == "function" then
        info_ok, info_value = pcall(self.network.object_info, type_id)
    end
    local field_ok, field_value = false, nil
    local string_ok, string_value = false, nil
    if type(self.gs.game_object_field) == "function" then
        local field_made, field_id = pcall(self.ids.from_hex, "d7a5d63e")
        if field_made and field_id ~= nil then
            field_ok, field_value = pcall(self.gs.game_object_field,
                session, sample.goid, field_id)
        end
        string_ok, string_value = pcall(self.gs.game_object_field,
            session, sample.goid, "4fqtox")
    end
    local unit_status = "unavailable"
    if type(self.gs.unit_synchronizer) == "function" and
        type(self.synchronizer.game_object_id_to_unit) == "function" then
        local sync_ok, sync = pcall(self.gs.unit_synchronizer, session)
        if sync_ok and sync ~= nil then
            local unit_ok, unit = pcall(self.synchronizer.game_object_id_to_unit,
                sync, sample.goid)
            unit_status = describe(unit_ok, unit)
            if unit_ok and unit ~= nil and type(self.units.debug_name) == "function" then
                local name_ok, name = pcall(self.units.debug_name, unit)
                unit_status = unit_status .. ":" .. describe(name_ok, name)
                if name_ok and type(name) == "string" then
                    unit_status = unit_status .. ":" .. name:sub(1, 32)
                end
            end
        end
    end
    return "CATALOG_API type_hex=" .. describe(type_ok, type_value) ..
        " info_hex=" .. describe(info_ok, info_value) ..
        " field_hex=" .. describe(field_ok, field_value) ..
        " field_string=" .. describe(string_ok, string_value) ..
        " unit_link=" .. unit_status ..
        " goid=" .. tostring(sample.goid) .. " type=" .. sample.type_hash
end

return CatalogProbe
