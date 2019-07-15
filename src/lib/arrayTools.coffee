
$$.ArrayTools = ->
  return if Array::unique
  Object.filter = (o,c)->
    r = {}
    r[k] = v for k,v of o when c k,v
    r
  unless Array::flat then Object.defineProperty Array::,'flat',enumerable:false,value:->
    depth = if isNaN(arguments[0]) then 1 else Number(arguments[0])
    if depth then Array::reduce.call(@, ((acc, cur) ->
      if Array.isArray(cur) then acc.push.apply acc, Array::flat.call(cur, depth - 1)
      else acc.push cur
      acc
    ), []) else Array::slice.call(@)
  Object.defineProperties String::,
    asValue: enumerable:no, get:->  @
    asArray: enumerable:no, get:-> [@]
  Object.defineProperties Array::,
    asValue: enumerable:no, get: -> l = @length; `l==0?false:l==1?this[0]:this`
    asArray: enumerable:no, get: -> @
    first:   enumerable:no, get: -> @[0]
    last:    enumerable:no, get: -> @[@length-1]
    trim:    enumerable:no, get: -> return ( @filter (i)-> i? and i isnt false ) || []
    random:  enumerable:no, get: -> @[Math.round Math.random()*(@length-1)]
    unique:  enumerable:no, get: -> u={}; @filter (i)-> return u[i] = on unless u[i]; no
    remove:  enumerable:no, value: (v)-> @splice(i,1)    if i = @indexOf v; @
    cull:    enumerable:no, value: (v)-> @splice(i,1) while i = @indexOf v; @
    insert:  enumerable:no, value: (v)-> @push v if -1 is @indexOf v
    common:  enumerable:no, value: (b)-> @filter (i)-> -1 isnt b.indexOf i
    without: enumerable:no, value: (v)-> v = v.asArray; @filter (e)-> -1 is v.indexOf e
    uniques: enumerable:no, get: ->
      u={}; result = @slice()
      @forEach (i)->
        result.remove i if u[i]
        u[i] = on
      result
  return
