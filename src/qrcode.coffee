
@require 'bundinha/frontend'

@client.init = ->
  QR.write = qrcode
  QR.read  = jsQR
  return

@script [[BunDir,'node_modules','qrcode-generator','qrcode.js']]
@script [[BunDir,'node_modules','jsqr','dist','jsQR.js']]

#  ██████  ██████  ██      ██ ██████
# ██    ██ ██   ██ ██      ██ ██   ██
# ██    ██ ██████  ██      ██ ██████
# ██ ▄▄ ██ ██   ██ ██      ██ ██   ██
#  ██████  ██   ██ ███████ ██ ██████
#     ▀▀

@client.Sleep = (ms)-> new Promise (resolve)->
  setTimeout resolve, ms

@client.HasMediaQueries = ->
  a = navigator.mediaDevices? and navigator.mediaDevices.getUserMedia?
  b = navigator.mediaDevices? and navigator.mediaDevices.enumerateDevices?
  a and b

@client class QR

QR.facingMode = 'environment'
QR.onDetect = ->

QR.init =  ->
  return new Error 'getUserMedia() is not supported by your browser' unless HasMediaQueries()
  $$.video = document.querySelector 'video'
  $$.ctx   = null
  do QR.startVideo

QR.startVideo = ->
  constraints = audio:no, video:facingMode:QR.facingMode, frameRate:30
  navigator.mediaDevices.getUserMedia constraints
  .then (stream) -> new Promise (resolve,reject)->
    video.srcObject = stream
    while video.videoWidth is 0
      await Sleep 100
    width  = video.videoWidth
    height = video.videoHeight
    $$.canvas = new OffscreenCanvas width, height
    QR.ctx = canvas.getContext '2d'
    document.body.classList.add 'recording'
    resolve true

QR.stopVideo =  (data)->
  video.srcObject.getTracks()[0].stop()
  document.body.classList.remove 'recording'

QR.scan = ->
  document.body.classList.add 'recording'
  do QR.scanNextImage

QR.toggleVideo = (data)->
  state = not video.srcObject.getTracks()[0].enabled
  video.srcObject.getTracks()[0].enabled = state
  document.body.classList[if state then 'add' else 'remove'] 'recording'

QR.stopScan = (data)->
  document.body.classList.toggle 'recording'
  QR.stopScan.reject  null
  QR.stopScan.resolve = QR.stopScan.reject = null

QR.scanNextImage = ->
  return unless document.body.classList.contains 'recording'
  width  = canvas.width
  height = canvas.height
  QR.ctx.drawImage video, 0, 0
  img = QR.ctx.getImageData 0, 0, width, height
  CodeScanner.postMessage data:img, width:width, height:height
  CodeScanner.onmessage = QR.processWorkerResult

QR.processWorkerResult = (msg)->
  result = msg.data
  if result.data? and result.data isnt ''
    # console.log 'result', result.data
    QR.onDetect result.data if QR.onDetect
  else if result.binaryData? and result.binaryData.length > 0
    console.log 'bin-result', result.binaryData
    QR.onDetect result.binaryData if QR.onDetect
  else
    # console.log 'skip', result
    return do QR.scanNextImage
  return
  ctx.clearRect 0,0, canvas.width, canvas.height
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

# WebWorker does the processing using jsQR

@webWorker 'CodeScanner', ( ->
  self.onmessage = (msg)->
    msg = msg.data.data
    result = jsQR msg.data, msg.width, msg.height
    self.postMessage (
      if result then result else error:true )
    null
  null
), [BunDir,'node_modules','jsqr','dist','jsQR.js']
