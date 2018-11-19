
@require 'bundinha/backend/backend'

#  ██████ ██      ██ ███████ ███    ██ ████████
# ██      ██      ██ ██      ████   ██    ██
# ██      ██      ██ █████   ██ ██  ██    ██
# ██      ██      ██ ██      ██  ██ ██    ██
#  ██████ ███████ ██ ███████ ██   ████    ██

@client.CALL = @client.AJAX = (call,data)->
  new Promise (resolve,reject)->
    xhr = new XMLHttpRequest
    xhr.open ( if data then 'POST' else 'GET' ), '/api'
    if data
      xhr.setRequestHeader "Content-Type","application/json"
      xhr.send JSON.stringify [call,data]
    else xhr.send()
    xhr.onload = ->
      try result = JSON.parse @response
      catch e then reject "JSON Error: " + e
      unless result.error
           resolve result
      else reject result.error
    null

# ██     ██ ███████ ██████  ███████ ██████  ██    ██
# ██     ██ ██      ██   ██ ██      ██   ██ ██    ██
# ██  █  ██ █████   ██████  ███████ ██████  ██    ██
# ██ ███ ██ ██      ██   ██      ██ ██   ██  ██  ██
#  ███ ███  ███████ ██████  ███████ ██   ██   ████

{ APP } = @server

APP.startServer = ->
  if 'http' is APP.protocol
    APP.server = require('http').createServer APP.handleRequest
    APP.Protocol = '::http'
  else
    APP.Protocol = ':https'
    if APP.getCerts then do APP.getCerts
    keyPath = $path.join ConfigDir, 'host.key'
    crtPath = $path.join ConfigDir, 'host.crt'
    hasKey = $fs.existsSync keyPath
    hasCrt = $fs.existsSync crtPath
    unless hasKey and hasCrt
      console.log 'SSL'.red, 'HOST crt missing:', crtPath
      console.log 'SSL'.red, 'HOST key missing:', keyPath
      process.exit 1
    APP.httpsContext = require('tls').createSecureContext
      key: $fs.readFileSync keyPath
      cert: $fs.readFileSync crtPath
    options = SNICallback:(servername,cb)-> cb null, APP.httpsContext
    APP.server = require('https').createServer options, APP.handleRequest
  do APP.initWebSockets if WebSockets?
  _addr_ = if APP.addr is '0.0.0.0' then null else APP.addr
  new Promise (resolve)-> APP.server.listen APP.port, _addr_, ->
    console.log APP.Protocol, 'online'.green, APP.addr.red + ':' + APP.port.toString().magenta
    return resolve() unless APP.chgid
    console.log APP.Protocol, 'dropping privileges'.green, APP.chgid.toString().yellow
    process.setgid APP.chgid
    process.setuid APP.chgid
    return resolve()

@server.init = ->
  out = []
  for expr, func of APP.get
    m = expr.match /\/(.*?)\/([gimy])?$/
    expr = new RegExp m[1], m[2] || ''
    out.push expr:expr, func:func
  APP.get = out
  return

APP.handleRequest = (req,res)->
  console.debug 'request'.cyan, req.url
  if req.method is 'POST' and req.url is '/api'
    res.json = APP.apiResponse
    try await APP.apiRequest req, res
    catch error
      res.json error:error.toString()
  else if req.method is 'GET'
    for rule in APP.get
      continue unless m = rule.expr.exec req.url
      req.parsedUrl = m
      return rule.func.call res, req, res
    # fallback to fileRequest
    APP.fileRequest req, res
  else APP.errorResponse 501, 'Uninplemented'

APP.readStream = (stream)-> new Promise (resolve,reject)->
  body = []
  stream.on 'data', (chunk)-> body.push chunk
  stream.on 'end', -> resolve Buffer.concat(body).toString('utf8')

#  █████       ██  █████  ██   ██
# ██   ██      ██ ██   ██  ██ ██
# ███████      ██ ███████   ███
# ██   ██ ██   ██ ██   ██  ██ ██
# ██   ██  █████  ██   ██ ██   ██

APP.apiResponse = (data)->
  @setHeader 'Content-Type', 'text/json'
  @statusCode = 200
  @end JSON.stringify data

APP.apiRequest = (req,res)->
  stream = undefined
  switch (req.headers['content-encoding'] or 'raw').toLowerCase()
    when 'deflate' then req.pipe stream = zlib.createInflate()
    when 'gzip'    then req.pipe stream = zlib.createGunzip()
    when 'raw'     then stream = req; stream.length = req.headers['content-length']
    else return res.json error:'Request without data'

  body = JSON.parse await @readStream stream

  unless Array.isArray body
    throw new Error 'Request not an array'

  [ call, args ] = body
  # reply to public api-requests

  if fn = @public[call]
    console.debug @Protocol.yellow, "call".green, call, args, '$public'
    return fn.call res, args, req, res

  # reply to private api-requests only with valid auth
  value = await RequireAuth req

  if false isnt need_group = @group[call]
    RequireGroup req, need_group

  unless fn = @private[call]
    throw new Error 'Command not found: ' + call

  console.debug @Protocol.yellow, "call".green, req.ID, call, args
  fn.call res, args, req, res

# ███████ ██ ██      ███████
# ██      ██ ██      ██
# █████   ██ ██      █████
# ██      ██ ██      ██
# ██      ██ ███████ ███████

@shared MIME: class MIME
  @typeOf:(file)->
    MIME.type[file.split('.').pop()] || 'application/octet-stream'
  @type:
    avi:  'video/avi'
    css:  'text/css'
    html: 'text/html'
    js:   'text/javascript'
    mkv:  'video/x-matroska'
    mp4:  'video/mp4'
    oga:  'audio/ogg',
    ogg:  'application/ogg',
    ogv:  'video/ogg',
    svg:  'image/svg+xml'
    txt:  'text/plain',
    wav:  'audio/x-wav',
    webm: 'video/webm'

APP.resolveWebFile = (file)->
  $path.join WebDir, file

APP.errorResponse = (res,file,status,e)->
  console.log APP.Protocol.red, file.yellow
  console.log   ' ', e.message if e.message
  console.debug ' ', e.trace
  res.writeHead status
  res.end status + ': ' + e

APP.fileRequest = (req,res)->
  file = req.url
  file = '/index.html' if file is '/'
  file = '/index.html' if file is '/app'
  mime = MIME.typeOf file
  file = APP.resolveWebFile file
  return APP.errorResponse res, file, 404, 'File not Found' if false is file
  console.debug 'static-get'.cyan, file, mime
  try stat = await $fs.stat$ file
  catch e then return APP.errorResponse res, file, 404, 'File not Found'
  return APP.errorResponse res, file, 404, 'File not Found' if stat.isDirectory()
  return APP.fileRequestChunked req,res,file,mime,stat      if req.headers.range
  res.writeHead 200,
    "Accept-Ranges"  : "bytes"
    "Content-Length" : stat.size
    "Content-Type"   : mime
  $fs.createReadStream(file).pipe res
  null

APP.fileRequestChunked = (req,res,file,mime,stat)->
  parts = req.headers.range.replace(/bytes=/, "").split("-")
  [ partialstart, partialend ] = parts
  total = stat.size
  start = parseInt partialstart, 10
  end = if partialend then parseInt partialend, 10 else total - 1
  end = Math.min end, start + 4 * 1024 * 1024
  chunksize = end - start
  console.debug APP.Protocol.green, file.yellow, start, chunksize, total, stat.size
  res.writeHead 206,
    "Accept-Ranges"     : "bytes"
    "Content-Length"    : chunksize + 1
    "Content-Range"     : "bytes " + start + "-" + end + "/" + total
    "Content-Type"      : mime
    "Connection"        : 'keep-alive'
    "Transfer-Encoding" : 'chunked'
  $fs.createReadStream(file,start:start,end:end).pipe(res)
