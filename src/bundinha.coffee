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

$$.Bundinha = class Bundinha
  constructor:(opts)->
    $$.BUND = @ unless $$.BUND?
    @fromSource = true
    @requireScope = ['os','util','fs',['cp','child_process'],'path','level','colors',['forge','node-forge']]
    Object.assign @, opts
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

Bundinha::cmd_handle = ->
  return do @cmd_init       if ( ARG.init is true )
  $$.BunPackage = @parseConfig BunDir,  'package.json'
  $$.AppPackage = @parseConfig RootDir, 'package.json'
  $$.AppPackageName = AppPackage.name.replace(/-devel$/,'')
  return do @cmd_push_clean if ( ARG.push and ARG.clean ) is true
  return do @cmd_push       if ( ARG.push is true )
  return do @cmd_deploy     if ( ARG.deploy is true )
  console.log '------------------------------------'
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
              '['+ 'bundinha'.yellow + '/'.gray + BunPackage.version.gray+
              ( '/dev'.red ) + ']'
  console.log '------------------------------------'
  $$.$forge  = require 'node-forge'
  @require 'bundinha/build/build'
  @require 'bundinha/build/lib'
  @require 'bundinha/build/scope'
  @require 'bundinha/build/license'
  @require 'bundinha/build/frontend'
  @require 'bundinha/build/backend'
  do @loadDependencies
  @require 'bundinha/client'
  @require 'bundinha/backend'
  await do @build
  process.exit 0

Bundinha::cmd_init = ->
  console.log 'init'.yellow, RootDir
  @reqdir RootDir, 'src'
  @reqdir RootDir, 'config'
  unless $fs.existsSync $path.join RootDir, 'package.json'
    $cp.execSync 'npm init'
  p = @parseConfig RootDir, 'package.json'
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
  Object.assign @, JSON.parse $fs.readFileSync $path.join ConfigDir, AppPackageName + '.json'
  [ url, user, host, path ] = @Deploy.url.match /^([^@]+)@([^:]+):(.*)$/
  process.stderr.write 'push'.yellow + ' ' + user.red.bold + '@' + host.green + ':' + path.gray
  result = $cp.spawnSync 'rsync',['-avzhL','build/',@Deploy.url]
  console.log if result.status is 0 then ' success'.green.bold else ' success'.red.bold
  process.exit result.status if final

Bundinha::cmd_deploy = ->
  @cmd_push no; [ url, user, host, path ] = @Deploy.url.match /^([^@]+)@([^:]+):(.*)$/
  $cp.spawnSync 'ssh',[user+'@'+host,"""
  cd '#{path}'; npm i -g .; #{AppPackageName}-backend install-nginx;
  systemctl reload nginx; systemctl restart tix
  """], stdio:'inherit'

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

Bundinha::require = (file)->
  # unless module.paths.includes(RootDir) then module.paths = module.paths.concat [
  #   RootDir, BunDir, RootDir + '/node_modules', BunDir + '/node_modules' ]
  mod = ( rest = file.split '/' ).shift()
  switch mod
    when 'bundinha'
      console.log 'depend'.green.bold, file.bold
      file = $path.join BunDir,  'src', rest.join '/'
    when AppPackageName
      console.log 'depend'.yellow.bold, file.bold
      file = $path.join RootDir, 'src', rest.join '/'
    else return require file
  try
    if $fs.existsSync cfile = file + '.coffee'
         scpt = $fs.readFileSync cfile, 'utf8'
         scpt = $coffee.compile scpt, bare:on, filename:cfile
    else scpt = $fs.readFileSync file + '.js', 'utf8'
    func = new Function 'APP','require','__filename','__dirname',scpt
    func.call @, @, require, file, $path.dirname file
  catch error
    if error.stack
      line = parseInt error.stack.split('\n')[1].split(':')[1]
      col  = try parseInt error.stack.split('\n')[1].split(':')[2].split(')')[0] catch e then 0
      console.log 'require'.red.bold, [file.bold,line,col].join ':'
    console.log ' ', error.message.bold
    console.log '>',
      scpt.split('\n')[line-3].substring(0,col-2).yellow
      scpt.split('\n')[line-3].substring(col-1,col).red
      scpt.split('\n')[line-3].substring(col+1).yellow
    process.exit 1

#  ██████  ██       ██████  ██████   █████  ██      ███████
# ██       ██      ██    ██ ██   ██ ██   ██ ██      ██
# ██   ███ ██      ██    ██ ██████  ███████ ██      ███████
# ██    ██ ██      ██    ██ ██   ██ ██   ██ ██           ██
#  ██████  ███████  ██████  ██████  ██   ██ ███████ ███████

Bundinha.global = {}

Bundinha.global.SHA512 = (value)->
  $forge.md.sha512.create().update( value ).digest().toHex()

Bundinha.global.SHA1 = (value)->
  $forge.md.sha1.create().update( value ).digest().toHex()

Bundinha.global.escapeHTML = (str)->
  String(str)
  .replace /&/g,  '&amp;'
  .replace /</g,  '&lt;'
  .replace />/g,  '&gt;'
  .replace /"/g,  '&#039;'
  .replace /'/g,  '&x27;'
  .replace /\//g, '&x2F;'

Bundinha.global.toAttr = (str)->
  alphanumeric = /[a-zA-Z0-9]/
  ( for char in str
      if char.match alphanumeric then char
      else '&#' + char.charCodeAt(0).toString(16) + ';'
  ).join ''
