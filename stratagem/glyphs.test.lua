return function(equal)
    local Radial = dofile("radial.lua")
    Radial.Glyphs = dofile("dist/glyphs.generated.lua")
    local data, debug = Radial.Glyphs, "core/performance_hud/debug"
    local loaded, fail, created, bound, counter, bitmap_calls = true, false, 0, 0, 0, 0
    local surfaces, shapes, messages, english = {}, {}, {}, nil
    local function vector(x, y, z, w) return {x = x, y = y, z = z, w = w} end
    local sr = {Vector2 = vector, Vector3 = vector, Vector4 = vector, Color = function(...) return {...} end,
        IdString64 = {from_hex = function(id) return id end},
        Application = {can_get = function(kind, name)
            if kind == "font" then equal(name, debug, "Korean names never ask for a native font"); return true end
            return name == debug or kind == "texture" and name == data.texture and loaded or
                kind == "material" and name == "c0f3797849262087"
        end, worlds = function() return {2} end},
        World = {create_screen_gui = function(world)
            equal(world, 2); created = created + 1; surfaces[created] = {}; return created
        end, destroy_gui = function(world, gui)
            equal(world, 2); assert(surfaces[gui]);
            for _, shape in pairs(shapes) do assert(shape.gui ~= gui) end
            surfaces[gui] = nil
        end},
        Material = {set_texture = function(material, slot, atlas)
            equal(slot, "3aa8b87e00000000", "glyphs use the known icon-mask slot, not MSDF")
            if fail == "bind" then error("binding failed") end
            equal(atlas, data.texture); material.atlas = atlas; bound = bound + 1
        end, set_vector4 = function(material, slot, value) material[slot] = {value.x, value.y, value.z, value.w} end},
        Gui = {material = function(gui, name)
            equal(name, "c0f3797849262087"); assert(surfaces[gui]); return surfaces[gui]
        end, text_extents = function(_, text, font, size)
            equal(font, debug, "native font extents are not used for Korean"); return vector(-size, -size), vector((#text - 1) * size, 0)
        end, text = function(gui, text, font)
            equal(gui, 123); equal(font, debug); english = text; counter = counter + 1; return counter
        end, bitmap_uv = function(gui, material, lo, hi, position, size)
            bitmap_calls = bitmap_calls + 1
            if fail == "draw" and bitmap_calls % 2 == 0 then return nil end
            equal(material, "c0f3797849262087", "draw uses GUI-local material resource, not a native pointer")
            local surface = assert(surfaces[gui]); equal(surface.atlas, data.texture)
            equal(table.concat(surface["28723f4d00000000"], ","), "1,1,1,1")
            equal(table.concat(surface["851fd4fd00000000"], ","), "0,0,0,0")
            equal(lo.x >= 0 and lo.y >= 0 and hi.x <= 1 and hi.y <= 1, true)
            equal(position.z == 12 or position.z == 13, true); equal(size.x > 0 and size.y > 0, true)
            counter = counter + 1; shapes[counter] = {gui = gui, position = position, size = size}; return counter
        end, destroy_bitmap = function(gui, id) assert(shapes[id] and shapes[id].gui == gui); shapes[id] = nil end,
        destroy_text = function(gui) equal(gui, 123) end},
    }
    local radial = Radial.new(sr, {}, 1, function(line) messages[#messages + 1] = line end)
    radial.gui, radial.world, radial.width = 123, 2, 720
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(created, 1); equal(bound, 1); equal(#radial.ids, 2, "one retained bitmap per visible Korean glyph")
    local minx, maxx, miny = math.huge, -math.huge, math.huge
    for _, shape in pairs(shapes) do
        minx, maxx = math.min(minx, shape.position.x), math.max(maxx, shape.position.x + shape.size.x)
        miny = math.min(miny, shape.position.y)
    end
    equal(math.abs((minx + maxx) / 2 - 360) < 0.001, true, "glyph bearings center real pixels")
    equal(miny, 200, "glyph baseline is aligned to visible lower edge")
    radial:text("궤도 380mm 고폭 폭격", 360, 200, 20, {}, 80, "380MM HE BARRAGE")
    equal(created, 1); equal(bound, 1, "hover reuses one atlas and owned material")
    equal(english, nil, "Korean labels render with no Korean game font or language dependency")
    radial:label("이글 가스 공중타격", 360, 250, 20, {}, 75, "EAGLE GAS AIRSTRIKE")
    radial:close(); equal(next(shapes), nil); equal(next(surfaces), nil, "glyph bitmaps die before their owned surface")
    loaded = false
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(english, "REINFORCEMENT", "missing mod atlas uses readable fallback"); equal(created, 1)
    loaded = true
    radial:text("龘", 360, 200, 20, {}, 120, "UNKNOWN")
    equal(english, "UNKNOWN", "unsupported future characters cannot vanish silently")
    fail = "bind"
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(english, "REINFORCEMENT"); local attempts = created
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(created, attempts, "binding failures cannot allocate unbounded surfaces")
    radial:close(); equal(next(surfaces), nil)
    fail, bitmap_calls = "draw", 0
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(next(shapes), nil, "partial glyph draw is rolled back before fallback")
    equal(english, "REINFORCEMENT"); equal(radial.glyph_failed, true)
    local before = bitmap_calls
    radial:text("재보급", 360, 200, 20, {}, 120, "RESUPPLY")
    equal(bitmap_calls, before, "failed bitmap route is not retried for every label in one opening")
    equal(english, "RESUPPLY")
    radial:close(); equal(radial.glyph_failed, nil, "next opening can recover")
    fail = false
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(#radial.ids, 2); radial:close(); equal(next(shapes), nil)
    radial:text("증원", 360, 200, 24, {}, 100, "REINFORCEMENT", 24, 1.5)
    equal(#radial.ids, 4, "bitmap fallback retains both shadow and foreground glyphs")
    equal(shapes[radial.ids[1][2]].position.z, 12)
    equal(shapes[radial.ids[3][2]].position.z, 13)
    radial:close(); equal(next(shapes), nil)
    fail, bitmap_calls = "draw", 0
    radial:text("증원", 360, 200, 24, {}, 100, "REINFORCEMENT", 24, 1.5)
    equal(next(shapes), nil, "partial shadow glyphs are removed before English fallback")
    equal(#radial.ids, 2, "English fallback keeps a complete shadow pair")
    radial:close(); fail = false
    local can_get = sr.Application.can_get
    sr.Application.can_get = function(kind, name)
        if kind == "font" and name == "e007454455e2d2bb" or kind == "texture" and name == "8d346dcdd08459d5" or
            kind == "material" and name == "content/fonts/core_sans" then return true end
        return can_get(kind, name)
    end
    sr.Gui.has_all_glyphs = function() return true end
    -- This fixture cannot bind an MSDF material; the real bitmap path must recover.
    local before = bitmap_calls
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(radial.native_font_failed, true)
    equal(bitmap_calls - before, 2, "native failure falls back to actual Korean bitmaps before English")
    equal(#radial.ids, 2); radial:close(); equal(next(shapes), nil); equal(next(surfaces), nil)
    equal(table.concat(messages, "|"):find("renderer=mask-bitmap", 1, true) ~= nil, true)
end
