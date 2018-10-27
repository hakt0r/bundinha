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
  $$.DEBUG      = no
  $$.RootDir    = process.env.APP  || __dirname
  $$.WebDir     = process.env.HTML || $path.join RootDir, 'html'
  $$.AppPackage = JSON.parse $fs.readFileSync ($path.join RootDir, 'package.json' ), 'utf8'
  parentDir     = $path.join $path.dirname RootDir
  $$.DevMode    = $fs.existsSync pp = $path.join parentDir,'config',AppPackage.name + '.json'
  $$.ConfigDir  = process.env.CONF ||
    if DevMode then $path.join parentDir, 'config'
    else $path.join RootDir, 'config'
  return
@serverHeader.push @arrayTools

@server
  preinit:->
    do APP.loadDependencies
    do APP.readEnv
    for name, func of APP.command when process.argv.includes name
      func()
    return
  init:->
    await APP.preinit()
    $fs.stat$     = $util.promisify $fs.stat
    $fs.exists$   = $util.promisify $fs.exists
    $fs.readdir$  = $util.promisify $fs.readdir
    $fs.readFile$ = $util.promisify $fs.readFile
    $cp.spawn$    = $util.promisify $cp.spawn
    console.debug = (->) unless DEBUG
    do APP.splash
    await do APP.startServer
    do APP.initConfig
    do APP.initDB
    return

@server.APP = class $app

$app.require = @requireScope

$app.loadDependencies = ->
  for dep in @require
    if Array.isArray dep
      $$['$' + dep[0]] = require dep[1]
    else $$['$' + dep] = require dep
  return

$app.readEnv = ->
  try do APP.initConfig
  $$.DEBUG     =  process.env.DEBUG || false
  APP.chgid    =  $$.ChgID    || process.env.CHGID || false
  APP.port     =  $$.Port     || process.env.PORT  || 9999
  APP.addr     =  $$.Addr     || process.env.ADDR  || '127.0.0.1'
  APP.protocol =  $$.Protocol || process.env.PROTO || 'https'
  return

$app.splash = ->
  console.log '------------------------------------'
  console.log ' ',
    AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
    '['+ 'bundinha'.yellow + '/'.gray + AppPackage.bundinha.gray +
    ( if DevMode then '/dev'.red else '/rel'.green ) + ']'
  console.log '------------------------------------'
  console.log 'RootDir  '.yellow, RootDir.green
  console.log 'WebDir   '.yellow, WebDir.green
  console.log 'ConfigDir'.yellow, ConfigDir.green
  return

$app.initConfig = ->
  return if @configWasRead
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
  @configWasRead = true
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