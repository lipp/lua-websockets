return {
  client = require'websocket.client',
  server = require'websocket.server',
  CONTINUATION = 0,
  TEXT = 1,
  BINARY = 2,
  CLOSE = 8,
  PING = 9,
  PONG = 10
}
