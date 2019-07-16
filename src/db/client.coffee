
@require 'bundinha/db/db'

{ Database } = @server

Database.plugin.client =
  open:(name,opts)-> ( new Database.Client name, opts ).open()
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

@npm 'https'
@npm 'querystring'

RPC.BackendCall = (remote,auth,args...)-> new Promise (resolve)->
  buffer = Buffer.from('')
  postData = $querystring.stringify args
  options = hostname:remote, path:'/api',method:'POST',headers:
    'Authorization': auth,
    'Content-Type': 'application/x-www-form-urlencoded',
    'Content-Length': Buffer.byteLength postData
  req = $https.request options, (res)->
    res.on 'data', (chunk)->
      buffer = Buffer.concat [buffer,chunk]
    res.on 'end', (chunk)->
      buffer = Buffer.concat [buffer,chunk] if chunk
      resolve JSON.parse buffer.toString 'utf8'
  req.on 'error', -> resolve null
  req.write postData
  req.end()

@server class Database.Client
  constructor:(@name,opts)->
    Database.addLocking @
    @remote = opts.remote
    @auth = Buffer.from('$domain|1273099s8a7d09a8s7d098as7d9da546s47d6a3sd54a3s654da36s54d3a65s4d36a54sd36a5s486c5xz9v7mas7_asnda9').toString('base64')
  open:=>
    return @
  get:(key)=>
    return v if v = @cache[path]
    await RPC.BackendCall @remote,'db',@name,'get',key
  del:(key)->
    await @lockRecord path, null
    await RPC.BackendCall @remote,'db',@name,'del',key
    @releaseRecord path
  put:(key,value)=>
    await @lockRecord path, null
    value = if typeof value is 'string' then value else JSON.stringify value
    await RPC.BackendCall @remote,'db',@name,'put',key,value
    @releaseRecord path
  createReadStream:->
    e = new (require 'events').EventEmitter
    readFile = (key)=>
      return if key.match /\.\$\$$/
      e.emit 'data', key:key, value:await @get key
    setTimeout =>
      await Promise.all ( readFile key for key in await $fs.readdir$ @path )
      e.emit 'end'
    return e
