
#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████
# return if @command

@require 'bundinha/rpc'; { RPC } = @server

@server class Command

@command = (name,opts)=>
  if typeof name is 'object' then for name, opts of name
       @group name, ['$console','admin'], opts
  else @group name, ['$console','admin'], opts
  return

@preCommand = (func)=>
  c = @server.APP.PreCommand
  @server.APP.PreCommand = c = [] unless c? and Array.isArray c
  c.push func
  return

@preCommand ->
  await APP.initConfig()

Command.init = ->
  await fn() for fn in APP.PreCommand if APP.PreCommand?
  args = process.argv; i = 0
  args = args.slice 2
  return unless 0 < args.length
  process.exitAfterCommands = true
  try
    user = await Command.consoleUser()
    call = new RPC.Console args, user
    result = await call.execute()
  catch e
    console.error e
    process.exit 1
  process.exit 1 if process.exitAfterCommands and false is result
  console.log result unless true is result # console.log if process.stdout.isTTY then result else JSON.stringify result, null, 2
  process.exit 0 if process.exitAfterCommands

Command.consoleUser = ->
  info = $os.userInfo()
  unless User?
    return Object.assign info, UID:0, USER:info.username, GROUP:['$console'], COOKIE:'$console'
  user = try await User.aliasSearch info.username
  unless user
    user = try ( await do User.admins ).shift()
  unless user
    console.debug ' call '.red.bold.whiteBG, "User unknown:".red, info?.username?.white.bold
    console.debug '    $ '.red.bold.whiteBG, info
    return process.exit 1
  user = ( await User.get user ).record
  user = Object.assign user, info, console:true
  user.group = [user.group||[],'$console','$auth'].flat()
  UID:0, USER:user, GROUP:user.group, COOKIE:'$console'

@server.ArgsFor = (command)->
  process.argv.slice 1 + process.argv.indexOf command

@command 'help', ->
  @log " #{$$.AppName} ".bold.inverse.yellow, 'help'
  @log '     ', 'usage:'.underline, Object.keys(AppPackage.bin)[0].bold, 'command'.underline,'arguments...'.underline
  @log '   ', 'command:'.underline, Object.keys(RPC.byId).map((i)->i.replace /\\\\/g,'\\').join(', ').grey
  @log '  ', 'argument:'.underline, 'KEY'.yellow.italic+'='.gray+'value'.green.italic
  true

@server class RPC.Console extends RPC
  type:'$console'
  stdio:['$console','$console','$error']
  isConsole:true

# return unless @commandRPC # optional
# ██    ██ ███    ██ ██ ██   ██
# ██    ██ ████   ██ ██  ██ ██
# ██    ██ ██ ██  ██ ██   ███
# ██    ██ ██  ██ ██ ██  ██ ██
#  ██████  ██   ████ ██ ██   ██

@server class RPC.UNIX extends RPC
  type:'$console'
  stdio:['$console','$console','$error']
  isUNIX:true
  isConsole:true
  constructor:(msg,parent,sock)->
    super msg, parent
    @SOCK = sock
    @writeHead = @setHeader = ->
  log:(args...)-> @SOCK.sendMessage 'l' + JSON.stringify(args); RPC::log.apply @, args
  err:(args...)-> @SOCK.sendMessage 'e' + JSON.stringify(args); RPC::err.apply @, args
  respond:(data)->
    return @SOCK.sendMessage JSON.stringify false unless data
    return @SOCK.sendMessage JSON.stringify status$:1 if data.error and data.error.length > 0
    return @SOCK.sendMessage JSON.stringify data

@server.init = ->
  Command.createServer()
  return

@preCommand ->
  return unless await $fs.exists$ path = $path.join ConfigDir,'sock'
  await new Promise (resolve)->
    return resolve() unless sock = try require('net').createConnection(path)
    sock.on 'error', (error)-> resolve()
    sock.on 'connect', (error)->
      args = process.argv.slice 2
      MessageStream sock, (msg)->
        if msg[0] is 'e' then return console.error.apply console, JSON.parse(msg.substring 1)
        if msg[0] is 'l' then return console.log  .apply console, JSON.parse(msg.substring 1)
        process.exit 1 if ( json = try JSON.parse msg )?.status$ is 1
        process.exit 0 if json is true
        process.exit 1 if json is false
        console.log json; process.exit 0
      sock.sendMessage JSON.stringify args
  return

Command.createServer = ->
  if $fs.exists$ path = $path.join ConfigDir,'sock'
    await $cp.run$ 'fuser','-HUP',path
    try await $fs.unlink$ path = $path.join ConfigDir,'sock'
  await new Promise (resolve)->
    Command.server = require('net').createServer Command.onUnixClient
    Command.server.on 'error', Command.onUnixError
    Command.server.listen path, -> resolve()

Command.onUnixClient = (client)->
  console.debug '  unix '.whiteBG.blue.bold, 'client'.yellow.bold
  MessageStream client, (msg)->
    msg = try JSON.parse msg.toString 'utf8'
    result = await ( new RPC.UNIX msg, ( await Command.consoleUser() ), client ).handle()
    result = result || status$:1
    client.sendMessage JSON.stringify(result)
  client.on 'error', (msg)-> # console.error '$console'.gray+':e'.red, msg

Command.onUnixError = (e)->
  console.error '  unix '.whiteBG.blue.bold, 'error'.red.bold
  console.error e

# ulib:MessageStream
MessageStream = (sock,callback)->
  sock.sendMessage = (msg)->
    b = Buffer.concat [Buffer.from([0,0,0,0]),msg = Buffer.from msg]
    b.writeUInt32LE msg.length, 0
    @write b
  buffer = Buffer.from []; nextLen = -1
  sock.on 'data', (msg)->
    buffer = Buffer.concat [buffer,msg]
    if nextLen is -1 and buffer.length >= 4
      nextLen = buffer.readUInt32LE 0; buffer = buffer.subarray 4
    while ( nextLen > -1 ) and ( buffer.length >= nextLen )
      callback buffer.subarray(0,nextLen).toString()
      buffer = buffer.subarray nextLen
      if buffer.length >= 4
           nextLen = buffer.readUInt32LE 0; buffer = buffer.subarray 4
      else nextLen = -1
    return
  return
@server.MessageStream = MessageStream
@client.MessageStream = MessageStream
