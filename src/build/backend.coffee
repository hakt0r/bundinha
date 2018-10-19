# ██████   █████   ██████ ██   ██ ███████ ███    ██ ██████
# ██   ██ ██   ██ ██      ██  ██  ██      ████   ██ ██   ██
# ██████  ███████ ██      █████   █████   ██ ██  ██ ██   ██
# ██   ██ ██   ██ ██      ██  ██  ██      ██  ██ ██ ██   ██
# ██████  ██   ██  ██████ ██   ██ ███████ ██   ████ ██████

Bundinha::buildBackend = ->
  console.log ':build'.green, 'backend'.bold

  out = '( function(){ ' + (
    @serverHeader.map (i)-> i.toBareCode()
    .join('\n')
  ).toString() + '\n})()\n'

  scripts = []
  server = {}
  hooks = {}
  hooks[hook] = '' for hook in @server._hook

  for hook in @server._hook when ( code = @serverScope[hook] )?
    hooks[hook] = code
    delete @serverScope[hook]

  for name, api of @serverScope when typeof api isnt 'function'
    scripts.push "$$#{accessor name} = #{JSON.stringify api};"
    delete @serverScope[name]

  Object.assign server, @serverScope

  add = ''
  for name, cons of @shared.constant
    add +="\n$$#{accessor name} = #{JSON.stringify cons};"
  scripts.push add
  console.log 'shared'.green, Object.keys(@shared.constant).join(' ').gray

  plugins = ''; declaredPlugins = ['APP']
  for module, plugs of @pluginScope
    list = []
    plugins += "\n$$#{accessor module} = {plugin:{}};"
    for name, plug of plugs
      if plug.server?
        plugins += "\n$$#{accessor module}.plugin[#{JSON.stringify name}] = #{plug.server.toString()};"
      if plug.worker?
        plugins += "\nsetInterval(#{plug.worker.toString()},#{plug.interval || 1000 * 60 * 60});"
    console.log 'plugin'.green, module, list.join ' '

  apis = ''; apilist = []
  apis += @processAPI @shared.function, apilist
  apis += @processAPI server,           apilist

  scripts.push apis
  scripts.push plugins

  add = "\nAPP.defaultConfig = {};"
  for name, value of @configScope
    add +="""\nAPP.defaultConfig#{accessor name} = #{JSON.stringify value};"""
  scripts.push add
  console.log 'config'.green, Object.keys(@configScope).join(' ').gray

  for scope in ['db','public','private','group','command']
    add = "\nAPP#{accessor scope} = {};"
    for name, func of @[scope+'Scope']
      value = if typeof func is 'function' then func.toString() else JSON.stringify func
      add +="\nAPP#{accessor scope}#{accessor name} = #{value};"
    scripts.push add
    console.log scope.red, Object.keys(@[scope+'Scope']).join(' ').gray

  console.log 'server'.green, apilist.join(' ').gray

  { minify } = require 'uglify-es'

  out += scripts.join '\n'
  out += "\nAPP#{accessor hook} = async function(){" +  hooks[hook] + '\n};' for hook in @server._hook
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

  AppPackage.bin[AppPackageName + '-backend'] = './backend.js'
  # AppPackage.scripts['install-systemd'] = """sudo npm -g i .; #{} install-systemd"""

  $fs.writeFileSync $path.join(RootDir,'build','backend.js'), out
  $fs.writeFileSync $path.join(RootDir,'build','package.json'), JSON.stringify AppPackage, null, 2

  unless $fs.existsSync $path.join BuildDir, 'node_modules'
    $cp.execSync 'cd build; npm i'
