--[[

     Licensed under GNU General Public License v2
      * (c) 2020, razamatan@hotmail.com

--]]

local lgi = require 'lgi'
local GLib, Gio = lgi.GLib, lgi.Gio

local client = {}

-- Lain socket client util submodule
function client:new(vals)
    vals = vals or {}
    vals.host = vals.host or 'localhost'
    vals.accept_regex = vals.accept_regex or '\n'
    vals.error_handler = vals.error_handler or function(_) end
    vals.waiting = false
    setmetatable(vals, self)
    self.__index = self
    return vals
end

function client:send(msg, callback)
    self:_connect()
    if not self.waiting then return end

    self.output:write(msg)
    table.insert(self.handlers, {msg, callback or function() end})
end

function client:_error(err)
    self.conn, self.fd, self.input, self.output = nil, nil, nil, nil
    self.error_handler(err)
    self.waiting = false
end

function client:_connect()
    if self.waiting then return end

    -- Set up a new connection
    local address
    if self.host:sub(1, 1) == '/' then
        -- It's a unix socket
        address = Gio.UnixSocketAddress.new(self.host)
    else
        -- Do a TCP connection
        address = Gio.NetworkAddress.new(self.host, self.port)
    end
    local socket_client = Gio.SocketClient()
    local err
    self.conn, err = socket_client:connect(address)

    if not self.conn then
        self:_error(err)
        return false
    end

    self.fd = self.conn:get_socket():get_fd()
    self.output = Gio.UnixOutputStream.new(self.fd)
    self.input = Gio.UnixInputStream.new(self.fd)

    self.handlers = {}

    local replies = {}
    local rpc_loop
    rpc_loop = function()
        self.waiting = self.conn:is_connected()
        if not self.waiting then return end
        self.input:read_bytes_async(4096, GLib.PRIORITY_DEFAULT, nil, function(result, reply)
            local bytes
            bytes, err = result:read_bytes_finish(reply)
            if bytes then
                local data = bytes:get_data()
                repeat
                    local accept = self:_accept_reply(data)
                    err = self:_error_reply(data)
                    if not (accept[1] or err[1]) then
                        table.insert(replies, data)
                        break
                    end

                    local idx = self._first_found(accept, err)
                    local matched = string.sub(data, idx[1], idx[2])

                    table.insert(replies, string.sub(data, 1, idx[1]-1))
                    local full = table.concat(replies, '')
                    replies = {}

                    local handler = self.handlers[1]
                    handler[2](not err, matched, full, handler[1])

                    table.remove(self.handlers, 1)

                    data = string.sub(data, idx[2] + 1)
                until false
                rpc_loop()
            else
                self:_error(err)
                replies = {}
            end
        end)
        print('exited loop')
    end
    print('started loop')
    rpc_loop()

    return self
end

function client:_accept_reply(buf)
    local i, j = buf:find(self.accept_regex)
    return {i, j}
end

function client:_error_reply(buf)
    if not self.error_refex then
        return {nil, nil}
    end
    local i, j = buf:find(self.error_regex)
    return {i, j}
end

client._first_found = function(a, b)
    if not b[1] then
        return a
    elseif not a[1] then
        return b
    elseif a[1] < b[2] then
        return a
    else
        return b
    end
end


--[[
-- Example on how to use this (standalone)

lgi = require 'lgi'
Gio = lgi.Gio
GLib = lgi.GLib

socket = require 'socket'
s = socket:new('heimdall', 8000, function(err) print('ERROR:', err) end)
s:send('GET /', function(success, reply) print(success, reply) end)

GLib.MainLoop():run()
--]]

return client
