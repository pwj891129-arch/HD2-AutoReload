return function(equal)
    local Radial = dofile("radial.lua")
    Radial.Glyphs = dofile("dist/glyphs.generated.lua")
    local function vector(x, y, z) return {x = x, y = y, z = z} end
    local text, blocks, icons, triangles, width, height, x, y = {}, {}, {}, {}, 1280, 720, 0.5, 0.5
    local group, next_group = nil, 0
    local sr = {Vector2 = vector, Vector3 = vector, Color = function(...) return {...} end,
        Application = {worlds = function() return {2} end, can_get = function() return true end},
        Gui = {text = function() end, text_extents = function(_, value, _, size)
            local chars = 0; for _ in value:gmatch("[\1-\127\194-\244][\128-\191]*") do chars = chars + 1 end
            return vector(-0.2 * size, -0.7 * size), vector((chars * 0.55 - 0.2) * size, 0.3 * size)
        end, resolution = function() return width, height end},
        World = {destroy_gui = function() end}}
    local channel = {cursor = function() return x, y end}
    local radial = Radial.new(sr, channel)
    radial.gui, radial.world, radial.opened = 1, 2, true
    radial.icon_data = function(_, row) return {signature = row.kind} end
    radial.icon = function(_, index, _, px, py, size)
        icons[index] = {x = px - size / 2, y = py - size / 2, w = size, h = size}; return true
    end
    radial.clear = function(self) self.signature = nil; text, icons, triangles = {}, {}, {} end
    local draw_text = radial.text
    radial.text = function(self, ...)
        local previous = group; next_group = next_group + 1; group = next_group
        draw_text(self, ...); group = previous
    end
    radial.shape_on = function(_, _, kind, value, font, size, material, at)
        if kind == "triangle" then triangles[#triangles + 1] = {value, font, size}; return end
        if kind == "bitmap_uv" then
            text[#text + 1] = {value = "glyph", group = group, x = material.x, y = material.y, w = at.x, h = at.y}; return
        end
        assert(kind == "text")
        local lo, hi = sr.Gui.text_extents(1, value, font, size)
        text[#text + 1] = {value = value, group = group, x = at.x + lo.x, y = at.y + lo.y, w = hi.x - lo.x, h = hi.y - lo.y}
    end
    local function inside(box, point)
        return point.x >= box.x - 0.001 and point.x <= box.x + box.w + 0.001 and
            point.y >= box.y - 0.001 and point.y <= box.y + box.h + 0.001
    end
    local function corners(box)
        return {{x = box.x, y = box.y}, {x = box.x + box.w, y = box.y},
            {x = box.x, y = box.y + box.h}, {x = box.x + box.w, y = box.y + box.h}}
    end
    local function overlap(a, b)
        return a.x < b.x + b.w - 0.001 and b.x < a.x + a.w - 0.001 and
            a.y < b.y + b.h - 0.001 and b.y < a.y + a.h - 0.001
    end
    local names = {"ORBITAL 380MM HE BARRAGE", "EAGLE GAS AIRSTRIKE", "REINFORCEMENT BEACON", "LONGUNBROKENWEAPONNAME"}
    local native = false
    local debug_extents = sr.Gui.text_extents
    sr.Gui.text_extents = function(gui, value, font, size)
        if font == "native-korean" then
            local count = 0; for _ in value:gmatch("[\1-\127\194-\244][\128-\191]*") do count = count + 1 end
            return vector(-0.105 * size, -1.183 * size), vector((count * 0.9 + 0.125) * size, 0.065 * size)
        end
        return debug_extents(gui, value, font, size)
    end
    radial.text_style = function(self, value) return {text = value, font = "core/performance_hud/debug",
        material = "core/performance_hud/debug", gui = self.gui, bitmap = value:find("[\128-\255]") ~= nil} end
    local bitmap_style = radial.text_style
    radial.text_style = function(self, value)
        if native and value:find("[\128-\255]") then return {text = value, font = "native-korean", gui = self.gui} end
        return bitmap_style(self, value)
    end
    local korean = {"궤도 380mm 고폭 폭격", "이글 가스 공중타격", "증원", "중기관총"}
    for _, mode in ipairs({{names}, {korean}, {korean, true}}) do
    local labels = mode[1]; native = mode[2]
    for _, dimensions in ipairs({{320, 240}, {1280, 720}, {1920, 1080}, {2560, 1440}, {3840, 2160}}) do
        width, height = dimensions[1], dimensions[2]
        for count = 1, 16 do
            local inventory = {rows = {}}
            for index = 1, count do inventory.rows[index] = {kind = index, name = labels[(index - 1) % #labels + 1],
                status = index % 2 == 0 and "12345s" or "READY", slot = index <= 4 and index or nil, ready = true} end
            for _, scale in ipairs({1, 1.5, 2, 3, 4}) do
                radial.scale, radial.signature = scale, nil
                equal(radial:draw(inventory), true)
                local radius = count > 8 and 235 or 190
                local effective = math.min(scale, height / (2 * (radius + 104)), width / (2 * (radius + 76)))
                local inner, outer = 54 * effective, (radius + 64) * effective
                blocks = {}
                for index = 1, count do
                    local angle = math.pi / 2 - (index - 1) * 2 * math.pi / count
                    local dx, dy, bw, bh = Radial.content(count, inner, outer, angle, effective)
                    blocks[index] = {x = width / 2 + dx - bw / 2, y = height / 2 + dy - bh / 2, w = bw, h = bh}
                    local half = math.pi / count - 0.02
                    for _, p in ipairs(corners(blocks[index])) do
                        local px, py = p.x - width / 2, p.y - height / 2
                        local r = math.sqrt(px * px + py * py)
                        equal(r >= inner and r <= outer, true, "content rectangle stays inside the annulus")
                        local delta = (math.atan2(py, px) - angle + math.pi) % (2 * math.pi) - math.pi
                        equal(math.abs(delta) <= half, true, "content stays inside its own sector")
                    end
                    for _, p in ipairs(corners(icons[index])) do equal(inside(blocks[index], p), true, "larger icon inside its content block") end
                    equal(icons[index].w <= 84 * effective + 0.001, true, "icons grow to 84px when space permits")
                    if count <= 9 then equal(icons[index].w > 55 * effective, true, "normal wheel icons are visibly larger than the previous 44px cap") end
                end
                for _, item in ipairs(text) do
                    local owner
                    for index, box in ipairs(blocks) do
                        local fits = true; for _, p in ipairs(corners(item)) do fits = fits and inside(box, p) end
                        if fits then owner = index; break end
                    end
                    equal(owner ~= nil, true, "wrapped name/status/slot remains inside one sector")
                    for _, icon in ipairs(icons) do equal(overlap(item, icon), false, "text does not overlap an icon") end
                end
                for index, a in ipairs(text) do
                    for j = index + 1, #text do
                        if a.group ~= text[j].group then equal(overlap(a, text[j]), false, "name/status/slot labels including shadows do not overlap") end
                    end
                end
            end
        end
    end
    end
    native = false
    for index = 1, 9 do
        local angle = math.pi / 2 - (index - 1) * 2 * math.pi / 9
        local _, _, _, _, icon_size, name_size, status_size = Radial.content(9, 54, 299, angle, 1)
        equal(icon_size > 63, true, "readable names do not require shrinking normal nine-sector icons")
        equal(name_size >= 18, true, "normal nine-sector names have at least 18px nominal height")
        equal(status_size >= 12, true, "status remains readable at normal scale")
    end
    x, y, width, height = 0.5, 0.95, 1920, 1080
    radial.signature, radial.scale = nil, 1.5
    equal(radial:draw({rows = {{kind = 1, name = korean[1], status = "READY", ready = true}}}), true)
    equal(radial.selected, 1)
    local effective = math.min(1.5, height / (2 * (190 + 104)), width / (2 * (190 + 76)))
    local center = 54 * effective
    local centered = 0
    for _, item in ipairs(text) do
        if item.y < height / 2 + center and item.y + item.h > height / 2 - center then
            centered = centered + 1
            for _, p in ipairs(corners(item)) do
                equal((p.x - width / 2) ^ 2 + (p.y - height / 2) ^ 2 < center ^ 2, true,
                    "selected name stays in the wheel center instead of below/outside the wheel")
            end
        end
    end
    equal(centered > 0, true)
end
