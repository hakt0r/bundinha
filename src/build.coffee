
# ███████  ██████ ██████  ██ ██████  ████████ ███████
# ██      ██      ██   ██ ██ ██   ██    ██    ██
# ███████ ██      ██████  ██ ██████     ██    ███████
#      ██ ██      ██   ██ ██ ██         ██         ██
# ███████  ██████ ██   ██ ██ ██         ██    ███████

$script = APP.script.$.map (i)->
  unless fs.existsSync i
    console.log 'script'.red, i
    return i
  console.log 'script'.green, i
  fs.readFileSync i

$script.push """
  window.$$ = window;
  $$.isServer = ! ( $$.isClient = true );
  $$.debug = false;
"""

template = {}
Object.assign template, tpl for tpl in APP.tpl.$

tpls  = '\n$$.$tpl = {};'
tpls += "\n$tpl.#{name} = #{JSON.stringify tpl};" for name, tpl of template
tpls += "\n$$.#{name} = #{JSON.stringify tpl};" for name, tpl of APP.shared.$

$script.push tpls

client = init:''

for funcs in APP.client.$
  if ( init = funcs.init )?
    delete funcs.init
    client.init += "\n(#{init.toString()}());"
  Object.assign client, funcs

for module, plugs of APP.plugin.$
  list = []
  client.init += "\n#{module}.plugin = {};"
  for name, plug of plugs
    if plug.client?
      client.init += "\n#{module}.plugin.#{name} = #{plug.client.toString()};"
    if plug.worker?
      setInterval plug.worker, plug.interval || 1000 * 60 * 60
      setTimeout plug.worker
  console.log 'api:plugin', module, list.join ' '

init = client.init; delete client.init

apis = ''
for name, api of client
  apis += "\n$$.#{name} = #{api.toString()};"
  console.log 'api', name
$script.push apis
$script.push init

$script = $script.join '\n'

fs.writeFileSync path.join(RootDir,'build','app.js'), $script

#  █████  ██████  ██████
# ██   ██ ██   ██ ██   ██
# ███████ ██████  ██████
# ██   ██ ██      ██
# ██   ██ ██      ██

fs.writeFileSync path.join(RootDir,'build','index.html'), $body = """
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8"/>
    <title>#{APP.title}</title>
    <meta name="description" content="#{APP.description}"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <link rel="stylesheet" href="/build/css/fontawesome.css"/>
    <link rel="stylesheet" href="/build/plan.css"/>
  </head><body></body>
  <script src="/build/app.js"></script>
  </html>"""
