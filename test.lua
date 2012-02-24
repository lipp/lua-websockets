local websockets = require'websockets'
local c = websockets.context{
   port = 8001,
--   interf = 'eth6',
   protocols = {
      logws = function(...) print(...); return 3; end
   }
}

c:fork_service_loop()
c:destroy()
