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
  USER = process.env.USER || process.getuid()
  HOME = process.env.HOME || os.homedir()
  PORT = process.env.PORT || throw new Error 'PORT= environment variable or argument required'
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
    console.log 'Error:', 'systemd is required for this setup'.red
    console.log 'In addition this requires:'
    console.log "  sudo loginctl enable-linger #{USER}".yellow
    process.exit 1
  dest = $path.join HOME, '.local','share','systemd','user',AppPackage.name + '.service'
  console.log 'install'.yellow, 'systemd for', USER.green
  $cp.spawnSync 'mkdir',['-p',$path.dirname dest], stdio:'inherit'
  $fs.writeFileSync dest, """
    [Unit]
    Description=#{AppPackage.name} backend

    [Service]
    #{$$.SystemdServiceExtra||''}
    Environment=CONF=#{ConfigDir}
    ExecStart=#{process.execPath} #{__filename}

    [Install]
    WantedBy=multi-user.target
  """

  $cp.sudoSnippet = """
  [ "$USER" = "root" ] || { sudo='sudo'; [ -n "$DISPLAY" ] && { SUDO_ASKPASS=$(which ssh-askpass); [ -n "$SUDO_ASKPASS" ] && { ask='-A'; export SUDO_ASKPASS; }; }; }
  """

  $cp.spawnSync 'sh',['-c',"""
    #{$cp.sudoSnippet}
    if ! $sudo $ask loginctl show-user #{USER} | grep -q linger=yes
    then $sudo $ask loginctl enable-linger #{USER}; fi
    systemctl --user | grep -q #{AppPackage.name}.service &&
      systemctl --user disable #{AppPackage.name}
    systemctl --user enable  #{AppPackage.name}
    systemctl --user restart #{AppPackage.name}
  """], stdio: 'inherit'
  APP.configKeys.pushUnique 'BaseUrl';      $$.BaseUrl      = 'https://' + DOMAIN
  APP.configKeys.pushUnique 'ServerName';   $$.ServerName   = DOMAIN
  APP.configKeys.pushUnique 'SSLHostKey';   $$.SSLHostKey   = KEY
  APP.configKeys.pushUnique 'SSLFullchain'; $$.SSLFullchain = CERT
  APP.configKeys.pushUnique 'SSLBackend';   $$.SSLBackend   = false
  APP.configKeys.pushUnique 'Protocol';     $$.Protocol     = 'http'
  APP.configKeys.pushUnique 'Port';         $$.Port         = PORT
  APP.writeConfig()
  Command.call 'install:nginx'
  process.exit 0

@command 'start',  -> $cp.spawnSync 'systemctl',['--user','start',  AppPackage.name]; process.exit 0
@command 'stop',   -> $cp.spawnSync 'systemctl',['--user','stop',   AppPackage.name]; process.exit 0
@command 'restart',-> $cp.spawnSync 'systemctl',['--user','restart',AppPackage.name]; process.exit 0
@command 'enable', -> $cp.spawnSync 'systemctl',['--user','enable', AppPackage.name]; process.exit 0
@command 'disable',-> $cp.spawnSync 'systemctl',['--user','disable',AppPackage.name]; process.exit 0
