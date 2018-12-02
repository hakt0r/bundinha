@require 'bundinha/backend/backend'
@require 'bundinha/backend/nginx'

@command 'install-unpriv', ->
  USER = process.env.USER || process.getuid()
  HOME = process.env.HOME || os.homedir()
  try $cp.execSync 'which systemctl'
  catch e
    console.log 'Error:', 'systemd is required for this setup'.red
    console.log 'In addition this requires:'
    console.log "  sudo -A loginctl enable-linger #{USER}".yellow
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
  $cp.spawnSync 'sh',['-c',"""
    if ! loginctl show-user #{USER} | grep linger=yes
    then
    export SUDO_ASKPASS=$(which ssh-askpass)
      [ -n "$DISPLAY" ] && ask='-A'
      sudo $ask loginctl enable-linger #{USER}
    fi
    systemctl --user | grep -q #{AppPackage.name}.service &&
    systemctl --user disable #{AppPackage.name}
    systemctl --user enable  #{AppPackage.name}
    systemctl --user restart #{AppPackage.name}
  """], stdio: 'inherit'
  process.exit 0
