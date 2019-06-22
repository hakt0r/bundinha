
# ███████  ██████ ██████  ██ ██████  ████████
# ██      ██      ██   ██ ██ ██   ██    ██
# ███████ ██      ██████  ██ ██████     ██
#      ██ ██      ██   ██ ██ ██         ██
# ███████  ██████ ██   ██ ██ ██         ██

@collectorScope 'script', {}, (target,prop,value)=>
  prop = 'app'     if 'string' is typeof value
  prop = 'asset'   if Array.isArray value
  value = value[0] if Array.isArray value
  @scriptScope[prop] = @scriptScope[prop] || []
  @scriptScope[prop].push value
  console.debug 'script'.yellow, prop.bold, value.toString().substring(0,99)
  true

@phase 'build:frontend:pre', @buildFrontendScriptsPre = =>
  @scriptFile = @scriptFile || @htmlFile.replace(/.html$/,'') + '.js'
  @scriptURI  = $path.join @AssetURL, @scriptFile

@phase 'build:frontend:post', @buildFrontendScripts = =>
  console.debug ':build'.green, 'scripts'.yellow.bold
  { minify } = require 'uglify-es' if @minify
  apilist = []
  scripts = []
  scripts.push """window.$$ = window; $$.isServer = ! ( $$.isClient = true ); $$.debug = false;"""
  scripts.push "$$.#{name} = #{JSON.stringify tpl};" for name, tpl of @shared.constant
  scripts.push "$$.BunWebWorker = #{JSON.stringify Object.keys(@webWorkerScope)};"
  await do =>
    # @script references
    @scriptScope.asset = @scriptScope.asset || []
    for href in @scriptScope.asset when href.match and url = href.match /^href:(.*)$/
      @insertScripts += """<script src="#{url[1].replace /^\//,''}"></script>"""
    if @concatScripts
      scripts.push ( await @loadAsset href ) + '\n' for href     in @scriptScope.asset when href.match and not href.match /^href:(.*)$/
      scripts.push ( script.join '\n'      ) + '\n' for k,script of @scriptScope       when k isnt 'asset'
    else
      for href in @scriptScope.asset
        continue if href.match and href.match /^href:/
        [file,data] = await @linkAsset href
        @insertScripts += """<script src="#{file.replace /^\//,''}"></script>"""
        @scriptHash.push "'" + ( contentHash data ) + "'"
        @asset.push file
      for k,v of @scriptScope
        scripts = scripts.concat v unless k is 'asset'
    # @plugin and @client references
    client = @clientScope
    for module, plugs of @pluginScope
      list = []
      client.init += "\n#{module}.plugin = {};"
      for name, plug of plugs
        if plug.clientInit
          client.init += "\n(#{plug.clientInit.toString()})()"
        if plug.client?
          client.init += "\n#{module}.plugin[#{JSON.stringify name}] = #{plug.client.toString()};"
        # if plug.clientWorker? TODO
      console.debug '::plug'.green, module, list.join ' '
    hook = {}
    for name in ['preinit','init']
      hook[name] = client[name] || ''
      delete client[name]

    scripts.push @processAPI ( Object.entries client), apilist
    scripts.push 'setTimeout(async ()=>{' + [hook.preinit,hook.init].join('\n') + '});'
    scripts = scripts.join '\n'
    scripts = minify(scripts,@minify).code if @minify
    return                                 if scripts.trim() is ''
    @scriptHash.push "'" + ( contentHash scripts ) + "'"
    if @inlineScripts is false
         $fs.writeFileSync $path.join(@AssetDir,@scriptFile), scripts
         @insertScripts += """<script src="#{@scriptURI.replace /^\//,''}"></script>"""
         @asset.push @scriptURI
         console.debug ':write'.green, @scriptFile.bold
    else @insertScripts += """<script>#{scripts}"</script>"""
  @scriptHash = @scriptHash.join ' '
