local json = require "cjson"
local path = require "path"

local function readFile(p)
  p = path.fullpath(p)
  local f = assert(io.open(p, 'rb'))
  local d = f:read("*a")
  f:close()
  return d
end

local function readJson(p)
  return json.decode(readFile(p))
end

local function writeFile(p, data)
  local f = assert(io.open(p, "w+"))
  f:write(data)
  f:close()
end

local function writeJson(p, t)
  return writeFile(p, json.encode(t))
end

local function cleanDir(p, mask)
  if path.exists(p) then
    path.each(path.join(p, mask), function(P)
      path.remove(P)
    end)
  end
end

local function printReport(name, t)
  print("","Test case ID " .. name .. ":")
  for k, v in pairs(t) do
    print("","",k,"=>",v)
  end
  print("-------------")
end

local Utils = {} do
Utils.readFile  = readFile
Utils.readJson  = readJson
Utils.writeFile = writeFile
Utils.writeJson = writeJson
Utils.cleanDir  = cleanDir
end

local Autobahn = {} do

function Autobahn.cleanReports(p)
  cleanDir(p, "*.json")
  cleanDir(p, "*.html")
end

function Autobahn.readReport(p, agent)
  local p = path.join(p, "index.json")
  if not path.exists(p) then return end
  local t = readJson(p)
  t = t[agent] or {}
  return t
end

function Autobahn.printReports(name, t, dump)
  print(name .. ":")
  for k, v in pairs(t)do
    printReport(k, v, dump)
  end
end

function Autobahn.verifyReport(p, agent)
  local report = Autobahn.readReport(p, agent)
  if not report then return false end

  local behavior, behaviorClose = {}, {}
  local errors, warnings = {}, {}

  for name, result in pairs(report) do
    if result.behavior == 'FAILED' then
      errors[name] = result
    elseif result.behavior == 'WARNING' then
      warnings[name] = result
    elseif result.behavior == 'UNIMPLEMENTED' then
      warnings[name] = result
    elseif result.behaviorClose ~= 'OK' and result.behaviorClose ~= 'INFORMATIONAL' then
      warnings[name] = result
    end
  end

  if next(warnings) then
    Autobahn.printReports("WARNING", warnings)
  end

  if next(errors) then
    Autobahn.printReports("ERROR", errors)
    return false
  end

  return true
end

end

local Server = {} do

function Server.getCaseCount(URI)
  return URI .. "/getCaseCount"
end

function Server.runTestCase(URI, no, agent)
  return URI .. "/runCase?case=" .. no .. "&agent=" .. agent
end

function Server.updateReports(URI, agent)
  return URI .. "/updateReports?agent=" .. agent
end

end

Autobahn.Server = Server

Autobahn.Utils  = Utils

return Autobahn
