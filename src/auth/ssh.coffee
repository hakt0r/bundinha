
@require 'bundinha/auth/dbremote'
@require 'bundinha/auth/auth'
@require 'bundinha/auth/command'
@require 'bundinha/auth/frontend'

{ APP, User } = @server

@public "/register", APP.denyAuth

User.authenticationChallenge = (rec)->
  challenge:'$plaintext$' unless q.pass?

User.authenticatePlain = (id,password)->
  result = await $cp.exec$ """
  LANG=C ssh #{id}@localhost echo '@ok@'
  """
  result? and result.status is 0 and result.stdout.match /@ok@/

User.authenticateWithClientSalt = (id,password,salt)->
  false

User.authenticateRequest = (q,req,res)->
  return res.json challenge:'$plaintext$' unless q.pass?
  unless await User.authenticatePlain q.id, q.pass
    throw new Error I18.NXUser
  req.USER = rec
  rec

User.registerRequest = (q,req,res)->
  throw new Error I18.AccessDenied

@server.User.create = (opts)->
  throw new Error I18.AccessDenied

@server.User.passwd = (user,pass)->
  throw new Error I18.AccessDenied
