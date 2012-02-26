local websockets = require'websockets'
local c = websockets.context{
   port = 8001,
   protocols = {{
                   name = "http-only",
                   callback = print
             }}
}

while true do
   c:service(1000000)
end
c:destroy()
