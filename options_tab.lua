local OptionsTab = {}
local BAR, COUNT, CURRENT, LABELS = 1248, 57448, 57452, 57320
local TEXT, STRIDE, TEMPLATE = 8296, 3400, 0xc67c7faf
local CATEGORIES = {['hd2_helper.general']=true, ['hd2_helper.shared']=true, ['hd2_helper.mission']=true}

local function upvalues(fn)
    local result = {}
    for slot=1,debug.getinfo(fn,'u').nups do
        local name,value = debug.getupvalue(fn,slot)
        result[name] = {value=value,slot=slot}
    end
    return result
end

-- The provider has no public tab API. Discover only its checked view helpers;
-- unsupported closure layouts keep the public MODS integration untouched.
local function discover(root, menu, env)
    if type(root)~='function' then return nil,'game update callback unavailable' end
    local ready = upvalues(menu.ready)
    local state = ready.state and ready.state.value
    if type(state)~='table' or type(state.mods)~='table' or type(state.options)~='table' then
        return nil,'provider state unavailable'
    end
    local source = debug.getinfo(menu.ready,'S').source
    local functions,tables,preferred,seen,found = {root},{},{},{},{}
    local head,tail,inspected,table_entries = 1,1,0,0
    local step,list_slots = nil,{}
    local function queue(value)
        if type(value)=='function' then
            if debug.getinfo(value,'S').source==source then preferred[#preferred+1]=value
            elseif not step then tail=tail+1;functions[tail]=value end
        elseif not step and type(value)=='table' then tables[#tables+1]=value end
    end
    -- Follow callback functions before foreign state/cache tables. Once the
    -- provider's own state is found, inspect only that provider's view graph.
    while (#preferred>0 or head<=tail or #tables>0) and inspected<1024 do
        local value
        if #preferred>0 then value=table.remove(preferred)
        elseif head<=tail then value=functions[head];head=head+1
        else value=table.remove(tables) end
        if value~=env and value~=_G and not seen[value] then
            seen[value]=true;inspected=inspected+1
            if type(value)=='function' then
                local vars = upvalues(value)
                if debug.getinfo(value,'S').source==source then
                    if not step and vars.state and vars.state.value==state and
                        vars.enter_view and vars.maintain_view and vars.ensure_mods_tab then
                        step=value
                        functions,tables,preferred,found,list_slots={},{},{},{},{}
                        head,tail=1,0
                        seen={[value]=true}
                        local translation=vars.translation and vars.translation.value
                        if type(translation)=='table' and type(translation.refresh)=='function' then
                            local refresh_vars=upvalues(translation.refresh)
                            if refresh_vars.state and refresh_vars.state.value==state then found.translation=translation end
                        end
                    end
                    if step then
                        for name,entry in pairs(vars) do
                            if type(entry.value)=='function' and not found[name] then found[name]=entry.value end
                        end
                        if vars.mod_list and type(vars.mod_list.value)=='function' then
                            list_slots[#list_slots+1]={fn=value,slot=vars.mod_list.slot,original=vars.mod_list.value}
                        end
                    end
                end
                for _,entry in pairs(vars) do queue(entry.value) end
            elseif type(value)=='table' then
                -- Avoid walking every registered value, runtime cache and game global.
                for name,child in next,value do
                    table_entries=table_entries+1
                    if table_entries>4096 then return nil,'callback table budget exhausted' end
                    if name~='env' and name~='values' and name~='options' and name~='mods' and name~='texts' and
                        (type(child)=='function' or type(child)=='table') then
                        queue(child)
                    end
                end
            end
        end
    end
    if inspected>=1024 then return nil,'callback graph budget exhausted' end
    if not step then return nil,'provider update callback unavailable' end
    if #list_slots~=1 then return nil,'provider category callback ambiguous or unavailable' end
    for _,name in ipairs({'escape_menu','enter_view','leave_view','maintain_view','update_apply',
        'update_visuals','neutralize_dialog','show_text','get32','put32','put8','drop_pending'}) do
        if type(found[name])~='function' then return nil,'provider view helper unavailable: '..name end
    end
    found.state,found.list_slot = state,list_slots[1]
    return found
end

function OptionsTab.new(env, app, log)
    local self = {env=env,app=app,log=log,elapsed=0}
    local function note(message)
        if self.message~=message then log('OPTIONS_TAB '..message);self.message=message end
    end
    function self:connect(menu)
        if self.menu==menu then return end
        if type(menu)~='table' or menu.api~=1 or menu.version~=3 or type(menu.ready)~='function' or not menu.ready() then return end
        if not debug or not debug.getupvalue or not debug.setupvalue then return end
        local root=rawget(env,'update')
        self.connect_ticks=(self.connect_ticks or 0)+1
        if self.searched_menu==menu and self.searched_root==root and
            self.connect_ticks<(self.retry_tick or 0) then return end
        self.searched_menu,self.searched_root=menu,root
        self.retry_tick=self.connect_ticks+120
        local hooks,why = discover(root,menu,env)
        if not hooks then note('provider layout unavailable: '..tostring(why)..'; retaining MODS categories');return end
        local native = hooks.state.native
        if type(native)~='table' or not native.set_tab_labels or not native.set_label or not native.set_string_arg then return end
        local ffi = require('ffi')
        self.labels = ffi.new('uint32_t[8]')
        self.ffi,self.h,self.menu = ffi,hooks,menu
        local slot = hooks.list_slot
        local function scoped_list()
            local original = slot.original()
            if not self.placed then return original end
            local result = {}
            for _,category in ipairs(original) do
                if (CATEGORIES[category.id]==true)==(self.helper_scope==true) then result[#result+1]=category end
            end
            return result
        end
        debug.setupvalue(slot.fn,slot.slot,scoped_list)
        note('checked provider view connected')
    end
    function self:unavailable()
        if not self.h or rawget(env,'ModOptionsMenu')~=self.menu or not self.menu.ready() then return 'provider unavailable' end
        local runtime=rawget(env,'BingusRuntime')
        local status=runtime and runtime.statuses and runtime.statuses.ModOptionsMenu
        if status and status.state~='running' then return 'provider '..tostring(status.state) end
    end
    function self:screen()
        local why=self:unavailable()
        if why then return nil,why end
        local screen,status = self.h.escape_menu()
        if status=='open' then return screen,status end
        return nil,status
    end
    function self:refresh_language(language)
        if not self.h or not self.h.translation or self.text_language==language then return end
        -- MOM refreshes on opening before the helper's language poll runs.
        -- Refresh its cached text model after that poll, without touching values.
        local ok,why=pcall(self.h.translation.refresh)
        if ok then
            self.text_language=language;log('OPTIONS_TAB texts refreshed '..language)
        else note('text refresh '..tostring(why)) end
    end
    function self:owned(screen)
        if not self.slot or not self.title_pointer then return false end
        local h,bar = self.h,screen+BAR
        return h.get32(bar+LABELS+4*self.slot)==TEMPLATE and
            self:text_pointer(bar+TEXT+STRIDE*self.slot)==self.title_pointer
    end
    function self:text_pointer(widget)
        if self.h.get32(widget+272)~=TEMPLATE then return nil end
        local count=tonumber(self.ffi.cast('uint8_t *',widget+616)[0])
        if count>14 then return nil end
        for i=0,count-1 do
            local arg=widget+280+24*i
            if self.h.get32(arg)==0xab2a7b35 and self.h.get32(arg+4)==1 then
                return tonumber(self.ffi.cast('uintptr_t *',arg+8)[0])
            end
        end
    end
    function self:leave(screen)
        if not self.view then return end
        local h = self.h
        if screen==self.view.screen then h.leave_view(self.view)
        else h.drop_pending() end
        self.view=nil
    end
    function self:before()
        if not self.h or rawget(env,'ModOptionsMenu')~=self.menu then return end
        local screen,status = self.h.escape_menu()
        if status~='open' then return end
        local h,bar = self.h,screen+BAR
        if not self:owned(screen) then self.placed=false;return end
        if h.get32(bar+CURRENT)~=self.slot then self:leave(screen) end
        local count = h.get32(bar+COUNT)
        if count==self.slot+1 then
            -- Hide just our last slot while older MODS/BTO/HUD+ adapters run.
            -- Native input and rendering see the full count after this scope.
            h.put32(bar+COUNT,count-1)
            self.hidden={screen=screen,count=count}
        end
    end
    function self:restore()
        local hidden = self.hidden
        self.hidden=nil
        local screen,status
        if hidden then screen,status=self.h.escape_menu() end
        if hidden and screen==hidden.screen and status=='open' then
            if self:owned(hidden.screen) then self.h.put32(hidden.screen+BAR+COUNT,hidden.count)
            else self.placed,self.slot=false,nil end
        end
        return hidden~=nil,screen,status
    end
    function self:place(screen, dt)
        local h,bar = self.h,screen+BAR
        if self:owned(screen) then
            if h.get32(bar+COUNT)~=self.slot+1 then self.placed=false;return false end
            self.placed,self.screen_id=true,screen;return true
        end
        self:leave(screen)
        self.placed=false
        local count,current = h.get32(bar+COUNT),h.get32(bar+CURRENT)
        if count<4 or count>=8 or current>=count then
            note('tab bar unavailable: count='..count..' current='..current);return false
        end
        if self.screen_id~=screen or self.observed~=count then
            self.screen_id,self.observed,self.elapsed,self.observed_at=screen,count,0,nil
        end
        local now=self.app.time_since_launch and self.app.time_since_launch()
        if type(now)=='number' and now==now and now>=0 and now<math.huge then
            if not self.observed_at or now<self.observed_at then self.observed_at=now end
            self.elapsed=now-self.observed_at
        else self.elapsed=self.elapsed+dt end
        if self.elapsed<0.5 then return false end
        for i,label in ipairs({0xd876b36e,0x78934e12,0x8c02bd80}) do
            if h.get32(bar+LABELS+4*(i-1))~=label then
                note('stock tab layout unavailable at slot '..(i-1));return false
            end
        end
        -- set_tab_labels clears COUNT text arguments. Keep the existing owners'
        -- label/string pointers, not copies of their title or translation code.
        local captions = {}
        for index=0,count-1 do
            self.labels[index]=h.get32(bar+LABELS+4*index)
            local widget = bar+TEXT+STRIDE*index
            if h.get32(widget+272)==TEMPLATE then
                local args = tonumber(self.ffi.cast('uint8_t *',widget+616)[0])
                if args>14 then return false end
                for i=0,args-1 do
                    local arg=widget+280+24*i
                    if h.get32(arg)==0xab2a7b35 and h.get32(arg+4)==1 then
                        captions[#captions+1]={widget=widget,pointer=self.ffi.cast('const char **',arg+8)[0]}
                    end
                end
            end
        end
        self.labels[count]=TEMPLATE
        h.state.native.set_tab_labels(bar,self.labels,count+1)
        for _,caption in ipairs(captions) do
            h.state.native.set_label(caption.widget,TEMPLATE)
            h.state.native.set_string_arg(caption.widget,0xab2a7b35,caption.pointer)
        end
        h.put32(bar+STRIDE*current+11004,3);h.put8(bar+STRIDE*current+11021,1)
        h.show_text(bar+TEXT+STRIDE*count,'HD2H')
        self.slot=count
        self.title_pointer=self:text_pointer(bar+TEXT+STRIDE*count)
        self.placed=self.title_pointer~=nil
        if not self.placed then note('tab text ownership unavailable; retaining MODS categories');return false end
        -- A MODS view built before the new tab must drop helper categories too.
        if h.state.view then h.state.view.revision=-1 end
        note('HD2H tab added at slot '..count)
        return true
    end
    function self:after(dt,observed,screen,status)
        if observed then
            local why=self:unavailable()
            if why then screen,status=nil,why end
        else screen,status=self:screen() end
        if self.screen_status~=status and self.h then
            self.screen_status=status
            log('OPTIONS_TAB screen '..tostring(status))
        end
        if not screen then
            if status=='covered' then return end
            if self.h then self:leave(nil) end
            self.placed,self.screen_id=false,nil
            return
        end
        if not self:place(screen,dt) then return end
        local h = self.h
        if h.get32(screen+BAR+CURRENT)~=self.slot then return end
        local foreign = h.state.view
        self.helper_scope=true;h.state.view=self.view
        local ok,why = pcall(function()
            if not h.state.view then h.enter_view(screen) else h.maintain_view(h.state.view) end
            h.update_apply(h.state.view);h.update_visuals(h.state.view,dt);h.neutralize_dialog(h.state.view)
        end)
        self.view=h.state.view;h.state.view=foreign;self.helper_scope=false
        if not ok then error(why,0) end
    end
    function self:install()
        local previous = rawget(env,'update')
        if previous==self.wrapper or type(previous)~='function' then return end
        local function finish(dt,ok,...)
            -- Reuse only the post-update observation; never carry screen pointers across frames.
            local observed,screen,status=self:restore()
            if not ok then error((...),0) end
            local good,failure=pcall(self.after,self,dt,observed,screen,status)
            if not good then
                note('view '..tostring(failure))
                pcall(function() self:leave(self:screen()) end)
                self.placed=false
            end
            return ...
        end
        local wrapper
        wrapper=function(...)
            if self.wrapper~=wrapper then return previous(...) end
            if not self.frame_seen then
                self.frame_seen=true;log('OPTIONS_TAB frame callback active')
            end
            local ok,why = pcall(self.before,self)
            if not ok then note('before '..tostring(why)) end
            local dt = select(1,...)
            if type(dt)~='number' or dt~=dt or dt<0 or dt==math.huge then dt=0 end
            return finish(dt,pcall(previous,...))
        end
        self.wrapper=wrapper;rawset(env,'update',wrapper)
    end
    function self:tick(menu,language)
        self:connect(menu)
        if language then self:refresh_language(language) end
        if not self.startup_registered and self.h then self:install() end
    end
    -- The game can cache its update callback. Wrap the final mod chain at
    -- loader startup, before that cache, rather than replacing it in a frame.
    local loader=rawget(env,'CowboyBingusModLoader')
    if loader and type(loader.after_startup)=='function' then
        self.startup_registered=true
        local ok,accepted=pcall(loader.after_startup,function()
            self:install()
            log('OPTIONS_TAB startup frame callback installed')
        end)
        if not ok or accepted==false then
            self.startup_registered=false
            note('startup callback unavailable; using legacy update integration')
        end
    end
    return self
end
return OptionsTab
