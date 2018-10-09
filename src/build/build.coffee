# ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████   ██████  ██ ███████ ██████

$$.contentHash = (data)->
  # """sha256-#{forge.util.encode64 forge.md.sha256.create().update(data).digest().bytes()}"""
  """sha256-#{require('crypto').createHash('sha256').update(data).digest().toString 'base64'}"""

$$.accessor = (key)->
  return ".#{key}" if key.match /^[a-z0-9_]+$/i
  return "[#{JSON.stringify key}]"

Function::toCode = -> '('+ @toString() + '());\n'
Function::toBareCode = ->
  @toString()
  .replace(/^[^\{]+{/,'')
  .replace(/}$/,'')

Bundinha::build = ->
  @shared BuildId: SHA512 new Date
  console.log ':build'.green, ( BuildId ).yellow
  @reqdir  BuildDir
  @reqdir  path.join BuildDir, 'html'
  @require path.join AppPackageName, AppPackageName
  @WebRoot  = path.join RootDir,'build','html'
  @AssetDir = path.join RootDir,'build','html','app'
  do @buildLicense
  do @buildServiceWorker
  do @buildFrontend
  do @buildBackend

Bundinha::processAPI = (opts,apilist)->
  apis = ''
  descriptorFilters = ['prototype','name','length','caller','arguments']
  for name, api of opts
    debugger if name is 'MIME'
    func = api.toString()
    out = "\n$$.#{name} = #{func};"
    if api::? and typeof api is 'function'
      descs = Object.getOwnPropertyDescriptors api
      members = []
      for key, desc of descs when not descriptorFilters.includes key
        value = api[key]
        if typeof value is 'function'
          code = value.toString()
          add = if code.match /^async / then 'async ' else ''
          regex = new RegExp "  static #{add}#{key}\\("
          if func.match regex
            members.push '@'.green + key
            continue
          code = code.replace /^[^(]+/, 'function ' + key
          out += "\n#{name}#{accessor key} = #{add}#{code};"
          members.push '@'.yellow + key
        else
          out += "\n$$.#{name}#{accessor key} = #{JSON.stringify value};\n"
          members.push '@'.red + key
      console.log name.bold, members.join ' ' if members.length > 0
    apis += out
    apilist.push name
  debugger
  apis
