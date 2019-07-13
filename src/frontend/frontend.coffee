
@require 'bundinha/frontend/miqro'

@client init:$$.ArrayTools
@client escapeHTML:escapeHTML
@client toAttr:toAttr
@client SHA512:SHA512

@client.init = ->
  try $$.$forge = forge
  $$.$$$  = document
  $$.BODY = $$$.body
  $$.CONT = $ 'content'
  $$.NAVI = $ 'navigation'
  BODY.append $$.CONT = $.make '<content>'    unless CONT
  BODY.append $$.NAVI = $.make '<navigation>' unless NAVI
  return

@require 'bundinha/frontend/button'
@require 'bundinha/frontend/editor'
@require 'bundinha/frontend/notification'
