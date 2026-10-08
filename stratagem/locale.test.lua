return function(equal, Reader)
    local en, ko = dofile("dist/locale.generated.lua"), dofile("dist/locale.generated.lua")
    local language = {current = 'ko'}
    ko.bind(language)
    ko.name(124,'MISSIONS. REINFORCEMENT BEACON')
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
    equal(translated.rows[1].name, "작살총"); equal(translated.rows[2].name, "증원")
    equal(translated.rows[1].slot, 1, "personal hotkey number is unchanged")
    equal(translated.rows[1].command[1], 2, "localized label never changes command")
    Reader.Locale = en
    equal(reader:radial(true, false).rows[1].name, "HARPOON GUN ")
    Reader.Locale = nil
    language.current = 'en'
    equal(ko.name(124,'MISSIONS. REINFORCEMENT BEACON'),'REINFORCEMENT BEACON','game language change refreshes names')
    language.current = 'fr'
    equal(ko.name(124,'MISSIONS. REINFORCEMENT BEACON'),'REINFORCEMENT BEACON','unsupported wheel language falls back to English')
    assert(loadfile("../dist/combined.generated.lua"), "Unified bilingual payload compiles in LuaJIT")
end
