
local arg = {...}
local flightmodes = assert(loadfile("sensors/flightmodes.lua"))()

local telemetry = {}
local protocol, telemetrySOURCE, crsfSOURCE

local currentTelemetrySensor = nil
local currentTelemetryType = nil
local internalModule = nil
local externalModule = nil
local telemetryType

local _sourceCache = setmetatable({}, { __mode = "v" })
local _createTried = {}

-- creation throttling
local _startTime = os.clock()         -- seconds since Lua VM start
local _lastCreateTime = -1            -- time of last successful create (seconds)

local function _creationAllowed()
    local now = os.clock()
    -- block creates during first 5s of runtime
    if now < 5.0 then return false end
    -- block if last create was <5s ago
    if _lastCreateTime > 0 and (now - _lastCreateTime) < 5.0 then
        return false
    end
    return true
end


local sensorTable = {

    -- RSSI Sensors
    rssi = {
        name = "RSSI",
        unit_string = "%",
        sensors = {
            sport = {
                { appId = 0xF010, subId = 0 },
            },
            crsf = { "Rx Quality" },
        },
    },

    -- RSSI Sensors
    link = {
        name = "Link Quality",
        unit_string = "dB",
        sensors = {
            sport = {
                { appId = 0xF101, subId = 0 },
            },
            crsf = { "Rx RSSI1" },
        },
    }, 

        
    -- Voltage Sensors
    voltage = {
        name = "Voltage",
        unit_string = "V",
        sensors = {
            sport = {
                { appId = 0x0B50, subId = 0 },
                { appId = 0x0210, subId = 0 },
                { appId = 0xF103, subId = 0 },
                { appId = 0xF103, subId = 1 },
            },
            crsf = { "Rx Batt" },
        },    
    },

    fuel = {
        name = "Fuel",
        unit_string = "%",
        sensors = {
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600 }, },
            crsf = { "Rx Batt%" },
        },
    },

    -- Current Sensors
    current = {
        name = "Current",
        unit_string = "A",
        sensors = {
            sport = {
                { appId = 0x0B50, subId = 1 }, 
                { appId = 0x0200, subId = 0 },                             
            },
            crsf = { "Rx Current" },
        },
    },

    -- ESC Temperature Sensors
    temp_esc = {
        name = "ESC Temperature",
        sensors = {
            sport = {
                { appId = 0x0B70, subId = 0 },
            },
        },
    },

    altitude = {
        name = "Altitude",
        sensors = {
            sport = { 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0820 } ,                
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0100 } 
            
            },
            crsf  = { "GPS alt"},
        },
    },    

    consumption = {
        name = "Consumption",
        unit_string = "mAh",
        sensors = {
            sport = {
                { appId = 0x0B60, subId = 1 },
                { appId = 0x0B30, subId = 0 },
            },
            crsf = { "Rx Cons" },
        },
    },


    heading = {
        name = "Yaw",
        sensors = {
            sport = { 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5210 }, 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0830 },
            },
            crsf = { "GPS Heading" },
        },
    },

    roll = {
        name = "Roll",
        sensors = {
            sport = { 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0440 , subId = 0},                 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730 , subId = 0}, 
            },
            crsf = { "Roll" },
        },
        autoCreate = true,
        transform = function(value)
            if currentTelemetryType == "sport" then
                if value then
                    return -value/10
                end
                return value
            else
                return value
            end
        end
    },

    pitch = {
        name = "Pitch",
        sensors = {
            sport = { 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0430, subId = 0 },                 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730, subId = 1 }, 
            },
            crsf = { "Pitch" },
        },
        autoCreate = true,
        transform = function(value)
            if currentTelemetryType == "sport" then
                if value then
                    return -value/10
                end
                return value
            else
                return value
            end
        end        
    },    

    groundspeed = {
        name = "Ground Speed",
        sensors = {
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0830, subId = 0 }, },
            crsf  = { "GPS speed"},
        },
    },    

    satellites = {
        name = "Satellites",
        sensors = {
            sport = { 
                    { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0480, subId = 0 }, 
                    { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0410, subId = 0 }, 
                    },
            crsf = { "GPS Satellites" },
        },
        transform = function(value)
            if currentTelemetryType == "sport" then
                if value then
                    if string.len(value) > 1 then
                        if string.len(value) < 2 then
                            value = tonumber(widget.value)
                        else
                            value = tonumber(string.sub(value, 3))
                        end
                    end                   
                end
                return value
            else
                return value
            end
        end          
    },    
    
    gps_latitude = {
        name = "GPS Latitude",
        sensors = {
            sport = { 
                    {name="GPS", options=OPTION_LATITUDE},
                    },
            crsf = { 
                    {name="GPS", options=OPTION_LATITUDE},
                    },
        },
    },  
    
    gps_longitude= {
        name = "GPS Longitude",
        sensors = {
            sport = { 
                    {name="GPS", options=OPTION_LONGITUDE},
                    },
            crsf = { 
                    {name="GPS", options=OPTION_LONGITUDE},
                    },
        },
    },  

    flightmode = {
        name = "Flight Mode",
        sensors = {
            sport = { 
                    { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0470, subId = 0 }, 
                    },
            crsf = { "Flight mode" },
        },
        autoCreate = true,
        transform = function(value)
            if currentTelemetryType == "sport" then
                if value then
                    return flightmodes.eval("sport", value)
                end
                return value
            else
                if value then
                    return flightmodes.eval("crsf", value)
                end
            end
        end        
    }, 

    
}


-- Default definitions for auto-created SPORT sensors.
local autoCreate = {
    roll =  {
        name     = "Roll",
        physId   = 0x1B,
        unit     = UNIT_DEGREE,
        decimals = 1,
        appId    = 0x0440,
        subId    = 0,
    },
    pitch = {
        name     = "Pitch",
        physId   = 0x1B,
        unit     = UNIT_DEGREE,
        decimals = 1,
        appId    = 0x0430,
        subId    = 1,
    },
    flightmode = {
        name     = "Flight Mode",
        physId   = 0x1B,
        unit     = UNIT_RAW,
        decimals = 0,
        appId    = 0x0470,
        subId    = 0,
    },
    gps_speed = {
        name     = "GPS Speed",
        physId   = 0x1B,
        unit     = UNIT_KNOT,
        decimals = 0,
        appId    = 0x0830,
        subId    = 0,
    },    
}



local function getTelemetryType()

    -- only do heavy calls when we *don’t* already have a sensor
    if not internalModule or not externalModule then
        internalModule = model.getModule(0)
        externalModule = model.getModule(1)
    end

    if internalModule and internalModule:enable() then
        currentTelemetrySensor      = system.getSource({ appId = 0xF101 })
        currentTelemetryType = "sport"
    elseif externalModule and externalModule:enable() then
        currentTelemetrySensor       = system.getSource({ crsfId = 0x14, subIdStart = 0, subIdEnd = 1 })
        currentTelemetryType = "crsf"
        if not currentTelemetrySensor then
            currentTelemetrySensor      = system.getSource({ appId = 0xF101 })
            currentTelemetryType = "sport"
        end
    end
end

-- Build a unique key for a specific sensor definition (per protocol).
local function _defKey(def)
    return (currentTelemetryType or "unknown")
        .. "|" .. string.format("%04X", def.appId or 0)
        .. "|" .. tostring(def.subId or 0)
end

-- Create a SPORT sensor object via ETHOS API, then set its IDs (once).
local function _createSportSensor(sensorDef, sensorKey)
    if currentTelemetryType ~= "sport" or not currentTelemetrySensor then return false end

    -- rate limit: only after 5s from start, and no more than once every 5s
    if not _creationAllowed() then return false end

    local cfg = autoCreate[sensorKey]
    if not cfg then return false end

    -- Only one try per specific def (protocol+appId+subId) per session.
    local defKey = _defKey(sensorDef)
    if _createTried[defKey] then return false end
    _createTried[defKey] = true


    -- Create the sensor and configure fields
    local sensor = model.createSensor({ type = SENSOR_TYPE_DIY })
    sensor:name(cfg.name)
    sensor:unit(cfg.unit)
    sensor:decimals(cfg.decimals)
    sensor:physId(cfg.physId)
    sensor:appId(cfg.appId)
    sensor:subId(cfg.subId)
    sensor:minimum(min or -1000000000)
    sensor:maximum(max or 2147483647)

    -- success: update last-create timestamp to enforce the 5s gap
    _lastCreateTime = os.clock()
    return true
end


-- Build cache key for current telemetryType + sensor name.
local function _ck(name)
    return (telemetryType or "unknown") .. "|" .. tostring(name)
end

--- Clears all cached Source handles (e.g., after protocol change or sensor rescans).
function telemetry.clearCache()
    _sourceCache = setmetatable({}, { __mode = "v" })
end

--- Optional helper to set telemetry type and invalidate cache in one go.
-- @param t "crsf" | "sport" | "sim" | "unknown"
function telemetry.setTelemetryType(t)
    if telemetryType ~= t then
        telemetryType = t
        telemetry.clearCache()
        -- Also clear creation attempts on protocol change to allow a fresh try.
        _createTried = {}        
    end
end




--[[ 
    Retrieves the current sensor protocol.
    @return protocol - The protocol used by the sensor.
]]
function telemetry.getSensorProtocol()
    return protocol
end


--[[ 
    Helper: Get the raw Source object for a given sensorKey, caching as we go.
]]
function telemetry.getSensorSource(name)
    if not sensorTable[name] then return nil end

    
    -- Fast path: cached handle for this protocol + sensor key
    local key = _ck(name)
    local cached = _sourceCache[key]
    if cached ~= nil then
        return cached
    end

    if currentTelemetryType  == "crsf" then
            protocol = "crsf"
            for _, sensor in ipairs(sensorTable[name].sensors.crsf or {}) do
                local source = system.getSource(sensor)
                if source then
                    _sourceCache[key] = source
                    return source
                end
            end
    elseif currentTelemetryType == "sport" then
        protocol = "sport"
        local entry = sensorTable[name]
        for _, sensor in ipairs(entry.sensors.sport or {}) do
            local source = system.getSource(sensor)
            if source then
            _sourceCache[key] = source
            return source
            end
                -- One-shot self-heal: only for flagged sensors, with an active SPORT link.
                if entry.autoCreate and currentTelemetrySensor then
                    if _createSportSensor(sensor, name) then
                        local s2 = system.getSource(sensor)
                        if s2 then
                            _sourceCache[key] = s2
                            return s2
                        end
                    end
                    -- Whether success or fail, we won't retry this def again this session.
                end
        end
    end

    return nil
end


function telemetry.getSensor(sensorKey)
    local entry = sensorTable[sensorKey]

    -- Virtual source (user-defined)
    if entry and type(entry.source) == "function" then
        local src = entry.source()
        if src and type(src.value) == "function" then
            local value, major, minor = src.value()
            major = major or entry.unit

            -- ✅ Apply transform if defined
            if type(entry.transform) == "function" then
                value = entry.transform(value)
            end

            return value, major, minor
        end
    end

    -- Physical/real telemetry source
    local source = telemetry.getSensorSource(sensorKey)
    if not source then
        return nil
    end

    -- get initial defaults
    local value = source:value()
    local major = entry and entry.unit or nil
    local minor = nil

    -- ✅ Apply transform if defined
    if entry and type(entry.transform) == "function" then
        value = entry.transform(value)
    end

    return value, major, minor
end



function telemetry.wakeup()
    -- Determine telemetry type
    getTelemetryType()


end

return telemetry