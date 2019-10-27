
# ███████ ███████ ██████  ██    ██ ███████ ██████
# ██      ██      ██   ██ ██    ██ ██      ██   ██
# ███████ █████   ██████  ██    ██ █████   ██████
#      ██ ██      ██   ██  ██  ██  ██      ██   ██
# ███████ ███████ ██   ██   ████   ███████ ██   ██

@flag 'UseAuth'
@AuthDB = @AuthDB || 'text'
@require 'bundinha/db/' + @AuthDB
@db 'user',       plugin: @AuthDB
@db 'session',    plugin: @AuthDB

@config
  AdminUser:      'admin'
  AdminPassword:  false
  SessionTimeout: 3600000

@preCommand ->
  try rec = await APP.user.get AdminUser
  catch e
    $$.AdminPassword = $$.AdminPassword || $forge.util.bytesToHex $forge.random.getBytes 32
    $$.AdminUser     = $$.AdminUser     || 'admin'
    await APP.writeConfig()
    seedSalt = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
    hashedPass = SHA512 [ AdminPassword, seedSalt ].join ':'
    User.create args:id:AdminUser, pass:hashedPass, seedSalt:seedSalt, group:['admin']
  return

@serverCron ->
  Cronish.from id:'session:prune', interval:60e3, worker:-> new Promise (resolve)->
    APP.session.createReadStream()
    .on 'data', (entry)->
      { key, value, path } = entry
      return unless try value = JSON.parse value
      [ id, date ] = value
      return if isNaN date = parseInt date
      return if Date.now() < date + SessionTimeout
      console.debug 'session'.yellow.bold, 'reap', (id|'NULL').bold, (( Date.now() - date ) / SessionTimeout ) + 'm old'
      APP.session.del key
    .on 'close', resolve
  return

# ██    ██ ███████ ███████ ██████
# ██    ██ ██      ██      ██   ██
# ██    ██ ███████ █████   ██████
# ██    ██      ██ ██      ██   ██
#  ██████  ███████ ███████ ██   ██

@server class User
  constructor:(opts={})-> Object.assign @record = {}, User.defaults(), opts
  commit:-> APP.user.put(@record.id,JSON.stringify @record).then => @

User.defaults = -> id:User.getUID(), group: []
User.getUID = -> SHA512 Date.now() + '-' + $forge.random.getBytesSync 16

User.groups = (callback)-> new Promise (resolve)->
  a = {}
  APP.user.createReadStream()
  .on 'data', (u)->
    u = JSON.parse u.value
    a[u.id] = name:u.id, members:[u.id], isuser:true, user:u
    for group in u.group
      unless a[group]
        a[group] = name:group, members:[]
      a[group].members.push u.id
  .on 'end',  (u)-> resolve Object.values(a).map callback

User.get = (id)-> new User JSON.parse await APP.user.get id
User.del = (id)-> APP.user.del id
User.set = (id,rec)-> APP.user.put id, rec

User.map = (callback)-> new Promise (resolve)->
  a = []; APP.user.createReadStream()
  .on 'data', (u)-> try ( a.push callback JSON.parse u.value )
  .on 'end',  (u)-> resolve a
@server.User.filter = (callback)-> new Promise (resolve)->
  a = []; APP.user.createReadStream()
  .on 'data', (u)-> try ( a.push u unless false is callback.call u = JSON.parse u.value )
  .on 'end',  (u)-> resolve a
@server.User.admins = -> await User.filter -> @group?.includes('admin') or @id is $$.AdminUser
@server.User.adminIds = -> ( await User.admins() ).map (u)-> u.id

User.aliasSearch = (alias)-> new Promise (resolve)->
  a = []
  APP.user.createReadStream()
  .on 'data', (data)->
    try u = JSON.parse data.value
    catch e then console.log data, e
    return unless ( u.id is alias ) or ( u.alias?.includes? alias )
    a.push u.id
  .on 'end',  (u)-> resolve a.shift()

@server.User.create = (req)->
  opts = req.args
  opts.storageSalt = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
  opts.pass = SHA512 [ opts.pass, opts.storageSalt ].join ':'
  new User(opts).commit()

@server.User.passwd = (user,pass)->
  u = await User.get user
  opts = {}
  opts.seedSalt    = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
  opts.storageSalt = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
  hashedPass       = SHA512 [ pass,       opts.seedSalt ].join ':'
  opts.pass        = SHA512 [ hashedPass, opts.storageSalt ].join ':'
  Object.assign u.record, opts
  u.commit()

@server.User.addGroups = (user,groups)->
  u = await User.get user
  u.record.group = u.record.group.concat(groups).unique
  u.commit()

#  █████  ██████  ██
# ██   ██ ██   ██ ██
# ███████ ██████  ██
# ██   ██ ██      ██
# ██   ██ ██      ██

@server.AddAuthCookie = (req)->
  cookie = User.getUID()
  console.debug 'COOKIE'.yellow, req.USER.id, req.USER.group
  header  = "SESSION=#{cookie};"
  header += " expires=#{new Date(Date.now()+86409000).toUTCString()};"
  header += " path=/;"
  header += " domain=#{$$.CookieDomain};" if $$.CookieDomain?
  req.setHeader 'Set-Cookie', header
  req.COOKIE = cookie
  APP.session.put cookie, JSON.stringify [req.USER.id,Date.now()]

@server.RequireAuth = (req)->
  unless ( await ReadAuth req ) and req.USER? and req.GROUP?.includes? '$auth'
    req.err? 'Access denied: invalid user'
    false
  else true

@server.ReadAuth = (req,opts={})->
  if auth = req.htReq?.headers?.authorization
    auth = ( Buffer.from auth.split(' ').pop(), 'base64' ).toString().split(':')
    return false unless user = try JSON.parse await APP.user.get auth[0]
    return false unless await User.authenticatePlain auth[0], auth[1], user
    AddAuthToRequest req, user, false
    return true
  return false unless cookies = req.htReq.headers.cookie
  return false unless cookie = ( cookies.match /SESSION=([A-Za-z0-9+/=]+={0,3});?/ )?[1]
  return false unless ( session = try JSON.parse await APP.session.get cookie )?
  [ id, date ] = session
  date = parseInt date
  return false     if isNaN date = parseInt date
  minute = 60000
  if Date.now() > date + SessionTimeout
    console.debug 'session'.red.bold, 'reject', id.bold, ((( date + 3600e3 ) -  Date.now() ) / minute ) + 'm old'
    return false
  return false unless user = try await APP.user.get id
  AddAuthToRequest req, JSON.parse(user), cookie
  true

@server.AddAuthToRequest = (req,rec,cookie)->
  req.COOKIE = cookie if cookie
  req.UID    = rec.id
  req.GROUP  = ['$auth'].concat ( rec.group || [] ).slice()
  req.USER   = rec
  true

@server.RequireGroupBare = (hasGroup,needsGroup)->
  return true if hasGroup.includes 'admin'
  needsGroup.reduce ( (access,i)-> access or hasGroup.includes i ), no

@server.RequireGroup = (req,needsGroup)->
  user_id = req.USER.id
  if user_id is AdminUser and not req.USER.group
    req.USER.group = ['admin']
    APP.user.put user_id, JSON.stringify req.USER
  hasGroup = req.USER.group
  console.debug 'GROUP'.yellow, user_id, 'has:', hasGroup, 'needs:', needsGroup
  DenyAuth ': no groups'     unless hasGroup
  DenyAuth ': invalid group' unless RequireGroupBare hasGroup, needsGroup

@server.AuthSuccess = (req)->
  try req.setHeader "X-Auth-User",    req.USER.id
  try req.setHeader "X-Auth-Group", ( req.USER.group || [] ).join ', '
  success:true, groups:req.USER.group

@server.DenyAuth = (reason='')->
  throw new Error 'Access Denied' + reason

@server.Logout = (req)->
  return true unless req.COOKIE
  if req.htReq
    req.setHeader 'Set-Cookie', "SESSION=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"
  await APP.session.del req.COOKIE
  console.debug 'DEAUTH'.yellow, req.USER.id, req.USER.group
  true

# ██████  ███████  ██████  ██    ██ ███████ ███████ ████████ ███████
# ██   ██ ██      ██    ██ ██    ██ ██      ██         ██    ██
# ██████  █████   ██    ██ ██    ██ █████   ███████    ██    ███████
# ██   ██ ██      ██ ▄▄ ██ ██    ██ ██           ██    ██         ██
# ██   ██ ███████  ██████   ██████  ███████ ███████    ██    ███████
#                     ▀▀

User.authenticatePlain = (id,password,rec)->
  return false unless id? and password?
  unless rec
    try rec = JSON.parse await APP.user.get id
  return false unless rec?
  hashedPass = SHA512 [ password,   rec.seedSalt    ].join ':'
  hashedPass = SHA512 [ hashedPass, rec.storageSalt ].join ':'
  return rec.pass is hashedPass

User.authenticateWithClientSalt = (id,password,salt)->
  return false unless id? and password?
  try rec = rec || JSON.parse await APP.user.get id
  return false unless rec?
  hashedPass = SHA512 [ rec.pass, salt ].join ':'
  return password is hashedPass

User.authenticateRequest = (req)->
  { id, pass, salt } = req.args
  rec = await APP.user.get id
  rec = JSON.parse rec
  return challenge:storageSalt:rec.storageSalt,seedSalt:rec.seedSalt unless pass?
  unless await User.authenticateWithClientSalt id, pass, salt, rec
    throw new Error "#{I18.NXUser}: #{id}"
  AddAuthToRequest req, rec

User.registerRequest = (req)->
  { id, pass, salt, inviteKey, inviteSalt } = req.args
  throw new Error 'User exists' if ( try rec = await APP.user.get id )?
  throw new Error 'Invalid InviteKey' unless inviteKey is SHA512 [ APP.InviteKey, inviteSalt ].join ':'
  unless rec = await User.create args:id:id, pass:pass, seedSalt:salt
    throw new Error "#{I18.RegistrationFailed}: #{id}"
  AddAuthToRequest req, rec

@public 'login', ->
  result = await User.authenticateRequest @
  return result if result.challenge
  await AddAuthCookie @
  return  AuthSuccess @

@public 'register', ->
  return unless await User.registerRequest @
  await AddAuthCookie @
  return  AuthSuccess @

@private 'logout', ->
  return await Logout @

@private 'authenticated', ->
  return  AuthSuccess @
