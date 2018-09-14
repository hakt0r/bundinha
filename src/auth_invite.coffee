
#  █████  ██    ██ ████████ ██   ██
# ██   ██ ██    ██    ██    ██   ██
# ███████ ██    ██    ██    ███████
# ██   ██ ██    ██    ██    ██   ██
# ██   ██  ██████     ██    ██   ██

APP.config "inviteKey.txt": ->
  if fs.existsSync p = path.join ConfigDir, 'inviteKey.txt'
    APP.InviteKey = fs.readFileSync(p).toString()
  else fs.writeFileSync p, APP.InviteKey = 'secretKey!'

APP.private "/authenticated", (q,req,res)->
  res.json error:false

APP.public "/login", (q,req,res)->
  APP.user.get q.id, (error,rec)->
    try rec = JSON.parse rec catch e
      return res.json id:q.id, error:e.message
    if error
      return res.json id:q.id, error:I18.NXUser
    unless q.pass?
      return res.json challenge:
        storageSalt: rec.storageSalt
        seedSalt:    rec.seedSalt
    hashedPass = SHA512 [ rec.pass, q.salt ].join ':'
    unless hashedPass is q.pass
      return res.json id:q.id, error:I18.NXUser
    cookie = Buffer.from(forge.random.getBytesSync 128).toString('base64')
    await APP.session.put cookie, q.id
    res.setHeader 'Set-Cookie', "SESSION=#{cookie}; expires=#{new Date(new Date().getTime()+86409000).toUTCString()}; path=/"
    res.json error:false
    null
  null

APP.public "/register", (q,req,res)->
  APP.user.get q.id, (error,rec)->
    console.log APP.InviteKey
    hashedInviteKey = SHA512 [ APP.InviteKey, q.inviteSalt ].join ':'
    return res.json error:'Invalid InviteKey' unless q.inviteKey is hashedInviteKey
    return res.json error:'User exists'       unless error
    cookie      = Buffer.from(forge.random.getBytesSync 128).toString 'base64'
    storageSalt = Buffer.from(forge.random.getBytesSync 128).toString 'base64'
    hashedPass = SHA512 [ q.pass, storageSalt ].join ':'
    userRecord =
      pass: hashedPass
      seedSalt: q.salt
      storageSalt: storageSalt
    await Promise.all [
      APP.user.put q.id, JSON.stringify userRecord
      APP.session.put cookie, q.id ]
    res.setHeader 'Set-Cookie', "SESSION=#{cookie}; expires=#{new Date(new Date().getTime()+86409000).toUTCString()}; path=/"
    res.json error:false
    null
  null

APP.private '/logout', (q,req,res)->
  res.setHeader 'Set-Cookie', "SESSION=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"
  APP.session.delete cookie
  APP.apiResponse {}
  true

#  ██████ ██      ██ ███████ ███    ██ ████████
# ██      ██      ██ ██      ████   ██    ██
# ██      ██      ██ █████   ██ ██  ██    ██
# ██      ██      ██ ██      ██  ██ ██    ██
#  ██████ ███████ ██ ███████ ██   ████    ██

APP.script 'node_modules','node-forge','dist','forge.min.js'

api = APP.clientApi()

api.CheckLoginCookie = ->
  if document.cookie.match /SESSION=/
    ajax '/authenticated', {}
    .then (result)-> not result.error
    .catch (error)->
      NotificationToast.show 'offline mode' if error is 'offline'
      false
  else Promise.resolve false

api.ButtonLogout = ->
  btn = IconButton 'Logout'
  btn.onclick = ->
    window.dispatchEvent new Event 'logout'
    ajax '/logout', {}
    .then LoginForm
    .catch LoginForm
  btn

api.RequestChallenge = (user,pass)->
  ajax '/login', id:user

api.RequestLogin = (user,pass,response)->
  { challenge } = response
  clientSalt = btoa forge.random.getBytesSync 128
  hashedPass = SHA512 [ pass,       challenge.seedSalt    ].join ':'
  hashedPass = SHA512 [ hashedPass, challenge.storageSalt ].join ':'
  hashedPass = SHA512 [ hashedPass, clientSalt            ].join ':'
  ajax '/login', id:user, pass:hashedPass, salt:clientSalt

# ██       ██████   ██████  ██ ███    ██
# ██      ██    ██ ██       ██ ████   ██
# ██      ██    ██ ██   ███ ██ ██ ██  ██
# ██      ██    ██ ██    ██ ██ ██  ██ ██
# ███████  ██████   ██████  ██ ██   ████

api.GetAppLogo = ->
  return null unless AppLogo?
  i = new Image
  i.src = URL.createObjectURL new Blob [AppLogo], filename:'AppLogo', type:'image/svg+xml'
  i

api.LoginForm = -> requestAnimationFrame ->
  document.querySelector('content').innerHTML = """
  <div class="window modal monolithic" id="loginWindow">
    <form id="login">
      <input type="email"    name="id"                   placeholder="#{I18.Username}" autocomplete="username" autofocus="true" />
      <input type="password" name="pass" pattern=".{6,}" placeholder="#{I18.Password}" autocomplete="password" />
    </form>
  </div>
  """
  document.getElementById('loginWindow').prepend GetAppLogo()
  form$ = document.getElementById 'login'
  navigation$ = document.querySelector('navigation')
  navigation$.innerHTML = ''
  navigation$.append IconButton 'Register', RegisterForm
  navigation$.append IconButton 'Login', ' default', form$.onsubmit = (e) ->
    e.preventDefault()
    user = ( user$ = document.querySelector '[name=id]' ).value
    pass = ( pass$ = document.querySelector '[name=pass]' ).value
    window.UserID = user
    RequestChallenge( user, pass )
    .then  (challenge)-> RequestLogin user, pass, challenge
    .then  (response)-> window.dispatchEvent new Event 'login'
    .catch (error)->
      NotificationToast.show error
      user$.setCustomValidity error
      setTimeout ( -> user$.setCustomValidity '' ), 3000
    null
  window.dispatchEvent new Event 'loginform'
  null

# ██████  ███████  ██████  ██ ███████ ████████ ███████ ██████
# ██   ██ ██      ██       ██ ██         ██    ██      ██   ██
# ██████  █████   ██   ███ ██ ███████    ██    █████   ██████
# ██   ██ ██      ██    ██ ██      ██    ██    ██      ██   ██
# ██   ██ ███████  ██████  ██ ███████    ██    ███████ ██   ██

api.RegisterForm = -> requestAnimationFrame ->
  document.querySelector('content').innerHTML = """
  <div class="window modal monolithic" id="registerWindow">
    <form id="register" action="/register" method="post">
      <input type="email"    name="user"      placeholder="#{I18.Username}"        autocomplete="username"         autofocus="true"/>
      <input type="password" name="pass"      placeholder="#{I18.Password}"        autocomplete="new-password"     pattern=".{6,}" />
      <input type="password" name="confirm"   placeholder="#{I18.ConfirmPassword}" autocomplete="confirm-password" pattern=".{6,}" />
      <input type="password" name="inviteKey" placeholder="#{I18.InviteKey}"       autocomplete="password"         pattern=".{6,}" />
    </form>
  </div>"""
  document.getElementById('registerWindow').prepend GetAppLogo()
  form$      = document.getElementById 'register'
  pass$      = document.querySelector '[name=pass]'
  confirm$   = document.querySelector '[name=confirm]'
  navigation$ = document.querySelector('navigation')
  navigation$.innerHTML = ''
  navigation$.append IconButton 'Login', LoginForm
  navigation$.append IconButton 'Register', ' default', form$.onsubmit = (e) ->
    form$      = document.getElementById 'register'
    user$      = document.querySelector '[name=user]'
    pass$      = document.querySelector '[name=pass]'
    confirm$   = document.querySelector '[name=confirm]'
    inviteKey$ = document.querySelector '[name=inviteKey]'
    e.preventDefault()
    user = user$.value
    pass = pass$.value
    confirm = confirm$.value
    inviteKey = inviteKey$.value
    if pass is confirm then confirm$.setCustomValidity ''
    else return confirm$.setCustomValidity I18.PasswordNoMatch
    seedSalt   = btoa forge.random.getBytesSync 128
    inviteSalt = btoa forge.random.getBytesSync 128
    hashedPass = SHA512 [ pass, seedSalt ].join ':'
    hashedInviteKey = SHA512 [ inviteKey, inviteSalt ].join ':'
    window.UserID = user
    ajax '/register', id:user, pass:hashedPass, salt:seedSalt, inviteKey:hashedInviteKey, inviteSalt:inviteSalt
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
