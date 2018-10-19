
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
  self.addEventListener 'fetch', (event)->
    { url } = req = event.request
    return unless req.method is "POST"
    # event.respondWith fetch(req.clone()).catch ->
    #   new Response errorResponse, jsonHeaders
    return unless url.match /\.(mp3|ogg|opus|mkv|mp4|avi|mpe?g|ts)$/
    event.respondWith new Promise (resolve)->
      return resolve res if res = await caches.match req
      res = await fetch req.clone()
      if !res or res.status != 200 or res.type isnt 'basic'
        return resolve res
      cache = await caches.open CACHE_NAME
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
