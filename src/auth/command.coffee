
#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████  ███████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██ ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██ ███████
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██      ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████  ███████

@command 'user',            -> await User.get @args.shift()
@command 'user:list',       -> await User.map (u)-> u
@command 'user:list:names', -> await User.map (u)-> u.id
@command 'user:pass',       -> await User.passwd ...@args
@command 'group',           -> await User.addGroups @args[0], @args.slice 1

@command 'user:add', ->
  @log 'adduser'.green, @args
  record = try await User.get user = @args.shift()
  return @error 'User exists:'.bold.red, user if record
  pass = @args.shift()
  seedSalt   = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
  hashedPass = SHA512 [ pass, seedSalt ].join ':'
  User.create args: id:user, pass:hashedPass, seedSalt:seedSalt, group:if @args.length > 0 then @args else null
  true

@command 'user:del', ->
  [ user ] = @args
  return true unless user
  try await User.get user; await User.del user
  true

@command 'user:edit', ->
  [ user ] = @args
  try
    return unless u = await User.get user
    p = '/tmp/edit.1234'
    await new Promise (resolve)->
      await $fs.writeFile$ p, JSON.stringify u.record
      e = $cp.spawn 'atom',['--wait',p]
      e.on 'close', resolve
    u = await $fs.readFile$ p, 'utf8'
    await User.set user, u if try JSON.parse u
  catch error
    @error 'User does not exist:'.bold, user, error
