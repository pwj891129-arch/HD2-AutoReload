return function(equal,read,fixture,finish)
    local LiveOptions = dofile('mod_options.lua')
    local schema = assert(loadstring(read('dist/menu-schema.generated.lua')))()
    local function menu(saved)
        local m = {api=1,version=3,max_options=32,options={},values={},callbacks={},saved=saved or {},groups={},registrations=0}
        function m.register_option(id,spec)
            if m.fail == id then return false,'temporary registration failure' end
            if m.options[id] then return true end
            assert(type(spec.mod_id)=='string' and #spec.mod_id<=64)
            if spec.type=='toggle' then assert(type(spec.default)=='boolean')
            else assert(spec.type=='choice' and #spec.choices>=2 and #spec.choices<=16 and
                spec.default>=1 and spec.default<=#spec.choices) end
            m.groups[spec.mod_id]=(m.groups[spec.mod_id] or 0)+1
            assert(m.groups[spec.mod_id]<=32,'category row limit')
            m.options[id]=spec;m.registrations=m.registrations+1
            local value=m.saved[id]
            if value==nil then value=spec.default end
            m.values[id]=value
            return true
        end
        function m.get(id)
            if m.get_failure then error('temporary get failure') end
            return m.values[id]
        end
        function m.on_change(id,callback)
            if m.subscription_failure then error('temporary callback failure') end
            m.callbacks[id]=callback -- v1 API does not promise a return value.
        end
        function m.apply(values)
            for id,value in pairs(values) do
                m.saved[id],m.values[id]=value,value
                if m.callbacks[id] then m.callbacks[id](value,id) end
            end
        end
        return m
    end
    local prefix='hd2_helper.'
    local function rid(id) return prefix..'autoreload.'..id end
    local function sid(id) return prefix..'stratagem.'..id end
    local now, logs, values = 0,{},{}
    local app={time_since_launch=function() return now end,
        can_get=function(_,resource) return values[resource]~=nil end}
    local function load(resource) return values[resource] end
    local function log(message) logs[#logs+1]=message end
    local env={};local settings=LiveOptions.new(env,app,load,schema,'en',log)
    equal(#settings.records,46,'all Arsenal options exposed')
    equal(settings.values.enabled,false,'missing reload checkbox stays off')
    equal(settings.values.shared_reinforce,false,'missing individual checkbox stays off')
    equal(settings.values.shared_all,'individual','missing bulk uses individual settings')
    local applied,updates=nil,0
    settings:attach('test',function(v) applied=v.enabled;updates=updates+1 end)
    settings:tick();equal(applied,false,'missing menu retains Arsenal')
    env.ModOptionsMenu={api=1,version=2}
    settings:tick();settings:tick()
    equal(#logs,1,'old API logs once and preserves defaults')
    equal(applied,false,'old menu is optional')
    local m=menu({[rid('enabled')]=true,[sid('scale')]=3})
    env.ModOptionsMenu=m;settings:tick()
    equal(m.registrations,46,'all options registered once')
    equal(m.groups['hd2_helper.general'],9,'general category row budget')
    equal(m.groups['hd2_helper.shared'],5,'common category row budget')
    equal(m.groups['hd2_helper.mission'],32,'mission category row budget')
    equal(applied,true,'saved toggle overrides Arsenal off')
    equal(settings.values.scale,1.5,'saved choice mapped to runtime value')
    equal(m.options[sid('shared_reinforce')].default,false,'false defaults passed as boolean')
    now=0.1;settings:tick();equal(#logs,1,'poll cooldown does not claim a supported API is old')
    equal(m.registrations,46,'cooldown does not duplicate registration')
    m.apply({[rid('enabled')]=false,[sid('scale')]=5})
    equal(applied,true,'callbacks batch before consumer update')
    settings:tick();equal(applied,false,'APPLY takes effect on next update')
    equal(settings.values.scale,3,'300 percent supported live')
    local revision=settings.revision
    m.apply({[sid('scale')]=6,[rid('enabled')]='on',[sid('slow')]=0/0})
    settings:tick();equal(settings.revision,revision,'invalid menu values refused')
    equal(settings.values.scale,3,'invalid choice preserves applied scale')
    m.values[sid('slow')]=2 -- API set changes applied values without callbacks.
    now=0.4;settings:tick();equal(settings.values.slow,true,'API set is picked up by polling')
    env.ModOptionsMenu=menu(m.saved);now=0.8;settings:tick()
    equal(env.ModOptionsMenu.registrations,46,'replacement API re-registers stable IDs')
    local applied_before=settings.values.enabled
    m.apply({[rid('enabled')]=not applied_before})
    equal(settings.values.enabled,applied_before,'obsolete menu callback cannot change current settings')
    m=env.ModOptionsMenu;m.get_failure=true;now=1.1;settings:tick()
    equal(settings.values.enabled,applied_before,'temporary get failure preserves applied settings')
    m.get_failure=false;m.values[rid('enabled')]=true;now=1.4;settings:tick()
    equal(settings.values.enabled,true,'get failure can recover')
    local subscriptions=menu();subscriptions.subscription_failure=true;env.ModOptionsMenu=subscriptions
    settings=LiveOptions.new(env,app,load,schema,'en',log);settings:tick()
    equal(next(subscriptions.callbacks),nil,'callback failure does not invent a subscription')
    subscriptions.subscription_failure=false;now=1.8;settings:tick()
    equal(type(subscriptions.callbacks[rid('enabled')]),'function','callback subscription retries')

    local korean=menu();env.ModOptionsMenu=korean
    local ko=LiveOptions.new(env,app,load,schema,'ko',log);ko:tick()
    equal(korean.options[sid('shared_reinforce')].label,'공용: 증원','Korean label is UTF-8 text')
    equal(korean.options[rid('enabled')].mod,'HD2 헬퍼','Korean category label')
    local language = {current='ko',poll=function() end}
    local dynamic=menu({[rid('enabled')]=true,[sid('scale')]=4})
    env.ModOptionsMenu=dynamic
    local automatic=LiveOptions.new(env,app,load,schema,language,log);automatic:tick()
    equal(type(dynamic.options[rid('enabled')].label),'function','provider receives automatic language text function')
    equal(dynamic.options[sid('shared_reinforce')].label(),'공용: 증원','game Korean selected')
    equal(dynamic.options[rid('enabled')].mod(),'HD2 헬퍼','dynamic Korean category')
    equal(automatic.values.scale,2,'saved value retained independently of language')
    language.current='en';now=now+.3;automatic:tick()
    local reinforce
    for _,definition in ipairs(schema) do if definition.key=='shared_reinforce' then reinforce=definition end end
    equal(dynamic.options[sid('shared_reinforce')].label(),reinforce.text.en.label,'English switch without re-registering')
    equal(dynamic.options[rid('enabled')].mod(),'HD2 Helper','dynamic English category')
    equal(dynamic.registrations,46,'language change never duplicates registration')
    equal(automatic.values.enabled,true,'language change never resets toggle')
    equal(automatic.values.scale,2,'language change never resets choice')
    language.current='fr'
    equal(dynamic.options[rid('enabled')].label(),schema[1].text.fr.label,'French option language is translated')
    language.current='zz'
    equal(dynamic.options[rid('enabled')].label(),schema[1].text.en.label,'unsupported option language is English')
    local scale
    for _,definition in ipairs(schema) do if definition.key=='scale' then scale=definition end end
    equal(dynamic.options[sid('scale')].choices[2](),scale.text.en.choices[2],'choice text uses English fallback')
    local failing=menu();failing.fail=sid('mission_flag');env.ModOptionsMenu=failing
    settings=LiveOptions.new(env,app,load,schema,'en',log);now=1;settings:tick()
    equal(failing.registrations,45,'one registration failure does not block other rows')
    failing.fail=nil;now=3.1;settings:tick()
    equal(failing.registrations,46,'failed registration retries')
    values['mods/hd2_helper/autoreload_setting_railgun_threshold']=0.91
    env.ModOptionsMenu=menu();settings=LiveOptions.new(env,app,load,schema,'en',log);settings:tick()
    equal(settings.values.railgun_threshold,false,'malformed Arsenal threshold stays fail-closed')
    equal(env.ModOptionsMenu.options[rid('railgun_threshold')],nil,'malformed baseline does not become a live default')
    values={}

    local f=fixture({autoreload_setting_enabled=false,autoreload_setting_charge90=false,
        autoreload_setting_vehicle=false,stratagem_option_radial=false,stratagem_option_hotkeys=false})
    m=menu({[rid('enabled')]=true,[rid('charge90')]=true,[sid('radial')]=true,[sid('hotkeys')]=true})
    f.env.ModOptionsMenu=m;f.step(0.02)
    equal(f.env.HD2HelperAutoReload.config.enabled,true,'Arsenal OFF can be enabled by saved in-game setting')
    equal(f.env.TEST_READER.charge_enabled,true,'Arsenal OFF charge reader can be activated')
    equal(f.env.HD2StratagemHotkeys.config.radial,true,'Arsenal OFF wheel can be activated')
    equal(f.env.HD2StratagemHotkeys.config.hotkeys,true,'Arsenal OFF shortcuts can be activated')
    f.env.shutdown()

    f=fixture();m=menu();f.env.ModOptionsMenu=m;f.step(0.02)
    f.env.HD2HelperAutoReload.release_at=100
    m.apply({[rid('enabled')]=false});f.step(0.02)
    equal(#f.events,1,'live disable releases owned reload pulse once')
    equal(f.events[1].route,'reload','live disable only releases reload')
    equal(f.events[1].down,false,'live disable never presses a key or fires')
    f.env.shutdown()

    for _,load_order in ipairs({'menu-first','helper-first'}) do
        m=menu({[rid('enabled')]=false,[rid('charge90')]=false,[rid('vehicle')]=false,
            [sid('radial')]=false,[sid('hotkeys')]=false})
        local function setup(target) target.ModOptionsMenu=m end
        local f=fixture(nil,5,nil,nil,nil,load_order=='menu-first' and setup or nil)
        if load_order=='helper-first' then setup(f.env) end
        f.step(0.02)
        equal(f.env.HD2HelperAutoReload.config.enabled,false,'saved reload off after '..load_order)
        equal(f.env.HD2StratagemHotkeys.config.radial,false,'saved radial off after '..load_order)
        equal(f.env.TEST_READER.charge_enabled,false,'saved charge off reaches native reader')
        equal(m.registrations,46,'both load orders register once')
        m.apply({[rid('enabled')]=true,[rid('charge90')]=true,[rid('vehicle')]=true,
            [rid('railgun_threshold')]=2,[sid('radial')]=true,[sid('hotkeys')]=true,
            [sid('scale')]=2,[sid('slow')]=2,[sid('shared_all')]=2,[sid('mission_all')]=2})
        f.step(0.02)
        equal(f.env.HD2HelperAutoReload.config.enabled,true,'reload enabled without restart')
        equal(f.env.HD2HelperAutoReload.config.vehicle,true,'vehicle reload live')
        equal(f.env.HD2HelperAutoReload.config.railgun_threshold,0.9,'90 percent live')
        equal(f.env.TEST_READER.charge_enabled,true,'charge enabled without restarting native reader')
        equal(f.env.HD2StratagemHotkeys.config.radial,true,'radial enabled without restart')
        equal(f.env.HD2StratagemHotkeys.config.hotkeys,true,'hotkeys enabled without restart')
        equal(f.env.HD2StratagemHotkeys.config.scale,1.25,'125 percent live')
        equal(f.env.TEST_RADIAL.scale,1.25,'renderer scale updated')
        equal(f.env.HD2StratagemHotkeys.config.delay,0.030,'30ms delay live')
        local shared=f.env.HD2StratagemHotkeys.config.shared
        equal(shared[93],true,'shared bulk applies')
        equal(shared[11],true,'mission bulk applies')
        m.apply({[sid('shared_mission_all')]=3});f.step(0.02)
        equal(shared[93],false,'combined OFF overrides shared bulk')
        equal(shared[11],false,'combined OFF overrides mission bulk')
        m.apply({[sid('shared_mission_all')]=1,[sid('shared_all')]=1,[sid('mission_all')]=1,
            [sid('shared_reinforce')]=true,[sid('mission_flag')]=true});f.step(0.02)
        equal(shared[93],true,'individual shared restored after bulk')
        equal(shared[11],true,'individual mission restored after bulk')
        equal(shared[145],false,'other individual choices remain off')
        f.step(0.02);f.keys[5]=true;f.step(0.02)
        equal(f.env.TEST_RADIAL.opened,true,'wheel opens with live settings')
        m.apply({[sid('scale')]=4});f.step(0.02)
        equal(f.env.TEST_RADIAL.opened,false,'scale change closes current selection')
        equal(f.env.HD2StratagemHotkeys.pending,nil,'scale change cancels stale selection')
        equal(#f.events,0,'settings change emits no command, reload or fire')
        f.keys[5]=false;f.step(0.02);f.keys[5]=true;f.step(0.02)
        equal(f.env.TEST_RADIAL.opened,true,'fresh activation after settings change')
        f.center();f.keys[5]=false;f.step(0.02)
        m.apply({[sid('radial')]=false,[sid('hotkeys')]=false,[rid('charge90')]=false})
        f.step(0.02);f.step(0.02)
        f.keys[1]=true;f.step(0.06);f.shot.ammo=0;f.keys[1]=false;f.step(0.06);finish(f)
        local presses=0
        for _,event in ipairs(f.events) do if event.route=='reload' and event.down then presses=presses+1 end end
        equal(presses,1,'reload runs after enabling from saved OFF')
        f.env.shutdown()
    end
end
