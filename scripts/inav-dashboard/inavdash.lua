-- Use the `inavdash` injected via ENV (from main.lua)
-- (No local table here—keep a single shared namespace)

-- external library placeholders (load them as a one off in create)
inavdash.telemetry = nil
inavdash.radios = {}
inavdash.render = {}


local sensors = {}
local internalModule = nil
local externalModule = nil

local supportedResolutions = {
    -- 800x480 -> X20 Full Screen -> No Title
    ["800x480"] = { 
        ah = { x= 0, y= 2, w= 400, h= 240 },
    },
     -- 800x480 -> Single Widget -> Title
    ["784x294"] = { 
        ah = { x= 0, y= 2, w= 392, h= 200 },
        altitude = {x= 396, y=2, w= 150, h= 80 }, 
    },
     -- 800x480 -> Single Widget -> No Title
    ["784x316"] = { 
        ah = { x= 0, y= 2, w= 392, h= 215 }, -- 200 * (316/294) ≈ 215
    },
    -- 480x320 -> X18 Full Screen -> No Title
    ["480x320"] = {
        ah = { x= 0, y= 2, w= 240, h= 160 },
    }, 
    -- 480x320 -> Single Widget -> Title 
    ["472x191"] = {
        ah = { x= 0, y= 2, w= 236, h= 130 },
    }, 
    -- 480x320 -> Single Widget -> No Title
    ["472x210"] = {
        ah = { x= 0, y= 2, w= 236, h= 143 },
    },
}

-- Determine screen resolution and setup layout
local function getScreenSizes()
    local sw, sh = lcd.getWindowSize()
    local resString = string.format("%dx%d", sw, sh)
    if supportedResolutions[resString] then
        inavdash.radios = supportedResolutions[resString]
    else
        -- Fallback for unsupported resolutions to prevent Lua errors (maybe not the best solution?)
        inavdash.radios = {
            ah = { x = 0, y = 0, w = math.floor(sw * 0.5), h = math.floor(sh * 0.75) }
        }
        print("Unsupported screen resolution: " .. resString .. " - using fallback layout")
    end
    -- Enable when doing new radios
    -- print("Screen resolution: " .. resString)
end


function inavdash.create()

    -- load externals
    if not inavdash.telemetry then  inavdash.telemetry = assert(loadfile("lib/telemetry.lua"))()  end
    if not inavdash.render.lib then inavdash.render.lib = assert(loadfile("lib/render_lib.lua"))() end
    if not inavdash.render.ah then inavdash.render.ah = assert(loadfile("lib/render_ah.lua"))() end


end

function inavdash.configure()
    -- body
end

function inavdash.paint()

    local LCD_WIDTH, LCD_HEIGHT = lcd.getWindowSize()

    -- Clear background
    lcd.color(lcd.RGB(0,0,0))
    lcd.drawFilledRectangle(0, 0, LCD_WIDTH, LCD_HEIGHT)
    
    if inavdash.render.ah then
        -- positions are pre-calculated in wakeup
        inavdash.render.ah.paint()
    end

    if inavdash.render.lib then
        -- Altitude box example
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_S,
        }
        inavdash.render.lib.telemetryBox(inavdash.radios.altitude.x, inavdash.radios.altitude.y, inavdash.radios.altitude.w, inavdash.radios.altitude.h, "Altitude", sensors['altitude'], "M", opts)
    end


end

function inavdash.wakeup()

    -- Get screen sizes and layout if not done yet
    getScreenSizes()

    -- Get telemetry type
    if inavdash.telemetry then
        inavdash.telemetry.wakeup()
    end

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
        inavdash.render.ah.wakeup(sensors, inavdash.radios.ah.x, inavdash.radios.ah.y, inavdash.radios.ah.w, inavdash.radios.ah.h, ahconfig)
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