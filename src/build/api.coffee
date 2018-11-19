
# ███████ ██   ██  █████  ██████  ███████ ██████
# ██      ██   ██ ██   ██ ██   ██ ██      ██   ██
# ███████ ███████ ███████ ██████  █████   ██   ██
#      ██ ██   ██ ██   ██ ██   ██ ██      ██   ██
# ███████ ██   ██ ██   ██ ██   ██ ███████ ██████

@scope 'flag', (name,value=true)-> @flagScope[name] = value
@collectorScope 'client', ['preinit','init']
@collectorScope 'server', ['preinit','init']

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
      else if typeof value is 'object' and typeof (vals = Object.values value)[0] is 'function'
        if Array.isArray value
          out += "\n$$.#{name}#{selector}#{accessor key} = [];\n"
          out += "\n$$.#{name}#{selector}#{accessor key}#{accessor k} = #{v.toString()};\n" for k,v of value
        else
          out += "\n$$.#{name}#{selector}#{accessor key} = {};\n"
          out += "\n$$.#{name}#{selector}#{accessor key}#{accessor k} = #{v.toString()};\n" for k,v of value
      else
        out += "\n$$.#{name}#{selector}#{accessor key} = #{JSON.stringify value};\n"
        members.push sym.gray + key
    out
  for name, api of opts
    # debugger if name is 'MIME'
    if typeof api is 'function'
      func = api.toString()
      out = "\n$$#{accessor name} = #{func};"
      members = []
      if api::?
        out = _process_members_ out, members, api::, '.prototype'
        out = _process_members_ out, members, api
      console.debug name.bold, members.join ' ' if members.length > 0
    else out = "\n$$#{accessor name} = #{JSON.stringify api};"
    apis += out
    apilist.push name
  apis
