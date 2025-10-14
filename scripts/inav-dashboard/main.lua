-- Keep the namespace local (no globals)
local inavdash= {}

package.loaded.inavdash = inavdash

-- If you still want to ban accidental globals in this chunk:
local _ENV = setmetatable({ rfsuite = inavdash }, {
  __index = _G,
  __newindex = function(_, k) error("attempt to create global '"..tostring(k).."'", 2) end
})


-- Basic project info (keep in below format as some deployment tools parse this)
local config = {}
config.name= "INAV Dashboard"
config.version = {major = 0, minor = 0, revision = 0, suffix = "DEV"}
config.ethosVersion = {1, 6, 2}
config.baseDir = "inav-dashboard"
config.key = "inavdsh"


inavdash.config = config

inavdash.widget = assert(loadfile("widget.lua"))()


local function init()


    system.registerWidget(
        {
            key = inavdash.config.key,			-- unique project id
            name = inavdash.config.name,		-- name of widget
            create = inavdash.widget.create,			-- function called when creating widget
            configure = inavdash.widget.configure,		-- function called when configuring the widget (use ethos forms)
            paint = inavdash.widget.paint,				-- function called when lcd.invalidate() is called
            wakeup = inavdash.widget.wakeup,			-- function called as the main loop
            read = inavdash.widget.read,				-- function called when starting widget and reading configuration params
            write = inavdash.widget.write,				-- function called when saving values / changing values in the configuration menu
            event = inavdash.widget.event,				-- function called when buttons or screen clips occur
            menu = inavdash.widget.menu,				-- function called to add items to the menu
            persistent = false,			        -- true or false to make the widget carry values between sessions and models (not safe imho)
        }
    )

end

return {init = init}