
@require 'bundinha/build/build'

@scope 'flag', (name,value=true)->
  @flagScope[name] = value

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

@shared Bundinha.global
