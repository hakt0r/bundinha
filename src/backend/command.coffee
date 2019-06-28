
#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████
# return if @command

@command = (name,opts)=>
  if typeof name is 'object'
    for name, opts of name
       @server.Command.byName[name] = opts
  else @server.Command.byName[name] = opts
  return

@preCommand = (func)=>
  c = @server.APP.PreCommand
  @server.APP.PreCommand = c = [] unless c? and Array.isArray c
  c.push func
  return

@preCommand ->
  await APP.initConfig()

@server class Command
  @byName: {}
  constructor:(@name,@func)->
    Command.byName[@name] = @
    @execute = @func.bind @

Command.call = (cmd,args=[],req,res)->
  return unless func = Command.byName[cmd]
  if Array.isArray(args) then args = args.map (i)-> switch i[0]
    when '{' then JSON.parse i
    when '[' then JSON.parse i
    when 'f' then ( if i is 'false' then false else i )
    else i
  subreq = req || new Command.Request func, args, req
  subres = res || new Command.Response func
  await func.execute args, subreq, subres
  return subres.response

Command.init = ->
  for name, func of Command.byName
    Command.byName[name] = new Command name, func
  await fn() for fn in APP.PreCommand if APP.PreCommand?
  args = process.argv; i = 0; chain = []
  args = args.slice 2
  while cmd = args.shift()
    unless func = Command.byName[cmd]
      console.error "Command not found: #{cmd}"
      console.error " try " + "#{Object.keys(AppPackage.bin)[0]}".bold + " help".bold.yellow
      process.exit 1
    if -1 isnt idx = args.indexOf '--'
      s = 1 + args.indexOf name
      chain.push [cmd,func,args.slice 0, idx]
      args = args.slice idx + 1
    else
      chain.push [cmd,func,args]
      break
  return unless 0 < chain.length
  process.exitAfterCommands = true
  for call in chain
    [cmd,func,args] = call
    result = await Command.call cmd, args
  process.exit 1 if process.exitAfterCommands and false is result
  process.exit 0 if process.exitAfterCommands

@server class Command.Request
  src:"$console"
  isConsole: true
  constructor:(@cmd,@argv,@parent)->
    if @parent
      @[k] = @parent[k] for k in ['USER','ID','COOKIE','sock']
    else @USER = id:process.env.USER

@server class Command.Response
  isConsole: true
  constructor: (@cmd)-> @dst = "$console"
  json:  (@response)-> console.log JSON.stringify @response
  error:     (@fail)-> console.error @fail

@server.ArgsFor = (command)->
  process.argv.slice 1 + process.argv.indexOf command

@command 'help', ->
  console.log " #{$$.AppName} ".bold.inverse.yellow, 'help'
  console.log '     ', 'usage:'.underline, Object.keys(AppPackage.bin)[0].bold, 'command'.underline,'arguments...'.underline
  console.log '   ', 'command:'.underline, Object.keys(Command.byName).join(', ').grey
  console.log '  ', 'argument:'.underline, 'KEY'.yellow.italic+'='.gray+'value'.green.italic
  process.exit 0

# ██████  ██████   ██████
# ██   ██ ██   ██ ██
# ██████  ██████  ██
# ██   ██ ██      ██
# ██   ██ ██       ██████
return unless @commandRPC

@preCommand ->
  return unless await $fs.exists$ path = $path.join ConfigDir,'sock'
  await new Promise (resolve)->
    return resolve() unless sock = try require('net').createConnection(path)
    sock.on 'connect', (error)->
      args = process.argv.slice 2
      sock.write JSON.stringify args
    sock.on 'data', (msg)->
      msg = msg.toString 'utf8'
      process.exit 1 if (json = try JSON.parse msg)?.status$ is 1
      console.log msg
      process.exit 0
    sock.on 'error', (e)-> resolve()
  return

@server.init = ->
  Command.createServer()
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
  console.error '  unix '.whiteBG.blue.bold, 'client'.yellow.bold
  client.on 'data', (msg)->
    msg = try JSON.parse msg.toString 'utf8'
    result = await Command.call msg
    result = result || status$:1
    client.write JSON.stringify result

Command.onUnixError = (e)->
  console.error '  unix '.whiteBG.blue.bold, 'error'.red.bold
  console.error e
