local render = {}

local function ascii_skeleton(s)
    return (s or ""):gsub("[\128-\255]", "x")
end

-- helper: convert decimal degrees to DMS string
local function toDMS(deg, isLat)
    local absDeg = math.abs(deg)
    local d = math.floor(absDeg)
    local m = math.floor((absDeg - d) * 60)
    local s = (absDeg - d - m / 60) * 3600

    local dir
    if isLat then
        dir = (deg >= 0) and "N" or "S"
    else
        dir = (deg >= 0) and "E" or "W"
    end

    return string.format("%d°%02d'%04.1f\"%s", d, m, s, dir)
end

function render.paint(x, y, w, h, label, latitude, longitude, opts)
    opts = opts or {}
    if not opts.colorbg    then opts.colorbg    = lcd.RGB(0, 0, 0) end
    if not opts.colorvalue then opts.colorvalue = lcd.RGB(255, 255, 255) end
    if not opts.colorlabel then opts.colorlabel = lcd.RGB(200, 200, 200) end
    if not opts.fontvalue  then opts.fontvalue  = FONT_S end
    if not opts.fontlabel  then opts.fontlabel  = FONT_S end
    if opts.widthAsciiFallback == nil then opts.widthAsciiFallback = false end

    if latitude == nil or longitude == nil then
        latitude = 0
        longitude = 0
    end

    -- background
    lcd.color(opts.colorbg)
    lcd.drawFilledRectangle(x, y, w, h)

    -- draw label (top)
    lcd.font(opts.fontlabel)
    local lw, lh = lcd.getTextSize(label or "")
    lcd.color(opts.colorlabel)
    local lx = x + (w - lw) / 2
    local labelBottom = y + lh + 2 -- small gap below label
    lcd.drawText(lx, y + 2, label or "")

    -- convert to DMS
    local latStr = toDMS(latitude, true)
    local lonStr = toDMS(longitude, false)

    -- measure text height for centering
    lcd.font(opts.fontvalue)
    local _, vh = lcd.getTextSize(latStr)
    local totalHeight = vh * 2 + 4 -- 4px gap between lines

    -- vertical start centered in remaining space under label
    local availableHeight = h - (labelBottom - y)
    local vyStart = labelBottom + (availableHeight - totalHeight) / 2

    lcd.color(opts.colorvalue)
    local function drawCenteredText(text, yPos)
        local measure = opts.widthAsciiFallback and ascii_skeleton(text) or text
        local tw, _ = lcd.getTextSize(measure)
        local tx = x + (w - tw) / 2
        lcd.drawText(tx, yPos, text)
    end

    drawCenteredText(latStr, vyStart)
    drawCenteredText(lonStr, vyStart + vh + 4)
end

return render
