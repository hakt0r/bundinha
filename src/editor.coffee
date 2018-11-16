
@require 'bundinha/frontend'

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
