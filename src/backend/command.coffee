
#  ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████

unless @command then @command = (name,opts)=>
  if typeof name is 'object'
    for name, opts of name
       @server.Command.byName[name] = opts
  else @server.Command.byName[name] = opts
  return

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
  req = req || new Command.Request  func, args
  res = res || new Command.Response func
  await func.execute args, req, res

Command.init = ->
  for name, func of Command.byName
    Command.byName[name] = new Command name, func
  args = process.argv; i = 0; chain = []
  while cmd = args.shift()
    continue unless func = Command.byName[cmd]
    if -1 isnt idx = args.indexOf '--'
      s = 1 + args.indexOf name
      chain.push [cmd,func,args.slice 0, idx]
      args = args.slice idx + 1
    else
      chain.push [cmd,func,args]
      break
  return unless 0 < chain.length
  process.exitAfterCommands = true
  do APP.initConfig
  do APP.initDB if APP.initDB
  for call in chain
    [cmd,func,args] = call
    await Command.call cmd, args
  process.exit 0 if process.exitAfterCommands

@server class Command.Request
  isConsole: true
  constructor:(@cmd,@argv)->
    @USER = id:process.env.USER
    @src = "$console"

@server class Command.Response
  isConsole: true
  constructor:(@cmd)-> @dst = "$console"
  json:(opts)-> console.log JSON.stringify opts
  error:(opts)-> console.error opts; process.exit 1

@server.ArgsFor = (command)->
  process.argv.slice 1 + process.argv.indexOf command

@command 'help', ->
  console.log " #{$$.AppName} ".bold.inverse.yellow, 'help'
  console.log '     ', 'usage:'.underline, Object.keys(AppPackage.bin)[0].bold, 'command'.underline,'arguments...'.underline
  console.log '   ', 'command:'.underline, Object.keys(Command.byName).join(', ').grey
  console.log '  ', 'argument:'.underline, 'KEY'.yellow.italic+'='.gray+'value'.green.italic
  process.exit 0
