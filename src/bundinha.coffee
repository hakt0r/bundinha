###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

global.$$ = global
$$.isClient = not ( $$.isServer = true )
$$.debug = no

# ██████  ███████ ██████  ███████
# ██   ██ ██      ██   ██ ██
# ██   ██ █████   ██████  ███████
# ██   ██ ██      ██           ██
# ██████  ███████ ██      ███████

$$.os     = require 'os'
$$.fs     = require 'fs'
$$.cp     = require 'child_process'
$$.path   = require 'path'
$$.level  = require 'level'
$$.colors = require 'colors'
$$.coffee = require 'coffeescript'

# ███████ ███    ██ ██    ██
# ██      ████   ██ ██    ██
# █████   ██ ██  ██ ██    ██
# ██      ██  ██ ██  ██  ██
# ███████ ██   ████   ████

$$.RootDir    = process.env.APP  || path.dirname module.parent.parent.filename
$$.BuildDir   = process.env.BASE || path.join RootDir, 'build'
$$.ConfigDir  = process.env.CONF || path.join RootDir, 'config'

$$.BunDir     = path.dirname __dirname # in build mode
$$.BunPackage = JSON.parse fs.readFileSync (path.join BunDir,  'package.json'), 'utf8'
$$.AppPackage = JSON.parse fs.readFileSync (path.join RootDir, 'package.json'), 'utf8'

$$.$GLOBAL = true

$$.APP = module.exports =
  chgid:      process.env.CHGID || false
  port:       process.env.PORT  || 9999
  addr:       process.env.ADDR  || '127.0.0.1'
  protocol:   process.env.PROTO || 'https'
  fromSource: fs.existsSync path.join RootDir,'src',AppPackage.name+'.coffee'

# ██ ███    ██ ██ ████████
# ██ ████   ██ ██    ██
# ██ ██ ██  ██ ██    ██
# ██ ██  ██ ██ ██    ██
# ██ ██   ████ ██    ██

setImmediate APP.init = ->
  do APP.initConfig
  await do APP.start
  console.log 'init','database'.green;
  APP.reqdir BuildDir
  console.log '------------------------------------'
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
              '['+ BunPackage.name.yellow + '/'.gray + BunPackage.version.gray+
              ( if APP.fromSource then '/dev'.red else '/rel'.green ) + ']'
  # console.log module.parent
  console.log '------------------------------------'
  if APP.fromSource
    await do APP.initLicense
    require './client'
    require path.join RootDir, 'src',   AppPackage.name + '.coffee'
    require './build'
  else require path.join RootDir, 'build', AppPackage.name + '.js'
  do APP.initWeb
  do APP.initDB
  null

# ██████  ██████
# ██   ██ ██   ██
# ██   ██ ██████
# ██   ██ ██   ██
# ██████  ██████

APP.initDB = ->
  for name, opts of APP.db.$
    console.log 'db', name.green
    APP[name] = level path.join ConfigDir, name + '.db'
  null

# ██     ██ ███████ ██████  ███████ ██████  ██    ██
# ██     ██ ██      ██   ██ ██      ██   ██ ██    ██
# ██  █  ██ █████   ██████  ███████ ██████  ██    ██
# ██ ███ ██ ██      ██   ██      ██ ██   ██  ██  ██
#  ███ ███  ███████ ██████  ███████ ██   ██   ████

APP.start = -> new Promise (resolve)-> APP.server.listen APP.port, APP.addr, ->
  console.log APP.protocol, 'online'.green, APP.addr.red + ':' + APP.port.toString().magenta
  return resolve() unless APP.chgid
  console.log 'server','dropping privileges'.green, APP.chgid.toString().yellow
  process.setgid APP.chgid
  process.setuid APP.chgid
  return resolve()

APP.readStream = (stream)-> new Promise (resolve,reject)->
  body = []
  stream.on 'data', (chunk)-> body.push chunk
  stream.on 'end', -> resolve Buffer.concat(body).toString('utf8')

APP.initWeb = ->

APP.web = (req,res)->
  if req.method is 'POST' and req.url is '/api'
    res.json = APP.apiResponse
    return APP.apiRequest req, res
  if APP.web.pages.includes req.url
    return APP.fileRequest req, res
  res.statusCode = 404
  res.end '404 - Not found'

APP.web.pages = ['/','/app','/service.js']

APP.fileRequest = (req,res)->
  file = req.url
  file = 'index.html' if file is '/'
  file = 'index.html' if file is '/app'
  console.log 'static-get'.cyan, file
  mime = if file.match /js$/ then 'text/javascript' else 'text/html'
  file = path.join BuildDir, file
  errorResponse = (e)->
    console.log 'http'.red, file.yellow, e.message
    res.writeHead 500
    res.end 'Internal Server Error'
  fs.stat file, (error,stat)->
    return errorResponse error if error
    console.log 'http'.green, file.yellow
    stream = fs.createReadStream file
    stream.on 'error', errorResponse
    res.setHeader 'Content-Type',   mime
    res.setHeader 'Content-Length', stat.size
    res.writeHead 200
    stream.pipe res
  null

APP.apiRequest = (req,res)->
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
    console.log "call".red, call, args
    return fn args, req, res if fn = APP.public.$[call]
    # a cookie is required to continue
    console.log "headers", req.headers
    return res.json error:'Access denied' unless cookies = req.headers.cookie
    CookieReg = /SESSION=([^-A-Za-z0-9+/=]|=[^=]|={3,});/
    return res.json error:'Access denied' unless match = cookies.match CookieReg
    cookie = match[1]
    APP.session.get cookie
    .then (id)-> APP.user.get id
    .then (value)->
      req.ID = id
      req.USER = value
      if fn = APP.private.$[call] and req.USER
        fn args, req, res
      else res.json error:'Access denied'
  .catch (error)-> return res.json error:'Access denied', message: error.message

APP.apiResponse = (data)->
  @setHeader 'Content-Type', 'text/json'
  @statusCode = 200
  @end JSON.stringify data

#  ██████  ██████  ███    ██ ███████ ██  ██████
# ██      ██    ██ ████   ██ ██      ██ ██
# ██      ██    ██ ██ ██  ██ █████   ██ ██   ███
# ██      ██    ██ ██  ██ ██ ██      ██ ██    ██
#  ██████  ██████  ██   ████ ██      ██  ██████

APP.initConfig = ->
  unless fs.existsSync confDir = path.join ConfigDir
    try fs.mkdirSync path.join ConfigDir
    catch e
      console.log 'config', ConfigDir.red, e.message
      process.exit 1

  console.log 'config', ConfigDir.green

  fn() for fn in APP.config.$

  hasKey = fs.existsSync keyPath = path.join ConfigDir, 'host.key'
  hasCrt = fs.existsSync crtPath = path.join ConfigDir, 'host.crt'

  if 'http' is APP.protocol
    APP.server = ( require 'http' ).createServer(APP.web)
    return
  unless hasKey and hasCrt
    selfsigned = require './selfsigned'
    selfsigned APP.publicDNS, APP.publicIP
    console.log 'SSL'.red, 'CA certificate can be found in:', path.join ConfigDir, 'ca.crt'
  options =
    key:  fs.readFileSync 'config/host.key'
    cert: fs.readFileSync 'config/host.crt'
    ca:   fs.readFileSync 'config/ca.crt'
  APP.server = ( require 'https' ).createServer(options,APP.web)

# ██████   ██████  ███████ ██████  ██       █████
# ██   ██ ██    ██ ██      ██   ██ ██      ██   ██
# ██   ██ ██    ██ ███████ ██████  ██      ███████
# ██   ██ ██    ██      ██ ██      ██      ██   ██
# ██████   ██████  ███████ ██      ███████ ██   ██

APP.public = (path,callback,fallback)->
  APP.public.$[path] = callback
  APP.fallback.$[path] = fallback if fallback

APP.private = (path,callback,fallback)->
  APP.public.$[path] = callback
  APP.fallback.$[path] = fallback if fallback

APP.fallback = (path,fallback)->
  APP.fallback.$[path] = fallback

APP.public.$   = {}
APP.private.$  = {}
APP.fallback.$ = {}

APP.db = (name)-> APP.db.$[name] = true
APP.db.$ = user:on, session:on

APP.css = (argsForPath...)->
  p = path.join.apply path, argsForPath
  APP.css.$[p] = true
APP.css.$ = {}

APP.config = (fnConfigurationReader)->
  APP.config.$.push fnConfigurationReader
APP.config.$ = []

APP.shared = (objOfConstants)->
  Object.assign $$,           objOfConstants
  Object.assign APP.shared.$, objOfConstants
APP.shared.$ = {}

APP.script = (args...)->
  p = path.join.apply path, [BunDir].concat args
  APP.script.$.push p
APP.script.$ = []

APP.tpl = (isglobal,objOfTemplates)->
  if true is isglobal then Object.assign $$, objOfTemplates
  else objOfTemplates = isglobal
  objOfTemplates = {} unless objOfTemplates?
  APP.tpl.$.push objOfTemplates
  objOfTemplates
APP.tpl.$ = []

APP.sharedApi = (objOfFunctions)->
  Object.assign $$, objOfFunctions
  APP.clientApi objOfFunctions

APP.clientApi = (objOfClientSideFunctions)->
  objOfClientSideFunctions = {} unless objOfClientSideFunctions?
  APP.clientApi.$.push objOfClientSideFunctions
  objOfClientSideFunctions
APP.clientApi.$ = []

APP.plugin = (module,obj)->
  if typeof obj is 'string'
    name = obj
    obj = name:name
  else name = obj.name
  APP.plugin.$[module]        = mod = {} unless  mod = APP.plugin.$[module]
  APP.plugin.$[module][name] = plug = {} unless plug = mod[name]
  plug
APP.plugin.$ = {}

APP.webWorker = (name,sources...)->
  APP.clientApi init:->
    loadWorker = (name)->
      src = document.getElementById(name).textContent
      blob = new Blob [src], type: 'text/javascript'
      $$[name] = new Worker window.URL.createObjectURL blob
    loadWorker name for name in BunWebWorker
    null
  APP.webWorker.$[name] = APP.compileSources sources
APP.webWorker.$ = {}

APP.sharedApi
  escapeHTML: (str)->
    String(str)
    .replace /&/g,  '&amp;'
    .replace /</g,  '&lt;'
    .replace />/g,  '&gt;'
    .replace /"/g,  '&#039;'
    .replace /'/g,  '&x27;'
    .replace /\//g, '&x2F;'
  toAttr: (str)->
    alphanumeric = /[a-zA-Z0-9]/
    ( for char in str
        if char.match alphanumeric then char
        else '&#' + char.charCodeAt(0).toString(16) + ';'
    ).join ''

# ██████  ██    ██ ██ ██      ██████  ██      ██ ██████
# ██   ██ ██    ██ ██ ██      ██   ██ ██      ██ ██   ██
# ██████  ██    ██ ██ ██      ██   ██ ██      ██ ██████
# ██   ██ ██    ██ ██ ██      ██   ██ ██      ██ ██   ██
# ██████   ██████  ██ ███████ ██████  ███████ ██ ██████

Array::unique = ->
  @filter (value, index, self) -> self.indexOf(value) == index

APP.touch = require 'touch'

APP.symlink = (src,dst)->
  ok = -> console.log 'link'.green, path.basename(src).yellow, '->'.yellow, dst.bold
  return do ok if fs.existsSync dst
  return do ok if fs.symlinkSync src, dst

APP.reqdir = (dst) ->
  ok = -> console.log 'dir'.green, path.basename(dst).yellow
  return do ok if fs.existsSync dst
  return do ok if fs.mkdirSync dst

APP.compileSources = (sources)->
  out = ''
  for source in sources
    if typeof source is 'function'
      source = source.toString().split '\n'
      source.shift(); source.pop(); source.pop()
      source = source.join '\n'
      out += source
    else if Array.isArray source
      source = path.join.apply path, source if Array.isArray source
      if source.match /.coffee$/
           out += coffee.compile ( fs.readFileSync source, 'utf8' ), bare:on
      else out += fs.readFileSync source, 'utf8'
    else if typeof source is 'string'
      out += source;
    else throw new Error 'source of unhandled type', typeof source
  out

# ██      ██  ██████ ███████ ███    ██ ███████ ███████
# ██      ██ ██      ██      ████   ██ ██      ██
# ██      ██ ██      █████   ██ ██  ██ ███████ █████
# ██      ██ ██      ██      ██  ██ ██      ██ ██
# ███████ ██  ██████ ███████ ██   ████ ███████ ███████

APP.initLicense = ->
  if fs.existsSync ( licenseFile = path.join BuildDir, 'licenses.html' )
    console.log 'exists'.green, licenseFile.bold
    return
  console.log 'create'.green, licenseFile.bold
  npms = ( for name, pkg of await require 'legally'
    [match,link,version] = name.match /(.*)@([^@]+)/
    shortName = link.split('/').pop()
    licenses = pkg.package.concat(pkg.license).unique()
    licenses = licenses.filter (i)-> i isnt '? verify'
    """<div class=npm-package>
    <span class=version>#{version}</span>
    <span class=name><a href="https://www.npmjs.com/package/#{encodeURI link}">#{escapeHTML shortName}</a></span>
    <span class="license-list"><span class="license">#{licenses.map(escapeHTML).join('</span><span class="license">')}</span></span>
    </div>"""
  ).join '\n'
  html = """
    <h1>Licenses</h1>
    <h2>npm packages</h2>
    <table class="npms">#{npms}</table>
    <h2>nodejs and dependencies</h2>
  """
  nodeLicenseURL = "https://raw.githubusercontent.com/nodejs/node/master/LICENSE"
  return new Promise (resolve)->
    require 'https'
    .get nodeLicenseURL, (resp) =>
      data = '';
      resp.on 'data', (chunk) -> data += chunk.toString()
      resp.on 'end', ->
        data = data.replace /</g, '&lt;'
        data = data.replace />/g, '&gt;'
        data = data.replace /, is licensed as follows/g, ''
        toks = data.split /"""/
        out  = toks.shift(); mode = off
        while ( segment = do toks.shift )
          unless mode
            out += '<pre class=license_text>'
            segment = segment.replace /\n *\/\/ /g, ''
            segment = segment.replace /\n *# /g, '\n'
            segment = segment.replace /\n *#\n/g, '\n\n'
            segment = segment.replace /\n *\=+ *\n*/g, '<span class=hr></span>'
            segment = segment.replace /\n *\-+ *\n*/g, '<span class=hr></span>'
            out += segment.trim() + '</pre>'
            mode = on
          else
            out += segment.trim().replace(/^ *- */,'')
            mode = off
        html += out
        fs.writeFileSync licenseFile, html
        do resolve
    .on "error", (err) ->
      console.log "Error: " + err.message
      process.exit 1
    null
