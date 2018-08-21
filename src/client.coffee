###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

# document.addEventListener 'DOMContentLoaded', -> return

api = APP.client()

api.LoadOffscreen = (html)->
  o = document.createElement 'div'
  o.innerHTML = html
  o.firstChild

api.ajax = (url,data)-> new Promise (resolve,reject)->
  method = 'POST'
  method = 'GET' unless data
  xhr = new XMLHttpRequest
  xhr.open method, url
  if data
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.send JSON.stringify data
  else xhr.send()
  xhr.onload = ->
    try result = JSON.parse @response
    catch e then reject "JSON Error: " + e
    unless result.error
        resolve result
    else reject result.error
  null

api.IconButton = (key,xclass='',fn)->
  if typeof xclass is 'function'
    fn = xclass
    xclass = ''
  btn = """<button id="#{key}" class="#{key} #{xclass}">#{I18[key]}</button>"""
  btn = """<button id="#{key}" class="#{key} faw fa-#{ICON[key]}#{xclass}"><span>#{I18[key]}</span></button>""" if ICON[key]?
  btn = LoadOffscreen btn
  btn.onclick = fn if fn?
  btn.onclick = fn
  btn

api.ModalWindow = (opts)->
  ModalWindow.closeActive() if ModalWindow.closeActive
  extraClass = ''
  extraClass = opts.class if opts.class
  head = if opts.head then "<h1>#{opts.head}</h1>" else ''
  id   = if opts.id   then """id="#{opts.id}" """  else ''
  document.body.append html = LoadOffscreen """
  <div #{id}class="window modal#{extraClass}">
    #{head}
    #{opts.body}
  </div>"""
  opts.closeBtn.classList.add 'deleting' if opts.closeBtn?
  ModalWindow.closeActive = close = (e)->
    ModalWindow.closeActive = null
    if opts.closeBtn?
      opts.closeBtn.classList.remove 'deleting'
      opts.closeBtn.onclick = if opts.showHandler? then opts.showHandler else null
    document.removeEventListener 'keyup', keyClose
    opts.onclose() if opts.onclose
    html.remove()
    e.preventDefault() if e
    false
  opts.closeBtn.onclick = close if opts.closeBtn?
  document.addEventListener 'keyup', keyClose = (e)->
    return false unless e.key is 'Escape'
    close e
  html

# ███████ ██████  ██ ████████  ██████  ██████
# ██      ██   ██ ██    ██    ██    ██ ██   ██
# █████   ██   ██ ██    ██    ██    ██ ██████
# ██      ██   ██ ██    ██    ██    ██ ██   ██
# ███████ ██████  ██    ██     ██████  ██   ██

api.EditProperty = (opts)-> new Promise (resolve)->
  resolved = ->
    resolve [key,value]
    ModalWindow.closeActive()
  { item,title,key,value } = opts
  ModalWindow
    body:"""
    <form id="propertyEditor">
      <input  type="text" name="key"   placeholder="#{I18.Key}"   autocomplete="off" autofocus="true" />
      <input  type="text" name="value" placeholder="#{I18.Value}" autocomplete="off" />
      <button type="reset" class="fa fa-times-circle">#{I18.Cancel}</button>
      <button type="submit" class="fa fa-check-circle">#{I18.Save}</button>
    </form>"""
  form$  = document.getElementById 'propertyEditor'
  key$   = document.querySelector '[name=key]'
  value$ = document.querySelector '[name=value]'
  key$  .value = key   || ''
  value$.value = value || ''
  form$.onsubmit = (e) ->
    e.preventDefault()
    key   = key$.value
    value = value$.value
    resolved()
  form$.onreset = resolved
  null

api.EditValue = (opts)-> new Promise (resolve)->
  resolved = ->
    opts.onclose() if opts.onclose
    form$.remove()
    resolve value
  opts.id = 'propertyEditor' unless opts.id
  { item,title,value } = opts
  opts.body = """
  <form>
    <input  type="text" name="value" placeholder="#{I18.Value}" autocomplete="off" autofocus="true" />
    <button type="reset">#{I18.Cancel}</button>
    <button type="submit">#{I18.Save}</button>
  </form>"""
  html = ModalWindow opts
  form$ = document.getElementById 'propertyEditor'
  value$ = document.querySelector '[name=value]'
  value$.value = value if value?
  form$.onsubmit = (e) ->
    e.preventDefault()
    value = value$.value
    resolved()
    null
  form$.onreset = resolved
  null

# ███    ██  ██████  ████████ ██ ███████ ██  ██████  █████  ████████ ██  ██████  ███    ██ ███████
# ████   ██ ██    ██    ██    ██ ██      ██ ██      ██   ██    ██    ██ ██    ██ ████   ██ ██
# ██ ██  ██ ██    ██    ██    ██ █████   ██ ██      ███████    ██    ██ ██    ██ ██ ██  ██ ███████
# ██  ██ ██ ██    ██    ██    ██ ██      ██ ██      ██   ██    ██    ██ ██    ██ ██  ██ ██      ██
# ██   ████  ██████     ██    ██ ██      ██  ██████ ██   ██    ██    ██  ██████  ██   ████ ███████

notifyApi = APP.client()

notifyApi.init = ->
  showToastNotification.list = []

notifyApi.showToastNotification = (timeout,text)->
  unless text?
    text = timeout
    timeout = 1000
  showToastNotification.list.push [Date.now() + timeout, text]
  updateToastNotification()

notifyApi.updateToastNotification = -> requestAnimationFrame ->
  unless e = document.querySelector '.toastNotifications'
    document.body.append LoadOffscreen '<div class="toastNotifications"></div>'
    e = document.querySelector '.toastNotifications'
  now = Date.now()
  nextEvent = Infinity
  showToastNotification.list = list = showToastNotification.list.filter (item)->
    time = item[0]
    nextEvent = time if time < nextEvent and time > now
    time > now
  if list.length > 0
    e.innerHTML = '<div class="notification">' +
      list.map((i)-> i[1]).join('</div>\n<div class="notification">') +
      '</div>'
    e.classList.add 'active'
    nextEvent = if nextEvent is Infinity then now + 100 else nextEvent
    setTimeout ( -> updateToastNotification() ), nextEvent - now
  else
    e.innerHTML = ''
    e.classList.remove 'active'
  null

notifyApi.showModalConfirm = (text)->
  { text, body, ok, cancel } = text if typeof text is 'object'
  ok     = I18.Ok     unless ok
  cancel = I18.Cancel unless cancel
  text = if body then ['<h1>',text,'</h1><p>',body,'</p>'].join('') else text
  return await new Promise (resolve)->
    document.body.append LoadOffscreen """<div id="customConfirm" class="window modal">
      <div class="message">
        #{text}
      <div>
      <button type="reset">#{cancel}</button>
      <button type="submit">#{ok}</button>
    </div>"""
    answered = (val)-> ->
      document.getElementById('customConfirm').remove()
      resolve val
    document.querySelector('#customConfirm button[type=submit]').onclick = answered yes
    document.querySelector('#customConfirm button[type=reset]' ).onclick = answered no
    null
