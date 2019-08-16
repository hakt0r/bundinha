
#  ██████ ███████ ███████
# ██      ██      ██
# ██      ███████ ███████
# ██           ██      ██
#  ██████ ███████ ███████

@collectorScope 'css', {}, (target,prop,value)=>
  prop = 'asset'   if Array.isArray value
  value = value[0] if Array.isArray value
  prop = 'app'     if 'string' is typeof value
  @cssScope[prop] = @cssScope[prop] || []
  @cssScope[prop].push value
  # console.debug '  CSS '.yellow.bold.inverse, prop.bold, value
  true

@phase 'build:frontend:pre',0,@buildFrontendStylesPre = =>
  @cssFile = @cssFile || @htmlFile.replace(/.html$/,'') + '.css'
  @cssURI  = $path.join @AssetURL, @cssFile

@phase 'build:frontend:post',@buildFrontendStyles = =>
  @cssScope.asset = @cssScope.asset || []
  await do =>
    # console.debug "  CSS ".red.bold.inverse, @cssScope
    CleanCSS = require 'clean-css' if @minify
    styles = ''
    for href in @cssScope.asset when Array.isArray(href) and href[0]?.match? and href[0]?.match /^href:/
      @insertStyles += """<link rel=stylesheet href="#{href.slice(1).join '/'}"/>"""
    if @concatStyles
      styles += ( await @loadAsset href ) + '\n' for href     in @cssScope.asset when href.match and not href.match /^href:(.*)$/
      styles += ( styles.join '\n'      ) + '\n' for k,styles of @cssScope       when k isnt 'asset'
    else
      for href in @cssScope.asset
        continue if Array.isArray(href) and href[0]?.match? and href[0]?.match /^href:/
        [file,data] = await @linkAsset href
        @insertStyles += """<link rel=stylesheet href="#{file.replace /^\//,''}"/>"""
        @stylesHash.push "'" + ( contentHash data ) + "'"
        @asset.push file
      styles += data + '\n' for dest, data of @cssScope when dest isnt 'asset'
    styles = (new CleanCSS {}).minify(styles).styles if @minify
    return                                           if styles.trim() is ''
    @stylesHash.push "'" + ( contentHash styles ) + "'"
    if @inlineStyles is false
         console.debug ' CSS:WRITE '.green.inverse, @cssFile
         $fs.writeFileSync $path.join(@AssetDir,@cssFile), styles
         @insertStyles += """<link rel=stylesheet href="#{@cssURI.replace /^\//,''}"/>"""
         @asset.push @cssURI
         console.debug ':write'.green, @cssFile.bold
    else @insertStyles += """<styles>#{styles}"</styles>"""
  @stylesHash = @stylesHash.join ' '
