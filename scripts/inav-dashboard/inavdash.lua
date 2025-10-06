-- Use the `inavdash` injected via ENV (from main.lua)
-- (No local table here—keep a single shared namespace)

-- external library placeholders (load them as a one off in create)
inavdash.telemetry = nil
inavdash.radios = {}
inavdash.render = {}


local sensors = {}
local internalModule = nil
local externalModule = nil

-- === One grid layout for all resolutions ===
-- Think only in grid units; it auto-resolves to pixels at runtime.

-- Define your grid once
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

    -- load externals
    if not inavdash.telemetry then  inavdash.telemetry = assert(loadfile("lib/telemetry.lua"))()  end
    if not inavdash.render.telemetry then inavdash.render.telemetry = assert(loadfile("lib/render_telemetry.lua"))() end
    if not inavdash.render.ah then inavdash.render.ah = assert(loadfile("lib/render_ah.lua"))() end
    if not inavdash.render.satellites then inavdash.render.satellites = assert(loadfile("lib/render_satellites.lua"))() end
    if not inavdash.render.gps then inavdash.render.gps = assert(loadfile("lib/render_gps.lua"))() end

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

    if inavdash.render.telemetry then

        -- Map
        local opts = {
            colorbg = lcd.RGB(0,114,0),
            colorvalue = lcd.RGB(255,255,255),
            colorlabel = lcd.RGB(200,200,200),
            fontvalue = FONT_L,
            fontlabel = FONT_XS,
        }
        inavdash.render.telemetry.paint(inavdash.radios.map.x, inavdash.radios.map.y, inavdash.radios.map.w, inavdash.radios.map.h, "Map", "COMING SOON", "", opts)

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
    sensors['gps_latitude'] = inavdash.telemetry.getSensor('gps_latitude')
    sensors['gps_longitude'] = inavdash.telemetry.getSensor('gps_longitude')

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