
Object.hasMemberFunctions = (obj)->
  return false unless typeof obj is 'function'
  return false unless obj::?
  return false if obj::constructor.toString().match /^(async )?function/
  has = true for k,d of Object.getOwnPropertyDescriptors(obj)   when typeof d.value is 'function'
  has = true for k,d of Object.getOwnPropertyDescriptors(obj::) when typeof d.value is 'function' if obj::?
  has || false

Function::argumentDescriptor = ->
  return [] unless args = @toString().match /^[^(]+\(([^)]*)\)/
  args[1].split(',')
  .filter (arg)-> arg?
  .map    (arg)-> arg.replace(/\/\*.*\*\//, '').trim().split('=').map (d)-> d.trim()

Function::argumentList = -> @argumentDescriptor().map( (d)-> d.shift() ).filter( (d)-> d.length )

Function::_bind = Function::bind unless Function::_bind
Function::bind = (i,...a)->
  Object.assign Function::_bind.call(this,i,a), boundTo:[i,a]

@scope 'flag', (name,value=true)-> @flagScope[name] = value
@collectorScope 'client', ['preinit','init']
@collectorScope 'server', ['preinit','init']

@shared = (obj)->
  if Object.hasMemberFunctions obj
    o = {}; o[obj.name] = obj; obj = o
  for key, value of obj
    if typeof value is 'function'
      @client obj
      @server obj
      $$[key] = value
    else @shared.constant[key] = $$[key] = value
  return
@shared.constant = {}

@scope.plugin = (module,obj)->
  if typeof obj is 'string'
    name = obj
    obj = name:name
  else name = obj.name
  @pluginScope[module]        = mod = {} unless  mod = @pluginScope[module]
  @pluginScope[module][name] = plug = {} unless plug = mod[name]
  plug

Bundinha::processAPI = (opts,apiDesc)->
  out = ''
  for record in opts
    console.log name.red if name is 'PreCommand'
    [ name, value ] = record
    out += @compileValue "$$",name,value,'',apiDesc
  out

Bundinha::compileValue = (path,name,value,selector,apiDesc)->
  switch typeof value
    when 'function'
           @compileFunction path,name,value,selector,apiDesc
    when 'object'
      if Array.isArray value
           @compileArray    path,name,value,selector,apiDesc
      else if value?.constructor is Set
           @compileSet      path,name,value,selector,apiDesc
      else if value?.constructor is Map
           @compileMap      path,name,value,selector,apiDesc
      else @compileObject   path,name,value,selector,apiDesc
    else   "\n#{path}#{selector}#{accessor name} = #{JSON.stringify value};"

Bundinha::compileArray = (path,name,value,selector,apiDesc)->
  out = "\n#{path}#{selector}#{accessor name} = [];"
  for k,v of value
    if 'function' is typeof v
         out += "\n#{path}#{selector}#{accessor name}#{accessor k} = #{v.toString()};"
    else out += "\n#{path}#{selector}#{accessor name}#{accessor k} = #{JSON.stringify v};"
  out

Bundinha::compileMap = (path,name,value,selector,apiDesc)->
  "\n#{path}#{selector}#{accessor name} = new Map(#{JSON.stringify Array.from value});"

Bundinha::compileSet = (path,name,value,selector,apiDesc)->
  "\n#{path}#{selector}#{accessor name} = new Set(#{JSON.stringify Array.from value});"

Bundinha::compileFunction = (path,name,value,selector,apiDesc)->
  if Object.hasMemberFunctions value
    return @compileObject path,name,value,selector,apiDesc
  code = value.toString()
  add = if code.match /^async / then 'async ' else ''
  xdd = if selector is '' then 'static ' + add else add
  regex = new RegExp "  #{xdd}#{name}\\("
  if code.match regex
    members.push sym.green + name
    return
  code = code.replace /^[^(]+/, 'function ' + name.replace /[-:]/g, ''
  "\n#{path}#{selector}#{accessor name} = #{add}#{code};"

Bundinha::compileObject = (path,name,value,selector,apiDesc)->
  descriptorFilters = ['prototype','length','caller','arguments','constructor']
  func = if value.constructor is Object then '{}' else value.toString()
  out = "\n#{path}#{selector}#{accessor name} = #{func};"
  # prototype
  if value::?
    descs = Object.getOwnPropertyDescriptors value::
    out += @compileValue "#{path}#{selector}#{accessor name}",key,desc.value,'.prototype',apiDesc for key, desc of descs when not descriptorFilters.includes key
  # statics
  descs = Object.getOwnPropertyDescriptors value
  out   += @compileValue "#{path}#{selector}#{accessor name}",key,desc.value,'',  apiDesc for key, desc of descs when not descriptorFilters.includes key
  out
