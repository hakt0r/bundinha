# ██████   █████   ██████ ██   ██ ███████ ███    ██ ██████
# ██   ██ ██   ██ ██      ██  ██  ██      ████   ██ ██   ██
# ██████  ███████ ██      █████   █████   ██ ██  ██ ██   ██
# ██   ██ ██   ██ ██      ██  ██  ██      ██  ██ ██ ██   ██
# ██████  ██   ██  ██████ ██   ██ ███████ ██   ████ ██████

Bundinha::backendHooks = ['preinit','init']
Bundinha::buildBackend = ->
  console.log ':build'.green, 'backend'.bold

  @command 'install-systemd', ->
    fs.writeFileSync '/etc/systemd/system/' + AppPackage.name + '.service', """
      [Unit]
      Description=#{AppPackage.name} backend

      [Service]
      ExecStart=#{process.execPath} #{__filename}

      [Install]
      WantedBy=multi-user.target
    """
    process.exit 0

  out = '(' + ( @serverHeader ).toString() + ')()\n'

  scripts = []
  server = {}
  hooks = {}
  hooks[hook] = '' for hook in @backendHooks

  for funcs in @serverScope
    for hook in @backendHooks when ( func = funcs[hook] )?
      hooks[hook] += "\n#{func.toBareCode()}"
      delete funcs[hook]
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
  apis += @processAPI @shared.function, apilist
  apis += @processAPI server,           apilist

  scripts.push apis
  scripts.push plugins

  for scope in ['config','db','public','private','command']
    add = "\nAPP#{accessor scope} = {};"
    for name, func of @[scope+'Scope']
      add +="\nAPP#{accessor scope}#{accessor name} = #{func.toString()};"
    scripts.push add
    console.log scope.green, Object.keys(@[scope+'Scope']).join(' ').gray

  console.log 'server'.green, apilist.join(' ').gray

  { minify } = require 'uglify-es'

  out += scripts.join '\n'
  out += "\nAPP#{accessor hook} = async function(){" +  hooks[hook] + '\n};' for hook in @backendHooks
  out += "\nAPP#{accessor hook}();" for hook in @backendHooks
  out += '\n'
  # out = minify(out).code

  out = "#!#{process.execPath}\n" + out # add shebang

  p = AppPackage
  delete p.devDependencies
  p.dependencies = {} unless p.dependencies
  p.dependencies[k] = v for k,v of BunPackage.dependencies when not p.dependencies[k]?
  p.bundinha = BunPackage.version
  p.name = p.name.replace /-devel$/,''

  AppPackage.bin[AppPackageName + '-backend'] = './backend.js'
  # AppPackage.scripts['install-systemd'] = """sudo npm -g i .; #{} install-systemd"""

  fs.writeFileSync path.join(RootDir,'build','backend.js'), out
  fs.writeFileSync path.join(RootDir,'build','package.json'), JSON.stringify AppPackage

  unless fs.existsSync path.join BuildDir, 'node_modules'
    cp.execSync 'cd build; npm i'
