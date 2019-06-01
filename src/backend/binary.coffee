
# ██████  ██ ███    ██  █████  ██████  ██ ███████ ███████
# ██   ██ ██ ████   ██ ██   ██ ██   ██ ██ ██      ██
# ██████  ██ ██ ██  ██ ███████ ██████  ██ █████   ███████
# ██   ██ ██ ██  ██ ██ ██   ██ ██   ██ ██ ██           ██
# ██████  ██ ██   ████ ██   ██ ██   ██ ██ ███████ ███████

@server class SystemBinary
  @byName: {}
  @installQueue: []

  constructor:(opts)->
    Object.assign @, opts
    @version = @version || '1.0.0-git1'
    return i if i = SystemBinary.byName[@bin]; SystemBinary.byName[@bin] = @

  depend:->
    return Promise.resolve() if await @isInstalled()
    console.log 'missing'.yellow, @bin.bold
    return @install @ if @debian? or @debianDev?
    return Promise.resolve()

  isInstalled:->
    try @path = ( await $cp.exec$ "which #{@bin}" ).stdout.trim()
    return @path?

  install:-> new Promise (@resolvePkgs)=>
    clearTimeout SystemBinary.timer
    SystemBinary.timer = setTimeout -> SystemBinary.doInstallPackages()
    SystemBinary.installQueue.push @

  installFromSource:-> new Promise (resolve,reject)=>
    unless @build
      console.log 'no-build-script', @bin
      return resolve()
    toStdErr = [null,process.stderr,process.stderr]
    try
      await $cp.spawnExec$ 'sh', [ '-c', """
      set -eux
      git clone --depth=1 #{@git} /tmp/#{@bin}-#{@version}
      cd /tmp/#{@bin}-#{@version}
      #{@build}
      rm -rf /tmp/#{@bin}-#{@version}"""
      ], stdio:toStdErr
      resolve()
    catch e
      console.error 'Error'.red.bold, 'building SystemPackage:', @bin.bold
      console.error e
      process.exit 1

SystemBinary.depend = (opts)-> ( new SystemBinary opts ).depend()

SystemBinary.doInstallPackages = ->
  process.env.DEBIAN_FRONTEND = 'noninteractive'
  toStdErr = [null,process.stderr,process.stderr]
  install   = {}
  installed = new Set ( await $cp.exec$ 'dpkg --get-selections | grep -v deinstall' ).stdout.toString().trim().split('\n').map (pkg)-> pkg.split(':').shift().split('\t').shift()
  SystemBinary.installQueue.forEach (binary)-> if binary.debianDev then binary.debianDev.forEach (pkg)-> install[pkg] = install[pkg] || installed.has pkg
  SystemBinary.installQueue.forEach (binary)-> if binary.debian    then binary.debian   .forEach (pkg)-> install[pkg] = true
  keep = ( k for k,v of install when v is true  )
  dev  = ( k for k,v of install when v is false )
  console.log 'installing'.yellow.bold, keep.join(', ').green, dev.join(', ').grey
  await $cp.spawnExec$ 'sudo',
    ['-A','apt-get','install','-yq'].concat(keep).concat(dev),
    stdio:toStdErr
  for binary in SystemBinary.installQueue
    console.log 'building'.yellow.bold, binary.bin.bold.white
    await binary.installFromSource()
    binary.resolvePkgs?()
  console.log 'cleaning up...'.yellow.bold
  await $cp.spawnExec$ 'sudo', ['-A','apt-get','purge','-yq'].concat(dev), stdio:toStdErr
  await $cp.spawnExec$ 'sudo', ['-A','apt-get','autoremove','-yq'],        stdio:toStdErr
  SystemBinary.installQueue = []
