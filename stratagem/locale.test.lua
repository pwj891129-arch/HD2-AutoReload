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
    local loaded, glyphs, drawn, messages = true, true, {}, {}
    local function vector(x, y, z) return {x = x, y = y, z = z} end
    local sr = {
        Vector3 = vector, IdString64 = {from_hex = function(id) return id end},
        Application = {can_get = function(kind, name)
            return name == "core/performance_hud/debug" or loaded and
                (kind == "font" and (name == "e007454455e2d2bb" or name == "fca7631255290a2c") or
                kind == "material" and name == "content/fonts/runtime_font")
        end},
        Gui = {text = function() end, has_all_glyphs = function() return glyphs end,
            text_extents = function(_, text, _, size)
                local chars = 0; for _ in text:gmatch("[\1-\127\194-\244][\128-\191]*") do chars = chars + 1 end
                return vector(0, 0), vector(chars * size, size)
            end},
    }
    local radial = Radial.new(sr, {}, 1, function(line) messages[#messages + 1] = line end)
    radial.gui, radial.width = 123, 720
    radial.shape = function(_, kind, text, font, size, material, position)
        drawn = {kind = kind, text = text, font = font, size = size, material = material, x = position.x}
    end
    radial:text("궤도 380mm 고폭 폭격", 360, 200, 16, {}, 120, "380MM HE BARRAGE")
    equal(drawn.text, "궤도 380mm 고폭 폭격", "Unicode goes unchanged to native font renderer")
    equal(drawn.font, "e007454455e2d2bb", "Korean game font is used instead of Latin-only debug font")
    equal(drawn.material, "content/fonts/runtime_font")
    equal(drawn.size < 16, true, "long Korean labels fit the same sector width")
    equal(drawn.x >= 300, true, "text stays centered inside its allowed width")
    loaded = false
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(drawn.text, "REINFORCEMENT BEACON", "unloaded Korean font uses readable fallback, not missing glyph boxes")
    equal(drawn.font, "core/performance_hud/debug"); equal(#messages, 1, "missing font is logged once")
    loaded, glyphs = true, false
    radial:text("증원", 360, 200, 16, {}, 120, "REINFORCEMENT BEACON")
    equal(drawn.text, "REINFORCEMENT BEACON", "missing glyph coverage fails to readable English")
    equal(#messages, 1)
    glyphs = true
    radial:text("RAILGUN", 360, 200, 16, {}, 120)
    equal(drawn.font, "core/performance_hud/debug", "English font and material remain unchanged")
    assert(loadfile("../dist/combined.ko.generated.lua"), "Korean combined payload compiles in LuaJIT")
end
