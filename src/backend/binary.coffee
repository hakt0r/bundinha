
# ██████  ██ ███    ██  █████  ██████  ██ ███████ ███████
# ██   ██ ██ ████   ██ ██   ██ ██   ██ ██ ██      ██
# ██████  ██ ██ ██  ██ ███████ ██████  ██ █████   ███████
# ██   ██ ██ ██  ██ ██ ██   ██ ██   ██ ██ ██           ██
# ██████  ██ ██   ████ ██   ██ ██   ██ ██ ███████ ███████

@server class SystemBinary
  @dep: {}
  @byName: {}
  @installQueue: []

  constructor:(opts)->
    Object.assign @, opts
    @bin = $path.basename @lib if @lib?
    @version = @version || '1.0.0-git1'
    @host = @host || 'localhost'
    return i if i = SystemBinary.byName[@bin]
    SystemBinary.byName[@bin] = @

  depend:->
    if await @isInstalled()
      console.debug 'installed:'.yellow.bold, @bin || @lib || 'undefined'.red.bold
      return
    console.log 'missing'.yellow, (@bin||@lib||'UNDEFINED').gray
    await @install @ if @debian? or @debianDev? or @build?
    console.log 'installed'.yellow, (@bin||@lib||'UNDEFINED').gray

  isInstalled:->
    try
      if @lib?
        return false unless await $fs.exists$ @path = @lib
      else @path = ( await $cp.run$ host:@host, args:["which",@bin] ).stdout.trim()
    return @path? and @path.trim() isnt ''

  install:-> new Promise (@resolvePkgs)=>
    clearTimeout SystemBinary.timer
    SystemBinary.timer = setTimeout => SystemBinary.doInstallPackages.call @
    SystemBinary.installQueue.push @

  installFromSource:->
    unless @build
      console.log 'no-build-script', @bin
      return
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
    try await $cp.run$ host:@host, args:[script.join '\n'], log:true
    catch e
      console.error 'Error'.red.bold, 'building SystemPackage:', @bin.bold
      console.error e
      process.exit 1

SystemBinary.depend = (opts)->
  ( new SystemBinary opts ).depend()

@server.preinit = ->
  await SystemBinary.depend opts for name, opts of SystemBinary.dep
  return

SystemBinary.mode = {}
SystemBinary.test = {}

SystemBinary.test.systemd = (name)-> """which systemctl"""
SystemBinary.mode.systemd = (name)-> """
  cp /tmp/#{name}.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl restart #{name}
  rm /tmp/#{name}.service
  """

SystemBinary.test.initd = (name)-> """test -f /etc/init.d"""
SystemBinary.mode.initd = (name)-> """
  cp /tmp/#{name}.initd /etc/init.d/#{name}
  chmod a+x /etc/init.d/#{name}
  /etc/init.d/#{name} stop
  update-rc.d #{name} defaults
  rm /tmp/#{name}.initd
  """

SystemBinary.doInstallPackages = ->
  # systemUsers
  if @systemUser then for name in @systemUser
    await @host.exec args:["""
    grep #{name} /etc/passwd || adduser --system --no-create-home --group #{name}
    """]
  # initScripts
  for rcService, activate of SystemBinary.mode when @[rcService]
    test = SystemBinary.test[rcService]()
    continue unless await @host.exec args:[test], log:true
    if typeof @[rcService] is 'object'
      list = @[rcService]
    unless list
      list = {}
      list[@bin] = systemd
    for name, service of list
      await @host.writeFile "/tmp/#{name}.service", service
      await @host.exec args:[SystemBinary.mode[rcService](name)], log:true
  # packages
  process.env.DEBIAN_FRONTEND = 'noninteractive'
  toStdErr = [null,process.stderr,process.stderr]
  install   = {}
  installed = new Set (
    await $cp.run$ host:@host, args:['dpkg --get-selections | grep -v deinstall'], log:true
  ).stdout.toString().trim().split('\n').map (pkg)->
    pkg.split(':').shift().split('\t').shift()
  SystemBinary.installQueue.forEach (binary)-> if binary.debianDev then binary.debianDev.forEach (pkg)-> install[pkg] = install[pkg] || installed.has pkg
  SystemBinary.installQueue.forEach (binary)-> if binary.debian    then binary.debian   .forEach (pkg)-> install[pkg] = true
  keep = ( k for k,v of install when v is true  )
  dev  = ( k for k,v of install when v is false )
  console.log 'installing'.yellow.bold, keep.join(', ').green, dev.join(', ').grey
  await $cp.run$ host:@host, args:['$l','apt-get','install','-yq'].concat(keep).concat(dev)
  console.log 'installing->building'.yellow.bold
  for binary in SystemBinary.installQueue
    console.log 'building'.yellow.bold, binary.bin.bold.white
    await binary.installFromSource()
    binary.resolvePkgs?()
  console.log 'cleaning up...'.yellow.bold
  await $cp.run$ host:@host, args:['$l','apt-get','purge','-yq'].concat dev
  await $cp.run$ host:@host, args:['$l','apt-get','autoremove','-yq']
  SystemBinary.installQueue = []
