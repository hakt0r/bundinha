###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

setImmediate ->
  $$.$coffee = require 'coffeescript'
  new Bundinha().handleCommand()

require 'colors'

global.$$ = global

$$.$os    = require 'os'
$$.$fs    = require 'fs'
$$.$cp    = require 'child_process'
$$.$path  = require 'path'
$$.$util  = require 'util'
$$.$forge = require 'node-forge'

$$.ENV = process.env
$$.ARG = process.argv.slice 2
ARG[v] = not v.match /^no-/ for v in process.argv

# global
$$.TempDir   = ENV.TEMP      || $path.join $os.tmpdir(),'bundinha',$os.userInfo().username
# project
$$.RootDir   = ENV.APP       || process.cwd()
$$.RootNpm   = ENV.ROOT_NPM  || $path.join RootDir,'node_modules'
$$.ConfigDir = ENV.CONF      || $path.join RootDir,'config'
$$.BuildDir  = ENV.BASE      || $path.join RootDir,'build'
$$.GitDir    = ENV.GIT_DEPS  || $path.join RootDir,'node_modules','.git'
# build
$$.BuildNpm  = ENV.BUILD_NPM || $path.join BuildDir,'node_modules'
$$.WebDir    = ENV.HTML      || $path.join BuildDir,'html'
# bundinha
$$.BunDir    = ENV.BUNDINHA  || $path.dirname $path.dirname __filename
$$.BunNpm    = ENV.BUN_NPM   || $path.join BunDir,'node_modules'

console._log = console.log; console._err = console.error
console.verbose = console.error
console.debug   = console.error
console.debug   = (->) unless ( $$.DEBUG   = ENV.DEBUG   )?
console.verbose = (->) unless ( $$.VERBOSE = ENV.VERBOSE )?

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
    @npmScope = ['os','util','fs',['cp','child_process'],'path','colors']
    @npmDevScope = []
    @gitDevScope = []
    @aptDevScope = []
    @aptScope    = []
    @phaseList   = []
    @reqdir  TempDir
    @require 'bundinha/build/build'
    @require 'bundinha/build/backend'
    @require 'bundinha/build/frontend'
    @require 'bundinha/build/api'
    return

Bundinha::parseConfig = (args...)->
  JSON.parse $fs.readFileSync $path.join.apply($path,args), 'utf8'

Bundinha::writeConfig = (cfg,args...)->
  $fs.writeFileSync $path.join.apply($path,args), JSON.stringify(cfg,null,2),'utf8'

Bundinha::readPackage = ->
  $$.BunPackage = @parseConfig BunDir,  'package.json'
  $$.AppPackage = @parseConfig RootDir, 'package.json'
  $$.AppPackageName = AppPackage.name.replace(/-devel$/,'')
  try
    Object.assign @, conf = JSON.parse $fs.readFileSync $path.join ConfigDir, AppPackageName + '.json'
    @confKeys = Object.keys conf
    conf

Bundinha::build = ->
  @require 'bundinha/backend/backend'
  @reqdir BuildDir
  await do @loadDependencies
  console.debug ':build'.green, @htmlFile
  @require @sourceFile || $path.join AppPackageName, AppPackageName
  @WebRoot  = $path.join BuildDir,'html'
  @AssetURL = '/app' unless @AssetURL?
  @AssetDir = $path.join BuildDir,'html', @AssetURL
  @htmlFile = @htmlFile || 'index.html'
  @htmlPath = $path.join WebDir, @htmlFile
  @backendFile = @backendFile || 'backend.js'
  @reqdir WebDir
  @reqdir @AssetDir
  await do @loadDependencies
  await @emphase 'build:pre'
  await @emphase 'build'
  await @emphase 'build:post'
  return

Bundinha::page = (opts={}) ->
  opts.hasBackend = no
  opts.BuildId = @BuildId
  b = new Bundinha
  Object.assign b, opts
  b.readPackage()
  await do b.build

#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████

Bundinha::handleCommand = ->
  args = process.argv.slice 2; cmd = args.shift()
  try @readPackage() # may fail, may not
  return await @cmd.init.apply @, args if cmd is 'init'
  @readPackage() # this one may not fail
  return unless true is await func.apply @, args if func = @cmd.pre[cmd]
  @shared BuildId: @BuildId = @BuildId || SHA512 new Date
  @BuildLog = BuildId.substring(0,6).yellow

  nameLength = AppPackage.name.length
  console.log '--------------------------------------' + ''.padStart(nameLength,'-')
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray + '/' + BuildId.substring(0,7).magenta +
              '['+ 'bundinha'.yellow + '/'.gray + BunPackage.version.gray +
              ( '/dev'.red ) + ']'
  console.log '--------------------------------------' + ''.padStart(nameLength,'-')
  if func = @cmd[cmd]
    return unless true is await func.apply @, args
  else await do @build
  if func = @cmd.post[cmd]
    return unless true is await func.apply @, args

Bundinha::cmd = pre:{}, post:{}, init: ->
  @require 'bundinha/build/build'
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
  unless $fs.existsSync p = $path.join RootDir, 'src', appName + '.coffee'
    $fs.writeFileSync p, """
    @require 'bundinha/backend/unpriv'
    @require 'bundinha/backend/command'
    @require 'bundinha/auth/invite'
    """
  process.exit 0

#  █████  ██    ██ ████████  ██████  ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██    ██    ██    ██ ██   ██ ██    ██ ██ ██      ██   ██
# ███████ ██    ██    ██    ██    ██ ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██    ██    ██    ██ ██   ██ ██    ██ ██ ██      ██   ██
# ██   ██  ██████     ██     ██████  ██████   ██████  ██ ███████ ██████

Bundinha::cmd.pre.autobuild = (args...)->
  project = process.cwd()
  @error 'Not a project'       unless $fs.existsSync project + "/package.json"
  @error 'No source directory' unless $fs.existsSync project + "/src"
  watch = {}; lock = false; linger = false
  build = ->
    return if lock
    # if linger
    #   try linger.kill('SIGHUP')
    #   try linger.kill('SIGKILL')
    lock = true
    console.log 'run'.green.bold, $path.basename project
    p = $cp.spawn 'bundinha', stdio:'inherit'
    await new Promise (resolve)-> p.on 'close', resolve
    if args.length > 0
      p = $cp.spawn 'sh',['-c',args.shift()], stdio:'inherit'
      await new Promise (resolve)-> p.on 'close', resolve
    setTimeout ( ->
      console.log 'unlock'.yellow.bold
      lock = false
    ), 2000
  arm = (p,i)-> (l,c)->
    return if l.mtimeMs is c.mtimeMs
    console.log 'trig'.yellow.bold, $path.basename p
    clearTimeout splint
    splint = setTimeout build
  scan = (dir)->
    items = await $fs.readdir$ dir
    stats = await Promise.all items.map (i)-> $fs.stat$ $path.join dir, i
    await Promise.all ( stats
    .map  (i,k)->
      p = $path.join dir, items[k]
      return p if i.isDirectory()
      watch[p] = $fs.watchFile p, interval:100, arm p, i unless watch[p]
      false
    .filter (i)-> i isnt false
    .map    (i)-> scan i )
  scanner = ->
    await scan $path.join project, 'src'
    await scan $path.join BunDir
    timer = setTimeout scanner, 1000
  timer   = setTimeout scanner

# ██████  ██    ██ ███████ ██   ██
# ██   ██ ██    ██ ██      ██   ██
# ██████  ██    ██ ███████ ███████
# ██      ██    ██      ██ ██   ██
# ██       ██████  ███████ ██   ██

Bundinha::cmd.pre.push = (args...)->
  if args.includes 'clean'
    $cp.execSync """
    ssh #{ARG[0]} 'killall node; cd /var/www/; rm -rf #{AppPackageName}/*'
    """; return
  final = true if args.includes 'final'
  [ url, user, host, path ] = @Deploy.url.match /^([^@]+)@([^:]+):(.*)$/
  process.stderr.write 'push'.yellow + ' ' + user.red.bold + '@' + host.green + ':' + path.gray
  console.debug ['rsync','-avzhL','--exclude','node_modules/','build/',@Deploy.url].join(' ')
  result = $cp.spawnSync 'rsync',['-avzhL','--exclude','node_modules/','build/',@Deploy.url] ,stdio:'inherit'
  console.log if result.status is 0 then ' success'.green.bold else ' error'.red.bold
  process.exit result.status if final

# ██████  ███████ ██████  ██       ██████  ██    ██
# ██   ██ ██      ██   ██ ██      ██    ██  ██  ██
# ██   ██ █████   ██████  ██      ██    ██   ████
# ██   ██ ██      ██      ██      ██    ██    ██
# ██████  ███████ ██      ███████  ██████     ██

Bundinha::cmd.pre.deploy = ->
  return $cp.spawnSync 'sh',['-c',@Deploy.command] if @Deploy.command
  await   @cmd.push 'final'; [ url, user, host, path ] = @Deploy.url.match /^([^@]+)@([^:]+):(.*)$/
  process.stderr.write 'deploy'.yellow + ' ' + user.red.bold + '@' + host.green + ':' + path.gray
  result = $cp.spawnSync 'ssh',[user+'@'+host,"""
  cd '#{path}'; npm i -g .;
  #{AppPackageName}-backend install-systemd;
  #{AppPackageName}-backend install:nginx;
  /etc/init.d/nginx restart;
  which systemctl >/dev/null 2>&1 && systemctl restart #{AppPackageName} || /etc/init.d/#{AppPackageName} restart
  """], stdio:'inherit'
  console.log if result.status is 0 then ' success'.green.bold else ' error'.red.bold

Bundinha::cmd.post.doc = ->
  console.log $util.inspect @serverScope, depth:0

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
  return "[#{key}]" if key.toString?().match? /^[0-9]+$/
  return ".#{key}"  if key.match /^[a-z0-9_]+$/i
  return "[#{JSON.stringify key}]"

Bundinha::npm    = (spec)-> @npmScope   .push spec
Bundinha::apt    = (spec)-> @aptScope   .push spec
Bundinha::npmDev = (spec)->
  console.debug ' npmDev '.yellow.bold.inverse, spec
  @npmDevScope.push spec
Bundinha::gitDev = (spec)-> @gitDevScope.push spec
Bundinha::aptDev = (spec)-> @aptDevScope.push spec

Bundinha::loadDependencies = ->
  module.paths.insert $path.join BuildDir, 'node_modules'
  module.paths.insert $path.join RootDir,  'node_modules'
  module.paths.insert $path.join BunDir,   'node_modules'
  moduleName = (spec)-> if Array.isArray spec then spec[1] else spec
  filterForMissing = (scope,base)-> scope.map(moduleName).filter (spec)->
    return false if module.constructor.builtinModules.includes spec
    return false if $fs.existsSync $path.join base,'node_modules', spec
    true
  installGit = (pkgs)->
    return unless pkgs and pkgs.length > 0
    await $fs.mkdirp$ GitDir
    stat = await Promise.all pkgs.map (pkg)->
      $fs.exists$ $path.join GitDir, $path.basename pkg
    pkgs = pkgs.filter (pkg,idx)-> not stat[idx]
    return unless pkgs and pkgs.length > 0
    console.log 'git'.blue.bold, pkgs.join(' ').gray
    await Promise.all pkgs.map (pkg)->
      await $cp.run$ '#l','git','clone','--depth=1',pkg,
        $path.join GitDir,$path.basename pkg
  installApt = (pkgs)->
    return unless pkgs and pkgs.length > 0
    console.log 'apt'.blue.bold, pkgs.join(' ').gray
    await $cp.run$
      log: true
      needsRoot: true
      args: ['apt-get','install','-yq'].concat(pkgs)
      env:  Object.assign {}, process.env, DEBIAN_FRONTEND:'noninteractive'
  installScope = (scope,base,arg)->
    console.debug ' npm '.yellow.bold.inverse, base, scope.flat().join(' ')
    missing = filterForMissing scope, base
    if missing.length > 0
      console.debug ':::build:npm', arg, missing
      process.chdir base
      $cp.spawnSync 'npm',['i',arg].concat(missing),stdio:'inherit'
    for dep in scope
      if Array.isArray dep
        continue if false is dep[0]
        $$[dep[0]] = require dep[1]
      else $$[dep] = require dep
      console.debug ' $load$ '.white.redBG.bold, dep
  await installApt [@aptDevScope,@aptScope].flat().unique
  await installGit @gitDevScope
  await installScope @npmDevScope, RootDir,   '--save-dev'
  await installScope @npmScope,    BuildDir,  '--save-opt' unless ( @hasBackend is no ) or ( AppPackage.hasBackend is no )
  true

#  █████  ███████ ███████ ███████ ████████ ███████
# ██   ██ ██      ██      ██         ██    ██
# ███████ ███████ ███████ █████      ██    ███████
# ██   ██      ██      ██ ██         ██         ██
# ██   ██ ███████ ███████ ███████    ██    ███████

Bundinha::symlink = (src,dst)->
  ok = -> console.debug '::link'.green, $path.basename(src).yellow, '->'.yellow, dst.bold
  return do ok if $fs.existsSync dst
  return do ok if $fs.symlinkSync src, dst

Bundinha::linkFile = (src,dest)-> # console.log '::link'.yellow, $path.basename(src).bold, $path.basename(dest).bold, $os.userInfo().username; console.log (try ($cp.execSync "ls -al  '#{src}'").toString().trim().gray.bold)||'error'.red.bold; console.log (try ($cp.execSync "ls -al '#{dest}'").toString().trim().gray.bold)||'error'.red.bold
  $fs.linkSync src, dest unless $fs.existsSync dest
  console.debug '::link'.green, $path.basename(dest).bold

Bundinha::reqdir = (dst...) ->
  dst = $path.join.apply $path, dst
  ok = -> console.debug ':::dir'.green, $path.basename(dst).yellow
  return do ok if $fs.existsSync dst
  return do ok if $fs.mkdirp$.sync dst

Bundinha::compileSources = (sources)->
  out = ''
  for source in sources
    if typeof source is 'function'
      out += source.toBareCode()
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
  console.debug 'load'.yellow.bold, file, path
  $fs.readFileSync path, 'utf8'

Bundinha::linkAsset = (path)->
  path = $path.join.apply $path, path if Array.isArray path
  return if path?.match? /^href:/
  console.debug 'link'.yellow.bold, path
  throw new Error 'NOT IMPLEMENTED YET' if path.match /https?:/
  file = $path.join @AssetURL, $path.basename path
  dest = $path.join @AssetDir, $path.basename path
  @linkFile path, $path.join WebDir, file
  [ file, $fs.readFileSync dest, 'utf8' ]

# ███████ ██   ██ ████████ ███████ ███    ██ ███████ ██  ██████  ███    ██ ███████
# ██       ██ ██     ██    ██      ████   ██ ██      ██ ██    ██ ████   ██ ██
# █████     ███      ██    █████   ██ ██  ██ ███████ ██ ██    ██ ██ ██  ██ ███████
# ██       ██ ██     ██    ██      ██  ██ ██      ██ ██ ██    ██ ██  ██ ██      ██
# ███████ ██   ██    ██    ███████ ██   ████ ███████ ██  ██████  ██   ████ ███████

require './lib/nodePromises'; do Bundinha::nodePromises = $$.NodePromises
Bundinha::touch = $fs.touch
require './lib/arrayTools'  ; do Bundinha::arrayTools   = $$.ArrayTools
require './lib/phaser'      ; Phaser Bundinha::
require './lib/cronish'

# ██████  ███████  ██████  ██    ██ ██ ██████  ███████
# ██   ██ ██      ██    ██ ██    ██ ██ ██   ██ ██
# ██████  █████   ██    ██ ██    ██ ██ ██████  █████
# ██   ██ ██      ██ ▄▄ ██ ██    ██ ██ ██   ██ ██
# ██   ██ ███████  ██████   ██████  ██ ██   ██ ███████
#                     ▀▀

$$._BUND_INSTANCE_ = false
stripBOM = (input)->
  input = input.slice 1 if input.charCodeAt(0) is 0xFEFF
  input = input.replace /#!\/[^\n]+\n/g,''
  input

# require.extensions['.js'] = (module,filename)->
#   content = $fs.readFileSync filename, 'utf8'
#   content = '( function(){\n' + stripBOM(content) + '\n}).apply(_BUND_INSTANCE_);\n'
#   module._compile content, filename

require.extensions['.coffee'] = (module,filename)=>
  options = Object.assign (
    bare:on, filename:filename, inlineMap:yes, sourceMap:yes
  ), module.options || {}
  cacheExists = $fs.existsSync cache = $path.join TempDir, hash = SHA1 filename
  compile = =>
    console.log "::brew".yellow, filename.bold
    { js, sourceMap } = $coffee._compileFile filename, options
    $coffee.sourceMap = $coffee.sourceMap || {}
    $coffee.sourceMap[filename] = sourceMap
    scpt = js
    $fs.writeFileSync cache, scpt
    $fs.touch.sync cache, ref:filename
    scpt
  scpt = (
    if cacheExists
      c = $fs.statSync cache
      s = $fs.statSync filename
      if c.mtime.toString().trim() is s.mtime.toString().trim()
        $fs.readUTF8Sync cache
      else compile()
    else compile() )
  scpt = '( function(){\n' + scpt + '\n}).apply(_BUND_INSTANCE_);\n'
  delete require.cache[filename]
  return module._compile scpt, filename

Bundinha::require = (query,p='')->
  if 'string' is type = typeof query
    query = $path.join p, query if p isnt ''
    return true if @module[query]?
    unless module.paths.includes path = $path.join RootDir,'node_modules'
      module.paths.push path
    mod = ( rest = ( file = query ).split '/' ).shift()
    switch mod
      when 'bundinha'     then file = $path.join BunDir,  'src', rest.join '/'
      when AppPackageName then file = $path.join RootDir, 'src', rest.join '/'
      else return require file
    @module[query] = @module[file] = true
    $$._BUND_INSTANCE_ = @; require file; $$._BUND_INSTANCE_ = false
  else if Array.isArray query then for mod in query
    @require mod, p
  else if 'object' is type then for path, mod of query
    @require mod, $path.join p, path
  true
