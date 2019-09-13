
@require 'bundinha/backend/binary'

@preCommand ->
  return false unless domain = $$.BaseUrl?.replace(/.*:\/\//,'').replace(/\/.*/,'')
  await ( acme = new ACME domain ).init() unless ACME.ca
  return

@server.APP.getCerts = (require=false)->
  return false unless domain = $$.BaseUrl?.replace(/.*:\/\//,'').replace(/\/.*/,'')
  await ( new ACME domain ).init() unless ACME.ca
  if cert = await ACME.check()
    unless await ACME.usingForeignCerts()
      $$.SSLHostKey   = cert.key
      $$.SSLFullchain = cert.cert
      console.debug '  acme '.magenta.greenBG.bold, domain.bold, $path.basename(cert.key).gray
      await APP.writeConfig()
  else if require and not await ACME.usingForeignCerts()
      console.debug '  acme '.red.greenBG.bold, domain.bold
      await ACME.renewHTTP()
  APP.httpsContext = require('tls').createSecureContext key:cert.privkey, cert:cert.cert if 'https' is $$.Protocol

#  █████   ██████ ███    ███ ███████
# ██   ██ ██      ████  ████ ██
# ███████ ██      ██ ████ ██ █████
# ██   ██ ██      ██  ██  ██ ██
# ██   ██  ██████ ██      ██ ███████

# powered by acme.sh
#   https://github.com/Neilpang/acme.sh

@server class ACME
  constructor:(@domain)->
    console.debug ' acme '.blue.bold.whiteBG, @domain.bold.white, 'initialized'.yellow.bold
    $$.ACME = @

ACME::init = ->
  APP.port = parseInt APP.port
  @ca   = $path.join ConfigDir,'ca'
  @path = $path.join ConfigDir,'.acme.sh'
  @conf = $path.join ConfigDir,'acme'
  @bin  = $path.join @path, 'acme.sh'
  @call = ['/bin/sh',@bin,"--home",@path,"--config-home",@conf,"--cert-home",@ca]
  @call.splice(1,0,['--staging']) if process.env.ACME is 'stage'
  await SystemBinary.depend lib:@path, debian:['socat'], build:"""
  cd '#{ConfigDir}'
  curl -L https://github.com/Neilpang/acme.sh/archive/2.8.1.tar.gz > acme.tgz
  tar xzvf acme.tgz; rm acme.tgz; mv acme.sh-* .acme.sh
  .acme.sh/acme.sh --install --home '#{@path}' --config-home '#{@conf}' --cert-home #{@ca}
  """; return @

#  ██████ ██   ██ ███████  ██████ ██   ██
# ██      ██   ██ ██      ██      ██  ██
# ██      ███████ █████   ██      █████
# ██      ██   ██ ██      ██      ██  ██
#  ██████ ██   ██ ███████  ██████ ██   ██

ACME::check = ->
  list = await @list()
  check = cert if cert = list[@domain]
  for name, cert of list
    check = cert if cert.san?.includes? @domain
    check = cert if cert.san?.includes? '*.' + @domain.replace /^[^.]+\./, ''
    check = cert if cert.san?.includes? '*.' + @domain.split('.').slice(-2).join('.')
  return false unless check
  if check.renew > new Date then check else false
@command 'acme:check',      (args...)-> await ACME.check ...args
@command 'acme:check:http', (args...)-> await ACME.check ...args

# ██      ██ ███████ ████████
# ██      ██ ██         ██
# ██      ██ ███████    ██
# ██      ██      ██    ██
# ███████ ██ ███████    ██

ACME::list = ->
  acmeResult = await $cp.run$ args:[ACME.call,"--list"].flat()
  return {} unless acmeResult?.stdout?; list = {}
  beginList = false
  acmeResult.stdout.trim().split('\n').forEach (line)=>
    if line.match '\t'
         w = line.split(/\t/).map (word)-> word.trim()
    else w = line.split(/\ \ +/).map (word)-> word.trim()
    return beginList = true if w[0] is 'Main_Domain'
    return unless beginList
    c = ( try $fs.readFileSync ( $path.join @ca, w[0], w[0] + '.conf' ), 'utf8' ) || ''
    r =
      len: w[1].replace /^""$/, ''
      san: if ( san = w[2] ) is 'no' then false else if san then san.split(/,/) else false
      created: new Date w[3]
      renew:   new Date w[4]
      cert: $path.join @ca, w[0], 'fullchain.cer'
      key:  $path.join @ca, w[0], w[0] + '.key'
      mode: if c.match(/Le_Webroot='dns'/)? then 'dns' else 'http'
    return if r.renew.toString() is 'Invalid Date'
    list[w[0]] = r
  return list
@command 'acme:list', (args...)-> await ACME.list ...args

# ██████  ███████ ███    ██ ███████ ██     ██
# ██   ██ ██      ████   ██ ██      ██     ██
# ██████  █████   ██ ██  ██ █████   ██  █  ██
# ██   ██ ██      ██  ██ ██ ██      ██ ███ ██
# ██   ██ ███████ ██   ████ ███████  ███ ███

ACME::renewHTTP = (req)->
  # req.log "acme".yellow.bold, 'renew'.red.bold
  throw new Error 'Undefined: ServerName' unless $$.ServerName
  await @nginxRedirectOn req
  { stdout } = acmeResult = await $cp.run$ [
    ACME.call,"--issue","-d",$$.ServerName,"--standalone","--httpport",APP.port + 1776].flat()
  result = ACME.parseResult req, acmeResult, $$.ServerName
  await @nginxRedirectOff req
  result
@command 'acme:renew',      (args...)-> await ACME.renew ...args
@command 'acme:renew:http', (args...)-> await ACME.renew ...args

# ████████  ██████   ██████  ██      ███████
#    ██    ██    ██ ██    ██ ██      ██
#    ██    ██    ██ ██    ██ ██      ███████
#    ██    ██    ██ ██    ██ ██           ██
#    ██     ██████   ██████  ███████ ███████

ACME::usingForeignCerts = ->
  return false unless $$.SSLHostKey? and $$.SSLFullchain?
  hasKey = await $fs.exists$ SSLHostKey
  hasCrt = await $fs.exists$ SSLFullchain
  return false unless hasKey and hasCrt
  certs = await ACME.list()
  return false for name, cert of certs when SSLHostKey is cert.key
  console.log ' acme '.inverse.yellowBG.bold, 'usingForeignCerts', SSLHostKey
  true

ACME::parseResult = (request,{stdout,stderr},domain,firstStep=false)->
  SSL = "  acme ".blue.whiteBG.bold + ' ' + domain.bold
  if stdout?.match /-----END CERTIFICATE-----/
    request.log SSL, 'renewed'.green.bold
    true
  else if m = stdout?.match /Skip\, Next renewal time is: ([^\n]+)/
    request.log SSL, 'valid until'.green.bold, (m.pop()||'').italic.bold
    true
  else unless firstStep
    request.err SSL, 'not renewed'.red.bold
    request.err stdout.trim().replace(/\[[^\]]+\] /g,' ').gray
    request.err stderr.trim().replace(/\[[^\]]+\] /g,' ').gray
    false

ACME::nginxRedirectOff = -> if NGINX.httpRedirect is @httpRedirect
  NGINX.httpRedirect = ACME.oldRedirect
  await Command.call req, 'install:nginx'

ACME::nginxRedirectOn = (req)->
  @oldRedirect = NGINX.httpRedirect if NGINX.httpRedirect isnt @httpRedirect
  NGINX.httpRedirect =  ACME.httpRedirect
  await Command.call req, 'install:nginx'

ACME::httpRedirect = -> """
  server {
    listen 80;
    listen [::]:80;
    server_name #{$$.ServerName};
    location = /.well-known/acme-challenge/ { return 404; }
    location ~ /.well-known/acme-challenge/* {
      allow all;
      proxy_pass http://127.0.0.1:#{APP.port + 1776};
      proxy_redirect off;
      proxy_buffering off;
      proxy_set_header        Host            $host;
      proxy_set_header        X-Real-IP       $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto $scheme; }
    location / {
      return 301 https://$host$request_uri; }
  }"""

# ██████  ███    ██ ███████
# ██   ██ ████   ██ ██
# ██   ██ ██ ██  ██ ███████
# ██   ██ ██  ██ ██      ██
# ██████  ██   ████ ███████
return unless @acmeDNS

ACME::renewDNS = (request)->
  {domain,dynamic,domains,subDomains,aliased,force,updateDNS,nameServer} = request
  writeNewConfig = ->
    return unless cert = await ACME.check()
    $$.SSLHostKey   = cert.key
    $$.SSLFullchain = cert.cert
    await APP.writeConfig()
    await Command.call 'install:nginx'
  try await $fs.unlink$ cachePath if force
  SSL = "  acme ".blue.whiteBG.bold + ' ' + domain.bold
  cachePath = "/tmp/acme_cache.#{domain}"
  dnsArgs = ['--dns','--yes-I-know-dns-manual-mode-enough-go-ahead-please']
  dnsArgs.push '--force' if force
  return false unless await $fs.exists$ ACME.bin
  args = []; stdout = []
  for dom in domains.concat(aliased).concat(subDomains)
    if ( dom is domain ) or subDomains.includes dom
         args = args.concat ['-d','*.'+dom]
    else args = args.concat ['-d',dom,'-d','*.'+dom]
  request.log SSL, 'update', [domains,aliased,subDomains].flat().map( (i)-> i.green ).join(', ')
  # force = force || not await $fs.exists$ cachePath
  # if force
  request.log SSL, 'talking to ACME'.yellow.bold
  { stdout } = acmeResult = await $cp.run$ [
    ACME.call,'--issue',dnsArgs,'-d',domain,args,'--challenge-alias',dynamic].flat()
  await $fs.writeFile$ cachePath, stdout
  if ACME.parseResult request, acmeResult, domain, true
    await writeNewConfig()
    return true
  # else stdout = await $fs.stdoutFile$ cachePath, 'utf8'
  request.log SSL, 'reading DNS tokens'.yellow.bold
  found = true; challenge = []; check = []
  while found
    try [m0,dom] = m = stdout.match /domain: '_acme-challenge\.([^']+)'/i; dom = dom.trim()
    try [n0,tok] = n = stdout.match /txt value: '([^']+)'/i; tok = tok.trim()
    break unless n? and m?
    stdout = stdout.substring n.index + tok.length
    challenge.push ['txt',"_acme-challenge.#{dom}.",tok,300]
    check.push ACME.checkDNS dom, tok, nameServer
  domains.forEach (domain)-> if domain isnt dynamic and not aliased.includes domain
    challenge.push ['cname',"_acme-challenge.#{domain}.","_acme-challenge.#{dynamic}.",300]
  subDomains.forEach (domain)->
    challenge.push ['cname',"_acme-challenge.#{domain}.","_acme-challenge.#{dynamic}.",300]
  await updateDNS challenge, 'add', request
  request.log SSL, 'checking DNS-TXT records'.yellow.bold, DNS.tempRecords
  r = await Promise.all check.map (i)-> i()
  throw new Error 'DNS check failed' unless r.reduce (
    (c,v)-> if c is false then false else v
  ), true
  request.log SSL, 'ACME is verifying'.yellow.bold
  { stdout } = acmeResult = await $cp.run$ [ACME.call,'--renew',dnsArgs,'-d',domain,args].flat(); stdout = r.stdout
  await updateDNS challenge, 'delete', request
  if ACME.parseResult request, acmeResult, domain
    await writeNewConfig()
    true
  else false

ACME::checkDNS = (domain,token,nameServer)-> ->
  SSL = "  acme ".blue.whiteBG.bold + ' ' + domain.bold
  r = await $cp.run$ 'host','-t','TXT',"_acme-challenge.#{domain}", nameServer
  if r?.stdout?.includes? token
    request.log SSL,'token'.green, domain.bold, token
    return true
  request.err SSL,'token'.red.bold, domain.bold
  request.err r?.stderr
  request.err r?.stdout
  false
