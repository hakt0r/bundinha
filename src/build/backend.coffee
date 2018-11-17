
return if @HasBackend is false
@HasBackend = true

@phase 'build',9999,=>
  await do @buildBackend
  return

# ███████  ██████  ██████  ██████  ███████ ███████
# ██      ██      ██    ██ ██   ██ ██      ██
# ███████ ██      ██    ██ ██████  █████   ███████
#      ██ ██      ██    ██ ██      ██           ██
# ███████  ██████  ██████  ██      ███████ ███████

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

@scope.devConfig = (obj)->
  Object.assign @, obj
  Object.assign @configScope, obj
@scope.config = (obj)->
  Object.assign @configScope, obj

# ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████   ██████  ██ ███████ ██████

Bundinha::buildBackend = ->
  console.log ':build'.green, 'backend'.bold, @backendFile.yellow

  out = '( function(){ ' + (
    @serverHeader.map (i)-> i.toBareCode()
    .join('\n')
  ).toString() + '\n})()\n'

  scripts = []
  server = {}
  hooks = {}
  hooks[hook] = '' for hook in @serverHook

  # FLAGS
  scripts.push "$$.FLAG = {};"
  for name, value of @flagScope
    scripts.push "FLAG#{accessor name} = #{JSON.stringify value};"

  # PULL HOOKS
  for hook in @serverHook when ( code = @serverScope[hook] )?
    hooks[hook] = code
    delete @serverScope[hook]

  # CONSTANTS
  for name, api of @serverScope when typeof api isnt 'function'
    scripts.push "$$#{accessor name} = #{JSON.stringify api};"
    delete @serverScope[name]

  Object.assign server, @serverScope

  add = ''
  for name, cons of @shared.constant
    add +="\n$$#{accessor name} = #{JSON.stringify cons};"
  scripts.push add
  console.debug 'shared'.green, Object.keys(@shared.constant).join(' ').gray

  plugins = ''; declaredPlugins = ['APP']
  for module, plugs of @pluginScope
    list = []
    plugins += "\n$$#{accessor module} = {plugin:{}};"
    for name, plug of plugs
      if plug.server?
        plugins += "\n$$#{accessor module}.plugin[#{JSON.stringify name}] = #{plug.server.toString()};"
      if plug.worker?
        plugins += "\nsetInterval(#{plug.worker.toString()},#{plug.interval || 1000 * 60 * 60});"
    console.debug 'plugin'.green, module, list.join ' '

  apis = ''; apilist = []
  apis += @processAPI @shared.function, apilist
  apis += @processAPI server,           apilist

  scripts.push apis
  scripts.push plugins

  add = "\nAPP.defaultConfig = {};"
  for name, value of @configScope
    add +="""\nAPP.defaultConfig#{accessor name} = #{JSON.stringify value};"""
  scripts.push add
  console.debug 'config'.green, Object.keys(@configScope).join(' ').gray

  for scope in ['db','get','public','private','group','command']
    add = "\nAPP#{accessor scope} = {};"
    for name, func of @[scope+'Scope']
      value = if typeof func is 'function' then func.toString() else JSON.stringify func
      add +="\nAPP#{accessor scope}#{accessor name} = #{value};"
    scripts.push add
    console.debug scope.red, Object.keys(@[scope+'Scope']).join(' ').gray

  console.debug 'server'.green, apilist.join(' ').gray

  { minify } = require 'uglify-es'

  out += scripts.join '\n'
  out += "\nAPP#{accessor hook} = async function(){" +  hooks[hook] + '\n};' for hook in @serverHook

  out += "\nAPP.init();"
  out += '\n'
  # out = minify(out).code

  out = "#!#{process.execPath}\n" + out # add shebang

  p = AppPackage
  delete p.devDependencies
  p.dependencies = {} unless p.dependencies
  for k,v of BunPackage.scripts when not p.scripts[k]?
    p.scripts[k] = v
  for k,v of p.scripts when v.match 'bundinha'
    v = v.replace 'build/', ''
    if      v is 'bundinha' then delete p.scripts[k]
    else if v is 'bundinha push' then delete p.scripts[k]
    else p.scripts[k] = v.replace 'bundinha; ', ''
  for k,v of BunPackage.dependencies when not p.dependencies[k]?
    p.dependencies[k] = v
  p.bundinha = BunPackage.version
  p.name = p.name.replace /-devel$/,''

  AppPackage.main = './backend.js'
  AppPackage.bin[AppPackageName+'-backend'] = './backend.js'
  # AppPackage.scripts['install-systemd'] = """sudo npm -g i .; #{} install-systemd"""

  $fs.writeFileSync $path.join(RootDir,'build', @backendFile ), out
  $fs.writeFileSync $path.join(RootDir,'build','package.json'), JSON.stringify AppPackage, null, 2

  unless $fs.existsSync $path.join BuildDir, 'node_modules'
    $cp.execSync 'cd build; npm i'

  return
