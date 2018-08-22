
#  █████  ██    ██ ████████ ██   ██
# ██   ██ ██    ██    ██    ██   ██
# ███████ ██    ██    ██    ███████
# ██   ██ ██    ██    ██    ██   ██
# ██   ██  ██████     ██    ██   ██

$$.forge = require 'node-forge'

APP.config ->
  if fs.existsSync p = path.join RootDir, 'config', 'inviteKey.txt'
    APP.InviteKey = fs.readFileSync(p).toString()
  else fs.writeFileSync p, APP.InviteKey = 'secretKey!'

APP.sharedApi SHA512: (value)->
  forge.md.sha512.create().update( value ).digest().toHex()

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
    res.cookie 'SESSION', cookie, expire: 360000 + Date.now()
    res.json error:false
    null
  null

APP.public "/register", (q,req,res)->
  APP.user.get q.id, (error,rec)->
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
    res.cookie 'SESSION', cookie, expire: 360000 + Date.now()
    res.json error:false
    null
  null

APP.private '/logout', (q,req,res)->
  res.clearCookie 'SESSION'
  res.json {}
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
      showToastNotification 'offline mode' if error is 'offline'
      false
  else Promise.resolve false

api.ButtonLogout = ->
  btn = IconButton 'Logout'
  btn.onclick = ->
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

api.LoginForm = (abortable=yes,onlogin='/')->
  document.body.innerHTML = """
  <div id="navigation" class="navigation"></div>
  <div class="window modal#{if abortable then '' else ' monolithic'}" id="loginWindow">
    <form id="login">
      <input type="email"    name="id"                   placeholder="#{I18.Username}" autocomplete="username" autofocus="true" />
      <input type="password" name="pass" pattern=".{6,}" placeholder="#{I18.Password}" autocomplete="password" />
    </form>
  </div>
  """
  if AppLogo?
    i = new Image
    i.src = URL.createObjectURL new Blob [AppLogo], filename:'AppLogo', type:'image/svg+xml'
    document.getElementById('loginWindow').prepend i
  form$ = document.getElementById 'login'
  navigation$ = document.getElementById 'navigation'
  navigation$.append IconButton 'Register', RegisterForm
  navigation$.append IconButton 'Login', ' default', form$.onsubmit = (e) ->
    e.preventDefault()
    user = ( user$ = document.querySelector '[name=id]' ).value
    pass = ( pass$ = document.querySelector '[name=pass]' ).value
    window.UserID = user
    RequestChallenge( user, pass )
      .then  ( challenge ) -> RequestLogin user, pass, challenge
      .then  (  response ) -> window.location = onlogin
      .catch (     error ) ->
        user$.setCustomValidity error
        setTimeout ( -> user$.setCustomValidity '' ), 3000
    null
  navigation$.append ButtonAbout() if ButtonAbout?
  null

# ██████  ███████  ██████  ██ ███████ ████████ ███████ ██████
# ██   ██ ██      ██       ██ ██         ██    ██      ██   ██
# ██████  █████   ██   ███ ██ ███████    ██    █████   ██████
# ██   ██ ██      ██    ██ ██      ██    ██    ██      ██   ██
# ██   ██ ███████  ██████  ██ ███████    ██    ███████ ██   ██

api.RegisterForm = (abortable=yes,onlogin='/')->
  document.body.innerHTML = """
  <div id="navigation" class="navigation"></div>
  <div class="window modal#{if abortable then '' else ' monolithic'}" id="registerWindow">
    <form id="register" action="/register" method="post">
      <input type="email"    name="user"      placeholder="#{I18.Username}"        autocomplete="username"         autofocus="true"/>
      <input type="password" name="pass"      placeholder="#{I18.Password}"        autocomplete="new-password"     pattern=".{6,}" />
      <input type="password" name="confirm"   placeholder="#{I18.ConfirmPassword}" autocomplete="confirm-password" pattern=".{6,}" />
      <input type="password" name="inviteKey" placeholder="#{I18.InviteKey}"       autocomplete="password"         pattern=".{6,}" />
    </form>
  </div>"""
  form$      = document.getElementById 'register'
  pass$      = document.querySelector '[name=pass]'
  confirm$   = document.querySelector '[name=confirm]'
  navigation$ = document.getElementById 'navigation'
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
      .then  (  response ) -> window.location = '/'
      .catch (     error ) -> user$.setCustomValidity error
    null
  pass$.onchange = confirm$.onkeyup = ->
    state = if pass$.value is confirm$.value then '' else I18.PasswordNoMatch
    confirm$.setCustomValidity state
  navigation$.append ButtonAbout() if ButtonAbout?
  null
