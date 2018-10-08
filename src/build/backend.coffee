# ██████   █████   ██████ ██   ██ ███████ ███    ██ ██████
# ██   ██ ██   ██ ██      ██  ██  ██      ████   ██ ██   ██
# ██████  ███████ ██      █████   █████   ██ ██  ██ ██   ██
# ██   ██ ██   ██ ██      ██  ██  ██      ██  ██ ██ ██   ██
# ██████  ██   ██  ██████ ██   ██ ███████ ██   ████ ██████

Bundinha::buildBackend = ->
  console.log ':build'.green, 'backend'.bold

  out = '(' + ( @serverHeader ).toString() + ')()\n'

  server = init:''
  scripts = []

  for funcs in @serverScope
    if ( init = funcs.init )?
      delete funcs.init
      server.init += "\n(#{init.toString()})();"
    for name, api of funcs when typeof api isnt 'function'
      scripts.push "$$#{accessor name} = #{JSON.stringify api};"
      delete funcs[name]
    Object.assign server, funcs

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

  init = '(function(){' +  server.init + '\n })()'
  delete server.init

  apis += @processAPI @shared.function, apilist
  apis += @processAPI server, apilist

  scripts.push apis
  scripts.push plugins

  for scope in ['config','db','public','private']
    add = "\nAPP#{accessor scope+'Scope'} = {};"
    for name, func of @[scope+'Scope']
      add +="\nAPP#{accessor scope+'Scope'}#{accessor name} = #{func.toString()};"
    scripts.push add
    console.log scope.green, Object.keys(@[scope+'Scope']).join(' ').gray

  console.log 'server'.green, apilist.join(' ').gray

  { minify } = require 'uglify-es'

  out += scripts.join '\n'
  out += init + '\n'

  # out = minify(out).code

  p = AppPackage
  delete p.devDependencies
  p.dependencies = {} unless p.dependencies
  p.dependencies[k] = v for k,v of BunPackage.dependencies when not p.dependencies[k]?
  p.bundinha = BunPackage.version
  p.name = p.name.replace /-devel$/,''

  fs.writeFileSync path.join(RootDir,'build','backend.js'), out
  fs.writeFileSync path.join(RootDir,'build','package.json'), JSON.stringify AppPackage

  unless fs.existsSync path.join BuildDir, 'node_modules'
    cp.execSync 'cd build; npm i'
