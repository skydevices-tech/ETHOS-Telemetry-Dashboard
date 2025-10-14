local inavdash = require("inavdash")

-- flightmode.lua
-- Unifies CRSF / S.Port flight mode inputs into a single numeric mode code.

local M = {}

-- Public enum
M.MODE = {
  DISARMED          = 0,
  READY_TO_ARM      = 1,
  ARMING_PREVENTED  = 2,
  ACRO              = 10,
  ANGLE             = 11,
  HORIZON           = 12,
  PASSTHRU          = 13,
  ALT_HOLD_ANGLE    = 20,
  POS_HOLD_ANGLE    = 21,
  WAYPOINT          = 22,
  RTH               = 23,
  COURSE_HOLD       = 26,
  CRUISE            = 27,
  FAILSAFE          = 99,
}

-- Internal state for HRST carry-over
local last_abcde = 0
local last_mode  = M.MODE.DISARMED

-- Helpers (no bitwise ops needed; works in Lua 5.1+)
local function bit_is_set(value, mask)
  value = value or 0
  return (value % (mask * 2)) >= mask
end

local function digits_ABCDE(n)
  n = tonumber(n) or 0
  local E = n % 10; n = (n - E) / 10
  local D = n % 10; n = (n - D) / 10
  local C = n % 10; n = (n - C) / 10
  local B = n % 10; n = (n - B) / 10
  local A = n % 10
  -- floor just in case of floats
  return math.floor(A), math.floor(B), math.floor(C), math.floor(D), math.floor(E)
end

local function pack_ABCDE(A,B,C,D,E)
  return (A or 0)*10000 + (B or 0)*1000 + (C or 0)*100 + (D or 0)*10 + (E or 0)
end

-- CRSF string -> ABCDE (A,B,C,D,E digits)
local function crsfToABCDE(fm)
  if not fm then return 0 end
  local A,B,C,D,E = 0,0,0,0,0
  if fm == "!ERR" or fm == "WAIT" then
    E = 2
  elseif fm == "OK" then
    E = 1
  elseif fm == "ACRO" or fm == "AIR" then
    D, E = 0, 4
  elseif fm == "ANGL" or fm == "STAB" then
    D, E = 1, 4
  elseif fm == "HOR" then
    D, E = 2, 4
  elseif fm == "MANU" then
    D, E = 4, 4
  elseif fm == "AH" then
    C, D, E = 2, 1, 4           -- altitude hold + angle
  elseif fm == "HOLD" then
    C, D, E = 4, 1, 4           -- position hold + angle
  elseif fm == "WP" then
    B, D, E = 2, 1, 4           -- waypoint + angle
  elseif fm == "RTH" then
    B, C, D, E = 1, 6, 1, 4     -- RTH + alt+pos hold + angle
  elseif fm == "!FS!" then
    A, E = 4, 4                 -- failsafe + armed
  elseif fm == "CRS" or fm == "CRSH" then
    B = 8                       -- Course Hold
  elseif fm == "3CRS" or fm == "CRUZ" then
    B, C = 8, 2                 -- Course Hold + Alt Hold
  elseif fm == "HRST" then
    return nil                  -- caller keeps last ABCDE/mode
  else
    E = 0
  end
  return pack_ABCDE(A,B,C,D,E)
end

-- ABCDE -> single numeric mode
local function mapABCDEtoMode(abcde)
  local A,B,C,D,E = digits_ABCDE(abcde)

  -- Failsafe wins (A bit 4)
  if bit_is_set(A,4) then return M.MODE.FAILSAFE end

  local armed     = bit_is_set(E,4)
  local prevented = bit_is_set(E,2)
  local ok        = bit_is_set(E,1)

  if not armed then
    if prevented then return M.MODE.ARMING_PREVENTED end
    if ok        then return M.MODE.READY_TO_ARM     end
    return M.MODE.DISARMED
  end

  -- Armed priorities
  if bit_is_set(B,1) then return M.MODE.RTH      end -- RTH
  if bit_is_set(B,2) then return M.MODE.WAYPOINT end -- Waypoint

  local angle       = bit_is_set(D,1)
  local horizon     = bit_is_set(D,2)
  local passthru    = bit_is_set(D,4)
  local heading     = bit_is_set(C,1)
  local alt         = bit_is_set(C,2)
  local pos         = bit_is_set(C,4)
  local course_hold = bit_is_set(B,8)

  if course_hold and alt  then return M.MODE.CRUISE end
  if course_hold          then return M.MODE.COURSE_HOLD end
  if pos and angle        then return M.MODE.POS_HOLD_ANGLE end
  if alt and angle        then return M.MODE.ALT_HOLD_ANGLE end
  if passthru             then return M.MODE.PASSTHRU end
  if horizon              then return M.MODE.HORIZON end
  if angle                then return M.MODE.ANGLE end

  return M.MODE.ACRO
end

-- Normalize inputs to ABCDE
local function toABCDE(telemType, value)
  if telemType == "sport" then
    return tonumber(value) or 0
  elseif telemType == "crsf" then
    return crsfToABCDE(tostring(value or ""))
  else
    return 0
  end
end

-- Public: eval(telemType, value) -> single numeric mode
function M.eval(telemType, value)
  local abcde = toABCDE(telemType, value)

  -- HRST handling: nil means "keep last"
  if abcde == nil then
    return last_mode
  end

  local mode = mapABCDEtoMode(abcde)

  -- Cache for future HRST or external reads
  last_abcde = abcde
  last_mode  = mode

  return mode
end

-- Optional helpers
function M.last_abcde() return last_abcde end
function M.last_mode()  return last_mode  end
function M.reset()
  last_abcde = 0
  last_mode  = M.MODE.DISARMED
end

return M
