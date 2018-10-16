@require 'bundinha/auth/auth'

@config InviteKey: 'secretKey!'

@public "/login", (q,req,res)->
  rec = await APP.user.get q.id, rec
  rec = JSON.parse rec
  unless q.pass?
    return res.json challenge:
      storageSalt: rec.storageSalt
      seedSalt:    rec.seedSalt
  hashedPass = SHA512 [ rec.pass, q.salt ].join ':'
  threow new Error I18.NXUser unless hashedPass is q.pass
  await AddAuthCookie res, q
  res.json error:false, WebSockets:WebSockets
  null

@client RequestLogin: (user,pass,response)->
  { challenge } = response
  clientSalt = btoa $forge.random.getBytesSync 128
  hashedPass = SHA512 [ pass,       challenge.seedSalt    ].join ':'
  hashedPass = SHA512 [ hashedPass, challenge.storageSalt ].join ':'
  hashedPass = SHA512 [ hashedPass, clientSalt            ].join ':'
  CALL '/login', id:user, pass:hashedPass, salt:clientSalt
  .then (result)->
    return ConnectWebSocket() if result.WebSockets
    result

@public "/register", (q,req,res)->
  APP.user.get q.id, (error,rec)->
    hashedInviteKey = SHA512 [ APP.InviteKey, q.inviteSalt ].join ':'
    return res.json error:'Invalid InviteKey' unless q.inviteKey is hashedInviteKey
    return res.json error:'User exists'       unless error
    storageSalt = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
    hashedPass = SHA512 [ q.pass, storageSalt ].join ':'
    userRecord =
      id:q.id
      pass: hashedPass
      seedSalt: q.salt
      storageSalt: storageSalt
    await Promise.all [
      APP.user.put q.id, JSON.stringify userRecord
      AddAuthCookie res, q ]
    res.json error:false, WebSockets:WebSockets
    return
  return
