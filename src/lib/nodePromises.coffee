
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
    opts = $cp.spawnOpts $cp.spawnArgs '$','tee',path
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
    vars.map (i)-> process.env[i] = ASKPASS unless process.env[i]
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

  $cp.awaitOutput = (s,opts)-> new Promise (resolve)-> ( ->
    e = []; o = []; s.stderr.setEncoding 'utf8'
    if opts.log then s.stderr.on 'data', (data)=> data.trim().split('\n').map (line)=>
      return if '' is line = line.trim()
      e.push line; console.log "#{if @localhost then ":" else "@"}#{@name}:".red, line
    else s.stderr.on 'data', (data)-> e.push data
    if opts.pipe
      pipePromise = opts.pipe s
      s.on 'close', (status)->
        await pipePromise if opts.awaitChild
        resolve stderr:e.join(''), status:status
    else
      s.stdout.setEncoding 'utf8'
      if opts.log
           s.stdout.on 'data', (data)=> o.push data; data.trim().split('\n').map (line)=>
             return if '' is line = line.trim()
             e.push line; console.log "#{if @localhost then ":" else "@"}#{@name}:".yellow, line
      else s.stdout.on 'data', (data)-> o.push data
      s.on 'close', (status)-> resolve stdout:o.join(''), stderr:e.join(''), status:status
    return ).call opts.host || opts.host = name:$os.hostname(), localhost:true

  $cp.run = (args...)->
    opts = $cp.spawnOpts $cp.spawnArgs ...args
    $cp.spawn opts.args[0], opts.args.slice(1), opts
    await $cp.awaitOutput s,opts

  $cp.run$ = (args...)->
    opts = $cp.spawnOpts $cp.spawnArgs ...args
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

  $cp.spawnArgs = (args...)->
    $$.Host = byId:{} unless $$.Host
    # console.log ' :SPAWN:ARGS: ', @name, args
    if      1 <  args.length then opts = args:args
    else if 1 is args.length and args[0]?
      if Array.isArray args[0] then opts = args:args[0]
      else if args[0].match?   then opts = args:['sh','-c',args[0]]
      else if args[0].args?    then opts = args[0]
    throw new Error " EXEC:FAIL #{JSON.stringify args}" unless opts
    opts.host = opts.args.shift() if opts.args[0]?.constructor is Host
    opts

  $cp.spawnOpts = (opts)-> ( ->
    $$.Host = byId:{} unless $$.Host
    args = opts.args
    if args[0]?.constructor is Host
      console.log '####',  args[0].canonical
      opts.host = args.shift()
    if m = args[0]?.match /^([^@]+@)?([$#]+)?([$#])([-!eltx]+)?$/
      opts.needsRoot  = true  if m[3] is '$' unless @virtual
      opts.needsInput = true  if m[4]?.match '-'
      opts.log = true         if m[4]?.match 'l'
      opts.log = true         if m[4]?.match 'e'
      opts.preferTerm  = true if m[4]?.match 't'
      opts.preferX11   = true if m[4]?.match 'x'
      opts.shellScript = true if m[4]?.match '!'
      opts.user = m[1].substring 0, -1 if m[1]
      opts.host = Host.byId[m[2]] if m[2]
      args.shift()
    currentUser = $os.userInfo().username
    user = if opts.needsRoot then 'root' else opts.user || currentUser
    args = ['sh','-c'].concat args if opts.shellScript
    if opts.needsRoot and @localhost and currentUser isnt 'root'
      if process.env.DISPLAY? and process.env.SUDO_ASKPASS
           args = ['sudo','-A'].concat args
      else
        opts.needsInput = true
        args = ['sudo'].concat args
    args = ['--'].concat args if args.length > 0
    argsFor =
      ssh:(via)->
        user = @user || 'root'
        addr = via.name
        addr = via.canonical if @staticIP
        args = args.slice 3 if args[0] is '--' and args[1] is 'sh' and args[2] is '-c'
        args = ['ssh','-o','LogLevel=QUIET','-t',user+"@"+addr].concat args
    if @virtual
      if parent = Host.byId[@parent[0]]
        if parent.localhost
          args = ['lxc-attach','-n',@name].concat args
          if process.env.DISPLAY? and process.env.SUDO_ASKPASS
            args = ['sudo','-A'].concat args
          else
            opts.needsInput = true
            args = ['sudo'].concat args
        else
          args = ['lxc-attach','-n',@name].concat args
          argsFor.ssh.call @, parent
      else throw new Error "No parent for Host[#{@name}]"
    else if @localhost
      if opts.preferTerm
        if args.length > 0
          args = ['-e',"'#{args.slice(1).join ' '}'"]
        args = ['xterm'].concat args
      else args = args.slice 1
    else argsFor.ssh.call @, @
    opts.stdio = opts.stdio || [null,null,null]
    if Array.isArray opts.stdio
      opts.stdio[0] = 'pipe' if opts.pipe
      opts.stdio[0] = process.stdin if opts.needsInput
      opts.stdio[1] = 'pipe' if opts.log or opts.pipe
      opts.stdio[2] = 'pipe' if opts.log
    opts.args = args
    opts.user = user #; console.log ' :SPAWN:1 '.black.greenBG.bold, @name, opts
    opts ).call opts.host || opts.host = name:$os.hostname(), localhost:true
  # console.log args.join(' ').gray, opts.stdio[0] id process.stdin
  maskCall = (name,parent)->
    real = $cp[name];
    $cp[name] = (args...)->
      res = real.apply $cp, args
      console.log ' ___'.yellow.bold
      console.log name.yellow.bold, args[0].bold.red, if Array.isArray args[1] then args[1] else args.length
      console.log ' ='.yellow.bold, res
      console.log ' '.yellow.bold
      res
  if process.env.DEBUG_NODE_SYSCALLS
    maskCall name, $cp for name,f of $cp
    maskCall name, $fs for name,f of $fs

  return
