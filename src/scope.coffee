
# ███████  ██████  ██████  ██████  ███████ ███████
# ██      ██      ██    ██ ██   ██ ██      ██
# ███████ ██      ██    ██ ██████  █████   ███████
#      ██ ██      ██    ██ ██      ██           ██
# ███████  ██████  ██████  ██      ███████ ███████

@scopeScope = {}
@collectorScope = (scope,hook,doSet)->
  unless doSet or Array.isArray hook
    doSet = hook
    hook = []
  @[hookName = scope + 'Hook'] = hook
  scopeObject = @[scopeName = scope + 'Scope'] = {}
  scopeObject[cat] = '' for cat in hook
  @[scope] = new Proxy (->),
    get: (_target,_prop)=>
      return hook if _prop is '_hook'
      scopeObject[_prop]
    set: doSet = (_target,_prop,_value)=>
      # console.log scope.yellow.bold, _prop.bold if scope is 'server'
      if hook.includes _prop
           # console.log _value
           scopeObject[_prop] += _value.toBareCode()
      else scopeObject[_prop]  = _value
      true
    apply: (_target,_this,_args)=>
      [ obj ] = _args
      return @[scope] unless obj?
      name = obj.name
      if obj::?
           doSet null, name, @[scope][name] = obj
      else doSet null, k,    v     for k,v of obj
      @[scope]

@scope = new Proxy(
  (name, addFunction)=>
    scopeName = name + 'Scope'
    addFunction = addFunction || ( (key,value)=> @[scopeName][key] = value )
    @scopeScope[name] = scopeObject = @[scopeName] = @[scopeName] || {}
    @[name] = new Proxy addFunction,
      get: (_target,_prop)=> @[scopeName][_prop]
      set: (_target,_prop,_value)=> @[name] _prop, _value; true
  get: (_target,_prop)=> @[_prop + 'Scope']
  set: (_target,_prop,_value)=> @scope _prop, _value; true )

@arrayScope = new Proxy(
  (name, pushFunction)->
    scopeName = name + 'Scope'
    pushFunction = pushFunction || ( (value)=> @[scopeName].push value )
    @scopeScope[name] = @[scopeName] = @[scopeName] || []
    @[name] = pushFunction
  get: (_target,_prop)=> @[_prop + 'Scope']
  set: (_target,_prop,_value)=> @arrayScope _prop, _value; true )

# ███████ ██   ██  █████  ██████  ███████ ██████
# ██      ██   ██ ██   ██ ██   ██ ██      ██   ██
# ███████ ███████ ███████ ██████  █████   ██   ██
#      ██ ██   ██ ██   ██ ██   ██ ██      ██   ██
# ███████ ██   ██ ██   ██ ██   ██ ███████ ██████

@scope 'flag', (name,value=true)-> @flagScope[name] = value

@shared = (obj)->
  client = @client()
  server = @server()
  for key, value of obj
    if typeof value is 'function'
         @shared.function[key] = client[key] = $$[key] = value
    else @shared.constant[key] = $$[key] = value
  return
@shared.constant = {}
@shared.function = {}

@scope.plugin = (module,obj)->
  if typeof obj is 'string'
    name = obj
    obj = name:name
  else name = obj.name
  @pluginScope[module]        = mod = {} unless  mod = @pluginScope[module]
  @pluginScope[module][name] = plug = {} unless plug = mod[name]
  plug

# ██████   █████   ██████ ██   ██ ███████ ███    ██ ██████
# ██   ██ ██   ██ ██      ██  ██  ██      ████   ██ ██   ██
# ██████  ███████ ██      █████   █████   ██ ██  ██ ██   ██
# ██   ██ ██   ██ ██      ██  ██  ██      ██  ██ ██ ██   ██
# ██████  ██   ██  ██████ ██   ██ ███████ ██   ████ ██████

@collectorScope 'server', ['preinit','init']
@scope 'command'
@scope 'group'

@scope.get = (path,group,callback)->
  unless callback
    callback = group
    group = false
  path = path.toString() if path.exec?
  @getScope[path] = callback
  @groupScope[path]   = group

@scope.public = (path,callback)->
  @publicScope[path] = callback
  @groupScope[path]  = false

@scope.private = (path,group,callback)->
  unless callback
    callback = group
    group = false
  @privateScope[path] = callback
  @groupScope[path]   = group

@scope.group = (path,group)->
  @groupScope[path] = group

@scope.db = (name)-> @dbScope[name] = true

@scope.devConfig = (obj)->
  Object.assign @, obj
  Object.assign @configScope, obj
@scope.config = (obj)->
  Object.assign @configScope, obj

# ███████ ██████   ██████  ███    ██ ████████ ███████ ███    ██ ██████
# ██      ██   ██ ██    ██ ████   ██    ██    ██      ████   ██ ██   ██
# █████   ██████  ██    ██ ██ ██  ██    ██    █████   ██ ██  ██ ██   ██
# ██      ██   ██ ██    ██ ██  ██ ██    ██    ██      ██  ██ ██ ██   ██
# ██      ██   ██  ██████  ██   ████    ██    ███████ ██   ████ ██████

@collectorScope 'client',  ['preinit','init']
@collectorScope 'html',    ['head','body']

@arrayScope.script = (args...)->
  if $fs.existsSync p = $path.join.apply path, [RootDir].concat args
    @scriptScope.push p
  else if $fs.existsSync p = $path.join.apply path, [BunDir].concat args
    @scriptScope.push p
  else @scriptScope.push args[0]

@arrayScope.tpl = (isglobal,objOfTemplates)->
  if true is isglobal then Object.assign $$, objOfTemplates
  else objOfTemplates = isglobal
  objOfTemplates = {} unless objOfTemplates?
  @tplScope.push objOfTemplates
  objOfTemplates

@scope.webWorker = (name,sources...)->
  @client.init = ->
    loadWorker = (name)->
      src = document.getElementById(name).textContent
      blob = new Blob [src], type: 'text/javascript'
      $$[name] = new Worker window.URL.createObjectURL blob
    loadWorker name for name in BunWebWorker
    return
  @webWorkerScope[name] = @compileSources sources

@scope.css = (args...)->
  if args[0].match and args[0].match /^href:/
    @cssScope[args[0].substring 5] = 'href'
  else if args[0] is true
    @cssScope[args[1]] = args[2]
  else
    p = $path.join.apply path, args
    @cssScope[p] = true

# ██████  ██    ██ ██ ██   ████████ ██ ███    ██ ███████
# ██   ██ ██    ██ ██ ██      ██    ██ ████   ██ ██
# ██████  ██    ██ ██ ██      ██    ██ ██ ██  ██ ███████
# ██   ██ ██    ██ ██ ██      ██    ██ ██  ██ ██      ██
# ██████   ██████  ██ ███████ ██    ██ ██   ████ ███████

@shared Bundinha.global
