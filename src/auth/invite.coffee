
@require 'bundinha/auth/dblocal'
@require 'bundinha/auth/auth'
@require 'bundinha/auth/command'
@require 'bundinha/auth/frontend'

{ User } = @server

@config InviteKey: $forge.util.bytesToHex $forge.random.getBytes 32

User.registerRequest = (q,req,res)->
  throw new Error 'User exists' if ( try rec = await APP.user.get q.id )?
  throw new Error 'Invalid InviteKey' unless q.inviteKey is SHA512 [ APP.InviteKey, q.inviteSalt ].join ':'
  await User.create id:q.id, pass:q.pass, seedSalt:q.salt
  rec
