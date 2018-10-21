###
  UNLICENSED
  c) 2018 Sebastian Glaser
  All Rights Reserved.
###

@client init:@arrayTools
@client init:@miqro

@client.init = ->
  $$.$forge = forge
  return

@client.CALL = @client.AJAX = (call,data)->
  new Promise (resolve,reject)->
    xhr = new XMLHttpRequest
    xhr.open ( if data then 'POST' else 'GET' ), '/api'
    if data
      xhr.setRequestHeader "Content-Type","application/json"
      xhr.send JSON.stringify [call,data]
    else xhr.send()
    xhr.onload = ->
      try result = JSON.parse @response
      catch e then reject "JSON Error: " + e
      unless result.error
           resolve result
      else reject result.error
    null

# ██████  ██    ██ ████████ ████████  ██████  ███    ██ ███████
# ██   ██ ██    ██    ██       ██    ██    ██ ████   ██ ██
# ██████  ██    ██    ██       ██    ██    ██ ██ ██  ██ ███████
# ██   ██ ██    ██    ██       ██    ██    ██ ██  ██ ██      ██
# ██████   ██████     ██       ██     ██████  ██   ████ ███████

@client.SubmitButton = (key,xclass='',fn)->
  b = IconButton key,xclass,fn
  b.type='submit'
  b

@client.ResetButton = (key,xclass='',fn)->
  b = IconButton key,xclass,fn
  b.type='reset'
  b

@client.IconButton = (key,xclass='',fn)->
  if typeof xclass is 'function'
    fn = xclass
    xclass = ''
  btn = """<button id="#{key}" class="#{key} #{xclass}">#{I18[key]}</button>"""
  btn = """<button id="#{key}" class="#{key} faw fa-#{ICON[key]}#{xclass}"><span>#{I18[key]}</span></button>""" if ICON[key]?
  btn = $.make btn
  btn.onclick = fn if fn?
  btn.onclick = fn
  btn

@client.ModalWindow = (opts)->
  ModalWindow.closeActive() if ModalWindow.closeActive
  extraClass = ''
  extraClass = opts.class if opts.class
  head = if opts.head then "<h1>#{opts.head}</h1>" else ''
  id   = if opts.id   then """id="#{opts.id}" """  else ''
  document.body.append html = $.make """
  <div #{id}class="window modal#{extraClass}">
    #{head}
  </div>"""
  if opts.body
    if Array.isArray opts.body
      html.append e for e in opts.body
    else if 'string' is typeof opts.body
      html.append $.make opts.body
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

@client.EditProperty = (opts)-> new Promise (resolve)->
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

@client.EditValue = (opts)-> new Promise (resolve)->
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

@client.init = ->
  new PersistentToast
  new NotificationToast
  new MutableToast
  return

@client class ToastController
  constructor:(id)->
    @constructor.instance = @
    @count = 0
    @$ = $.make "<div id=#{id} class=toasts></div>"
  push: -> if ++@count is 1 then @$.classList.add    'active'
  pop:  -> if --@count is 0 then @$.classList.remove 'active'

@client class PersistentToast extends ToastController
  constructor:-> super 'info'; PersistentToast.show = @show.bind @
  show: (text,ok,cancel)-> new Promise (resolve,reject)=>
    document.body.append @$
    @$.append n = $.make "<div class=notification>#{text}</div>"
    n.append SubmitButton ok    , ( => @pop n.remove(); do resolve ) if ok
    n.append ResetButton  cancel, ( => @pop n.remove(); do reject  ) if cancel
    do @push

@client class NotificationToast extends ToastController
  constructor:-> super 'notify'; NotificationToast.show = @show.bind @
  show: (timeout,text)->
    document.body.append @$
    unless text? then ( text = timeout; timeout = 1000 )
    @$.append html = $.make "<div class=notification>#{text}</div>"
    setTimeout ( => html.remove(); @pop() ), timeout
    do @push

@client class MutableToast extends ToastController
  @byName: {}
  constructor:-> super 'mutable'; MutableToast.show = @show.bind @
  expire:(name,timeout)->
    return unless wrap = MutableToast.byName[name]
    clearTimeout  wrap.timer
    wrap.timer = setTimeout ( =>
      delete MutableToast.byName[name]
      wrap.remove()
      @pop()
    ), timeout
    return wrap
  show: (name,timeout,html)->
    document.body.append @$
    unless html? then ( html = timeout; timeout = 1000 )
    if wrap = MutableToast.byName[name]
      wrap.innerHTML = ''
      wrap.append html
      return @expire name, timeout
    MutableToast.byName[name] = wrap = $.make "<div class=notification></div>"
    wrap.append html
    @$.append wrap
    @push()
    return @expire name, timeout

@client.showModalConfirm = (text)->
  { text, body, ok, cancel } = text if typeof text is 'object'
  ok     = I18.Ok     unless ok
  cancel = I18.Cancel unless cancel
  text = if body then ['<h1>',text,'</h1><p>',body,'</p>'].join('') else text
  return await new Promise (resolve)->
    document.body.append $.make """<div id="customConfirm" class="window modal">
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
