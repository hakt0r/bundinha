
@require 'bundinha/auth/auth'
@require 'bundinha/auth/command'
@require 'bundinha/auth/frontend'

{ User } = @server

@config InviteKey: $forge.util.bytesToHex $forge.random.getBytes 32

User.registerRequest = (req)->
  { args } = req
  throw new Error 'User exists' if ( try rec = await APP.user.get args.id )?
  throw new Error 'Invalid InviteKey' unless args.inviteKey is SHA512 [ APP.InviteKey, args.inviteSalt ].join ':'
  req.USER = await User.create args
