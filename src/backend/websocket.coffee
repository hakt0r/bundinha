
@npm 'ws'
@require 'bundinha/backend/web'
@shared WebSockets:true

# ██     ██ ███████ ██████  ███████  ██████   ██████ ██   ██ ███████ ████████
# ██     ██ ██      ██   ██ ██      ██    ██ ██      ██  ██  ██         ██
# ██  █  ██ █████   ██████  ███████ ██    ██ ██      █████   █████      ██
# ██ ███ ██ ██      ██   ██      ██ ██    ██ ██      ██  ██  ██         ██
#  ███ ███  ███████ ██████  ███████  ██████   ██████ ██   ██ ███████    ██

@server.APP.initWebSockets = ->
  wss = new ( require 'ws' ).Server noServer:true
  APP.server.on 'upgrade', (request, socket, head)->
    RequireAuth request
    .then -> wss.handleUpgrade request, socket, head, (ws)->
      wss.emit 'connection', ws, request
    .catch (error)->
      console.log error
      socket.destroy()
    return
  wss.on 'connection', (ws,connReq) ->
    ws.on 'message', (body) ->
      try
        [ id, call, args ] = JSON.parse body
        json = (data)-> data.id = id; ws.send JSON.stringify data
        error = (error)-> ws.send JSON.stringify error:error, id:id
        req = id:id, USER:connReq.USER, ID:connReq.ID, COOKIE:connReq.COOKIE
        res = id:id, json:json, error:error, setHeader:(->)
        return fn.call res, args, req, res if fn = APP.public[call]
        if false isnt need_group = APP.group[call]
          RequireGroup req, need_group
        return fn.call res, args, req, res if fn = APP.private[call]
      catch error
        console.log error
        try res.error error
  console.log APP.Protocol, 'websockets'.green

@client.init = ->
  $$.on 'logout', ->
    try CALL.socket.close()
    CALL.socket = false
    return
  return

@client.CALL = (call,data)->
  return WebSocketRequest call, data if CALL.socket
  return AJAX call, data

@client.CheckLoginCookieWasSuccessful = (result)->
  $$.GROUP = result.groups
  return ConnectWebSocket() if result.success
  result.success || false

@client.LoginResult = (result)->
  $$.GROUP = result.groups
  return ConnectWebSocket() if result.success
  result.success || false

@client.ConnectWebSocket = -> new Promise (resolve,reject)->
  WebSocketRequest.id      = WebSocketRequest.id || 0
  WebSocketRequest.request = WebSocketRequest.request || {}
  l = location; p = l.protocol; h = l.host
  addr = p.replace('http','ws') + '//' + h + '/api'
  console.log 'ws', 'connect', addr
  socket = new WebSocket addr
  socket.addEventListener 'error', ->
    CALL.socket = null
    NotificationToast.show 1000, 'offline'
  socket.addEventListener 'open', ->
    console.log 'ws', 'connected'
    CALL.socket = socket
    resolve socket
  socket.addEventListener 'message', (msg)->
    data = JSON.parse msg.data
    req = WebSocketRequest.request[data.id]
    req.reject  data.error if data.error
    req.resolve data
    delete WebSocketRequest.request[data.id]
  socket.addEventListener 'error', reject

@client.WebSocketRequest = (call,data)-> new Promise (resolve,reject)->
  WebSocketRequest.request[id = WebSocketRequest.id++] = resolve:resolve, reject:reject
  if CALL.socket.readyState is CALL.socket.OPEN
    CALL.socket.send JSON.stringify [id,call,data]
    return
  try
    await ConnectWebSocket()
    return unless CALL.socket.readyState is CALL.socket.OPEN
    CALL.socket.send JSON.stringify [id,call,data]
    return
  LoginForm()
  NotificationToast.show 1000, """
  <div class=error>
    <h1>Connection Error:</h1>
    <div>Could not connect to the WebSocket service at #{CALL.socket.url}.</div>
  </div>"""
  return
