

@npmDev '@fortawesome/fontawesome-free'
@phase 'build:pre',-1,=>
  console.debug ':icons'.green, Object.keys(ICON).join(' ').gray
  pack = $path.dirname $path.dirname require.resolve '@fortawesome/fontawesome-free'
  repo = $path.join pack,'svgs'
  dest = $path.join BuildDir,'fontawesome.css'

  @css """
  .fa,.faw { position: relative; min-width:2.5em; }
  .fa span, .faw span { display:none; }
  .fa:before,.faw:before {
    content: '';
    height: 100%;
    width: 100%;
    background-repeat: no-repeat;
    background-position: center;
    background-size: auto 1em;
    position: absolute; top:0; left:0; }
  .faw:before { filter: invert(100%); }
  """ + ( for key, name of ICON
    if $fs.existsSync icon = $path.join repo,'solid',"#{name}.svg"
      icon = $fs.readFileSync icon, 'utf8'
    else if $fs.existsSync icon = $path.join repo,'brands',"#{name}.svg"
      icon = $fs.readFileSync icon, 'utf8'
    if icon.match '\.svg$'
      console.log '404'.red, name
      continue
    icon = ".fa-#{name}:before{
      background-image:url('data:image/svg+xml;utf8," + Buffer.from(
      icon
      .replace /<!--[\s\S]+/gm, ''
      .trim()
    ).toString('utf8') + '\'); }'
  ).join '\n'

  console.debug ':icons'.green, Object.keys(ICON).join(' ').gray
