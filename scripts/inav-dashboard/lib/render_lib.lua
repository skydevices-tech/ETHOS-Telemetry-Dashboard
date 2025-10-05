local render_lib = {}


local render_lib = {}

function render_lib.telemetryBox(x, y, w, h, label, value, unit, opts)
    -- fallbacks
    if value == nil then value = "-" end
    opts = opts or {}
    if not opts.colorbg    then opts.colorbg    = lcd.RGB(0, 0, 0) end
    if not opts.colorvalue then opts.colorvalue = lcd.RGB(255, 255, 255) end
    if not opts.colorlabel then opts.colorlabel = lcd.RGB(200, 200, 200) end
    if not opts.fontvalue  then opts.fontvalue  = FONT_STD end
    if not opts.fontlabel  then opts.fontlabel  = FONT_S end

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

    -- draw centered value (with unit)
    local valueText = (tostring(value) or "-") .. (unit and (" " .. unit) or "")
    lcd.font(opts.fontvalue)
    local vw, vh = lcd.getTextSize(valueText)
    local vx = x + (w - vw) / 2
    -- center vertically within the box, then push down by the title offset
    local vy = y + (h - vh) / 2 + offsetY
    lcd.color(opts.colorvalue)
    lcd.drawText(vx, vy, valueText)
end



return render_lib