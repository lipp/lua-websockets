local websockets = require'websockets'
local c = websockets.context{
   port = 8001,
--   interf = 'eth6',
   protocols = {
      logws = function(...) 
		 local args = {...}		 
		 for i,arg in pairs(args) do
		    print('logws',i,arg);
		 end
	      end
   }
}

while true do
   c:service(1000000)
end
c:destroy()
