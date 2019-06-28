
@require 'bundinha/build/frontend'

@phase 'frontend:build', =>
  for font in @fontList
    [name,weight] = font
    n = encodeURIComponent name
    w = encodeURIComponent weight
    u = "https://fonts.googleapis.com/css?format=woff2&family=#{n}:#{w}"
    a = 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.81 Safari/537.36'
    r = $cp.spawnSync 'curl',[u,'-H',a,'--compressed']
    css = r.stdout.toString()
    while ( m = css.match /url\((http[^)]+)\)/ )?
      r = $cp.spawnSync 'curl',[m[1],'-H',a,'--compressed']
      css = css.replace m[1], 'data:font/woff2;base64,' + r.stdout.toString 'base64'
    $fs.writeFileSync p, css
    console.debug 'font'.green, name.bold, weight, ( css.length / 1024 ).toFixed 2
  return

@fontList = []
@font = (name,weight=400)->
  p = $path.join WebDir, name.toLowerCase() + '_' + weight + '.css'
  return if $fs.existsSync p
  @fontList.push name, weight
