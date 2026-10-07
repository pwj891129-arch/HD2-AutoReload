local names = (function()
-- @NAMES@
end)()
local Locale = {language = 'en'}
function Locale.bind(language) Locale.source = language end
function Locale.name(kind, native)
    Locale.language = Locale.source and Locale.source.current == 'ko' and 'ko' or 'en'
    if Locale.language == "ko" then
        local row = names[kind]
        if row and row.native == native then return row.ko end
        return "스트라타젬 " .. tostring(kind)
    end
    return (native or ("STRATAGEM " .. tostring(kind))):gsub("^.-%.%s*", "")
end
return Locale
