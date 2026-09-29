local Discovery = {}
Discovery.__index = Discovery

local PAGE_SIZE, MAX_OBJECTS, MAX_FIELDS = 12, 512, 80

local function scalar(value)
    local kind = type(value)
    return kind == "boolean" or (kind == "number" and value == value and
        value > -math.huge and value < math.huge)
end

local function flatten(value, prefix, depth, out, count)
    if type(value) ~= "table" or depth > 2 or count.n >= MAX_FIELDS then return end
    local indexes = {}
    for index in pairs(value) do
        if type(index) == "number" and index >= 0 and index <= 512 and
            index == math.floor(index) then indexes[#indexes + 1] = index end
    end
    table.sort(indexes)
    for _, index in ipairs(indexes) do
        if count.n >= MAX_FIELDS then break end
        local item, label = value[index], prefix .. tostring(index)
        if scalar(item) then
            out[label] = item
            count.n = count.n + 1
        elseif type(item) == "table" then
            flatten(item, label .. ".", depth + 1, out, count)
        end
    end
end

local function owned_ids(gs, session, peer)
    if type(gs.objects_owned_by) ~= "function" or
        type(gs.game_object_field_batched) ~= "function" then
        return nil, "api-unavailable"
    end
    local ok, owned = pcall(gs.objects_owned_by, session, peer)
    if not ok or type(owned) ~= "table" then return nil, "owned-unavailable" end
    local ids, seen = {}, {}
    for _, goid in pairs(owned) do
        if type(goid) == "number" and goid >= 0 and goid == math.floor(goid) and
            not seen[goid] then
            seen[goid] = true
            ids[#ids + 1] = goid
        end
    end
    table.sort(ids)
    if #ids == 0 then return nil, "no-owned-objects" end
    if #ids > MAX_OBJECTS then return nil, "too-many-owned=" .. #ids end
    return ids
end

function Discovery.new(gs)
    return setmetatable({ gs = gs or {}, phase = "idle" }, Discovery)
end

function Discovery:reset()
    self.phase, self.scan, self.baseline = "idle", nil, nil
    self.known_goid, self.known_type, self.baseline_count = nil, nil, nil
end

function Discovery:request(session, peer, sample, reason)
    if self.phase == "baseline" or self.phase == "compare" then
        return "DISCOVERY skipped=busy"
    end
    local phase = self.phase == "ready" and "compare" or "baseline"
    if phase == "baseline" then
        if not sample or sample.active ~= true or not sample.goid or
            not sample.slot or sample.seated_fire then
            return "DISCOVERY skipped=hold-recognized-weapon-first"
        end
        self.known_goid, self.known_type = sample.goid, sample.type_hash
    elseif not sample or sample.grip ~= 70 or type(reason) ~= "string" or
        not reason:find("^no%-on%-body%-object%-of%-grip=70") then
        return "DISCOVERY skipped=hold-unrecognized-grip70-weapon-second"
    end
    local ids, failure = owned_ids(self.gs, session, peer)
    if not ids then return "DISCOVERY skipped=" .. failure end
    self.scan = { ids = ids, index = 1, values = {}, errors = 0, next_read = 0 }
    self.phase = phase
    return "DISCOVERY " .. phase .. "-start owned=" .. #ids ..
        " known_goid=" .. tostring(self.known_goid) ..
        " known_type=" .. tostring(self.known_type)
end

local function compare(before, after)
    local rows, seen = {}, {}
    for goid in pairs(before) do seen[goid] = true end
    for goid in pairs(after) do seen[goid] = true end
    for goid in pairs(seen) do
        local old, new = before[goid], after[goid]
        local changes, fields = {}, {}
        if old then for field in pairs(old) do fields[field] = true end end
        if new then for field in pairs(new) do fields[field] = true end end
        for field in pairs(fields) do
            local a, b = old and old[field], new and new[field]
            if a ~= b then
                changes[#changes + 1] = field .. ":" .. tostring(a) .. ">" .. tostring(b)
            end
        end
        table.sort(changes)
        if not old or not new or #changes > 0 then
            rows[#rows + 1] = { goid = goid, count = #changes,
                state = not old and "added" or not new and "removed" or "changed",
                fields = changes }
        end
    end
    table.sort(rows, function(a, b)
        if a.state ~= b.state then
            if a.state == "added" then return true end
            if b.state == "added" then return false end
            if a.state == "removed" then return true end
            if b.state == "removed" then return false end
        end
        if a.count ~= b.count then return a.count > b.count end
        return a.goid < b.goid
    end)
    return rows
end

function Discovery:step(session, now)
    local scan = self.scan
    if not scan or now < scan.next_read then return nil end
    scan.next_read = now + 0.25
    for _ = 1, PAGE_SIZE do
        local goid = scan.ids[scan.index]
        if not goid then break end
        scan.index = scan.index + 1
        local ok, raw = pcall(self.gs.game_object_field_batched, session, goid, {})
        if ok and type(raw) == "table" then
            local fields = {}
            flatten(raw, "", 1, fields, { n = 0 })
            scan.values[goid] = fields
        else
            scan.errors = scan.errors + 1
        end
    end
    if scan.index <= #scan.ids then return nil end
    self.scan = nil
    local lines = {}
    if self.phase == "baseline" then
        self.baseline = scan.values
        self.baseline_count = #scan.ids
        self.phase = "ready"
        lines[1] = "DISCOVERY baseline-ready objects=" .. #scan.ids ..
            " readable=" .. tostring(#scan.ids - scan.errors) ..
            " errors=" .. scan.errors .. " known_goid=" .. tostring(self.known_goid)
    else
        self.phase = "done"
        local rows = compare(self.baseline or {}, scan.values)
        lines[1] = "DISCOVERY compare-ready before=" ..
            tostring(self.baseline_count or 0) .. " after=" .. #scan.ids ..
            " changed=" .. #rows ..
            " errors=" .. scan.errors .. " known_goid=" .. tostring(self.known_goid)
        for index = 1, math.min(#rows, 24) do
            local row = rows[index]
            local shown = {}
            for field = 1, math.min(#row.fields, 6) do
                shown[#shown + 1] = row.fields[field]
            end
            lines[#lines + 1] = "DISCOVERY candidate goid=" .. row.goid ..
                " state=" .. row.state .. " changes=" .. row.count ..
                " fields=" .. table.concat(shown, ",")
        end
    end
    return lines
end

return Discovery
