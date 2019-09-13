
$$.NodePromises = ->
  Promise.cue = (worker)->
    q = (task...)-> tip cue.push task
    q.cue = cue = []; running = no
    tip = -> unless running
      return running = no unless task = cue.shift()
      running = yes; worker task, -> tip running = no
    return q

  $fs[k+'$'] = $util.promisify $fs[k] for k in ['stat','mkdir','unlink','rmdir','exists','readdir','readFile','rename','writeFile']

  $fs.escape = (key)->
    key.toString().replace(/_/g,'_0').replace(/\0/g,'_1').replace(/\//g,'_2').replace(/\\/g,'_3').replace(/\|/g,'_4').replace(/\?/g,'_5').replace(/\*/g,'_6').replace(/\"/g,'_7').replace(/</g,'_8').replace(/>/g,'_9').replace(/:/g,'_A').replace(/"/g,'_B')

  $fs.unescape = (key)->
    key.toString().replace(/_1/g,'\0').replace(/_2/g,'/').replace(/_3/g,'\\').replace(/_4/g,'|').replace(/_5/g,'?').replace(/_6/g,'*').replace(/_7/g,'"').replace(/_8/g,'<').replace(/_9/g,'>').replace(/_A/g,':').replace(/_B/g,'"').replace(/_0/g,'_')

  $fs.mkdirp$ = (args...)->
    0 is ( await $cp.run$ ['mkdir','-p',args].flat() ).status

  $fs.mkdirp$.sync = (args...)->
    0 is ( $cp.spawnSync 'mkdir',['-p',args].flat() ).status

  $fs.touch = (args...)->
    if 'object' is typeof args.last
      opts = args.pop()
      args = ['-r',opts.ref,args].flat() if opts.ref
    $cp.spawn$ 'touch', args

  $fs.touch.sync = (args...)->
    if 'object' is typeof args.last
      opts = args.pop()
      args = ['-r',opts.ref,args].flat() if opts.ref
    $cp.spawnSync 'touch', args

  $fs.writeFileAsRoot$ = (path,data)->
    opts = $cp.spawnOpts '$','tee',path
    opts.stdio = ['pipe','pipe','pipe']
    s = $cp.spawn opts.args[0], opts.args.slice(1), opts
    s.stdin.write data; s.stdin.end()
    await $cp.awaitOutput s,opts

  $fs.readUTF8Sync = (path)->
    path = $path.join.apply $path,path if Array.isArray path
    $fs.readFileSync path, 'utf8'

  $fs.readBase64Sync = (path)->
    path = $path.join.apply $path,path if Array.isArray path
    $fs.readFileSync path, 'base64'

  $cp[k+'$'] = $util.promisify $cp[k] for k in ['spawn','exec']

  $cp.which = (name)->
    if ( w = $cp.spawnSync 'which',[name] ).status isnt 0 then false else w.stdout.toString().trim()

  $cp.which$ = (name)->
    if ( w = await $cp.spawn$$ 'which',[name] ).status isnt 0 then false else w.stdout.toString().trim()

  vars = ['SUDO_ASKPASS','SSH_ASKPASS','GIT_ASKPASS']
  list = ['kasa-askpass','ssh-askpass-gnome','ssh-askpass','ksshaskpass','r-cran-askpass','lxqt-openssh-askpass','razorqt-openssh-askpass','ssh-askpass-fullscreen']
  need = 0 isnt ( vars.filter (v)-> not process.env[v]? ).length
  if need then for canidate in list
    continue unless ASKPASS = $cp.which canidate
    vars.map (i)->
      # console.log "@@ #{i} #{ASKPASS} #{process.env[i]}"
      process.env[i] = ASKPASS # unless process.env[i]
    break

  $cp.setEncoding = (i,e)->
    [i.stderr,i.stdout,i.stdin].map( (i)-> i.setEncoding e )
    return i

  $cp.spawn$$ = (cmd,args,opts)->
    new Promise (resolve,reject)->
      $cp.spawn cmd, args, opts
      .on 'error', reject
      .on 'close', resolve

  $cp.awaitSilent = (s)->
    new Promise (r,e)-> s.on('close',r).on('error',e)

  $cp.logOutput = (pre...)->
    s = pre.pop()
    log = (data)->
      data.trim().split('\n').map (line)->
        console.log.apply console, pre.concat [line.gray]
    s.stdout.setEncoding 'utf8'; s.stdout.on 'data', log
    s.stderr.setEncoding 'utf8'; s.stderr.on 'data', log

  $cp.awaitOutput = (s,opts)->
    opts.host = opts.host || opts.host = name:$os.hostname(), localhost:true
    e = []; o = []; s.stderr.setEncoding 'utf8'
    if opts.log or opts.pipe then s.stderr.on 'data', (data)=>
      data.trim().split('\n').map (line)=>
        return if '' is line = line.trim()
        e.push line
        console.log "#{if opts.host.localhost then ":" else "@"}#{opts.host.name}:".red, line
    else s.stderr.on 'data', (data)-> e.push data
    if opts.pipe
      pipePromise = opts.pipe s
      return new Promise (resolve)-> s.on 'close', (status)->
        await pipePromise if opts.awaitChild
        resolve stderr:e.join(''), status:status
    s.stdout.setEncoding 'utf8'
    if opts.log then s.stdout.on 'data', (data)=>
      o.push data
      data.trim().split('\n').map (line)=>
        return if '' is line = line.trim()
        console.log "#{if opts.host.localhost then ":" else "@"}#{opts.host.name}:".yellow, line
    else s.stdout.on 'data', (data)-> o.push data
    new Promise (resolve)-> s.on 'close', (status)-> resolve stdout:o.join(''), stderr:e.join(''), status:status

  $cp.awaitProcess = (s,e,o)-> new Promise (resolve)->
    s.on 'close', (status)-> resolve stdout:o.join(''), stderr:e.join(''), status:status

  $cp.run = (args...)->
    opts = $cp.spawnOpts ...args
    $cp.spawn opts.args[0], opts.args.slice(1), opts
    await $cp.awaitOutput s,opts

  $cp.run$ = (args...)->
    { args } = opts = $cp.spawnOpts ...args
    s = $cp.spawn opts.args[0], opts.args.slice(1), opts
    console.debug ' run$ '.white.redBG.bold, (a=opts.args)[0].bold, a.slice(1).join(' ').gray,
      if opts.stdio[0] is process.stdin then '<0'.red.bold e else ''
    await $cp.awaitOutput s,opts

  $cp.sudo = Promise.cue (task,done)->
    [ args, opts, callback ] = task
    unless typeof opts is 'object'
      callback = opts
      opts = {}
    do done unless ( args = args || [] ).length > 0
    args.unshift '-A' if process.env.SUDO_ASKPASS and process.env.DISPLAY
    sudo = $cp.spawn 'sudo', args, opts
    # sudo.stderr.on 'data', (d)-> console.log d
    # sudo.stdout.on 'data', (d)-> console.log d
    console.debug '\x1b[32mSUDO\x1b[0m', process.env.DISPLAY, args.join ' '
    if callback then callback sudo, done
    else sudo.on 'close', done

  $cp.sudo.read = (cmd,callback)->
    console.debug '$cp.sudo.read', cmd
    $cp.sudo ['sh','-c',cmd], (proc,done)->
      $cp.setEncoding proc, 'utf8'
      proc.stdout.once 'data', -> done null
      $carrier.carry proc.stdout, callback

  $cp.sudo.sync = (cmd)->
    console.debug '$cp.sudo.sync', cmd
    args = ['sh','-c',cmd]
    args.unshift '-A' if process.env.DISPLAY
    $cp.spawnSync 'sudo', args

  $cp.sudo.script = (cmd,callback)->
    console.debug '$cp.sudo.script', cmd
    $cp.sudo ['sh','-c',cmd], (sudo,done)->
      do done; $cp.setEncoding sudo, 'utf8'; out = []; err = []
      $carrier.carry sudo.stdout, out.push.bind out
      $carrier.carry sudo.stderr, err.push.bind out
      sudo.on 'close', (status)-> callback status, out.join('\n'), err.join('\n')

  $cp.spawnOpts = (args...)-> new $cp.SpawnOpts ...args

  class $cp.SpawnOpts
    constructor:(args...)->
      if args[0]?.script?
        return args[0]
      if typeof args[0] is 'string' and args.length is 1
             opts = args:[args[0]]
      else if Array.isArray args[0]
        if    Array.isArray args[0]
             opts = args:args[0]
        else opts = args:args
      else if typeof args[0] is 'object'
             opts = args[0]
      else   opts = args:args
      Object.assign @, opts
      @originalArgs = ( @args = @args.asArray ).slice()
      @handleHost()
      @handleUser()
      @handleModifiers()
      @handleScript()
      @env = @env || process.env
      if      @host?.localhost then @argsLocal()
      else if @host?.virtual   then @argsVirtual()
      else                          @argsRemote()
      @pipeSetup()
      # @debug()
    handleHost:->
      $$.Host = byId:{} unless $$.Host # FIXME: move this somewhere sensible :D
      @host = @args.shift() if @args[0]?.constructor is Host
      @host = @args.pop()   if @args[@args.length]?.constructor is Host
      @host = @host || @host = name:$os.hostname(), localhost:true
      @parent = Host.byId[@host.parent[0]] if @host?.virtual? and @host?.parent?
    handleUser:->
      @currentUser = $os.userInfo().username
      @user = if @needsRoot then 'root' else @user || @currentUser
    handleModifiers:->
      return unless @args.length > 0 and m = @args[0]?.match /^([^@]+@)?([$#]+)?([$#])([-!eltx]+)?$/
      @args.shift()
      @needsRoot  = true  if m[3] is '$' unless @host.virtual
      @needsInput = true  if m[4]?.match '-'
      @log = true         if m[4]?.match 'l'
      @log = true         if m[4]?.match 'e'
      @preferTerm  = true if m[4]?.match 't'
      @preferX11   = true if m[4]?.match 'x'
      @user = m[1].substring 0, -1 if m[1]
      @host = Host.byId[m[2]]      if m[2]
    handleScript:->
      return if @script or @host?.localhost
      @script = @args.shift() if @args.length is 1 and not @args[0].match /^[^ ]+$/
      @script = "eval \"$(echo #{(Buffer.from do @script.toString).toString('base64').replace(/\n/,'')}|base64 -d)\"" if @script
    argsLocal:->
      return unless @preferTerm
      @args = ['-e',"'#{@args.join ' '}'"] if @args.length > 0
      @args = ['xterm'].concat @args
      return unless @needsRoot
      @args = ['sudo'].concat @args
      @args = ['sudo','-A'].concat @args.slice 1 if process.env.DISPLAY? and process.env.SUDO_ASKPASS
    argsVirtual:->
      if @parent.localhost
        if @script
             @args = ['lxc-attach','-n',@host.name,'--','sh','-c',@script].flat()
        else @args = ['lxc-attach','-n',@host.name,'--'].concat @args
        @needsRoot = true
        return @argsLocal()
      else if @parent
        if @script
             @script = "lxc-attach -n #{@host.name} -- sh -c '#{@script}'"
             # 'lxc-attach','-n',@host.name,'--','sh','-c',
             @args = ['ssh','-o','LogLevel=QUIET','-t',@parent.sshArgs(),@script].flat()
        else @args = ['ssh','-o','LogLevel=QUIET','-t',@parent.sshArgs(),'--','lxc-attach','-n',@host.name,'--',@args].flat()
      else throw new Error "No parent for Host[#{@name}]"
    argsRemote:->
      if @script
           @args = ['ssh','-o','LogLevel=QUIET','-t',@host.sshArgs(),'--',@script].flat()
      else @args = ['ssh','-o','LogLevel=QUIET','-t',@host.sshArgs(),'--',@args]  .flat()
    pipeSetup:->
      @stdio = @stdio || [null,null,null]
      return unless Array.isArray @stdio
      @stdio[0] = 'pipe' if @pipe
      @stdio[0] = process.stdin if @needsInput
      @stdio[1] = 'pipe' if @log or @pipe
      @stdio[2] = 'pipe' if @log
    toJSON:-> log:@log, needsRoot:@needsRoot, user:@user, host:@host.name
    debug:->
      try
        console.debug ' --- '.red.bold, 'command'.yellow.bold, ' --- '.red.bold
        if @script
          console.debug ' script '.blue.inverse.bold
          console.debug 'o', @originalArgs.map((i)-> i.gray.bold.inverse).join(' ').white.bold
          console.debug '$', @script.gray.bold
          console.debug '>', @args        .map((i)-> i.gray.bold.inverse).join(' ').white.bold
        else
          console.debug ' command '.blue.inverse.bold
          console.debug 'o', @originalArgs.map((i)-> i.gray.bold.inverse).join(' ').white.bold
          console.debug '>', @args        .map((i)-> i.gray.bold.inverse).join(' ').white.bold
        console.debug '  @log ', JSON.stringify @log
        console.debug ' @host ', JSON.stringify @host.name
        console.debug ' @user ', JSON.stringify @user
      catch e then console.log @; process.exit 1
