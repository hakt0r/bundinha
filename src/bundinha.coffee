###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

fs   = require 'fs'
path = require 'path'

global.$$ = global

$$.debug = no

$$.APP =
  fromSource: true
  require: $: [ 'os', 'fs', ['cp','child_process'], 'path', 'level', 'colors', ['forge','node-forge'] ]

require './dsl'

$$.RootDir   =  process.env.APP  || path.dirname module.parent.parent.filename
$$.BuildDir  = process.env.BASE || path.join RootDir, 'build'
$$.ConfigDir = process.env.CONF || path.join RootDir, 'config'
$$.BunDir    = path.dirname __dirname # in build mode

$$.BunPackage = JSON.parse fs.readFileSync (path.join BunDir,  'package.json'), 'utf8'
$$.AppPackage = JSON.parse fs.readFileSync (path.join RootDir, 'package.json'), 'utf8'
$$.AppPackageName = AppPackage.name.replace(/-devel$/,'')

setImmediate APP.buildPackage = ->
  do APP.loadDependencies
  $$.coffee = require 'coffeescript'
  console.log '------------------------------------'
  console.log ' ', AppPackage.name.green  + '/'.gray + AppPackage.version.gray,
              '['+ 'bundinha'.yellow + '/'.gray + BunPackage.version.gray+
              ( if APP.fromSource then '/dev'.red else '/rel'.green ) + ']'
  console.log '------------------------------------'
  $$.forge = require 'node-forge'
  APP.NodeLicense = await do APP.fetchLicense
  require './backend'
  require './build'
  process.exit 0

APP.loadDependencies = ->
  for dep in APP.require.$
    if Array.isArray dep
      $$[dep[0]] = require dep[1]
    else $$[dep] = require dep
  return

APP.shared
  SHA512: (value)->
    forge.md.sha512.create().update( value ).digest().toHex()
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
