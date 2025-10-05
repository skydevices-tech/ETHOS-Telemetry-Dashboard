-- Keep the namespace local (no globals)
local inavdash= {}


-- Basic project info (keep in below format as some deployment tools parse this)
local config = {}
config.name= "INAV Dashboard"
config.version = {major = 0, minor = 0, revision = 0, suffix = "DEV"}
config.ethosVersion = {1, 6, 2}
config.baseDir = "inav-dashboard"
config.key = "inavdsh"


inavdash.config = config

-- Shared environment so every chunk sees `inavdash` without touching _G
local ENV = setmetatable({ inavdash = inavdash }, {
  __index = _G,
  -- Uncomment to forbid accidental globals from modules:
   __newindex = function(_, k) error("attempt to create global '"..tostring(k).."'", 2) end
})

package.path = package.path .. ";inav-dashboard/?.lua;inav-dashboard/?/init.lua"
local mod = require("inavdash")                 -- loads inav-dashboard/inavdash.lua
for k,v in pairs(mod) do inavdash[k]=v end



local function init()


    system.registerWidget(
        {
            key = inavdash.config.key,			-- unique project id
            name = inavdash.config.name,		-- name of widget
            create = inavdash.create,			-- function called when creating widget
            configure = inavdash.configure,		-- function called when configuring the widget (use ethos forms)
            paint = inavdash.paint,				-- function called when lcd.invalidate() is called
            wakeup = inavdash.wakeup,			-- function called as the main loop
            read = inavdash.read,				-- function called when starting widget and reading configuration params
            write = inavdash.write,				-- function called when saving values / changing values in the configuration menu
			event = inavdash.event,				-- function called when buttons or screen clips occur
			menu = inavdash.menu,				-- function called to add items to the menu
			persistent = false,			        -- true or false to make the widget carry values between sessions and models (not safe imho)
        }
    )

end

return {init = init}