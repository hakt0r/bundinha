
@HasFrontend = if @HasFrontend? then @HasFrontend else true

# ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████   ██████  ██ ███████ ██████

@phase 'build',0, =>
  return if @HasFrontend is false
  @reqdir WebDir
  @reqdir @AssetDir
@phase 'build',9999, =>
  return if @HasFrontend is false
  console.log ':build'.green, 'frontend'.bold, @AssetURL.yellow, @htmlFile.bold
  await @emphase 'build:frontend:pre'
  await @emphase 'build:frontend'
  @insertWebsocket = ''
  @insertWebsocket = ' wss:' if WebSockets?
  @insert_policy = """<meta http-equiv="Content-Security-Policy" content="
  default-src  'self';
  manifest-src 'self' https:;
  connect-src  'self'#{@insertWebsocket};
  img-src      'self' blob: data: https:;
  media-src    'self' blob: data: https:;
  style-src    'self' 'unsafe-inline';
  script-src   'self' #{@scriptHash} https:;
  worker-src   'self' #{@workerHash} blob: https:;
  frame-src    'self' ;"/>"""
  # style-src    'self' 'unsafe-inline' '#{@stylesHash}' app/;
  ## FF is very strict about styles and csp
  unless @htmlScope.body then @html.body = """
    <navigation></navigation><content><center>JavaScript is required.</center></content>"""
  $fs.writeFileSync @htmlPath, $body = """
  <!DOCTYPE html><html><head>
    <meta charset="utf-8"/>
    <title>#{AppName}</title>
    <meta name="description" content="#{@description}"/>
    <meta name="theme-color" content="#{@manifest.theme_color}"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
  #{@insert_policy}#{@insertManifest}#{@htmlScope.head}#{@insertStyles}#{@insertWorkers}#{@insertScripts}
  </head><body>#{@htmlScope.body}</body></html>"""
  console.verbose 'write'.green, @htmlPath.bold

# ██   ██ ████████ ███    ███ ██
# ██   ██    ██    ████  ████ ██
# ███████    ██    ██ ████ ██ ██
# ██   ██    ██    ██  ██  ██ ██
# ██   ██    ██    ██      ██ ███████

@collectorScope 'html', ['head','body'],
  (scopeObject, hook)->
    (target,prop,value)=>
      console.log 'html'.yellow.bold, scopeObject, prop.bold, value
      value = ( await @loadAsset path for path in value ).join '\n' if Array.isArray value
      if hook.includes prop then scopeObject[prop] += value
      else                        scopeObject[prop]  = value
      true

# ██     ██  ██████  ██████  ██   ██ ███████ ██████
# ██     ██ ██    ██ ██   ██ ██  ██  ██      ██   ██
# ██  █  ██ ██    ██ ██████  █████   █████   ██████
# ██ ███ ██ ██    ██ ██   ██ ██  ██  ██      ██   ██
#  ███ ███   ██████  ██   ██ ██   ██ ███████ ██   ██

@scope.webWorker = (name,sources...)->
  @client.init = ->
    loadWorker = (name)->
      src = document.getElementById(name).textContent
      blob = new Blob [src], type: 'text/javascript'
      $$[name] = new Worker window.URL.createObjectURL blob
    loadWorker name for name in BunWebWorker
    return
  @webWorkerScope[name] = @compileSources sources

@phase 'build:frontend',0,=>
  @insertWorkers = ( for name, src of @webWorkerScope
    # src = minify(src).code
    """<script id="#{name}" type="text/js-worker">#{src}</script>"""
  ).join '\n'
  @workerHash = ''
  @workerHash += "'" + contentHash(@serviceWorkerSource) + "'" if @serviceWorkerSource
  @workerHash += " '" + contentHash(src) + "'" for name, src of @webWorkerScope

# ███████  ██████ ██████  ██ ██████  ████████
# ██      ██      ██   ██ ██ ██   ██    ██
# ███████ ██      ██████  ██ ██████     ██
#      ██ ██      ██   ██ ██ ██         ██
# ███████  ██████ ██   ██ ██ ██         ██

@collectorScope 'script', {}, (target,prop,value)=>
  prop = 'asset' if Array.isArray value
  prop = 'app'   if 'string' is typeof value
  @scriptScope[prop] = @scriptScope[prop] || []
  @scriptScope[prop].push value
  # console.debug 'script'.yellow, prop.bold, value
  true

@phase 'build:frontend:pre',0,=>
  @scriptHash = []
  @insertScripts = ''
  @concatScripts = if @concatScripts? then @concatScrits  else no
  @inlineScripts = if @inlineScripts? then @inlineScripts else no
  @scriptFile = @scriptFile || @htmlFile.replace(/.html$/,'') + '.js'
@phase 'build:frontend',9999,=>
  console.debug ':build'.green, 'scripts'.yellow.bold
  { minify } = require 'uglify-es' if @minifyScripts is true
  apilist = []
  scripts = []
  scripts.push """window.$$ = window; $$.isServer = ! ( $$.isClient = true ); $$.debug = false;"""
  scripts.push "$$.#{name} = #{JSON.stringify tpl};" for name, tpl of @shared.constant
  scripts.push "$$.BunWebWorker = #{JSON.stringify Object.keys(@webWorkerScope)};"
  await do =>
    # @script references
    @scriptScope.asset = @scriptScope.asset || []
    for href in @scriptScope.asset when href.match and url = href.match /^href:(.*)$/
      @insertScripts += """<script src="#{url[1]}"></script>"""
    if @concatScripts
      scripts.push ( await @loadAsset href ) + '\n' for href     in @scriptScope.asset when href.match and not href.match /^href:(.*)$/
      scripts.push ( script.join '\n'      ) + '\n' for k,script of @scriptScope       when k isnt 'asset'
    else
      for href in @scriptScope.asset
        [file,data] = await @linkAsset href
        @insertScripts += """<script src="#{file}"></script>"""
        @scriptHash.push "'" + ( contentHash data ) + "'"
      scripts.concat ( data for dest, data of @scriptScope when dest isnt 'asset' )
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
    scripts.push @processAPI @shared.function, apilist
    scripts.push @processAPI client, apilist
    scripts.push 'setTimeout(async ()=>{' + [hook.preinit,hook.init].join('\n') + '});'
    scripts = scripts.join '\n'
    scripts = minify(scripts).code                   if @minifyScripts is true
    return                                           if scripts.trim() is ''
    @scriptHash.push "'" + ( contentHash scripts ) + "'"
    if @inlineScripts is false
         $fs.writeFileSync $path.join(@AssetDir,@scriptFile), scripts
         @insertScripts += """<script src="#{$path.join @AssetURL,@scriptFile}"></script>"""
         console.debug ':write'.green, @scriptFile.bold
    else @insertScripts += """<script>#{scripts}"</script>"""
  @scriptHash = @scriptHash.join ' '
  console.debug 'client'.green, apilist.join(' ').gray

#  ██████ ███████ ███████
# ██      ██      ██
# ██      ███████ ███████
# ██           ██      ██
#  ██████ ███████ ███████

@collectorScope 'css', {}, (target,prop,value)=>
  prop = 'asset' if Array.isArray value
  prop = 'app'   if 'string' is typeof value
  @cssScope[prop] = @cssScope[prop] || []
  @cssScope[prop].push value
  # console.log '  CSS '.yellow.bold.inverse, prop.bold, value
  true

@phase 'build:frontend:pre',0,=>
  @stylesHash = []
  @insertStyles = ''
  @concatStyles = if @concatStyles? then @concatStyles else no
  @inlineStyles = if @inlineStyles? then @inlineStyles else no
  @cssFile = @cssFile || @htmlFile.replace(/.html$/,'') + '.css'
@phase 'build:frontend',9999,=>
  @cssScope.asset = @cssScope.asset || []
  await do =>
    # console.log "  CSS ".red.bold.inverse, @cssScope
    CleanCSS = require 'clean-css' if @minifyScripts is true
    styles = ''
    for href in @cssScope.asset when href.match and url = href.match /^href:(.*)$/
      @insertStyles += """<link rel=stylesheet href="#{url[1]}"/>"""
    if @concatStyles
      styles += ( await @loadAsset href ) + '\n' for href     in @cssScope.asset when href.match and not href.match /^href:(.*)$/
      styles += ( styles.join '\n'      ) + '\n' for k,styles of @cssScope       when k isnt 'asset'
    else
      for href in @cssScope.asset
        [file,data] = await @linkAsset href
        @insertStyles += """<link rel=stylesheet href="#{file}"/>"""
        @stylesHash.push "'" + ( contentHash data ) + "'"
      styles += data + '\n' for dest, data of @cssScope when dest isnt 'asset'
    styles = (new CleanCSS {}).minify(styles).styles if @minifyScripts is true
    return                                           if styles.trim() is ''
    @stylesHash.push "'" + ( contentHash styles ) + "'"
    if @inlineStyles is false
         $fs.writeFileSync $path.join(@AssetDir,@cssFile), styles
         @insertStyles += """<link rel=stylesheet href="#{$path.join @AssetURL,@cssFile}"/>"""
         console.debug ':write'.green, @cssFile.bold
    else @insertStyles += """<styles>#{styles}"</styles>"""
  @stylesHash = @stylesHash.join ' '

# ███    ███  █████  ███    ██ ██ ███████ ███████ ███████ ████████
# ████  ████ ██   ██ ████   ██ ██ ██      ██      ██         ██
# ██ ████ ██ ███████ ██ ██  ██ ██ █████   █████   ███████    ██
# ██  ██  ██ ██   ██ ██  ██ ██ ██ ██      ██           ██    ██
# ██      ██ ██   ██ ██   ████ ██ ██      ███████ ███████    ██

@phase 'build:frontend',0,=>
  unless @insertManifest
    @manifest = @manifest ||
      name: AppName
      short_name: title
      theme_color: "black"
    @insertManifest = ''
  $fs.writeFileSync $path.join(@AssetDir,'manifest.json'), JSON.stringify @manifest
