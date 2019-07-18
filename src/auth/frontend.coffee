
# ███████ ██████   ██████  ███    ██ ████████ ███████ ███    ██ ██████
# ██      ██   ██ ██    ██ ████   ██    ██    ██      ████   ██ ██   ██
# █████   ██████  ██    ██ ██ ██  ██    ██    █████   ██ ██  ██ ██   ██
# ██      ██   ██ ██    ██ ██  ██ ██    ██    ██      ██  ██ ██ ██   ██
# ██      ██   ██  ██████  ██   ████    ██    ███████ ██   ████ ██████

@script [[BunDir,'node_modules','node-forge','dist','forge.min.js']]

@client.RequestLogin = (user,pass,response)->
  { challenge } = response
  if challenge is '$plaintext$'
    hashedPass = pass
    clientSalt = null
  else
    clientSalt = btoa $forge.random.getBytesSync 128
    hashedPass = SHA512 [ pass,       challenge.seedSalt    ].join ':'
    hashedPass = SHA512 [ hashedPass, challenge.storageSalt ].join ':'
    hashedPass = SHA512 [ hashedPass, clientSalt            ].join ':'
  LoginResult await CALL 'login', id:user, pass:hashedPass, salt:clientSalt

@client.CheckLoginCookie = ->
  if document.cookie.match /SESSION=/
    CALL 'authenticated', {}
    .then CheckLoginCookieWasSuccessful
    .catch (error)->
      NotificationToast.show 'offline mode' if error is 'offline'
      false
  else Promise.resolve false

@client.CheckLoginCookieWasSuccessful = (result)->
  $$.GROUP = result.groups
  result.success || false

@client.Logout = ->
  ModalWindow.closeActive() if ModalWindow.closeActive
  try await CALL 'logout', {}
  $$.emit 'logout'
  $$.location = $$.location.origin
  return # do LoginForm

@client.ButtonLogout = ->
  btn = IconButton 'Logout'
  btn.onclick = Logout
  btn

@client.Login = (user,pass)->
  challenge = await CALL 'login', id:user
  RequestLogin user, pass, challenge

@client.LoginResult = (result)->
  $$.GROUP = result.groups
  result.success || false
  result

# ██       ██████   ██████  ██ ███    ██
# ██      ██    ██ ██       ██ ████   ██
# ██      ██    ██ ██   ███ ██ ██ ██  ██
# ██      ██    ██ ██    ██ ██ ██  ██ ██
# ███████  ██████   ██████  ██ ██   ████

if @AppLogo
  @client.AppLogo = $fs.readUTF8Sync @AppLogo
  @client.GetAppLogo = ->
    return '' unless AppLogo?
    i = new Image
    i.src = URL.createObjectURL new Blob [AppLogo], filename:'AppLogo', type:'image/svg+xml'
    i.draggable = false
    i

@client.LoginForm = -> requestAnimationFrame ->
  $('content').innerHTML = """
  <div class="window modal monolithic" id="loginWindow">
    <form id="login">
      <input type="email"    name="id"                   placeholder="#{I18.Username}" autocomplete="username" autofocus="true" />
      <input type="password" name="pass" pattern=".{6,}" placeholder="#{I18.Password}" autocomplete="password" />
    </form>
  </div>
  """
  document.getElementById('loginWindow').prepend GetAppLogo()
  navigation$ = $ 'navigation'
  form$ = document.getElementById 'login'
  name$ = form$.find '[name=id]'
  pass$ = form$.find '[name=pass]'
  form$.onsubmit = (evt) ->
    console.log 'onsubmit'
    evt.preventDefault()
    user = ( user$ = $ '[name=id]'   ).value
    pass = ( pass$ = $ '[name=pass]' ).value
    window.UserID = user
    try
      response = await Login user, pass
      window.dispatchEvent new Event 'login'
    catch error
      NotificationToast.show error
      user$.setCustomValidity error
      setTimeout ( -> user$.setCustomValidity '' ), 3000
  name$.onkeydown = (evt)-> pass$.focus    evt if evt.key is 'Enter' or evt.key is 'Tab'
  pass$.onkeydown = (evt)-> form$.onsubmit evt if evt.key is 'Enter'
  navigation$.innerHTML = ''
  navigation$.append IconButton 'Register', RegisterForm
  navigation$.append IconButton 'Login', ' default', form$.onsubmit
  window.dispatchEvent new Event 'loginform'
  return

# ██████  ███████  ██████  ██ ███████ ████████ ███████ ██████
# ██   ██ ██      ██       ██ ██         ██    ██      ██   ██
# ██████  █████   ██   ███ ██ ███████    ██    █████   ██████
# ██   ██ ██      ██    ██ ██      ██    ██    ██      ██   ██
# ██   ██ ███████  ██████  ██ ███████    ██    ███████ ██   ██

@client.RegisterForm = -> requestAnimationFrame ->
  $('content').innerHTML = """
  <div class="window modal monolithic" id="registerWindow">
    <form id="register" action="/api/register" method="post">
      <input type="email"    name="user"      placeholder="#{I18.Username}"        autocomplete="username"         autofocus="true"/>
      <input type="password" name="pass"      placeholder="#{I18.Password}"        autocomplete="new-password"     pattern=".{6,}" />
      <input type="password" name="confirm"   placeholder="#{I18.ConfirmPassword}" autocomplete="confirm-password" pattern=".{6,}" />
      <input type="password" name="inviteKey" placeholder="#{I18.InviteKey}"       autocomplete="password"         pattern=".{6,}" />
    </form>
  </div>"""
  document.getElementById('registerWindow').prepend GetAppLogo()
  form$       = document.getElementById 'register'
  pass$       = $ '[name=pass]'
  confirm$    = $ '[name=confirm]'
  navigation$ = $ 'navigation'
  navigation$.innerHTML = ''
  navigation$.append IconButton 'Login', LoginForm
  navigation$.append IconButton 'Register', ' default', form$.onsubmit = (e) ->
    form$      = document.getElementById 'register'
    user$      = $ '[name=user]'
    pass$      = $ '[name=pass]'
    confirm$   = $ '[name=confirm]'
    inviteKey$ = $ '[name=inviteKey]'
    e.preventDefault()
    user = user$.value
    pass = pass$.value
    confirm = confirm$.value
    inviteKey = inviteKey$.value
    if pass is confirm then confirm$.setCustomValidity ''
    else return confirm$.setCustomValidity I18.PasswordNoMatch
    seedSalt   = btoa $forge.random.getBytesSync 128
    inviteSalt = btoa $forge.random.getBytesSync 128
    hashedPass = SHA512 [ pass, seedSalt ].join ':'
    hashedInviteKey = SHA512 [ inviteKey, inviteSalt ].join ':'
    window.UserID = user
    CALL 'register', id:user, pass:hashedPass, salt:seedSalt, inviteKey:hashedInviteKey, inviteSalt:inviteSalt
    .then ->
      window.dispatchEvent new Event 'register'
      window.dispatchEvent new Event 'login'
    .catch (error) ->
      user$.setCustomValidity error
      NotificationToast.show error
    null
  pass$.onchange = confirm$.onkeyup = ->
    state = if pass$.value is confirm$.value then '' else I18.PasswordNoMatch
    confirm$.setCustomValidity state
  window.dispatchEvent new Event 'registerform'
  null
