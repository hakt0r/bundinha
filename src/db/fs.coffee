
@require 'bundinha/db/db'

{ Database } = @server

Database.plugin.fs =
  open:(name,opts)->
    console.log 'open:fs', name
    ( new Database.Filesystem name, opts ).open()
  get: (id)-> new Promise (resolve)=>
    throw new Error 'Not found: ' + id unless rec = JSON.parse await @db.get id
    rec.id = id
    resolve new @ rec
  del: (id)-> new Promise (resolve)=>
    @db.del id
    resolve true
  createFrom: (req)->
    try evt = await @db.get req.args.id
    throw new Error 'Exists' if evt?
    evt = @create req

@server class Database.Filesystem
  constructor:(@name,opts)->
    Database.addLocking @
    @path = $path.join ConfigDir, @name
    if opts.escape
      @escape = $$[opts.escape]
      unless @escape and typeof @escape is 'function'
        throw new Error "Db:Filesystem - @escape is not a function"
        process.exit 1
    else @escape = $fs.escape
  open:->
    await $fs.mkdir$ @path unless await $fs.exists$ @path
    return @
  get:(key,isEscaped)->
    dir  = $path.dirname key
    if isEscaped then file = $path.basename key
    else file = @escape $path.basename key
    path = $path.join @path,dir,file
    return v if v = @cache[path]
    throw new Error "db:#{@name}: key does not exist '#{key}'" unless await $fs.exists$ path
    result = await $fs.readFile$ path, 'utf8'
    return result
  del:(key)->
    dir  = $path.dirname key
    file = @escape $path.basename key
    path = $path.join @path,dir,file
    await @lockRecord path, null
    await $fs.unlink$ path
    if 0 is ( c = await $fs.readdir$ $path.join @path, dir ).length
      await $fs.rmdir$ $path.join @path, dir
      p = dir.split '/'
      while check = p.pop()
        full = $path.join ...[@path].concat(p)
        unless 0 is c = ( await $fs.readdir$ full ).length
          p.push check
          break
        await $fs.rmdir$ full
    @releaseRecord path
  put:(key,value)->
    dir  = $path.dirname key
    file = @escape $path.basename key
    path = $path.join @path,dir,file
    fullDir = $path.join @path, dir
    await @lockRecord path, null
    unless await $fs.exists$ fullDir
      await $fs.mkdirp$ fullDir
    value = if typeof value is 'string' then value else JSON.stringify value
    await $fs.writeFile$ path + '.$$', value
    # await $cp.spawn$$ 'sync'
    await $fs.rename$ path + '.$$', path
    @releaseRecord path
  createReadStream:(opts={})->
    e = new (require 'events').EventEmitter
    readItem = (key)=>
      dir  = $path.dirname key
      file = $path.basename key
      path = $path.join @path,dir,file
      return if file.slice(-3) is '.$$' or file is '..' or file is '.'
      stat = await $fs.stat$ path
      await readFile key if stat.isFile()
      await readDir  key if stat.isDirectory()
    readDir = (path)=>
      await Promise.all (
        readItem "#{path}/#{key}" for key in await $fs.readdir$ $path.join @path, path )
    readFileAll = (key)=> e.emit 'data', key:key, value:await @get key, true
    readFileKey = (key)=> e.emit 'data', key
    readFileVal = (key)=> e.emit 'data', await @get key, true
    if opts.key? or opts.value?
      opts.key   = false if opts.value and not opts.key?
      opts.value = false if opts.key   and not opts.value?
    else opts.key = opts.value = true
    if          opts.key and     opts.value then readFile = readFileAll
    else if not opts.key and     opts.value then readFile = readFileVal
    else if     opts.key and not opts.value then readFile = readFileKey
    setTimeout => await readDir ''; e.emit 'end'
    return e
