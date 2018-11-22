
@require 'bundinha/miqro'
@client init:@arrayTools
@client escapeHTML:escapeHTML
@client toAttr:toAttr
@client SHA512:SHA512

@client.init = ->
  try $$.$forge = forge
  $$.BODY = $$$.body
  $$.CONT = $ 'content'
  $$.NAVI = $ 'navigation'
  BODY.append $$.CONT = $.make '<content>'    unless CONT
  BODY.append $$.NAVI = $.make '<navigation>' unless NAVI
  return

@require 'bundinha/button'
@require 'bundinha/editor'
@require 'bundinha/notification'
