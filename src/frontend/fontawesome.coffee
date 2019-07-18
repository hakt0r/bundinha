@npmDev "@fortawesome/fontawesome-free"
@gitDev "https://github.com/google/material-design-icons"

@client class Icon
  constructor:(id,title)-> return $.make Icon.markup id, title
  from:([id,title])-> new Icon
  @markup:(id,title)-> """<i title="#{title}" class="faw #{id}"/>"""

@icon = (args...)-> for spec in args
  if typeOf spec is 'string'    
    ICON[spec] = spec

@phase 'build:pre',-1,=>

  # ███    ███  █████  ████████ ███████ ██████  ██  █████  ██       ██████  ███████ ███████ ██  ██████  ███    ██
  # ████  ████ ██   ██    ██    ██      ██   ██ ██ ██   ██ ██       ██   ██ ██      ██      ██ ██       ████   ██
  # ██ ████ ██ ███████    ██    █████   ██████  ██ ███████ ██ █████ ██   ██ █████   ███████ ██ ██   ███ ██ ██  ██
  # ██  ██  ██ ██   ██    ██    ██      ██   ██ ██ ██   ██ ██       ██   ██ ██           ██ ██ ██    ██ ██  ██ ██
  # ██      ██ ██   ██    ██    ███████ ██   ██ ██ ██   ██ ███████  ██████  ███████ ███████ ██  ██████  ██   ████

  MaterialIcons = new Map
  d = $path.join RootDir,'node_modules','.git','material-design-icons'
  r = ( await $cp.run$ 'find',d,'-type','f' ).stdout.slice(0,-1).split('\n')
  for line in r when line.match(/_48px\.svg$/) and line.match /production/
    { dir, name, ext } = $path.parse line
    tmp = name.split '_'; size = tmp.pop(); name = tmp.join('_').replace /ic_/,''
    flavour = $path.basename dir
    return if name is ''
    MaterialIcons.set name, line
  console.log ':material-icons'.green.bold, MaterialIcons.size.toString().blue.bold

  # ███████  ██████  ███    ██ ████████  █████  ██     ██ ███████ ███████  ██████  ███    ███ ███████
  # ██      ██    ██ ████   ██    ██    ██   ██ ██     ██ ██      ██      ██    ██ ████  ████ ██
  # █████   ██    ██ ██ ██  ██    ██    ███████ ██  █  ██ █████   ███████ ██    ██ ██ ████ ██ █████
  # ██      ██    ██ ██  ██ ██    ██    ██   ██ ██ ███ ██ ██           ██ ██    ██ ██  ██  ██ ██
  # ██       ██████  ██   ████    ██    ██   ██  ███ ███  ███████ ███████  ██████  ██      ██ ███████

  FontAwesome = new Map
  d = $path.join RootDir,'node_modules','@fortawesome','fontawesome-free','svgs'
  r = ( await $cp.run$ 'find',d,'-type','f' ).stdout.slice(0,-1).split('\n')
  for line in r
    { name } = $path.parse line
    FontAwesome.set name, line
  console.log ':fontawesome'.green.bold, FontAwesome.size.toString().blue.bold

  # ██████   █████   ██████ ██   ██
  # ██   ██ ██   ██ ██      ██  ██
  # ██████  ███████ ██      █████
  # ██      ██   ██ ██      ██  ██
  # ██      ██   ██  ██████ ██   ██

  collect = {}

  for key, name of ICON
    Array.requireOn(collect,name).insert key

  @css ["""
  .faw { position: relative; }
  .faw:before {
    content: '';
    height: 100%;
    width: 100%;
    background-repeat: no-repeat;
    background-position: center;
    background-size: auto 1em;
    position: absolute; top:0; left:0;
    filter: invert(100%); }
  .faw span { display:none; }
  body.light-theme .faw:before { filter: unset; }
  """].concat( for name, keys of collect
    icon = $fs.readFileSync path, 'utf8' if path = FontAwesome.get name
    icon = $fs.readFileSync path, 'utf8' if path = MaterialIcons.get name
    unless icon
      console.log 'Icon not found:'.red, name, "(#{key})"
      continue
    classes = [name,keys].flat().unique
    .map (name)-> ".faw.#{name}:before"
    .join ','
    icon = "#{classes}{background-image:url('data:image/svg+xml;utf8," + Buffer.from(
      icon
      .replace /<!--[\s\S]+/gm, ''
      .trim()
    ).toString('utf8') + '\');}'
  ).join '\n'
  console.debug ':icons'.green, Object.keys(collect).join(' ').gray
