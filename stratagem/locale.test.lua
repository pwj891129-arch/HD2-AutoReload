return function(equal, Reader)
    local en, ko = dofile("dist/locale.en.generated.lua"), dofile("dist/locale.ko.generated.lua")
    equal(en.language, "en"); equal(ko.language, "ko")
    for _, row in ipairs({
        {124, "MISSIONS. REINFORCEMENT BEACON", "증원"},
        {33, "CONSUMABLES. RESUPPLY", "재보급"},
        {113, "TEAM WEAPONS. HARPOON GUN ", "작살총"},
        {105, "VEHICLES. FAST RECON VEHICLE (FRV)", "포격 FRV"},
        {1, "VEHICLES. BASTION(tank)", "바스티온 Mk XVI"},
        {81, "TEAM WEAPONS. SHARK ENERGY WEAPON", "멜타건"},
        {126, "EAGLE. Gas AIRSTRIKE", "이글 가스 공중타격"},
        {116, "SEAF Squad", "SEAF 분대"},
    }) do
        equal(ko.name(row[1], row[2]), row[3], "Korean game name follows verified native identity")
        equal(en.name(row[1], row[2]), row[2]:gsub("^.-%.%s*", ""), "English debug display is preserved")
        equal(ko.name(row[1], "different definition"), "스트라타젬 " .. row[1], "reused kind cannot display another stratagem's name")
    end
    equal(ko.name(150, nil), "스트라타젬 150", "unknown future stratagem has Korean fallback")
    local reader = Reader.new({read = function() return string.char(0):rep(8) end})
    local rows = {{kind = 124, address = 100000, uses = 1}, {kind = 113, address = 100048, uses = 1, slot = 1}}
    reader.inventory = function() return {rows = rows, token = "same-inventory"} end
    reader.definitions = function() return {
        [124] = {record = 200000, name = "MISSIONS. REINFORCEMENT BEACON", command = {1, 2}},
        [113] = {record = 200400, name = "TEAM WEAPONS. HARPOON GUN ", command = {2, 3}},
    } end
    reader.root = function() return 300000 end
    reader.integer64 = function(_, at) return at == 300024 and 1000000 or 0 end
    reader.hash = function() return "0123456789abcdef" end
    Reader.Locale = ko
    local translated = reader:radial(true, false)
    equal(translated.rows[1].name, "증원"); equal(translated.rows[2].name, "작살총")
    equal(translated.rows[2].slot, 1, "personal hotkey number is unchanged")
    equal(translated.rows[2].command[1], 2, "localized label never changes command")
    Reader.Locale = en
    equal(reader:radial(true, false).rows[2].name, "HARPOON GUN ")
    Reader.Locale = nil
    local Radial = dofile("radial.lua")
    local loaded, atlas_loaded, first_loaded, glyphs, drawn, messages = true, true, true, true, {}, {}
    local surfaces, created, binds, fail = {}, 0, 0, nil
    local function vector(x, y, z) return {x = x, y = y, z = z} end
    local sr = {
        Vector3 = vector, IdString64 = {from_hex = function(id) return id end},
        Application = {can_get = function(kind, name)
            return name == "core/performance_hud/debug" or loaded and
                (kind == "font" and (first_loaded and name == "e007454455e2d2bb" or name == "fca7631255290a2c") or
                kind == "texture" and atlas_loaded and (name == "8d346dcdd08459d5" or name == "9ae590aec7c63b1c") or
                kind == "material" and name == "content/fonts/core_sans")
        end, worlds = function() return {2} end},
        World = {create_screen_gui = function(world, mode, sx, sy)
            assert(world == 2 and mode == "scale" and sx == 1 and sy == 1)
            created = created + 1; surfaces[created] = {}; return created
        end, destroy_gui = function(world, gui) assert(world == 2 and surfaces[gui]); surfaces[gui] = nil end},
        Material = {set_texture = function(material, slot, atlas)
            assert(slot == "88bac99b00000000", "MSDF slot, not icon diffuse slot")
            if fail == "binding" then error("binding failed") end
            material.atlas = atlas; binds = binds + 1
        end},
        Gui = {text = function() end, has_all_glyphs = function() return glyphs end,
            material = function(gui, name)
                assert(name == "content/fonts/core_sans" and surfaces[gui], "owned font GUI only")
                local material = {}; surfaces[gui].material = material; return material
            end,
            text_extents = function(gui, text, font, size)
                if font ~= "core/performance_hud/debug" then
                    assert(surfaces[gui].material.atlas, "loaded font/material without bound atlas cannot render")
                end
                local chars = 0; for _ in text:gmatch("[\1-\127\194-\244][\128-\191]*") do chars = chars + 1 end
                return vector(-2 * size, -0.8 * size), vector((chars - 2) * size, 0.2 * size)
            end},
    }
    local radial = Radial.new(sr, {}, 1, function(line) messages[#messages + 1] = line end)
    radial.gui, radial.world, radial.width = 123, 2, 720
    radial.shape_on = function(_, gui, kind, text, font, size, material, position)
        drawn = {kind = kind, text = text, font = font, size = size, material = material, x = position.x, y = position.y}
        if font ~= "core/performance_hud/debug" then
            assert(gui ~= 123 and surfaces[gui].material == material)
            assert(material.atlas == (font == "e007454455e2d2bb" and "8d346dcdd08459d5" or "9ae590aec7c63b1c"))
        end
    end
    radial:text("궤도 380mm 고폭 폭격", 360, 200, 16, {}, 120, "380MM HE BARRAGE")
    equal(drawn.text, "궤도 380mm 고폭 폭격", "Unicode goes unchanged to native font renderer")
    equal(drawn.font, "e007454455e2d2bb", "Korean game font is used instead of Latin-only debug font")
    equal(drawn.material.atlas, "8d346dcdd08459d5", "matching Korean atlas is explicitly bound before text")
    equal(created, 1); equal(binds, 1)
    equal(drawn.size < 16, true, "long Korean labels fit the same sector width")
    equal(drawn.x - 2 * drawn.size >= 300, true, "native bearing is included in text centering")
    equal(drawn.y - 0.8 * drawn.size, 200, "native baseline bearing is included in vertical placement")
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(created, 1); equal(binds, 1, "hover reuses its own bound font surface")
    radial:close(); equal(next(surfaces), nil, "owned font surfaces are disposed, not native HUD surfaces")
    atlas_loaded = false
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(drawn.text, "REINFORCEMENT BEACON", "loaded fonts cannot authorize rendering without their actual atlas")
    equal(created, 1, "missing atlas declines before allocating a font GUI")
    atlas_loaded = true
    loaded = false
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(drawn.text, "REINFORCEMENT BEACON", "unloaded Korean font uses readable fallback, not missing glyph boxes")
    equal(drawn.font, "core/performance_hud/debug"); equal(#messages, 2, "binding source and missing atlas are logged once")
    loaded, glyphs = true, false
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(drawn.text, "REINFORCEMENT BEACON", "missing glyph coverage fails to readable English")
    equal(#messages, 2)
    glyphs = true
    radial:text("RAILGUN", 360, 200, 16, {}, 120)
    equal(drawn.font, "core/performance_hud/debug", "English font and material remain unchanged")
    first_loaded = false
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(drawn.font, "fca7631255290a2c"); equal(drawn.material.atlas, "9ae590aec7c63b1c", "alternate font uses its own atlas, not the primary atlas")
    radial:close(); equal(next(surfaces), nil)
    first_loaded = true
    fail = "binding"
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(drawn.text, "REINFORCEMENT BEACON", "failed texture binding fails to readable English")
    local attempts = created
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(created, attempts, "binding failures do not allocate unbounded font surfaces")
    radial:close(); equal(next(surfaces), nil)
    assert(loadfile("../dist/combined.ko.generated.lua"), "Korean combined payload compiles in LuaJIT")
end
