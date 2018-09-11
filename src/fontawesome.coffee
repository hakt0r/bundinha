
repo = path.join BunDir,'node_modules','@fortawesome','fontawesome-free','svgs'
dest = path.join BuildDir, 'fontawesome.css'

APP.css dest

if fs.existsSync dest
  console.log 'exists'.green, dest
  return

css = """
.fa,.faw { position: relative; min-width:2em; }
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
  icon = path.join repo,'solid',"#{name}.svg"
  icon = fs.readFileSync icon, 'utf8'
  unless icon
    console.log '404'.red, name
    continue
  icon = ".fa-#{name}:before{
    background-image:url('data:image/svg+xml;utf8," + Buffer.from(
    icon
    .replace /<!--[\s\S]+/gm, ''
    .trim()
  ).toString('utf8') + '\'); }'
).join '\n'

fs.writeFileSync dest, css

console.log ':icons'.green, Object.keys(ICON).join(' ').gray
