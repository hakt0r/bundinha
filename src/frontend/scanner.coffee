###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###


# READ_QR = if navigator.BarcodeDetector
#     barcodeDetector = new BarcodeDetector();
#     (image)-> new Promise (resolve)->
#       barcodeDetector.detect(image)
#         .then resolve
#         .catch resolve
#   else

importScripts '/jsqr.js'

self.onmessage = (msg)->
  msg = msg.data.data
  result = jsQR msg.data, msg.width, msg.height
  self.postMessage (
    if result then result else error:false )
  null
