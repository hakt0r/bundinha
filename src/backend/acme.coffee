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
  unless certs = await greenlock.check opts
    APP.httpServer = require('http').createServer APP.handleRequest
    await new Promise (resolve)-> APP.httpServer.listen 80, resolve
    certs = await greenlock.register opts
    APP.httpServer.close()
    throw new Error 'Cannot generate certs' unless certs
  APP.httpsContext = require('tls').createSecureContext
    key:certs.privkey
    cert:certs.cert
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
  console.log 'LE-CHALLENGE'.red.bold.inverse, req.headers.host, req.url
  res.end ACME[req.headers.host]
