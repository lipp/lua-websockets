#!/usr/bin/env lua
local frame = require'websocket.frame'
local socket = require'socket'
local encode = frame.encode
local TEXT = frame.TEXT
local s = string.rep('abc',100)

local tests = {
  ['---WITH XOR---'] = true,
  ['---WITHOUT XOR---'] = false
}

for name,do_xor in pairs(tests) do
  print(name)
  local n = 1000000
  local t1 = socket.gettime()
  for i=1,n do
    encode(s,TEXT,do_xor)
  end
  local dt = socket.gettime() - t1
  print('n=',n)
  print('dt=',dt)
  print('ops/sec=',n/dt)
  print('microsec/op=',1000000*dt/n)
end
