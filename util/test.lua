lgi = require 'lgi'
Gio = lgi.Gio
GLib = lgi.GLib

socket = require 'socket'

--[[
s = socket:new{
    port = 8000,
    accept_regex = '\r\n',
    error_handler = function(err) print('ERROR:', err) end}
s:send('GET /index.html HTTP/1.0\r\n\r\n', function(success, matched, rest) print(success, matched, rest) end)
]]--

s = socket:new{
    port=6600,
    accept_regex = 'OK\n',
    error_regex = 'ACK[^\n]*\n',
    error_handler=function(err) print('ERROR:', err) end}

s:send('status\n', function(success, matched, rest)
  print('STATUS success', success)
  print('STATUS rest', rest)
  print('STATUS matched', matched)
end)
s:send('password foo\n', function(success, matched, rest)
  print('PASSWORD success', success)
  print('PASSWORD rest', rest)
  print('PASSWORD matched', matched)
end)
s:send('currentsong\n', function(success, matched, rest)
  print('CURRENTSONG success', success)
  print('CURRENTSONG rest', rest)
  print('CURRENTSONG matched', matched)
end)
s:send('ping\n', function(success, matched, rest)
  print('PING success', success)
  print('PING rest', rest)
  print('PING matched', matched)
end)

--[[
s:send('close\n', function(success, matched, rest)
  print('CLOSE success', success)
  print('CLOSE rest', rest)
  print('CLOSE matched', matched)
end)
--]]

GLib.MainLoop():run()
