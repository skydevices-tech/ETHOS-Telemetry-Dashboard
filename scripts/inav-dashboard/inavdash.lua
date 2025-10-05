local inavdash= {}

-- external library placeholders (load them as a one off in create)
inavdash.telemetry = nil
inavdash.render = {}

local sensors = {}
local LCD_W
local LCD_H 


function inavdash.create()

    if not inavdash.telemetry then 
        inavdash.telemetry = assert(loadfile("lib/telemetry.lua"))()
    end
    if not inavdash.render.ah then
        inavdash.render.ah = assert(loadfile("lib/render_ah.lua"))() 
    end


end

function inavdash.configure()
    -- body
end

function inavdash.paint()
    
    if inavdash.render.ah then

        inavdash.render.ah.paint()
    end



end

function inavdash.wakeup()


    LCD_W, LCD_H = lcd.getWindowSize()

    -- Load all sensors.
    sensors['voltage'] = inavdash.telemetry.getSensor('voltage')
    sensors['current'] = inavdash.telemetry.getSensor('current')
    sensors['altitude'] = inavdash.telemetry.getSensor('altitude')
    sensors['fuel'] = inavdash.telemetry.getSensor('fuel')
    sensors['rssi'] = inavdash.telemetry.getSensor('rssi')
    sensors['roll'] = inavdash.telemetry.getSensor('roll')
    sensors['pitch'] = inavdash.telemetry.getSensor('pitch')
    sensors['heading'] = inavdash.telemetry.getSensor('heading')
    sensors['groundspeed'] = inavdash.telemetry.getSensor('groundspeed')
    sensors['satellites'] = inavdash.telemetry.getSensor('satellites')

    if inavdash.render.ah then
        local ahconfig = {
            ppd = 2.0,
            show_altitude = false,
            show_groundspeed = false,
        }
        inavdash.render.ah.wakeup(sensors, 0, 0, 320, 240, ahconfig)
    end


    -- Paint only if we are on screen
    if lcd.isVisible() then
        lcd.invalidate()
    end

end

function inavdash.read()
    -- body
end

function inavdash.write()
    -- body
end

function inavdash.event()
    -- body
end

function inavdash.menu()
    -- body
end

return inavdash