--[[

     Licensed under GNU General Public License v2
      * (c) 2013,      Luca CPZ
      * (c) 2010-2012, Peter Hofmann

--]]

local helpers = require("lain.helpers")
local naughty = require("naughty")
local wibox   = require("wibox")
local string  = string

-- Network infos
-- lain.widget.net

local function factory(args)
    args             = args or {}

    local net        = { widget = args.widget or wibox.widget.textbox(), devices = {} }
    local timeout    = args.timeout or 2
    local units      = args.units or 1024 -- KB
    local notify     = args.notify or "on"
    local wifi_state = args.wifi_state or "off"
    local eth_state  = args.eth_state or "off"
    local screen     = args.screen or 1
    local format     = args.format or "%.1f"
    local settings   = args.settings or function(_, _) end

    -- Compatibility with old API where iface was a string corresponding to 1 interface
    net.iface = (args.iface and (type(args.iface) == "string" and {args.iface}) or
                (type(args.iface) == "table" and args.iface)) or {}

    function net.get_devices()
        net.iface = {} -- reset at every call
        helpers.line_callback("ip link", function(line)
            net.iface[#net.iface + 1] = not string.match(line, "LOOPBACK") and string.match(line, "(%w+): <") or nil
        end)
    end

    if #net.iface == 0 then net.get_devices() end

    function net.update()
        -- These are the totals over all specified interfaces
        net.now = {
            devices  = {},
            -- Bytes since last iteration
            sent     = 0,
            received = 0
        }

        for _, dev in ipairs(net.iface) do
            local dev_now    = {}
            local dev_before = net.devices[dev] or { last_t = 0, last_r = 0 }
            local now_t      = tonumber(helpers.first_line(string.format("/sys/class/net/%s/statistics/tx_bytes", dev)) or 0)
            local now_r      = tonumber(helpers.first_line(string.format("/sys/class/net/%s/statistics/rx_bytes", dev)) or 0)

            dev_now.carrier  = helpers.first_line(string.format("/sys/class/net/%s/carrier", dev)) or "0"
            dev_now.state    = helpers.first_line(string.format("/sys/class/net/%s/operstate", dev)) or "down"

            dev_now.sent     = (now_t - dev_before.last_t) / timeout / units
            dev_now.received = (now_r - dev_before.last_r) / timeout / units

            net.now.sent     = net.now.sent + dev_now.sent
            net.now.received = net.now.received + dev_now.received

            dev_now.sent     = string.format(format, dev_now.sent)
            dev_now.received = string.format(format, dev_now.received)

            dev_now.last_t   = now_t
            dev_now.last_r   = now_r

            if wifi_state == "on" and helpers.first_line(string.format("/sys/class/net/%s/uevent", dev)) == "DEVTYPE=wlan" then
                dev_now.wifi   = true
                if string.match(dev_now.carrier, "1") then
                        dev_now.signal = tonumber(string.match(helpers.lines_from("/proc/net/wireless")[3], "(%-%d+%.)")) or nil
                end
            else
                dev_now.wifi   = false
            end

            if eth_state == "on" and helpers.first_line(string.format("/sys/class/net/%s/uevent", dev)) ~= "DEVTYPE=wlan" then
                dev_now.ethernet = true
            else
                dev_now.ethernet = false
            end

            net.devices[dev] = dev_now

            -- Notify only once when connection is lost
            if string.match(dev_now.carrier, "0") and notify == "on" and helpers.get_map(dev) then
                naughty.notify {
                    title    = dev,
                    text     = "No carrier",
                    icon     = helpers.icons_dir .. "no_net.png",
                    screen   = screen
                }
                helpers.set_map(dev, false)
            elseif string.match(dev_now.carrier, "1") then
                helpers.set_map(dev, true)
            end

            net.now.carrier = dev_now.carrier
            net.now.state = dev_now.state
            net.now.devices[dev] = dev_now
            -- net.now.sent and net.now.received will be
            -- the totals across all specified devices
        end

        net.now.sent_string = string.format(format, net.now.sent)
        net.now.received_string = string.format(format, net.now.received)

        settings(net.widget, net.now)
    end

    helpers.newtimer("network", timeout, net.update)

    return net
end

return factory
