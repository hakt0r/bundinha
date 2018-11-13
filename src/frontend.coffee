
@require 'bundinha/miqro'
@client init:@arrayTools
@client init:@miqro
@client escapeHTML:escapeHTML
@client toAttr:toAttr
@client SHA512:SHA512

@client.init = ->
  try $$.$forge = forge
  return

@require 'bundinha/button'
@require 'bundinha/editor'
@require 'bundinha/notification'
