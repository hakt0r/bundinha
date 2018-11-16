###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

setImmediate ->
  $$.$coffee = require 'coffeescript'
  new Bundinha().cmd_handle()

require 'colors'

global.$$ = global

$$.$fs   = require 'fs'
$$.$cp   = require 'child_process'
$$.$path = require 'path'
$$.$util = require 'util'

$$.ENV = process.env
$$.ARG = process.argv.filter (v)-> not v.match /^-/
for v in ( process.argv.filter (v)-> v.match /^-/ )
  ARG[v.replace /^-+/, ''] = not ( v.match /^--no-/ )?

$$.RootDir   = ENV.APP      || process.cwd()
$$.ConfigDir = ENV.CONF     || $path.join RootDir, 'config'
$$.BuildDir  = ENV.BASE     || $path.join RootDir, 'build'
$$.BunDir    = ENV.BUNDINHA || $path.dirname $path.dirname __filename
$$.WebDir    = ENV.HTML     || $path.join BuildDir, 'html'

console.verbose = ->
unless $$.DEBUG = ENV.DEBUG is 'true'
  console.debug = ->
if $$.VERBOSE = ENV.VERBOSE is 'true'
  console.verbose = console.error
console._log = console.log
console._err = console.error

$$.COM =
  build: "bundinha"
  prepublish: "bundinha"
  start: "PROTO=http PORT=9999 CHGID=$USER node build/backend.js"
  test:  "bundinha; ADDR=0.0.0.0 PORT=443 CHGID=$USER sudo -E node build/backend.js"
  debug: "bundinha; ADDR=0.0.0.0 PORT=443 node --inspect build/backend.js"
  push: "bundinha push"

# ██████  ██    ██ ███    ██ ██████  ██ ███    ██ ██   ██  █████
# ██   ██ ██    ██ ████   ██ ██   ██ ██ ████   ██ ██   ██ ██   ██
# ██████  ██    ██ ██ ██  ██ ██   ██ ██ ██ ██  ██ ███████ ███████
# ██   ██ ██    ██ ██  ██ ██ ██   ██ ██ ██  ██ ██ ██   ██ ██   ██
# ██████   ██████  ██   ████ ██████  ██ ██   ████ ██   ██ ██   ██

$$.Bundinha = class Bundinha extends require 'events'
  constructor:(opts)->
    super()
    @module = {}
    $$.BUND = @ unless $$.BUND?
    @requireScope = ['os','util','fs',['cp','child_process'],'path','level','colors',['forge','node-forge']]
    Object.assign @, opts
    @phaseList = []
    @require 'bundinha/build/build'
    return

Bundinha::parseConfig = (args...)->
  JSON.parse $fs.readFileSync $path.join.apply($path,args), 'utf8'

Bundinha::writeConfig = (cfg,args...)->
  $fs.writeFileSync $path.join.apply($path,args), JSON.stringify(cfg,null,2),'utf8'

#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████

Bundinha::readPackage = ->
  $$.BunPackage = @parseConfig BunDir,  'package.json'
  $$.AppPackage = @parseConfig RootDir, 'package.json'
  $$.AppPackageName = AppPackage.name.replace(/-devel$/,'')
  try
    Object.assign @, conf = JSON.parse $fs.readFileSync $path.join ConfigDir, AppPackageName + '.json'
    @confKeys = Object.keys conf
    conf

Bundinha::phase = (key,prio,func)->
  ( func = prio; prio = 1 ) unless func?
  @phaseList.push k:key,p:prio,f:func

Bundinha::emphase = (key)->
  list = @phaseList
    .filter (o)-> o.k is key
    .sort (a,b)-> a.p - b.p
  for o in list
    console.debug ':phase'.yellow, key.bold, o.p, o.f.toBareCode().trim().split('\n')[0].gray
    await o.f.call @
    console.debug ':phase'.green, key.bold, o.p, o.f.toBareCode().trim().split('\n')[0].gray
  return

Bundinha::build = ->
  @require 'bundinha/backend/backend' unless @backend  is false
  do @loadDependencies

  @htmlFile = @htmlFile || 'index.html'
  @htmlPath = $path.join WebDir, @htmlFile
  @backendFile = @backendFile || 'backend.js'
  console.verbose ':build'.green, @htmlFile

  @reqdir  BuildDir
  @reqdir  $path.join BuildDir, 'html'
  @require @sourceFile || $path.join AppPackageName, AppPackageName
  @WebRoot  = $path.join RootDir,'build','html'
  @AssetDir = $path.join RootDir,'build','html','app'

  await @emphase 'build:pre'
  await @emphase 'build'
  await @emphase 'build:post'

Bundinha::page = (opts={}) ->
  opts.backend = no
  opts.BuildId = @BuildId
  b = new Bundinha
  b.readPackage()
  Object.assign b, opts
  await do b.build

Bundinha::cmd_handle = ->
  try @readPackage()
  return do @cmd_init       if ( ARG.init is true )
  @readPackage()
  return do @cmd_push_clean if ( ARG.push and ARG.clean ) is true
  return do @cmd_push       if ( ARG.push is true )
  return do @cmd_deploy     if ( ARG.deploy is true )

  $$.$forge  = require 'node-forge'
  @shared BuildId: @BuildId || SHA512 new Date
  @BuildLog = BuildId.substring(0,6).yellow

  nameLength = AppPackage.name.length
  console.log '--------------------------------------' + ''.padStart(nameLength,'-')
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray + '/' + BuildId.substring(0,7).magenta +
              '['+ 'bundinha'.yellow + '/'.gray + BunPackage.version.gray +
              ( '/dev'.red ) + ']'
  console.log '--------------------------------------' + ''.padStart(nameLength,'-')
  await do @build

Bundinha::cmd_init = ->
  @require 'bundinha/build/build'
  @require 'bundinha/build/lib'
  console.log 'init'.yellow, RootDir
  @reqdir RootDir, 'src'
  @reqdir RootDir, 'config'
  unless $fs.existsSync $path.join RootDir, 'package.json'
    $cp.execSync 'npm init', stdio:'inherit'
  p = @parseConfig RootDir, 'package.json'
  delete p.scripts.test
  appName = p.name.replace(/-devel$/,'')
  p.bin = p.bin || {}
  p.scripts = p.scripts || {}
  p.devDependencies = p.devDependencies || {}
  unless p.bin[appName+'-backend']
    p.bin[appName+'-backend'] = $path.join '.','build','backend.js'
  p.scripts[name] = script for name,script of COM when not p.scripts[name]
  p.devDependencies.bundinha = 'file:'+BunDir unless p.devDependencies.bundinha
  @writeConfig p, RootDir, 'package.json'
  process.exit 0

Bundinha::cmd_push = (final=yes)->
  [ url, user, host, path ] = @Deploy.url.match /^([^@]+)@([^:]+):(.*)$/
  process.stderr.write 'push'.yellow + ' ' + user.red.bold + '@' + host.green + ':' + path.gray
  console.debug ['rsync','-avzhL','--exclude','node_modules/','build/',@Deploy.url].join(' ')
  result = $cp.spawnSync 'rsync',['-avzhL','--exclude','node_modules/','build/',@Deploy.url] ,stdio:'inherit'
  console.log if result.status is 0 then ' success'.green.bold else ' error'.red.bold
  process.exit result.status if final

Bundinha::cmd_deploy = ->
  return $cp.spawnSync 'sh',['-c',@Deploy.command] if @Deploy.command
  @cmd_push no; [ url, user, host, path ] = @Deploy.url.match /^([^@]+)@([^:]+):(.*)$/
  process.stderr.write 'deploy'.yellow + ' ' + user.red.bold + '@' + host.green + ':' + path.gray
  result = $cp.spawnSync 'ssh',[user+'@'+host,"""
  cd '#{path}'; npm i -g .;
  #{AppPackageName}-backend install-systemd;
  #{AppPackageName}-backend install-nginx;
  /etc/init.d/nginx restart;
  which systemctl >/dev/null 2>&1 && systemctl restart #{AppPackageName} || /etc/init.d/#{AppPackageName} restart
  """], stdio:'inherit'
  console.log if result.status is 0 then ' success'.green.bold else ' error'.red.bold

Bundinha::cmd_push_clean = ->
  $cp.execSync """
  ssh #{ARG[0]} 'killall node; cd /var/www/; rm -rf #{AppPackageName}/*'
  """; return

# ██████  ███████  ██████  ██    ██ ██ ██████  ███████
# ██   ██ ██      ██    ██ ██    ██ ██ ██   ██ ██
# ██████  █████   ██    ██ ██    ██ ██ ██████  █████
# ██   ██ ██      ██ ▄▄ ██ ██    ██ ██ ██   ██ ██
# ██   ██ ███████  ██████   ██████  ██ ██   ██ ███████
#                     ▀▀

Bundinha::require = (query)->
  file = query
  return mod if mod = @module[query]
  unless module.paths.includes path = $path.join RootDir,'node_modules'
    module.paths.push path
  mod = ( rest = file.split '/' ).shift()
  switch mod
    when 'bundinha'
      console.verbose 'depend'.green.bold, file.bold
      file = $path.join BunDir,  'src', rest.join '/'
    when AppPackageName
      console.verbose 'depend'.yellow.bold, file.bold
      file = $path.join RootDir, 'src', rest.join '/'
    else return require file
  try
    if $fs.existsSync cfile = file + '.coffee'
         scpt = $fs.readFileSync cfile, 'utf8'
         scpt = $coffee.compile scpt, bare:on, filename:cfile
    else scpt = $fs.readFileSync file + '.js', 'utf8'
    func = new Function 'APP','require','__filename','__dirname',scpt
    @module[query] = => func.call @, @, require, file, $path.dirname file
    do @module[query]
  catch error
    @module[query] = false
    if error.stack
      line = parseInt error.stack.split('\n')[1].split(':')[1]
      col  = try parseInt error.stack.split('\n')[1].split(':')[2].split(')')[0] catch e then 0
      console.error 'require'.red.bold, [file.bold,line,col].join ':'
    try
      console.error ' ', error.message.bold
      console.error '>',
        scpt.split('\n')[line-3].substring(0,col-2).yellow
        scpt.split('\n')[line-3].substring(col-1,col).red
        scpt.split('\n')[line-3].substring(col+1).yellow
    process.exit 1

#  █████  ██████  ██████   █████  ██    ██ ████████  ██████   ██████  ██      ███████
# ██   ██ ██   ██ ██   ██ ██   ██  ██  ██     ██    ██    ██ ██    ██ ██      ██
# ███████ ██████  ██████  ███████   ████      ██    ██    ██ ██    ██ ██      ███████
# ██   ██ ██   ██ ██   ██ ██   ██    ██       ██    ██    ██ ██    ██ ██           ██
# ██   ██ ██   ██ ██   ██ ██   ██    ██       ██     ██████   ██████  ███████ ███████

Bundinha::arrayTools = ->
  Object.defineProperties Array::,
    trim:    get: -> return ( @filter (i)-> i? and i isnt false ) || []
    random:  get: -> @[Math.round Math.random()*(@length-1)]
    unique:  get: -> u={}; @filter (i)-> return u[i] = on unless u[i]; no
    uniques: get: ->
      u={}; result = @slice()
      @forEach (i)->
        result.remove i if u[i]
        u[i] = on
      result
    remove:     enumerable:no, value: (v) -> @splice i, 1 if i = @indexOf v; @
    pushUnique: enumerable:no, value: (v) -> @push v if -1 is @indexOf v
    common:     enumerable:no, value: (b) -> @filter (i)-> -1 isnt b.indexOf i
  return

#  ██████  ██       ██████  ██████   █████  ██      ███████
# ██       ██      ██    ██ ██   ██ ██   ██ ██      ██
# ██   ███ ██      ██    ██ ██████  ███████ ██      ███████
# ██    ██ ██      ██    ██ ██   ██ ██   ██ ██           ██
#  ██████  ███████  ██████  ██████  ██   ██ ███████ ███████

Bundinha.global = {}

$$.SHA512 = (value)->
  $forge.md.sha512.create().update( value ).digest().toHex()

$$.SHA1 = (value)->
  $forge.md.sha1.create().update( value ).digest().toHex()

$$.escapeHTML = (str)->
  String(str)
  .replace /&/g,  '&amp;'
  .replace /</g,  '&lt;'
  .replace />/g,  '&gt;'
  .replace /"/g,  '&#039;'
  .replace /'/g,  '&x27;'
  .replace /\//g, '&x2F;'

$$.toAttr = (str)->
  alphanumeric = /[a-zA-Z0-9]/
  ( for char in str
      if char.match alphanumeric then char
      else '&#' + char.charCodeAt(0).toString(16) + ';'
  ).join ''
