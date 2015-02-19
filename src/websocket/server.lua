return setmetatable({},{__index = function(self, name)
  local backend = require("websocket.server_" .. name)
  self[name] = backend
  return backend
end})
