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
$$.WebRootDir = process.env.BASE || path.join RootDir, 'build'
$$.ConfigDir  = process.env.CONF || path.join RootDir, 'config'

$$.BunDir = path.dirname __dirname # in build mode
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
  APP.reqdir WebRootDir
  console.log '------------------------------------'
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
              '['+ BunPackage.name.yellow + '/'.gray + BunPackage.version.gray+
              ( if APP.fromSource then '/dev'.red else '/rel'.green ) + ']'
  # console.log module.parent
  console.log '------------------------------------'
  await do APP.initLicense
  if APP.fromSource
       require './client'
       require path.join RootDir, 'src',   AppPackage.name + '.coffee'
       require './build'
  else require path.join RootDir, 'build', AppPackage.name + '.js'
  # do APP.initDB
  do APP.initWeb
  do APP.initConfig
  do APP.start

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

# ██     ██ ███████ ██████
# ██     ██ ██      ██   ██
# ██  █  ██ █████   ██████
# ██ ███ ██ ██      ██   ██
#  ███ ███  ███████ ██████

APP.initWeb = ->
  APP.web = ( require 'express' )()
  APP.web.use '/build', require('serve-static') WebRootDir, etag:yes
  APP.web.use do require 'compression'
  APP.web.use do require 'cookie-parser'
  APP.web.use do require('body-parser').json
  APP.web.use (req,res,next)->
    return next() unless cookie = req.cookies.SESSION
    # return next() if cookie is 'j:null' #
    APP.session.get cookie, (error,id)->
      return next() if error
      APP.user.get id, (error,value)->
        req.ID = id
        req.USER = value
        next()

  APP.web.get '/', (req,res)->
    APP.headers.$.map (i)-> i req, res
    res.send fs.readFileSync (path.join WebRootDir,'index.html'), 'utf8'
  APP.web.post url, handler for url, handler of APP.postPublic.$
  APP.web.post url, handler for url, handler of APP.postPrivate.$

#  ██████  ██████  ███    ██ ███████ ██  ██████
# ██      ██    ██ ████   ██ ██      ██ ██
# ██      ██    ██ ██ ██  ██ █████   ██ ██   ███
# ██      ██    ██ ██  ██ ██ ██      ██ ██    ██
#  ██████  ██████  ██   ████ ██      ██  ██████

APP.initConfig = ->
  unless fs.existsSync confDir = path.join RootDir, 'config'
    try fs.mkdirSync path.join RootDir, 'config'
    catch e
      console.log 'config', ConfigDir.red, e.message
      process.exit 1

  console.log 'config', ConfigDir.green

  fn() for fn in APP.config.$

  hasKey = fs.existsSync keyPath = path.join RootDir, 'config', 'server.key'
  hasCrt = fs.existsSync crtPath = path.join RootDir, 'config', 'server.crt'

  if 'http' is APP.protocol
    APP.server = ( require 'http' ).createServer(APP.web)
    return
  unless hasKey and hasCrt
    selfsigned = require 'selfsigned'
    attrs = [ { name: 'commonName', value: os.hostname() + '.local' } ]
    opts = extensions: [
      { name: 'basicConstraints', cA: true }
      { name: 'subjectAltName', altNames: [
        { type: 2, value: os.hostname() + '.local' }
        { type: 2, value: os.hostname() }
        { type: 2, value: 'localhost' } ] } ]
    for network, ips of os.networkInterfaces()
      for key, ip of ips when ip.family is 'IPv4'
        opts.extensions[1].altNames.push { type: 7, ip: ip.address }
    pems = selfsigned.generate attrs, opts
    fs.writeFileSync keyPath, pems.private
    fs.writeFileSync crtPath, pems.cert
  options =
    key:  fs.readFileSync 'config/server.key'
    cert: fs.readFileSync 'config/server.crt'
  APP.server = ( require 'https' ).createServer(options,APP.web)

# ███████ ████████  █████  ██████  ████████
# ██         ██    ██   ██ ██   ██    ██
# ███████    ██    ███████ ██████     ██
#      ██    ██    ██   ██ ██   ██    ██
# ███████    ██    ██   ██ ██   ██    ██

APP.start = -> APP.server.listen APP.port, APP.addr, ->
  console.log APP.protocol, 'online'.green, APP.addr.red + ':' + APP.port.toString().magenta
  unless APP.chgid
    console.log 'init','database'.green; APP.initDB()
    return
  console.log 'server','dropping privileges'.green, APP.chgid.toString().yellow
  process.setgid APP.chgid
  process.setuid APP.chgid
  console.log 'init','database'.green; APP.initDB()
  null


# ██████  ███████ ██
# ██   ██ ██      ██
# ██   ██ ███████ ██
# ██   ██      ██ ██
# ██████  ███████ ███████

APP.postPublic = (path,callback)->
  APP.postPublic.$[path] = (req,res,next)->
    return res.json error:'Request without data' unless req.body
    callback req,res,next
APP.postPublic.$ = {}

APP.postPrivate = (path,callback)->
  APP.postPrivate.$[path] = (req,res,next)->
    return res.json error:'Access denied'        unless req.USER
    return res.json error:'Request without data' unless req.body
    callback req,res,next
APP.postPrivate.$ = {}

APP.db = (name)->
  APP.db.$[name] = true
APP.db.$ = user:on, session:on

APP.headers = (fnHeaderGenerator)->
  APP.headers.$.push fnHeaderGenerator
APP.headers.$ = []

APP.config = (fnConfigurationReader)->
  APP.config.$.push fnConfigurationReader
APP.config.$ = []

APP.shared = (objOfConstants)->
  Object.assign $$,           objOfConstants
  Object.assign APP.shared.$, objOfConstants
APP.shared.$ = {}

APP.script = (args...)->
  p = path.join.apply path, [BunDir].concat args
  console.log 'script', p
  APP.script.$.push p
APP.script.$ = []

APP.tpl = (isglobal,objOfTemplates)->
  if true is isglobal
    Object.assign $$, objOfTemplates
  else objOfTemplates = isglobal
  objOfTemplates = {} unless objOfTemplates?
  APP.tpl.$.push objOfTemplates
  objOfTemplates
APP.tpl.$ = []

APP.global = (objOfFunctions)->
  Object.assign $$, objOfFunctions
  APP.client objOfFunctions

APP.client = (objOfClientSideFunctions)->
  objOfClientSideFunctions = {} unless objOfClientSideFunctions?
  APP.client.$.push objOfClientSideFunctions
  objOfClientSideFunctions
APP.client.$ = []

APP.plugin = (module,obj)->
  if typeof obj is 'string'
    name = obj
    obj = name:name
  else name = obj.name
  APP.plugin.$[module]        = mod = {} unless  mod = APP.plugin.$[module]
  APP.plugin.$[module][name] = plug = {} unless plug = mod[name]
  plug
APP.plugin.$ = {}

# ██████  ██    ██ ██ ██      ██████  ██      ██ ██████
# ██   ██ ██    ██ ██ ██      ██   ██ ██      ██ ██   ██
# ██████  ██    ██ ██ ██      ██   ██ ██      ██ ██████
# ██   ██ ██    ██ ██ ██      ██   ██ ██      ██ ██   ██
# ██████   ██████  ██ ███████ ██████  ███████ ██ ██████

APP.touch = require 'touch'

APP.compile = (src,dst)->
  dst = path.join WebRootDir, dst
  return null unless src.match /\.coffee$/
  return null if ( stat = fs.statSync src ).isDirectory()
  dstat = fs.statSync dst if fs.existsSync dst
  return null if stat.mtime.toString().trim() is dstat.mtime.toString().trim() if dstat
  fs.writeFileSync dst, code = coffee.compile fs.readFileSync src, 'utf8'
  APP.touch.sync dst, ref:src
  dstat = fs.statSync dst if fs.existsSync dst
  console.log 'compiled'.green, src.yellow, stat.mtime, ( dstat || mtime:'0' ).mtime
  null

APP.symlink = (src,dst)->
  console.log 'link'.yellow, path.basename(src).yellow, '->'.yellow, dst.bold
  return if fs.existsSync dst
  fs.symlinkSync src, dst
  console.log 'link'.green, path.basename(src).yellow, '->'.yellow, dst.bold

APP.reqdir = (dst) ->
  return if fs.existsSync dst
  fs.mkdirSync dst

Array::unique = ->
  @filter (value, index, self) ->
    self.indexOf(value) == index

# ██      ██  ██████ ███████ ███    ██ ███████ ███████
# ██      ██ ██      ██      ████   ██ ██      ██
# ██      ██ ██      █████   ██ ██  ██ ███████ █████
# ██      ██ ██      ██      ██  ██ ██      ██ ██
# ███████ ██  ██████ ███████ ██   ████ ███████ ███████

APP.initLicense = ->
  if fs.existsSync ( licenseFile = path.join WebRootDir, 'licenses.html' )
    console.log 'exists'.green, licenseFile.bold
    return
  console.log 'create'.green, licenseFile.bold
  npms = cp.spawnSync path.join(BunDir, 'node_modules', '.bin', 'legally'), ['-p','--width','200']
  npms = npms.output.toString().split(/\n/)
    .filter (i)-> i.match(/^│ [^M]/)
    .filter (i)-> not i.match(/Packages/)
    .map (i)->
      i = i.split (/│/)
        .map (i)-> i.trim()
        .filter (value, index, self)->
          value isnt '' and value isnt '-'
        .unique()
    .filter (i)-> i.length > 0
    .map (i)-> i.shift().split(/@/).concat i
    .sort (a,b)-> a[0].localeCompare b[0]
    .map (i)-> """<tr><td class="package">#{i.shift()}</td><td class="version">#{i.shift()}</td><td><span class="license">#{i.join('</span><br/><span class="license">')}</span></td>"""
    .join "\n"
  html = """
    <h1>Licenses</h1>
    <h2>npm packages</h2>
    <table class="npms">
      #{npms}
    </table>
    <h2>nodejs and dependencies</h2>
  """

  nodeLicenseURL = "https://raw.githubusercontent.com/nodejs/node/master/LICENSE"
  await new Promise (resolve)->
    require 'https'
    .get nodeLicenseURL, (resp) =>
      data = '';
      resp.on 'data', (chunk) -> data += chunk.toString()
      resp.on 'end', ->
        data = data.replace /</g, '&lt;'
        data = data.replace />/g, '&gt;'
        html += data
        console.log html
        fs.writeFileSync licenseFile, html
        do resolve
    .on "error", (err) ->
      console.log "Error: " + err.message
      process.exit 1
    null
