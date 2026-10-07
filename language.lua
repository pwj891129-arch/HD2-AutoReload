local Language = {}
Language.RVA = {settings = 0x3326340, index = 705500 + 212, records = 0x37c5650, count = 15}
Language.CODES = {
    us='en',en='en',['en-us']='en',uk='en',gb='en',['en-gb']='en',
    fr='fr',it='it',de='de',es='es',['es-es']='es',mx='es-419',['es-mx']='es-419',['es-419']='es-419',
    jp='ja',ja='ja',['ja-jp']='ja',kr='ko',ko='ko',['ko-kr']='ko',
    br='pt-BR',['pt-br']='pt-BR',pt='pt',['pt-pt']='pt',pl='pl',ru='ru',
    cn='zh-Hans',zh='zh-Hans',zhs='zh-Hans',['zh-cn']='zh-Hans',['zh-hans']='zh-Hans',
    tw='zh-Hant',zht='zh-Hant',['zh-tw']='zh-Hant',['zh-hant']='zh-Hant'
}
function Language.resolve(code)
    return type(code)=='string' and Language.CODES[code:lower():gsub('_','-')] or 'en'
end
local function integer(bytes)
    local value = 0
    for index = #bytes, 1, -1 do value = value * 256 + bytes:byte(index) end
    return value
end
function Language.code(channel)
    if type(channel) ~= 'table' or type(channel.base) ~= 'number' or type(channel.read) ~= 'function' then return nil end
    local function read(address, size)
        local ok, bytes = pcall(channel.read,channel,address,size)
        if ok and type(bytes) == 'string' and #bytes == size then return bytes end
    end
    local function pointer(address)
        local bytes = read(address,8)
        local value = bytes and integer(bytes)
        if value and value >= 65536 and value < 2^47 then return value end
    end
    -- Read the game's Text Language, not the Windows or Steam UI language.
    local r = Language.RVA
    local settings = pointer(channel.base+r.settings)
    local bytes = settings and read(settings+r.index,4)
    local index = bytes and integer(bytes)
    if not index or index >= r.count then return nil end
    local record = pointer(channel.base+r.records+8*index)
    local text = record and pointer(record+8)
    bytes = text and (read(text,16) or read(text,8))
    local code = bytes and bytes:match('^(%a[%w%-_]*)%z')
    if code and #code <= 12 then return code end
end
function Language.new(log)
    local self = {current = 'en',revision=0}
    function self:bind(channel)
        self.channel,self.poll_at = channel,nil
        self:poll(0)
    end
    function self:poll(now)
        if now < (self.poll_at or 0) then return end
        self.poll_at = now+0.25
        local code = Language.code(self.channel)
        local language = Language.resolve(code) or 'en'
        if self.current ~= language or self.code ~= code or not self.noted then
            if self.current~=language then self.revision=self.revision+1 end
            self.current,self.code,self.noted = language,code,true
            log('LANGUAGE game='..tostring(code)..' helper='..language)
        end
    end
    return self
end
return Language
