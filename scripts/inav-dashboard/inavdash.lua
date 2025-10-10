-- Use the `inavdash` injected via ENV (from main.lua)
-- (No local table here—keep a single shared namespace)

-- external library placeholders (load them as a one off in create)
inavdash.sensors = {}
inavdash.layout =  {}
inavdash.render =  {}


local sensors = {}
local internalModule = nil
local externalModule = nil
local currentPage = currentPage or 1

-- GPS Lock
local gps_lock_prev = false


-- Define your grid once
-- This is a simply html-style grid system
-- You can adjust the number of columns/rows/padding to taste
local GRID = {
  cols   = 30,   -- change to taste
  rows   = 16,
  pad    = 2,   -- pixel gap between cells
  header = 0,   -- reserve a fixed px header if you ever need a title bar
}

-- Place widgets in grid terms (col/row are 1-based)
local GRID_WIDGETS = nil

local GRID_PAGES = {
    [1] = {
        ah            =  { col = 1,  row = 1, colspan = 12, rowspan = 8 },
        flightmode    =  { col = 1,  row = 9, colspan = 12, rowspan = 4 },
        map           =  { col = 13, row = 1, colspan = 14, rowspan = 8 },
        altitude      =  { col = 23, row = 9, colspan = 4,  rowspan = 4 },
        groundspeed   =  { col = 19, row = 9, colspan = 4,  rowspan = 4 },  
        heading       =  { col = 27, row = 5, colspan = 4,  rowspan = 4 },
        satellites    =  { col = 27, row = 9, colspan = 4,  rowspan = 4 },
        gps           =  { col = 19,  row = 13, colspan = 8,  rowspan = 4 },
        gps_lock      =  { col = 27,  row = 13, colspan = 4,  rowspan = 4 },
        voltage       =  { col = 1,  row = 13, colspan = 4,  rowspan = 4 },
        current       =  { col = 5,  row = 13, colspan = 4,  rowspan = 4 },  
        fuel          =  { col = 9,  row = 13, colspan = 4,  rowspan = 4 },
        rssi          =  { col = 27, row = 1, colspan = 4,  rowspan = 4 },
        home_dir      =  { col = 13, row = 9, colspan = 6,  rowspan = 8 },   
    },
    [2] = {
        ah            =  { col = 1,  row = 1, colspan = 16, rowspan = 12 },
        flightmode    =  nil,
        map           =  { col = 17,  row = 1, colspan = 14, rowspan = 12 },
        altitude      =  { col = 13,  row = 13, colspan = 4,  rowspan = 4 },
        groundspeed   =  { col = 17,  row = 13, colspan = 4,  rowspan = 4 },
        heading       =  { col = 21,  row = 13, colspan = 4,  rowspan = 4 },
        satellites    =  nil,
        gps           =  { col = 25,  row = 13, colspan = 6,  rowspan = 4 },
        gps_lock      =  nil,
        voltage       =  { col = 1,  row = 13, colspan = 4,  rowspan = 4 },
        current       =  { col = 5,  row = 13, colspan = 4,  rowspan = 4 }, 
        fuel          =  { col = 9,  row = 13, colspan = 4,  rowspan = 4 },
        rssi          =  nil,
        home_dir      =  nil
    },
    

}



-- Convert one grid definition to pixel rects (inspired by dashboard.lua)
local function computeGridRects(sw, sh, grid, widgets)
  local cols   = math.max(1, grid.cols or 1)
  local rows   = math.max(1, grid.rows or 1)
  local pad    = grid.pad or 0
  local header = grid.header or 0

  local W_raw, H_raw = sw, sh
  local W, H = W_raw, H_raw - header

  local function adjustDimension(dim, cells, padCount)
    return dim - ((dim - padCount * pad) % cells)
  end

  -- make width/height divisible by grid + padding (like dashboard.lua)
  W = adjustDimension(W, cols, cols - 1)
  H = adjustDimension(H, rows, rows + 1) -- +1 so first row sits below a pad

  local xOffset = math.floor((W_raw - W) / 2)

  local contentW = W - ((cols - 1) * pad)
  local contentH = H - ((rows + 1) * pad)
  local cellW    = contentW / cols
  local cellH    = contentH / rows

  local rects = {}
  for name, box in pairs(widgets or {}) do
    local c  = math.max(1, math.min(cols, box.col or 1))
    local r  = math.max(1, math.min(rows, box.row or 1))
    local cs = math.max(1, math.min(cols - c + 1, box.colspan or 1))
    local rs = math.max(1, math.min(rows - r + 1, box.rowspan or 1))

    local w  = math.floor(cs * cellW + (cs - 1) * pad)
    local h  = math.floor(rs * cellH + (rs - 1) * pad)

    local x  = math.floor((c - 1) * (cellW + pad)) + xOffset
    local y  = math.floor(pad + (r - 1) * (cellH + pad)) + header

    rects[name] = { x = x, y = y, w = w, h = h }
  end
  return rects
end

-- Replace the old per-resolution logic with a single compute
local function getScreenSizes()
  local sw, sh = lcd.getWindowSize()
  inavdash.layout = computeGridRects(sw, sh, GRID, GRID_WIDGETS)
end


function inavdash.create()

    -- Telemetry
    if not inavdash.sensors.telemetry then inavdash.sensors.telemetry = assert(loadfile("sensors/telemetry.lua"))()  end

    -- Render modules
    if not inavdash.render.telemetry then inavdash.render.telemetry = assert(loadfile("render/telemetry.lua"))() end
    if not inavdash.render.ah then inavdash.render.ah = assert(loadfile("render/ah.lua"))() end
    if not inavdash.render.gps then inavdash.render.gps = assert(loadfile("render/gps.lua"))() end
    if not inavdash.render.gps_lock then inavdash.render.gps_lock = assert(loadfile("render/gps_lock.lua"))() end
    if not inavdash.render.map then inavdash.render.map = assert(loadfile("render/map.lua"))() end
    if not inavdash.render.flightmode then inavdash.render.flightmode = assert(loadfile("render/flightmode.lua"))() end
    if not inavdash.render.hd then inavdash.render.hd = assert(loadfile("render/homedirection.lua"))() end


end

function inavdash.configure()
    -- body
end

function inavdash.paint()

    local LCD_WIDTH, LCD_HEIGHT = lcd.getWindowSize()

    -- Clear background
    lcd.color(lcd.RGB(0,0,0))
    lcd.drawFilledRectangle(0, 0, LCD_WIDTH, LCD_HEIGHT)
    
    -- Artificial Horizon
    if inavdash.layout.ah then
        inavdash.render.ah.paint()
    end

    -- Map
    if inavdash.layout.map then
         inavdash.render.map.paint()
    end            

    if inavdash.render.telemetry then

        -- Flight Mode
        if inavdash.layout.flightmode then        
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }

            inavdash.render.flightmode.paint(inavdash.layout.flightmode.x, inavdash.layout.flightmode.y, inavdash.layout.flightmode.w, inavdash.layout.flightmode.h, "Flight Mode", sensors['flightmode'] or 0, "", opts)
        end

        -- Altitude
        if inavdash.layout.altitude then        
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }

            inavdash.render.telemetry.paint(inavdash.layout.altitude.x, inavdash.layout.altitude.y, inavdash.layout.altitude.w, inavdash.layout.altitude.h, "Altitude", sensors['altitude'] or 0, "", opts)
        end

        -- Ground Speed
         if inavdash.layout.groundspeed then       
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }
        

            inavdash.render.telemetry.paint(inavdash.layout.groundspeed.x, inavdash.layout.groundspeed.y, inavdash.layout.groundspeed.w, inavdash.layout.groundspeed.h, "Speed", sensors['groundspeed'] or 0, "", opts)
        end

        -- Distance
        if inavdash.layout.heading then
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }

            inavdash.render.telemetry.paint(inavdash.layout.heading.x, inavdash.layout.heading.y, inavdash.layout.heading.w, inavdash.layout.heading.h, "Heading", sensors['heading'] or 0, "", opts)
        end

        -- Voltage
        if inavdash.layout.voltage then 
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }


            inavdash.render.telemetry.paint(inavdash.layout.voltage.x, inavdash.layout.voltage.y, inavdash.layout.voltage.w, inavdash.layout.voltage.h, "Voltage", sensors['voltage'] or 0, "V", opts)
        end

        -- Fuel
        if inavdash.layout.fuel then
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }


            inavdash.render.telemetry.paint(inavdash.layout.fuel.x, inavdash.layout.fuel.y, inavdash.layout.fuel.w, inavdash.layout.fuel.h, "Fuel", sensors['fuel'] or 0, "%", opts)
        end

        -- Current
        if inavdash.layout.current then
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }


            inavdash.render.telemetry.paint(inavdash.layout.current.x, inavdash.layout.current.y, inavdash.layout.current.w, inavdash.layout.current.h, "Current", sensors['current'] or 0, "A", opts)
        end

        -- RSSI
        if inavdash.layout.rssi then
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }


            inavdash.render.telemetry.paint(inavdash.layout.rssi.x, inavdash.layout.rssi.y, inavdash.layout.rssi.w, inavdash.layout.rssi.h, "RSSI", sensors['rssi'] or 0, "%", opts)
        end

        -- Satellites
        if inavdash.layout.satellites then
            local opts = {
                colorbg = lcd.RGB(40,40,40),
                colorvalue = lcd.RGB(255,255,255),
                colorlabel = lcd.RGB(200,200,200),
                fontvalue = FONT_L,
                fontlabel = FONT_XS,
            }
            inavdash.render.telemetry.paint(inavdash.layout.satellites.x, inavdash.layout.satellites.y, inavdash.layout.satellites.w, inavdash.layout.satellites.h, "Satellites",sensors['satellites'] or 0, "", opts)
        end

        if inavdash.layout.home_dir then inavdash.render.hd.paint() end

    end


    -- GPS
    if inavdash.layout.gps then
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_S,
            fontlabel = FONT_XS,
        }
        inavdash.render.gps.paint(inavdash.layout.gps.x, inavdash.layout.gps.y, inavdash.layout.gps.w, inavdash.layout.gps.h, "GPS",sensors['gps_latitude'], sensors['gps_longitude'], opts)
    end

    -- GPS Lock
    if inavdash.layout.gps_lock then
        local opts = {
            images = {
                red = "gfx/red.png",
                orange = "gfx/orange.png",
                green = "gfx/green.png",
            },
            colorbg = lcd.RGB(40,40,40),
        }
        inavdash.render.gps_lock.paint(inavdash.layout.gps_lock.x, inavdash.layout.gps_lock.y, inavdash.layout.gps_lock.w, inavdash.layout.gps_lock.h, sensors['gps_lock'], sensors['satellites'], opts)
    end

end

function inavdash.wakeup()

    if GRID_WIDGETS == nil then
        -- First time only: pick a page layout
        GRID_WIDGETS = GRID_PAGES[currentPage] or GRID_PAGES[1]
    end


    -- Get screen sizes and layout if not done yet
    getScreenSizes()

    -- Check sensors
    if inavdash.sensors and inavdash.sensors.telemetry then
        inavdash.sensors.telemetry.wakeup()

        sensors['voltage'] = inavdash.sensors.telemetry.getSensor('voltage')
        sensors['current'] = inavdash.sensors.telemetry.getSensor('current')
        sensors['altitude'] = inavdash.sensors.telemetry.getSensor('altitude')
        sensors['fuel'] = inavdash.sensors.telemetry.getSensor('fuel')
        sensors['rssi'] = inavdash.sensors.telemetry.getSensor('rssi')
        sensors['roll'] = inavdash.sensors.telemetry.getSensor('roll')
        sensors['pitch'] = inavdash.sensors.telemetry.getSensor('pitch')
        sensors['heading'] = inavdash.sensors.telemetry.getSensor('heading')
        sensors['groundspeed'] = inavdash.sensors.telemetry.getSensor('groundspeed')
        sensors['satellites'] = inavdash.sensors.telemetry.getSensor('satellites')
        sensors['gps_latitude'] = inavdash.sensors.telemetry.getSensor('gps_latitude')
        sensors['gps_longitude'] = inavdash.sensors.telemetry.getSensor('gps_longitude')
        sensors['flightmode'] = inavdash.sensors.telemetry.getSensor('flightmode')


        if sensors['gps_lock'] == false then
            sensors['groundspeed'] =  0
            sensors['heading'] = 0
            sensors['altitude'] = 0
        end

        -- GPS Lock logic
        do
            -- Detect GPS lock transition
            local prev = gps_lock_prev
            local fm = sensors['flightmode']           -- will be nil when no link

            -- derive purely from flightmode, but gate on link
            local new_lock
            if fm == nil then
            new_lock = false                         -- no link/value => not locked
            elseif fm == 2 then
            new_lock = false                         -- whatever 2 is in your map (e.g., no-GPS mode)
            else
            new_lock = true                          -- all other known modes => treat as “locked”
            end

            -- optional: one-shot beep on false -> true
            if prev == false and new_lock == true then
                --system.playTone(1000, 500, 0)
            end
            gps_lock_prev = new_lock

            -- expose to the UI
            sensors['gps_lock'] = new_lock       
            
            -- Simple home update (no map.state table)
            local lat = sensors['gps_latitude']
            local lon = sensors['gps_longitude']
            if new_lock then
                if (not sensors['home_latitude'] or sensors['home_latitude'] == 0)
                   and lat and lon then
                    sensors['home_latitude']  = lat
                    sensors['home_longitude'] = lon
                end
            else
                sensors['home_latitude']  = 0
                sensors['home_longitude'] = 0
            end


        end

        -- Virtual sensor: distance from home (meters)
        do
        local lat, lon  = sensors['gps_latitude'], sensors['gps_longitude']
        local hlat, hlon = sensors['home_latitude'], sensors['home_longitude']
        if sensors['gps_lock'] and lat and lon and hlat and hlon and hlat ~= 0 and hlon ~= 0 then
            local dx, dy = inavdash.render.map.enu_dxdy(lat, lon, hlat, hlon) -- meters East/North
            sensors['gps_distancehome'] = inavdash.render.map.hypot(dx, dy)   -- meters
        else
            sensors['gps_distancehome'] = 0
        end
        end      
        

    end


    if inavdash.render.ah then
        local ahconfig = {
            ppd = 2.0,
            show_altitude = false,
            show_groundspeed = false,
        }
        if inavdash.render.ah then
            inavdash.render.ah.wakeup(sensors, inavdash.layout.ah.x, inavdash.layout.ah.y, inavdash.layout.ah.w, inavdash.layout.ah.h, ahconfig)
        end
    end

    if inavdash.render.map then
        local opts = {
            north_up = false,
            show_grid = true,
            show_distance = false, 
            home_icon = "gfx/home.png",
            own_icon  = "gfx/arrow.png",
            show_speed_vec = false,
            show_zoom = true,
            colors = {
                bg    = lcd.RGB(0, 60, 0),
                grid  = lcd.RGB(0, 90, 0),
                trail = lcd.RGB(170, 220, 170),
                own   = lcd.RGB(255, 255, 255),
                home  = lcd.RGB(255, 255, 255),
                text  = lcd.RGB(255, 255, 255),
            },
            -- home directly from sensors
            home = sensors['gps_lock'] and {
                lat = sensors['home_latitude'],
                lon = sensors['home_longitude'],
            } or nil,

            light_on_gps_ms = 2000,
        }

        local s = {
            latitude    = sensors['gps_latitude'],
            longitude   = sensors['gps_longitude'],
            heading     = sensors['heading'],
            groundspeed = sensors['groundspeed'],
            home_lat    = sensors['home_latitude'],
            home_lon    = sensors['home_longitude'], 
        }

        local box = inavdash.layout.map
        if box then
            inavdash.render.map.wakeup(box.x, box.y, box.w, box.h, s,opts)
        end
    end

    if inavdash.layout.home_dir then
        local box = inavdash.layout.home_dir
        local s = {
            latitude  = sensors['gps_latitude'],
            longitude = sensors['gps_longitude'],
            heading   = sensors['heading'],
            home_lat  = sensors['home_latitude'],
            home_lon  = sensors['home_longitude'],
        }
        local opts = {
            images = {
                forward = "gfx/hd_fwd.png",
                left    = "gfx/hd_left.png",
                right   = "gfx/hd_right.png",
                back    = "gfx/hd_rev.png",
            },
            colors = { bg = lcd.RGB(40,40,40), frame = lcd.RGB(80,80,80), text = lcd.RGB(255,255,255) },
            show_ring = true,
            show_text = true,
        }
        if box then
            inavdash.render.hd.wakeup(box.x, box.y, box.w, box.h, s, opts)
        end
    end


    -- Flight Mode change detection with audio playback
    do
        local fm = sensors['flightmode']
        local prev = inavdash._prev_flightmode
        -- Only trigger if we have a valid mode now, and either it's the first one
        -- (prev == nil) or it has changed since last time.
        if fm and (prev == nil or fm ~= prev) then
            local file = string.format("audio/en/default/fm-%d.wav", fm)
            system.playFile(file)
            inavdash._prev_flightmode = fm
        end
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

function inavdash.event(widget, category, value, x, y)
    if lcd.hasFocus() then
        print("Event received:", category, value, x, y)
        local num_pages = #GRID_PAGES

        if category == 0 and value == 4100 then -- scroll right
            currentPage = currentPage + 1
            if currentPage > num_pages then
                currentPage = 1 -- wrap around to first page
            end
        elseif category == 0 and value == 4099 then -- scroll left
            currentPage = currentPage - 1
            if currentPage < 1 then
                currentPage = num_pages -- wrap around to last page
            end
        end

        -- Update the widgets to the current page
        GRID_WIDGETS = GRID_PAGES[currentPage]

        print("Current page:", currentPage)
    end
end


function inavdash.menu()
    return {}
end

return inavdash