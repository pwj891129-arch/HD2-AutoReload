local HashTypeProbe = {}
HashTypeProbe.__index = HashTypeProbe

function HashTypeProbe.new(gs, ids)
    return setmetatable({ gs = gs or {}, ids = ids or {}, done = false }, HashTypeProbe)
end

function HashTypeProbe:reset()
    self.done = false
end

function HashTypeProbe:read(session, sample, known_call)
    if self.done then return "HASH_TYPE already-checked" end
    if not session or type(sample) ~= "table" or sample.active ~= true or
        sample.seated_fire or not sample.goid or not sample.slot or
        type(known_call) ~= "string" then
        return "HASH_TYPE skipped=no-recognized-held-weapon"
    end
    local hash = type(sample.type_hash) == "string" and
        sample.type_hash:match("^0x(%x%x%x%x%x%x%x%x)$")
    if not hash then return "HASH_TYPE skipped=no-type-hash" end
    local prefix = "HASH_TYPE goid=" .. tostring(sample.goid) ..
        " slot=" .. sample.slot .. " type=0x" .. hash
    if type(self.gs.game_object_is_type) ~= "function" then
        return prefix .. " baseline=unavailable hash=not-run"
    end
    local baseline_ok, baseline = pcall(self.gs.game_object_is_type,
        session, sample.goid, known_call)
    if not baseline_ok or baseline ~= true then
        return prefix .. " baseline=" .. (baseline_ok and tostring(baseline) or "error") ..
            " hash=not-run"
    end
    self.done = true
    if type(self.ids.from_hex) ~= "function" then
        return prefix .. " baseline=true hash=api-unavailable"
    end
    local made, type_id = pcall(self.ids.from_hex, hash)
    if not made or type_id == nil then
        return prefix .. " baseline=true hash=id-error"
    end
    local checked, matched = pcall(self.gs.game_object_is_type,
        session, sample.goid, type_id)
    return prefix .. " baseline=true hash=" ..
        (checked and tostring(matched) or "error")
end

return HashTypeProbe
