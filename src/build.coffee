
# ███████  ██████ ██████  ██ ██████  ████████ ███████
# ██      ██      ██   ██ ██ ██   ██    ██    ██
# ███████ ██      ██████  ██ ██████     ██    ███████
#      ██ ██      ██   ██ ██ ██         ██         ██
# ███████  ██████ ██   ██ ██ ██         ██    ███████

APP.serviceWorker ->
  CACHE_NAME = 'cinv1'
  urlsToCache = ['/']
  self.addEventListener 'install', (event)-> event.waitUntil(
    caches.open(CACHE_NAME).then (cache)-> cache.addAll urlsToCache )
  self.addEventListener 'fetch', (event)->
    event.respondWith (
      if event.request.method is "POST"
        fetch event.request.clone()
        .catch -> new Response JSON.stringify( error:'offline' ), headers: 'Content-Type': 'application/json'
      else caches.match(event.request).then (res)->
        return res if res
        fetchRequest = event.request.clone()
        fetch(fetchRequest).then (res)->
          return res if !res or res.status != 200 or res.type != 'basic'
          cached = res.clone()
          caches.open(CACHE_NAME).then (cache)-> cache.put event.request, cached
          res )
  null

scripts = APP.script.$.map (i)->
  unless fs.existsSync i
    console.log 'script'.red, i
    return i
  console.log 'script'.green, i
  fs.readFileSync i

scripts.push """
  window.$$ = window;
  $$.isServer = ! ( $$.isClient = true );
  $$.debug = false;
"""

template = {}
Object.assign template, tpl for tpl in APP.tpl.$

tpls  = '\n$$.$tpl = {};'
tpls += "\n$tpl.#{name} = #{JSON.stringify tpl};" for name, tpl of template
tpls += "\n$$.#{name} = #{JSON.stringify tpl};" for name, tpl of APP.shared.$
tpls += "\n$$.BunWebWorker = #{JSON.stringify Object.keys(APP.webWorker.$)};"

scripts.push tpls

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
      # setTimeout plug.worker # TODO: oninit
  console.log 'api:plugin', module, list.join ' '

init = client.init; delete client.init

apis = ''; apilist = []
for name, api of client
  apis += "\n$$.#{name} = #{api.toString()};"
  apilist.push name
scripts.push apis
scripts.push init

console.log 'client-api'.green, apilist.join(' ').gray

{ minify } = require 'uglify-es'
scripts = scripts.join '\n'
# scripts = minify( scripts.join '\n' ).code
fs.writeFileSync path.join(RootDir,'build','app.js'), scripts

#  █████  ██████  ██████
# ██   ██ ██   ██ ██   ██
# ███████ ██████  ██████
# ██   ██ ██      ██
# ██   ██ ██      ██

styles = ( for filePath, opts of APP.css.$
  console.log 'css'.green, filePath
  fs.readFileSync filePath, 'utf8' ).join '\n'

workers = ( for name, src of APP.webWorker.$
  # src = minify(src).code
  """<script id="#{name}" type="text/js-worker">
  #{src}
  </script>"""
).join '\n'

fs.writeFileSync path.join(RootDir,'build','index.html'), $body = """
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8"/>
    <title>#{title}</title>
    <meta name="description" content="#{APP.description}"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <link rel=manifest href='data:application/manifest+json,
    { "name": "#{AppName}",
      "short_name": "#{title}",
      "start_url": "http://localhost:9999",
      "display": "standalone",
      "icons": [
        { "src": "data:image/png;base64,#{AppIconPNG}",
          "density": "1",
          "sizes": "256x256",
          "type": "image/png" },
        { "src": "data:image/svg+xml;base64,#{AppIcon}",
          "density": "1",
          "sizes": "any",
          "type": "image/svg+xml" }
      ]
    }'>
    </script>
    <style>
    #{styles}
  </style></head><body></body>
  #{workers}
  <script>
  #{scripts}
  </script>
  </html>"""
