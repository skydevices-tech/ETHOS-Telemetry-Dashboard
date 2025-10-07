-- Use the `inavdash` injected via ENV (from main.lua)
-- (No local table here—keep a single shared namespace)

-- external library placeholders (load them as a one off in create)
inavdash.sensors = {}
inavdash.radios =  {}
inavdash.render =  {}


local sensors = {}
local internalModule = nil
local externalModule = nil


-- Define your grid once
-- This is a simply html-style grid system
-- You can adjust the number of columns/rows/padding to taste
local GRID = {
  cols   = 30,   -- change to taste
  rows   = 8,
  pad    = 2,   -- pixel gap between cells
  header = 0,   -- reserve a fixed px header if you ever need a title bar
}

-- Place widgets in grid terms (col/row are 1-based)
local GRID_WIDGETS = {
  -- Full-bleed AH across the whole grid:
  ah            =  { col = 1,  row = 1, colspan = 16, rowspan = 6 },
  map           =  { col = 17, row = 1, colspan = 10, rowspan = 6 },
  altitude      =  { col = 27, row = 1, colspan = 4,  rowspan = 2 },
  groundspeed   =  { col = 27, row = 3, colspan = 4,  rowspan = 2 },  
  heading       =  { col = 27, row = 5, colspan = 4,  rowspan = 2 },
  satellites    =  { col = 27, row = 7, colspan = 4,  rowspan = 2 },
  gps           =  { col = 17,  row = 7, colspan = 10,  rowspan = 2 },
  voltage       =  { col = 1,  row = 7, colspan = 4,  rowspan = 3 },
  current       =  { col = 5,  row = 7, colspan = 4,  rowspan = 3 },  
  fuel          =  { col = 9,  row = 7, colspan = 4,  rowspan = 3 },
  rssi          =  { col = 13, row = 7, colspan = 4,  rowspan = 3 },
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
  inavdash.radios = computeGridRects(sw, sh, GRID, GRID_WIDGETS)
end

function inavdash.create()

    -- Telemetry
    if not inavdash.sensors and not inavdash.sensors.telemetry then inavdash.sensors.telemetry = assert(loadfile("sensors/telemetry.lua"))()  end

    -- Render modules
    if not inavdash.render.telemetry then inavdash.render.telemetry = assert(loadfile("render/telemetry.lua"))() end
    if not inavdash.render.ah then inavdash.render.ah = assert(loadfile("render/ah.lua"))() end
    if not inavdash.render.satellites then inavdash.render.satellites = assert(loadfile("render/satellites.lua"))() end
    if not inavdash.render.gps then inavdash.render.gps = assert(loadfile("render/gps.lua"))() end
    if not inavdash.render.map then inavdash.render.map = assert(loadfile("render/map.lua"))() end

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
    if inavdash.render.ah then
        -- positions are pre-calculated in wakeup
        inavdash.render.ah.paint()
    end

    -- Map
    if inavdash.render.map then
         inavdash.render.map.paint()
    end            

    if inavdash.render.telemetry then

        -- Altitude
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.altitude.x, inavdash.radios.altitude.y, inavdash.radios.altitude.w, inavdash.radios.altitude.h, "Altitude", sensors['altitude'], "", opts)

        -- Ground Speed
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.groundspeed.x, inavdash.radios.groundspeed.y, inavdash.radios.groundspeed.w, inavdash.radios.groundspeed.h, "Speed", sensors['groundspeed'], "", opts)

        -- Distance
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.heading.x, inavdash.radios.heading.y, inavdash.radios.heading.w, inavdash.radios.heading.h, "Heading", sensors['heading'], "°", opts)

        -- Voltage
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.voltage.x, inavdash.radios.voltage.y, inavdash.radios.voltage.w, inavdash.radios.voltage.h, "Voltage", sensors['voltage'], "V", opts)

        -- Fuel
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.fuel.x, inavdash.radios.fuel.y, inavdash.radios.fuel.w, inavdash.radios.fuel.h, "Fuel", sensors['fuel'], "%", opts)


        -- Current
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.current.x, inavdash.radios.current.y, inavdash.radios.current.w, inavdash.radios.current.h, "Current", sensors['current'], "A", opts)

        -- Current
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.rssi.x, inavdash.radios.rssi.y, inavdash.radios.rssi.w, inavdash.radios.rssi.h, "RSSI", sensors['rssi'], "%", opts)


    end

    -- Satellites
    if inavdash.render.satellites then
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.satellites.paint(inavdash.radios.satellites.x, inavdash.radios.satellites.y, inavdash.radios.satellites.w, inavdash.radios.satellites.h, "Satellites",sensors['satellites'], "", opts)
    end


    -- GPS
    if inavdash.render.gps then
        local opts = {
            colorbg = lcd.RGB(40,40,40),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_S,
            fontlabel = FONT_XS,
        }
        inavdash.render.gps.paint(inavdash.radios.gps.x, inavdash.radios.gps.y, inavdash.radios.gps.w, inavdash.radios.gps.h, "GPS",sensors['gps_latitude'], sensors['gps_longitude'], opts)
    end



end

function inavdash.wakeup()

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

    end

    -- === Home locker (no FC home required) ===
    do
        local st   = inavdash.render.map.state
        local sats = tonumber(sensors['satellites']) or 0
        local lat  = tonumber(sensors['gps_latitude'])
        local lon  = tonumber(sensors['gps_longitude'])
        local gs   = tonumber(sensors['groundspeed']) or 0

        -- Parameters (tune to taste)
        local MIN_SATS       = 6
        local MAX_SPEED_MPS  = 0.8     -- consider "steady" below this
        local WINDOW_SAMPLES = 20      -- how many recent samples to check
        local WANDER_METERS  = 5       -- max radius of wander to accept

        -- only try to lock when GPS looks valid and we have a position
        if sats >= MIN_SATS and lat and lon then
            -- ring buffer of recent GPS points (lat/lon)
            st._samples[st._si] = { lat = lat, lon = lon, gs = gs }
            st._si = (st._si % WINDOW_SAMPLES) + 1

            if not st._locked then
                -- need the window to be full
                if #st._samples >= WINDOW_SAMPLES then
                    -- compute "center" (simple average) and max radius
                    local sumLat, sumLon, maxR = 0, 0, 0
                    for i = 1, WINDOW_SAMPLES do
                        sumLat = sumLat + (st._samples[i].lat or lat)
                        sumLon = sumLon + (st._samples[i].lon or lon)
                    end
                    local cLat = sumLat / WINDOW_SAMPLES
                    local cLon = sumLon / WINDOW_SAMPLES

                    -- check wander & speed
                    local ok = true
                    for i = 1, WINDOW_SAMPLES do
                        local s = st._samples[i]
                        local dx, dy = inavdash.render.map.enu_dxdy(s.lat, s.lon, cLat, cLon)
                        local r = inavdash.render.map.hypot(dx, dy)
                        if r > maxR then maxR = r end
                        if (s.gs or 0) > MAX_SPEED_MPS then ok = false break end
                    end

                    if ok and maxR <= WANDER_METERS then
                        st.home_lat, st.home_lon = cLat, cLon
                        st._locked = true

                        if system and system.playTone then system.playTone(1000, 500, 0) end
                    end
                end
            end
        end

        -- Optional: simple manual clear (e.g., if you add a menu later)
        -- if some_condition then st.home_lat, st.home_lon, st._locked, st._samples, st._si = nil, nil, false, {}, 1 end
    end



    if inavdash.render.ah then
        local ahconfig = {
            ppd = 2.0,
            show_altitude = false,
            show_groundspeed = false,
        }
        inavdash.render.ah.wakeup(sensors, inavdash.radios.ah.x, inavdash.radios.ah.y, inavdash.radios.ah.w, inavdash.radios.ah.h, ahconfig)
    end

    if inavdash.render.map then
    local opts = {
    north_up = false,
    show_grid = true,
    colors = {
        bg    = lcd.RGB(0, 60, 0),
        grid  = lcd.RGB(0, 90, 0),
        trail = lcd.RGB(170, 220, 170),
        own   = lcd.RGB(255, 255, 255),
        home  = lcd.RGB(255, 255, 255),
        text  = lcd.RGB(255, 255, 255),
    },
    -- only provide home once locked:
    home = (inavdash.state and inavdash.state._locked) and {
        lat = inavdash.state.home_lat,
        lon = inavdash.state.home_lon,
    } or nil,

    -- optional: reduce draw load for ~2s when GPS first appears
    light_on_gps_ms = 2000,
    }

    local s = {
        latitude    = sensors['gps_latitude'],
        longitude   = sensors['gps_longitude'],
        heading     = sensors['heading'],
        groundspeed = sensors['groundspeed'],
        home_lat    = sensors['home_latitude'],   -- if available
        home_lon    = sensors['home_longitude'],  -- if available
    }

    local box = inavdash.radios.map
    inavdash.render.map.wakeup(s, box.x, box.y, box.w, box.h, opts)
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