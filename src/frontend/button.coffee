
# ██████  ██    ██ ████████ ████████  ██████  ███    ██ ███████
# ██   ██ ██    ██    ██       ██    ██    ██ ████   ██ ██
# ██████  ██    ██    ██       ██    ██    ██ ██ ██  ██ ███████
# ██   ██ ██    ██    ██       ██    ██    ██ ██  ██ ██      ██
# ██████   ██████     ██       ██     ██████  ██   ████ ███████

@client.SubmitButton = (key,css='',fn)->
  b = IconButton key,css,fn
  b.type='submit'
  b

@client.ResetButton = (key,css='',fn)->
  b = IconButton key,css,fn
  b.type='reset'
  b

@client.IconButton = (key,css='',fn)->
  [fn,css] = [css,''] if typeof css is 'function'
  i18 = """title="#{i = I18[key] || key}" """; t18 = """<span>#{i}</span>"""
  btn = """<button id="#{key}" #{i18}class="#{key} #{css}">#{i}</button>"""
  btn = """<button id="#{key}" #{i18}class="#{key} faw #{ICON[key]}#{css}">#{t18}</button>""" if ICON[key]?
  btn = $.make btn
  btn.onclick = fn if fn?
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
    return html

@client.ModalWindow.section = (name,value)->
  return unless value? and value isnt false
  switch typeof value
    when 'function' then @section name, value()
    when 'string'   then @append @body = $.make value
    when 'object'
      if Array.isArray value
        @append @body = $.make ''
        ( @body.append e for e in value )
      else @append @body = value
    else throw new Error """ModalWindow::section(#{name},#{value}) Unexpected: #{typeof value}"""

@client class Button
  constructor:(opts={})->
    btn = document.createElement 'button'
    Object.assign btn, opts
    btn.classList.add btn.key
    btn.title = btn.title || I18[btn.key] || btn.key
    btn.classList.add c for c in @classList.split ' ' if @classList?
    unless off is btn.icon
      btn.classList.add 'faw'
      btn.classList.add ( ICON[btn.icon || btn.key] )
    btn.on 'click', opts.click if opts.click?
    btn.append $.make "<span class=title>#{btn.title}</span>"
    return btn

@client.FormTool = (name,opts,build)->
  unless build?
    build = opts
    opts = {}
  _button = (form)-> (opts)->
    form.append new Button opts
  _group = (form)-> (build)->
    ff = $$$.createElement 'group'
    build.call
      button: _button ff
      group:   _group ff
      input:   _input ff
    form.append ff
  _input = (form)-> (opts)->
    for field, o of opts
      tag = o.tag || 'input'
      e = $$$.createElement tag
      switch tag
        when 'input'
          attr = Object.assign {}, e, {
            type         : 'text'
            autocomplete : 'off'
          }, o
          e.setAttribute k,v for k,v of attr
      e.name = o.name || field.toLowerCase()
      form.append e
    return
  form = $$$.createElement 'form'
  form.id = form.name = name
  form.addClass c for c in opts.css if opts.css
  build.call
    button: _button form
    group:   _group form
    input:   _input form
  form
