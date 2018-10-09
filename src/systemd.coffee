
@command 'install-systemd', ->
  console.log 'install'.red, 'systemd.service'
  fs.writeFileSync '/etc/systemd/system/' + AppPackage.name + '.service', """
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
  cp.execSync """
    systemctl enable  #{AppPackage.name}
    systemctl restart #{AppPackage.name}
  """
  process.exit 0
