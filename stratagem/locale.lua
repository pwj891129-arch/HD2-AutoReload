local LANGUAGE = "@LANGUAGE@"
local names = (function()
-- @NAMES@
end)()
local Locale = {language = LANGUAGE}
function Locale.name(kind, native)
    if LANGUAGE == "ko" then
        local row = names[kind]
        if row and row.native == native then return row.ko end
        return "스트라타젬 " .. tostring(kind)
    end
    return (native or ("STRATAGEM " .. tostring(kind))):gsub("^.-%.%s*", "")
end
return Locale
