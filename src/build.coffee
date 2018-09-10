
BuildId = SHA512(new Date)
console.log "Build-Id", BuildId.yellow

# ███████ ███████ ██████  ██    ██ ██  ██████ ███████
# ██      ██      ██   ██ ██    ██ ██ ██      ██
# ███████ █████   ██████  ██    ██ ██ ██      █████
#      ██ ██      ██   ██  ██  ██  ██ ██      ██
# ███████ ███████ ██   ██   ████   ██  ██████ ███████

ServiceHeader  = """
  AppName = '#{AppName}';
  BuildId = '#{BuildId}';
"""
ServiceWorker = ->
  SCOPE = self
  WAS_UPDATED = no
  CACHE_NAME = AppName + '_' + BuildId
  jsonHeaders = headers:'Content-Type':'application/json'
  errorResponse = JSON.stringify error:'offline'
  self.addEventListener 'install', (event)-> event.waitUntil (
    caches.open CACHE_NAME
    .then (cache)-> cache.addAll ['/'] )
  self.addEventListener 'message', (msg)->
    return unless msg.data is 'skipWaiting'
    self.skipWaiting()
    .then -> clients.claim()
  self.addEventListener 'activate', (event)-> event.waitUntil (
    caches.keys()
    .then (keyList)->
      for key in keyList
        continue if key is CACHE_NAME
        caches.delete key )
  self.addEventListener 'fetch', (event)-> event.respondWith (
    if event.request.method is "POST"
      fetch event.request.clone()
      .catch -> new Response errorResponse, jsonHeaders
    else caches.match(event.request).then (res)->
      return res if res
      fetch event.request.clone()
      .then (res)->
        return res if !res or res.status != 200 or res.type != 'basic'
        cached = res.clone()
        caches.open(CACHE_NAME)
        .then (cache)-> cache.put event.request, cached
        res )
  null

if APP.HasServiceWorker
  APP.serviceWorkerSource = APP.compileSources [ ServiceHeader, ServiceWorker ]
  fs.writeFileSync path.join(BuildDir,'service.js'), APP.serviceWorkerSource
  APP.clientApi init:->
    window.addEventListener 'beforeinstallprompt', ->
      console.log 'install-prompt'
    return Promise.resolve() unless 'serviceWorker' of navigator
    navigator.serviceWorker.addEventListener 'controllerchange', ->
      window.location.reload()
    navigator.serviceWorker
    .register '/service.js'
    .then (reg)->
      if reg.waiting?
        PersistentToast.show I18.UpdateAvailable, 'Update', 'Cancel'
        .then -> reg.waiting.postMessage "skipWaiting"
      else reg.addEventListener 'updatefound', ->
        reg.installing.addEventListener 'statechange', ->
          return unless @state is 'installed'
          PersistentToast.show I18.UpdateAvailable, 'Update', 'Cancel'
          .then -> reg.waiting.postMessage "skipWaiting"
      reg.update()
    .catch (err) -> console.log 'ServiceWorker registration failed: ', err
    navigator.serviceWorker.addEventListener 'message', (event)->
      console.log event.data
    null

# ███████  ██████ ██████  ██ ██████  ████████ ███████
# ██      ██      ██   ██ ██ ██   ██    ██    ██
# ███████ ██      ██████  ██ ██████     ██    ███████
#      ██ ██      ██   ██ ██ ██         ██         ██
# ███████  ██████ ██   ██ ██ ██         ██    ███████

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
for name, tpl of template
  if typeof tpl is 'function'
       tpls += "\n$tpl.#{name} = #{tpl.toString()};"
  else tpls += "\n$tpl.#{name} = #{JSON.stringify tpl};"
tpls += "\n$$.#{name} = #{JSON.stringify tpl};" for name, tpl of APP.shared.$
tpls += "\n$$.BunWebWorker = #{JSON.stringify Object.keys(APP.webWorker.$)};"

scripts.push tpls

client = init:''

for funcs in APP.clientApi.$
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
# scripts = minify(scripts).code
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
  """<script id="#{name}" type="text/js-worker">#{src}</script>"""
).join '\n'

manifesto = if APP.HasServiceWorker then """
<link rel=manifest href='data:application/manifest+json,
{ "name": "#{AppName}",
  "short_name": "#{title}",
  "start_url": "#{APP.BaseUrl}",
  "display": "standalone",
  "theme_color": "black",
  "background_color": "%23231f27",
  "icons": [
    { "src": "data:image/png;base64,#{AppIconPNG}",
      "density": "1",
      "sizes": "512x512",
      "type": "image/png" },
    { "src": "data:image/svg+xml;base64,#{AppIcon}",
      "density": "1",
      "sizes": "any",
      "type": "image/svg+xml" }
  ]
}'/>""" else ''

contentHash = (data)-> # TODO: this is broken
  'sha256-' + forge.util.encode64(
    forge.md.sha256.create().update(data).digest().bytes()
  )

contentHashNative = (data)->
  'sha256-' + require('crypto').createHash('sha256').update(data).digest().toString('base64')

mainfestHash = contentHashNative manifesto
stylesHash   = contentHashNative styles
scriptHash   = contentHashNative scripts
workerHash   = ''
workerHash   += " '" + contentHashNative(src) + "'" for name, src of APP.webWorker.$
workerHash   += " '" + contentHashNative(APP.serviceWorkerSource) + "'"

fs.writeFileSync path.join(RootDir,'build','index.html'), $body = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>#{title}</title>
  <meta name="description" content="#{APP.description}"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <meta name="theme-color" content="black"/>
  <meta http-equiv="Content-Security-Policy" content="
    default-src 'none';
    manifest-src 'self' data: '#{mainfestHash}';
    connect-src #{APP.BaseUrl}/api;
    img-src     'self' blob: data: #{APP.BaseUrl}/;
    style-src   '#{stylesHash}';
    script-src  '#{scriptHash}';
    worker-src  #{workerHash} blob: https:;
  "/>
  #{manifesto}
<style>#{styles}</style></head>
<body><center>JavaScript is required.</center></body>
#{workers}<script>#{scripts}</script></html>"""
