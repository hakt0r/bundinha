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

@server.User.create = (opts)->
  opts.storageSalt = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
  opts.pass = SHA512 [ opts.pass, opts.storageSalt ].join ':'
  new User(opts).commit()

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
    User.create id:q.id, pass: q.pass, seedSalt: q.salt
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
