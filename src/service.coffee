
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
  cache = null
  caches.open CACHE_NAME
  .then (c)-> cache = c
  jsonHeaders = headers:'Content-Type':'application/json'
  errorResponse = JSON.stringify error:'offline'
  self.addEventListener 'install', (event)-> event.waitUntil (
    cache.addAll ['/','/app/app.css','/app/app.js'] )
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
      console.log 'cached?', req.url
      res = await caches.match req
      return resolve res if res
      console.log 'cached?no', req.url
      res = await fetch req.clone()
      return resolve res if !res or res.status != 200 or res.type isnt 'basic'
      console.log 'get?yesh', req.url
      cache.put req, res.clone()
      resolve res
  null

#  ██████ ██      ██ ███████ ███    ██ ████████
# ██      ██      ██ ██      ████   ██    ██
# ██      ██      ██ █████   ██ ██  ██    ██
# ██      ██      ██ ██      ██  ██ ██    ██
#  ██████ ███████ ██ ███████ ██   ████    ██

@client.init = ->
  InitServiceWorker()
  return

@client.InitServiceWorker = ->
  window.addEventListener 'beforeinstallprompt', ->
    console.log 'install-prompt'
  return Promise.resolve() unless 'serviceWorker' of navigator
  navigator.serviceWorker.addEventListener 'controllerchange', ->
    window.location.reload()
  navigator.serviceWorker
  .register 'service.js'
  .then (reg)->
    if reg.waiting?
      PersistentToast.show I18.UpdateAvailable, 'Update', 'Cancel'
      .then -> reg.waiting.postMessage "skipWaiting"
    else reg.addEventListener 'updatefound', ->
      console.log 'updatefound'
      reg.installing.addEventListener 'statechange', ->
        return unless @state is 'installed'
        PersistentToast.show I18.UpdateAvailable, 'Update', 'Cancel'
        .then => @postMessage "skipWaiting"
      reg.update()
  .catch (err) -> console.log 'ServiceWorker registration failed: ', err
  navigator.serviceWorker.addEventListener 'message', (event)->
    console.log event.data
  return

# ██████  ██    ██ ██ ██      ██████
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████  ██    ██ ██ ██      ██   ██
# ██   ██ ██    ██ ██ ██      ██   ██
# ██████   ██████  ██ ███████ ██████

Bundinha::ServiceHeader = ''
Bundinha::buildServiceWorker = ->
  @manifest =
    name: AppName
    short_name: title
    start_url: @BaseUrl
    display: "standalone"
    icons: [
      src: "data:image/png;base64,#{AppIconPNG}", density: "1", sizes: "512x512", type: "image/png"
      src: "data:image/svg+xml;base64,#{AppIcon}", density: "1", sizes: "any", type: "image/svg+xml" ]
    theme_color: "black"
    background_color: "%23231f27"

  @insert_manifest = unless @HasServiceWorker then '' else """
  <link rel=manifest href='data:application/manifest+json,#{JSON.stringify @manifest}'/>"""

  return unless @HasServiceWorker

  @ServiceHeader = """
  AppName = '#{AppName}';
  BuildId = '#{BuildId}';
  """ + @ServiceHeader

  @serviceWorkerSource = @compileSources [ @ServiceHeader, @ServiceWorker ]
  $fs.writeFileSync $path.join(@WebRoot,'service.js'), @serviceWorkerSource
