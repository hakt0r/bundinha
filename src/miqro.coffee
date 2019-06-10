
@require 'bundinha/build/frontend'

# ███    ███ ██  ██████  ██████   ██████
# ████  ████ ██ ██    ██ ██   ██ ██    ██
# ██ ████ ██ ██ ██    ██ ██████  ██    ██
# ██  ██  ██ ██ ██ ▄▄ ██ ██   ██ ██    ██
# ██      ██ ██  ██████  ██   ██  ██████

Bundinha::miqro = -> # aka. Vquery, VanillaJ and jFlat
  window.$$$ = document
  window.$$  = window
  window.$   = (query)-> document.querySelector query
  $.all = (query)-> Array.prototype.slice.call document.querySelectorAll query
  $.map = (query,fn)-> Array.prototype.slice.call(document.querySelectorAll query).map(fn)
  $.make = (html)->
    template = document.createElement 'template'
    template.innerHTML = html
    html = template.content
    if ( node = html.childNodes ).length is 1 then node[0] else html
  SmoothEvents = (spec)-> Object.assign spec,
    events:(key)-> (( @EVENT || {} )[key] || [] )
    on: (key,func,opts)->
      @addEventListener key, func, opts
      (( @EVENT = @EVENT || @EVENT = {} )[key] || @EVENT[key] = [] ).push func
    off: (key,func,opts)->
      @events(key).remove func
      @removeEventListener key, func, opts
    kill: (key)-> @events(key).map @off.bind @, key
    once: (key,func)-> @on key, func, once:yes
    emit: (key,data)-> @dispatchEvent Object.assign( new Event key ), data: data
  for spec in [$$,$$$,HTMLElement::,DocumentFragment::]
    SmoothEvents spec
    spec.find = (query)-> @querySelector query
    spec.findAll = (query)-> Array::slice.call @querySelectorAll query
    spec.map = (query,fn)-> Array::slice.call(@querySelectorAll query).map fn
  return

@client init:@miqro
