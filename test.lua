local websockets = require'websockets'
local c = websockets.context{
   port = 8001,
--   interf = 'eth6',
   protocols = {
      logws = print
   }
}

c:destroy()
