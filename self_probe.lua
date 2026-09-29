local SelfProbe = {}
SelfProbe.__index = SelfProbe
local MAX_LINES = 600

local function scalar(value)
    if type(value) == "boolean" then return value end
    if type(value) == "number" and value == value and
        value > -10000 and value < 10000 then return value end
end

local function flatten(value, prefix, depth, out, budget)
    if type(value) ~= "table" or depth > 2 or budget.left <= 0 then return end
    local indexes = {}
    for index in pairs(value) do
        if type(index) == "number" and index >= 0 and index <= 512 and
            index == math.floor(index) then indexes[#indexes + 1] = index end
    end
    table.sort(indexes)
    for _, index in ipairs(indexes) do
        if budget.left <= 0 then break end
        local key = prefix .. tostring(index)
        local item = value[index]
        local count = scalar(item)
        if count ~= nil then
            out[key] = count
            budget.left = budget.left - 1
        elseif depth < 2 then
            flatten(item, key .. ".", depth + 1, out, budget)
        end
    end
end

local function changed(before, after)
    if type(before) ~= type(after) then return true end
    if type(after) == "boolean" then return before ~= after end
    if before == after then return false end
    if before == math.floor(before) and after == math.floor(after) then return true end
    return math.abs(after - before) >= 0.05
end

local function direct_fields(gs, session, goid)
    if type(gs.game_object_field) ~= "function" then return "" end
    local parts = {}
    for _, field in ipairs({ { "rounds", "4fqtox" }, { "slot0", "ip47m3" },
        { "trigger", "a70n1_" }, { "reloading", "gbgqot6" } }) do
        local ok, value = pcall(gs.game_object_field, session, goid, field[2])
        if ok and scalar(value) ~= nil then
            parts[#parts + 1] = field[1] .. "=" .. tostring(value)
        end
    end
    return table.concat(parts, ",")
end

function SelfProbe.new(gs)
    return setmetatable({ gs = gs, next_scan = 0, page = 0,
        seen = {}, lines = 0, fire = false, reload = false }, SelfProbe)
end

function SelfProbe:reset()
    self.next_scan, self.page, self.seen, self.lines = 0, 0, {}, 0
    self.fire, self.reload, self.event, self.baseline = false, false, nil, nil
end

function SelfProbe:read(session, peer, now, fire, manual_reload, slot)
    local lines = {}
    local fire_edge = fire and not self.fire
    local reload_edge = manual_reload and not self.reload
    self.fire, self.reload = fire == true, manual_reload == true
    if fire or manual_reload then
        self.event = { kind = manual_reload and "reload" or "fire", at = now }
    end
    if fire_edge or reload_edge then
        if self.lines < MAX_LINES then
            lines[#lines + 1] = string.format("SELF_INPUT t=%.2f kind=%s slot=%s", now,
                self.event.kind, tostring(slot))
            self.lines = self.lines + 1
        end
    end
    if self.lines >= MAX_LINES then return lines end
    local relevant = self.event and now - self.event.at <= 1.5
    if type(self.gs.objects_owned_by) ~= "function" or
        type(self.gs.game_object_field_batched) ~= "function" or
        now < self.next_scan then return lines end
    self.next_scan = now + ((relevant or not self.baseline) and 0.08 or 0.3)
    local ok, owned = pcall(self.gs.objects_owned_by, session, peer)
    if not ok or type(owned) ~= "table" then return lines end
    local goids = {}
    for _, goid in pairs(owned) do
        if type(goid) == "number" and goid >= 0 and goid == math.floor(goid) then
            goids[#goids + 1] = goid
        end
    end
    table.sort(goids)
    local pages = math.max(1, math.ceil(#goids / 24))
    local page = self.page % pages
    self.page = (page + 1) % pages
    local logged = 0
    for index = page * 24 + 1, math.min(#goids, (page + 1) * 24) do
        local goid = goids[index]
        local read_ok, raw = pcall(self.gs.game_object_field_batched,
            session, goid, {})
        if read_ok and type(raw) == "table" then
            local fields = {}
            flatten(raw, "", 1, fields, { left = 160 })
            local previous = self.seen[goid]
            self.seen[goid] = { fields = fields, at = now }
            if relevant and previous and now - previous.at <= 10 and
                logged < 4 and self.lines < MAX_LINES then
                local changes, deltas = {}, {}
                for key, value in pairs(fields) do
                    local before = previous.fields[key]
                    if before ~= nil and changed(before, value) then
                        local priority = type(value) == "boolean" and 3 or
                            (type(before) == "number" and
                                value == math.floor(value) and before == math.floor(before) and
                                value < before) and 2 or 1
                        changes[#changes + 1] = { key = key, before = before,
                            value = value, priority = priority }
                    end
                end
                table.sort(changes, function(a, b)
                    if a.priority ~= b.priority then return a.priority > b.priority end
                    return a.key < b.key
                end)
                for i = 1, math.min(#changes, 12) do
                    local one = changes[i]
                    deltas[#deltas + 1] = one.key .. ":" ..
                        tostring(one.before) .. ">" .. tostring(one.value)
                end
                if #deltas > 0 then
                    lines[#lines + 1] = string.format(
                        "SELF_DELTA t=%.2f kind=%s slot=%s goid=%d fields=%s direct=%s",
                        now, self.event.kind, tostring(slot), goid,
                        table.concat(deltas, ","), direct_fields(self.gs, session, goid))
                    self.lines = self.lines + 1
                    logged = logged + 1
                end
            end
        end
    end
    if self.page == 0 then
        local owned_set = {}
        for _, goid in ipairs(goids) do owned_set[goid] = true end
        for goid in pairs(self.seen) do
            if not owned_set[goid] then self.seen[goid] = nil end
        end
    end
    if not self.baseline and self.page == 0 and #goids > 0 then
        self.baseline = true
        lines[#lines + 1] = string.format("SELF_BASELINE t=%.2f owned=%d", now, #goids)
    end
    return lines
end

return SelfProbe
