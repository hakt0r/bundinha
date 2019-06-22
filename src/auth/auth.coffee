
# ███████ ███████ ██████  ██    ██ ███████ ██████
# ██      ██      ██   ██ ██    ██ ██      ██   ██
# ███████ █████   ██████  ██    ██ █████   ██████
#      ██ ██      ██   ██  ██  ██  ██      ██   ██
# ███████ ███████ ██   ██   ████   ███████ ██   ██

@flag 'UseAuth'

@config
  AdminUser: 'admin'
  AdminPassword: $forge.util.bytesToHex $forge.random.getBytes 32

@require 'bundinha/db/level'
@db 'session'

@server.init = ->
  try await $fs.mkdir$ '/tmp/auth'
  try rec = await APP.user.get AdminUser
  catch e
    seedSalt = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
    hashedPass = SHA512 [ AdminPassword, seedSalt ].join ':'
    User.create id:AdminUser, pass:hashedPass, seedSalt:seedSalt, group:['admin']
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
    a[u.id] = name:u.id, members:[u.id], isuser:true
    for group in u.group
      unless a[group]
        a[group] = name:group, members:[]
      a[group].members.push u.id
  .on 'end',  (u)-> resolve Object.values(a).map callback

User.get = (id)-> new User JSON.parse await APP.user.get id
User.del = (id)-> APP.user.del id
User.set = (id,rec)-> APP.user.put id, rec
User.map = (callback)-> new Promise (resolve)->
  a = []
  APP.user.createReadStream()
  .on 'data', (u)-> try a.push callback JSON.parse u.value catch e then console.log u
  .on 'end',  (u)-> resolve a

User.authenticatePlain = (id,password,rec)->
  return false unless id? and password?
  try rec = rec || JSON.parse await APP.user.get id
  return false unless rec?
  hashedPass = SHA512 [ password,   rec.seedSalt ].join ':'
  hashedPass = SHA512 [ hashedPass, rec.storageSalt ].join ':'
  return rec.pass is hashedPass

User.authenticateWithClientSalt = (id,password,salt)->
  return false unless id? and password?
  try rec = rec || JSON.parse await APP.user.get id
  return false unless rec?
  hashedPass = SHA512 [ rec.pass, salt ].join ':'
  return password is hashedPass

# User.authenticateRequest = @server.DenyAuth
User.authenticateRequest = (q,req,res)->
  rec = await APP.user.get q.id
  rec = JSON.parse rec
  unless q.pass?
    res.json challenge:
      storageSalt:rec.storageSalt
      seedSalt:rec.seedSalt
    return false
  unless await User.authenticateWithClientSalt q.id, q.pass, q.salt, rec
    throw new Error I18.NXUser
  req.USER = rec
  rec

# User.registerRequest = @server.DenyAuth
User.registerRequest = (q,req,res)->
  throw new Error 'User exists' if ( try rec = await APP.user.get q.id )?
  throw new Error 'Invalid InviteKey' unless q.inviteKey is SHA512 [ APP.InviteKey, q.inviteSalt ].join ':'
  await User.create id:q.id, pass:q.pass, seedSalt:q.salt
  rec

@server.User.create = (opts)->
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
  try id   = await APP.session.get cookie
  try user = await APP.user.get req.ID = id
  throw new Error 'Access denied: invalid session' unless user
  try req.USER = JSON.parse user
  throw new Error 'Access denied: invalid user' unless req.USER?

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

@server.AuthSuccess = (q,req,res)->
  res.json success:true, groups:req.USER.group

@server.DenyAuth = (reason='')->
  throw new Error 'Access Denied' + reason

@server.Logout = (q,req,res)->
  try APP.session.get req.COOKIE catch e then return console.log 'logout:no:cookie', e
  try APP.session.del req.COOKIE
  console.log 'DEAUTH'.yellow, req.USER.id, req.USER.group
  res.setHeader 'Set-Cookie', "SESSION=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"
  $fs.unlinkSync ( $path.join '/tmp/auth', req.COOKIE ), '' if $fs.existsSync '/tmp/auth'
  res.json success:true

# ██████  ███████  ██████  ██    ██ ███████ ███████ ████████ ███████
# ██   ██ ██      ██    ██ ██    ██ ██      ██         ██    ██
# ██████  █████   ██    ██ ██    ██ █████   ███████    ██    ███████
# ██   ██ ██      ██ ▄▄ ██ ██    ██ ██           ██    ██         ██
# ██   ██ ███████  ██████   ██████  ███████ ███████    ██    ███████
#                     ▀▀

@private "/authenticated", (q,req,res)-> await AuthSuccess q,req,res
@private '/logout',        (q,req,res)-> await Logout      q,req,res

# @private "/login", @server.DenyAuth
@public "/login", (q,req,res)->
  return unless rec = await User.authenticateRequest q, req, res
  await AddAuthCookie res, rec
  AuthSuccess q, req, res, rec
  return

# @private "/register", @server.DenyAuth
@public "/register", (q,req,res)->
  return unless rec = await User.registerRequest q,req,res
  await AddAuthCookie res, rec
  AuthSuccess q, req, res, rec
  return
