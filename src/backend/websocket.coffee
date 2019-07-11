
# ██     ██ ███████ ██████  ███████  ██████   ██████ ██   ██ ███████ ████████
# ██     ██ ██      ██   ██ ██      ██    ██ ██      ██  ██  ██         ██
# ██  █  ██ █████   ██████  ███████ ██    ██ ██      █████   █████      ██
# ██ ███ ██ ██      ██   ██      ██ ██    ██ ██      ██  ██  ██         ██
#  ███ ███  ███████ ██████  ███████  ██████   ██████ ██   ██ ███████    ██

@npm 'ws'
@shared WebSockets:true
@require 'bundinha/backend/web'
@require 'bundinha/rpc'; { RPC } = @server

@server class RPC.WebSock extends RPC
  type:'$ws'
  stdio:['$web','$web','$error']
  isWebsocket: true
  isWeb: true
  constructor:(msg,parent)->
    super msg.slice(1), parent
    Object.assign @, rid:msg[0]
    { UID, USER, COOKIE, GROUP } = @parent
  # log:-> try @send
  respond: (data)->
    unless data
      @err 'Empty response'
      return @SOCK.send JSON.stringify [@rid,false,'NO_DATA']
    if data.error and data.error.length > 0
      data.error = data.error.map (i)=>
        @err i
        @err i.stack
        i.toString()
      return @SOCK.send JSON.stringify [@rid,null,data.error]
    return @SOCK.send JSON.stringify [@rid,data]

# ███████ ███████ ██████  ██    ██ ███████ ██████
# ██      ██      ██   ██ ██    ██ ██      ██   ██
# ███████ █████   ██████  ██    ██ █████   ██████
#      ██ ██      ██   ██  ██  ██  ██      ██   ██
# ███████ ███████ ██   ██   ████   ███████ ██   ██

@server.init = ->
  WebSock.ID$ = me =
    nextId:0
    freeId:[]
    get:-> me.freeId.shift() || me.nextId++
    del:(id)-> me.freeId.push()
  return

@server class WebSock
  constructor:(ws,req)->
    Object.assign ws, WebSock::
    ws.uid = WebSock.ID$.get()
    ws.req = req
    ws.reqid = 0
    ws.pending = {}
    ws.on 'message', WebSock::handleMessage.bind ws
    ws.on 'close', ->
      WebSock.ID$.del ws.uid
      WebSock.server.emit 'close', ws
    return ws

WebSock::handleMessage = (msg)->
  switch msg[0]
    when '[' then @handleRequest  msg
    when '@' then @handleResponse msg
  return

WebSock::handleRequest = (msg)->
  new RPC.WebSock JSON.parse(msg), Object.assign {},
    COOKIE: @req.COOKIE
    USER:   @req.USER
    GROUP:  @req.GROUP
    UID:    @req.UID
    SOCK:   @
  .handle()

WebSock::query = (call,data)-> new Promise (resolve,reject)=>
  @pending[id = @reqid++] = sock:@, resolve:resolve, reject:reject, call:call, data:data
  try @send '@' + JSON.stringify [id,call,data] catch e then reject e

WebSock::handleResponse = (msg)->
  [id,data,error] = JSON.parse msg.substring 1
  unless req = @pending[id]
    console.error 'Invalid response:', msg
    throw new Error 'Invalid response'
  delete @pending[req.id]
  return req.reject [req,error].flat() if error
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
    try
      request.htReq = request
      await RequireAuth request
    catch error then console.log error; socket.destroy()
    wss.handleUpgrade request, socket, head, (ws)-> wss.emit 'connection', ws, request
    return
  wss.on 'connection', (s,r)-> s = new WebSock s,r
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

@phase 'build', =>
  @client.LoginResult = (result)->
    $$.GROUP = result.groups
    return WebSock.connect() if result.success
    result.success || false
  @client.CheckLoginCookieWasSuccessful = (result)->
    $$.GROUP = result.groups
    return WebSock.connect() if result.success
    result.success || false
  return

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
    if handler = @client.WebSock.messageHandler[call]
      req = new WebSock.Request  id
      res = new WebSock.Response id
      handler data, req, res
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
  return req.reject [req,error].flat() if ( not req? ) or error
  req.resolve data
  return

WebSock.connect = (old)-> new Promise (resolve,reject)->
  l = location; p = l.protocol; h = l.host
  addr = p.replace('http','ws') + '//' + h + '/api'
  console.log 'ws', 'connect', addr
  new WebSock addr,resolve,reject,old

WebSock::query = (call,data)-> new Promise (resolve,reject)=>
  @pending[id = @reqid++] = resolve:resolve, reject:reject, call:call, data:data
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

class WebSock.Request
  src: '$websocket'
  isWebsocket: true
  isFrontend: true
  constructor:->

class WebSock.Response
  src: '$websocket'
  isWebsocket: true
  isFrontend: true
  constructor:(@id)->
  json  : (data)-> CALL.sock.send '@' + JSON.stringify [id,data,null]
  error : (data)-> CALL.sock.send '@' + JSON.stringify [id,null,data]

# ██████  ██    ██ ██████  ███████ ██    ██ ██████
# ██   ██ ██    ██ ██   ██ ██      ██    ██ ██   ██
# ██████  ██    ██ ██████  ███████ ██    ██ ██████
# ██      ██    ██ ██   ██      ██ ██    ██ ██   ██
# ██       ██████  ██████  ███████  ██████  ██████

@client.WebSock.messageHandler = {}

WebSock.defineMessage = (call,shared,client,server)=>
  @client.WebSock.messageHandler[call] = client || shared
  @private call, server || shared

WebSock.defineMessage 'sub', (opts,req,res)->
  subs = req.sock.sub || req.sock.sub = []
  for k in opts
    subs.push k
    unless list = PubSub.rsub.get(k)
      list = {}
      list[k] = req.sock
      PubSub.rsub.set k, list
    else list[k] = req.sock
  return

WebSock.defineMessage 'pub', (opts,req,res)->
  pubs = req.sock.pub || req.sock.pub = []
  for k in opts
    pubs.push k
    unless list = PubSub.rpub.get(k)
      list = {}
      list[k] = req.sock
      PubSub.rpub.set k, list
    else list[k] = req.sock
  return

@shared class PubSub
  @init:->
    PubSub.lsub = new Set
    PubSub.lpub = new Set
    PubSub.rpub = new Map
    PubSub.rsub = new Map
  @sub:(key)->
    PubSub.lsub.add key
    @broadcast 'sub', key
  @pub:(key,list...)->
    PubSub.lpub.add key
    @subcast 'pub', list.wrapArray().length
