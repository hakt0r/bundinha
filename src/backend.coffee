# ██ ███    ██ ██ ████████
# ██ ████   ██ ██    ██
# ██ ██ ██  ██ ██    ██
# ██ ██  ██ ██ ██    ██
# ██ ██   ████ ██    ██

@serverHeader = []
@serverHeader.push ->
  require 'colors'
  global.$$     = global
  $$.$path      = require 'path'
  $$.$fs        = require 'fs'
  $$.isClient   = not ( $$.isServer = yes )
  $$.debug      = no
  $$.RootDir    = process.env.APP  || __dirname
  $$.WebDir     = process.env.HTML || $path.join RootDir, 'html'
  $$.ConfigDir  = process.env.CONF || $path.join $path.dirname(RootDir), 'config'
  $$.AppPackage = JSON.parse $fs.readFileSync ($path.join RootDir, 'package.json' ), 'utf8'
  return
@serverHeader.push @arrayTools
# @serverHeader.push @miqro

$server = @server
  preinit:->
    do APP.loadDependencies
    do APP.readEnv
    for name, func of APP.command when process.argv.includes name
      func()
    return
  init:->
    await APP.preinit()
    console.debug = (->) unless DEBUG
    do APP.splash
    await do APP.startServer
    do APP.initConfig
    do APP.initDB
    return

$server.APP = class $app

$app.fromSource = no
$app.require = @requireScope

$app.loadDependencies = ->
  for dep in @require
    if Array.isArray dep
      $$['$' + dep[0]] = require dep[1]
    else $$['$' + dep] = require dep
  return

$app.readEnv = ->
  $$.DEBUG     =  process.env.DEBUG || false
  APP.chgid    =  process.env.CHGID || false
  APP.port     =  process.env.PORT  || 9999
  APP.addr     =  process.env.ADDR  || '127.0.0.1'
  APP.protocol =  process.env.PROTO || 'https'
  return

$app.splash = ->
  console.log '------------------------------------'
  console.log ' ',
    AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
    '['+ 'bundinha'.yellow + '/'.gray + AppPackage.bundinha.gray +
    ( if APP.fromSource then '/dev'.red else '/rel'.green ) + ']'
  console.log '------------------------------------'
  console.log 'RootDir  '.yellow, RootDir.green
  console.log 'WebDir   '.yellow, WebDir.green
  console.log 'ConfigDir'.yellow, ConfigDir.green
  return

$app.initConfig = ->
  unless $fs.existsSync confDir = $path.join ConfigDir
    try $fs.mkdirSync $path.join ConfigDir
    catch e
      console.log 'config', ConfigDir.red, e.message
      process.exit 1
  @configKeys = Object.keys @defaultConfig
  if $fs.existsSync p = $path.join ConfigDir, AppPackage.name + '.json'
    Object.assign $$, config = JSON.parse $fs.readFileSync p, 'utf8'
    update = no
    for key, value of @defaultConfig when not $$[key]?
      update = yes
      $$[key] = value
      console.debug 'config'.yellow, key, JSON.stringify value
    @configKeys = Object.keys(config).concat(@configKeys).unique
    do @writeConfig if update is yes
  else $fs.writeFileSync p, JSON.stringify @defaultConfig
  console.debug 'config', ConfigDir.green, @configKeys.join(' ').gray

$app.writeConfig = ->
  p = $path.join ConfigDir, AppPackage.name + '.json'
  $fs.writeFileSync p, JSON.stringify (
    o = {}
    o[k] = $$[k] for k in @configKeys
    o ), null, 2

$app.initDB = ->
  for name, opts of APP.db
    APP[name] = $level $path.join ConfigDir, name + '.db'
    console.log '::::db', ':' + name.bold
  console.log '::::db', 'ready'.green

# ██     ██ ███████ ██████  ███████ ██████  ██    ██
# ██     ██ ██      ██   ██ ██      ██   ██ ██    ██
# ██  █  ██ █████   ██████  ███████ ██████  ██    ██
# ██ ███ ██ ██      ██   ██      ██ ██   ██  ██  ██
#  ███ ███  ███████ ██████  ███████ ██   ██   ████

$app.startServer = ->

  if 'http' is APP.protocol
    APP.Protocol = '::http'
    APP.server = require('http')
    .createServer APP.web

  else
    hasKey = $fs.existsSync keyPath = $path.join ConfigDir, 'host.key'
    hasCrt = $fs.existsSync crtPath = $path.join ConfigDir, 'host.crt'

    unless hasKey and hasCrt
      console.log 'SSL'.red, 'HOST crt missing:', crtPath
      console.log 'SSL'.red, 'HOST key missing:', keyPath
      process.exit 1

    APP.Protocol = ':https'
    options =
      key:  $fs.readFileSync keyPath
      cert: $fs.readFileSync crtPath

    APP.server = require('https')
    .createServer options, APP.handleRequest

  do APP.initWebSockets if WebSockets?
  new Promise (resolve)-> APP.server.listen APP.port, APP.addr, ->
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

$app.handleRequest = (req,res)->
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

$app.readStream = (stream)-> new Promise (resolve,reject)->
  body = []
  stream.on 'data', (chunk)-> body.push chunk
  stream.on 'end', -> resolve Buffer.concat(body).toString('utf8')

#  █████       ██  █████  ██   ██
# ██   ██      ██ ██   ██  ██ ██
# ███████      ██ ███████   ███
# ██   ██ ██   ██ ██   ██  ██ ██
# ██   ██  █████  ██   ██ ██   ██

$app.apiResponse = (data)->
  @setHeader 'Content-Type', 'text/json'
  @statusCode = 200
  @end JSON.stringify data

$app.apiRequest = (req,res)->
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

$app.resolveWebFile = (file)->
  $path.join WebDir, file

$app.errorResponse = (res,file,status,e)->
  console.log APP.Protocol.red, file.yellow
  console.log   ' ', e.message if e.message
  console.debug ' ', e.trace
  res.writeHead status
  res.end status + ': ' + e

$app.fileRequest = (req,res)->
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

$app.fileRequestChunked = (req,res,file,mime,stat)->
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
