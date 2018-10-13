# ██      ██  ██████ ███████ ███    ██ ███████ ███████
# ██      ██ ██      ██      ████   ██ ██      ██
# ██      ██ ██      █████   ██ ██  ██ ███████ █████
# ██      ██ ██      ██      ██  ██ ██      ██ ██
# ███████ ██  ██████ ███████ ██   ████ ███████ ███████

Bundinha::buildLicense = ->
  npms = ( for name, pkg of @npmLicenses
    [match,link,version] = name.match /(.*)@([^@]+)/
    shortName = link.split('/').pop()
    licenses = pkg.package.concat(pkg.license).unique
    licenses = licenses.filter (i)-> i isnt '? verify'
    """<div class=npm-package>
    <span class=version>#{version}</span>
    <span class=name><a href="https://www.npmjs.com/package/#{encodeURI link}">#{escapeHTML shortName}</a></span>
    <span class="license-list"><span class="license">#{licenses.map(escapeHTML).join('</span><span class="license">')}</span></span>
    </div>"""
  ).join '\n'
  html = """
    <h1>Licenses</h1>
    <h2>npm packages</h2>
    <table class="npms">#{npms}</table>
    <h2>nodejs and dependencies</h2>
  """
  data = @NodeLicense
  data = data.replace /</g, '&lt;'
  data = data.replace />/g, '&gt;'
  data = data.replace /, is licensed as follows/g, ''
  toks = data.split /"""/
  out  = toks.shift(); mode = off
  while ( segment = do toks.shift )
    unless mode
      out += '<pre class=license_text>'
      segment = segment.replace /\n *\/\/ /g, ''
      segment = segment.replace /\n *# /g, '\n'
      segment = segment.replace /\n *#\n/g, '\n\n'
      segment = segment.replace /\n *\=+ *\n*/g, '<span class=hr></span>'
      segment = segment.replace /\n *\-+ *\n*/g, '<span class=hr></span>'
      out += segment.trim() + '</pre>'
      mode = on
    else
      out += segment.trim().replace(/^ *- */,'')
      mode = off
  html += out
  tpl = @tpl()
  tpl.AppPackageLicense = html
  console.log 'format'.green, 'license'
