
# ███████  ██████  ██████  ██████  ███████ ███████
# ██      ██      ██    ██ ██   ██ ██      ██
# ███████ ██      ██    ██ ██████  █████   ███████
#      ██ ██      ██    ██ ██      ██           ██
# ███████  ██████  ██████  ██      ███████ ███████

@scopeScope = {}
@collectorScope = (scope,hook,doSet)->
  if 'function' is typeof hook
    doSet = hook; hook = []
  @[hookName = scope + 'Hook'] = hook
  scopeObject = @[scopeName = scope + 'Scope'] = {}
  scopeObject[cat] = '' for cat in hook
  unless doSet then doSet = (_target,_prop,_value)=>
    # console.log scope.yellow.bold, _prop.bold, _target if scope is 'server'
    if hook.includes _prop then scopeObject[_prop] += _value.toBareCode()
    else                        scopeObject[_prop]  = _value
    true
  proxy =
    get: (_target,_prop)=>
      return hook if _prop is '_hook'
      scopeObject[_prop]
    set: doSet
    apply: (_target,_this,_args)=>
      [ obj ] = _args
      return @[scope] unless obj?
      if 'string' is typeof obj then doSet null, null, obj
      else if Array.isArray obj then doSet null, null, obj
      else if obj::?            then doSet null, ( name = obj.name ), @[scope][name] = obj
      else                           doSet null, k,                   v for k,v of obj
      @[scope]
  @[scope] = new Proxy ( -> ), proxy

@scope = new Proxy(
  (name, addFunction)=>
    scopeName = name + 'Scope'
    addFunction = addFunction || ( (key,value)=> @[scopeName][key] = value )
    @scopeScope[name] = scopeObject = @[scopeName] = @[scopeName] || {}
    @[name] = new Proxy addFunction,
      get: (_target,_prop)=> @[scopeName][_prop]
      set: (_target,_prop,_value)=> @[name] _prop, _value; true
  get: (_target,_prop)=> @[_prop + 'Scope']
  set: (_target,_prop,_value)=> @scope _prop, _value; true )

@arrayScope = new Proxy(
  (name, pushFunction)->
    scopeName = name + 'Scope'
    pushFunction = pushFunction || ( (value)=> @[scopeName].push value )
    @scopeScope[name] = @[scopeName] = @[scopeName] || []
    @[name] = pushFunction
  get: (_target,_prop)=> @[_prop + 'Scope']
  set: (_target,_prop,_value)=> @arrayScope _prop, _value; true )
