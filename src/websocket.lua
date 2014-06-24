local frame = require'websocket.frame'

return {
  client = require'websocket.client',
  server = require'websocket.server',
  CONTINUATION = frame.CONTINUATION,
  TEXT = frame.TEXT,
  BINARY = frame.BINARY,
  CLOSE = frame.CLOSE,
  PING = frame.PING,
  PONG = frame.PONG
}
