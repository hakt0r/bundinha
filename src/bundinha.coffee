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
$$.ARG = process.argv.slice 2
ARG[v] = not v.match /^no-/ for v in process.argv

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
    @requireScope = ['os','util','fs',['cp','child_process'],'path','colors']
    @requireDevScope = []
    @phaseList = []
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
  do @loadDependencies
  # console.verbose ':build'.green, @htmlFile
  @require @sourceFile || $path.join AppPackageName, AppPackageName
  @WebRoot  = $path.join BuildDir,'html'
  @AssetURL = '/app' unless @AssetURL?
  @AssetDir = $path.join BuildDir,'html', @AssetURL
  @htmlFile = @htmlFile || 'index.html'
  @htmlPath = $path.join WebDir, @htmlFile
  @backendFile = @backendFile || 'backend.js'
  @reqdir WebDir
  @reqdir @AssetDir
  do @loadDependencies
  await @emphase 'build:pre'
  await @emphase 'build'
  await @emphase 'build:post'
  return

Bundinha::page = (opts={}) ->
  opts.HasBackend = no
  opts.BuildId = @BuildId
  b = new Bundinha
  b.readPackage()
  Object.assign b, opts
  await do b.build

#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████

Bundinha::cmd_handle = ->
  try @readPackage()
  return do @cmd_init       if ( ARG.init is true )
  @readPackage()
  return do @cmd_push_clean if ( ARG.push and ARG.clean ) is true
  return do @cmd_push       if ( ARG.push is true )
  return do @cmd_deploy     if ( ARG.deploy is true )

  @shared BuildId: @BuildId = @BuildId || SHA512 new Date
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
  #{AppPackageName}-backend install:nginx;
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

Bundinha::npm = (spec)->
  # console.debug '@npm:req', spec
  @requireScope.push spec

Bundinha::npmDev = (spec)->
  # console.debug '@npm:dev', spec
  @requireDevScope.push spec

Bundinha::loadDependencies = ->
  module.paths.pushUnique $path.join BuildDir, 'node_modules'
  module.paths.pushUnique $path.join RootDir,  'node_modules'
  module.paths.pushUnique $path.join BunDir,   'node_modules'
  moduleName = (spec)-> if Array.isArray spec then spec[1] else spec
  filterForMissing = (scope,base)-> scope.map(moduleName).filter (spec)->
    return false if module.constructor.builtinModules.includes spec
    # console.log $path.join base,'node_modules', spec
    # console.log $fs.existsSync $path.join base,'node_modules', spec
    return false if $fs.existsSync $path.join base,'node_modules', spec
    true
  installScope = (scope,base,arg)->
    missing = filterForMissing scope, base
    if missing.length > 0
      console.debug ':::build:npm', missing
      process.chdir base
      $cp.spawnSync 'npm',['i',arg].concat(missing),stdio:'inherit'
    for dep in scope
      if Array.isArray dep
        continue if false is dep[0]
        $$[dep[0]] = require dep[1]
      else $$[dep] = require dep
      console.debug ' $load$ '.white.redBG.bold, dep
  installScope @requireDevScope, RootDir,   '--save-dev'
  installScope @requireScope,    BuildDir,  '--save-opt'
  return

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
  return do ok if $fs.mkdirSync dst

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
  # console.debug ' LOAD '.red.inverse, file, path
  $fs.readFileSync path, 'utf8'

Bundinha::linkAsset = (path)->
  path = $path.join.apply $path, path if Array.isArray path
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

$fs.touch = Bundinha::touch = require 'touch'

$fs.readUTF8Sync = (path)->
  path = $path.join.apply $path,path if Array.isArray path
  $fs.readFileSync path, 'utf8'

$fs.readBase64Sync = (path)->
  path = $path.join.apply $path,path if Array.isArray path
  $fs.readFileSync path, 'base64'

do Bundinha::nodePromises = ->
  $fs.stat$      = $util.promisify $fs.stat
  $fs.mkdir$     = $util.promisify $fs.mkdir
  $fs.exists$    = $util.promisify $fs.exists
  $fs.readdir$   = $util.promisify $fs.readdir
  $fs.readFile$  = $util.promisify $fs.readFile
  $fs.rename$    = $util.promisify $fs.rename
  $fs.writeFile$ = $util.promisify $fs.writeFile
  $fs.writeFileAsRoot$ = (path,data)->
    opts = $cp.spawnOpts $cp.spawnArgs '$','tee',path
    opts.stdio = ['pipe','pipe','pipe']
    s = $cp.spawn opts.args[0], opts.args.slice(1), opts
    s.stdin.write data; s.stdin.end()
    await $cp.awaitOutput s,opts
  $fs.unlink$    = $util.promisify $fs.unlink
  $cp.spawn$     = $util.promisify $cp.spawn
  $cp.spawn$$    = (cmd,args,opts)-> new Promise (resolve,reject)-> $cp.spawn(cmd,args,opts).on('error',reject).on('close',resolve)
  $cp.exec$      = $util.promisify $cp.exec
  $cp.run = (args...)->
    opts = $cp.spawnOpts $cp.spawnArgs ...args
    $cp.spawn opts.args[0], opts.args.slice(1), opts
    await $cp.awaitOutput s,opts
  $cp.run$ = (args...)->
    opts = $cp.spawnOpts $cp.spawnArgs ...args
    s = $cp.spawn opts.args[0], opts.args.slice(1), opts
    console.log '$run$'.white.redBG.bold, opts.args, opts.stdio[0] is process.stdin
    await $cp.awaitOutput s,opts
  $cp.spawnArgs = (args...)->
    # console.log ' :SPAWN:ARGS: ', @name, args
    if      1 <  args.length then opts = args:args
    else if 1 is args.length and args[0]?
      if Array.isArray args[0] then opts = args:args[0]
      else if args[0].match?   then opts = args:['sh','-c',args[0]]
      else if args[0].args?    then opts = args[0]
    throw new Error " EXEC:FAIL #{JSON.stringify args}" unless opts
    opts
  $cp.spawnOpts = (opts)-> ( ->
    args = opts.args
    if m = args[0]?.match /^([$#])([-eltx]+)?(@.*)?$/
      opts.needsRoot = true  if m[1] is '$' unless @virtual
      opts.needsInput = true if m[2]?.match '-'
      opts.log = true        if m[2]?.match 'l'
      opts.log = true        if m[2]?.match 'e'
      opts.preferTerm = true if m[2]?.match 't'
      opts.preferX11  = true if m[2]?.match 'x'
      args.shift()
    currentUser = $os.userInfo().username
    user = if opts.needsRoot then 'root' else opts.user || currentUser
    if opts.needsRoot and @localhost and currentUser isnt 'root'
      if process.env.DISPLAY? and process.env.SUDO_ASKPASS
           args = ['sudo','-A'].concat args
      else
        opts.needsInput = true
        args = ['sudo'].concat args
    args = ['--'].concat args if args.length > 0
    if @virtual
      if parent = Host.byId[@parent[0]]
        if parent.localhost
          args = ['lxc-attach','-n',@name].concat args
          if process.env.DISPLAY? and process.env.SUDO_ASKPASS
            args = ['sudo','-A'].concat args
          else
            opts.needsInput = true
            args = ['sudo'].concat args
        else
          user = parent.user || 'root'
          args = ['ssh','-o','LogLevel=QUIET','-t',user+"@"+parent.name,'lxc-attach','-n',@name].concat args
      else throw new Error "No parent for Host[#{@name}]"
    else if @localhost
      if opts.preferTerm
        if args.length > 0
          args = ['-e',"'#{args.slice(1).join ' '}'"]
        args = ['xterm'].concat args
      else args = args.slice 1
    else if @staticIP
      user = @user || 'root'
      args = ['ssh','-o','LogLevel=QUIET','-t',user+"@"+@canonical].concat args
    else
      user = @user || 'root'
      args = ['ssh','-o','LogLevel=QUIET','-t',user+"@"+@name].concat args
    opts.stdio = opts.stdio || [null,null,null]
    if Array.isArray opts.stdio
      opts.stdio[0] = process.stdin if opts.needsInput
      opts.stdio[1] = 'pipe' if opts.log or opts.pipe
      opts.stdio[2] = 'pipe' if opts.log
    opts.args = args
    opts.user = user #; console.log ' :SPAWN:1 '.black.greenBG.bold, @name, opts
    opts ).call opts.host || opts.host = name:$os.hostname(), localhost:true
  # console.log args.join(' ').gray, opts.stdio[0] id process.stdin
  $cp.awaitSilent = (s)-> new Promise (r,e)-> s.on('close',r).on('error',e)
  $cp.awaitOutput = (s,opts)-> new Promise (resolve)-> ( ->
    e = []; o = []; s.stderr.setEncoding 'utf8'
    if opts.log then s.stderr.on 'data', (data)=> data.trim().split('\n').map (line)=>
      return if '' is line = line.trim()
      e.push line; console.log "#{if @localhost then ":" else "@"}#{@name}:".red, line
    else s.stderr.on 'data', (data)-> e.push data
    if opts.pipe
      pipePromise = opts.pipe s
      s.on 'close', (status)->
        await pipePromise if opts.awaitChild
        resolve stderr:e.join(''), status:status
    else
      s.stdout.setEncoding 'utf8'
      if opts.log
           s.stdout.on 'data', (data)=> o.push data; data.trim().split('\n').map (line)=>
             return if '' is line = line.trim()
             e.push line; console.log "#{if @localhost then ":" else "@"}#{@name}:".yellow, line
      else s.stdout.on 'data', (data)-> o.push data
      s.on 'close', (status)-> resolve stdout:o.join(''), stderr:e.join(''), status:status
    return ).call opts.host || opts.host = name:$os.hostname(), localhost:true
  return

do Bundinha::arrayTools = ->
  return if Array::unique
  Object.filter = (o,c)->
    r = {}
    r[k] = v for k,v of o when c k,v
    r
  unless Array::flat then Object.defineProperty Array::,'flat',enumerable:false,value:->
    depth = if isNaN(arguments[0]) then 1 else Number(arguments[0])
    if depth then Array::reduce.call(this, ((acc, cur) ->
      if Array.isArray(cur) then acc.push.apply acc, Array::flat.call(cur, depth - 1)
      else acc.push cur
      acc
    ), []) else Array::slice.call(this)
  Object.defineProperty String::, 'arrayWrap', get:-> [@]
  Object.defineProperty Array::,  'arrayWrap', get:-> @
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

# ██████  ██   ██  █████  ███████ ███████ ██████
# ██   ██ ██   ██ ██   ██ ██      ██      ██   ██
# ██████  ███████ ███████ ███████ █████   ██████
# ██      ██   ██ ██   ██      ██ ██      ██   ██
# ██      ██   ██ ██   ██ ███████ ███████ ██   ██

$$.Phaser = (Spec)->
  Spec.phase = (key,prio,func)->
    ( func = prio; prio = 1 ) unless func?
    @phaseList.push k:key,p:prio,f:func
    return @
  Spec.emphase = (key)->
    list = @phaseList
      .filter (o)-> o.k is key
      .sort (a,b)-> a.p - b.p
    await Promise.all list.map (o)->
      try await o.f.call @
      catch error
        console.error ':phase'.red, (key+':'+o.p).bold
        console.error error
        console.debug "[phase-handler]", error, o.f.toCode().gray
        process.exit 1
    console.debug ':phase'.green, key.red
    return @
  Spec

Phaser Bundinha::
