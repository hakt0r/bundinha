
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

@client.ModalWindowButton = (opts)->
  opts.id = opts.id || opts.key.toLowerCase()
  opts.body = opts.body || $.make """<div>"""
  opts.buttonTitle = opts.buttonTitle || opts.title || opts.key
  opts.title = opts.title || I18[opts.key] || 'ModalWindow'
  show = ->
    body = opts.body || ''
    body = body() if body.call
    win = ModalWindow
      id: opts.id || opts.title.toLowerCase()
      head: opts.head || opts.title.toLowerCase()
      body: body
      showHandler: show
      closeBtn: opts.closeBtn || btn
    win.show = show
    opts.init.call win, opts if opts.init
    win
  btn = IconButton opts.buttonTitle, show

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
    if Array.isArray opts.body then           html.append html.body = e for e in opts.body
    else if 'string' is typeof opts.body then html.append html.body = $.make opts.body
    else                                      html.append html.body = opts.body
  opts.closeBtn.classList.add 'deleting' if opts.closeBtn?
  ModalWindow.closeActive = html.close = close = (e)->
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