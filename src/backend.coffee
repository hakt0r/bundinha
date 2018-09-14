# ██ ███    ██ ██ ████████
# ██ ████   ██ ██    ██
# ██ ██ ██  ██ ██    ██
# ██ ██  ██ ██ ██    ██
# ██ ██   ████ ██    ██

APP.serverHeader = ->
  global.$$ = global
  require 'colors'
  $$.path = require 'path'
  $$.fs   = require 'fs'
  $$.isClient = not ( $$.isServer = yes )
  $$.debug = no
  $$.RootDir   = process.env.APP  || __dirname
  $$.WebDir    = process.env.HTML || path.join RootDir, 'html'
  $$.ConfigDir = process.env.CONF || path.join path.dirname(RootDir), 'config'
  $$.AppPackage = JSON.parse fs.readFileSync (path.join RootDir, 'package.json' ), 'utf8'
  $$.APP =
    fromSource: no
    require:$:[]
    config:$:{}
    private:$:{}
    public:$:{}
    db:$:{}
  Array::unique =-> @filter (value, index, self) -> self.indexOf(value) == index
  return

API = APP.serverApi()

API.init = ->
  do APP.loadDependencies
  do APP.readEnv
  console.debug = (->) unless DEBUG
  do APP.splash
  await do APP.startServer
  APP.web.pages = ['/','/app','/service.js']
  do APP.initConfig
  do APP.initDB

API.loadDependencies = APP.loadDependencies

API.readEnv = ->
  $$.DEBUG     =  process.env.DEBUG || false
  APP.chgid    =  process.env.CHGID || false
  APP.port     =  process.env.PORT  || 9999
  APP.addr     =  process.env.ADDR  || '127.0.0.1'
  APP.protocol =  process.env.PROTO || 'https'
  return

API.splash = APP.splash = ->
  console.log '------------------------------------'
  console.log ' ',
    AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
    '['+ 'bundinha'.yellow + '/'.gray + AppPackage.bundinha.gray +
    ( if APP.fromSource then '/dev'.red else '/rel'.green ) + ']'
  console.log '------------------------------------'
  console.log 'ConfigDir'.yellow, ConfigDir.green
  return

API.initConfig = ->
  unless fs.existsSync confDir = path.join ConfigDir
    try fs.mkdirSync path.join ConfigDir
    catch e
      console.log 'config', ConfigDir.red, e.message
      process.exit 1
  for key, fn of APP.config.$
    try fn()
    catch e then console.log key.red, fn, e.message
  console.log 'config', ConfigDir.green, Object.keys(APP.config.$).join(' ').gray

API.initDB = ->
  for name, opts of APP.db.$
    APP[name] = level path.join ConfigDir, name + '.db'
    console.log '::::db', ':' + name.bold
  console.log '::::db', 'ready'.green

# ██     ██ ███████ ██████  ███████ ██████  ██    ██
# ██     ██ ██      ██   ██ ██      ██   ██ ██    ██
# ██  █  ██ █████   ██████  ███████ ██████  ██    ██
# ██ ███ ██ ██      ██   ██      ██ ██   ██  ██  ██
#  ███ ███  ███████ ██████  ███████ ██   ██   ████

API.startServer = ->
  if 'http' is APP.protocol
    APP.Protocol = '::http'
    APP.server = require('http')
    .createServer APP.web
    return

  hasKey = fs.existsSync keyPath = path.join ConfigDir, 'host.key'
  hasCrt = fs.existsSync crtPath = path.join ConfigDir, 'host.crt'

  unless hasKey and hasCrt
    console.log 'SSL'.red, 'HOST crt missing:', crtPath
    console.log 'SSL'.red, 'HOST key missing:', keyPath
    process.exit 1

  APP.Protocol = ':https'
  options =
    key:  fs.readFileSync keyPath
    cert: fs.readFileSync crtPath

  APP.server = require('https')
  .createServer options, APP.web

  new Promise (resolve)-> APP.server.listen APP.port, APP.addr, ->
    console.log APP.Protocol, 'online'.green, APP.addr.red + ':' + APP.port.toString().magenta
    return resolve() unless APP.chgid
    console.log APP.Protocol, 'dropping privileges'.green, APP.chgid.toString().yellow
    process.setgid APP.chgid
    process.setuid APP.chgid
    return resolve()

API.readStream = (stream)-> new Promise (resolve,reject)->
  body = []
  stream.on 'data', (chunk)-> body.push chunk
  stream.on 'end', -> resolve Buffer.concat(body).toString('utf8')

API.web = (req,res)->
  if req.method is 'POST' and req.url is '/api'
    res.json = APP.apiResponse
    return APP.apiRequest req, res
  if APP.web.pages.includes req.url
    return APP.fileRequest req, res
  res.statusCode = 404
  res.end '404 - Not found'

API.fileRequest = (req,res)->
  file = req.url
  file = 'index.html' if file is '/'
  file = 'index.html' if file is '/app'
  # console.log 'static-get'.cyan, file
  mime = if file.match /js$/ then 'text/javascript' else 'text/html'
  file = path.join WebDir, file
  errorResponse = (e)->
    console.log APP.Protocol.red, file.yellow, e.message
    res.writeHead 500
    res.end 'Internal Server Error'
  fs.stat file, (error,stat)->
    return errorResponse error if error
    console.log APP.Protocol.green, file.yellow
    stream = fs.createReadStream file
    stream.on 'error', errorResponse
    res.setHeader 'Content-Type',   mime
    res.setHeader 'Content-Length', stat.size
    res.writeHead 200
    stream.pipe res
  null

API.apiRequest = (req,res)->
  stream = undefined
  switch (req.headers['content-encoding'] or 'raw').toLowerCase()
    when 'deflate' then req.pipe stream = zlib.createInflate()
    when 'gzip'    then req.pipe stream = zlib.createGunzip()
    when 'raw'     then stream = req; stream.length = req.headers['content-length']
    else return res.json error:'Request without data'
  APP.readStream stream
  .then (body)->
    # parse body
    try body = JSON.parse body
    catch e then return res.json error:'Request is invalid json', message:e.message
    return              res.json error:'Request not an array' unless Array.isArray body
    [ call, args ] = body
    # reply to public api-requests
    console.debug APP.Protocol.yellow, "call".red, call, args
    return fn args, req, res if fn = APP.public.$[call]
    # a cookie is required to continue
    console.debug APP.Protocol.yellow, "headers", req.headers
    return res.json error:'Access denied' unless cookies = req.headers.cookie
    CookieReg = /SESSION=([A-Za-z0-9+/=]+={0,3});?/
    return res.json error:'Access denied' unless match = cookies.match CookieReg
    cookie = match[1]
    APP.session.get cookie
    .then (id)-> APP.user.get req.ID = id
    .then (value)->
      if ( req.USER = value )? and fn = APP.private.$[call]
        fn args, req, res
      else res.json error:'Access denied', message:"Invalid session"
  .catch (error)-> res.json error:'Access denied', message: error.message

API.apiResponse = (data)->
  @setHeader 'Content-Type', 'text/json'
  @statusCode = 200
  @end JSON.stringify data
