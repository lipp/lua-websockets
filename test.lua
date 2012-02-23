local websockets = require'websockets'
local c = websockets.context{
   port = 8001,
   interf = 'lo',
   protocols = {
      logws = print
   }
}

context:destroy()
