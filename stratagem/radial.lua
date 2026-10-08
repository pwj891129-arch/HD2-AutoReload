local Radial = {}
Radial.__index = Radial
local ICON_MATERIAL, ICON_SLOT = "c0f3797849262087", "3aa8b87e00000000"
local ICON_COLORS = {"28723f4d00000000", "851fd4fd00000000", "10c353af00000000"}
local FONT_MATERIAL, FONT_SLOT = "content/fonts/core_sans", "88bac99b00000000"
local KOREAN_FONTS = {
    {font = "e007454455e2d2bb", atlas = "8d346dcdd08459d5"},
    {font = "fca7631255290a2c", atlas = "9ae590aec7c63b1c"},
}
-- @GLYPHS@
function Radial.new(sr, channel, scale, trace, direction)
    return setmetatable({sr = sr, channel = channel, scale = scale or 1,
        direction = direction == "clockwise" and "clockwise" or "counterclockwise",
        ids = {}, icons = {}, fonts = {}, icon_reasons = {}, trace = trace}, Radial)
end
function Radial:dimensions()
    -- Gui.resolution accepts an optional viewport, never a Gui object.
    local width, height = self.sr.Gui.resolution()
    if type(width) == "number" and type(height) == "number" and
        width >= 320 and height >= 240 and width <= 32768 and height <= 32768 then
        return width, height
    end
end
function Radial.angle(index, count, direction)
    local sign = direction == "clockwise" and -1 or 1
    return math.pi / 2 + sign * (index - 0.5) * 2 * math.pi / count
end
function Radial.pick(x, y, width, height, count, scale, direction)
    if not x or not y or count < 1 then return nil end
    local dx, dy = (x - 0.5) * width, (y - 0.5) * height
    if dx * dx + dy * dy < (38 * scale) ^ 2 then return nil end
    local sign = direction == "clockwise" and -1 or 1
    local angle = (sign * (math.atan2(dy, dx) - math.pi / 2)) % (2 * math.pi)
    return math.floor(angle / (2 * math.pi / count)) % count + 1
end
function Radial:world_live(world)
    local worlds = self.sr.Application.worlds()
    for _, value in pairs(worlds or {}) do if value == world then return true end end
    return false
end
function Radial:clear()
    local shapes = #self.ids > 0
    if not shapes then
        for _, icon in pairs(self.icons) do if icon.id ~= nil then shapes = true; break end end
    end
    local live = shapes and self.gui and self:world_live(self.world)
    -- Remove each successful deletion immediately so a retry never destroys it twice.
    for index = #self.ids, 1, -1 do
        local item = self.ids[index]
        if live then self.sr.Gui["destroy_" .. item[1]](item[3] or self.gui, item[2]) end
        self.ids[index] = nil
    end
    for _, icon in pairs(self.icons) do
        if live and icon.id ~= nil then self.sr.Gui.destroy_bitmap(icon.gui, icon.id) end
        icon.id = nil
    end
    self.signature = nil
end
function Radial:restore()
    if self.mouse and self.channel.foreground() then
        self.channel.center_cursor()
        self.sr.Window.set_show_cursor(self.mouse.show)
        self.sr.Window.set_mouse_focus(self.mouse.focus)
        self.mouse = nil
    end
end
function Radial:close()
    self.opened, self.selected, self.inventory = false, nil, nil
    local good, why = pcall(function()
        self:clear()
        if (next(self.icons) or next(self.fonts)) and self.gui and self:world_live(self.world) then
            for _, icon in pairs(self.icons) do
                if icon.gui then self.sr.World.destroy_gui(self.world, icon.gui); icon.gui = nil end
            end
            for _, font in pairs(self.fonts) do
                if font.gui then self.sr.World.destroy_gui(self.world, font.gui); font.gui = nil end
            end
        end
    end)
    if good then
        if next(self.icons) then self.icons = {} end
        if next(self.fonts) then self.fonts = {} end
    end
    if next(self.icon_reasons) then self.icon_reasons = {} end
    self.icon_report = nil
    self.glyph_failed = nil
    self.native_font_failed = nil
    self.native_font_error, self.native_fallback_report, self.measure_error = nil, nil, nil
    self:restore()
    if not good then error(why) end
end
function Radial:dispose()
    self:close()
    if self.gui and self:world_live(self.world) then
        self.sr.World.destroy_gui(self.world, self.gui)
    end
    self.gui, self.world = nil, nil
end
local function image_resource(sr, kind, hex, resources)
    local key = kind .. ":" .. hex
    local cached = resources and resources[key]
    if cached then return unpack(cached, 1, 4) end
    local ok, id = pcall(sr.IdString64.from_hex, hex)
    local queried, available
    if ok and id then queried, available = pcall(sr.Application.can_get, kind, id) end
    if resources then resources[key] = {ok, id, queried, available} end
    return ok, id, queried, available
end
function Radial:icon_data(row, resources)
    local sr = self.sr
    local picture, art = row.picture, row.art
    if type(picture) ~= "string" or #picture ~= 16 or not picture:match("^[0-9a-fA-F]+$") or
        picture == "0000000000000000" then return nil, "invalid-reference" end
    if type(art) ~= "table" then return nil, row.art_error or "image-metadata-unavailable" end
    if type(art.texture) ~= "string" or #art.texture ~= 16 or not art.texture:match("^[0-9a-fA-F]+$") or
        art.texture == "0000000000000000" or type(art.uv) ~= "table" or type(art.colors) ~= "table" then
        return nil, "image-metadata-invalid"
    end
    local uv = art.uv
    for index = 1, 4 do
        if type(uv[index]) ~= "number" or uv[index] ~= uv[index] or uv[index] < 0 or uv[index] > 1 then
            return nil, "image-uv-invalid"
        end
    end
    if uv[1] >= uv[3] or uv[2] >= uv[4] then return nil, "image-uv-invalid" end
    local signature = {picture, art.texture, table.concat(uv, ",")}
    for index = 1, 3 do
        local colour = art.colors[index]
        if type(colour) ~= "table" then return nil, "image-colors-invalid" end
        for component = 1, 4 do
            local value = colour[component]
            if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
                return nil, "image-colors-invalid"
            end
        end
        signature[#signature + 1] = table.concat(colour, ",")
    end
    if not sr.Gui.bitmap_uv or not sr.Gui.destroy_bitmap then return nil, "bitmap-api-unavailable" end
    if not sr.Gui.material or not sr.Material or not sr.Material.set_texture or
        not sr.Material.set_vector4 or not sr.Vector4 then return nil, "image-material-api-unavailable" end
    if not sr.IdString64 or not sr.IdString64.from_hex then return nil, "idstring-api-unavailable" end
    local ok, material, queried, available = image_resource(sr, "material", ICON_MATERIAL, resources)
    if not ok or not material then return nil, "material-id-failed:" .. tostring(material) end
    if not queried then return nil, "material-query-failed:" .. tostring(available) end
    if available ~= true then return nil, "native-mask-material-unavailable" end
    local texture_ok, texture, texture_queried, texture_available = image_resource(sr, "texture", art.texture, resources)
    if not texture_ok or not texture then return nil, "texture-id-failed:" .. tostring(texture) end
    if not texture_queried or texture_available ~= true then return nil, "native-atlas-unavailable" end
    return {picture = picture, material = material, texture = texture, art = art,
        signature = table.concat(signature, "|")}, "ready"
end
function Radial:icon(index, data, x, y, size, colour)
    if not data then return false end
    local sr = self.sr
    local good, why = pcall(function()
        local icon = self.icons[index]
        if not icon then
            icon = {}
            self.icons[index] = icon
            local gui = sr.World.create_screen_gui(self.world, "scale", 1, 1)
            if not gui or gui == 0 then error("icon-gui-unavailable") end
            icon.gui = gui
            local material = sr.Gui.material(icon.gui, data.material)
            if not material or material == 0 then error("icon-material-unavailable") end
            icon.material = material
        end
        if not icon.material then error("icon-material-unavailable") end
        if icon.signature ~= data.signature then
            sr.Material.set_texture(icon.material, sr.IdString64.from_hex(ICON_SLOT), data.texture)
            for channel = 1, 3 do
                local c = data.art.colors[channel]
                -- These are raw shader vector components, not Color()'s ARGB conversion.
                sr.Material.set_vector4(icon.material, sr.IdString64.from_hex(ICON_COLORS[channel]),
                    sr.Vector4(c[1], c[2], c[3], c[4]))
            end
            icon.signature = data.signature
        end
        local uv = data.art.uv
        local id = sr.Gui.bitmap_uv(icon.gui, data.material, sr.Vector2(uv[1], uv[2]),
            sr.Vector2(uv[3], uv[4]), sr.Vector3(x - size / 2, y - size / 2, 11),
            sr.Vector2(size, size), colour)
        if id == nil then error("icon-bitmap-unavailable") end
        icon.id = id
    end)
    if not good then return false, "image-draw-failed:" .. tostring(why) end
    return true
end
function Radial:open(inventory)
    local sr, app, win = self.sr, self.sr.Application, self.sr.Window
    local function stage(name) if self.trace then self.trace("OVERLAY stage=" .. name) end end
    if not app or not sr.Gui or not sr.World or not win or not sr.Vector3 or not sr.Vector2 or not sr.Color or
        not win.set_mouse_focus or not win.mouse_focus or not win.show_cursor or
        not win.set_show_cursor or not self.channel.cursor or not self.channel.center_cursor or
        not app.worlds or not app.main_world or not app.can_get or
        not sr.World.create_screen_gui or not sr.World.destroy_gui or not sr.Gui.resolution or
        not sr.Gui.triangle or not sr.Gui.destroy_triangle or not sr.Gui.text or
        not sr.Gui.text_extents or not sr.Gui.destroy_text then return false, "overlay-api-unavailable" end
    if not inventory or type(inventory.rows) ~= "table" or #inventory.rows < 1 or #inventory.rows > 16 then
        return false, "overlay-inventory-unavailable"
    end
    stage("resources")
    if not app.can_get("font", "core/performance_hud/debug") then
        return false, "overlay-font-unavailable"
    end
    if not app.can_get("material", "core/performance_hud/debug") then
        return false, "overlay-material-unavailable"
    end
    stage("dimensions")
    local width, height = self:dimensions()
    if not width then return false, "overlay-resolution-unavailable" end
    self.width, self.height = width, height
    if self.mouse then self:restore(); if self.mouse then return false, "cursor-restore-pending" end end
    stage("world")
    local main, target = app.main_world(), nil
    for _, world in pairs(app.worlds() or {}) do if world ~= main then target = world; break end end
    if not target then return false, "overlay-world-unavailable" end
    if self.world ~= target or not self.gui or not self:world_live(self.world) then
        self:dispose()
        stage("create-gui")
        self.gui = sr.World.create_screen_gui(target, "scale", 1, 1)
        if not self.gui or self.gui == 0 then self.gui = nil; return false, "overlay-gui-unavailable" end
        self.world = target
    end
    stage("cursor")
    self.mouse = {show = win.show_cursor(), focus = win.mouse_focus()}
    if type(self.mouse.show) ~= "boolean" or type(self.mouse.focus) ~= "boolean" then
        self.mouse = nil; return false, "cursor-state-unavailable"
    end
    win.set_mouse_focus(false)
    win.set_show_cursor(true)
    if not self.channel.center_cursor() then self:close(); return false, "cursor-center-failed" end
    self.inventory, self.opened = inventory, true
    stage("draw")
    if not self:draw(inventory) then self:close(); return false, "overlay-surface-unavailable" end
    stage("ready")
    return true
end
function Radial:shape(kind, ...)
    return self:shape_on(self.gui, kind, ...)
end
function Radial:shape_on(gui, kind, ...)
    local id = self.sr.Gui[kind](gui, ...)
    if id == nil then error("overlay-" .. kind .. "-failed") end
    self.ids[#self.ids + 1] = {kind == "bitmap_uv" and "bitmap" or kind, id, gui}
end
function Radial:glyph_resources()
    local sr = self.sr
    local data = Radial.Glyphs
    if not data or not sr.Gui.bitmap_uv or not sr.Gui.destroy_bitmap or not sr.Vector4 then return end
    if not sr.IdString64 or not sr.IdString64.from_hex or not sr.Material or not sr.Material.set_texture or
        not sr.Material.set_vector4 or not sr.Gui.material then return end
    local ok, atlas, material = pcall(function()
        local atlas, material = sr.IdString64.from_hex(data.texture), sr.IdString64.from_hex(ICON_MATERIAL)
        if sr.Application.can_get("texture", atlas) and sr.Application.can_get("material", material) then
            return atlas, material
        end
    end)
    if ok then return atlas, material end
end
function Radial:native_font_resources(spec)
    local sr = self.sr
    if not sr.IdString64 or not sr.IdString64.from_hex or not sr.Gui.has_all_glyphs or
        not sr.Gui.material or not sr.Material or not sr.Material.set_texture then return end
    local good, resource, atlas = pcall(function()
        local resource, atlas = sr.IdString64.from_hex(spec.font), sr.IdString64.from_hex(spec.atlas)
        if sr.Application.can_get("font", resource) == true and sr.Application.can_get("texture", atlas) == true and
            sr.Application.can_get("material", FONT_MATERIAL) == true then return resource, atlas end
    end)
    if good then return resource, atlas end
end
function Radial:native_text_style(text)
    local sr = self.sr
    if self.native_font_failed or not sr.IdString64 or not sr.IdString64.from_hex or
        not sr.Gui.has_all_glyphs or not sr.Gui.material or not sr.Material or not sr.Material.set_texture then return end
    for _, spec in ipairs(KOREAN_FONTS) do
        local good, style = pcall(function()
            local resource, atlas = self:native_font_resources(spec)
            if not resource or sr.Gui.has_all_glyphs(self.gui, text, resource) ~= true then return end
            local font = self.fonts[spec.font]
            if not font then font = {}; self.fonts[spec.font] = font end
            if not font.gui then
                font.gui = sr.World.create_screen_gui(self.world, "scale", 1, 1)
                if not font.gui or font.gui == 0 then font.gui = nil; error("font-gui-unavailable") end
            end
            if not font.material then
                local instance = sr.Gui.material(font.gui, FONT_MATERIAL)
                if not instance or instance == 0 then error("font-material-unavailable") end
                sr.Material.set_texture(instance, sr.IdString64.from_hex(FONT_SLOT), atlas)
                font.material = instance
            end
            -- Resolve the same GUI-local resource that was bound above, as bitmap_uv does.
            -- Do not pass a Material pointer through the game's text resource argument.
            return {text = text, font = resource, material = FONT_MATERIAL, gui = font.gui, native = spec}
        end)
        if good and style then return style end
        if not good and self.native_font_error ~= tostring(style) then
            self.native_font_error = tostring(style)
            if self.trace then self.trace("OVERLAY native-font-bind-failed " .. self.native_font_error:gsub("[\r\n]", " ")) end
        end
        if not good then self.native_font_failed = true; return end
    end
end
function Radial:text_style(text, fallback)
    local sr, debug = self.sr, "core/performance_hud/debug"
    if text:find("[\128-\255]") then
        local native = self:native_text_style(text)
        if native then return native end
        if not self.native_fallback_report and self.trace then
            self.native_fallback_report = true
            self.trace("OVERLAY native-font-fallback reason=" ..
                (self.native_font_failed and "native-call-failed" or "native-resources-or-glyph-coverage-unavailable"))
        end
        local atlas, material = self:glyph_resources()
        local good, result = pcall(function()
            if not atlas or self.glyph_failed then return end
            for char in text:gmatch("[\1-\127\194-\244][\128-\191]*") do
                if not Radial.Glyphs.glyphs[char] then return end
            end
            local font = self.fonts.glyphs
            if not font then font = {}; self.fonts.glyphs = font end
            if not font.gui then
                font.gui = sr.World.create_screen_gui(self.world, "scale", 1, 1)
                if not font.gui or font.gui == 0 then font.gui = nil; error("font-gui-unavailable") end
            end
            if not font.material then
                local instance = sr.Gui.material(font.gui, material)
                if not instance or instance == 0 then error("font-material-unavailable") end
                -- Raster glyphs use the same proven native mask-bitmap path as wheel icons.
                -- No native font selection, MSDF shader or game language resources are involved.
                sr.Material.set_texture(instance, sr.IdString64.from_hex(ICON_SLOT), atlas)
                for index = 1, 3 do
                    local v = index == 1 and 1 or 0
                    sr.Material.set_vector4(instance, sr.IdString64.from_hex(ICON_COLORS[index]), sr.Vector4(v, v, v, v))
                end
                font.material = instance
                if self.trace then self.trace("OVERLAY glyph-source atlas=" .. Radial.Glyphs.texture .. " renderer=mask-bitmap") end
            end
            return {text = text, font = "wheel-glyphs", bitmap = true, material = material, gui = font.gui}
        end)
        if good and result then return result end
        if not good and self.font_error ~= tostring(result) then
            self.font_error = tostring(result)
            if self.trace then self.trace("OVERLAY glyph-bind-failed " .. self.font_error:gsub("[\r\n]", " ")) end
        end
        if not self.font_warning and self.trace then self.trace("OVERLAY Korean glyph atlas unavailable; English fallback") end
        self.font_warning = true
        text = fallback or "STRATAGEM"
    end
    return {text = text, font = debug, material = debug, gui = self.gui}
end
function Radial:measure(style, size)
    local lo, hi
    if style.bitmap then
        local factor, pen, left, bottom, right, top = size / Radial.Glyphs.base, 0, math.huge, math.huge, -math.huge, -math.huge
        for char in style.text:gmatch("[\1-\127\194-\244][\128-\191]*") do
            local g = Radial.Glyphs.glyphs[char]
            if not g then error("glyph-unavailable") end
            if g[3] > 0 and g[4] > 0 then
                left, bottom = math.min(left, pen + g[5]), math.min(bottom, g[6])
                right, top = math.max(right, pen + g[5] + g[3]), math.max(top, g[6] + g[4])
            end
            pen = pen + g[7]
        end
        lo, hi = {x = left * factor, y = bottom * factor}, {x = right * factor, y = top * factor}
    else
        lo, hi = self.sr.Gui.text_extents(style.gui, style.text, style.font, size)
    end
    for _, value in ipairs({lo.x, lo.y, hi.x, hi.y}) do
        if value ~= value or math.abs(value) > 100000 then error("font-extents-invalid") end
    end
    local width, height = hi.x - lo.x, hi.y - lo.y
    if width ~= width or height ~= height or width <= 0 or height <= 0 or
        width > 100000 or height > 100000 then error("font-extents-invalid") end
    return lo, hi, width, height
end
function Radial:text(text, x, y, size, colour, maximum_width, fallback, maximum_height, shadow)
    local sr, style = self.sr, self:text_style(text, fallback)
    shadow = shadow or 0
    if (not style.bitmap and not sr.Application.can_get("font", style.font)) or
        not sr.Gui.text or not sr.Gui.text_extents then return end
    local limit = math.min(self.width - 40, maximum_width or self.width) - shadow
    local good, lo, hi, width, height = pcall(self.measure, self, style, size)
    if not good then
        if style.font == "core/performance_hud/debug" then return end
        if self.measure_error ~= tostring(lo) then
            self.measure_error = tostring(lo)
            if self.trace then self.trace("OVERLAY font-extents-failed " .. self.measure_error:gsub("[\r\n]", " ")) end
        end
        if style.native then
            self.native_font_failed = true
            return self:text(text, x, y, size, colour, maximum_width, fallback, maximum_height, shadow)
        end
        style = self:text_style(fallback or "STRATAGEM")
        good, lo, hi, width, height = pcall(self.measure, self, style, size)
        if not good then return end
    end
    local ratio = math.min(1, limit / width, ((maximum_height or math.huge) - shadow) / height)
    if ratio < 1 then
        size = size * ratio
        good, lo, hi, width, height = pcall(self.measure, self, style, size)
        if not good then
            if style.native then
                self.native_font_failed = true
                if self.trace then self.trace("OVERLAY native-font-measure-failed " .. tostring(lo):gsub("[\r\n]", " ")) end
                return self:text(text, x, y, size, colour, maximum_width, fallback, maximum_height, shadow)
            end
            return
        end
    end
    local px, py = x - width / 2 - lo.x - shadow / 2, y - lo.y + shadow
    local function draw(draw_colour, offset_x, offset_y, layer)
        if not style.bitmap then
            self:shape_on(style.gui, "text", style.text, style.font, size, style.material,
                sr.Vector3(px + offset_x, py + offset_y, layer), draw_colour)
            return
        end
        local data, factor, pen = Radial.Glyphs, size / Radial.Glyphs.base, 0
        for char in style.text:gmatch("[\1-\127\194-\244][\128-\191]*") do
            local g = data.glyphs[char]
            if g[3] > 0 and g[4] > 0 then
                self:shape_on(style.gui, "bitmap_uv", style.material,
                    sr.Vector2(g[1] / data.width, g[2] / data.height),
                    sr.Vector2((g[1] + g[3]) / data.width, (g[2] + g[4]) / data.height),
                    sr.Vector3(px + offset_x + (pen + g[5]) * factor, py + offset_y + g[6] * factor, layer),
                    sr.Vector2(g[3] * factor, g[4] * factor), draw_colour)
            end
            pen = pen + g[7]
        end
    end
    local function draw_pair()
        if shadow > 0 then draw(sr.Color(255, 0, 0, 0), shadow, -shadow, 12) end
        draw(colour, 0, 0, 13)
    end
    local start = #self.ids
    local function rollback()
        for index = #self.ids, start + 1, -1 do
            local shape = self.ids[index]
            sr.Gui["destroy_" .. shape[1]](shape[3], shape[2]); self.ids[index] = nil
        end
    end
    if style.bitmap then
        local good, why = pcall(draw_pair)
        if not good then
            rollback()
            self.glyph_failed = true
            if self.trace then self.trace("OVERLAY glyph-draw-failed " .. tostring(why):gsub("[\r\n]", " ")) end
            self:text(fallback or "STRATAGEM", x, y, size, colour, maximum_width, nil, maximum_height, shadow)
        elseif self.fonts.glyphs and not self.fonts.glyphs.draw_report then
            self.fonts.glyphs.draw_report = true
            if self.trace then self.trace(string.format("OVERLAY glyph-drawn count=%d size=%.1f bounds=%.1fx%.1f", #self.ids - start, size, width, height)) end
        end
    elseif style.native then
        local good, why = pcall(draw_pair)
        if not good then
            rollback()
            self.native_font_failed = true
            if self.trace then self.trace("OVERLAY native-font-draw-failed " .. tostring(why):gsub("[\r\n]", " ")) end
            return self:text(text, x, y, size, colour, maximum_width, fallback, maximum_height, shadow)
        end
        local font = self.fonts[style.native.font]
        if not font.draw_report and self.trace then
            font.draw_report = true
            self.trace(string.format("OVERLAY native-font-drawn font=%s atlas=%s material=%s renderer=resource-text size=%.2f bounds=%.2f,%.2f,%.2f,%.2f id=%s",
                style.native.font, style.native.atlas, style.material, size,
                px + lo.x, py + lo.y, px + hi.x, py + hi.y, tostring(self.ids[#self.ids][2])))
        end
    else
        draw_pair()
    end
end
function Radial:label(text, x, top, size, colour, width, fallback, shadow)
    shadow = shadow or 0
    local style = self:text_style(text, fallback)
    local good, _, _, measured = pcall(self.measure, self, style, size)
    if not good or measured <= width - shadow then
        self:text(text, x, top - size, size, colour, width, fallback, size, shadow)
        return
    end
    local chars = {}; for char in style.text:gmatch("[\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = char end
    local split, score = nil, math.huge
    local spaces = style.text:find(" ") ~= nil
    for index = 1, #chars - 1 do
        if not spaces or chars[index] == " " or chars[index + 1] == " " then
            local left, right = table.concat(chars, "", 1, index):gsub("%s+$", ""),
                table.concat(chars, "", index + 1):gsub("^%s+", "")
            if left ~= "" and right ~= "" then
                local a = {gui = style.gui, font = style.font, text = left, bitmap = style.bitmap}
                local b = {gui = style.gui, font = style.font, text = right, bitmap = style.bitmap}
                local ok_a, _, _, wa = pcall(self.measure, self, a, size)
                local ok_b, _, _, wb = pcall(self.measure, self, b, size)
                if not ok_a or not ok_b then
                    self:text(text, x, top - size, size, colour, width, fallback, size, shadow); return
                end
                local value = math.max(wa, wb)
                if value < score then split, score = {left, right}, value end
            end
        end
    end
    if not split then self:text(style.text, x, top - size, size, colour, width, fallback, size, shadow); return end
    local original_size, start = size, #self.ids
    size = size * math.min(1, (width - shadow) / score)
    for index, line in ipairs(split) do
        self:text(line, x, top - index * size, size, colour, width, fallback, size, shadow)
        if style.native and self.native_font_failed or style.bitmap and self.glyph_failed then
            for item = #self.ids, start + 1, -1 do
                local shape = self.ids[item]
                self.sr.Gui["destroy_" .. shape[1]](shape[3], shape[2]); self.ids[item] = nil
            end
            self:label(text, x, top, original_size, colour, width, fallback, shadow); return
        end
    end
end
function Radial.content(count, inner, outer, angle, scale)
    scale = scale or outer / (count > 8 and 299 or 254)
    local half, step = math.pi / count - 0.02, (math.pi / count - 0.02) / 3
    local function fits(x, y, width, height)
        local mx, my = math.max(0, math.abs(x) - width / 2), math.max(0, math.abs(y) - height / 2)
        if mx * mx + my * my < inner * inner then return false end
        for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do
            local px, py = x + sx * width / 2, y + sy * height / 2
            local delta = (math.atan2(py, px) - angle + math.pi) % (2 * math.pi) - math.pi
            if math.abs(delta) > half then return false end
            local middle = -half + (math.floor((delta + half) / step) + 0.5) * step
            local limit = outer * math.cos(step / 2) / math.cos(delta - middle)
            if px * px + py * py > limit * limit then return false end
        end end
        return true
    end
    -- A tall block uses much more of the wedge than the previous conservative square.
    -- Search only when geometry changes; content and selection stay independent.
    for reduction = 0, 95 do
        local unit = scale * (1 - reduction / 100)
        local width, height = 110 * unit, 156 * unit
        for sample = 1, 63 do
            local radius = inner + (outer - inner) * sample / 64
            local x, y = radius * math.cos(angle), radius * math.sin(angle)
            if fits(x, y, width, height) then return x, y, width, height, 84 * unit, 24 * unit, 16 * unit, 4 * unit end
        end
    end
    error("overlay-layout-unavailable")
end
function Radial:draw(inventory)
    if not self.opened or not self:world_live(self.world) then return false end
    local sr, rows, scale = self.sr, inventory.rows, self.scale
    local w, h = self:dimensions()
    if not w or #rows < 1 or #rows > 16 or
        not sr.Application.can_get("font", "core/performance_hud/debug") or
        not sr.Application.can_get("material", "core/performance_hud/debug") then return false end
    self.width, self.height = w, h
    local base_radius = #rows > 8 and 235 or 190
    scale = math.min(scale, h / (2 * (base_radius + 104)), w / (2 * (base_radius + 76)))
    local nx, ny = self.channel.cursor()
    if not nx then return false end
    self.selected = Radial.pick(nx, ny, w, h, #rows, scale, self.direction)
    local mark, pictures, reasons = {tostring(self.selected), tostring(w), tostring(h), tostring(scale), self.direction}, {}, {}
    mark[#mark + 1] = tostring(self.native_font_failed)
    for _, spec in ipairs(KOREAN_FONTS) do
        mark[#mark + 1] = self:native_font_resources(spec) and spec.font or "native-font-unavailable"
    end
    mark[#mark + 1] = self:glyph_resources() and not self.glyph_failed and "glyph-ready" or "glyph-unavailable"
    -- Resource availability is shared only within this draw, including failures.
    local resources = {}
    for index, row in ipairs(rows) do
        pictures[index], reasons[index] = self:icon_data(row, resources)
        mark[#mark + 1] = row.kind .. ":" .. row.status .. ":" .. tostring(row.name) .. ":" .. tostring(row.slot) ..
            ":" .. tostring(row.ready) .. ":" .. tostring(row.picture) .. ":" .. tostring(reasons[index]) ..
            ":" .. (pictures[index] and pictures[index].signature or "")
    end
    local signature = table.concat(mark, "|")
    if signature == self.signature then return true end
    self:clear()
    for index, icon in pairs(self.icons) do
        if not pictures[index] then
            if icon.gui then sr.World.destroy_gui(self.world, icon.gui) end
            self.icons[index] = nil
        end
    end
    local radius = base_radius * scale
    local inner, outer = 54 * scale, radius + 64 * scale
    local cx, cy = w / 2, h / 2
    local geometry = table.concat({#rows, inner, outer, self.direction}, ":")
    if self.geometry ~= geometry then self.geometry, self.blocks = geometry, {} end
    local drawn_icons = 0
    local function vertex(r, a) return sr.Vector3(cx + r * math.cos(a), 0, cy + r * math.sin(a)) end
    for index, row in ipairs(rows) do
        local selected = index == self.selected
        local angle, half = Radial.angle(index, #rows, self.direction), math.pi / #rows - 0.02
        local colour = selected and row.ready and sr.Color(225, 92, 110, 38) or
            (row.ready and sr.Color(205, 28, 32, 36) or sr.Color(200, 18, 20, 23))
        for step = 0, 5 do
            local a, b = angle - half + half * step / 3, angle - half + half * (step + 1) / 3
            self:shape("triangle", vertex(inner, a), vertex(outer, a), vertex(outer, b), 10, colour)
            self:shape("triangle", vertex(inner, a), vertex(outer, b), vertex(inner, b), 10, colour)
        end
        local block = self.blocks[index]
        if not block then block = {Radial.content(#rows, inner, outer, angle, scale)}; self.blocks[index] = block end
        local dx, dy, width, height, icon_size, name_size, status_size, gap = unpack(block)
        local x, y = cx + dx, cy + dy
        local ink = row.ready and sr.Color(255, 255, 255, 240) or sr.Color(190, 125, 128, 130)
        local name_ink = row.ready and sr.Color(255, 255, 255, 245) or sr.Color(255, 219, 224, 230)
        local status_ink = row.ready and sr.Color(255, 229, 236, 220) or sr.Color(255, 200, 210, 220)
        local top = y + height / 2
        local shown, why = self:icon(index, pictures[index], x, top - icon_size / 2, icon_size, ink)
        if shown then drawn_icons = drawn_icons + 1 end
        local reason = not shown and (why or reasons[index] or "unknown") or nil
        local report = reason and (row.kind .. ":" .. tostring(row.picture) .. ":" .. reason) or nil
        if report and report ~= self.icon_reasons[index] and self.trace then
            self.trace("OVERLAY icon-fallback kind=" .. row.kind .. " material=" .. tostring(row.picture) ..
                " reason=" .. reason:gsub("[\r\n]", " "))
        end
        if shown and self.trace then
            local source = "ready:" .. pictures[index].signature
            if source ~= self.icon_reasons[index] then
                self.trace("OVERLAY icon-source kind=" .. row.kind .. " slot=" .. tostring(row.slot) ..
                    " picture=" .. row.picture .. " atlas=" .. pictures[index].art.texture ..
                    " uv=" .. table.concat(pictures[index].art.uv, ",") .. " name=" ..
                    tostring(row.name):gsub("[\r\n]", " "))
            end
            report = source
        end
        self.icon_reasons[index] = report
        local name_top = top - icon_size - gap
        local shadow = name_size / 14
        self:label(row.name or ("STRATAGEM " .. row.kind), x, name_top,
            name_size, name_ink, width, row.name_english, shadow)
        local reserved = row.slot and 20 * icon_size / 84 or 0
        if row.slot then
            local slot_size = 16 * icon_size / 84
            self:text(tostring(row.slot), x + width / 2 - slot_size / 2, y - height / 2,
                slot_size, name_ink, slot_size, nil, slot_size, shadow)
        end
        self:text(row.status, x - reserved / 2, y - height / 2, status_size, status_ink,
            width - reserved, nil, status_size, shadow)
    end
    local report = drawn_icons .. "/" .. #rows
    if report ~= self.icon_report then
        self.icon_report = report
        if self.trace then self.trace("OVERLAY icons=" .. report) end
    end
    if self.selected then
        local row = rows[self.selected]
        self:label(row.name or tostring(row.kind), cx, cy + 20 * scale, 20 * scale,
            sr.Color(255, 255, 255, 245), inner * 1.3, row.name_english, 1.5 * scale)
    end
    self.signature = signature
    return true
end
return Radial
