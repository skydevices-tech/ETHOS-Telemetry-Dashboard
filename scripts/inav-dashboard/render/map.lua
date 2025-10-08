-- render_map.lua (Ethos-safe, NO TRAIL)
-- North-up or Heading-up mini map with home pointer. Integer-only drawing,
-- no polygons, NaN/Inf guards, atan2 compatibility, and optional light mode.

local RenderMap = {
  _frame = nil,
  _light_until = nil,   -- optional light mode timestamp (ms)
}

-- === bitmap caches ===
RenderMap._icons = RenderMap._icons or {
  home_path = nil, home = nil,
  own_path  = nil, own  = nil,
}
RenderMap._rot_cache = RenderMap._rot_cache or { angle = nil, bmp = nil }  -- rotated ownship

local function _resolve_bitmap(bmp_or_path)
  if not bmp_or_path then return nil end
  if type(bmp_or_path) == "string" then
    local ok, handle = pcall(lcd.loadBitmap, bmp_or_path)
    return ok and handle or nil
  end
  return bmp_or_path
end

local function _bmp_size(bmp)
  if not bmp then return 0, 0 end
  local w = (bmp.width and bmp:width()) or (bmp.getWidth and bmp:getWidth()) or bmp.w or 0
  local h = (bmp.height and bmp:height()) or (bmp.getHeight and bmp:getHeight()) or bmp.h or 0
  return tonumber(w) or 0, tonumber(h) or 0
end

local function _set_icon(which, src)
  local path = type(src) == "string" and src or nil
  local cache = RenderMap._icons
  -- reload only if path/handle changed
  if path and cache[which .. "_path"] ~= path then
    cache[which .. "_path"] = path
    cache[which] = _resolve_bitmap(path)
  elseif type(src) ~= "string" then
    cache[which .. "_path"] = nil
    cache[which] = src
  end
end

local function _dispose_rotated()
  local rc = RenderMap._rot_cache
  if rc.bmp and rc.bmp.delete then
    pcall(function() rc.bmp:delete() end)
  end
  rc.bmp = nil
  rc.angle = nil
end


-- --- bitmap helpers ---
local function _resolve_bitmap(bmp_or_path)
  if type(bmp_or_path) == "string" then
    local ok, handle = pcall(lcd.loadBitmap, bmp_or_path)
    return ok and handle or nil
  end
  return bmp_or_path
end

local function _bmp_size(bmp)
  if not bmp then return 0, 0 end
  -- Ethos bitmaps generally expose width/height as methods
  local w = (bmp.width and bmp:width()) or (bmp.getWidth and bmp:getWidth()) or bmp.w or 0
  local h = (bmp.height and bmp:height()) or (bmp.getHeight and bmp:getHeight()) or bmp.h or 0
  return tonumber(w) or 0, tonumber(h) or 0
end

local function meters_per_deg(lat_deg)
  local lat = math.rad(lat_deg or 0)
  return 111320.0, 111320.0 * math.cos(lat)
end

local function enu_dxdy(lat, lon, lat0, lon0)
  if not lat or not lon or not lat0 or not lon0 then return 1e9, 1e9 end
  local mlat, mlon = meters_per_deg(lat0)
  return (lon - lon0) * mlon, (lat - lat0) * mlat
end

local function hypot(x, y) return math.sqrt((x or 0)^2 + (y or 0)^2) end

-- ===== helpers (wakeup only) =====
local function sval(s, k, d)
  if type(s) ~= "table" then return d end
  local v = s[k]
  if type(v) == "table" then v = v.value or v.val or v.v or v[1] end
  v = tonumber(v)
  return v ~= nil and v or d
end

-- cross-version atan2
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
  local lat = math.rad(lat_deg or 0)
  local m_per_deg_lat = 111320.0
  local m_per_deg_lon = 111320.0 * math.cos(lat)
  return m_per_deg_lat, m_per_deg_lon
end

local function enu_from_latlon(lat, lon, lat0, lon0)
  local mlat, mlon = meters_per_deg(lat0 or 0)
  return (lon - (lon0 or 0)) * mlon, (lat - (lat0 or 0)) * mlat   -- x East, y North
end

-- ===== integer/finite-safe drawing wrappers (Ethos likes ints) =====
local function i(v)  -- round to nearest int
  return math.floor((tonumber(v) or 0) + 0.5)
end
local function finite(v)
  v = tonumber(v) or 0
  return v == v and v ~= 1/0 and v ~= -1/0 -- not NaN/Inf
end

local function dline(x1,y1,x2,y2)
  lcd.drawLine(i(x1), i(y1), i(x2), i(y2))
end
local function drect(x,y,w,h)
  lcd.drawRectangle(i(x), i(y), i(w), i(h))
end
local function dfrect(x,y,w,h)
  lcd.drawFilledRectangle(i(x), i(y), i(w), i(h))
end
local function dtri(x1,y1,x2,y2,x3,y3,filled)
  x1,y1,x2,y2,x3,y3 = i(x1),i(y1),i(x2),i(y2),i(x3),i(y3)
  if filled and lcd.drawFilledTriangle then
    lcd.drawFilledTriangle(x1,y1,x2,y2,x3,y3)
  else
    if lcd.drawTriangle then lcd.drawTriangle(x1,y1,x2,y2,x3,y3) else
      lcd.drawLine(x1,y1,x2,y2); lcd.drawLine(x2,y2,x3,y3); lcd.drawLine(x3,y3,x1,y1)
    end
  end
end
local function dtext(x,y,txt)
  lcd.drawText(i(x), i(y), tostring(txt or ""))
end

-- ===== public API =====

-- sensors expected (names are flexible): latitude, longitude, home_lat, home_lon,
-- heading (deg), course (deg) optional, groundspeed (m/s or your units)
-- Options:
--   colors = {bg, grid, own, home, text}
--   north_up = false (heading-up by default)
--   min_ppm, max_ppm (pixels per meter) bounds for auto-zoom
--   keep_home_margin = 18 (px)
--   show_grid = true
--   light_on_gps_ms = 2000  (optional reduced drawing when GPS first appears)
function RenderMap.wakeup(x, y, w, h, sensors, opts)
  opts = opts or {}

  local lat  = sval(sensors, "latitude",  0)
  local lon  = sval(sensors, "longitude", 0)
  local hlat = sval(sensors, "home_lat",  0)
  local hlon = sval(sensors, "home_lon",  0)

  -- fall back: if no explicit home in sensors, allow opts.home.{lat,lon}
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
  local ppm_auto = math.min((w - 2*margin)/span_m, (h - 2*margin)/span_m)
  local ppm      = opts.ppm or clamp(ppm_auto, ppm_min, ppm_max)
  if not finite(ppm) or ppm <= 0 then ppm = 1 end

  -- Map rotation: heading-up (default) or North-up
  local map_up_deg = (opts.north_up and 0 or heading)
  local r = math.rad(map_up_deg)
  local s, c = math.sin(r), math.cos(r)

  -- home screen position (relative to box origin)
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
  local vx, vy = nil, nil
  if gs and gs > 0 then
    local cr = math.rad(opts.north_up and course - map_up_deg or 0)  -- heading-up already aligned
    local sc, cc = math.sin(cr), math.cos(cr)
    vx, vy = sc * gs, -cc * gs
    vx, vy = cx + vx * ppm * 0.8, cy + vy * ppm * 0.8
  end

  -- Colors
  local colors = opts.colors or {}
  local col_bg     = colors.bg     or lcd.RGB(0, 60, 0)
  local col_grid   = colors.grid   or lcd.RGB(0, 90, 0)
  local col_own    = colors.own    or lcd.RGB(255, 255, 255)
  local col_home   = colors.home   or lcd.RGB(255, 255, 255)
  local col_text   = colors.text   or lcd.RGB(255, 255, 255)

  -- Optional light mode for first GPS appearance
  if not RenderMap._light_until and (lat ~= 0 or lon ~= 0) and (lcd.getTime and opts.light_on_gps_ms) then
    RenderMap._light_until = lcd.getTime() + (opts.light_on_gps_ms or 2000)
  end

 -- capture/resolve icons (load once; no per-frame loads)
  local o = opts or {}
  _set_icon("home", o.home_icon)
  _set_icon("own",  o.own_icon)

  -- Primitive frame
  RenderMap._frame = {
    box     = {x=x, y=y, w=w, h=h},
    ppm     = ppm,
    mapRot  = map_up_deg,
    colors  = {bg=col_bg, grid=col_grid, own=col_own, home=col_home, text=col_text},
    own_tri = own_tri,
    show_distance = (o.show_distance ~= false),
    home_xy = { x = x + hx, y = y + hy },
    spd_vec = (vx and vy) and { cx, cy, vx, vy } or nil,
    readout = { gs = gs, dist = dist_m, brg = brg },
    show_grid = (o.show_grid ~= false),
    north_up  = (o.north_up == true),
    opts      = { angle_step = o.angle_step or 10 }, -- quantize rotation to reduce churn
  }
end


-- Pure renderer
function RenderMap.paint()
  local F = RenderMap._frame
  if not F then return end
  local x, y, w, h = F.box.x, F.box.y, F.box.w, F.box.h

  -- clip
  lcd.setClipping(i(x), i(y), i(w), i(h))

  -- background
  lcd.color(F.colors.bg); dfrect(x, y, w, h)

  -- light mode check (reduces draw load briefly after GPS shows up)
  local light = false
  if RenderMap._light_until and lcd.getTime then
    light = lcd.getTime() < RenderMap._light_until
    if not light then RenderMap._light_until = nil end
  end

  -- optional grid
  if F.show_grid and not light then
    lcd.color(F.colors.grid)
    local step = 32
    for gx = x, x+w, step do dline(gx, y, gx, y+h) end
    for gy = y, y+h, step do dline(x, gy, x+w, gy) end
  end

  -- home icon (bitmap if provided, else fallback)
  do
    local hx, hy = F.home_xy.x, F.home_xy.y
    local hbmp = RenderMap._icons.home
    if hbmp then
      lcd.drawBitmap(i(hx - 8), i(hy - 8), hbmp)
    else
      lcd.color(F.colors.home)
      local s = 6
      dtri(hx - s, hy - s, hx, hy - 2*s, hx + s, hy - s, true)
      dfrect(hx - 0.7*s, hy - s, 1.4*s, 1.7*s)
    end
  end

  -- ownship (bitmap if provided, rotated-cached; else triangle)
  do
    local obmp = RenderMap._icons.own
    if obmp and obmp.rotate then
      local cx, cy = F.box.x + F.box.w/2, F.box.y + F.box.h/2
      local step = (F.opts and F.opts.angle_step) or 10
      local ang  = (F.mapRot or 0) % 360
      local bucket = step > 0 and (math.floor((ang + step/2)/step) * step) or ang

      local rc = RenderMap._rot_cache
      if rc.angle ~= bucket or not rc.bmp then
        -- replace cached rotation
        _dispose_rotated()
        rc.bmp = obmp:rotate(bucket)
        rc.angle = bucket
      end

      local rw, rh = _bmp_size(rc.bmp)
      lcd.drawBitmap(i(cx - rw/2), i(cy - rh/2), rc.bmp)
    else
      -- fallback triangle
      lcd.color(F.colors.own)
      local t = F.own_tri
      dtri(t[1],t[2], t[3],t[4], t[5],t[6], true)
    end
  end

  -- speed vector
  if F.spd_vec then
    dline(F.spd_vec[1], F.spd_vec[2], F.spd_vec[3], F.spd_vec[4])
  end

  -- readouts
  if F.show_distance then
    lcd.color(F.colors.text); lcd.font(FONT_XS)
    local gs = tonumber(F.readout.gs) or 0
    local dist_ft = (tonumber(F.readout.dist) or 0) * 3.28084
    local brg = tonumber(F.readout.brg) or 0
    local dist_ft_0 = math.floor(dist_ft + 0.5)
    local brg_0 = (math.floor(brg + 0.5)) % 360

    dtext(x + 4, y + 4, string.format("%.1f u/s", gs))
    dtext(x + 4, y + h - 12, string.format("%dft  %03d°", dist_ft_0, brg_0))
  end
    -- heading tape on sides (W/E markers like your screenshot)
    dtext(x + 2,  y + h/2 - 6, "W")
    dtext(x + w - 10, y + h/2 - 6, "E")

  -- reset clip
  local W,H = lcd.getWindowSize()
  lcd.setClipping(0,0,W,H)
end


RenderMap.hypot = hypot
RenderMap.enu_dxdy = enu_dxdy
RenderMap.meters_per_deg = meters_per_deg

return RenderMap
