local LiveOptions = {}
function LiveOptions.new(env, app, load, schema, language, log)
    local self = {values = {}, records = {}, listeners = {}, revision = 0}
    if LiveOptions.Tab then self.tab=LiveOptions.Tab.new(env,app,log) end
    local function note(record, reason)
        if record.reason ~= reason then log('MOD_OPTIONS '..record.id..' '..tostring(reason));record.reason = reason end
    end
    local function index_of(values, value)
        for index, item in ipairs(values) do if item == value then return index end end
    end
    local function text_for(definition)
        local selected = type(language) == 'table' and language.current or language
        return definition.text[selected] or definition.text.en
    end
    local function label(definition, key, index)
        if type(language) ~= 'table' then
            local text = text_for(definition)[key]
            return index and text[index] or text
        end
        -- Mod Options Menu v1.2 refreshes function-backed text without changing IDs or values.
        return function()
            local text = text_for(definition)[key]
            return index and text[index] or text
        end
    end
    for _, definition in ipairs(schema) do
        local value = false
        if not definition.toggle then value = definition.values[1] end
        if type(app.can_get) == 'function' then
            local ok, present = pcall(app.can_get,'lua','mods/hd2_helper/'..definition.prefix..definition.key)
            if not ok then value = definition.invalid
            elseif present then
                local loaded, selected = pcall(load,'mods/hd2_helper/'..definition.prefix..definition.key)
                if loaded and (definition.toggle and type(selected) == 'boolean' or
                    not definition.toggle and index_of(definition.values,selected)) then value = selected
                else value = definition.invalid end
            end
        end
        self.values[definition.key] = value
        self.records[#self.records+1] = {definition = definition,id = definition.id}
    end
    function self:change(record, selected)
        local d = record.definition
        local value
        if d.toggle and type(selected) == 'boolean' then value = selected
        elseif not d.toggle and type(selected) == 'number' and selected == math.floor(selected) and
            selected >= 1 and selected <= #d.values then value = d.values[selected]
        else note(record,'invalid menu value; keeping applied setting');return end
        if self.values[d.key] ~= value then
            self.values[d.key] = value;self.revision = self.revision+1
        end
    end
    function self:notify(now)
        for name, listener in pairs(self.listeners) do
            if listener.revision ~= self.revision and now >= (listener.retry_at or 0) then
                local ok, why = pcall(listener.apply,self.values)
                if ok then listener.revision,listener.reason = self.revision,nil
                else
                    listener.retry_at = now+0.25
                    if listener.reason ~= tostring(why) then
                        log('MOD_OPTIONS apply '..name..' '..tostring(why));listener.reason = tostring(why)
                    end
                end
            end
        end
    end
    function self:attach(name, apply)
        self.listeners[name] = {apply = apply,revision = -1}
        self:notify(0)
    end
    function self:tick()
        local now = app.time_since_launch and app.time_since_launch() or 0
        if type(now) ~= 'number' or now ~= now or now == math.huge or now < 0 then return end
        if type(language) == 'table' then language:poll(now) end
        local menu = rawget(env,'ModOptionsMenu')
        local compatible = type(menu) == 'table' and menu.api == 1 and type(menu.version) == 'number' and menu.version >= 3 and
            type(menu.register_option) == 'function' and type(menu.get) == 'function' and
            type(menu.on_change) == 'function'
        if compatible and now >= (self.poll_at or 0) then
            self.poll_at = now+0.25
            if self.menu ~= menu then
                self.menu = menu
                for _, record in ipairs(self.records) do
                    record.registered,record.subscribed,record.retry_at,record.reason = nil,nil,nil,nil
                end
            end
            for _, record in ipairs(self.records) do
                local d = record.definition
                if not record.registered and now >= (record.retry_at or 0) then
                    local initial = self.values[d.key]
                    local default = initial
                    if not d.toggle then default = index_of(d.values,initial) end
                    if default ~= nil then
                        local choices
                        if not d.toggle then
                            choices = {}
                            for index = 1,#d.values do choices[index] = label(d,'choices',index) end
                        end
                        local spec = {type = d.toggle and 'toggle' or 'choice',label = label(d,'label'),
                            description = label(d,'description'),mod = label(d,'mod'),mod_id = d.category,
                            choices = choices,default = default,gap = d.gap}
                        local ok, registered, why = pcall(menu.register_option,record.id,spec)
                        if ok and registered == true then record.registered = true
                        else note(record,why or registered);record.retry_at = now+2 end
                    else note(record,'invalid Arsenal choice; registration refused');record.retry_at = now+2 end
                end
                if record.registered then
                    if not record.subscribed then
                        local ok, subscribed = pcall(menu.on_change,record.id,function(value)
                            if self.menu == menu then self:change(record,value) end
                        end)
                        if ok and subscribed ~= false then record.subscribed = true
                        else note(record,subscribed) end
                    end
                    local ok, selected = pcall(menu.get,record.id)
                    if ok then self:change(record,selected) else note(record,selected) end
                end
            end
        elseif menu and not compatible and self.menu_warning ~= menu then
            self.menu_warning = menu
            log('MOD_OPTIONS requires Mod Options Menu v1.2 / API 1 version 3; Arsenal settings retained')
        end
        self:notify(now)
        if self.tab then self.tab:tick(menu,type(language)=='table' and language.current or language) end
    end
    return self
end
return LiveOptions
