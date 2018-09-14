
# ██████  ███████ ██
# ██   ██ ██      ██
# ██   ██ ███████ ██
# ██   ██      ██ ██
# ██████  ███████ ███████

APP.public = (path,callback,fallback)->
  APP.public.$[path] = callback
  APP.private.$[path] = callback
  APP.fallback.$[path] = fallback if fallback

APP.private = (path,callback,fallback)->
  APP.private.$[path] = callback
  APP.fallback.$[path] = fallback if fallback

APP.fallback = (path,fallback)->
  APP.fallback.$[path] = fallback

APP.public.$   = {}
APP.private.$  = {}
APP.fallback.$ = {}

APP.db = (name)-> APP.db.$[name] = true
APP.db.$ = user:on, session:on

APP.css = (argsForPath...)->
  p = path.join.apply path, argsForPath
  APP.css.$[p] = true
APP.css.$ = {}

APP.config = (objectOfConfigFunctions)->
  Object.assign APP.config.$, objectOfConfigFunctions
APP.config.$ = {}

APP.shared = (objOfValues)->
  clientApi = APP.clientApi()
  serverApi = APP.serverApi()
  for key, value of objOfValues
    if typeof value is 'function'
      APP.sharedFunction[key] = value
      clientApi[key]          = value
      $$[key]                 = value
    else
      APP.sharedConstant[key] = value
      $$[key]                 = value
APP.sharedConstant = {}
APP.sharedFunction = {}

APP.script = (args...)->
  p = path.join.apply path, [BunDir].concat args
  APP.script.$.push p
APP.script.$ = []

APP.tpl = (isglobal,objOfTemplates)->
  if true is isglobal then Object.assign $$, objOfTemplates
  else objOfTemplates = isglobal
  objOfTemplates = {} unless objOfTemplates?
  APP.tpl.$.push objOfTemplates
  objOfTemplates
APP.tpl.$ = []

APP.clientApi = (objOfClientSideFunctions)->
  objOfClientSideFunctions = {} unless objOfClientSideFunctions?
  APP.clientApi.$.push objOfClientSideFunctions
  objOfClientSideFunctions
APP.clientApi.$ = []

APP.serverApi = (objOfClientSideFunctions)->
  objOfClientSideFunctions = {} unless objOfClientSideFunctions?
  APP.serverApi.$.push objOfClientSideFunctions
  objOfClientSideFunctions
APP.serverApi.$ = []


APP.plugin = (module,obj)->
  if typeof obj is 'string'
    name = obj
    obj = name:name
  else name = obj.name
  APP.plugin.$[module]        = mod = {} unless  mod = APP.plugin.$[module]
  APP.plugin.$[module][name] = plug = {} unless plug = mod[name]
  plug
APP.plugin.$ = {}

APP.webWorker = (name,sources...)->
  APP.clientApi init:->
    loadWorker = (name)->
      src = document.getElementById(name).textContent
      blob = new Blob [src], type: 'text/javascript'
      $$[name] = new Worker window.URL.createObjectURL blob
    loadWorker name for name in BunWebWorker
    null
  APP.webWorker.$[name] = APP.compileSources sources
APP.webWorker.$ = {}

# ██████  ██    ██ ██ ██      ██████  ██      ██ ██████
# ██   ██ ██    ██ ██ ██      ██   ██ ██      ██ ██   ██
# ██████  ██    ██ ██ ██      ██   ██ ██      ██ ██████
# ██   ██ ██    ██ ██ ██      ██   ██ ██      ██ ██   ██
# ██████   ██████  ██ ███████ ██████  ███████ ██ ██████

Array::unique = ->
  @filter (value, index, self) -> self.indexOf(value) == index

APP.touch = require 'touch'

APP.symlink = (src,dst)->
  ok = -> console.log '::link'.green, path.basename(src).yellow, '->'.yellow, dst.bold
  return do ok if fs.existsSync dst
  return do ok if fs.symlinkSync src, dst

APP.reqdir = (dst) ->
  ok = -> console.log ':::dir'.green, path.basename(dst).yellow
  return do ok if fs.existsSync dst
  return do ok if fs.mkdirSync dst

APP.compileSources = (sources)->
  out = ''
  for source in sources
    if typeof source is 'function'
      source = source.toString().split '\n'
      source.shift(); source.pop(); source.pop()
      source = source.join '\n'
      out += source
    else if Array.isArray source
      source = path.join.apply path, source if Array.isArray source
      if source.match /.coffee$/
           out += coffee.compile ( fs.readFileSync source, 'utf8' ), bare:on
      else out += fs.readFileSync source, 'utf8'
    else if typeof source is 'string'
      out += source;
    else throw new Error 'source of unhandled type', typeof source
  out

APP.fetchLicense = -> new Promise (resolve,reject)->
  _log = console.log; _err = console.error # HACK: suppress legally's verbosity
  console.log = console.error = ->
  APP.npmLicenses = await require 'legally'
  console.log = _log; console.error = _err # HACK: suppress legally's verbosity
  nodeLicenseURL = "https://raw.githubusercontent.com/nodejs/node/master/LICENSE"
  data = ''
  require 'https'
  .get nodeLicenseURL, (resp)->
    resp.on 'data', (chunk) -> data += chunk.toString()
    resp.on 'end', -> resolve data
    resp.on 'error ', -> do reject
