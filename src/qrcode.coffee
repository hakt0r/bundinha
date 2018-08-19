
APP.script 'node_modules', 'qrcode', 'build', 'qrcode.min.js'
# Used in service worker now
# APP.script 'node_modules', 'jsqr', 'dist', 'jsQR.js'
symlink(
  path.join BunDir, 'node_modules', 'jsqr', 'dist', 'jsQR.js'
  path.join WebRootDir, 'jsqr.js' )

compile path.join(BunDir,'src','scanner.coffee'), 'scanner.js'

APP.headers (req,res)->
  res.append 'Content-Security-Policy',
             "worker-src https://#{req.headers.host}/;"

#  ██████  ██████  ██      ██ ██████
# ██    ██ ██   ██ ██      ██ ██   ██
# ██    ██ ██████  ██      ██ ██████
# ██ ▄▄ ██ ██   ██ ██      ██ ██   ██
#  ██████  ██   ██ ███████ ██ ██████
#     ▀▀

api = APP.client()

api.Sleep = (ms)-> new Promise (resolve)->
  setTimeout resolve, ms

api.HasMediaQueries = ->
  a = navigator.mediaDevices? and navigator.mediaDevices.getUserMedia?
  b = navigator.mediaDevices? and navigator.mediaDevices.enumerateDevices?
  a and b

api.PreferBackCamera = (devices)-> new Promise (resolve,reject)->
  anydevice = null
  for device in devices when device.kind is 'videoinput'
    anydevice = device
    break if device.label.match(/back/)
  return resolve anydevice if anydevice?
  reject new Error "No video devices"

api.init = -> $$.QR =
  write: QRCode
  init: ->
    return new Error 'getUserMedia() is not supported by your browser' unless HasMediaQueries()
    $$.video  = document.querySelector 'video'
    $$.canvas = document.querySelector 'canvas'
    $$.ctx    = null
    navigator.mediaDevices.enumerateDevices()
      .then PreferBackCamera
      .then (device)->
        constraints = facingMode:"environment", audio:no, video:{}
        constraints.video.deviceId = device.deviceId if device.deviceId?
        navigator.mediaDevices.getUserMedia constraints
      .then (stream) ->
        video.srcObject = stream
        while not ( 0 < video.videoWidth )
          await Sleep 100
        null

  scan: -> new Promise (resolve,reject)->
    document.body.classList.add 'recording'
    QR.Scanner = new BarcodeDetector if BarcodeDetector?
    QR.stopScan.resolve = resolve
    QR.stopScan.reject  = reject
    do QR.scanNextImage

  stopScan: (data)->
    if QR.stopScan.resolve?
      if data then QR.stopScan.resolve data
      else         QR.stopScan.reject  null
    document.body.classList.remove 'recording'
    clearInterval QR.timer
    QR.stopScan.resolve = QR.stopScan.reject = null

  scanNextImage: ->
    canvas.width  = width  = video.videoWidth
    canvas.height = height = video.videoHeight
    ctx = canvas.getContext '2d'
    # ctx.drawImage video, 0, 0
    ctx.clearRect 0,0,width,height
    img = ctx.getImageData 0, 0, width, height
    CodeScanner.postMessage data:img, width:width, height:height
    CodeScanner.onmessage = QR.processWorkerResult ctx

  processWorkerResult: (ctx)-> (msg)->
    result = msg.data
    return do QR.scanNextImage unless result.data and result.data.trim() isnt ''
    ctx.strokeStyle = "red"
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.moveTo.apply ctx, Object.values(result.location.topLeftCorner)
    ctx.lineTo.apply ctx, Object.values(result.location.topRightCorner)
    ctx.lineTo.apply ctx, Object.values(result.location.bottomRightCorner)
    ctx.lineTo.apply ctx, Object.values(result.location.bottomLeftCorner)
    ctx.lineTo.apply ctx, Object.values(result.location.topLeftCorner)
    ctx.stroke()
    QR.stopScan result.data
