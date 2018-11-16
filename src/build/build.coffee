
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

@require 'bundinha/build/backend'
@require 'bundinha/build/frontend'
@require 'bundinha/build/shared'

# ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████   ██████  ██ ███████ ██████

Bundinha::processAPI = (opts,apilist)->
  apis = ''; name = null
  descriptorFilters = ['prototype','name','length','caller','arguments','constructor']
  _process_members_ = (out,members,api,selector='')->
    descs = Object.getOwnPropertyDescriptors api
    sym = if  selector is '' then '@' else '::'
    for key, desc of descs when not descriptorFilters.includes key
      value = api[key]
      if typeof value is 'function'
        code = value.toString()
        add = if code.match /^async / then 'async ' else ''
        xdd = if selector is '' then 'static ' + add else add
        regex = new RegExp "  #{xdd}#{key}\\("
        if code.match regex
          members.push sym.green + key
          continue
        code = code.replace /^[^(]+/, 'function ' + key
        out += "\n#{name}#{selector}#{accessor key} = #{add}#{code};"
        members.push sym.yellow + key
      else
        out += "\n$$.#{name}#{selector}#{accessor key} = #{JSON.stringify value};\n"
        members.push sym.gray + key
    out
  for name, api of opts
    # debugger if name is 'MIME'
    func = api.toString()
    out = "\n$$.#{name} = #{func};"
    if api::? and typeof api is 'function'
      members = []
      out = _process_members_ out, members, api::, '.prototype'
      out = _process_members_ out, members, api
      console.debug name.bold, members.join ' ' if members.length > 0
    apis += out
    apilist.push name
  apis

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

# ████████  ██████   ██████  ██      ███████
#    ██    ██    ██ ██    ██ ██      ██
#    ██    ██    ██ ██    ██ ██      ███████
#    ██    ██    ██ ██    ██ ██           ██
#    ██     ██████   ██████  ███████ █████�█

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

$$.contentHash = (data)->
  # """sha256-#{$forge.util.encode64 $forge.md.sha256.create().update(data).digest().bytes()}"""
  """sha256-#{require('crypto').createHash('sha256').update(data).digest().toString 'base64'}"""

$$.accessor = (key)->
  return ".#{key}" if key.match /^[a-z0-9_]+$/i
  return "[#{JSON.stringify key}]"

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

Bundinha::reqdir = (dst...) ->
  dst = $path.join.apply $path, dst
  ok = -> console.debug ':::dir'.green, $path.basename(dst).yellow
  return do ok if $fs.existsSync dst
  return do ok if $fs.mkdirSync dst
