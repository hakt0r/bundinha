
@require 'bundinha/db/db'

{ Database } = @server

Database.plugin.text =
  open:(name,opts)-> ( new Database.Text name ).open()
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

@server class Database.Text
  constructor:(@name)-> @path = $path.join ConfigDir, @name
  open:=> await $fs.mkdir$ @path unless await $fs.exists$ @path; @
  get:(key)=>
    path = $path.join @path, key
    throw new Error "db:#{@name}: key does not exist '#{key}'" unless await $fs.exists$ path
    $fs.readFile$ path, 'utf8'
  del:(key)-> await $fs.unlink$ $path.join @path, key
  put:(key,value)=>
    path = $path.join @path, key
    value = if typeof value is 'string' then value else JSON.stringify value
    await $fs.writeFile$ path+'.$$', value
    $fs.rename$ path+'.$$', path
  createReadStream:->
    e = new (require 'events').EventEmitter
    readFile = (key)=> e.emit 'data', key:key, value:await @get key
    setTimeout =>
      await Promise.all ( readFile key for key in await $fs.readdir$ @path )
      e.emit 'end'
    return e
