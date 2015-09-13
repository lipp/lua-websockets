var WebSocketServer = require('ws').Server;
var wss = new WebSocketServer({ port: parseInt(process.argv[2]) });

wss.on('connection', function connection(ws) {
  ws.on('message', function incoming(message, flags) {
  	ws.send(message, flags);
  });
});
