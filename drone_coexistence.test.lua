return function(equal,read,fixture,finish)
    local runtime=read('../DroneRemoteControl/src/runtime.lua')
    for _,name in ipairs({'binary','lease','flight','control_hotkey','cooperation','controller','clock'}) do
        runtime=runtime:gsub('%-%- @'..name:upper()..'@',function()
            return read('../DroneRemoteControl/src/'..name..'.lua')
        end)
    end
    runtime=runtime:gsub('%-%- @PLATFORM@','return {new=function() return DRONE_CHANNEL end}')
        :gsub('%-%- @READER@','return {new=function() return DRONE_READER end}')
        :gsub('%-%- @ENGINE@','return {new=function() return DRONE_ENGINE end}')
    assert(not runtime:find('%-%- @'))
    local function setup(env,keys)
        local memory={[1000]='\190\0\0\0',[1100]='\4\0',[1284]='POS',[1300]='ROT',[2000]='KEY'}
        local snapshot={brain={address=1000,valid=function() return true end},camera=10000,camera_row=1100,
            drone_position={0,5,2},actor_position={0,0,0},deployed=true,token='DRONE',heat=0,reserve=3,
            overheated=false,fire_valid=function() return true end,camera_valid=function() return true end}
        local bindings={aim_mode=4,backpack=84,fire=1,forward=87,
            back=83,left=65,right=68,up=32,down=17,binding_token='DRONE-KEYS',
            pack_entries={{2000,'KEY'}},valid=function() return true end}
        env.DRONE_CHANNEL={foreground=function() return env.TEST_CHANNEL.foreground() end,
            now=function() return env.stingray.Application.time_since_launch() end,
            down=function(_,vk) return keys[vk]==true end,
            read=function(_,at) return memory[at] end,
            write=function(_,at,value) memory[at]=value;return true end,
            mouse_delta=function() return 0,0 end,vector=function() return {0,1,0} end,
            floats=function(_,value) return #value==4 and 'DRONE-ROT' or 'DRONE-POS' end,
            fire=function(_,_,value) env.drone_firing=value end}
        env.DRONE_READER={bindings=function() return bindings end,
            raw=function(_,at) return memory[at] or 'FORWARD' end,
            word=function(_,at) return memory[at]=='\190\0\0\0' and 190 or 0 end,
            snapshot=function() snapshot.menu_active=env.TEST_MENU.menu_active();return snapshot end}
        local old_open=env.TEST_RADIAL.open
        env.TEST_RADIAL.open=function(self,...)
            self.mouse={focus=true};return old_open(self,...)
        end
        env.TEST_RADIAL.restore=function(self)
            if env.restore_error then error('cursor restore pending') end
            self.mouse=nil
        end
        local old_close=env.TEST_RADIAL.close
        env.TEST_RADIAL.close=function(self) old_close(self);self:restore() end
        env.DRONE_ENGINE={prepare=function() end,capture_input=function()
            equal(env.TEST_RADIAL.opened,false,'wheel closed before drone captures input')
            equal(env.TEST_RADIAL.mouse,nil,'wheel relinquishes focus first')
            equal(env.HD2StratagemHotkeys.remote_owner,env.DroneRemoteControl.input_owner,'wheel handoff acknowledged')
            equal(env.HD2HelperAutoReload.remote_owner,env.DroneRemoteControl.input_owner,'reload handoff acknowledged')
            env.drone_capture=true
        end,clear=function()
            if env.drone_cleanup_error then error('focus restore pending') end
            env.drone_capture=false
        end,move=function() env.drone_moved=true end,hud=function() end}
        env.stingray.Unit,env.stingray.World,env.stingray.Window,env.stingray.Mouse={},{},{},{}
        env.stingray.Vector3,env.stingray.Quaternion=function() end,function() end
        env.print=function() end
        local previous=env.update
        env.update=function(...)
            if env.base_error then error('original update failed') end
            return previous(...)
        end
        setfenv(assert(loadstring(runtime)),env)()
        env.drone_snapshot,env.drone_memory=snapshot,memory
    end
    for _,order in ipairs({'drone-first','helper-first'}) do
        for _,mode in ipairs({'hold','toggle'}) do
            for _,vk in ipairs({164,5,6}) do
                local f=fixture(nil,vk,nil,nil,mode,order=='drone-first' and setup or nil)
                if order=='helper-first' then setup(f.env,f.keys) end
                local env=f.env
                local a,b,c=f.step(0.02)
                equal(a,123,'coexistence update return');equal(b,nil,'coexistence nil return');equal(c,321,'coexistence tail')
                f.keys[vk]=true;if mode=='toggle' then f.latch(true) end;f.step(0.02)
                equal(env.TEST_RADIAL.opened,true,'ordinary wheel works with idle drone mod')
                f.keys[4],f.keys[84]=true,true;f.step(0.02)
                equal(env.DroneRemoteControl.control_active,true,'both load orders enter with companions enabled')
                equal(env.HD2StratagemHotkeys.config.radial,true,'wheel preference remains on')
                equal(env.HD2HelperAutoReload.config.enabled,true,'reload preference remains on')
                f.keys[84],f.keys[49],f.keys[1]=false,true,true
                f.shot.ammo,f.shot.charge_kind,f.shot.charging=0,'epoch',true
                f.shot.charge_limit,f.shot.charge_elapsed,f.shot.charge_max=2.7,2.7,2.8
                for _=1,5 do f.step(0.02) end
                equal(env.drone_firing,true,'attack controls drone only')
                equal(env.TEST_RADIAL.opened,false,'wheel stays closed during control')
                equal(#f.events,0,'remote control emits no helper fire release, reload or command')
                f.keys[84]=true;f.step(0.02)
                equal(env.DroneRemoteControl.control_active,false,'fresh backpack exits')
                equal(env.DroneRemoteControl.blocking_inputs,false,'input gate released after restoration')
                for _=1,5 do f.step(0.02) end
                equal(#f.events,0,'held inputs at exit cannot replay automation')
                f.keys[vk],f.keys[1],f.keys[84],f.keys[4]=false,false,false,false
                if mode=='toggle' then f.latch(false) end
                f.shot.ammo,f.shot.charging=1,false
                for _=1,5 do f.step(0.02) end
                equal(env.HD2StratagemHotkeys.remote_rearm,nil,'wheel releases rearm gate')
                equal(env.HD2HelperAutoReload.remote_rearm,nil,'reload releases rearm gate')
                equal(#f.events,0,'held number is not replayed on resume')
                f.keys[vk]=true;if mode=='toggle' then f.latch(true) end;f.step(0.02)
                equal(env.TEST_RADIAL.opened,true,'fresh wheel activation '..order..' '..mode..' '..vk..
                    ' reason='..tostring(env.HD2StratagemHotkeys.reason))
                f.center();f.keys[vk]=false;f.latch(false);f.step(0.02)
                f.keys[49]=false;f.keys[1]=true;f.step(0.06)
                f.shot.ammo=0;f.keys[1]=false;f.step(0.06);finish(f)
                local reloads=0
                for _,event in ipairs(f.events) do
                    if event.route=='reload' and event.down then reloads=reloads+1 end
                    equal(event.route~='command' and event.route~='charge',true,'no stale sector or charge release after exit')
                end
                equal(reloads,1,'fresh fire-release cycle resumes auto reload')
                equal(env.shutdown(),'closed','coexistence shutdown preserves original')
            end
        end
    end
    local f=fixture();setup(f.env,f.keys);f.step(0.02);f.keys[5],f.keys[4]=true,true;f.step(0.02)
    f.env.restore_error=true;f.keys[84]=true;f.step(0.02)
    equal(f.env.DroneRemoteControl.control_active,false,'failed companion cleanup refuses capture')
    equal(f.env.drone_capture,false,'no partial drone focus capture')
    equal(f.env.drone_memory[1000],'\190\0\0\0','failed handoff leaves native AI unchanged')
    f.env.restore_error=false;f.env.shutdown()

    f=fixture();setup(f.env,f.keys);f.step(0.02);f.keys[5],f.keys[4]=true,true;f.step(0.02);f.keys[84]=true;f.step(0.02)
    f.keys[84]=false;f.step(0.02);f.env.drone_cleanup_error=true;f.keys[84]=true;f.step(0.02)
    equal(f.env.DroneRemoteControl.blocking_inputs,true,'drone restore failure retains companion gate')
    f.keys[49],f.keys[1]=true,true;f.shot.ammo=0
    for _=1,5 do f.step(0.02) end
    equal(#f.events,0,'pending drone restore blocks all companion automation')
    f.env.drone_cleanup_error=false;f.step(0.02)
    equal(f.env.DroneRemoteControl.blocking_inputs,false,'restore retry releases companion gate')
    f.env.shutdown()

    for _,fault in ipairs({'focus','respawn','heat','foreign-update'}) do
        f=fixture();setup(f.env,f.keys);f.step(0.02);f.keys[5],f.keys[4]=true,true;f.step(0.02)
        f.keys[84]=true;f.step(0.02)
        equal(f.env.DroneRemoteControl.control_active,true,'cleanup scenario starts active')
        if fault=='focus' then f.focus(false)
        elseif fault=='respawn' then f.env.drone_snapshot.token='NEW-AVATAR'
        elseif fault=='heat' then f.env.drone_snapshot.overheated=true
        elseif fault=='foreign-update' then f.env.base_error=true end
        local ok,why=pcall(f.step,0.02)
        if fault=='foreign-update' then
            equal(ok,false,'foreign update error remains visible')
            equal(tostring(why):find('original update failed',1,true)~=nil,true,'foreign error preserved')
        end
        equal(f.env.DroneRemoteControl.control_active,false,'control stops on '..fault)
        equal(f.env.DroneRemoteControl.blocking_inputs,false,'gate restored on '..fault)
        equal(f.env.drone_memory[1000],'\190\0\0\0','AI restored on '..fault)
        equal(f.env.drone_memory[1100],'\4\0','camera restored on '..fault)
        equal(f.env.HD2StratagemHotkeys.remote_owner,nil,'wheel owner released on '..fault)
        equal(f.env.HD2HelperAutoReload.remote_owner,nil,'reload owner released on '..fault)
        f.env.base_error=false;f.env.shutdown()
    end

    f=fixture();setup(f.env,f.keys);f.step(0.02);f.keys[5],f.keys[4]=true,true;f.step(0.02)
    f.keys[84]=true;f.step(0.02)
    f.step(0)
    equal(f.env.DroneRemoteControl.control_active,true,'zero-time update keeps remote control active')
    f.step(0.5)
    equal(f.env.DroneRemoteControl.control_active,true,'long frame uses bounded movement instead of refusing control')
    equal(f.env.HD2StratagemHotkeys.remote_owner,f.env.DroneRemoteControl.input_owner,'long frame retains input owner')
    f.env.shutdown()

    f=fixture();setup(f.env,f.keys);f.step(0.02)
    equal(f.env.TEST_MENU.menu_active(),false,'aim-mode scenario begins without native stratagem menu')
    f.keys[4]=true;f.step(0.02);f.keys[84]=true;f.step(0.02)
    equal(f.env.DroneRemoteControl.control_active,true,'aim-mode combo enters without opening helper wheel')
    equal(f.env.TEST_RADIAL.opened,false,'aim-mode combo does not open helper wheel')
    f.keys[4],f.keys[84]=false,false;f.step(0.02);f.keys[84]=true;f.step(0.02)
    equal(f.env.DroneRemoteControl.control_active,false,'backpack alone exits aim-mode control')
    f.env.shutdown()

    f=fixture();f.step(0.02)
    local owner,other={},{}
    f.env.HD2HelperAutoReload.release_at=10
    equal(f.env.HD2HelperAutoReload.suspend_input(owner),true,'pending reload up acknowledged before handoff')
    equal(#f.events,1,'only pending reload release sent')
    equal(f.events[1].down,false,'pending reload released, never pressed')
    equal(f.env.HD2HelperAutoReload.suspend_input(other),false,'reload owner cannot be stolen')
    equal(f.env.HD2StratagemHotkeys.suspend_input(owner),true,'wheel handoff acknowledges quiet input')
    equal(f.env.HD2StratagemHotkeys.resume_input(other),false,'wheel owner cannot be stolen')
    f.env.HD2HelperAutoReload.resume_input(owner);f.env.HD2StratagemHotkeys.resume_input(owner)
    f.env.shutdown()
end
