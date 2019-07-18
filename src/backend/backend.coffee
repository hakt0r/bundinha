# ██ ███    ██ ██ ████████
# ██ ████   ██ ██    ██
# ██ ██ ██  ██ ██    ██
# ██ ██  ██ ██ ██    ██
# ██ ██   ████ ██    ██

@require 'bundinha/crypto/heavy'

@serverHeader = []
@serverHeader.push ->
  require 'colors'
  global.$$     = global
  $$.$path      = require 'path'
  $$.$fs        = require 'fs'
  $$.DEBUG      = no
  $$.VERBOSE    = no
  $$.ENV        = process.env
  $$.RootDir    = process.env.APP  || __dirname
  $$.WebDir     = process.env.HTML || $path.join RootDir, 'html'
  $$.AppPackage = JSON.parse $fs.readFileSync ($path.join RootDir, 'package.json' ), 'utf8'
  parentDir     = $path.join $path.dirname RootDir
  $$.DevMode    = $fs.existsSync pp = $path.join parentDir,'config',AppPackage.name + '.json'
  $$.ConfigDir  = process.env.CONF ||
    if DevMode then $path.join parentDir, 'config'
    else $path.join RootDir, 'config'
  console._log = console.log; console._err = console.error
  console.verbose = console.error
  console.verbose = (->) unless ( $$.VERBOSE = ENV.VERBOSE )?
  console.debug = console.error
  console.debug = (->) unless ( $$.DEBUG   = ENV.DEBUG   )?
  return

@phase 'build:pre',-1,=>
  @serverHeader.push """
    $$.AssetDir = $path.join(WebDir,"#{@AssetDir.replace(WebDir,'')}");
  """

@server
  preinit:->
    do APP.loadDependencies
    do APP.readEnv
    do APP.nodePromises
    do APP.arrayTools
    process.title = (  $$.BaseUrl || AppPackage.name ).replace(/https?:\/\//,'')
    await do Command.init
    return
  init:->
    await do APP.preinit
    await do APP.splash
    await do APP.startServer
    await do APP.initConfig
    # await do APP.initDB if APP.initDB
    return
  SHA512:SHA512
  escapeHTML:escapeHTML

@server.APP = class $app

$app.arrayTools   = $$.ArrayTools
$app.nodePromises = $$.NodePromises
$app.require      = @npmScope

$app.loadDependencies = ->
  for dep in @require
    if Array.isArray dep
      continue if false is dep[0]
      $$['$' + dep[0]] = require dep[1]
    else $$['$' + dep] = require dep
    console.debug ' $load$ '.white.redBG.bold, dep
  return

$app.readEnv = ->
  try APP.initConfig yes
  $$.DEBUG     =  process.env.DEBUG is 'true' || false
  APP.chgid    =  $$.ChgID    || process.env.CHGID || false
  APP.port     =  $$.Port     || process.env.PORT  || 9999
  APP.addr     =  $$.Addr     || process.env.ADDR  || '127.0.0.1'
  APP.protocol =  $$.Protocol || process.env.PROTO || 'https'
  console.debug   = if DEBUG   then console.log else ->
  console.verbose = if VERBOSE then console.log else ->
  return

$app.splash = ->
  console.log '------------------------------------'
  console.log ' ',
    AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
    '['+ 'bundinha'.yellow + '/'.gray + AppPackage.bundinha.gray +
    ( if DevMode then '/dev'.red else '/rel'.green ) + ']'
  console.log '------------------------------------'
  console.log '    BaseUrl'.yellow, $$.BaseUrl   ?.bold.white || 'undefined'.red.bold
  console.log '  ConfigDir'.yellow, $$.ConfigDir ?.green      || 'undefined'.red.bold
  console.log '    RootDir'.yellow, $$.RootDir   ?.green      || 'undefined'.red.bold
  console.log '     WebDir'.yellow, $$.WebDir    ?.green      || 'undefined'.red.bold
  return

@require 'bundinha/backend/command'
$app.initConfig = (probeOnly=no)->
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
    @arrayTools()
    @configKeys = Object.keys(config).concat(@configKeys).uniques
    do @writeConfig if update is yes and probeOnly is no
  else if not probeOnly
    Object.assign $$, config = @defaultConfig
    @configKeys = Object.keys @defaultConfig
    $fs.writeFileSync p, JSON.stringify @defaultConfig
  @configWasRead = true
  console.debug 'config', ConfigDir.green, @configKeys.join(' ').gray

$app.writeConfig = ->
  p = $path.join ConfigDir, AppPackage.name + '.json'
  console.debug ' config:write '.white.inverse.bold, @configKeys.join(' ').gray
  $fs.writeFileSync p, JSON.stringify (
    o = {}
    o[k] = $$[k] for k in @configKeys
    o ), null, 2

@require 'bundinha/backend/command'
