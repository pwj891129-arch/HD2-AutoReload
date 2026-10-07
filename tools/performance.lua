local fixture=dofile('tools/channel-fixture.lua')
local report={}
for _,entry in ipairs({{'before','dist/performance-before'},{'after','.'}}) do
    local result={}
    for _,platform in ipairs({false,true}) do
        local f=fixture(entry[2]..(platform and '/stratagem/platform.lua' or '/native_reader.lua'),platform)
        local allocations=f.stats.buffers
        for i=1,1000 do f.channel:read(f.address,4);f.channel:read(f.address,platform and 83968 or 216) end
        result[platform and 'wheel-reader' or 'weapon-reader']={reads=f.stats.reads,buffers=f.stats.buffers-allocations}
    end
    rawset(_G,'HD2_HELPER_PERFORMANCE_ROOT',entry[2])
    result.options_tab=dofile('options_tab.test.lua')
    result.wheel=dofile('stratagem/icons.test.lua')(function() error('performance fixture must not run regression tests') end)
    rawset(_G,'HD2_HELPER_PERFORMANCE_ROOT',nil)
    report[entry[1]]=result
end
assert(report.before['weapon-reader'].reads==report.after['weapon-reader'].reads)
assert(report.before['wheel-reader'].reads==report.after['wheel-reader'].reads)
assert(report.before.wheel.created_shapes==report.after.wheel.created_shapes,'rendering workload and hover updates must stay identical')
local function json(value)
    if type(value)=='number' then return tostring(value) end
    local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
    local parts={};for _,key in ipairs(keys) do parts[#parts+1]=string.format('%q:',key)..json(value[key]) end
    return '{'..table.concat(parts,',')..'}'
end
local file=assert(io.open('dist/performance-comparison.json','wb'));file:write(json(report),'\n');file:close()
print('PASS helper offline workload comparison: '..json(report))
