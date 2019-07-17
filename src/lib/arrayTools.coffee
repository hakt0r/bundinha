
$$.ArrayTools = ->
  return if Array::unique
  Object.forEach = (o,c)-> c k,v for k,v of o
  Object.filter  = (o,c)-> r = {}; r[k] =         v for k,v of o when c k,v    ; r
  Object.map     = (o,c)-> r = {}; r[x[0]] = [x[1]] for k,v of o when x = c k,v; r
  unless Array::flat then Object.defineProperty Array::,'flat',enumerable:false,value:->
    depth = if isNaN(arguments[0]) then 1 else Number(arguments[0])
    if depth then Array::reduce.call(@, ((acc, cur) ->
      if Array.isArray(cur) then acc.push.apply acc, Array::flat.call(cur, depth - 1)
      else acc.push cur
      acc
    ), []) else Array::slice.call(@)
  Object.defineProperties String::,
    asValue: get:->  @
    asArray: get:-> [@]
  Array.requireOn = (o,k)-> o[k] || o[k] = []
  Object.defineProperties Array::,
    toObject: value: (callback)-> o = {}; @forEach((d)-> if r = callback d then ([k,v]=r;o[k]=v)); o
    asValue: get: -> l = @length; `l==0?false:l==1?this[0]:this`
    asArray: get: -> @
    first:   get: -> @[0]
    last:    get: -> @[@length-1]
    trim:    get: -> return ( @filter (i)-> i? and i isnt false ) || []
    random:  get: -> @[Math.round Math.random()*(@length-1)]
    unique:  get: -> u={}; @filter (i)-> return u[i] = on unless u[i]; no
    remove:  value: (v)-> @splice(i,1)    if i = @indexOf v; @
    cull:    value: (v)-> @splice(i,1) while i = @indexOf v; @
    insert:  value: (v)-> @push v if -1 is @indexOf v
    common:  value: (b)-> @filter (i)-> -1 isnt b.indexOf i
    without: value: (v)-> v = v.asArray; @filter (e)-> -1 is v.indexOf e
    uniques: get: ->
      u={}; result = @slice()
      @forEach (i)->
        result.remove i if u[i]
        u[i] = on
      result
  return
