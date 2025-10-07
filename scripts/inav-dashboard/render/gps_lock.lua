

local render = {}

local _bmpCache = {}

local function getBitmap(path)
    if not path then return nil end
    if not _bmpCache[path] then
        _bmpCache[path] = lcd.loadBitmap(path, true)
    end
    return _bmpCache[path]
end

-- normalize a color:
-- - number: returned as-is
-- - table: {r,g,b} or {R=..,G=..,B=..} -> lcd.RGB if available
local function normalizeColor(c)
    if type(c) == "number" then return c end
    if type(c) == "table" then
        local r = c.r or c.R or c[1] or 0
        local g = c.g or c.G or c[2] or 0
        local b = c.b or c.B or c[3] or 0
        if lcd.RGB then
            return lcd.RGB(r, g, b)
        end
        -- fallback: some firmwares accept packed 0xRRGGBB
        return (r << 16) | (g << 8) | b
    end
    return nil
end

-- fill background defensively across firmware variants
local function fillBg(x, y, w, h, color)
    if not color then return end
    -- Try common APIs (with/without explicit color arg)
    -- 1) ETHOS often supports setting color via lcd.color() then drawing
    if lcd.color then
        pcall(lcd.color, color)
    end
    if lcd.drawFilledRectangle then
        -- try with color param first
        if not pcall(lcd.drawFilledRectangle, x, y, w, h, color) then
            pcall(lcd.drawFilledRectangle, x, y, w, h)
        end
        return
    end
    if lcd.fillRect then
        if not pcall(lcd.fillRect, x, y, w, h, color) then
            pcall(lcd.fillRect, x, y, w, h)
        end
        return
    end
    -- as a last resort, draw a full-size bitmap background is not possible; ignore
end

function render.paint(x, y, w, h, value, opts)
    -- skip drawing if off-screen
    if not lcd.isVisible() then return end

    opts = opts or {}

    -- optional background color
    local bg = normalizeColor(opts.colorbg)
    if bg then
        fillBg(x, y, w, h, bg)
    end

    -- image mapping
    local images = opts.images or {
        red    = "red.png",
        orange = "orange.png",
        green  = "green.png",
    }

    -- normalize telemetry string
    local key = tostring(value or ""):lower()
    if key ~= "red" and key ~= "orange" and key ~= "green" then
        key = "red"  -- default fallback
    end

    local bmp = getBitmap(images[key])
    if not bmp then return end

    -- draw full box image (stretched to fill / fit depending on firmware)
    lcd.drawBitmap(x, y, bmp, w, h)
end

return render
