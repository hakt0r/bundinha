@require 'bundinha/auth/auth'

@public "/register", APP.denyAuth

@public "/login", (q,req,res)->
  APP.user.get q.id, (error,rec)->
    try rec = JSON.parse rec catch e
      return res.json id:q.id, error:e.message
    if error
      return res.json id:q.id, error:I18.NXUser
    unless q.pass?
      return res.json challenge:'fixme:plaintext'
    user = q.user.replace( /[^a-z0-9]/gi, '' ).substring 0, 512
    pass = q.pass
    i = cp.exec = """
      LANG=C ssh #{user}@localhost -- echo '@ok@'
    """
    i.stderr.data = (data)->
      console.log 'err', data = data.toString()
    i.stdout.data = (data)->
      console.log 'out', data = data.toString()
    hashedPass = SHA512 [ rec.pass, q.salt ].join ':'
    unless hashedPass is q.pass
      return res.json id:q.id, error:I18.NXUser
    cookie = Buffer.from(forge.random.getBytesSync 128).toString('base64')
    await APP.session.put cookie, q.id
    res.setHeader 'Set-Cookie', "SESSION=#{cookie}; expires=#{new Date(new Date().getTime()+86409000).toUTCString()}; path=/"
    res.json error:false, WebSockets:WebSockets
    null
  null

$client = @client()

$client.RequestLogin = (user,pass,response)->
  { challenge } = response
  if challenge is 'fixme:plaintext'
    hashedPass = pass
    clientSalt = null
  else
    clientSalt = btoa forge.random.getBytesSync 128
    hashedPass = SHA512 [ pass,       challenge.seedSalt    ].join ':'
    hashedPass = SHA512 [ hashedPass, challenge.storageSalt ].join ':'
    hashedPass = SHA512 [ hashedPass, clientSalt            ].join ':'
  ajax '/login', id:user, pass:hashedPass, salt:clientSalt
  .then (result)->
    console.log result
    return ConnectWebSocket() if result.WebSockets
    result

@private '/logout', (q,req,res)->
  APP.session.delete req.COOKIE
  res.setHeader 'Set-Cookie', "SESSION=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"
  res.json errot:false
  return
