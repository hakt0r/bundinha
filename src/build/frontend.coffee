
@HasFrontend         = if @HasFrontend?         then @HasFrontend         else true
@inlineManifest      = if @inlineManifest?      then @inlineManifest      else no
@inlineManifestIcons = if @inlineManifestIcons? then @inlineManifestIcons else no
@concatScripts       = if @concatScripts?       then @concatScripts       else no
@inlineScripts       = if @inlineScripts?       then @inlineScripts       else no
@concatStyles        = if @concatStyles?        then @concatStyles        else no
@inlineStyles        = if @inlineStyles?        then @inlineStyles        else no

@asset = ['/']
@scriptHash = []
@stylesHash = []
@insertStyles = ''
@insertScripts = ''

# ██   ██ ████████ ███    ███ ██
# ██   ██    ██    ████  ████ ██
# ███████    ██    ██ ████ ██ ██
# ██   ██    ██    ██  ██  ██ ██
# ██   ██    ██    ██      ██ ███████

@collectorScope 'html',{},(target,prop,value)=>
  prop = 'body' if prop is null
  prop = 'body' if prop is '0'
  value = value[0] if Array.isArray value
  @htmlScope[prop] = @htmlScope[prop] || []
  @htmlScope[prop].push value
  # console.log '::html'.yellow, prop.bold, value
  true

@phase 'build',0, =>
  return if @HasFrontend is false
  @reqdir WebDir
  @reqdir @AssetDir
@phase 'build',9999, =>
  return if @HasFrontend is false
  console.log ':build'.green, 'frontend'.bold, @AssetURL.yellow, @htmlFile.bold
  await @emphase 'build:frontend:pre'
  await @emphase 'build:frontend'
  @insertHtml = head:'',body:''
  for hook in ['head','body'] when list = @htmlScope[hook]
    for item in list
      if Array.isArray item then @insertHtml[hook] += ( await @loadAsset item )+'\n'
      else @insertHtml[hook] += item + '\n'
  @scriptHash = "'unsafe-inline'" if @unsafeScripts
  @insertWebsocket = ''
  @insertWebsocket = ' wss:' if WebSockets?
  @insertPolicy = """<meta http-equiv="Content-Security-Policy" content="
  default-src  'self';
  manifest-src #{@manifestPolicy};
  connect-src  'self'#{@insertWebsocket};
  img-src      'self' blob: data: https:;
  media-src    'self' blob: data: https:;
  style-src    'self' 'unsafe-inline';
  script-src   'self' #{@scriptHash} https:;
  worker-src   'self' #{@workerHash} blob: https:;
  frame-src    'self' ;"/>"""
  # style-src    'self' 'unsafe-inline' '#{@stylesHash}' app/;
  ## FF is very strict about styles and csp
  if @insertHtml.body is '' then @insertHtml.body = """
    <navigation></navigation><content><center>JavaScript is required.</center></content>"""
  $fs.writeFileSync @htmlPath, $body = """
  <!DOCTYPE html><html><head>
    <meta charset="utf-8"/>
    <title>#{AppName}</title>
    <meta name="description" content="#{@description}"/>
    <meta name="theme-color" content="#{@manifest.theme_color}"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
  #{@insertHtml.head}#{@insertPolicy}#{@insertManifest}#{@insertStyles}#{@insertWorkers}#{@insertScripts}
  </head><body>#{@insertHtml.body}</body></html>"""
  console.debug ':write'.green, @htmlPath.bold

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
  prop = 'app'     if 'string' is typeof value
  prop = 'asset'   if Array.isArray value
  value = value[0] if Array.isArray value
  @scriptScope[prop] = @scriptScope[prop] || []
  @scriptScope[prop].push value
  console.debug 'script'.yellow, prop.bold, value.toString().substring(0,99)
  true

@phase 'build:frontend:pre',0,@buildFrontendScriptsPre = =>
  @scriptFile = @scriptFile || @htmlFile.replace(/.html$/,'') + '.js'
  @scriptURI  = $path.join @AssetURL, @scriptFile
@phase 'build:frontend',9999,@buildFrontendScripts = =>
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
    console.log scripts
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
         @insertScripts += """<script src="#{@scriptURI.replace /^\//,''}"></script>"""
         @asset.push @scriptURI
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
  prop = 'asset'   if Array.isArray value
  value = value[0] if Array.isArray value
  prop = 'app'     if 'string' is typeof value
  @cssScope[prop] = @cssScope[prop] || []
  @cssScope[prop].push value
  # console.log '  CSS '.yellow.bold.inverse, prop.bold, value
  true

@phase 'build:frontend:pre',0,@buildFrontendStylesPre = =>
  @cssFile = @cssFile || @htmlFile.replace(/.html$/,'') + '.css'
  @cssURI  = $path.join @AssetURL, @cssFile
@phase 'build:frontend',9999,@buildFrontendStyles = =>
  @cssScope.asset = @cssScope.asset || []
  await do =>
    # console.log "  CSS ".red.bold.inverse, @cssScope
    CleanCSS = require 'clean-css' if @minifyScripts is true
    styles = ''
    for href in @cssScope.asset when href.match and url = href.match /^href:\/(.*)$/
      @insertStyles += """<link rel=stylesheet href="#{url[1]}"/>"""
    if @concatStyles
      styles += ( await @loadAsset href ) + '\n' for href     in @cssScope.asset when href.match and not href.match /^href:(.*)$/
      styles += ( styles.join '\n'      ) + '\n' for k,styles of @cssScope       when k isnt 'asset'
    else
      for href in @cssScope.asset
        continue if href.match and href.match /^href:/
        [file,data] = await @linkAsset href
        @insertStyles += """<link rel=stylesheet href="#{file.replace /^\//,''}"/>"""
        @stylesHash.push "'" + ( contentHash data ) + "'"
        @asset.push file
      styles += data + '\n' for dest, data of @cssScope when dest isnt 'asset'
    styles = (new CleanCSS {}).minify(styles).styles if @minifyScripts is true
    return                                           if styles.trim() is ''
    @stylesHash.push "'" + ( contentHash styles ) + "'"
    if @inlineStyles is false
         $fs.writeFileSync $path.join(@AssetDir,@cssFile), styles
         @insertStyles += """<link rel=stylesheet href="#{@cssURI.replace /^\//,''}"/>"""
         @asset.push @cssURI
         console.debug ':write'.green, @cssFile.bold
    else @insertStyles += """<styles>#{styles}"</styles>"""
  @stylesHash = @stylesHash.join ' '

# ███    ███  █████  ███    ██ ██ ███████ ███████ ███████ ████████
# ████  ████ ██   ██ ████   ██ ██ ██      ██      ██         ██
# ██ ████ ██ ███████ ██ ██  ██ ██ █████   █████   ███████    ██
# ██  ██  ██ ██   ██ ██  ██ ██ ██ ██      ██           ██    ██
# ██      ██ ██   ██ ██   ████ ██ ██      ███████ ███████    ██

@phase 'build',100,=>
  @manifest = Object.assign (
    name: AppName
    short_name: AppPackageName
    theme_color:      @themeColor || "black"
    background_color: @themeBg    || "#231f27"
  ), @manifest || {}
  if @inlineManifestIcons is yes
    @manifest.icons = [
      { src: "data:image/png;base64,#{$fs.readBase64Sync @AppIconPNG}", density: "1", sizes: "512x512", type: "image/png"  }
      { src: "data:image/svg+xml;base64,#{$fs.readBase64Sync @AppIcon}", density: "1", sizes: "any", type: "image/svg+xml" } ]
  else if @AppIcon? and @AppIconPNG?
    p1 = $path.join @AssetURL, b1 = $path.basename @AppIcon
    p2 = $path.join @AssetURL, b2 = $path.basename @AppIconPNG
    @manifest.icons = [
      { src: "#{p1}", density: "1", sizes: "any", type: "image/svg+xml" }
      { src: "#{p2}", density: "1", sizes: "512x512", type: "image/png"  } ]
    @linkAsset @AppIcon,    $path.join @AssetDir, p1
    @linkAsset @AppIconPNG, $path.join @AssetDir, p2
  return do @buildInlineManifest if @inlineManifest is yes
  @manifestPolicy = "'self' https:"
  @insertManifest = """<link rel=manifest crossorigin="use-credentials" href="#{$path.join @AssetURL,'manifest.json'}"/>"""
  if @HasBackend is no
    $fs.writeFileSync $path.join(@AssetDir,'manifest.json'), JSON.stringify @manifest
    return
  @server.AppManifest = @manifest
  @server.init = ->
    AppManifest.start_url = BaseUrl if AppManifest.start_url
    $fs.writeFileSync $path.join(AssetDir,'manifest.json'), JSON.stringify AppManifest
    return

@buildInlineManifest = ->
  @manifestPolicy = 'data:'
  @insertManifest = """<link rel=manifest href='data:application/manifest+json,#{
    JSON.stringify(@manifest).replace(/#/g,'%23')
  }'/>"""
