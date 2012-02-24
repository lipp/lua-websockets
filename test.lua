local websockets = require'websockets'
local c = websockets.context{
   port = 8001,
--   interf = 'eth6',
   protocols = {
      logws = function(...) 
		 local args = {...}		 
		 print('LL',#args,type(args[1]),...)
		 for i,arg in ipairs(args) do
		    print('logws',i,arg,getmetatable(arg));
		 end
	      end
   }
}

while true do
   c:service(1000000)
end
c:destroy()
