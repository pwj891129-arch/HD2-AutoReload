local ffi = require('ffi')
local PIN = {
    exe = 'f5fee03dcfdb2e553a4752c283590950ac13316b376d8196aa556ff0400d5f06',
    game = '2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e',
}
return function(path, platform)
    local stats = {buffers=0,reads=0}
    local storage = ffi.new('uint8_t[262144]')
    ffi.fill(storage,262144,65)
    local address = tonumber(ffi.cast('uintptr_t',storage))
    local mode, module = 'full',nil
    local kernel,user,bcrypt = {},{},{}
    local prefix = platform and 'HD2SH_' or ''
    local function api(table,name,fn) table[prefix..name]=fn end
    api(kernel,'GetModuleHandleA',function(name) return name and 131072 or 65536 end)
    api(kernel,'GetModuleFileNameW',function(value) module=value;return 1 end)
    api(kernel,'CreateFileW',function() return module end)
    api(kernel,'ReadFile',function(_,_,_,actual) actual[0]=0;return 1 end)
    api(kernel,'CloseHandle',function() return 1 end)
    api(kernel,'GetCurrentProcess',function() return 1 end)
    api(kernel,'GetCurrentProcessId',function() return 1 end)
    api(kernel,'ReadProcessMemory',function(_,at,buffer,size,actual)
        stats.reads=stats.reads+1
        assert(tonumber(ffi.cast('uintptr_t',at))==address,'only fixture-owned memory may be read')
        if mode=='failed' then return 0 end
        if mode=='missing-count' then return 1 end
        local length=mode=='partial' and size-1 or size
        ffi.copy(buffer,storage,length);actual[0]=length;return 1
    end)
    api(bcrypt,'BCryptOpenAlgorithmProvider',function(out) out[0]=ffi.cast('void *',1);return 0 end)
    api(bcrypt,'BCryptCreateHash',function(_,out) out[0]=ffi.cast('void *',2);return 0 end)
    api(bcrypt,'BCryptHashData',function() return 0 end)
    api(bcrypt,'BCryptFinishHash',function(_,out)
        local hex=module==65536 and PIN.exe or PIN.game
        for i=0,31 do out[i]=tonumber(hex:sub(i*2+1,i*2+2),16) end
        return 0
    end)
    api(bcrypt,'BCryptDestroyHash',function() return 0 end)
    api(bcrypt,'BCryptCloseAlgorithmProvider',function() return 0 end)
    setmetatable(user,{__index=function() error('fixture must not send input or inspect a game window') end})
    local fake = setmetatable({
        new=function(kind,...)
            if kind:match('^uint8_t%[') or kind:match('^unsigned char%[') then stats.buffers=stats.buffers+1 end
            return ffi.new(kind,...)
        end,
        load=function(name)
            if name=='kernel32' then return kernel end
            if name=='bcrypt' then return bcrypt end
            assert(name=='user32');return user
        end,
    },{__index=ffi})
    local file=assert(io.open(path,'rb'));local source=file:read('*a');file:close()
    local chunk=assert(loadstring(source,'@'..path))
    setfenv(chunk,setmetatable({require=function(name)
        assert(name=='ffi');return fake
    end},{__index=_G}))
    local module=chunk()
    local channel=platform and module.create(fake) or assert(module.new():ready())
    return {channel=channel,stats=stats,address=address,storage=storage,
        mode=function(value) mode=value end}
end
