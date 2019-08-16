
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
    @bin = $path.basename @lib if @lib?
    @version = @version || '1.0.0-git1'
    return i if i = SystemBinary.byName[@bin]; SystemBinary.byName[@bin] = @

  depend:->
    return if await @isInstalled()
    console.log 'missing'.yellow, (@bin||@lib||'UNDEFINED').gray
    await @install @ if @debian? or @debianDev? or @build?
    console.log 'installed'.yellow, (@bin||@lib||'UNDEFINED').gray

  isInstalled:->
    try
      if @lib?
        return false unless await $fs.exists$ @path = @lib
      else @path = ( await $cp.exec$ "which #{@bin}" ).stdout.trim()
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
    script = ["set -eux"]
    if @git then script.push """
      test -d /tmp/#{@bin}-#{@version} ||
      git clone --depth=1 #{@git} /tmp/#{@bin}-#{@version}"""
    else if @tarball
      await $fs.writeFile$ "/tmp/#{@bin}-#{@version}.tar.bz2", @tarball
      script.push """
      test -d  /tmp/#{@bin}-#{@version} || (
      mkdir -p /tmp/#{@bin}-#{@version}
      cd       /tmp/#{@bin}-#{@version}
      cat      /tmp/#{@bin}-#{@version}.tar.bz2 | base64 -d | tar xjvf -; )"""
    else script.push "mkdir -p /tmp/#{@bin}-#{@version}"
    script.push """cd /tmp/#{@bin}-#{@version}"""
    script.push @build() if @build and     @build.call
    script.push @build   if @build and not @build.call
    script.push """
    test -d /tmp/#{@bin}-#{@version} &&
    rm -rf /tmp/#{@bin}-#{@version}
    """
    try
      await $cp.run$ 'sh','-c',script.join '\n'
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
  await $cp.run$ ['$l','apt-get','install','-yq'].concat(keep).concat(dev)
  console.log 'installing->building'.yellow.bold
  for binary in SystemBinary.installQueue
    console.log 'building'.yellow.bold, binary.bin.bold.white
    await binary.installFromSource()
    binary.resolvePkgs?()
  console.log 'cleaning up...'.yellow.bold
  await $cp.run$ ['$l','apt-get','purge','-yq'].concat dev
  await $cp.run$ '$l','apt-get','autoremove','-yq'
  SystemBinary.installQueue = []
