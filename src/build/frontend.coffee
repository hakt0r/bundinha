# ███████ ██████   ██████  ███    ██ ████████ ███████ ███    ██ ██████
# ██      ██   ██ ██    ██ ████   ██    ██    ██      ████   ██ ██   ██
# █████   ██████  ██    ██ ██ ██  ██    ██    █████   ██ ██  ██ ██   ██
# ██      ██   ██ ██    ██ ██  ██ ██    ██    ██      ██  ██ ██ ██   ██
# ██      ██   ██  ██████  ██   ████    ██    ███████ ██   ████ ██████

Bundinha::buildFrontend = ->
  console.log ':build'.green, 'frontend'.bold, @AssetDir.yellow
  @reqdir @AssetDir

  scripts = @scriptScope.map (i)->
    unless $fs.existsSync i
      console.log 'script'.red, i
      return i
    console.log 'script'.green, i
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
    console.log 'plugin'.green, module, list.join ' '

  hook = {}
  for name in ['preinit','init'] when client[name]
    hook[name] = client[name]
    delete client[name]

  scripts.push @processAPI @shared.function, apilist = []
  scripts.push @processAPI client, apilist
  scripts.push 'setTimeout(async ()=>{' +
    [hook.preinit,hook.init].join('\n') +
    '});'

  console.log 'client'.green, apilist.join(' ').gray

  { minify } = require 'uglify-es'
  scripts = scripts.join '\n'
  # scripts = minify(scripts).code

  styles = ( for css, opts of @cssScope
    if opts is true
      console.log ':::css'.green, css
      $fs.readFileSync css, 'utf8'
    else opts
  ).join '\n'

  workers = ( for name, src of @webWorkerScope
    # src = minify(src).code
    """<script id="#{name}" type="text/js-worker">#{src}</script>"""
  ).join '\n'

  $fs.writeFileSync $path.join(@AssetDir,'app.js'), scripts
  $fs.writeFileSync $path.join(@AssetDir,'app.css'), styles

  mainfestHash = contentHash @insert_manifest
  stylesHash   = contentHash styles
  scriptHash   = contentHash scripts
  workerHash   = ''
  workerHash   += "'" + contentHash(@serviceWorkerSource) + "'"
  workerHash   += " '" + contentHash(src) + "'" for name, src of @webWorkerScope

  insert_scripts = ''
  insert_scripts += workers if workers
  insert_scripts += (
    if @inlineScripts
         """<script>#{scripts}</script>"""
    else """<script src="app/app.js"></script>""" )

  insert_styles = ''
  insert_styles += (
    if @inlineScripts
         """<script>#{styles}</script>"""
    else """<link rel=stylesheet href="app/app.css"/>""" )

  insert_websocket = ''
  insert_websocket = ' wss:' if WebSockets?
  @insert_policy = """<meta http-equiv="Content-Security-Policy" content="
  default-src  'self';
  manifest-src 'self' data: '#{mainfestHash}';
  connect-src  'self'#{insert_websocket};
  img-src      'self' blob: data: https:;
  media-src    'self' blob: data: https:;
  style-src    'self' 'unsafe-inline';
  script-src   'self' '#{scriptHash}' https:;
  worker-src   'self' #{workerHash} blob: https:;
  frame-src    'self' ;"/>"""
  # style-src    'self' 'unsafe-inline' '#{stylesHash}' app/;
  ## FF is very strict about styles and csp

  $fs.writeFileSync $path.join(WebDir,'index.html'), $body = """
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
  </head>
  <body>
    <navigation></navigation>
    <content>
      <center>JavaScript is required.</center>
    </content>
  </body>
  #{insert_styles}
  #{insert_scripts}
  </html>"""
