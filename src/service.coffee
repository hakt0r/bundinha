
@require 'bundinha/build/frontend'

@phase 'build',0, =>
  await do @buildServiceWorker
  return

# ███████ ███████ ██████  ██    ██ ██  ██████ ███████
# ██      ██      ██   ██ ██    ██ ██ ██      ██
# ███████ █████   ██████  ██    ██ ██ ██      █████
#      ██ ██      ██   ██  ██  ██  ██ ██      ██
# ███████ ███████ ██   ██   ████   ██  ██████ ███████

@HasServiceWorker = true

Bundinha::ServiceWorker = ->
  SCOPE = self
  WAS_UPDATED = no
  CACHE_NAME = AppName + '_' + BuildId
  jsonHeaders = headers:'Content-Type':'application/json'
  errorResponse = JSON.stringify error:'offline'
  self.addEventListener 'install', (event)-> event.waitUntil(
    caches.open CACHE_NAME
    .then (cache) ->
      cache.addAll ['/','/app/app.css','/app/app.js'].map (url)=>
        new Request url, credentials: 'same-origin' )
  self.addEventListener 'message', (msg)->
    return unless msg.data is 'skipWaiting'
    await self.skipWaiting()
    clients.claim()
  self.addEventListener 'activate', (event)->
    event.waitUntil new Promise (resolve)->
      keyList = await caches.keys()
      for key in keyList
        continue if key is CACHE_NAME
        caches.delete key
      resolve true
  self.addEventListener 'fetch', (event)->
    { url } = req = event.request
    return if req.method is "POST"
    return if url.match /\.(mp3|ogg|opus|mkv|mp4|avi|mpe?g|ts)$/
    event.respondWith new Promise (resolve)->
      res = await caches.match req
      return resolve res if res
      res = await fetch req.clone()
      return resolve res if !res or res.status != 200 or res.type isnt 'basic'
      cache = await caches.open CACHE_NAME
      cache.put req, res.clone()
      resolve res
  null

#  ██████ ██      ██ ███████ ███    ██ ████████
# ██      ██      ██ ██      ████   ██    ██
# ██      ██      ██ █████   ██ ██  ██    ██
# ██      ██      ██ ██      ██  ██ ██    ██
#  ██████ ███████ ██ ███████ ██   ████    ██

@client.preinit = ->
  await InitServiceWorker()
  return

@client.InitServiceWorker = ->
  return Promise.resolve() unless 'serviceWorker' of navigator
  window.addEventListener 'beforeinstallprompt', -> console.log 'install-prompt'
  navigator.serviceWorker.addEventListener 'message', (event)-> console.log event.data
  navigator.serviceWorker.addEventListener 'controllerchange', -> window.location.reload()
  reg = await navigator.serviceWorker.register 'service.js'
  if reg.waiting?
    reg.waiting.postMessage "skipWaiting"
  else
    reg.addEventListener 'updatefound', ->
      reg.installing.addEventListener 'statechange', ->
        return unless @state is 'installed'
        NotificationToast.show I18.UpdateAvailable, 'Update', 'Cancel'
        @postMessage "skipWaiting"
  return

# ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████   ██████  ██ ███████ ██████

Bundinha::ServiceHeader = ''
Bundinha::buildServiceWorker = ->
  return unless @HasServiceWorker
  @manifest = start_url: BaseUrl, display: "standalone"
  @ServiceHeader = """
  AppName = '#{AppName}';
  BuildId = '#{BuildId}';
  """ + @ServiceHeader
  @serviceWorkerSource = @compileSources [ @ServiceHeader, @ServiceWorker ]
  $fs.writeFileSync $path.join(@WebRoot,'service.js'), @serviceWorkerSource
