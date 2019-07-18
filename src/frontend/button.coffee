
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
  i = I18[key] || key
  i18 = """title="#{i}" """
  t18 = """<span>#{i}</span>"""
  btn = """<button id="#{key}" #{i18}class="#{key} #{xclass}">#{i}</button>"""
  btn = """<button id="#{key}" #{i18}class="#{key} faw #{ICON[key]}#{xclass}">#{t18}</button>""" if ICON[key]?
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
    win = new ModalWindow
      id: opts.id || opts.title.toLowerCase()
      head: opts.head || opts.title.toLowerCase()
      body: body
      showHandler: show
      closeBtn: opts.closeBtn || btn
    win.show = show
    opts.init.call win, opts if opts.init
    win
  btn = IconButton opts.buttonTitle, show

@client class ModalWindow
  constructor:(opts)->
    ModalWindow.closeActive() if ModalWindow.closeActive
    extraClass = ''
    extraClass = opts.class if opts.class
    head = if opts.head then "<h1>#{opts.head}</h1>" else ''
    id   = if opts.id   then """id="#{opts.id}" """  else ''
    document.body.append html = $.make """
    <div #{id}class="window modal#{extraClass}">
      #{head}
    </div>"""
    html.section = ModalWindow.section
    html.section "head", opts.head
    html.section "body", opts.body
    html.section "foot", opts.foot
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

@client.ModalWindow.section = (name,value)->
  return unless value?
  switch typeof value
    when 'function' then @section name, value()
    when 'string'   then @append @body = $.make value
    when 'object'
      if Array.isArray value
        @append @body = $.make ''
        ( @body.append e for e in value )
      else @append @body = value
    else throw new Error """ModalWindow::section(#{name},#{value}) Unexpected: #{typeof value}"""
