@require 'bundinha/auth/auth'

@config "inviteKey.txt": ->
  if fs.existsSync p = path.join ConfigDir, 'inviteKey.txt'
    APP.InviteKey = fs.readFileSync(p).toString()
  else fs.writeFileSync p, APP.InviteKey = 'secretKey!'

@public "/login", (q,req,res)->
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
    await APP.AddAuthCookie res, q
    res.json error:false
    null
  null

@client RequestLogin: (user,pass,response)->
  { challenge } = response
  clientSalt = btoa forge.random.getBytesSync 128
  hashedPass = SHA512 [ pass,       challenge.seedSalt    ].join ':'
  hashedPass = SHA512 [ hashedPass, challenge.storageSalt ].join ':'
  hashedPass = SHA512 [ hashedPass, clientSalt            ].join ':'
  ajax '/login', id:user, pass:hashedPass, salt:clientSalt

@public "/register", (q,req,res)->
  APP.user.get q.id, (error,rec)->
    hashedInviteKey = SHA512 [ APP.InviteKey, q.inviteSalt ].join ':'
    return res.json error:'Invalid InviteKey' unless q.inviteKey is hashedInviteKey
    return res.json error:'User exists'       unless error
    storageSalt = Buffer.from(forge.random.getBytesSync 128).toString 'base64'
    hashedPass = SHA512 [ q.pass, storageSalt ].join ':'
    userRecord =
      id:q.id
      pass: hashedPass
      seedSalt: q.salt
      storageSalt: storageSalt
    await Promise.all [
      APP.user.put q.id, JSON.stringify userRecord
      AddAuthCookie res, q ]
    res.json error:false
    return
  return
