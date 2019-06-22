
# ███    ███  █████  ███    ██ ██ ███████ ███████ ███████ ████████
# ████  ████ ██   ██ ████   ██ ██ ██      ██      ██         ██
# ██ ████ ██ ███████ ██ ██  ██ ██ █████   █████   ███████    ██
# ██  ██  ██ ██   ██ ██  ██ ██ ██ ██      ██           ██    ██
# ██      ██ ██   ██ ██   ████ ██ ██      ███████ ███████    ██

@phase 'build:pre', =>
  @manifestPolicy = "'self'"
  @server.AppManifest = @manifest = {}
  return if @HasBackend is no
  console.log " backend:dynamic ".blue.inverse, @AssetDir, 'manifest.json'
  @manifestPolicy = "'self' https:"
  @insertManifest = """<link rel=manifest crossorigin="use-credentials" href="#{$path.join @AssetURL,'manifest.json'}"/>"""
  @server.init = ->
    console.log " backend:dynamic ".red.inverse, AssetDir, 'manifest.json'
    csp = $fs.readFileSync $path.join(__dirname,'csp.txt'), 'utf8'
    console.log " write ".red.inverse, AssetDir, 'manifest.json', csp.replace(/\n/g,' ').replace(/[ ]+/g,' ').gray
    AppManifest.content_security_policy = csp
    AppManifest.orientation = AppManifest.orientation || 'any'
    AppManifest.start_url = BaseUrl + '/' # if AppManifest.start_url
    AppManifest.display = 'standalone' unless AppManifest.display
    $fs.writeFileSync $path.join(AssetDir,'manifest.json'), JSON.stringify AppManifest
    return
  Object.assign @manifest, (
    name: AppName
    manifest_version: 2
    short_name: AppPackageName
    theme_color:      @themeColor || "black"
    background_color: @themeBg    || "#231f27"
  ), @manifest
  if @inlineManifestIcons is yes
    @manifest.icons = [
      { src: "data:image/png;base64,#{$fs.readBase64Sync @AppIconPNG}", density: "1", sizes: "512x512", type: "image/png"  }
      { src: "data:image/svg+xml;base64,#{$fs.readBase64Sync @AppIcon}", density: "1", sizes: "any", type: "image/svg+xml" } ]
  else if @AppIcon? and @AppIconPNG?
    p1 = $path.join @AssetURL, b1 = $path.basename @AppIcon
    p2 = $path.join @AssetURL, b2 = $path.basename @AppIconPNG
    @manifest.icons = [
      { src: "#{p1}", density: "1", sizes: "any", type: "image/svg+xml" }
      { src: "#{p2}", density: "1", sizes: "512x512", type: "image/png"  } ]
    @linkAsset @AppIcon,    $path.join @AssetDir, p1
    @linkAsset @AppIconPNG, $path.join @AssetDir, p2
  return

@phase 'build:frontend:post', =>
  if icon = @AppIconPNG || @AppIcon
    await $cp.exec$ """
    convert -resize 32x32 '#{icon}' '#{$path.join @AssetDir,'favicon.ico'}'
    """

@phase 'build:frontend:metadata', =>
  return if @HasBackend is no
  console.log 'build:manifest'.bold.yellow, @workerHash
  return do @buildInlineManifest if @inlineManifest is yes
  return

@phase 'build:frontend:write', =>
  if @HasBackend is no
    console.log " write ".red.inverse, @AssetDir, 'manifest.json', 'static'.red
    $fs.writeFileSync $path.join(@AssetDir,'manifest.json'), JSON.stringify @manifest
    return
  return

@buildInlineManifest = ->
  @manifestPolicy = 'data:'
  @insertManifest = """<link rel=manifest href='data:application/manifest+json,#{
    JSON.stringify(@manifest).replace(/#/g,'%23')
  }'/>"""
