
# ██████  ██   ██  █████  ███████ ███████ ██████
# ██   ██ ██   ██ ██   ██ ██      ██      ██   ██
# ██████  ███████ ███████ ███████ █████   ██████
# ██      ██   ██ ██   ██      ██ ██      ██   ██
# ██      ██   ██ ██   ██ ███████ ███████ ██   ██

$$.Phaser = (Spec)->
  Spec.phase = (key,prio,func)->
    ( func = prio; prio = 1 ) unless func?
    @phaseList.push k:key,p:prio,f:func
    return @
  Spec.emphase = (key)->
    list = @phaseList
      .filter (o)-> o.k is key
      .sort (a,b)-> a.p - b.p
    await Promise.all list.map (o)->
      try await o.f.call @
      catch error
        console.error ':phase'.red, (key+':'+o.p).bold
        console.error error
        console.debug "[phase-handler]", error, o.f.toCode().gray
        process.exit 1
    console.debug ':phase'.green, key.red
    return @
  Spec
