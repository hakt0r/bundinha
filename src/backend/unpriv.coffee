@require 'bundinha/backend/backend'
@require 'bundinha/backend/nginx'

@command 'install', ->
  process.argv
  .filter  (i)-> i.match /^[A-Z]+=[^ ]+$/
  .map (i)->
    k = ( a = i.split '=' ).shift()
    v = a.join '='
    k = false if i.match /^(false|off|no)$/
    k = true  if i.match /^(true|on|yes)$/
    k = num   if not isNaN num = parseFloat i
    process.env[k] = v
  if not $$.BaseUrl and process.env.URL
    $$.BaseUrl = process.env.URL
    await APP.writeConfig()
  USER = process.env.USER || process.env.APP || process.userInfo().username
  if USER is 'root'
    console.error ' unpriv '.red.bold.inverse, "Can't install to root user. Set USER="
    process.exit 1
  HOME = process.env.HOME || os.homedir()
  PORT = process.env.PORT || $$.Port || throw new Error 'PORT= environment variable or argument required'
  CERT   = v if ( v = $$.SSLFullchain )?
  KEY    = v if ( v = $$.SSLHostKey   )?
  DOMAIN = v if ( v = $$.ServerName   )?
  DOMAIN = v.replace(/.*\/\//,'').replace(/(:[0-9]+)?\/.*$/,'') if ( v = $$.BaseUrl )? and not DOMAIN
  CERT   = v if ( v = process.env.CERT   )?
  KEY    = v if ( v = process.env.KEY    )?
  DOMAIN = v if ( v = process.env.DOMAIN )?
  throw new Error 'CERT= environment variable or argument required'   unless CERT?
  throw new Error 'DOMAIN= environment variable or argument required' unless DOMAIN?
  KEY = false if false is CERT
  try $cp.execSync 'which systemctl'
  catch e
    @err 'Error:', 'systemd is required for this setup'.red
    @err 'In addition this requires:'
    @err "  sudo loginctl enable-linger #{USER}".yellow
    process.exit 1
  $$.SystemdServiceExtra  = $$.SystemdServiceExtra || ''
  isSystemUser = ( $cp.spawnSync 'sh',['-c',"getent passwd #{USER} | grep -q bin/false"] ).status is 0
  if isSystemUser
       $$.SystemdServiceExtra += "User=#{USER}\n"
       $$.SystemdServiceExtra += "Group=#{USER}\n"
       dest = $path.join '/etc/systemd/system', AppPackage.name + '.service'
  else dest = $path.join HOME, '.local','share','systemd','user',AppPackage.name + '.service'
  @log ' instl '.blue.bold.whiteBG, 'systemd for', USER.green, isSystemUser
  $cp.spawnSync 'mkdir',['-p',$path.dirname dest], stdio:'inherit'
  $fs.writeFileSync dest, """
    [Unit]
    Description=#{AppPackage.name} backend

    [Service]
    #{$$.SystemdServiceExtra}
    Environment=CONF=#{ConfigDir}
    ExecStart=#{process.execPath} #{__filename}

    [Install]
    WantedBy=multi-user.target
  """
  @log ' instl '.blue.bold.whiteBG, 'sudo snippet'
  $cp.sudoSnippet = """
  if [ "$(whoami)" = "root" ]
  then
    appdo='sudo -E -u #{USER}'
    sudo=''
  else
    appdo=''
    sudo='sudo'
    [ -n "$DISPLAY" ] && SUDO_ASKPASS=$(which ssh-askpass)
    if [ -n "$SUDO_ASKPASS" ]
    then ask='-A'; export SUDO_ASKPASS
    fi
  fi"""
  @log ' instl '.blue.bold.whiteBG, 'linger'
  $cp.spawnSync 'sh',['-c',"""
    #{$cp.sudoSnippet}
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u root)/bus
    $sudo $ask loginctl >/dev/null 2>&1 || $sudo $ask apt install dbus
    if ! $sudo $ask loginctl show-user #{USER} | grep -q linger=yes
    then $sudo $ask loginctl enable-linger #{USER}; fi
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u #{USER})/bus
    if #{if isSystemUser then 'false' else 'true'}
    then
      $appdo systemctl --user | grep -q #{AppPackage.name}.service &&
        $appdo systemctl --user disable #{AppPackage.name}
      $appdo systemctl --user enable  #{AppPackage.name}
      $appdo systemctl --user restart #{AppPackage.name}
    else
      $sudo systemctl daemon-reload
      $sudo systemctl | grep -q #{AppPackage.name}.service &&
        $sudo systemctl disable #{AppPackage.name}
      $sudo systemctl enable  #{AppPackage.name}
      $sudo systemctl restart #{AppPackage.name}
    fi
    $sudo $ask chown -R #{USER}:#{USER} #{$path.dirname ConfigDir}
  """], stdio: 'inherit'
  @log ' instl '.blue.bold.whiteBG, 'config'
  APP.configKeys.insert 'BaseUrl';      $$.BaseUrl      = 'https://' + DOMAIN
  APP.configKeys.insert 'ServerName';   $$.ServerName   = DOMAIN
  APP.configKeys.insert 'SSLHostKey';   $$.SSLHostKey   = KEY
  APP.configKeys.insert 'SSLFullchain'; $$.SSLFullchain = CERT
  APP.configKeys.insert 'SSLBackend';   $$.SSLBackend   = false
  APP.configKeys.insert 'Protocol';     $$.Protocol     = 'http'
  APP.configKeys.insert 'Port';         $$.Port         = PORT
  APP.writeConfig()
  await @sub 'install:nginx'

@command 'status', -> ( await $cp.run$ 'systemctl','--user','status', AppPackage.name ).status is 0
@command 'start',  -> ( await $cp.run$ 'systemctl','--user','start',  AppPackage.name ).status is 0
@command 'stop',   -> ( await $cp.run$ 'systemctl','--user','stop',   AppPackage.name ).status is 0
@command 'restart',-> ( await $cp.run$ 'systemctl','--user','restart',AppPackage.name ).status is 0
@command 'enable', -> ( await $cp.run$ 'systemctl','--user','enable', AppPackage.name ).status is 0
@command 'disable',-> ( await $cp.run$ 'systemctl','--user','disable',AppPackage.name ).status is 0
