
@command 'install-systemd', ->
  console.log 'install'.red, 'systemd.service'
  $fs.writeFileSync '/etc/systemd/system/' + AppPackage.name + '.service', """
    [Unit]
    Description=#{AppPackage.name} backend

    [Service]
    Environment=PROTO=#{APP.protocol}
    Environment=ADDR=#{APP.addr}
    Environment=PORT=#{APP.port}
    Environment=CHGID=#{APP.chgid}
    Environment=CONF=#{ConfigDir}
    ExecStart=#{process.execPath} #{__filename}

    [Install]
    WantedBy=multi-user.target
  """
  $cp.execSync """
    systemctl enable  #{AppPackage.name}
    systemctl restart #{AppPackage.name}
  """
  process.exit 0

@command 'install-initd', ->
  console.log 'install'.red, 'init.d script'
  $fs.writeFileSync '/etc/init.d/' + AppPackage.name, """
    #! /bin/bash

    ### BEGIN INIT INFO
    # Provides:          #{AppPackage.name}
    # Required-Start:    $local_fs $network
    # Required-Stop:     $local_fs
    # Default-Start:     2 3 4 5
    # Default-Stop:      0 1 6
    # Short-Description: #{AppPackage.name}
    # Description:       #{AppPackage.name} backend
    ### END INIT INFO

    export PROTO=#{APP.protocol}
    export ADDR=#{APP.addr}
    export PORT=#{APP.port}
    export CHGID=#{APP.chgid}
    export CONF=#{ConfigDir}

    case "$1" in
      start|restart)
        /etc/init.d/#{AppPackage.name} stop
        #{process.execPath} #{__filename} >/dev/null 2>&1 &
        echo $? > /run/#{AppPackage.name}.pid;;
      stop)
        kill $(cat /run/#{AppPackage.name}.pid);;
      *) echo "Usage: /etc/init.d/cinv {start|stop|restart}"; exit 1;;
    esac
    exit 0
  """
  $cp.execSync """
    systemctl enable  #{AppPackage.name}
    systemctl restart #{AppPackage.name}
  """
  process.exit 0
