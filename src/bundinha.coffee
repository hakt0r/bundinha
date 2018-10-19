###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

setImmediate ->
  $$.APP = new Bundinha
  APP.cmd_handle()

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
    @fromSource = true
    @requireScope = ['os','util','fs',['cp','child_process'],'path','level','colors',['forge','node-forge']]
    @configScope = {}
    @cssScope = {}
    @dbScope = user:on, session:on
    @fallbackScope = {}
    @commandScope = {}
    @pluginScope = {}
    @privateScope = {}
    @groupScope = {}
    @publicScope = {}
    @scriptScope = []
    @clientScope = init:''
    @serverScope = []
    @shared.constant = {}
    @shared.function = {}
    @tplScope = []
    @webWorkerScope = {}
    @CollectorScope 'client'
    @CollectorScope 'server'
    Object.assign @, opts
    @shared Bundinha.global
    return

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

  $$.$forge  = require 'node-forge'
  $$.$coffee = require 'coffeescript'

  do @loadDependencies
  @require 'bundinha/client'
  @require 'bundinha/backend'

  console.log '------------------------------------'
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
              '['+ 'bundinha'.yellow + '/'.gray + BunPackage.version.gray+
              ( '/dev'.red ) + ']'
  console.log '------------------------------------'

  @NodeLicense = await do @fetchLicense

  do @build
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

Bundinha::cmd_push = ->
  $cp.execSync """
  tar cjvf - ./ | ssh #{ARG[1]} '
    cd /var/www/#{AppPackageName}; tar xjvf -;
    npm rebuild; killall node;
    PROTO=#{if ARG.secure then 'https' else 'http'} PORT=#{ARG.p || 9999} CHGID=#{ARG[2]} npm start >/dev/null 2>&1 &'
  """; return

Bundinha::cmd_push_clean = ->
  $cp.execSync """
  ssh #{ARG[0]} 'killall node; cd /var/www/; rm -rf #{AppPackageName}/*'
  """; return

require './build/lib'
require './build/build'
require './build/license'
require './build/frontend'
require './build/backend'

#  ██████  ██       ██████  ██████   █████  ██
# ██       ██      ██    ██ ██   ██ ██   ██ ██
# ██   ███ ██      ██    ██ ██████  ███████ ██
# ██    ██ ██      ██    ██ ██   ██ ██   ██ ██
#  ██████  ███████  ██████  ██████  ██   ██ ███████

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
