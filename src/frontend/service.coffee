
@require 'bundinha/build/frontend'
@HasServiceWorker = true

@phase 'build:pre',0,=>
  @ServiceHeader = ''
  return

@phase 'build:frontend:pre', 0, @buildServiceWorker = =>
  return unless @HasServiceWorker
  Object.assign @manifest, (
    start_url: @BaseUrl, display: "standalone"
  ), @manifest
  @ServiceHeader = """
  AppName = '#{AppName}';
  BuildId = '#{BuildId}';
  Assets  = #{JSON.stringify @asset};
  """ + @ServiceHeader
  @serviceWorkerSource = @compileSources [ @ServiceHeader, @ServiceWorker ]
  console.debug 'frontend:service:build'.bold.yellow
  return

@phase 'build:frontend:write', 9999, @buildServiceWorker = =>
  console.debug 'frontend:service:write'.bold.yellow
  $fs.writeFileSync $path.join(@WebRoot,'service.js'), @serviceWorkerSource
  return

# ███████ ███████ ██████  ██    ██ ██  ██████ ███████
# ██      ██      ██   ██ ██    ██ ██ ██      ██
# ███████ █████   ██████  ██    ██ ██ ██      █████
#      ██ ██      ██   ██  ██  ██  ██ ██      ██
# ███████ ███████ ██   ██   ████   ██  ██████ ███████

Bundinha::ServiceWorker = ->
  SCOPE = self
  WAS_UPDATED = no
  CACHE_NAME = AppName + '_' + BuildId
  jsonHeaders = headers:'Content-Type':'application/json'
  errorResponse = JSON.stringify error:'offline'
  Assets = [location.origin].concat Assets
  self.addEventListener 'install', (event)-> event.waitUntil(
    cache = await caches.open CACHE_NAME
    .then (cache) ->
      cache.addAll Assets.map (url)=>
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
    return if url.match /\.html$/
    return if url.match /\.(mp3|ogg|opus|mkv|mp4|avi|mpe?g|ts)$/
    event.respondWith new Promise (resolve)->
      res = await caches.match req
      return resolve res if res
      res = await fetch req.clone()
      return resolve res if !res or res.status != 200 or res.type isnt 'basic'
      cache = await caches.open CACHE_NAME
      cache.put req, res.clone()
      resolve res
  return

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
  window.addEventListener 'beforeinstallprompt', -> console.debug 'install-prompt'
  navigator.serviceWorker.addEventListener 'message', (event)-> console.debug event.data
  navigator.serviceWorker.addEventListener 'controllerchange', -> window.location.reload()
  reg = await navigator.serviceWorker.register 'service.js'
  if reg.waiting?
    reg.waiting.postMessage "skipWaiting"
  else
    reg.addEventListener 'updatefound', ->
      reg.installing.addEventListener 'statechange', ->
        return unless @state is 'installed'
        # NotificationToast.show I18.UpdateAvailable, 'Update', 'Cancel'
        @postMessage "skipWaiting"
  return
