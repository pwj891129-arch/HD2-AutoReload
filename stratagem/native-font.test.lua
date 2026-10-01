return function(equal)
    local Radial = dofile("radial.lua")
    Radial.Glyphs = dofile("dist/glyphs.generated.lua")
    local debug, template, slot = "core/performance_hud/debug", "content/fonts/core_sans", "88bac99b00000000"
    local fonts = {"e007454455e2d2bb", "fca7631255290a2c"}
    local atlases = {"8d346dcdd08459d5", "9ae590aec7c63b1c"}
    local loaded, complete, failure, next_id, next_gui = true, true, nil, 0, 10
    local surfaces, shapes, drawn, traces, binds = {}, {}, {}, {}, 0
    local function vector(x, y, z) return {x = x, y = y, z = z} end
    local handles = {}
    local function handle(id)
        if not handles[id] then handles[id] = {resource = id} end
        return handles[id]
    end
    local sr = {Vector2 = vector, Vector3 = vector, IdString64 = {from_hex = handle},
        Application = {worlds = function() return {2} end, can_get = function(kind, resource)
            if resource == debug then return true end
            if not loaded then return false end
            if resource == template then return kind == "material" end
            return type(resource) == "table" and (kind == "font" and (resource.resource == fonts[1] or resource.resource == fonts[2]) or
                kind == "texture" and (resource.resource == atlases[1] or resource.resource == atlases[2])) or false
        end},
        World = {create_screen_gui = function(world)
            equal(world, 2); next_gui = next_gui + 1; surfaces[next_gui] = {}; return next_gui
        end, destroy_gui = function(_, gui)
            assert(surfaces[gui]); for _, item in pairs(shapes) do assert(item.gui ~= gui) end; surfaces[gui] = nil
        end},
        Material = {set_texture = function(instance, variable, atlas)
            if failure == "bind" then error("bind failed") end
            equal(variable, handle(slot)); instance.atlas = atlas; binds = binds + 1
        end},
        Gui = {material = function(gui, name)
            equal(name, template); assert(surfaces[gui]); return surfaces[gui]
        end, has_all_glyphs = function(_, _, resource)
            return complete == true or complete == resource.resource
        end, text_extents = function(_, text, resource, size)
            if resource ~= debug then
                assert(type(resource) == "table" and resource.resource)
                if failure == "measure" then return vector(0 / 0, 0), vector(0 / 0, size) end
                if failure == "bearing" then return vector(math.huge, 0), vector(math.huge, size) end
                if failure == "scaled" and size < 20 then error("scaled measurement failed") end
            end
            local count = 0; for _ in text:gmatch("[\1-\127\194-\244][\128-\191]*") do count = count + 1 end
            return vector(-size * 0.2, -size * 0.3), vector((count - 0.2) * size, size * 0.7)
        end, text = function(gui, text, resource, size, material, position)
            if resource ~= debug then
                equal(material, template, "draw resolves the bound GUI-local resource, never a Material pointer")
                local instance = assert(surfaces[gui])
                local index = resource.resource == fonts[1] and 1 or 2
                equal(instance.atlas, handle(atlases[index]), "font and atlas stay paired")
                if failure == "draw" then return nil end
                if failure == "second-line" and text:find("공중", 1, true) then return nil end
                if failure == "throw" then error("text failed") end
            else equal(gui, 1); equal(material, debug) end
            next_id = next_id + 1; shapes[next_id] = {gui = gui, position = position}
            drawn[#drawn + 1] = {text = text, font = resource, size = size, position = position}; return next_id
        end, destroy_text = function(gui, id) equal(shapes[id].gui, gui); shapes[id] = nil end},
    }
    local radial = Radial.new(sr, {}, 1, function(line) traces[#traces + 1] = line end)
    radial.gui, radial.world, radial.width = 1, 2, 720
    local function close()
        radial:close(); equal(next(shapes), nil); equal(next(surfaces), nil)
        equal(radial.native_font_failed, nil, "another opening can recover")
    end
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT", 20)
    equal(drawn[#drawn].text, "증원"); equal(drawn[#drawn].font, handle(fonts[1])); equal(binds, 1)
    equal(drawn[#drawn].position.x, 344); equal(drawn[#drawn].position.y, 206)
    radial:label("이글 가스 공중타격", 360, 250, 20, {}, 90, "EAGLE GAS AIRSTRIKE")
    equal(binds, 1, "wrapped labels reuse the owned GUI material")
    equal(#traces, 1, "draw diagnostics are bounded per font per opening")
    equal(traces[1]:find("renderer=resource-text", 1, true) ~= nil, true)
    radial:text("READY", 360, 200, 20, {}, 120)
    equal(drawn[#drawn].font, debug, "ASCII renderer unchanged")
    close()
    complete = fonts[2]
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(drawn[#drawn].font, handle(fonts[2]), "missing coverage tries the second matched pair")
    close()
    complete = false
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(drawn[#drawn].text, "REINFORCEMENT", "no glyphs/resources never silently draws unsupported Korean")
    close()
    complete, loaded = true, false
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(drawn[#drawn].font, debug); close(); loaded = true
    for _, reason in ipairs({"bind", "measure", "bearing", "scaled", "draw", "throw"}) do
        failure = reason
        radial:text("증원", 360, 200, 20, {}, reason == "scaled" and 10 or 120, "REINFORCEMENT")
        equal(drawn[#drawn].font, debug, "failed native route falls back: " .. reason)
        equal(radial.native_font_failed, true)
        local count = binds
        radial:text("재보급", 360, 200, 20, {}, 120, "RESUPPLY")
        equal(binds, count, "failed native route is not retried for every label")
        close()
    end
    failure = "second-line"
    radial:label("이글 가스 공중타격", 360, 250, 20, {}, 90, "EAGLE GAS AIRSTRIKE")
    equal(radial.native_font_failed, true)
    equal(#radial.ids, 2, "a wrapped failure redraws the entire fallback label, not duplicate full names per line")
    for _, shape in pairs(shapes) do equal(shape.gui, 1, "no partial native label survives fallback") end
    close()
    failure = nil
    radial:text("증원", 360, 200, 20, {}, 120, "REINFORCEMENT")
    equal(drawn[#drawn].font, handle(fonts[1])); close()
end
