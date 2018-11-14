
@require 'bundinha/miqro'
@client init:@arrayTools
@client escapeHTML:escapeHTML
@client toAttr:toAttr
@client SHA512:SHA512

@client.init = ->
  try $$.$forge = forge
  CONT = $ 'content'; NAVI = $ 'navigation'
  $$$.body.append CONT = $.make '<content>'    unless CONT
  $$$.body.append NAVI = $.make '<navigation>' unless NAVI
  return

@require 'bundinha/button'
@require 'bundinha/editor'
@require 'bundinha/notification'
