
@client.init = ->
  new KeyboardManager
  $$.KeyboardSettings = bind:{}
  return

@client Kbd = class KeyboardManager
  constructor:(opts={})->
    $$.Kbd = @
    @help  = opts.help  || {}
    @state = opts.state || {}
    @mmap  = opts.mmap  || {}
    @rmap  = opts.rmap  || {}
    @up    = opts.up    || {}
    @dn    = opts.dn    || {}
    @d10   = opts.d10   || {}
    $$.on 'keyup',   @keyupHandler.bind @
    $$.on 'keydown', @keydownHandler.bind @
    null

# source: mdn these keycodes should be available on all major platforms
Kbd::workingKeycodes2018 = ["AltLeft","AltRight","ArrowDown","ArrowLeft","ArrowRight","ArrowUp",
"Backquote","Backslash","Backspace","BracketLeft","BracketRight","CapsLock","Comma","ContextMenu",
"ControlLeft","ControlRight","Convert","Copy","Cut","Delete","Digit0","Digit1","Digit2","Digit3",
"Digit4","Digit5","Digit6","Digit7","Digit8","Digit9","End","Enter","Equal","Escape","F1","F10",
"F11","F12","F13","F14","F15","F16","F17","F18","F19","F2","F20","F3","F4","F5","F6","F7","F8","F9",
"Find","Help","Home","Insert","IntlBackslash","KeyA","KeyB","KeyC","KeyD","KeyE","KeyF","KeyG",
"KeyH","KeyI","KeyJ","KeyK","KeyL","KeyM","KeyN","KeyO","KeyP","KeyQ","KeyR","KeyS","KeyT","KeyU",
"KeyV","KeyW","KeyX","KeyY","KeyZ","Minus","NonConvert","NumLock","Numpad0","Numpad1","Numpad2",
"Numpad3","Numpad4","Numpad5","Numpad6","Numpad7","Numpad8","Numpad9","NumpadAdd","NumpadDecimal",
"NumpadDivide","NumpadEnter","NumpadEqual","NumpadMultiply","NumpadSubtract","Open","OSLeft",
"OSRight","PageDown","PageUp","Paste","Pause","Period","PrintScreen","Props","Quote","ScrollLock",
"Select","Semicolon","ShiftLeft","ShiftRight","Slash","Space","Tab","Undo"]

Kbd::macro = (name,key,d10,func)->
  { name,key,d10,func } = name unless name.match
  KeyboardSettings.bind = {} unless KeyboardSettings.bind?
  key = KeyboardSettings.bind[name] || key
  console.debug key, name, KeyboardSettings.bind[name]?
  @macro[name] = func
  @bind key, name if key
  @d10[name] = d10

Kbd::bind = (combo,macro,opt) ->
  { combo,macro,opt } = combo unless combo.match
  opt = @macro[macro] unless opt?
  delete @rmap[combo]
  delete @help[combo]
  return console.log ':kbd', 'bind:opt:undefined', macro, key, combo, opt unless opt?
  opt = up: opt if typeof opt is 'function'
  key = combo.replace /^[cas]+/,''
  return console.log ':kbd', 'bind:key:unknown', macro, key, combo, opt if -1 is @workingKeycodes2018.indexOf key
  console.debug ':kbd', 'bind', combo, opt
  @up[macro] = opt.up if opt.up?
  @dn[macro] = opt.dn if opt.dn?
  @mmap[macro] = combo
  @rmap[combo] = macro
  @help[combo] = macro
  @state[key] = off

Kbd::keydownHandler = (e) ->
  # allow some browser-wide shortcuts that would otherwise not work
  return if e.ctrlKey and e.code is 'KeyC'
  return if e.ctrlKey and e.code is 'KeyV'
  return if e.ctrlKey and e.code is 'KeyR'
  return if e.ctrlKey and e.code is 'KeyL'
  # allow the inspector; but only in debug mode ;)
  # return if e.ctrlKey and e.shiftKey and e.code is 'KeyI' if debug
  e.preventDefault()
  code = e.code
  code = 'c' + code if e.ctrlKey
  code = 'a' + code if e.altKey
  code = 's' + code if e.shiftKey
  return @onkeydown e, code if @onkeydown
  return true if @onkeyup
  macro = @rmap[code]
  # notice 500, "d[#{code}]:#{macro} #{e.code}" if debug
  return if @state[code] is true
  @state[code] = true
  @dn[macro](e) if @dn[macro]?

Kbd::keyupHandler = (e) ->
  e.preventDefault()
  code = e.code
  code = 'c' + code if e.ctrlKey
  code = 'a' + code if e.altKey
  code = 's' + code if e.shiftKey
  return @onkeyup e, code if @onkeyup
  macro = @rmap[code]
  # notice 500, "u[#{code}]:#{macro}" if debug
  return if @state[code] is false
  @state[code] = false
  @up[macro](e) if @up[macro]?

Kbd::stackOrder = []
Kbd::stackItem  = []

Kbd::clearHooks = (key)->
  @focus = null
  document.removeEventListener 'paste', @onpaste if @onpaste
  delete @onpaste
  delete @onkeyup
  delete @onkeydown
  true

Kbd::grab = (focus,opts)->
  console.debug ':kbd', 'grab', focus.name
  if @focus
    unless @focus is focus and opts.onkeydown is @onkeydown and opts.onkeyup is @onkeyup and opts.onpaste is @onpaste
      console.debug ':kbd', 'obscure', @focus.name
      @stackOrder.push @stackItem[@focus.name] =
        focus:@focus
        onkeydown:@onkeydown
        onkeyup:@onkeyup
        onpaste:@onpaste
    else console.debug ':kbd', 'same', @focus.name
    do @clearHooks
  @focus = focus; Object.assign @, opts
  document.addEventListener 'paste', @onpaste if @onpaste
  console.debug ':kbd', 'grabbed', @focus.name
  true

Kbd::release = (focus)->
  if @focus is focus
    console.debug ':kbd', 'release_current', focus.name
    do @clearHooks
    if @stackOrder.length is 0
      console.debug ':kbd', 'main-focus'
      return true
    item = @stackOrder.pop()
    @grab item.focus, item
    true
  else if item = @stackItem[focus.name]
    console.debug ':kbd', 'release_obscured', focus.name
    Array.splice idx, 0 if idx = @stackOrder.indexOf item
    delete @stackItem[focus.name]
    console.debug ':kbd', 'main' unless @focus
    true
  else false
