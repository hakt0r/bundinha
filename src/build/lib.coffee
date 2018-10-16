# ███    ███ ██  ██████  ██████   ██████
# ████  ████ ██ ██    ██ ██   ██ ██    ██
# ██ ████ ██ ██ ██    ██ ██████  ██    ██
# ██  ██  ██ ██ ██ ▄▄ ██ ██   ██ ██    ██
# ██      ██ ██  ██████  ██   ██  ██████
#                   ▀▀

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

Bundinha::miqro = ->
  window.$$$ = document
  window.$$  = window
  window.$   = (query)-> document.querySelector query
  $.all  = (query)-> Array.prototype.slice.call document.querySelectorAll query
  $.map  = (query,fn)-> Array.prototype.slice.call(document.querySelectorAll query).map(fn)
  $.make = (html,opts={})->
    html = if html.call? then html opts else html
    html = document.createRange().createContextualFragment html
    if ( node = html.childNodes ).length is 1 then node[0] else html
  SmoothEventTarget = (spec)-> Object.assign spec,
    events:(key)-> (( @EVENT || {} )[key] || [] )
    on: (key,func,opts)->
      @addEventListener key, func, opts
      (( @EVENT = @EVENT || @EVENT = {} )[key] || @EVENT[key] = [] ).push func
    off: (key,func)->
      @events(key).remove func
      @removeEventListener key, func
    kill: (key)-> @events(key).map @off.bind @, key
    once: (key,func)-> @on key, func, once:yes
    emit: (key,data)-> @dispatchEvent Object.assign( new Event key ), data: data
  SmoothEventTarget spec for spec in [$$,$$$,HTMLElement::]
  return

# ██████  ███████ ██
# ██   ██ ██      ██
# ██   ██ ███████ ██
# ██   ██      ██ ██
# ██████  ███████ ███████

Bundinha::require = (file)->
  # unless module.paths.includes(RootDir) then module.paths = module.paths.concat [
  #   RootDir, BunDir, RootDir + '/node_modules', BunDir + '/node_modules' ]
  mod = ( rest = file.split '/' ).shift()
  switch mod
    when 'bundinha'     then file = $path.join BunDir,  'src', rest.join '/'
    when AppPackageName then file = $path.join RootDir, 'src', rest.join '/'
    else return require file
  try
    if $fs.existsSync cfile = file + '.coffee'
         scpt = $fs.readFileSync cfile, 'utf8'
         scpt = $coffee.compile scpt, bare:on, filename:cfile
    else scpt = $fs.readFileSync file + '.js', 'utf8'
    func = new Function 'APP','require','__filename','__dirname',scpt
    func.call @, APP, require, file, $path.dirname file
  catch error
    console.log 'Bundinha::require'.red, error.message.bold
    console.log error if error
    process.exit 1

Bundinha.global = {}
Bundinha.global.SHA512 = (value)->
  $forge.md.sha512.create().update( value ).digest().toHex()
Bundinha.global.SHA1 = (value)->
  $forge.md.sha1.create().update( value ).digest().toHex()

Bundinha::command = (name,callback)->
  @commandScope[name] = callback

Bundinha::public = (path,callback)->
  @publicScope[path]  = callback
  @privateScope[path] = callback
  @groupScope[path]   = false

Bundinha::private = (path,group,callback)->
  unless callback
    callback = group; group = false
  @privateScope[path] = callback
  @groupScope[path]   = group

Bundinha::group = (path,group)->
  @groupScope[path] = group

Bundinha::db = (name)-> @dbScope[name] = true

Bundinha::css = (argsForPath...)->
  if argsForPath[0] is true
    @cssScope[argsForPath[1]] = argsForPath[2]
  else
    p = $path.join.apply path, argsForPath
    @cssScope[p] = true

Bundinha::config = (obj)->
  Object.assign @configScope, obj

Bundinha::shared = (obj)->
  # console.debug 'shared'.bold, obj
  client = @client()
  server = @server()
  for key, value of obj
    if typeof value is 'function'
      @shared.function[key] = value
      client[key]           = value
      $$[key]               = value
    else
      @shared.constant[key] = value
      $$[key]               = value
  return

Bundinha::server = (obj={})->
  @serverScope.push obj
  obj

Bundinha::client = (obj={})->
  @clientScope.push obj
  obj

Bundinha::script = (args...)->
  if $fs.existsSync p = $path.join.apply path, [RootDir].concat args
    @scriptScope.push p
  else if $fs.existsSync p = $path.join.apply path, [BunDir ].concat args
    @scriptScope.push p
  else @scriptScope.push args[0]

Bundinha::tpl = (isglobal,objOfTemplates)->
  if true is isglobal then Object.assign $$, objOfTemplates
  else objOfTemplates = isglobal
  objOfTemplates = {} unless objOfTemplates?
  @tplScope.push objOfTemplates
  objOfTemplates

Bundinha::plugin = (module,obj)->
  if typeof obj is 'string'
    name = obj
    obj = name:name
  else name = obj.name
  @pluginScope[module]        = mod = {} unless  mod = @pluginScope[module]
  @pluginScope[module][name] = plug = {} unless plug = mod[name]
  plug

Bundinha::webWorker = (name,sources...)->
  @client init:->
    loadWorker = (name)->
      src = document.getElementById(name).textContent
      blob = new Blob [src], type: 'text/javascript'
      $$[name] = new Worker window.URL.createObjectURL blob
    loadWorker name for name in BunWebWorker
    null
  @webWorkerScope[name] = @compileSources sources

# ████████  ██████   ██████  ██      ███████
#    ██    ██    ██ ██    ██ ██      ██
#    ██    ██    ██ ██    ██ ██      ███████
#    ██    ██    ██ ██    ██ ██           ██
#    ██     ██████   ██████  ███████ █████�█

Bundinha::loadDependencies = ->
  for dep in @requireScope
    if Array.isArray dep
      $$[dep[0]] = require dep[1]
    else $$[dep] = require dep
  return

Bundinha::touch = require 'touch'

Bundinha::parseConfig = (args...)->
  JSON.parse $fs.readFileSync $path.join.apply($path,args), 'utf8'

Bundinha::writeConfig = (cfg,args...)->
  $fs.writeFileSync $path.join.apply($path,args), JSON.stringify(cfg,null,2),'utf8'

Bundinha::symlink = (src,dst)->
  ok = -> console.log '::link'.green, $path.basename(src).yellow, '->'.yellow, dst.bold
  return do ok if $fs.existsSync dst
  return do ok if $fs.symlinkSync src, dst

Bundinha::reqdir = (dst...) ->
  dst = $path.join.apply path, dst
  ok = -> console.log ':::dir'.green, $path.basename(dst).yellow
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
      source = $path.join.apply path, source if Array.isArray source
      if source.match /.coffee$/
           out += $coffee.compile ( $fs.readFileSync source, 'utf8' ), bare:on
      else out += $fs.readFileSync source, 'utf8'
    else if typeof source is 'string'
      out += source;
    else throw new Error 'source of unhandled type', typeof source
  out

Bundinha::fetchLicense = -> new Promise (resolve,reject)->
  _log = console.log; _err = console.error # HACK: suppress legally's verbosity
  console.log = console.error = ->
  @npmLicenses = await require 'legally'
  console.log = _log; console.error = _err # HACK: suppress legally's verbosity
  nodeLicenseURL = "https://raw.githubusercontent.com/nodejs/node/master/LICENSE"
  data = ''
  require 'https'
  .get nodeLicenseURL, (resp)->
    resp.on 'data', (chunk) -> data += chunk.toString()
    resp.on 'end', -> resolve data
    resp.on 'error ', -> do reject
