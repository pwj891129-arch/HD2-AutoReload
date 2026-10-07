local fixture = dofile('tools/channel-fixture.lua')
local checks=0
local function eq(actual,expected,message)
    checks=checks+1;assert(actual==expected,message..': '..tostring(actual)..' ~= '..tostring(expected))
end
for _,platform in ipairs({false,true}) do
    local f=fixture(platform and 'stratagem/platform.lua' or 'native_reader.lua',platform)
    local c,at=f.channel,f.address
    local allocations=f.stats.buffers
    local first=c:read(at,8)
    eq(first,string.rep('A',8),'owned memory read')
    f.storage[0]=66
    eq(c:read(at,8),'B'..string.rep('A',7),'each read uses fresh memory')
    eq(first,string.rep('A',8),'returned strings do not alias the reused buffer')
    for i=1,1000 do eq(c:read(at,4),'BAAA','small read remains fresh') end
    eq(f.stats.buffers,allocations,'small reads allocate no additional FFI buffers')
    for _,mode in ipairs({'failed','partial','missing-count'}) do
        f.mode(mode);eq(c:read(at,8),nil,'reject '..mode..' after successful same-size read')
        f.mode('full');eq(c:read(at,8),'B'..string.rep('A',7),'recover after '..mode)
    end
    for _,input in ipairs({{at,0},{at,-1},{at,1.5},{at,0/0},{at,math.huge},
        {at,'8'},{0,8},{at+.5,8},{0/0,8},{math.huge,8},{140737488355327,8}}) do
        local reads=f.stats.reads
        eq(c:read(input[1],input[2]),nil,'invalid address/length is refused')
        eq(f.stats.reads,reads,'invalid request never enters RPM')
    end
    eq(c:read(at,nil),nil,'nil length is refused')
    local maximum=platform and 262144 or 256
    eq(c:read(at,maximum+1),nil,'oversized read is refused')
    if platform then
        local a=c:read(at,83968)
        eq(#a,83968,'binding bucket grows the buffer')
        local grown=f.stats.buffers
        for i=1,100 do c:read(at,83968);c:read(at,4) end
        eq(f.stats.buffers,grown,'large/small alternating reads reuse capacity')
        eq(#c:read(at,maximum),maximum,'maximum valid read')
        eq(a:sub(1,4),'BAAA','growth does not mutate earlier returned strings')
    else eq(#c:read(at,maximum),maximum,'maximum valid read') end
end
print('PASS '..checks..' reusable read-buffer checks; mocked APIs and owned memory only')
