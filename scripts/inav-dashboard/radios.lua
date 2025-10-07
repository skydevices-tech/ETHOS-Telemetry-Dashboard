local environment = system.getVersion()
local LCD_W = environment['lcdWidth']
local LCD_H = environment['lcdHeight']

local resolution = LCD_W .. "x" .. LCD_H

--[[
  Supported Radios (by native resolution):
    • TANDEM X20 / TANDEM XE   → "800x480"
    • TANDEM X18 / TWIN X Lite → "480x320"  ← fallback target
    • Twin X14                 → "640x360"

  Behavior:
    - If the current resolution isn't in supportedRadios, fall back to X18 (480x320)
      and print a debug line.
]]

local supportedRadios = {
  ---------------------------------------------------------------------------
  -- TANDEM X20 / TANDEM XE (800x480)
  ---------------------------------------------------------------------------
  ["800x480"] = {
    fontTitle             = {FONT_XXS, FONT_XS},                            -- Font used for titles/labels
    fontValue             = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L},    -- Font used for telemetry values
    gpsFontValue          = {FONT_XXS, FONT_XS, FONT_S},                    -- Font used for GPS lat/lon values
    gpsLineGap            = 4,                                              -- gap between lat/lon lines
    unitGap               = 0,                                              -- gap between value and unit in telemetry
  },

  ---------------------------------------------------------------------------
  -- TANDEM X18 / TWIN X Lite (480x320)
  ---------------------------------------------------------------------------
  ["480x320"] = {
    fontTitle             = {FONT_XXS},                                     --
    fontValue             = {FONT_XXS, FONT_XS, FONT_S, FONT_M},            -- Font used for telemetry
    gpsFontValue          = {FONT_XXS, FONT_XS, FONT_S},                    -- Font used for GPS lat/lon values    
    gpsLineGap            = -2,                                             -- gap between lat/lon lines
    unitGap               = 0                                               -- gap between value and unit in telemetry
  },

  ---------------------------------------------------------------------------
  -- Twin X14 (640x360)
  ---------------------------------------------------------------------------
  ["640x360"] = {
    fontTitle             = {FONT_XXS, FONT_XS},                            -- Font used for titles/labels
    fontValue             = {FONT_XXS, FONT_XS, FONT_S, FONT_M},            -- Font used for telemetry values
    gpsFontValue          = {FONT_XXS, FONT_XS, FONT_S},                    -- Font used for GPS lat/lon values
    gpsLineGap            = 3,                                              -- gap between lat/lon lines
    unitGap               = 0                                               -- gap between value and unit in telemetry
  },
}

-- Pick active config, falling back to X18 if needed (and print a debug line)
local chosenKey = resolution
if not supportedRadios[chosenKey] then
  print(string.format("[ui] %s not supported; falling back to X18 (480x320)", resolution))
  chosenKey = "480x320"
end
local radio = supportedRadios[chosenKey]

-- Nil out the unused sub-tables to let GC reclaim them
for resKey in pairs(supportedRadios) do
  if resKey ~= chosenKey then
    supportedRadios[resKey] = nil
  end
end

return radio
