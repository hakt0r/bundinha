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

$$.$os    = require 'os'
$$.$fs    = require 'fs'
$$.$cp    = require 'child_process'
$$.$path  = require 'path'
$$.$util  = require 'util'
$$.$forge = require 'node-forge'

$$.ENV = process.env
$$.ARG = process.argv.filter (v)-> not v.match /^-/
for v in ( process.argv.filter (v)-> v.match /^-/ )
  ARG[v.replace /^-+/, ''] = not ( v.match /^--no-/ )?

$$.RootDir   = ENV.APP      || process.cwd()
$$.ConfigDir = ENV.CONF     || $path.join RootDir, 'config'
$$.BuildDir  = ENV.BASE     || $path.join RootDir, 'build'
$$.TempDir   = ENV.TEMP     || $path.join $os.tmpdir(), 'bundinha'
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
    @reqdir  TempDir
    @reqdir  BuildDir
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
  console.debug ':phase'.green, key.bold
  await Promise.all list.map (o)-> new Promise (r)-> r await o.f.call @
  return

Bundinha::build = ->
  @require 'bundinha/backend/backend' unless @backend  is false
  do @loadDependencies

  @htmlFile = @htmlFile || 'index.html'
  @htmlPath = $path.join WebDir, @htmlFile
  @backendFile = @backendFile || 'backend.js'
  console.verbose ':build'.green, @htmlFile
  @reqdir  $path.join BuildDir, 'html'
  @require @sourceFile || $path.join AppPackageName, AppPackageName
  @WebRoot  = $path.join RootDir,'build','html'
  @AssetURL = '/app'
  @AssetDir = $path.join RootDir,'build','html', @AssetURL

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
    compile = =>
      console.debug "::brew".yellow, cfile.bold
      scpt = $fs.readFileSync cfile, 'utf8'
      scpt = $coffee.compile scpt, bare:on, filename:cfile
      $fs.writeFileSync cache, scpt
      @touch.sync cache, ref:cfile
      scpt
    scpt = (
      cacheExists = $fs.existsSync cache = $path.join TempDir, hash = SHA1 cfile = file + '.coffee'
      sourceExists = $fs.existsSync cfile
      if cacheExists and sourceExists
        c = $fs.statSync cache
        s = $fs.statSync cfile
        if c.mtime.toString().trim() is s.mtime.toString().trim()
          $fs.readFileSync cache, 'utf8'
        else compile()
      else if sourceExists then compile()
      else $fs.readFileSync file + '.js', 'utf8' )
    func = new Function 'APP','require','__filename','__dirname',scpt
    do @module[query] = => func.call @, @, require, file, $path.dirname file
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
      console.error ' ', error
    catch e then console.error error
    process.exit 1

# ████████  ██████   ██████  ██      ███████
#    ██    ██    ██ ██    ██ ██      ██
#    ██    ██  █ ██ ██ █  ██ ██      ███████
#    ██    ██    ██ ██    ██ ██           ██
#    ██     ██████   ██████  ███████ ███████

$$.SHA512 = (value)->
  $forge.md.sha512.create().update( value ).digest().toHex()

$$.SHA1 = (value)->
  $forge.md.sha1.create().update( value ).digest().toHex()

String::toBareCode = -> @

Function::toCode = ->
  '('+ @toString().replace(/\n[ ]{4}/g,'\n') + '());\n'

Function::toBareCode = ->
  code = @toString()
  .replace(/^[^\{]+{/,'')
  .replace(/\n[ ]{4}/g,'\n')
  .replace(/^return /,'')
  .replace(/}$/,'')
  code

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
$$.contentHash = (data)->
  # """sha256-#{$forge.util.encode64 $forge.md.sha256.create().update(data).digest().bytes()}"""
  """sha256-#{require('crypto').createHash('sha256').update(data).digest().toString 'base64'}"""

$$.contentHashFile = (path)->
  contentHash $fs.readFileSync path, 'utf8'

$$.accessor = (key)->
  return ".#{key}" if key.match /^[a-z0-9_]+$/i
  return "[#{JSON.stringify key}]"

do Bundinha::arrayTools = ->
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

Bundinha::loadDependencies = ->
  for dep in @requireScope
    if Array.isArray dep
      $$[dep[0]] = require dep[1]
    else $$[dep] = require dep
  return

Bundinha::touch = require 'touch'

Bundinha::symlink = (src,dst)->
  ok = -> console.debug '::link'.green, $path.basename(src).yellow, '->'.yellow, dst.bold
  return do ok if $fs.existsSync dst
  return do ok if $fs.symlinkSync src, dst

Bundinha::linkFile = (src,dest)->
  $fs.linkSync src, dest unless $fs.existsSync dest
  console.debug '::link'.green, $path.basename(dest).bold

Bundinha::reqdir = (dst...) ->
  dst = $path.join.apply $path, dst
  ok = -> console.debug ':::dir'.green, $path.basename(dst).yellow
  return do ok if $fs.existsSync dst
  return do ok if $fs.mkdirSync dst

Bundinha::compileSources = (sources)->
  out = ''
  for source in sources
    if typeof source is 'function'
      source = source.toString().split '\n'
      source.shift(); source.pop(); source.pop()
      source = source.join '\n'
      out += source
    else if Array.isArray source
      source = $path.join.apply $path, source if Array.isArray source
      if source.match /.coffee$/
           out += $coffee.compile ( $fs.readFileSync source, 'utf8' ), bare:on
      else out += $fs.readFileSync source, 'utf8'
    else if typeof source is 'string'
      out += source;
    else throw new Error 'source of unhandled type', typeof source
  out

Bundinha::fetchAsset = (file,url)->
  if $fs.existsSync file
    console.debug ":asset".green, file.bold, url.gray
    Promise.resolve $fs.readFileSync file, 'utf8'
  else new Promise (resolve,reject)->
    console.debug ":asset".yellow, file.bold, url.gray
    data = ''
    require('https').get url, (resp)->
      resp.on 'data', (chunk) -> data += chunk.toString()
      resp.on 'end', ->
        $fs.writeFileSync file, data
        resolve data
      resp.on 'error ', -> do reject

Bundinha::loadAsset = (path)->
  path = $path.join.apply $path, path if Array.isArray path
  throw new Error 'NOT IMPLEMENTED YET' if path.match /https?:/
  file = $path.join @AssetURL, $path.basename path
  dest = $path.join @AssetDir, $path.basename path
  console.debug ' LOAD '.red.inverse,  file path
  $fs.readFileSync path, 'utf8'

Bundinha::linkAsset = (path)->
  path = $path.join.apply $path, path if Array.isArray path
  throw new Error 'NOT IMPLEMENTED YET' if path.match /https?:/
  file = $path.join @AssetURL, $path.basename path
  dest = $path.join @AssetDir, $path.basename path
  @linkFile path, $path.join WebDir, file
  [ file, $fs.readFileSync dest, 'utf8' ]
