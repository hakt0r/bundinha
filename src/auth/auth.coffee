
# ███████ ███████ ██████  ██    ██ ███████ ██████
# ██      ██      ██   ██ ██    ██ ██      ██   ██
# ███████ █████   ██████  ██    ██ █████   ██████
#      ██ ██      ██   ██  ██  ██  ██      ██   ██
# ███████ ███████ ██   ██   ████   ███████ ██   ██

@flag   'UseAuth'
@db     'user'
@db     'session'

@server class User
  constructor:(opts={})-> Object.assign @record = {}, User.defaults(), opts
  commit:-> APP.user.put(@record.id,JSON.stringify @record).then => @
User.defaults = -> id:User.getUID(), group: []
User.getUID = -> SHA512 Date.now() + '-' + $forge.random.getBytesSync 16

@server.AddAuthCookie = (res,user)->
  cookie = User.getUID()
  res.setHeader 'Set-Cookie', "SESSION=#{cookie}; expires=#{new Date(new Date().getTime()+86409000).toUTCString()}; path=/"
  $fs.writeFileSync ( $path.join '/tmp/auth', cookie ), '' if $fs.existsSync '/tmp/auth'
  console.log 'AUTH'.yellow, user.id, user.group
  APP.session.put cookie, user.id

@server.RequireAuth = (req)->
  throw new Error 'Access denied: no cookie' unless cookies = req.headers.cookie
  CookieReg = /SESSION=([A-Za-z0-9+/=]+={0,3});?/
  throw new Error 'Access denied: cookie' unless match = cookies.match CookieReg
  req.COOKIE = cookie = match[1]
  id   = await APP.session.get cookie
  user = await APP.user.get req.ID = id
  throw new Error 'Access denied: invalid session' unless ( req.USER = JSON.parse user )?

@server.RequireGroup = (req,group)->
  in_group = (access,i)-> access or has_group.includes i
  user_id = req.USER.id
  if user_id is AdminUser and not req.USER.group
    req.USER.group = ['admin']
    APP.user.put user_id, JSON.stringify req.USER
  has_group = req.USER.group
  console.debug 'GROUP'.yellow, user_id, 'has:', has_group, 'needs:', group
  DenyAuth 'Access denied: no groups'     unless has_group
  DenyAuth 'Access denied: invalid group' unless group.reduce in_group, no

@server.AuthSuccess = (q,req,res)->
  res.json success:true

@server.DenyAuth = (reason)->
  throw new Error 'Access Denied'

@server.Logout = (q,req,res)->
  try APP.session.del req.COOKIE
  res.setHeader 'Set-Cookie', "SESSION=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"
  res.json success:true

@private "/login",         @server.DenyAuth
@private "/register",      @server.DenyAuth
@private "/authenticated", @server.AuthSuccess
@private '/logout',        @server.Logout

#  ██████ ██      ██ ███████ ███    ██ ████████
# ██      ██      ██ ██      ████   ██    ██
# ██      ██      ██ █████   ██ ██  ██    ██
# ██      ██      ██ ██      ██  ██ ██    ██
#  ██████ ███████ ██ ███████ ██   ████    ██

@script 'node_modules','node-forge','dist','forge.min.js'

@client.RequestLogin = ->
  Promise.reject()

@client.CheckLoginCookie = ->
  if document.cookie.match /SESSION=/
    CALL '/authenticated', {}
    .then CheckLoginCookieWasSuccessful
    .catch (error)->
      NotificationToast.show 'offline mode' if error is 'offline'
      false
  else Promise.resolve false

@client.CheckLoginCookieWasSuccessful = (result)->
  result.success || false

@client.ButtonLogout = ->
  btn = IconButton 'Logout'
  btn.onclick = ->
    ModalWindow.closeActive() if ModalWindow.closeActive
    window.dispatchEvent new Event 'logout'
    CALL('/logout',{}).then(anew = -> $$.emit 'logout';do LoginForm).catch(anew)
  btn

@client.Login = (user,pass)->
  CALL '/login', id:user
  .then (challenge)-> RequestLogin user, pass, challenge

@client.LoginResult = (result)->
  result.success || false

# ██       ██████   ██████  ██ ███    ██
# ██      ██    ██ ██       ██ ████   ██
# ██      ██    ██ ██   ███ ██ ██ ██  ██
# ██      ██    ██ ██    ██ ██ ██  ██ ██
# ███████  ██████   ██████  ██ ██   ████

@client.GetAppLogo = ->
  return null unless AppLogo?
  i = new Image
  i.src = URL.createObjectURL new Blob [AppLogo], filename:'AppLogo', type:'image/svg+xml'
  i.draggable = false
  i

@client.LoginForm = -> requestAnimationFrame ->
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
    Login user, pass
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

@client.RegisterForm = -> requestAnimationFrame ->
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
    seedSalt   = btoa $forge.random.getBytesSync 128
    inviteSalt = btoa $forge.random.getBytesSync 128
    hashedPass = SHA512 [ pass, seedSalt ].join ':'
    hashedInviteKey = SHA512 [ inviteKey, inviteSalt ].join ':'
    window.UserID = user
    CALL '/register', id:user, pass:hashedPass, salt:seedSalt, inviteKey:hashedInviteKey, inviteSalt:inviteSalt
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
