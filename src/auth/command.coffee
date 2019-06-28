
#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████  ███████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██ ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██ ███████
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██      ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████  ███████

@command 'user', (args)->
  [ user ] = args
  u = await User.get user
  console.log if process.stdout.isTTY then u.record else JSON.stringify u.record, null, 2

@command 'user:list', (args,req,res)-> res.json await User.map( (u)-> u )
@command 'user:list:names', (args,req,res)-> res.json await User.map( (u)-> u.id )

@command 'user:pass', (args)->
  [ user, pass ] = args
  await User.passwd user, pass

@command 'user:add', (args)->
  args = args
  user = args.shift()
  pass = args.shift()
  try
    await User.get user
    console.error 'User exists:'.bold.red, user
    return
  seedSalt   = Buffer.from($forge.random.getBytesSync 128).toString 'base64'
  hashedPass = SHA512 [ pass, seedSalt ].join ':'
  User.create id:user, pass:hashedPass, seedSalt:seedSalt, group:if args.length > 0 then args else null

@command 'user:del', (args)->
  [ user ] = args
  try
    await User.get user
    await User.del user
  catch error
    console.log 'User does not exist:'.bold, user, error

@command 'user:edit', (args)->
  [ user ] = args
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
    console.log 'User does not exist:'.bold, user, error

@command 'group', (args)->
  [ user ] = args
  await User.addGroups user, args.slice 1
