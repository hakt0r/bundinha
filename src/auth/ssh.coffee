

# @require 'bundinha/auth/ssh_userdb'
@require 'bundinha/auth/auth'
@require 'bundinha/auth/command'
@require 'bundinha/auth/frontend'

{ APP, User } = @server

@public "register", APP.denyAuth

User.authenticationChallenge = (rec)->
  challenge:'$plaintext$' unless req.args.pass?

User.authenticatePlain = (id,password)->
  result = await $cp.exec$ """
  LANG=C ssh #{id}@localhost echo '@ok@'
  """
  result? and result.status is 0 and result.stdout.match /@ok@/

User.authenticateWithClientSalt = (id,password,salt)->
  false

User.authenticateRequest = (req)->
  [ id, pass ] = req.args
  return challenge:'$plaintext$' unless pass?
  unless await User.authenticatePlain id, pass
    throw new Error I18.NXUser
  req.USER = rec

User.registerRequest = -> throw new Error I18.AccessDenied
@server.User.create  = -> throw new Error I18.AccessDenied
@server.User.passwd  = -> throw new Error I18.AccessDenied
