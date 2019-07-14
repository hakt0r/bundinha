
$$.NodePromises = ->
  $fs.touch =      (args...)-> $cp.spawn$    'touch', args
  $fs.touch.sync = (args...)-> $cp.spawnSync 'touch', args
  $fs.readUTF8Sync = (path)->
    path = $path.join.apply $path,path if Array.isArray path
    $fs.readFileSync path, 'utf8'
  $fs.readBase64Sync = (path)->
    path = $path.join.apply $path,path if Array.isArray path
    $fs.readFileSync path, 'base64'
  $fs.stat$      = $util.promisify $fs.stat
  $fs.mkdir$     = $util.promisify $fs.mkdir
  $fs.exists$    = $util.promisify $fs.exists
  $fs.readdir$   = $util.promisify $fs.readdir
  $fs.readFile$  = $util.promisify $fs.readFile
  $fs.rename$    = $util.promisify $fs.rename
  $fs.writeFile$ = $util.promisify $fs.writeFile
  $fs.writeFileAsRoot$ = (path,data)->
    opts = $cp.spawnOpts $cp.spawnArgs '$','tee',path
    opts.stdio = ['pipe','pipe','pipe']
    s = $cp.spawn opts.args[0], opts.args.slice(1), opts
    s.stdin.write data; s.stdin.end()
    await $cp.awaitOutput s,opts
  $fs.unlink$    = $util.promisify $fs.unlink
  $cp.spawn$     = $util.promisify $cp.spawn
  $cp.spawn$$    = (cmd,args,opts)-> new Promise (resolve,reject)-> $cp.spawn(cmd,args,opts).on('error',reject).on('close',resolve)
  $cp.exec$      = $util.promisify $cp.exec
  $cp.awaitSilent = (s)-> new Promise (r,e)-> s.on('close',r).on('error',e)
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
    console.debug ' run$ '.white.redBG.bold, opts.args, opts.stdio[0] is process.stdin
    await $cp.awaitOutput s,opts
  $cp.spawnArgs = (args...)->
    Host = byId:{} unless $$.Host
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
    Host = byId:{} unless $$.Host
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
  return
