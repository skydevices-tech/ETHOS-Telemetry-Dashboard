-- homedirection.lua (single-image, rotated)
-- Direction-to-Home widget using ONE bitmap (hd.png) rotated in 5° steps.
-- Safe for Ethos; guards for width/height variants and rotate availability.
--
-- Inputs via wakeup(x,y,w,h, sensors, units, opts):
--   sensors: latitude, longitude, home_lat, home_lon, heading
--   units:   distance unit hint (optional)
--   opts:
--     image       = "gfx/hd.png"   -- single arrow/chevron pointing UP by default
--     angle_step  = 5               -- quantization step in degrees
--     colors      = { bg, ring, text }
--     show_ring   = true
--     show_text   = true            -- show distance or status
--     radius_px   = <number>        -- optional ring radius
--     flip_180    = false           -- set true if your hd.png points DOWN by default
--
-- Notes:
--  * Rotation is the signed difference from heading to bearing-to-home.
--    +ve = turn right, -ve = turn left (clockwise positive for Ethos rotate).
--  * If rotate() is not supported on your Ethos version, we draw a triangle.

local HD = { _frame = nil }

-- ===== helpers =====
local function i(v) return math.floor((tonumber(v) or 0) + 0.5) end
local function dfrect(x,y,w,h) lcd.drawFilledRectangle(i(x),i(y),i(w),i(h)) end
local function dtext(x,y,t) lcd.drawText(i(x), i(y), tostring(t or "")) end
local function dcircle(x,y,r,fill)
  x,y,r = i(x),i(y),i(r)
  if fill and lcd.drawFilledCircle then lcd.drawFilledCircle(x,y,r) else lcd.drawCircle(x,y,r) end
end
local function atan2(y,x)
  if math.atan2 then return math.atan2(y,x) end
  if x ~= nil then return math.atan(y,x) end
  return math.atan(y)
end
local function meters_per_deg(lat_deg)
  local lat = math.rad(lat_deg or 0)
  return 111320.0, 111320.0 * math.cos(lat)
end
local function enu_from_latlon(lat, lon, lat0, lon0)
  local mlat, mlon = meters_per_deg(lat0 or 0)
  return (lon - (lon0 or 0)) * mlon, (lat - (lat0 or 0)) * mlat -- x East, y North
end
local function hypot(x,y) x,y=tonumber(x) or 0, tonumber(y) or 0; return math.sqrt(x*x+y*y) end

-- bitmap + rotation cache
local _bmp = { src=nil, path=nil }
local _rot = { angle=nil, bmp=nil }

local function _resolve_bitmap(path)
  if not path then return nil end
  if _bmp.path == path and _bmp.src then return _bmp.src end
  local ok, b = pcall(lcd.loadBitmap, path)
  if ok and b then _bmp.path, _bmp.src = path, b; return b end
  return nil
end

local function _dispose_rot()
  if _rot.bmp and _rot.bmp.delete then pcall(function() _rot.bmp:delete() end) end
  _rot.angle, _rot.bmp = nil, nil
end

local function _bmp_size(b)
  if not b then return 0,0 end
  local w = (b.width and ((type(b.width)=="function") and b:width() or b.width))
         or (b.getWidth and ((type(b.getWidth)=="function") and b:getWidth() or b.getWidth))
         or b.w or 0
  local h = (b.height and ((type(b.height)=="function") and b:height() or b.height))
         or (b.getHeight and ((type(b.getHeight)=="function") and b:getHeight() or b.getHeight))
         or b.h or 0
  return tonumber(w) or 0, tonumber(h) or 0
end

local function col_or(c,f) return c or f or lcd.RGB(255,255,255) end

-- ===== API =====
function HD.wakeup(x, y, w, h, sensors, units, opts)
  opts = opts or {}; sensors = sensors or {}
  local lat  = tonumber(sensors.latitude)  or tonumber(sensors.gps_latitude)  or 0
  local lon  = tonumber(sensors.longitude) or tonumber(sensors.gps_longitude) or 0
  local hlat = tonumber(sensors.home_lat)  or tonumber(sensors.home_latitude)  or 0
  local hlon = tonumber(sensors.home_lon)  or tonumber(sensors.home_longitude) or 0
  --local hdg  = (tonumber(sensors.heading) or 0) % 360
  local hdg  = ((tonumber(sensors.heading) or 0) + 180) % 360

  -- colors / visuals
  local colors = opts.colors or {}
  local col_bg   = col_or(colors.bg,   lcd.RGB(40,40,40))
  local col_ring = col_or(colors.ring, lcd.RGB(90,90,90))
  local col_text = col_or(colors.text, lcd.RGB(255,255,255))

  -- image
  local img_path = opts.image -- string path to single image
  local img = _resolve_bitmap(img_path)

  local haveHome = (hlat ~= 0 and hlon ~= 0)
  local haveGPS  = (lat  ~= 0 or  lon ~= 0)

  local status = "NO GPS"
  local dist_m = 0
  local diff   = 0   -- signed difference: +right / -left

  if haveGPS and haveHome then
    local e, n = enu_from_latlon(lat, lon, hlat, hlon) -- craft relative to home? (home at 0,0)
    -- vector to home from craft is (-e, -n)
    local brg = (math.deg(atan2(-e, -n)) + 360) % 360  -- 0=N, clockwise
    diff = ((brg - hdg + 540) % 360) - 180              -- -180..+180
    dist_m = hypot(e, n)
    status = string.format("%dm", math.floor(dist_m + 0.5))
  elseif haveGPS and not haveHome then
    status = "NO HOME"
  end

  local step = tonumber(opts.angle_step) or 5
  if step < 1 then step = 1 end
  local ang = diff
  if opts.flip_180 then ang = (ang + 180) end
  -- quantize angle to step
  ang = (math.floor((ang + (step/2)) / step) * step) % 360

  -- ring radius
  local R = tonumber(opts.radius_px) or math.floor(math.min(w, h) * 0.35 + 0.5)

  HD._frame = {
    box={x=x,y=y,w=w,h=h},
    colors={bg=col_bg, ring=col_ring, text=col_text},
    img=img,
    img_path=img_path,
    ring={r=R, show=(opts.show_ring ~= false)},
    text={ show=(opts.show_text == true), str=status },
    angle=ang,
  }
end

function HD.paint()
  local F = HD._frame
  if not F then return end
  local x,y,w,h = F.box.x, F.box.y, F.box.w, F.box.h
  local cx, cy = x + w/2, y + h/2

  if F.text.show then cy = cy - (h * 0.08) end

  lcd.setClipping(i(x), i(y), i(w), i(h))
  lcd.color(F.colors.bg); dfrect(x,y,w,h)

  if F.ring.show then lcd.color(F.colors.ring); dcircle(cx, cy, F.ring.r, false) end

  local bmp = F.img
  if bmp and bmp.rotate then
    -- use rotation cache with 5° buckets (or configured step)
    local step = 5
    local ang = (F.angle or 0) % 360
    if F.opts and F.opts.angle_step then step = F.opts.angle_step end
    local bucket = step>0 and (math.floor((ang + step/2)/step)*step) or ang

    if _rot.angle ~= bucket or not _rot.bmp then
      _dispose_rot()
      _rot.bmp = bmp:rotate(bucket)
      _rot.angle = bucket
    end
    local rw,rh = _bmp_size(_rot.bmp)
    lcd.drawBitmap(i(cx - rw/2), i(cy - rh/2), _rot.bmp)
  else
    -- fallback triangle when no bitmap or no rotate()
    lcd.color(F.colors.text)
    local s = math.min(w,h) * 0.18
    local ang = math.rad((F.angle or 0))
    local sa, ca = math.sin(ang), math.cos(ang)
    local p1x, p1y = 0, -1.4*s
    local p2x, p2y = 0.9*s, 0.6*s
    local p3x, p3y = -0.9*s, 0.6*s
    local function rot(px,py) return px*ca - py*sa, px*sa + py*ca end
    p1x,p1y = rot(p1x,p1y); p2x,p2y = rot(p2x,p2y); p3x,p3y = rot(p3x,p3y)
    lcd.drawFilledTriangle(i(cx+p1x),i(cy+p1y), i(cx+p2x),i(cy+p2y), i(cx+p3x),i(cy+p3y))
  end

  if F.text.show then
    lcd.color(F.colors.text); lcd.font(FONT_XS)
    local tw, th = lcd.getTextSize(F.text.str)
    dtext(cx - tw/2, y + h - 14 - (th/2), F.text.str)
  end

  local W,H = lcd.getWindowSize(); lcd.setClipping(0,0,W,H)
end

return HD
