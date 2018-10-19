# ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████   ██████  ██ ███████ ██████

Function::toCode = ->
  '('+ @toString().replace(/\n[ ]{4}/g,'\n') + '());\n'

Function::toBareCode = ->
  code = @toString()
  .replace(/^[^\{]+{/,'')
  .replace(/\n[ ]{4}/g,'\n')
  .replace(/^return /,'')
  .replace(/}$/,'')
  # console.log '###',code,'###'
  code

$$.contentHash = (data)->
  # """sha256-#{$forge.util.encode64 $forge.md.sha256.create().update(data).digest().bytes()}"""
  """sha256-#{require('crypto').createHash('sha256').update(data).digest().toString 'base64'}"""

$$.accessor = (key)->
  return ".#{key}" if key.match /^[a-z0-9_]+$/i
  return "[#{JSON.stringify key}]"

Bundinha::build = ->
  @shared BuildId: SHA512 new Date
  console.log ':build'.green, ( BuildId ).yellow
  @reqdir  BuildDir
  @reqdir  $path.join BuildDir, 'html'
  @require $path.join AppPackageName, AppPackageName
  @WebRoot  = $path.join RootDir,'build','html'
  @AssetDir = $path.join RootDir,'build','html','app'
  do @buildLicense
  do @buildServiceWorker if @buildServiceWorker?
  do @buildFrontend
  do @buildBackend

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
        if func.match regex
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
    debugger if name is 'MIME'
    func = api.toString()
    out = "\n$$.#{name} = #{func};"
    if api::? and typeof api is 'function'
      members = []
      out = _process_members_ out, members, api::, '.prototype'
      out = _process_members_ out, members, api
      console.log name.bold, members.join ' ' if members.length > 0
    apis += out
    apilist.push name
  debugger
  apis
