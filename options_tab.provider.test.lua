-- Optional integration fixture: use the installed provider as data, never load
-- game.dll or call a game function. Its checked memory helpers see owned buffers.
local file=io.open('../data/9ba626afa44a3aa3.patch_85','rb')
if not file then print('SKIP installed option provider fixture');return end
local bytes=file:read('*a');file:close()
local ffi=require('ffi')
local function u32(text,offset)
    local a,b,c,d=text:byte(offset+1,offset+4);return a+b*256+c*65536+d*16777216
end
assert(u32(bytes,0)==0xf0000011 and u32(bytes,8)==1)
local offset=u32(bytes,120);local size=u32(bytes,160)
local source=bytes:sub(offset+9,offset+size)
if not source:find('version = 3',1,true) then print('SKIP installed provider is not API version 3');return end
local env=setmetatable({update=function() return 'original',nil,'tail' end},{__index=_G})
env._G=env
local function vars(fn)
    local t={};for i=1,debug.getinfo(fn,'u').nups do local name,v=debug.getupvalue(fn,i);t[name]={value=v,slot=i} end;return t
end
local chunk=assert(loadstring(source,'@InstalledMOMFixture'));setfenv(chunk,env);chunk()
local menu=assert(env.ModOptionsMenu)
local state=assert(vars(menu.ready).state.value)
local block=ffi.new('uint8_t[5000000]')
local screen=tonumber(ffi.cast('uintptr_t',block))
local BAR,COUNT,CURRENT,LABELS,TEXT,STRIDE=1248,57448,57452,57320,8296,3400
local function put32(at,v) ffi.cast('uint32_t *',at)[0]=v end
local function get32(at) return tonumber(ffi.cast('uint32_t *',at)[0]) end
local native={}
function native.set_label(at,label) put32(at+272,label) end
function native.set_string_arg(at,key,pointer)
    put32(at+280,key);put32(at+284,1);ffi.cast('const char **',at+288)[0]=pointer
    ffi.cast('uint8_t *',at+616)[0]=1
end
function native.set_tab_labels(at,labels,count)
    put32(at+COUNT,count)
    for i=0,count-1 do
        put32(at+LABELS+i*4,labels[i]);native.set_label(at+TEXT+STRIDE*i,labels[i])
        ffi.cast('uint8_t *',at+TEXT+STRIDE*i+616)[0]=0
    end
end
state.initialized,state.native=true,native
local pending,seen={env.update},{}
local step
while #pending>0 do
    local fn=table.remove(pending)
    if type(fn)=='function' and not seen[fn] then
        seen[fn]=true;local up=vars(fn)
        if up.ensure_mods_tab and up.enter_view then step=fn;break end
        for _,entry in pairs(up) do
            if type(entry.value)=='function' then pending[#pending+1]=entry.value
            elseif type(entry.value)=='table' and entry.value~=env and entry.value~=_G then
                for _,child in pairs(entry.value) do if type(child)=='function' then pending[#pending+1]=child end end
            end
        end
    end
end
assert(step,'installed provider step not found')
local up=vars(step)
debug.setupvalue(step,up.escape_menu.slot,function() return screen,'open' end)
local labels=ffi.new('uint32_t[6]',{0xd876b36e,0x78934e12,0x8c02bd80,0xc67c7faf,0xc67c7faf,1207430374})
native.set_tab_labels(screen+BAR,labels,6);put32(screen+BAR+CURRENT,2)
assert(menu.register_option('other.fixture',{type='toggle',mod_id='other.fixture',mod='Other',label='Other'}))
local schema_file=assert(io.open('dist/menu-schema.generated.lua','r'))
local schema=assert(loadstring(schema_file:read('*a')))();schema_file:close()
local language={current='en',poll=function() end}
local LiveOptions=dofile('mod_options.lua')
local live=LiveOptions.new(env,{time_since_launch=function()return 0 end,can_get=function()return false end},
    function()error('missing resources must not be loaded')end,schema,language,function()end)
live:tick()
local id='hd2_helper.stratagem.shared_reinforce'
local option=assert(state.options[id])
assert(type(option.sources.label)=='function','actual provider did not retain automatic text source')
local value=state.values[id]
local translation=assert(vars(menu.register_option).translation.value)
local tr=translation.tr;translation.tr=function(key)return key=='tab.mods' and 'MODS' or 'NO MOD OPTIONS INSTALLED'end
language.current='ko';translation.refresh()
assert(option.label=='공용: 증원','actual provider Korean label refresh failed')
assert(state.mods[2].title=='HD2 헬퍼','actual provider Korean category refresh failed')
assert(state.values[id]==value,'language change altered saved option value')
language.current='en';translation.refresh()
assert(option.label=='Shared: Reinforce','actual provider English refresh failed')
language.current='zz';translation.refresh()
assert(option.label=='Shared: Reinforce','actual provider English fallback failed')
translation.tr=tr
-- HUD-style wrappers keep their prior update under a nonstandard name and
-- carry large callback caches unrelated to the options provider.
local noisy=assert(loadstring([[
return function(frame_update)
    local context={callbacks={}}
    for i=1,2048 do context.callbacks[i]=function()return i end end
    return function(...)
        if context.enabled then context.callbacks[1]() end
        return frame_update(...)
    end
end
]],'@ForeignHUDFixture'))()
for i=1,4 do env.update=noisy(env.update) end
local startup={}
env.CowboyBingusModLoader={after_startup=function(callback)
    startup[#startup+1]=callback;return true
end}
local Tab=dofile('options_tab.lua')
local log={};local tab=Tab.new(env,{},function(s) log[#log+1]=s end)
assert(#startup==1,'separate tab must register its final update at loader startup')
for _,callback in ipairs(startup) do callback() end
assert(not tab.h,'provider connection must not be required at callback installation')
local engine_update=env.update
for i=1,8 do tab:tick(menu);engine_update(.1) end
assert(tab.h,'actual installed provider closure discovery failed: '..table.concat(log,' | '))
assert(tab.placed and tab.slot==6 and get32(screen+BAR+COUNT)==7,'actual provider placement failed')
assert(tab.h.translation==translation,'checked provider translation model was not discovered')
live.tab=tab
local saved={}
for key,v in pairs(state.values) do saved[key]=v end
local callbacks={}
for key,v in pairs(state.callbacks) do callbacks[key]=#v end
-- MOM's opening refresh runs before the helper's poll: its text cache still
-- uses English when the helper observes Japanese later in the same frame.
language.current='en';translation.refresh()
language.current='ja'
live:tick()
assert(option.label=='共通: 増援','late Japanese detection did not refresh actual cached option text')
language.current='ko';live:tick()
assert(option.label=='공용: 증원','returning from Japanese did not restore Korean cached text')
local locales={'en','ko','ja','fr','de','it','es','es-419','pt','pt-BR','pl','ru','zh-Hans','zh-Hant','ko'}
for _,locale in ipairs(locales) do
    language.current=locale;live:tick()
    for _,row in ipairs(schema) do
        local actual=assert(state.options[row.id])
        assert(actual.label==row.text[locale].label,'cached label mismatch: '..locale..' '..row.key)
        assert(actual.description==row.text[locale].description,'cached description mismatch: '..locale..' '..row.key)
        for index,text in ipairs(row.text[locale].choices or {}) do
            if actual.labels[index]==0xc67c7faf then
                assert(actual.choices[index]==translation.T.upper(text),'cached choice mismatch: '..locale..' '..row.key)
            end
        end
        assert(state.values[row.id]==saved[row.id],'language refresh changed saved value: '..row.id)
        assert(#state.callbacks[row.id]==callbacks[row.id],'language refresh added duplicate callback')
    end
end
local revision=state.revision
live:tick();assert(state.revision==revision,'unchanged language must not refresh the text model every frame')
local slot=tab.h.list_slot
local _,scoped=debug.getupvalue(slot.fn,slot.slot)
assert(#scoped()==1,'actual provider MODS still contains helper categories')
tab.helper_scope=true;assert(#scoped()==3,'actual provider helper category routing failed');tab.helper_scope=false
local a,b,c=env.update(.1)
assert(a=='original' and b==nil and c=='tail','actual provider update return forwarding failed')
local stripped_env=setmetatable({update=function()end},{__index=_G})
stripped_env._G=stripped_env
local stripped=assert(loadstring(string.dump(assert(loadstring(source,'@StrippedMOMFixture')),true)))
setfenv(stripped,stripped_env);stripped()
local stripped_menu=assert(stripped_env.ModOptionsMenu)
for i=1,debug.getinfo(stripped_menu.ready,'u').nups do
    local _,value=debug.getupvalue(stripped_menu.ready,i)
    if type(value)=='table' and value.mods and value.options then value.native={} end
end
local unsupported=Tab.new(stripped_env,{},function()end)
unsupported:tick(stripped_menu)
assert(not unsupported.h,'stripped unsupported private ABI must not be guessed')
assert(get32(screen+BAR+COUNT)==7,'unsupported ABI changed owned native tab bar')
print('PASS installed ModOptionsMenu v1.2: 47 options in 14 languages; late-poll Korean return, saved values, callbacks, cached engine update, native tab and stripped-ABI refusal; owned memory only')
