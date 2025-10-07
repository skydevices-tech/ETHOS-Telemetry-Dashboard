
local arg = {...}

local telemetry = {}
local protocol, telemetrySOURCE, crsfSOURCE

local currentTelemetrySensor = nil
local currentTelemetryType = nil
local internalModule = nil
local externalModule = nil
local telemetryType


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


-- Lightweight cache for resolved Source objects.
-- Keyed by "<protocol>|<sensorKey>". Weak values let GC clean up sources.
local _sourceCache = setmetatable({}, { __mode = "v" })

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
    end
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
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730 , subId = 0}, 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0440 , subId = 0}, 
            },
            crsf = { "Roll" },
        },
        transform = function(value)
            if currentTelemetryType == "sport" then
                if value then
                    return -value
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
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730, subId = 1 }, 
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0430, subId = 0 }, 
            },
            crsf = { "Pitch" },
        },
        transform = function(value)
            if currentTelemetryType == "sport" then
                if value then
                    return -value
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


}

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
    elseif currentTelemetryType  == "sport" then
            protocol = "sport"
            for _, sensor in ipairs(sensorTable[name].sensors.sport or {}) do
                local source = system.getSource(sensor)
                if source then
                    _sourceCache[key] = source
                    return source
                end
            end
    else
        protocol = "unknown"
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