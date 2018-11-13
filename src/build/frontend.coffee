
# ███████ ██████   ██████  ███    ██ ████████ ███████ ███    ██ ██████
# ██      ██   ██ ██    ██ ████   ██    ██    ██      ████   ██ ██   ██
# █████   ██████  ██    ██ ██ ██  ██    ██    █████   ██ ██  ██ ██   ██
# ██      ██   ██ ██    ██ ██  ██ ██    ██    ██      ██  ██ ██ ██   ██
# ██      ██   ██  ██████  ██   ████    ██    ███████ ██   ████ ██████

@phase 'build',9999, =>
  return if @frontend is false
  await do @buildFrontend
  return

Bundinha::buildFrontend = ->
  console.log ':build'.green, 'frontend'.bold, @AssetDir.replace(WebDir,'').yellow, @htmlFile.bold
  @reqdir @AssetDir

  @manifest = @manifest ||
    name: AppName
    short_name: title
    theme_color: "black"
  @insert_manifest = ''

  scripts = @scriptScope.map (i)->
    unless $fs.existsSync i
      console.debug 'script'.red, i
      return i
    console.debug 'script'.green, i
    $fs.readFileSync i

  scripts.push """
    window.$$ = window;
    $$.isServer = ! ( $$.isClient = true );
    $$.debug = false;
  """

  template = {}
  Object.assign template, tpl for tpl in @tplScope

  tpls  = '\n$$.$tpl = {};'
  for name, tpl of template
    if typeof tpl is 'function'
         tpls += "\n$tpl.#{name} = #{tpl.toString()};"
    else tpls += "\n$tpl.#{name} = #{JSON.stringify tpl};"
  tpls += "\n$$.#{name} = #{JSON.stringify tpl};" for name, tpl of @shared.constant
  tpls += "\n$$.BunWebWorker = #{JSON.stringify Object.keys(@webWorkerScope)};"

  scripts.push tpls

  client = @clientScope

  for module, plugs of @pluginScope
    list = []
    client.init += "\n#{module}.plugin = {};"
    for name, plug of plugs
      if plug.clientInit
        client.init += "\n(#{plug.clientInit.toString()})()"
      if plug.client?
        client.init += "\n#{module}.plugin[#{JSON.stringify name}] = #{plug.client.toString()};"
      if plug.worker?
        setInterval plug.worker, plug.interval || 1000 * 60 * 60
        # setTimeout plug.worker # TODO: oninit
    console.debug 'plugin'.green, module, list.join ' '

  hook = {}
  for name in ['preinit','init'] when client[name]
    hook[name] = client[name]
    delete client[name]

  scripts.push @processAPI @shared.function, apilist = []
  scripts.push @processAPI client, apilist
  scripts.push 'setTimeout(async ()=>{' +
    [hook.preinit,hook.init].join('\n') +
    '});'

  console.debug 'client'.green, apilist.join(' ').gray

  { minify } = require 'uglify-es'
  scripts = scripts.join '\n'
  # scripts = minify(scripts).code


  workers = ( for name, src of @webWorkerScope
    # src = minify(src).code
    """<script id="#{name}" type="text/js-worker">#{src}</script>"""
  ).join '\n'

  $fs.writeFileSync $path.join(@AssetDir,'app.js'), scripts
  $fs.writeFileSync $path.join(@AssetDir,'manifest.json'), JSON.stringify @manifest

  # mainfestHash = contentHash @insert_manifest if @insert_manifest
  scriptHash   = contentHash scripts
  workerHash   = ''
  workerHash   += "'" + contentHash(@serviceWorkerSource) + "'" if @serviceWorkerSource
  workerHash   += " '" + contentHash(src) + "'" for name, src of @webWorkerScope

  insert_scripts = ''
  insert_scripts += workers if workers
  insert_scripts += (
    if @inlineScripts
         """<script>#{scripts}</script>"""
    else """<script src="app/app.js"></script>""" )

  #  ██████ ███████ ███████
  # ██      ██      ██
  # ██      ███████ ███████
  # ██           ██      ██
  #  ██████ ███████ ███████

  stylesHash = ''
  insert_styles = ''

  styles = ( for css, opts of @cssScope
    if opts is true
      console.log ':::css'.green, css
      $fs.readFileSync css, 'utf8'
    else if opts is 'href'
      insert_styles += """<link rel=stylesheet href="#{css}"/>"""
      false
    else opts
  )
  .filter (i)-> i isnt false
  .join '\n'

  console.log @htmlFile, styles
  @cssFile = @cssFile || @htmlFile.replace(/.html$/,'') + '.css'
  $fs.writeFileSync $path.join(@AssetDir,@cssFile), styles

  insert_styles += (
    if @inlineScripts then """<styles>#{styles}</styles>"""
    else """<link rel=stylesheet href="app/#{@cssFile}"/>""" )

  stylesHash = contentHash styles

  #  ██████ ███████ ██████
  # ██      ██      ██   ██
  # ██      ███████ ██████
  # ██           ██ ██
  #  ██████ ███████ ██

  insert_websocket = ''
  insert_websocket = ' wss:' if WebSockets?
  @insert_policy = """<meta http-equiv="Content-Security-Policy" content="
  default-src  'self';
  manifest-src 'self' https:;
  connect-src  'self'#{insert_websocket};
  img-src      'self' blob: data: https:;
  media-src    'self' blob: data: https:;
  style-src    'self' 'unsafe-inline';
  script-src   'self' '#{scriptHash}' https:;
  worker-src   'self' #{workerHash} blob: https:;
  frame-src    'self' ;"/>"""
  # style-src    'self' 'unsafe-inline' '#{stylesHash}' app/;
  ## FF is very strict about styles and csp

  unless @htmlScope.body then @html 'body', """
    <navigation></navigation>
    <content>
      <center>JavaScript is required.</center>
    </content>"""

  $fs.writeFileSync @htmlPath, $body = """
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8"/>
    <title>#{AppName}</title>
    <meta name="description" content="#{@description}"/>
    <meta name="theme-color" content="#{@manifest.theme_color}"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    #{@insert_policy}
    #{@insert_manifest}
    #{@htmlScope.head}
  </head>
  <body>#{@htmlScope.body}</body>
  #{insert_styles}
  #{insert_scripts}
  </html>"""
  console.verbose 'write'.green, @htmlPath.bold
