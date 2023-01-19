--[[

     Licensed under GNU General Public License v2
      * (c) 2013,      Luca CPZ
      * (c) 2010-2012, Peter Hofmann

--]]

local helpers              = require("lain.helpers")
local wibox                = require("wibox")
local gmatch, lines, floor = string.gmatch, io.lines, math.floor

-- Memory usage (ignoring caches)
-- lain.widget.mem

local function factory(args)
    args           = args or {}

    local mem      = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 2
    local settings = args.settings or function(_, _) end

    function mem.update()
        mem.now = {}
        for line in lines("/proc/meminfo") do
            for k, v in gmatch(line, "([%a]+):[%s]+([%d]+).+") do
                if     k == "MemTotal"     then mem.now.total = floor(v / 1024 + 0.5)
                elseif k == "MemFree"      then mem.now.free  = floor(v / 1024 + 0.5)
                elseif k == "Buffers"      then mem.now.buf   = floor(v / 1024 + 0.5)
                elseif k == "Cached"       then mem.now.cache = floor(v / 1024 + 0.5)
                elseif k == "SwapTotal"    then mem.now.swap  = floor(v / 1024 + 0.5)
                elseif k == "SwapFree"     then mem.now.swapf = floor(v / 1024 + 0.5)
                elseif k == "SReclaimable" then mem.now.srec  = floor(v / 1024 + 0.5)
                end
            end
        end

        mem.now.used = mem.now.total - mem.now.free - mem.now.buf - mem.now.cache - mem.now.srec
        mem.now.swapused = mem.now.swap - mem.now.swapf
        mem.now.perc = math.floor(mem.now.used / mem.now.total * 100)

        settings(mem.widget, mem.now)
    end

    helpers.newtimer("mem", timeout, mem.update)

    return mem
end

return factory
