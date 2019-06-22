
@HasFrontend         = if @HasFrontend?         then @HasFrontend         else true
@inlineManifest      = if @inlineManifest?      then @inlineManifest      else no
@inlineManifestIcons = if @inlineManifestIcons? then @inlineManifestIcons else no
@concatScripts       = if @concatScripts?       then @concatScripts       else no
@inlineScripts       = if @inlineScripts?       then @inlineScripts       else no
@concatStyles        = if @concatStyles?        then @concatStyles        else no
@inlineStyles        = if @inlineStyles?        then @inlineStyles        else no

@asset = ['/']
@scriptHash = []
@stylesHash = []
@insertStyles = ''
@insertScripts = ''

@phase 'build',0, =>
  return if @HasFrontend is false
  @reqdir WebDir
  @reqdir @AssetDir

@phase 'build',9999, =>
  return if @HasFrontend is false
  console.log ':build:'.bold.inverse.green, 'frontend'.bold, @AssetURL.yellow, @htmlFile.bold
  @insertHtml = head:'',body:''
  await @emphase 'build:frontend:pre'
  await @emphase 'build:frontend'
  await @emphase 'build:frontend:post'
  await @emphase 'build:frontend:hash'
  await @emphase 'build:frontend:metadata'
  await @emphase 'build:frontend:write'

@require 'bundinha/frontend/html'
@require 'bundinha/frontend/script'
@require 'bundinha/frontend/worker'
@require 'bundinha/frontend/css'
@require 'bundinha/frontend/manifest'
