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
  await do APP.startServer
  console.log '------------------------------------'
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
              '['+ BunPackage.name.yellow + '/'.gray + BunPackage.version.gray+
              ( if APP.fromSource then '/dev'.red else '/rel'.green ) + ']'
  console.log '------------------------------------'
  $$.forge = require 'node-forge'
  APP.sharedApi SHA512: (value)-> forge.md.sha512.create().update( value ).digest().toHex()
  if APP.fromSource
    APP.NodeLicense = await do APP.fetchLicense
    require './build'
  else require path.join RootDir, 'build', AppPackage.name + '.js'
  do APP.initConfig
  do APP.initDB
  null

APP.initConfig = ->
  unless fs.existsSync confDir = path.join ConfigDir
    try fs.mkdirSync path.join ConfigDir
    catch e
      console.log 'config', ConfigDir.red, e.message
      process.exit 1
  fn() for key, fn of APP.config.$
  console.log 'config', ConfigDir.green, Object.keys(APP.config.$).join(' ').gray

# ██████  ██████
# ██   ██ ██   ██
# ██   ██ ██████
# ██   ██ ██   ██
# ██████  ██████

APP.initDB = ->
  for name, opts of APP.db.$
    APP[name] = level path.join ConfigDir, name + '.db'
    console.log '::::db', ':' + name.bold
  console.log '::::db', 'ready'.green

# ██     ██ ███████ ██████  ███████ ██████  ██    ██
# ██     ██ ██      ██   ██ ██      ██   ██ ██    ██
# ██  █  ██ █████   ██████  ███████ ██████  ██    ██
# ██ ███ ██ ██      ██   ██      ██ ██   ██  ██  ██
#  ███ ███  ███████ ██████  ███████ ██   ██   ████

APP.startServer = ->
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
  # console.log 'static-get'.cyan, file
  mime = if file.match /js$/ then 'text/javascript' else 'text/html'
  file = path.join BuildDir, file
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
    console.log APP.Protocol.yellow, "call".red, call, args
    return fn args, req, res if fn = APP.public.$[call]
    # a cookie is required to continue
    console.log APP.Protocol.yellow, "headers", req.headers
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

APP.apiResponse = (data)->
  @setHeader 'Content-Type', 'text/json'
  @statusCode = 200
  @end JSON.stringify data

# ██████   ██████  ███████ ██████  ██       █████
# ██   ██ ██    ██ ██      ██   ██ ██      ██   ██
# ██   ██ ██    ██ ███████ ██████  ██      ███████
# ██   ██ ██    ██      ██ ██      ██      ██   ██
# ██████   ██████  ███████ ██      ███████ ██   ██

APP.public = (path,callback,fallback)->
  APP.public.$[path] = callback
  APP.private.$[path] = callback
  APP.fallback.$[path] = fallback if fallback

APP.private = (path,callback,fallback)->
  APP.private.$[path] = callback
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

APP.config = (objectOfConfigFunctions)->
  Object.assign APP.config.$, objectOfConfigFunctions
APP.config.$ = {}

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
  ok = -> console.log '::link'.green, path.basename(src).yellow, '->'.yellow, dst.bold
  return do ok if fs.existsSync dst
  return do ok if fs.symlinkSync src, dst

APP.reqdir = (dst) ->
  ok = -> console.log ':::dir'.green, path.basename(dst).yellow
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

APP.fetchLicense = -> new Promise (resolve,reject)->
  _log = console.log; _err = console.error # HACK: suppress legally's verbosity
  console.log = console.error = ->
  APP.npmLicenses = await require 'legally'
  console.log = _log; console.error = _err # HACK: suppress legally's verbosity
  nodeLicenseURL = "https://raw.githubusercontent.com/nodejs/node/master/LICENSE"
  data = ''
  require 'https'
  .get nodeLicenseURL, (resp)->
    resp.on 'data', (chunk) -> data += chunk.toString()
    resp.on 'end', -> resolve data
    resp.on 'error ', -> do reject
