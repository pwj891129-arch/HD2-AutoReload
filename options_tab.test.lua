local ffi = require('ffi')
local Tab = dofile((rawget(_G,'HD2_HELPER_PERFORMANCE_ROOT') or '.')..'/options_tab.lua')
local checks=0
local function eq(actual,expected,message)
    checks=checks+1;assert(actual==expected,message..': '..tostring(actual)..' ~= '..tostring(expected))
end
local BAR,COUNT,CURRENT,LABELS,TEXT,STRIDE=1248,57448,57452,57320,8296,3400
local TEMPLATE=0xc67c7faf
local function fixture(extra,startup_mode)
    local env,logs={},{}
    local startup,engine_update={}
    if startup_mode then
        env.CowboyBingusModLoader={after_startup=function(callback)
            if startup_mode=='reject' then return false end
            if startup_mode=='error' then error('startup unavailable',0) end
            startup[#startup+1]=callback;return true
        end}
    end
    local block=ffi.new('uint8_t[100000]')
    local screen=tonumber(ffi.cast('uintptr_t',block))
    local bar=screen+BAR
    local function get32(at) return tonumber(ffi.cast('uint32_t *',at)[0]) end
    local function put32(at,v) ffi.cast('uint32_t *',at)[0]=v end
    local function put8(at,v) ffi.cast('uint8_t *',at)[0]=v end
    local texts={}
    local state={mods={{id='other',title='Other',order={}},
        {id='hd2_helper.general',title='General',order={}},
        {id='hd2_helper.shared',title='Common',order={}},
        {id='hd2_helper.mission',title='Mission',order={}}},options={},values={},pending={},pending_count=0,native={},revision=0}
    local native=state.native
    function native.set_label(at,label) put32(at+272,label) end
    function native.set_string_arg(at,key,pointer)
        put32(at+280,key);put32(at+284,1)
        ffi.cast('const char **',at+288)[0]=pointer;put8(at+616,1)
    end
    function native.set_tab_labels(at,labels,count)
        put32(at+COUNT,count)
        for i=0,count-1 do
            put32(at+LABELS+4*i,tonumber(labels[i]))
            native.set_label(at+TEXT+STRIDE*i,tonumber(labels[i]))
            put8(at+TEXT+STRIDE*i+616,0)
            ffi.cast('uintptr_t *',at+TEXT+STRIDE*i+288)[0]=0
        end
    end
    local function show_text(at,text)
        texts[text]=texts[text] or ffi.new('char[?]',#text+1,text)
        native.set_label(at,TEMPLATE);native.set_string_arg(at,0xab2a7b35,texts[text])
    end
    local labels=ffi.new('uint32_t[8]',{0xd876b36e,0x78934e12,0x8c02bd80,TEMPLATE,TEMPLATE,1207430374})
    native.set_tab_labels(bar,labels,4+(extra or 0));show_text(bar+TEXT+3*STRIDE,'MODS')
    if (extra or 0)>0 then show_text(bar+TEXT+4*STRIDE,'BTO') end
    if (extra or 0)>1 then native.set_label(bar+TEXT+5*STRIDE,1207430374) end
    put32(bar+CURRENT,2)
    local menu={api=1,version=3}
    function menu.ready() return state.native~=nil end
    env.ModOptionsMenu=menu
    local open,covered,leaves,queries=true,false,0,0
    local function escape_menu()
        queries=queries+1
        if covered then return nil,'covered' end
        return open and screen or nil,open and 'open' or 'closed'
    end
    local function drop_pending() state.pending={};state.pending_count=0 end
    local function mod_list()
        local list={};for i,v in ipairs(state.mods) do list[i]=v end;return list
    end
    local function list_mods(view) view.mods=mod_list() end
    local function enter_view(at)
        state.view={screen=at,revision=state.revision};list_mods(state.view)
    end
    local function leave_view(view) leaves=leaves+1;drop_pending();state.view=nil end
    local function maintain_view(view)
        if view.revision~=state.revision then list_mods(view);view.revision=state.revision end
    end
    local function update_apply(view)
        if state.apply then state.values.enabled=state.pending.enabled;drop_pending();state.apply=false end
    end
    local function update_visuals(view,dt) state.visual=dt end
    local function neutralize_dialog(view) state.dialog_view=view end
    local function ensure_mods_tab(at)
        local count=get32(at+BAR+COUNT)
        if count<4 then return false end
        show_text(at+BAR+TEXT+STRIDE*3,'MODS');return true
    end
    local function step(dt)
        if not state.native then return end
        local at,status=escape_menu();if status~='open' then return end
        if not ensure_mods_tab(at) then return end
        local current=get32(at+BAR+CURRENT)
        if state.view and current~=3 then leave_view(state.view) end
        if not state.view and current==3 then enter_view(at) end
        if state.view then maintain_view(state.view);update_apply(state.view);update_visuals(state.view,dt);neutralize_dialog(state.view) end
        if state.touched then put32(at+8,2);put8(at+12,1) end
        if state.fail then error(state.fail,0) end
    end
    env.update=function(dt,...) step(dt);return 'ok',nil,select(1,...) end
    local tab=Tab.new(env,{},function(line) logs[#logs+1]=line end)
    local function tick(dt) tab:tick(menu);return (engine_update or env.update)(dt or .1,'tail') end
    local function start()
        for _,callback in ipairs(startup) do callback() end
        engine_update=env.update
    end
    local function title(index)
        local at=bar+TEXT+STRIDE*index
        if get32(at+272)~=TEMPLATE then return get32(at+272) end
        return ffi.string(ffi.cast('const char **',at+288)[0])
    end
    return {env=env,menu=menu,state=state,tab=tab,tick=tick,bar=bar,screen=screen,block=block,get=get32,put=put32,
        title=title,log=logs,start=start,startup=startup,close=function(v) open=not v end,
        cover=function(v) covered=v end,leaves=function() return leaves end,queries=function() return queries end}
end

if rawget(_G,'HD2_HELPER_PERFORMANCE_ROOT') then
    local result={}
    for _,mode in ipairs({'closed','helper-tab'}) do
        local f=fixture(2,true);f.start();for i=1,8 do f.tick() end
        if mode=='closed' then f.close(true) else f.put(f.bar+CURRENT,6) end
        f.tick();local before=f.queries()
        for i=1,240 do f.tick(1/120) end
        result[mode]={frames=240,menu_queries=f.queries()-before}
    end
    return result
end

do
    local f=fixture(2,true);f.start();for i=1,8 do f.tick() end
    f.close(true);f.tick();local before=f.queries()
    for i=1,240 do f.tick(1/120) end
    eq(f.queries()-before,720,'closed frame uses two helper observations plus one provider observation')
    f.close(false);for i=1,8 do f.tick() end
    f.put(f.bar+CURRENT,6);f.tick();before=f.queries()
    for i=1,240 do f.tick(1/120) end
    eq(f.queries()-before,720,'tab restoration and rendering share one post-update observation')
end

for extras=0,2 do
    local f=fixture(extras)
    for i=1,6 do f.tick() end
    eq(f.get(f.bar+COUNT),5+extras,'new tab appends after existing tabs')
    eq(f.title(4+extras),'HD2H','requested top-level title')
    eq(f.title(3),'MODS','MODS title retained')
    if extras>0 then eq(f.title(4),'BTO','BTO title retained across relabel') end
    if extras>1 then eq(f.title(5),1207430374,'HUD+ localized label retained') end
    f.put(f.bar+CURRENT,3);f.tick()
    eq(#f.state.view.mods,1,'only helper categories hidden from MODS')
    eq(f.state.view.mods[1].id,'other','other categories retained')
    f.put(f.bar+CURRENT,4+extras);f.tick()
    eq(#f.tab.view.mods,3,'helper tab contains all three groups')
    eq(f.state.view,nil,'private helper view not exposed during peer updates')
    f.state.pending={enabled=false};f.state.pending_count=1;f.state.apply=true;f.tick()
    eq(f.state.values.enabled,false,'APPLY retains provider persistence and values')
    eq(f.state.pending_count,0,'pending edit applied')
    f.cover(true);f.tick();eq(f.tab.view~=nil,true,'covered menu retains private view')
    f.cover(false);f.tick()
    f.env.BingusRuntime={statuses={ModOptionsMenu={state='paused: the previous update failed'}}}
    f.tick();eq(f.tab.view,nil,'provider safety pause hands helper view back')
    eq(f.get(f.bar+COUNT),5+extras,'peer tab count survives provider pause')
    f.env.BingusRuntime.statuses.ModOptionsMenu.state='running';f.tick()
    eq(#f.tab.view.mods,3,'helper view resumes after provider guard resumes')
    local previous=f.env.update
    f.env.update=function(...)
        if f.tab.hidden then eq(f.get(f.bar+COUNT),4+extras,'late peer sees its original tab count; hidden='..
            tostring(f.tab.hidden.count)..'; logs='..table.concat(f.log,' | ')) end
        return previous(...)
    end
    local a,b,c=f.tick();eq(a,'ok','foreign return retained');eq(b,nil,'nil return retained');eq(c,'tail','trailing return retained')
    eq(f.get(f.bar+COUNT),5+extras,'full tab count restored after peer update')
    f.state.fail='foreign update error'
    local ok,why=pcall(f.tick)
    eq(ok,false,'foreign exception propagated');eq(why,'foreign update error','original error object retained')
    eq(f.get(f.bar+COUNT),5+extras,'count restored on exception')
    f.state.fail=nil
    f.put(f.bar+CURRENT,2);f.tick();eq(f.tab.view,nil,'leaves helper before vanilla provider runs')
    f.close(true);f.tick();eq(f.tab.placed,false,'menu closing resets ownership')
    f.close(false);for i=1,6 do f.tick() end
    eq(f.get(f.bar+COUNT),5+extras,'reopening does not duplicate existing tab')
end
for extras=0,2 do
    local f=fixture(extras,true)
    eq(#f.startup,1,'tab callback registered once at startup')
    local native=f.state.native
    f.state.native=nil;f.start()
    eq(f.tab.h,nil,'startup wrapper does not require initialized provider')
    f.tick();eq(f.tab.h,nil,'provider initialization can finish after startup')
    f.state.native=native
    local wrapper=f.env.update
    -- A stale global or another late wrapper must not disable the callback
    -- already cached by the engine.
    f.env.update=function(...) return wrapper(...) end
    for i=1,8 do f.tick() end
    eq(f.tab.placed,true,'cached engine callback places tab after delayed provider initialization')
    eq(f.title(4+extras),'HD2H','cached engine callback renders requested title')
    eq(f.tab.wrapper,wrapper,'frames do not repeatedly wrap the cached callback')
    eq(f.get(f.bar+COUNT),5+extras,'cached callback keeps BTO/HUD tab count')
    f.put(f.bar+CURRENT,3);f.tick()
    eq(#f.state.view.mods,1,'cached callback removes only helper categories from MODS')
    f.put(f.bar+CURRENT,4+extras);f.tick()
    eq(#f.tab.view.mods,3,'cached callback renders all helper settings on its own tab')
    f.close(true);f.tick();f.close(false)
    for i=1,8 do f.tick() end
    eq(f.get(f.bar+COUNT),5+extras,'cached callback survives escape menu reopen without duplicate tabs')
end
for _,mode in ipairs({'reject','error'}) do
    local f=fixture(0,mode)
    eq(f.tab.startup_registered,false,'unavailable startup API retains legacy integration')
    for i=1,8 do f.tick() end
    eq(f.tab.placed,true,'legacy integration still works without accepted startup callback')
end
local full=fixture(2)
full.put(full.bar+COUNT,8)
for i=1,10 do full.tick() end
eq(full.tab.placed,false,'full native tab bar is not overwritten')
full.put(full.bar+CURRENT,3);full.tick();eq(#full.state.view.mods,4,'capacity failure keeps MODS fallback')
local unknown=fixture()
unknown.menu.version=4;unknown.tick();eq(unknown.tab.h,nil,'unknown private ABI is not patched')
eq(unknown.get(unknown.bar+COUNT),4,'unknown ABI retains existing menu')
local unavailable=fixture()
local available_update=unavailable.env.update
unavailable.env.update=nil
unavailable.tab:tick(unavailable.menu)
eq(unavailable.tab.h,nil,'missing global update callback retains public categories')
unavailable.env.update=available_update
for i=1,8 do unavailable.tick() end
eq(unavailable.tab.placed,true,'restored global update callback reconnects')
local late=fixture()
local provider_update=late.env.update
local holder={}
late.env.update=function(...) if holder.callback then return holder.callback(...) end;return 'waiting' end
late.tick();eq(late.tab.h,nil,'temporarily missing update graph retains MODS')
holder.callback=provider_update
for i=1,119 do late.tick() end
eq(late.tab.h,nil,'failed discovery retries at a bounded interval')
for i=1,8 do late.tick() end
eq(late.tab.placed,true,'same-root callback attachment recovers without restarting')
eq(late.title(4),'HD2H','late discovery appends requested tab')
print('PASS '..checks..' separate tab/coexistence checks')
