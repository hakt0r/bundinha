
# ██     ██ ███████ ██████  ███████  ██████   ██████ ██   ██ ███████ ████████
# ██     ██ ██      ██   ██ ██      ██    ██ ██      ██  ██  ██         ██
# ██  █  ██ █████   ██████  ███████ ██    ██ ██      █████   █████      ██
# ██ ███ ██ ██      ██   ██      ██ ██    ██ ██      ██  ██  ██         ██
#  ███ ███  ███████ ██████  ███████  ██████   ██████ ██   ██ ███████    ██

@npm 'ws'
@require 'bundinha/backend/web'
@shared WebSockets:true

# ███████ ███████ ██████  ██    ██ ███████ ██████
# ██      ██      ██   ██ ██    ██ ██      ██   ██
# ███████ █████   ██████  ██    ██ █████   ██████
#      ██ ██      ██   ██  ██  ██  ██      ██   ██
# ███████ ███████ ██   ██   ████   ███████ ██   ██

@server class WebSock
  constructor:(ws,req)->
    Object.assign ws, WebSock::
    ws.req = req
    ws.reqid = 0
    ws.pending = {}
    ws.on 'message', WebSock::handleMessage.bind ws
    return ws

WebSock::handleMessage = (msg)->
  switch msg[0]
    when '[' then @handleRequest  msg
    when '@' then @handleResponse msg
  return

WebSock::handleRequest = (msg)->
  try
    [ id, call, args ] = JSON.parse msg
    json  = (data)  => @send JSON.stringify [id,data]
    error = (error) => @send JSON.stringify [id,null,error]
    req = id:id, USER:@req.USER, ID:@req.ID, COOKIE:@req.COOKIE
    res = id:id, json:json, error:error, setHeader:(->)
    return fn.call res, args, req, res if fn = APP.public[call]
    if false isnt need_group = APP.group[call]
      RequireGroup req, need_group
    return fn.call res, args, req, res if fn = APP.private[call]
  catch error
    console.error '::ws::', error
    try res.error error

WebSock::query = (call,data)-> new Promise (resolve,reject)=>
  @pending[id = @reqid++] = sock:@, resolve:resolve, reject:reject, call:call, data:data
  try @send '@' + JSON.stringify [id,call,data] catch e then reject e

WebSock::handleResponse = (msg)->
  [id,data,error] = JSON.parse msg.substring 1
  unless req = @pending[id]
    return console.error 'invalid response', msg
  delete @pending[data.id]
  return req.reject error if error
  req.resolve data
  return

WebSock.broadcast = (call,data)->
  WebSock.server.clients.forEach (sock)->
    sock.query call, data
    return
  return

WebSock.init = ->
  WebSock.server = wss = new ( require 'ws' ).Server noServer:true
  APP.server.on 'upgrade', (request, socket, head)->
    try await RequireAuth request
    catch error
      console.log error
      socket.destroy()
    wss.handleUpgrade request, socket, head, (ws)-> wss.emit 'connection', ws, request
    return
  wss.on 'connection', (s,r)-> new WebSock s,r
  console.log APP.Protocol, 'websockets'.green

#  ██████ ██      ██ ███████ ███    ██ ████████
# ██      ██      ██ ██      ████   ██    ██
# ██      ██      ██ █████   ██ ██  ██    ██
# ██      ██      ██ ██      ██  ██ ██    ██
#  ██████ ███████ ██ ███████ ██   ████    ██

@client.init = ->
  $$.on 'logout', ->
    try CALL.socket.close()
    try CALL.socket = false
    return
  return

@client.CALL = (call,data)->
  return CALL.socket.query call, data if CALL.socket
  return AJAX call, data

@client.CheckLoginCookieWasSuccessful = (result)->
  $$.GROUP = result.groups
  return WebSock.connect() if result.success
  result.success || false

@client.LoginResult = (result)->
  $$.GROUP = result.groups
  return WebSock.connect() if result.success
  result.success || false

@client class WebSock
  constructor:(addr,resolve,reject,opts={})->
    ws = new WebSocket addr
    Object.assign ws, WebSock::
    Object.assign ws, opts
    ws.reqid   = ws.reqid   || 0
    ws.pending = ws.pending || {}
    ws.addEventListener 'error', ->
      CALL.socket = null
      NotificationToast.show 1000, 'offline'
    ws.addEventListener 'open', ->
      console.log 'ws', 'connected'
      CALL.socket = ws
      resolve ws
    ws.addEventListener 'message', (msg)->
      switch msg.data[0]
        when '@' then ws.handleRequest  msg.data
        when '[' then ws.handleResponse msg.data
      return
    ws.addEventListener 'error', reject
    return ws

WebSock::handleRequest = (msg)->
  try
    [id,call,data] = JSON.parse msg.substring 1
    keys = Object.keys data
    $$.emit call, data:data, respond:(result)=>
      @send '@' + JSON.stringify [id,result]
  catch error
    console.error '%c--------------------------------------------------------------', 'color:red'
    console.error error
    console.error '%cserver:call: %c%s', 'color:red', 'color:white', msg.data
    console.error '%c--------------------------------------------------------------', 'color:red'

WebSock::handleResponse = (msg)->
  [id,data,error] = JSON.parse msg
  req = @pending[id]; delete @pending[id]
  req.reject  error if error
  req.resolve data
  return

WebSock.connect = (old)-> new Promise (resolve,reject)->
  l = location; p = l.protocol; h = l.host
  addr = p.replace('http','ws') + '//' + h + '/api'
  console.log 'ws', 'connect', addr
  new WebSock addr,resolve,reject,old

WebSock::query = (call,data)-> new Promise (resolve,reject)=>
  @pending[id = @reqid++] = resolve:resolve, reject:reject
  if @readyState is @OPEN
    @send JSON.stringify [id,call,data]
    return
  try
    await WebSock.connect
      pending : @pending
      reqid   : @reqid
    return unless CALL.socket.readyState is @OPEN
    CALL.socket.send JSON.stringify [id,call,data]
    return
  LoginForm()
  NotificationToast.show 1000, """
  <div class=error>
    <h1>Connection Error:</h1>
    <div>Could not connect to the WebSocket service at #{CALL.socket.url}.</div>
  </div>"""
  return
