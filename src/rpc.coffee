
@public = (path,callback)=>
  @group path, false, callback

@private = (path,group,callback)=>
  unless callback then callback = group; group = []
  @group path, ['$auth',group].flat(), callback

@get = (path,group,callback)=>
  unless callback then callback = group; group = []
  if path.exec?
    path = path.toString()
    RPC.match.add path
  @group path,group,callback

@group = (path,group,callback)->
  RPC.group[path] = [ group, RPC.group[path] || [] ].flat()
  RPC.byId[path] = callback

@server class RPC
  type:'$rpc'
  @byId : {}
  @group: {}
  @match: new Set
  constructor:(@cmd,@parent)->
    { @USER, @UID, @COOKIE, @GROUP, @SOCK } = @parent
    @data = null
    @errorData = []
  sub:  (cmd...)-> ( new RPC cmd, @ ).execute()
  log: (args...)-> console.log     ...[@type.gray+':l'.yellow].concat(args)
  err: (args...)-> console.error   ...[@type.gray+':e'.red].concat(args); @errorData.push args
  dbg: (args...)-> console.debug   ...[@type.gray+':d'.gray].concat(args)
  vrb: (args...)-> console.verbose ...[@type.gray+':v'.magenta].concat(args)
  error: (@fail, @failCode)-> throw new Error @fail
  setHeader:(args...)-> @err "Headers not supported".red.bold + ": #{args.join ' '}"
  handle:->
    try @data = await @execute()
    catch error
      @data = error:[error].concat(@errorData).map (e)->
        return unless e
        e = e.join ' ' if e.join
        e.toString().replace(/Error: /,'')
    @respond @data
  execute:->
    @cmd = [@cmd] unless Array.isArray @cmd
    @cmd = @cmd.filter (i)->i?
    @call = @cmd[0]
    @args = @cmd.slice 1
    console.debug ' call '.blue.bold.whiteBG, @call, @args?.join?(' ').gray
    # console.debug '    $ '.blue.bold.whiteBG, @USER
    if Array.isArray @args
      @args = @args.map (i)-> switch i[0]
        when '{','[' then JSON.parse i
        when 'f' then ( if i is 'false' then false else i )
        else i
      if @args.length is 1 and 'object' is typeof @args[0]
        @args = @args.shift()
    if @fn = await @resolve @call
      return await @fn.call @, @
    @err "Command not found: #{((@cmd?.join? ' ')||JSON.stringify @cmd).gray}"
    @err " try " + "#{Object.keys(AppPackage.bin)[0]}".bold + " help".bold.yellow
    false
  resolve:(call)->
    return false   unless ( acl = RPC.group[call] )?
    return @deny() unless ( false is acl[0] ) or ( RequireGroupBare @GROUP||[], acl||['$auth'] )
    return fn          if ( fn = RPC.byId[call] )?.call?
    return false
  deny:->
    user = @USER?.id || '$anonymous'
    console.error ' call '.red.bold.whiteBG, "Access Denied:".red, 'USER:', user.white.bold, 'CMD:', @cmd?.join(' ').gray
    @error "Access Denied: #{user} #{@cmd?.join ' '}", 401
  wasCalled:(key)->
    unless @state is RPC.FINISHED then @state = RPC.FINISHED; return true
    @error 'Resovler called twice', 501
