local Radial = dofile("stratagem/radial.lua")
Radial.Glyphs = dofile("stratagem/dist/glyphs.generated.lua")
local calls, id = {}, 0
local function vector(x, y, z, w) return {x = x, y = y, z = z, w = w} end
local function record(kind, args) id = id + 1; calls[#calls + 1] = {kind = kind, args = args}; return id end
local sr = {Vector2 = vector, Vector3 = vector, Vector4 = vector, Color = function(...) return {...} end,
    IdString64 = {from_hex = function(value) return value end},
    Application = {can_get = function() return true end, worlds = function() return {2} end},
    World = {create_screen_gui = function() return 3 end},
    Material = {set_texture = function() end, set_vector4 = function() end},
    Gui = {resolution = function() return 1280, 720 end, material = function() return 4 end,
        destroy_bitmap = function() end, bitmap_uv = function(_, ...) return record("glyph", {...}) end,
        triangle = function(_, ...) return record("triangle", {...}) end,
        text_extents = function(_, text, _, size) return vector(0, 0), vector(#text * size * 0.5, size) end,
        text = function(_, ...) return record("text", {...}) end},
}
local radial = Radial.new(sr, {cursor = function() return 0.5, 0.5 end}, 1.5)
radial.gui, radial.world, radial.opened = 1, 2, true
radial.clear = function() calls = {} end
radial.icon_data = function(_, row) return {signature = row.kind} end
radial.icon = function(_, index, _, x, y, size, color)
    record("icon", {index, x, y, size, color}); return true
end
local rows = {
    {kind = 124, name = "증원"}, {kind = 145, name = "SOS 신호기"}, {kind = 33, name = "재보급"},
    {kind = 128, name = "데이터 업로드"}, {kind = 56, name = "레일건", slot = 1},
    {kind = 101, name = "보급 팩", slot = 2}, {kind = 121, name = "기관총 센트리", slot = 3},
    {kind = 88, name = "돌파구 엑소슈트", slot = 4}, {kind = 50, name = "마엘스트롬"},
}
for index, row in ipairs(rows) do
    row.ready, row.status, row.name_english = index ~= 5, index == 5 and "399s" or "READY", "STRATAGEM"
end
assert(radial:draw({rows = rows}))
local function json(value)
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    if type(value) == "string" then return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
    local output = {}
    if #value > 0 then
        for _, item in ipairs(value) do output[#output + 1] = json(item) end
        return "[" .. table.concat(output, ",") .. "]"
    end
    for key, item in pairs(value) do output[#output + 1] = json(key) .. ":" .. json(item) end
    return "{" .. table.concat(output, ",") .. "}"
end
local file = assert(io.open("dist/wheel-preview.json", "wb"))
file:write(json({width = 1280, height = 720, calls = calls, rows = rows})); file:close()
print("PASS exported actual Lua geometry and Korean glyph UVs for offline visual verification")
