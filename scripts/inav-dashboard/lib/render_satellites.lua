local render = {}

-- optional: ASCII-only skeleton for width calc when fonts mis-measure multibyte glyphs
local function ascii_skeleton(s)
    return (s or ""):gsub("[\128-\255]", "x")
end

function render.paint(x, y, w, h, label, value, unit, opts)

    -- fallbacks
    if value == nil then value = "-" end
    opts = opts or {}
    if not opts.colorbg    then opts.colorbg    = lcd.RGB(0, 0, 0) end
    if not opts.colorvalue then opts.colorvalue = lcd.RGB(255, 255, 255) end
    if not opts.colorlabel then opts.colorlabel = lcd.RGB(200, 200, 200) end
    if not opts.fontvalue  then opts.fontvalue  = FONT_STD end
    if not opts.fontlabel  then opts.fontlabel  = FONT_S end
    -- optional toggle for ASCII width fallback (default off)
    if opts.widthAsciiFallback == nil then opts.widthAsciiFallback = false end

    -- background
    lcd.color(opts.colorbg)
    lcd.drawFilledRectangle(x, y, w, h)

    -- draw label centered at the top (like toolbox.lua’s title block)
    lcd.font(opts.fontlabel)
    local lw, lh = lcd.getTextSize(label or "")
    local lx = x + (w - lw) / 2
    -- small top inset similar to toolbox (title y ~= bestH/4)
    local ly = y + (lh / 4)
    lcd.color(opts.colorlabel)
    lcd.drawText(lx, ly, label or "")

    -- compute offset so value sits a bit below the title line (toolbox style)
    local offsetY = lh - 3

    -- draw centered value (unit drawn separately to avoid alignment issues)
    local valueStr = tostring(value)
    local unitStr  = unit and tostring(unit) or nil

    lcd.font(opts.fontvalue)

    -- width for centering is based ONLY on the numeric value
    local measureValue = opts.widthAsciiFallback and ascii_skeleton(valueStr) or valueStr
    local vw, vh = lcd.getTextSize(measureValue)

    local vx = x + (w - vw) / 2
    -- center vertically within the box, then push down by the title offset
    local vy = y + (h - vh) / 2 + offsetY

    lcd.color(opts.colorvalue)
    lcd.drawText(vx,  vy, valueStr)

    -- draw unit to the right, so it never affects centering
    if unitStr and unitStr ~= "" then
        local gap = 4 -- small fixed space between number and unit
        lcd.drawText(vx + vw + gap, vy, unitStr)
    end
end

return render
