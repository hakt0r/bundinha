
@require 'bundinha/backend/backend'
@require 'bundinha/rpc'
{ APP,RPC } = @server

# ██████  ██████   ██████
# ██   ██ ██   ██ ██
# ██████  ██████  ██
# ██   ██ ██      ██
# ██   ██ ██       ██████

APP.handleRequest = (req,res)->
  new RPC.Web req, res
  .handle()

@server class RPC.Web extends RPC
  type:'$web'
  stdio:['$web','$web','$error']
  isWeb: true
  constructor:(htReq,htRes)->
    super null, USER:{}, GROUP:[], UID:0, COOKIE:false
    @htReq = htReq; @htRes = htRes; { @url, @method } = htReq
    @setHeader = htRes.setHeader.bind htRes
    @writeHead = htRes.writeHead.bind htRes
    @write     = htRes.write    .bind htRes
    @end       = htRes.end      .bind htRes
    console.debug 'request'.cyan, @url, @method

RPC.Web::execute = ->
  await ReadAuth @
  if @method is 'GET'
    for rule in RPC.match
      continue unless m = rule.expr.exec @url
      @cmd = [rule.key,m.slice 2].flat(); @parsedUrl = m
      break
    if not @cmd and @url.match /^\/api\//
      @cmd = @url.replace(/^\/api\//,'').split()
    console.debug 'GET', @url, @cmd
    return APP.fileRequest @htReq, @htRes unless @cmd # fallback to fileRequest
  else if @method is 'POST' and @url is '/api'
    @cmd = await @handlePostBody()
  else return APP.httpError @, 501, 'Unimplemented'
  console.debug 'request:web:execute'.cyan, @url, @cmd
  await RPC::execute.call @

RPC.Web::respond = (data)->
  return if @ended
  @dbg 'respond', data
  @setHeader 'Content-Type', 'text/json'
  if @fail
    @data.error = @data.error.map (i)-> $colors.strip i
    @statusCode = if ( c = @failCode )? then c else 501
    @dbg 'error', @data.error
  else
    delete data.error
    @statusCode = 200
  @writeHead @statusCode
  @end JSON.stringify data

RPC.Web::redirect = (code,url)->
  @ended = true
  unless url
    url = code
    code = 302
  @writeHead @statusCode = code,
    Location: url
  @end()

RPC.Web::handlePostBody = ->
  @stream = undefined
  switch (@htReq.headers['content-encoding'] or 'raw').toLowerCase()
    when 'deflate' then @htReq.pipe @stream = zlib.createInflate()
    when 'gzip'    then @htReq.pipe @stream = zlib.createGunzip()
    when 'raw'     then @stream = @htReq; @stream.length = @htReq.headers['content-length']
    else return @error 'Request without data'
  unless Array.isArray body = JSON.parse await @readStream @stream
    throw new Error 'Request not an array'
  body

RPC.Web::readStream = (stream)-> new Promise (resolve,reject)->
  body = []
  stream.on 'data', (chunk)-> body.push chunk
  stream.on 'end', -> resolve Buffer.concat(body).toString('utf8')

#  ██████ ██      ██ ███████ ███    ██ ████████
# ██      ██      ██ ██      ████   ██    ██
# ██      ██      ██ █████   ██ ██  ██    ██
# ██      ██      ██ ██      ██  ██ ██    ██
#  ██████ ███████ ██ ███████ ██   ████    ██

@client.CALL = @client.AJAX = (call,data)-> new Promise (resolve,reject)->
  xhr = new XMLHttpRequest
  xhr.open ( if data then 'POST' else 'GET' ), '/api'
  if data
    xhr.setRequestHeader "Content-Type","application/json"
    xhr.send JSON.stringify [call,data]
  else xhr.send()
  xhr.onload = ->
    try
      result = JSON.parse @response
      unless result.error
        resolve result
      else reject result.error
    catch e
      if @status isnt 200
        l = location; p = l.protocol; h = l.host
        addr = p + '//' + h + '/api'
        reject """
        <div class=error>
          <h1>Network Error:</h1>
          <div><b>#{@status}</b> <i>#{@statusText}</i></div>
          <div>Could not connect to the service at #{addr}.</div>
        </div>"""
        return
      reject """
      <div class=error>
        <h1>JSON Error:</h1>
        <div>#{e.toString()}</div>
        <div>#{@response}.</div>
      </div>"""
  return

# ██     ██ ███████ ██████  ███████ ██████  ██    ██
# ██     ██ ██      ██   ██ ██      ██   ██ ██    ██
# ██  █  ██ █████   ██████  ███████ ██████  ██    ██
# ██ ███ ██ ██      ██   ██      ██ ██   ██  ██  ██
#  ███ ███  ███████ ██████  ███████ ██   ██   ████

APP.startServer = ->
  APP.compileExpressions()
  if 'http' is APP.protocol
    await APP.getCerts(true) if APP.getCerts
    APP.server = require('http').createServer APP.handleRequest
    APP.Protocol = '::http'
  else
    APP.Protocol = ':https'
    await APP.getCerts(true) if APP.getCerts
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
  WebSock?.init()
  _addr_ = if APP.addr is '0.0.0.0' then null else APP.addr
  new Promise (resolve)-> APP.server.listen APP.port, _addr_, ->
    console.log APP.Protocol, 'online'.green, APP.addr.red + ':' + APP.port.toString().magenta
    return resolve() unless APP.chgid
    # groups = $cp.execSync('id -Gn '+APP.chgid).toString().trim().split(' ') #.map (i)-> parseInt i
    console.log APP.Protocol, 'dropping privileges'.green, APP.chgid.toString().yellow #, groups.join ' '
    process.setgid 'sudo' # APP.chgid
    process.setuid APP.chgid
    # process.setgroups groups
    return resolve()

APP.compileExpressions = ->
  out = []
  for expr in Array.from RPC.match
    func = RPC.byId[expr]
    continue unless m = expr.match /^\/(.*?)\/([gimy])?$/
    rex = new RegExp m[1], m[2] || ''
    out.push expr:rex, func:func, key:expr
  RPC.match = out
  return

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
