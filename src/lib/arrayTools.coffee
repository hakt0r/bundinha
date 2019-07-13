
$$.ArrayTools = ->
  return if Array::unique
  Object.filter = (o,c)->
    r = {}
    r[k] = v for k,v of o when c k,v
    r
  unless Array::flat then Object.defineProperty Array::,'flat',enumerable:false,value:->
    depth = if isNaN(arguments[0]) then 1 else Number(arguments[0])
    if depth then Array::reduce.call(this, ((acc, cur) ->
      if Array.isArray(cur) then acc.push.apply acc, Array::flat.call(cur, depth - 1)
      else acc.push cur
      acc
    ), []) else Array::slice.call(this)
  Object.defineProperty String::, 'arrayWrap', get:-> [@]
  Object.defineProperty Array::,  'arrayWrap', get:-> @
  Object.defineProperties Array::,
    trim:    get: -> return ( @filter (i)-> i? and i isnt false ) || []
    random:  get: -> @[Math.round Math.random()*(@length-1)]
    unique:  get: -> u={}; @filter (i)-> return u[i] = on unless u[i]; no
    uniques: get: ->
      u={}; result = @slice()
      @forEach (i)->
        result.remove i if u[i]
        u[i] = on
      result
    remove:     enumerable:no, value: (v) -> @splice i, 1 if i = @indexOf v; @
    pushUnique: enumerable:no, value: (v) -> @push v if -1 is @indexOf v
    common:     enumerable:no, value: (b) -> @filter (i)-> -1 isnt b.indexOf i
  return
