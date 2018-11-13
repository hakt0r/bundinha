
# ███    ██  ██████  ████████ ██ ███████ ██  ██████  █████  ████████ ██  ██████  ███    ██
# ████   ██ ██    ██    ██    ██ ██      ██ ██      ██   ██    ██    ██ ██    ██ ████   ██
# ██ ██  ██ ██    ██    ██    ██ █████   ██ ██      ███████    ██    ██ ██    ██ ██ ██  ██
# ██  ██ ██ ██    ██    ██    ██ ██      ██ ██      ██   ██    ██    ██ ██    ██ ██  ██ ██
# ██   ████  ██████     ██    ██ ██      ██  ██████ ██   ██    ██    ██  ██████  ██   ████

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
