return setmetatable({},{__index = function(self, name)
  if name == 'new' then name = 'sync' end
  local backend = require("websocket.client_" .. name)
  self[name] = backend
  if name == 'sync' then self.new = backend end
  return backend
end})
