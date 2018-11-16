
@require 'bundinha/auth/auth'

@public "/register", APP.denyAuth

@public "/login", (q,req,res)->
  rec = await APP.user.get q.id, rec
  rec = JSON.parse rec
  unless q.pass?
    return res.json challenge:'fixme:plaintext'
  user = q.user.replace( /[^a-z0-9]/gi, '' ).substring 0, 512
  pass = q.pass
  await $cp.exec$ """
    LANG=C ssh #{user}@localhost -- echo '@ok@'
  """
  i.stderr.data = (data)->
    console.log 'err', data = data.toString()
  i.stdout.data = (data)->
    console.log 'out', data = data.toString()
  await AddAuthCookie res, q
  AuthSuccess q, req, res, rec
  null

@client.RequestLogin = (user,pass,response)->
  { challenge } = response
  if challenge is 'fixme:plaintext'
    hashedPass = pass
    clientSalt = null
  else
    clientSalt = btoa $forge.random.getBytesSync 128
    hashedPass = SHA512 [ pass,       challenge.seedSalt    ].join ':'
    hashedPass = SHA512 [ hashedPass, challenge.storageSalt ].join ':'
    hashedPass = SHA512 [ hashedPass, clientSalt            ].join ':'
  CALL '/login', id:user, pass:hashedPass, salt:clientSalt
  .then LoginResult
