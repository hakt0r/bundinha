
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
  # console.debug '::html:'.bold.inverse.yellow, prop.bold, value
  true

@phase 'build:frontend:hash', =>
  for hook in ['head','body'] when list = @htmlScope[hook]
    for item in list
      if Array.isArray item then @insertHtml[hook] += ( await @loadAsset item )+'\n'
      else @insertHtml[hook] += item + '\n'
  @scriptHash  = "'unsafe-inline'" if @unsafeScripts
  @scriptHash += " 'unsafe-eval'"  if @unsafeScripts
  @insertWebsocket = ''
  @insertWebsocket = 'wss:' if WebSockets?
  @csp = """
  default-src  'self';
  manifest-src #{@manifestPolicy};
  worker-src   'self' #{@workerHash} blob: https:;
  connect-src  'self' #{@insertWebsocket};
  script-src   'self' #{@scriptHash} https:;
  img-src      'self' blob: data: https:;
  media-src    'self' blob: data: https:;
  style-src    'self' 'unsafe-inline';
  frame-src    'self';
  """
  .replace /[\n ]+/g,' '
  .replace /\ ;/g,';'
  console.debug ':hash'.green, @htmlPath.bold

@phase 'build:frontend:write', =>
  $fs.writeFileSync $path.join(BuildDir,'csp.txt'), @csp
  @insertPolicy = """<meta http-equiv="Content-Security-Policy" content="#{@csp}"/>"""
  # style-src    'self' 'unsafe-inline' '#{@stylesHash}' app/;
  ## FF is very strict about styles and csp
  if @insertHtml.body is '' then @insertHtml.body = """
    <navigation></navigation><content><center>JavaScript is required.</center></content>"""
  console.debug 'frontend:index:build'.bold.yellow
  insertHead = [
    @insertHtml.head
    # @insertPolicy
    @insertManifest
    @insertStyles
    @insertWorkers
    @insertScripts ]
  $fs.writeFileSync @htmlPath, $body = """
  <!DOCTYPE html><html><head>
    <meta charset="utf-8"/>
    <title>#{AppName}</title>
    <link rel="shortcut icon" href="#{@AssetURL}/favicon.ico" type="image/x-icon">
    <meta name="description" content="#{@description||AppPackage.description||''}"/>
    <meta name="theme-color" content="#{@manifest.theme_color}"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
  #{insertHead.join '\n'}
  </head><body>#{@insertHtml.body}</body></html>"""
  console.debug ':write'.green, @htmlPath.bold
