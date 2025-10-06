-- render_map.lua
-- North-up or Heading-up mini map with home pointer + breadcrumb trail.
-- Math happens in wakeup(); paint() is pure drawing (fast).

local RenderMap = {
  _frame = nil,
  _trail = {},          -- ring buffer of recent ENU points (meters)
  _trail_i = 1,
}

-- ===== helpers (wakeup only) =====
local function sval(s, k, d)
  if type(s) ~= "table" then return d end            -- <— guard: sensors must be a table
  local v = s[k]
  if type(v) == "table" then v = v.value or v.val or v.v or v[1] end
  v = tonumber(v)
  return v ~= nil and v or d
end

local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end     -- Lua 5.1 style
  if x ~= nil then return math.atan(y, x) end        -- Lua 5.3 style
  return math.atan(y)                                -- last resort
end

local function clamp(v,a,b) if v<a then return a elseif v>b then return b else return v end end

local function rotate(px, py, s, c)
  return px * c - py * s, px * s + py * c
end

local function meters_per_deg(lat_deg)
  -- good enough for sub-km maps
  local lat = math.rad(lat_deg)
  local m_per_deg_lat = 111320.0
  local m_per_deg_lon = 111320.0 * math.cos(lat)
  return m_per_deg_lat, m_per_deg_lon
end

local function enu_from_latlon(lat, lon, lat0, lon0)
  local mlat, mlon = meters_per_deg(lat0)
  return (lon - lon0) * mlon, (lat - lat0) * mlat   -- x East, y North
end

local function build_house_icon(size)
  local s = size or 6
  -- simple house: triangle roof + square body centered at (0,0)
  return {
    roof = { -s, -s, 0, -2*s, s, -s },
    body = { -s*0.7, -s, s*0.7, -s, s*0.7, s*0.7, -s*0.7, s*0.7 },
  }
end

-- ===== public API =====

-- sensors expected (names are flexible): latitude, longitude, home_lat, home_lon,
-- heading (deg), course (deg) optional, groundspeed (m/s or your units)
-- Options:
--   colors = {bg, grid, trail, own, home, text}
--   north_up = false (heading-up by default)
--   min_ppm, max_ppm (pixels per meter) bounds for auto-zoom
--   keep_home_margin = 18 (px)
--   trail_len = 120 (samples)
--   show_grid = true
function RenderMap.wakeup(sensors, x, y, w, h, opts)
  opts = opts or {}

  local lat  = sval(sensors, "latitude",  0)
  local lon  = sval(sensors, "longitude", 0)
  local hlat = sval(sensors, "home_lat",  0)
  local hlon = sval(sensors, "home_lon",  0)

  -- fall back: if no explicit home in sensors, allow opts.home_{lat,lon}
  if (hlat == 0 and hlon == 0) and opts.home then
    hlat, hlon = opts.home.lat or 0, opts.home.lon or 0
  end

  local heading   = (sval(sensors, "heading",   0)) % 360
  local course    = (sval(sensors, "course",    heading)) % 360
  local gs        = sval(sensors, "groundspeed", 0)

  -- ENU in meters
  local xE, yN = enu_from_latlon(lat, lon, hlat, hlon)        -- craft relative to home (home at 0,0)
  local homeE, homeN = -xE, -yN                               -- home from craft

  -- Auto-zoom: keep both craft (center) and home visible with margin
  local margin   = opts.keep_home_margin or 18
  local maxR     = math.max(math.abs(homeE), math.abs(homeN), 1)
  local span_m   = 2.4 * maxR     -- little extra so it breathes
  local ppm_min  = opts.min_ppm or 0.2   -- 5 m/pixel max span ≈ 500 m across @ 100 px
  local ppm_max  = opts.max_ppm or 3.0   -- ~0.33 m/pixel
  local ppm_auto = clamp( math.min((w - 2*margin)/span_m, (h - 2*margin)/span_m), ppm_min, ppm_max )
  local ppm      = opts.ppm or ppm_auto

  -- Map rotation: heading-up (default) or North-up
  local map_up_deg = (opts.north_up and 0 or heading)
  local r = math.rad(map_up_deg)
  local s, c = math.sin(r), math.cos(r)

  -- home screen position
  local hx, hy = rotate(homeE, homeN, s, c)
  hx, hy = w/2 + hx * ppm, h/2 - hy * ppm

  -- ownship triangle (pointing along rotation-up)
  local own_len, own_w = 10, 6
  local p1x, p1y = 0, -own_len
  local p2x, p2y = own_w/2, own_len*0.6
  local p3x, p3y = -own_w/2, own_len*0.6
  p1x, p1y = rotate(p1x, p1y, s, c)
  p2x, p2y = rotate(p2x, p2y, s, c)
  p3x, p3y = rotate(p3x, p3y, s, c)
  local cx, cy = x + w/2, y + h/2
  local own_tri = { cx + p1x, cy + p1y,  cx + p2x, cy + p2y,  cx + p3x, cy + p3y }

  -- bearing + distance to home
  local dist_m = math.sqrt(homeE*homeE + homeN*homeN)
  local brg = (math.deg(atan2(homeE, homeN)) + 360) % 360

  -- speed vector (projected along course)
  local vx, vy = 0, 0
  if gs and gs > 0 then
    local cr = math.rad(opts.north_up and course - map_up_deg or 0)  -- heading-up already aligned
    local sc, cc = math.sin(cr), math.cos(cr)
    vx, vy = sc * gs, -cc * gs
    vx, vy = cx + vx * ppm * 0.8, cy + vy * ppm * 0.8
  end

  -- Trail ring buffer (in screen coords for cheap draw)
  local trail_len = math.floor(opts.trail_len or 120)
  if trail_len > 0 then
    RenderMap._trail[RenderMap._trail_i] = { x = hx, y = hy } -- store home rel point from craft perspective
    RenderMap._trail_i = (RenderMap._trail_i % trail_len) + 1
  end

  -- Colors
  local colors = opts.colors or {}
  local col_bg     = colors.bg     or lcd.RGB(0, 60, 0)
  local col_grid   = colors.grid   or lcd.RGB(0, 90, 0)
  local col_trail  = colors.trail  or lcd.RGB(170, 220, 170)
  local col_own    = colors.own    or lcd.RGB(255, 255, 255)
  local col_home   = colors.home   or lcd.RGB(255, 255, 255)
  local col_text   = colors.text   or lcd.RGB(255, 255, 255)

  -- Primitive frame
  RenderMap._frame = {
    box     = {x=x, y=y, w=w, h=h},
    ppm     = ppm,
    mapRot  = map_up_deg,
    colors  = {bg=col_bg, grid=col_grid, trail=col_trail, own=col_own, home=col_home, text=col_text},
    own_tri = own_tri,
    home_xy = { x = x + hx, y = y + hy },
    home_ic = build_house_icon(6),
    spd_vec = (gs and gs > 0) and { cx, cy, vx, vy } or nil,
    readout = {
      gs = gs,
      dist = dist_m,
      brg = brg
    },
    show_grid = (opts.show_grid ~= false),
    north_up  = (opts.north_up == true),
  }
end

-- Pure renderer
function RenderMap.paint()
  local F = RenderMap._frame
  if not F then return end
  local x, y, w, h = F.box.x, F.box.y, F.box.w, F.box.h
  local cx, cy = x + w/2, y + h/2

  -- clip
  lcd.setClipping(x, y, w, h)

  -- background
  lcd.color(F.colors.bg)
  lcd.drawFilledRectangle(x, y, w, h)

  -- optional grid
  if F.show_grid then
    lcd.color(F.colors.grid)
    local step = 25
    for gx = x, x+w, step do lcd.drawLine(gx, y, gx, y+h) end
    for gy = y, y+h, step do lcd.drawLine(x, gy, x+w, gy) end
  end

  -- trail
  if #RenderMap._trail > 1 then
    lcd.color(F.colors.trail)
    local prev = nil
    -- draw in stored order; ring gaps are harmless
    for i = 1, #RenderMap._trail do
      local p = RenderMap._trail[i]
      if p and prev then lcd.drawLine(x + prev.x, y + prev.y, x + p.x, y + p.y) end
      prev = p
    end
  end

  -- home icon
    do
    lcd.color(F.colors.home)
    local hx, hy = F.home_xy.x, F.home_xy.y
    local s = 6  -- base size (same look as before)

    -- roof (filled triangle if available, else outline)
    if lcd.drawFilledTriangle then
        lcd.drawFilledTriangle(hx - s, hy - s,  hx, hy - 2*s,  hx + s, hy - s)
    else
        lcd.drawTriangle(hx - s, hy - s,  hx, hy - 2*s,  hx + s, hy - s)
    end

    -- body (filled rectangle so it shows up clearly)
    local bw, bh = 1.4*s, 1.7*s
    if lcd.drawFilledRectangle then
        lcd.drawFilledRectangle(hx - bw/2, hy - s, bw, bh)
    else
        lcd.drawRectangle(hx - bw/2, hy - s, bw, bh)
    end
    end

  -- ownship
  lcd.color(F.colors.own)
  local t = F.own_tri
  lcd.drawFilledTriangle(t[1],t[2], t[3],t[4], t[5],t[6])

  -- speed vector
  if F.spd_vec then
    lcd.drawLine(F.spd_vec[1], F.spd_vec[2], F.spd_vec[3], F.spd_vec[4])
  end

  -- readouts
  lcd.color(F.colors.text)
  lcd.font(FONT_XS)

  local gs = tonumber(F.readout.gs) or 0
  local dist_ft = (tonumber(F.readout.dist) or 0) * 3.28084
  local brg = tonumber(F.readout.brg) or 0
  -- round/normalize for display
  local dist_ft_0 = math.floor(dist_ft + 0.5)
  local brg_0 = (math.floor(brg + 0.5)) % 360

  lcd.drawText(x + 4, y + 4, string.format("%.1f u/s", gs))
  lcd.drawText(x + 4, y + h - 12, string.format("%.0fft  %03.0f°", dist_ft_0, brg_0))

  -- heading tape on sides (W/E markers like your screenshot)
  lcd.drawText(x + 2,  y + h/2 - 6, "W")
  lcd.drawText(x + w - 10, y + h/2 - 6, "E")

  -- reset clip
  local W,H = lcd.getWindowSize()
  lcd.setClipping(0,0,W,H)
end

return RenderMap
