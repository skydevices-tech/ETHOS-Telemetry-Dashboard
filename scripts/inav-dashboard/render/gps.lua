local render = {}
local radio = assert(loadfile("radios.lua"))()

-- width-stabilizer for multibyte glyphs (optional)
local function ascii_skeleton(s)
    return (s or ""):gsub("[\128-\255]", "x")
end

-- helper: convert decimal degrees to DMS string
local function toDMS(deg, isLat)
    local absDeg = math.abs(deg)
    local d = math.floor(absDeg)
    local m = math.floor((absDeg - d) * 60)
    local s = (absDeg - d - m / 60) * 3600
    local dir = isLat and ((deg >= 0) and "N" or "S") or ((deg >= 0) and "E" or "W")
    return string.format("%d°%02d'%04.1f\"%s", d, m, s, dir)
end


-- helper: convert decimal degrees to a decimal string (signed)
    local function toDEC(deg, places)
        local fmt = string.format("%%.%df°", places or 5)
        return string.format(fmt, deg)
    end

-- choose largest font where a single line fits
local function chooseFontSingle(text, maxW, maxH, fonts, useAscii)
    local best = { font = fonts[1], w = 0, h = 0 }
    for _, f in ipairs(fonts) do
        lcd.font(f)
        local measure = useAscii and ascii_skeleton(text) or text
        local w, h = lcd.getTextSize(measure)
        if w <= maxW and h <= maxH then
            best = { font = f, w = w, h = h }
        else
            break
        end
    end
    lcd.font(best.font)
    return best
end

-- choose largest font where TWO lines (with gap) fit the box
local function chooseFontTwoLines(line1, line2, gap, maxW, maxH, fonts, useAscii)
    local best = { font = fonts[1], w1 = 0, w2 = 0, h = 0, totalH = 0 }
    for _, f in ipairs(fonts) do
        lcd.font(f)
        local m1 = useAscii and ascii_skeleton(line1) or line1
        local m2 = useAscii and ascii_skeleton(line2) or line2
        local w1, h1 = lcd.getTextSize(m1)
        local w2, h2 = lcd.getTextSize(m2)
        local needW = math.max(w1, w2)
        local needH = h1 + gap + h2
        if needW <= maxW and needH <= maxH then
            best = { font = f, w1 = w1, w2 = w2, h = math.max(h1, h2), totalH = needH }
        else
            break
        end
    end
    lcd.font(best.font)
    return best
end

function render.paint(x, y, w, h, label, latitude, longitude, opts)


    opts = opts or {}
    if not opts.colorbg    then opts.colorbg    = lcd.RGB(0, 0, 0) end
    if not opts.colorvalue then opts.colorvalue = lcd.RGB(255, 255, 255) end
    if not opts.colorlabel then
        opts.colorlabel = (lcd.darkMode() and lcd.RGB(154,154,154)) or lcd.RGB(77,73,77)
    end
    if opts.widthAsciiFallback == nil then opts.widthAsciiFallback = false end

    if latitude == nil or longitude == nil then
        latitude, longitude = 0, 0
    end

    -- background
    lcd.color(opts.colorbg)
    lcd.drawFilledRectangle(x, y, w, h)

    local TEXT_COLOR = (lcd.darkMode() and lcd.RGB(255,255,255)) or lcd.RGB(77,73,77)

    -----------------------------------------------------------------------
    -- Auto-sized label at top
    -----------------------------------------------------------------------
    local offsetY = 0
    if label and label ~= "" then
        local fontsTitle = radio.fontTitle or {FONT_XXS, FONT_XS}
        local title = chooseFontSingle(label, w * 0.9, h, fontsTitle, false)
        local lx = x + (w - title.w) / 2
        local ly = y + (title.h / 4)      -- subtle inset
        lcd.color(opts.colorlabel)
        lcd.drawText(lx, ly, label)
        offsetY = title.h - 3              -- push content down a touch
    end

    
-----------------------------------------------------------------------
-- Two-line value block (Latitude / Longitude), auto-sized together
-----------------------------------------------------------------------
local useDecimal = (opts.minWidthForDMS ~= nil) and (w < opts.minWidthForDMS)

local latStr, lonStr
if useDecimal then
    -- Decimal degrees (signed): e.g., 51.5074°, -0.1278°
    latStr = toDEC(latitude, opts.decimalPlaces)
    lonStr = toDEC(longitude, opts.decimalPlaces)
else
    -- Original DMS rendering with N/S/E/W
    latStr = toDMS(latitude, true)
    lonStr = toDMS(longitude, false)
end


    local gap = radio.gpsLineGap or 4
    local fontsValue = radio.gpsFontValue or {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L}
    local maxWVal, maxHVal = w * 0.92, (h - offsetY)
    local chosen = chooseFontTwoLines(latStr, lonStr, gap, maxWVal, maxHVal, fontsValue, opts.widthAsciiFallback)

    -- vertical start centered in remaining space under label
    local vyStart = y + offsetY + ( (h - offsetY) - chosen.totalH ) / 2

    lcd.color(TEXT_COLOR)
    -- draw each line centered (same font)
    local function drawCentered(text, yPos)
        local measure = opts.widthAsciiFallback and ascii_skeleton(text) or text
        local tw = lcd.getTextSize(measure)
        local tx = x + (w - tw) / 2
        lcd.drawText(tx, yPos, text)
    end

    drawCentered(latStr, vyStart)
    drawCentered(lonStr, vyStart + chosen.h + gap)
end

return render
