local TankProbe = {}
TankProbe.__index = TankProbe

local function small_count(value)
    if type(value) == "boolean" then return value and "true" or "false" end
    if type(value) == "number" and value == math.floor(value) and
        value >= 0 and value <= 40 then return tostring(value) end
end

local function fields(value, prefix, depth, out)
    if type(value) ~= "table" or depth > 2 or #out >= 80 then return end
    local indexes = {}
    for index in pairs(value) do
        if type(index) == "number" and index >= 0 and index <= 512 and
            index == math.floor(index) then indexes[#indexes + 1] = index end
    end
    table.sort(indexes)
    for _, index in ipairs(indexes) do
        if #out >= 80 then break end
        local label = prefix .. tostring(index)
        local item = value[index]
        local count = small_count(item)
        if count then out[#out + 1] = label .. "=" .. count
        elseif type(item) == "table" then fields(item, label .. ".", depth + 1, out) end
    end
end

function TankProbe.new(game_session)
    return setmetatable({ gs = game_session, next_read = 0, lines = 0,
        page = 0, last = {} }, TankProbe)
end

function TankProbe:reset()
    self.next_read, self.lines, self.page, self.last = 0, 0, 0, {}
end

function TankProbe:read(session, peer, now, seat)
    if now < self.next_read or self.lines >= 120 then return nil end
    self.next_read = now + 0.25
    if type(self.gs.objects_owned_by) ~= "function" or
        type(self.gs.game_object_field_batched) ~= "function" then
        return "TANK_PROBE unavailable"
    end
    local ok, owned = pcall(self.gs.objects_owned_by, session, peer)
    if not ok or type(owned) ~= "table" then return "TANK_PROBE owned-unavailable" end
    local goids = {}
    for _, goid in pairs(owned) do
        if type(goid) == "number" and goid >= 0 then goids[#goids + 1] = goid end
    end
    table.sort(goids)
    local pages = math.max(1, math.ceil(#goids / 12))
    local page = self.page % pages
    self.page = (page + 1) % pages
    local chunks = {}
    for index = page * 12 + 1, math.min(#goids, (page + 1) * 12) do
        local goid = goids[index]
        local read_ok, raw = pcall(self.gs.game_object_field_batched, session, goid, {})
        if read_ok and type(raw) == "table" then
            local out = {}
            fields(raw, "", 1, out)
            chunks[#chunks + 1] = tostring(goid) .. "[" .. table.concat(out, ",") .. "]"
        end
    end
    local fields_text = table.concat(chunks, " ")
    local fingerprint = tostring(seat or "unknown") .. " " .. fields_text
    if fingerprint == self.last[page] then return nil end
    self.last[page] = fingerprint
    self.lines = self.lines + 1
    return string.format("TANK_PROBE t=%.1f seat_hint=%s owned=%d page=%d/%d %s", now,
        tostring(seat or "unknown"), #goids, page + 1, pages, fields_text)
end

return TankProbe
