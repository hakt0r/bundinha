
@require 'bundinha/backend/backend'

@server.APP.initDB = ->
  initTable = (name, opts)->
    plugin = opts.plugin || opts.plugin = 'level'
    console.debug '::::db'.yellow, ':' + name.bold, plugin, opts
    db = await Database.plugin[plugin].open(name,opts)
    Database.byName[name] = db
    if ( typeName = opts.typeName )?
      Table = Database.extend $$[typeName], db, plugin, opts
      Table.path = Table::path = opts.path
      Table.fields = opts.fields
    else APP[name] = Table = db
    console.debug '::::db', ':' + name.bold, opts
    Table
  await Promise.all ( initTable name, opts for name, opts of APP.db )
  console.debug '::::db', 'ready'.green

@preCommand ->
  await do APP.initDB if APP.initDB
  return

@group 'db', ['$admin','$db'], ->
  if not ( name = @args.shift() ) or name is 'list'
    return Object.keys Database.byName
  unless db = Database.byName[name]
    @error 404
  switch cmd = @args.shift()
    when 'put'  then return await db.put key = @args.shift(), @args.shift()
    when 'get'  then return await db.get key = @args.shift()
    when 'del'  then return await db.del key = @args.shift()
    when 'edit' then return await new Promise (resolve)=>
      key = @args.shift()
      raw = @args.shift() is '-r'
      unless u = await db.get key
        @error "#{db}/#{key} does not exist:".bold, key, error
      p = '/tmp/edit.' + SHA512 [db,key].join '|'
      await new Promise (resolve)->
        await $fs.writeFile$ p, u
        e = $cp.spawn 'atom',['--wait',p]
        e.on 'close', resolve
      u = await $fs.readFile$ p, 'utf8'
      @error "Not valid JSON" if not raw and not try JSON.parse u
      await db.put key, u
      try await $fs.unlink$ p
      resolve true
    when 'list' then return await new Promise (resolve)->
      l = []
      s = db.createReadStream()
      s.on 'data', (r)-> l.push r.key
      s.on 'error', (r)->
      s.on 'end', (r)-> resolve l
  @error 404

@scope.db = (name,opts={})->
  if 'string' is typeof name
    @dbScope[name] = opts || {}
  else for typeName, opts of name
    opts.typeName = typeName
    opts.file     = opts.file   || typeName
    opts.fields   = opts.fields || $$[typeName].fields || {}
    @dbScope[opts.file] = opts

# ██████   █████  ████████  █████  ██████   █████  ███████ ███████
# ██   ██ ██   ██    ██    ██   ██ ██   ██ ██   ██ ██      ██
# ██   ██ ███████    ██    ███████ ██████  ███████ ███████ █████
# ██   ██ ██   ██    ██    ██   ██ ██   ██ ██   ██      ██ ██
# ██████  ██   ██    ██    ██   ██ ██████  ██   ██ ███████ ███████

@server class Database
  @byName:{}
  @extend:(Table,db,plugin,opts)=>
    p = Database.plugin[plugin].extend || {}
    g = Database.plugin.generic
    Table.db = Table::db = db
    Table.createFrom = fn.bind Table if fn = p.createFrom || g.createFrom
    Table.get        = fn.bind Table if fn = p.get        || g.get
    Table.put        = fn.bind Table if fn = p.put        || g.put
    Table.del        = fn.bind Table if fn = p.del        || g.del
    Table.verify     = fn.bind Table if fn = p.verify     || g.verify
    Table::verify    = fn            if fn = p.verify     || g.verify
    Table::toJSON    = fn            if fn = p.toJSON     || g.toJSON
    Table::toString  = fn            if fn = p.toString   || g.toString
    Object.assign Table, opts
    defineField = (key,spec)->
      console.debug opts.file, key.blue, spec
      Object.defineProperty Table::, key,
        get:(value)-> @record[key]
        set:(value)-> @record[key] = value; @isDirty = true
        enumerable: true
    if Table.fields?
      for key,spec of Table.fields
        spec.rw = spec.rw || Table.access
        defineField key,spec
    Table
  @plugin: generic:
    toJSON:   (req)-> await @verify @record, req, 'r'
    toString: (req)-> JSON.stringify await @toJSON req

Database.plugin.generic.verify = (data,req,access,create)->
  # console.log 'verify', access, Object.keys(data).join(',').gray, create || ''
  verified   = {}
  errors     = {}
  hadError   = false
  specFields = @fields || @constructor.fields
  hasGroups  = ( req.USER.group || [] ).slice()
  accessType = if access is 'r' then 0 else 1
  for fieldName, value of data
    if ( not opts = specFields[fieldName] ) and ( access is 'w' )
      throw new Error 'InvalidField: ' + fieldName
    continue unless opts
    accessGroups = [opts.rw[accessType]]
    hasGroups.push 'public' if -1 is hasGroups.indexOf 'public'
    testSpec     = opts.t
    testSpecKeys = Object.keys testSpec
    accessGroups.map (spec)->
      if spec[0] is '$' and func = $$[spec]
        if func req, data
          hasGroups.push spec if -1 is hasGroups.indexOf spec
    # console.log fieldName.bold, value
    # console.log 'need'.red, accessGroups
    # console.log 'has'.green, hasGroups
    for testName in testSpecKeys
      try
        value = Database[testName].apply null, testSpec[testName].concat value
        if create or RequireGroupBare hasGroups, accessGroups
          verified[fieldName] = value
        else if access is 'w'
          DenyAuth ': cannot write to: ' + fieldName;
      catch e
        errors[fieldName] = errors[fieldName] || {}
        errors[fieldName][testName] = e
        hadError = true
  if hadError
    req.err 'access'.red.bold, req.UID, errors
    throw ( e = new Error 'VerificationError'; e.data = errors; e )
  verified

# ███████ ██ ███████ ██      ██████      ████████ ██    ██ ██████  ███████ ███████
# ██      ██ ██      ██      ██   ██        ██     ██  ██  ██   ██ ██      ██
# █████   ██ █████   ██      ██   ██        ██      ████   ██████  █████   ███████
# ██      ██ ██      ██      ██   ██        ██       ██    ██      ██           ██
# ██      ██ ███████ ███████ ██████         ██       ██    ██      ███████ ███████

Database.String = (len,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  data

Database.Title = (len,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  throw new Error 'Maformed' unless data.match /^[a-z0-9-+ _@.,\(\)\[\]]+$/i
  data

Database.URL = (len,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'Maformed' unless data.match /^https?:\/\/[^'"<>]+$/i
  data

Database.CountryCode = (data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if 3 <= data.length
  throw new Error 'Maformed' unless data.match /^[a-z]+$/i
  data

Database.HTMLFormats = (len,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  # TODO
  data

Database.TimeStamp = (data)->
  data = parseFloat data
  throw new Error 'Required' unless data?
  throw new Error "NoNumber: #{data}(#{t})" if 'number' isnt t =  typeof data
  throw new Error 'NoTimestamp' unless 0 <= data <= Number.MAX_SAFE_INTEGER
  data

Database.Number = (min=-1,max=-1,places=0,data)->
  data = parseFloat data
  throw new Error 'Required' unless data?
  throw new Error "NoNumber: #{data}(#{t})" if 'number' isnt t =  typeof data
  throw new Error 'FractionOverflow' if places is 0 and data.toString().split('.')[1]?
  data

Database.Array = (len,types,data)->
  throw new Error 'Required' unless data?
  throw new Error "NoString: #{data}(#{t})" if 'string' isnt t =  typeof data
  throw new Error 'TooLong'  if len < data.length
  # TODO
  data

Database.addLocking = (Db)-> Object.assign Db,
  lock:{}
  cache:{}
  lockRecord:(key,value)->
    @cache[key] = value
    unless @lock[key]
      @lock[key] = []
    else new Promise (resolve)=> @lock[key].push resolve
  releaseRecord:(key,value)->
    if @lock[key] and next = @lock[key].shift()
      return next()
    delete @cache[key]
    delete @lock[key]
