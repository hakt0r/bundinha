###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

# document.addEventListener 'DOMContentLoaded', -> return

api = APP.clientApi()

api.LoadOffscreen = (html)->
  o = document.createElement 'div'
  o.innerHTML = html
  if o.children.length is 1 then o.firstChild else o.content

api.LoadOffscreenFragment = (html)->
  document.createRange().createContextualFragment html

api.ajax = (call,data)-> new Promise (resolve,reject)->
  method = 'POST'
  method = 'GET' unless data
  xhr = new XMLHttpRequest
  xhr.open method, '/api'
  if data
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.send JSON.stringify [call,data]
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
  </div>"""
  if opts.body
    if Array.isArray opts.body
      html.append e for e in opts.body
    else if 'string' is typeof opts.body
      html.append LoadOffscreen opts.body
    else html.append opts.body
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

notifyApi = APP.clientApi()

notifyApi.init = ->
  new PersistentToast
  new NotificationToast

notifyApi.ToastController = class ToastController
  constructor:(id)->
    @count = 0
    @$ = LoadOffscreen "<div id=#{id} class=toasts></div>"
  push: -> if ++@count is 1 then @$.classList.add    'active'
  pop:  -> if --@count is 0 then @$.classList.remove 'active'

notifyApi.PersistentToast = class PersistentToast extends ToastController
  constructor:-> super 'info'; PersistentToast.show = @show.bind @
  show: (text,ok,cancel)-> new Promise (resolve,reject)=>
    document.body.append @$
    @$.append n = LoadOffscreen "<div class=notification>#{text}</div>"
    n.append IconButton ok    , ( => @pop n.remove(); do resolve ) if ok
    n.append IconButton cancel, ( => @pop n.remove(); do reject  ) if cancel
    do @push

notifyApi.NotificationToast = class NotificationToast extends ToastController
  constructor:-> super 'notify'; NotificationToast.show = @show.bind @
  show: (timeout,text)->
    document.body.append @$
    unless text? then ( text = timeout; timeout = 1000 )
    @$.append html = LoadOffscreen "<div class=notification>#{text}</div>"
    setTimeout ( => html.remove(); @pop() ), timeout
    do @push

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
