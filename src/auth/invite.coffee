@require 'bundinha/auth/auth'
# a9883e62aeadf6709049ddda434e3d3ec041fec15b182c3f52609aa7ed50682d
@config
  AdminUser: 'admin'
  AdminPassword: $forge.util.bytesToHex $forge.random.getBytes 32
  InviteKey: $forge.util.bytesToHex $forge.random.getBytes 32

@server.init = ->
  try rec = await APP.user.get AdminUser
  catch e
    seedSalt = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
    hashedPass = SHA512 [ AdminPassword, seedSalt ].join ':'
    User.create id:AdminUser, pass:hashedPass, seedSalt:seedSalt, group:['admin']
  return

@public "/login", (q,req,res)->
  rec = await APP.user.get q.id
  rec = JSON.parse rec
  return res.json challenge: storageSalt:rec.storageSalt, seedSalt:rec.seedSalt unless q.pass?
  hashedPass = SHA512 [ rec.pass, q.salt ].join ':'
  throw new Error I18.NXUser unless hashedPass is q.pass
  await AddAuthCookie res, q
  AuthSuccess q, req, res, rec
  null

@public "/register", (q,req,res)->
  try rec = await APP.user.get q.id
  return throw new Error 'User exists' if rec?
  # check inviteKey
  unless q.inviteKey is SHA512 [ APP.InviteKey, q.inviteSalt ].join ':'
    return res.json error:'Invalid InviteKey'
  await Promise.all [
    User.create id:q.id, pass:q.pass, seedSalt:q.salt
    AddAuthCookie res, q ]
  AuthSuccess q, req, res, rec

@client.RequestLogin = (user,pass,response)->
  { challenge } = response
  clientSalt = btoa $forge.random.getBytesSync 128
  hashedPass = SHA512 [ pass,       challenge.seedSalt    ].join ':'
  hashedPass = SHA512 [ hashedPass, challenge.storageSalt ].join ':'
  hashedPass = SHA512 [ hashedPass, clientSalt            ].join ':'
  CALL '/login', id:user, pass:hashedPass, salt:clientSalt
  .then LoginResult

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

@command 'user', ->
  @APP.initConfig(); @APP.initDB(); [ user ] = process.argv.slice 1 + process.argv.indexOf 'user'
  u = await User.get user
  console.log if process.stdout.isTTY then u.record else JSON.stringify u.record, null, 2
  process.exit 0

@command 'passwd', ->
  @APP.initConfig(); @APP.initDB(); [ user, pass ] = process.argv.slice 1 + process.argv.indexOf 'passwd'
  await User.passwd user, pass; process.exit 0

@command 'group', ->
  @APP.initConfig(); @APP.initDB(); [ user ] = args = process.argv.slice 1 + process.argv.indexOf 'group'
  await User.addGroups user, args.slice 1; process.exit 0

@command 'adduser', ->
  @APP.initConfig(); @APP.initDB(); [ user, pass ] = args = process.argv.slice 1 + process.argv.indexOf 'adduser'
  try
    await User.get user
    console.log 'User exists:'.bold, user
    process.exit 1
  seedSalt   = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
  hashedPass = SHA512 [ pass, seedSalt ].join ':'
  User.create id:user, pass:hashedPass, seedSalt:seedSalt, group:if args.length > 0 then args else null
  process.exit 0
