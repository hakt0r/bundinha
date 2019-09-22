
@server class NGINX
  @dynamic:[]
  @http:[]

@preCommand ->
  await APP.getCerts()

@require 'bundinha/backend/backend'
@require 'bundinha/backend/web'
@require 'bundinha/backend/acme'

@config
  SSLFullchain: "/path/to/fullchain.crt"
  SSLHostKey:   "/path/to/host.key"
  SSLClientCA:  "/path/to/ca.crt"
  SSLGateDN:    "C=com,O=#{AppPackageName}.DOMAIN,CN=gate.#{AppPackageName}.DOMAIN.com"

@command 'install:nginx',->
  return false unless $$.ServerName = $$.ServerName || $$.BaseUrl?.replace(/https?:\/\//,'').replace(/\/.*/,'')
  await APP.initConfig()
  available = '/' + $path.join 'etc','nginx','sites-available',AppPackage.name+'.conf'
  enabled   = '/' + $path.join 'etc','nginx','sites-enabled',  AppPackage.name+'.conf'
  # $fs.writeFileSync path = $path.join(ConfigDir,'nginx.site.conf'), NGINX.config()
  try
    await $fs.writeFileAsRoot$ available, config = NGINX.config()
    await $cp.run$ '$','ln','-sf',available,enabled
    await $cp.run$ '$','/etc/init.d/nginx','restart'
  catch error
    @err error
    return false
  r = await $cp.run$ '$','nginx','-t'
  if r.status isnt 0
    @err ' nginx '.blue.whiteBG.bold, 'install'.red.bold
    @err '',"#{'BaseUrl'.padEnd(13).bold.yellow}: #{$$.BaseUrl.bold.white}"
    @err '',"#{'ServerName'.padEnd(13).bold.yellow}: #{$$.ServerName.bold.white}"
    @err '',"#{'SSLHostKey'.padEnd(13).bold.yellow}: #{$$.SSLHostKey.bold.white}"
    @err '',"#{'SSLFullchain'.padEnd(13).bold.yellow}: #{$$.SSLFullchain.bold.white}"
    @err '',"#{'Protocol'.padEnd(13).bold.yellow}: #{$$.Protocol.bold.white}"
    @err '',"#{'Port'.padEnd(13).bold.yellow}: #{$$.Port.bold.white}"
    @err '---'
    @err r.stdout
    @err r.stderr
    @err '---'
    @err config
    @error 'NGINX config error'
  @log ' nginx '.blue.whiteBG.bold, 'install'.green.bold
  true
  # $fs.writeFileSync '/etc/nginx/sites-available/' + AppPackage.name,
  # $fs.writeFileSync $path.join(ConfigDir,'nginx.server.conf'), NGINX.testConfig()

NGINX.testConfig = ->
  """
  user #{$os.userInfo().username};
  pid #{ConfigDir}/nginx.pid;
  worker_processes auto;
  include /etc/nginx/modules-enabled/*.conf;
  events { worker_connections 768; }
  http {
    gzip on;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    default_type application/octet-stream;
    include /etc/nginx/mime.types;
    access_log #{ConfigDir}/access.log;
    error_log #{ConfigDir}/error.log info;
    include /etc/nginx/conf.d/*.conf;
    include #{$path.join ConfigDir, 'nginx.site.conf'}; }
  """

NGINX.config = -> """
  #{NGINX.httpRedirect()}
  #{NGINX.http.map( (i)-> i() ).join '\n'}
  """ + if ( ssl = NGINX.ssl() ) then """
  server {
  #{NGINX.sslServer $$.ServerName || '_'}
    root #{WebDir};
    #{ssl}
    #{NGINX.sslLockdown()}
    #{NGINX.singleFactor()}
    #{NGINX.dynamic.map( (i)-> i() ).join '\n  '}
    #{NGINX.apiConfig()}
  }""" else ''

NGINX.sslServer = (serverName='_',webRoot='')->
  defaultServer = if '_' is serverName then ' default_server' else ''
  webRoot       = if ''  is webRoot    then '' else "root #{webRoot};"
  """
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_protocols TLSv1.2;# Requires nginx >= 1.13.0 else use TLSv1.2
    ssl_prefer_server_ciphers on;
    # ssl_dhparam /etc/nginx/dhparam.pem; # openssl dhparam -out /etc/nginx/dhparam.pem 4096
    ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
    ssl_session_timeout  10m;
    ssl_session_cache builtin:1000 shared:SSL:10m;
    ssl_session_tickets off; # Requires nginx >= 1.5.9
    ssl_stapling on; # Requires nginx >= 1.3.7
    ssl_stapling_verify on; # Requires nginx => 1.3.7
    listen      443 ssl#{defaultServer};
    listen [::]:443 ssl#{defaultServer};
    server_name #{serverName};
  #{webRoot}
  """

NGINX.ssl = (fullchain=$$.SSLFullchain,key=$$.SSLHostKey)->
  if ( $fs.existsSync fullchain ) and ( $fs.existsSync key ) then """
    ssl_certificate     #{fullchain};
    ssl_certificate_key #{key};
  """ else ''

NGINX.httpRedirect = (serverName)-> """
  server {
    listen 80;
    listen [::]:80;
    server_name #{serverName || $$.ServerName || '_'};
    return 301 https://$host$request_uri;
  }"""

NGINX.sslLockdown = -> """
  \ \ # resolver $DNS-IP-1 $DNS-IP-2 valid=300s;
    # resolver_timeout 5s;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    # add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
  """

NGINX.needsAuth = -> """
  if ( $grant != 1 ){ return 401; }
  """

NGINX.cookieFactor = (sessionPath=APP.session.path)->
  """
  \ \ set $grant 0;
    set $factor "";
    if ( $http_cookie ~* "SESSION=([a-f0-9]+)(;|$)" ) {
      set $auth_cookie $1; }
    if ( -f "#{sessionPath}/${auth_cookie}" ) {
      set $factor "${factor}c";
      set $auth_user_cookie $cookie_user; }
  """

NGINX.singleFactor = (sessionPath=APP.session.path)->
  return '' unless FLAG.UseAuth
  """
    # singleFactor
    set $auth_user_ssl "";
  #{NGINX.cookieFactor sessionPath}
    if ( $factor = 'c' ) { set $grant 1; }
  """

NGINX.multiFactor = (clientCA,gateDN)-> """
  # multiFactor
  #{NGINX.cookieFactor()}
  ssl_client_certificate #{SSLClientCA};
  ssl_verify_client      optional;
  ssl_verify_depth       2;
  set $gate_dn '#{SSLGateDN}';
  if ( $ssl_client_verify = SUCCESS       ) { set $factor "${factor}s"; set $has_cert 1; }
  if ( $ssl_client_s_dn != ''             ) { set $auth_dn $ssl_client_s_dn;    }
  if ( $ssl_client_s_dn = $gate_dn        ) { set $auth_dn $http_x_gate_s_dn;   }
  if ( $auth_dn ~ ([a-z]+).casa.hktr.de ) { set $auth_user_ssl $1;      }
  if ( $auth_user_ssl = 'gate'            ) { return 403; }
  if ( $factor = 'cs'                     ) { set $grant 1; }
  """

NGINX.apiConfig = ->
  """
  # apiConfig
  location /api {
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_pass #{APP.protocol}://127.0.0.1:#{APP.port}/api;
    proxy_http_version 1.1; }
  """

NGINX.debugHeaders = ->
  """
  # debug-headers
  add_header            "X-Factor" $factor           always;
  add_header           "X-Cookies" $http_cookie      always;
  add_header         "X-Auth-User" $cookie_user      always;
  add_header       "X-Auth-Cookie" $auth_cookie      always;
  add_header       "X-Remote-User" $remote_user      always;
  add_header        "X-Auth-Grant" $grant            always;
  add_header         "X-Auth-S-DN" $ssl_client_s_dn  always;
  add_header         "X-Gate-S-DN" $http_x_gate_s_dn always;
  add_header     "X-Auth-User-SSL" $auth_user_ssl    always;
  add_header  "X-Auth-User-Cookie" $auth_user_cookie always;
  """
