local Language = dofile('language.lua')
local checks = 0
local function eq(a,b,message) checks=checks+1;assert(a==b,message..': '..tostring(a)..' ~= '..tostring(b)) end
local function integer(n,size)
    local bytes = {}
    for i=1,size do bytes[i]=string.char(n%256);n=math.floor(n/256) end
    return table.concat(bytes)
end
local function fixture(code,index)
    local memory,reads = {},0
    local channel = {base=0x10000000}
    memory[channel.base+Language.RVA.settings]=integer(0x20000000,8)
    memory[0x20000000+Language.RVA.index]=integer(index or 4,4)
    memory[channel.base+Language.RVA.records+8*(index or 4)]=integer(0x30000000,8)
    memory[0x30000008]=integer(0x40000000,8)
    memory[0x40000000]=code..'\0'..string.rep('\0',16)
    function channel:read(at,size)
        reads=reads+1
        local value = memory[at]
        return value and #value>=size and value:sub(1,size) or nil
    end
    return channel,memory,function() return reads end
end
local language = Language.new(function() end)
eq(language.current,'en','safe startup fallback')
for _,code in ipairs({'ko','kr','ko-KR','us','en','de','zh-CN','zz'}) do
    local channel,_,reads = fixture(code)
    eq(Language.code(channel),code,'read game setting code')
    eq(reads(),5,'bounded five-read language lookup')
    language:bind(channel)
    eq(language.current,Language.resolve(code),'language selection')
end
local supported={us='en',fr='fr',it='it',de='de',es='es',mx='es-419',jp='ja',ko='ko',
    br='pt-BR',pt='pt',pl='pl',ru='ru',cn='zh-Hans',tw='zh-Hant'}
for code,locale in pairs(supported) do
    language:bind(fixture(code));eq(language.current,locale,'official game language selected')
end
for code,locale in pairs({['es-419']='es-419',['pt_BR']='pt-BR',['ZH-TW']='zh-Hant',
    ['ja-JP']='ja',['en-GB']='en',['unknown']='en'}) do
    eq(Language.resolve(code),locale,'normalized aliases and unsupported fallback')
end
eq(Language.code(fixture('es-419')),'es-419','numeric region code accepted')
local channel,memory,reads=fixture('ko')
language:bind(channel)
local count=reads();language:poll(.1);eq(reads(),count,'language polling throttled')
memory[0x40000000]='us\0'..string.rep('\0',16)
language:poll(.3);eq(language.current,'en','live game language switch')
memory[0x40000000]='ko\0'..string.rep('\0',16)
language:poll(.6);eq(language.current,'ko','live Korean switch')
local revision=language.revision
memory[0x40000000]='jp\0'..string.rep('\0',16)
language:poll(.9);eq(language.current,'ja','live Japanese switch')
memory[0x40000000]='ko\0'..string.rep('\0',16)
language:poll(1.2);eq(language.current,'ko','Japanese to Korean return')
eq(language.revision,revision+2,'locale revision increments on both directions')
channel.read=function() error('unreadable') end
language:poll(1.5);eq(language.current,'en','failed reads fall back to English')
for _,index in ipairs({15,255,4294967295}) do
    eq(Language.code(fixture('ko',index)),nil,'invalid language index refused')
end
eq(Language.code(fixture('1234')),nil,'invalid language code refused')
eq(Language.code({base='bad',read=function()error('must not read')end}),nil,'invalid base refused')
eq(Language.code(nil),nil,'missing channel fallback')
local bad,bytes=fixture('ko');bytes[bad.base+Language.RVA.settings]=integer(1,8)
eq(Language.code(bad),nil,'invalid pointer refused')
print('PASS '..checks..' game text-language and English fallback checks')
