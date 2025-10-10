-- homedirection.lua
-- Minimal Direction-to-Home widget that selects one of 4 arrow bitmaps.
-- Inputs (via 'sensors' table in wakeup):
--   latitude, longitude           : craft lat/lon (deg)
--   home_lat, home_lon            : home lat/lon (deg)
--   heading                       : craft heading (deg, 0..360, 0 = North)
-- Options (opts):
--   images = {
--      forward = "gfx/hd_fwd.png",
--      left    = "gfx/hd_left.png",
--      right   = "gfx/hd_right.png",
--      back    = "gfx/hd_back.png",
--   }
--   colors = { bg = lcd.RGB(40,40,40), frame = lcd.RGB(80,80,80), text = lcd.RGB(255,255,255) }
--   show_ring = true    -- draw soft ring behind arrow
--   show_text = false   -- show distance and/or status
--   radius_px = nil     -- optional fixed ring radius (defaults to min(w,h)*0.35)
--
-- Notes:
--   - Uses same ENU + bearing math style as render/map.lua.
--   - Safe if GPS/home not available: shows “--” and no arrow.

local HD = { _frame = nil }

-- ===== helpers (finite/int-safe drawing) =====
local function i(v) return math.floor((tonumber(v) or 0) + 0.5) end
local function drect(x,y,w,h) lcd.drawRectangle(i(x),i(y),i(w),i(h)) end
local function dfrect(x,y,w,h) lcd.drawFilledRectangle(i(x),i(y),i(w),i(h)) end
local function dtext(x,y,t) lcd.drawText(i(x), i(y), tostring(t or "")) end
local function dcircle(x,y,r,fill)
  x,y,r = i(x),i(y),i(r)
  if fill and lcd.drawFilledCircle then lcd.drawFilledCircle(x,y,r) else lcd.drawCircle(x,y,r) end
end

local function fmt_dist_m(m)  -- meters -> "123m" / "1.2km"
  m = tonumber(m)
  if not m or m ~= m or m < 0 then return "--" end
  if m >= 1000 then return string.format("%.1fkm", m / 1000.0) end
  return string.format("%dm", math.floor(m + 0.5))
end

-- Unit-aware distance formatter
local function fmt_distance(m, u)
  m = tonumber(m)
  if not m or m ~= m or m < 0 then return "--" end
  u = tostring(u or "m")
  if u == "ft" or u == "feet" then
    return string.format("%dft", math.floor(m * 3.28084 + 0.5))
  elseif u == "km" then
    return string.format("%.2fkm", m / 1000.0)
  elseif u == "mi" or u == "mile" or u == "miles" then
    return string.format("%.2fmi", m / 1609.344)
  elseif u == "nm" or u == "nmi" then
    return string.format("%.2fnm", m / 1852.0)
  else
    return string.format("%dm", math.floor(m + 0.5))
  end
end

-- atan2 across Lua versions
local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x ~= nil then return math.atan(y, x) end
  return math.atan(y)
end

local function meters_per_deg(lat_deg)
  local lat = math.rad(lat_deg or 0)
  local m_per_deg_lat = 111320.0
  local m_per_deg_lon = 111320.0 * math.cos(lat)
  return m_per_deg_lat, m_per_deg_lon
end

local function enu_from_latlon(lat, lon, lat0, lon0)
  local mlat, mlon = meters_per_deg(lat0 or 0)
  return (lon - (lon0 or 0)) * mlon, (lat - (lat0 or 0)) * mlat   -- x East, y North
end

local function hypot(x, y) x,y = tonumber(x) or 0, tonumber(y) or 0; return math.sqrt(x*x + y*y) end

-- bitmap cache
local _bmp = { fwd=nil, left=nil, right=nil, back=nil, path={} }
local function _resolve_bitmap(path)
  if not path then return nil end
  if _bmp.path[path] then return _bmp.path[path] end
  local ok, b = pcall(lcd.loadBitmap, path)
  if ok and b then _bmp.path[path] = b; return b end
  return nil
end

-- normalize colors
local function col_or(c, fallback)
  if c then return c end
  return fallback or lcd.RGB(255,255,255)
end

-- ===== public API =====

-- wakeup: compute which arrow to show (or none), distance, etc., and capture box/colors
function HD.wakeup(x, y, w, h, sensors, units, opts)
  opts = opts or {}
  sensors = sensors or {}

  -- preferred distance unit from units table (fallback to meters)
  local dist_unit = (units and (units.distance or units.altitude)) or "m"

  local lat  = tonumber(sensors.latitude)  or tonumber(sensors.gps_latitude)  or 0
  local lon  = tonumber(sensors.longitude) or tonumber(sensors.gps_longitude) or 0
  local hlat = tonumber(sensors.home_lat)  or tonumber(sensors.home_latitude)  or 0
  local hlon = tonumber(sensors.home_lon)  or tonumber(sensors.home_longitude) or 0
  local hdg  = (tonumber(sensors.heading) or 0) % 360
  local dist_sensor = tonumber(sensors.gps_distancehome or sensors.home_distance or sensors.distance_home or sensors.distancehome)

  -- choose colors + visuals
  local colors = opts.colors or {}
  local col_bg    = col_or(colors.bg,    lcd.RGB(40,40,40))
  local col_frame = col_or(colors.frame, lcd.RGB(90,90,90))
  local col_text  = col_or(colors.text,  lcd.RGB(255,255,255))

  -- lazy-load images once
  local img = opts.images or {}
  if img.forward then _bmp.fwd  = _resolve_bitmap(img.forward) end
  if img.left    then _bmp.left = _resolve_bitmap(img.left)    end
  if img.right   then _bmp.right= _resolve_bitmap(img.right)   end
  if img.back    then _bmp.back = _resolve_bitmap(img.back)    end

  local haveHome = (hlat ~= 0 and hlon ~= 0)
  local haveGPS  = (lat  ~= 0 or  lon ~= 0) -- loose gate

  local selected = nil
  local dist_m   = 0
  local diff_deg = 0
  local status   = "NO GPS"

  if haveGPS and haveHome then
    -- distance (prefer sensor if available)
    local e, n = enu_from_latlon(lat, lon, hlat, hlon)
    local dist_m = hypot(e, n)
    if dist_sensor and dist_sensor > 0 then dist_m = dist_sensor end

    -- bearing to home (deg from North, from clockwise)
    local brg = (math.deg(atan2(-e, -n)) + 360) % 360

    -- signed difference (-180..+180), + = turn right, - = turn left
    diff_deg = ((brg - hdg + 540) % 360) - 180

    -- choose quadrant
    local ad = math.abs(diff_deg)
    if ad <= 45 then
      selected = "fwd"
    elseif ad <= 135 then
      selected = (diff_deg > 0) and "right" or "left"
    else
      selected = "back"
    end

    status = fmt_distance(dist_m, dist_unit)
  elseif haveGPS and not haveHome then
    status = "NO HOME"
  end

  -- ring size
  local R = tonumber(opts.radius_px) or math.floor(math.min(w, h) * 0.35 + 0.5)

  HD._frame = {
    box = {x=x, y=y, w=w, h=h},
    colors = { bg=col_bg, frame=col_frame, text=col_text },
    ring = { r = R, show = (opts.show_ring ~= false) },
    text = { show = (opts.show_text == true), str = status },
    pick = selected,         -- "fwd" | "left" | "right" | "back" | nil
    dist = dist_m,           -- meters (for external use if wanted)
    diff = diff_deg,         -- signed deg
  }
end

-- paint: draw background, ring, chosen bitmap (centered), and optional text
function HD.paint()
  local F = HD._frame
  if not F then return end

  local x, y, w, h = F.box.x, F.box.y, F.box.w, F.box.h
  local cx, cy = x + w/2, y + h/2

  -- lift the main content slightly to give space below
  if F.text.show then
    cy = cy - (h * 0.08)   -- adjust this fraction to taste (0.05–0.12 looks good)
  end

  -- clip to widget box
  lcd.setClipping(i(x), i(y), i(w), i(h))

  -- background
  lcd.color(F.colors.bg)
  dfrect(x, y, w, h)


  -- ring (optional)
  if F.ring.show then
    lcd.color(F.colors.frame)
    dcircle(cx, cy, F.ring.r, false)
  end

 -- draw chosen arrow bitmap (if available)
    do
    local bmp = nil
    if F.pick == "fwd"   then bmp = _bmp.fwd
    elseif F.pick == "left"  then bmp = _bmp.left
    elseif F.pick == "right" then bmp = _bmp.right
    elseif F.pick == "back"  then bmp = _bmp.back
    end

    -- ▼ new: if nothing selected, default to forward image when available
    if not bmp then bmp = _bmp.fwd end

    if bmp then
        local bw = (bmp.width and bmp:width()) or (bmp.getWidth and bmp:getWidth()) or bmp.w or 0
        local bh = (bmp.height and bmp:height()) or (bmp.getHeight and bmp:getHeight()) or bmp.h or 0
        lcd.drawBitmap(i(cx - (bw/2)), i(cy - (bh/2)), bmp)
    else
        -- (rare) still no bitmap available → draw vector triangle
        lcd.color(F.colors.text)
        local s = math.min(w,h) * 0.18
        lcd.drawFilledTriangle(i(cx), i(cy - 1.4*s), i(cx + 0.9*s), i(cy + 0.6*s), i(cx - 0.9*s), i(cy + 0.6*s))
    end
    end


  -- optional text (distance or status)
    if F.text.show then
    lcd.color(F.colors.text)
    lcd.font(FONT_XS)
    local tw, th = lcd.getTextSize(F.text.str)
    -- lift the text upward by half its height for better visual balance
    dtext(cx - tw / 2, y + h - 14 - (th / 2), F.text.str)
    end

  -- reset clip
  local W,H = lcd.getWindowSize()
  lcd.setClipping(0,0,W,H)
end

return HD
