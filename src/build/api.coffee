
# ███████ ██   ██  █████  ██████  ███████ ██████
# ██      ██   ██ ██   ██ ██   ██ ██      ██   ██
# ███████ ███████ ███████ ██████  █████   ██   ██
#      ██ ██   ██ ██   ██ ██   ██ ██      ██   ██
# ███████ ██   ██ ██   ██ ██   ██ ███████ ██████

@scope 'flag', (name,value=true)-> @flagScope[name] = value
@collectorScope 'client', ['preinit','init']
@collectorScope 'server', ['preinit','init']

Object.hasMemberFunctions = (obj)->
  return false unless typeof obj is 'function'
  return false unless obj::?
  return false if obj::constructor.toString().match /^(async )?function/
  has = true for k,d of Object.getOwnPropertyDescriptors(obj)   when typeof d.value is 'function'
  has = true for k,d of Object.getOwnPropertyDescriptors(obj::) when typeof d.value is 'function' if obj::?
  has || false

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

Function::argumentDescriptor = ->
  return [] unless args = @toString().match /^[^(]+\(([^)]*)\)/
  args[1].split(',')
  .filter (arg)-> arg?
  .map    (arg)-> arg.replace(/\/\*.*\*\//, '').trim().split('=').map (d)-> d.trim()
Function::argumentList = -> @argumentDescriptor().map( (d)-> d.shift() ).filter( (d)-> d.length )

Bundinha::processAPI = (opts,apilist)->
  apis = ''; name = null
  descriptorFilters = ['prototype','name','length','caller','arguments','constructor']
  _process_members_ = (path,name,out,members,sublclasses,api,selector='')->
    descs = Object.getOwnPropertyDescriptors api
    sym = if selector is '' then '@' else '::'
    for key, desc of descs when not descriptorFilters.includes key
      value = api[key]
      if typeof value is 'function'
        if ( value::? and value::constructor? ) and key is value::constructor.name
          sublclasses.push [key,value]
        else
          code = value.toString()
          add = if code.match /^async / then 'async ' else ''
          xdd = if selector is '' then 'static ' + add else add
          regex = new RegExp "  #{xdd}#{key}\\("
          if code.match regex
            members.push sym.green + key
            continue
          code = code.replace /^[^(]+/, 'function ' + key
          out += "\n#{path.substring 1}#{selector}#{accessor key} = #{add}#{code};"
          members.push "#{sym.yellow}#{key}(#{value.argumentList().join(',').gray})"
      else if typeof value is 'object' and typeof (vals = Object.values value)[0] is 'function'
        if Array.isArray value
          out += "\n#{path.substring 1}#{selector}#{accessor key} = [];\n"
          out += "\n#{path.substring 1}#{selector}#{accessor key}#{accessor k} = #{v.toString()};\n" for k,v of value
        else
          out += "\n#{path.substring 1}#{selector}#{accessor key} = {};\n"
          out += "\n#{path.substring 1}#{selector}#{accessor key}#{accessor k} = #{v.toString()};\n" for k,v of value
      else
        out += "\n$$.#{name}#{selector}#{accessor key} = #{JSON.stringify value};\n"
        members.push sym.gray + key
    out
  _process_class_ = (path,name,api,classes)->
    func = api.toString()
    out = "\n$$#{path} = #{func};"
    members = []
    sublclasses = []
    if api::?
      out = _process_members_ path, name, out, members, sublclasses, api::, '.prototype'
      out = _process_members_ path, name, out, members, sublclasses, api
    if members.length > 0
         classes.push "#{path.substring(1).bold.red}(#{})", members.join ' '
    else classes.push "#{path.substring(1).bold.red}(#{})"
    for sub in sublclasses
      [key,value] = sub
      out += _process_class_ "#{path}#{accessor key}", key, value, classes
    return out
  funcs = []; classes = []
  for record in opts
    [ name, api ] = record
    if typeof api is 'function'
      if Object.hasMemberFunctions api
        out = _process_class_ accessor(name), name, api, classes
      else
        funcs.push "#{name.yellow}(#{api.argumentList().join(',').gray})"
        func = api.toString()
        out = "\n$$#{accessor name} = #{func};"
    else out = "\n$$#{accessor name} = #{JSON.stringify api};"
    apis += out
    apilist.push name
  console.log funcs.join ' '
  console.log classes.join ' '
  apis
