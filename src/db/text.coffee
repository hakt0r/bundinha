
@require 'bundinha/db/db'

{ Database } = @server

Database.plugin.text =
  open:(name,opts)->
    ( new Database.Text name, opts ).open()
  getJSON: (id)-> new Promise (resolve)=>
    throw new Error 'Not found: ' + id unless rec = JSON.parse await @db.get id
    rec.id = id
    resolve new @ rec
  del: (id)-> new Promise (resolve)=>
    @db.del id
    resolve true
  extend:
    get:(key)-> await @db.get key
    createFrom: (req)->
      try evt = await @db.get req.args.id
      throw new Error 'Exists' if evt?
      evt = @create req

@server class Database.Text
  constructor:(@name,opts)->
    Database.addLocking @
    @path = $path.join ConfigDir, @name
    if opts.escape
      @escape = $$[opts.escape]
      unless @escape and typeof @escape is 'function'
        throw new Error "Db:Text - @escape is not a function"
        process.exit 1
    else @escape = $fs.escape
  open:->
    await $fs.mkdir$ @path unless await $fs.exists$ @path
    return @
  get:(key,isEscaped)->
    if isEscaped then path = $path.join @path, key
    else path = $path.join @path, @escape(key)
    return v if v = @cache[path]
    throw new Error "db:#{@name}: key does not exist '#{key}'" unless await $fs.exists$ path
    result = await $fs.readFile$ path, 'utf8'
    return result
  del:(key)->
    path = $path.join @path, @escape key
    await @lockRecord path, null
    await $fs.unlink$ path
    @releaseRecord path
  put:(key,value)->
    console.debug @name.bold, 'put'.green.bold, key, value
    path = $path.join @path, @escape key
    await @lockRecord path, null
    value = if typeof value is 'string' then value else JSON.stringify value
    await $fs.writeFile$ path + '.$$', value
    await $cp.spawn$$ 'sync'
    await $fs.rename$ path + '.$$', path
    console.debug @name.bold, 'put'.green.bold, key, value
    @releaseRecord path
  createReadStream:->
    e = new (require 'events').EventEmitter
    readFile = (key)=>
      return if key.match /\.\$\$$/
      path = $path.join @path, key
      e.emit 'data', path:path, key:key, value:await @get key, true
    setTimeout =>
      await Promise.all ( readFile key for key in await $fs.readdir$ @path )
      e.emit 'end'
      e.emit 'close'
    return e
