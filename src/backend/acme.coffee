
return if @SSL? and @SSL.static

@npm 'greenlock'

@server.APP.getCerts = ->
  domain = BaseUrl.replace(/.*:\/\//,'').replace(/\/.*/,'')
  new ACMEHandler domain
  opts = domains:[domain], email:'sebek@sebek.de', agreeTos:yes, communityMember:no
  greenlock = require('greenlock').create
    version: 'draft-12'
    server: 'https://acme-v02.api.letsencrypt.org/directory'
    challengeType: 'http-01'
    challenges: 'http-01': create:-> ACME
    configDir:$path.join ConfigDir,'acme'
  certs = await greenlock.check opts
  unless certs
    APP.httpServer = require('http').createServer APP.handleRequest
    await new Promise (resolve)-> APP.httpServer.listen APP.port, resolve
    certs = await greenlock.register opts
    APP.httpServer.close()
    throw new Error 'Cannot generate certs' unless certs
    APP.httpsContext = require('tls').createSecureContext key:certs.privkey, cert:certs.cert if $$.SSLBackend
    console.log ' acme '.green.bold.inverse, domain
    return
  else if (new Date) > new Date certs.expiresAt then setTimeout ->
    certs = await greenlock.register opts
    APP.httpsContext = require('tls').createSecureContext key:certs.privkey, cert:certs.cert if $$.SSLBackend
    console.log ' acme '.green.bold.inverse, domain
    return
  else
    APP.httpsContext = require('tls').createSecureContext key:certs.privkey, cert:certs.cert if $$.SSLBackend
    console.log ' acme '.green.bold.inverse, domain
    return

@server class ACMEHandler
  constructor:(@domain)->
    console.log ' acme '.bold.inverse, @domain
    $$.ACME = @
  getOptions:-> {}
  set:(args, domain, token, secret, done)->
    console.log ' set '.bold.inverse, domain, token, secret
    @[domain] = secret
    do done
  get:(defaults, domain, key, done)->
    console.log ' get '.bold.inverse, defaults, domain, key
    done @[domain]
  remove:(defaults, domain, token, done)->
    console.log ' del '.bold.inverse, defaults, domain, key
    delete @[domain]
    do done

@get /acme-challenge/, (req,res)->
  res.writeHead 200,"Content-Type":'text/html'
  console.log 'acme:le-challenge'.green.bold.inverse, req.headers.host, req.url
  res.end ACME[req.headers.host]

@server.NGINX.httpRedirect = -> """
  server {
    listen 80;
    listen [::]:80;
    server_name #{$$.ServerName};
    location = /.well-known/acme-challenge/ { return 404; }
    location ~ /.well-known/acme-challenge/* {
      allow all;
      proxy_pass #{APP.protocol}://127.0.0.1:#{APP.port};
      proxy_redirect off;
      proxy_buffering off;
      proxy_set_header        Host            $host;
      proxy_set_header        X-Real-IP       $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto $scheme; }
    location / {
      return 301 https://$host$request_uri; }
  }"""
