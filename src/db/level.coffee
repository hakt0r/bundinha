
# @npm 'leveldb'
@require 'bundinha/db/db'

@server.APP.initDB = ->
  for name, opts of APP.db
    console.debug '::::db'.yellow, ':' + name.bold, opts
    db = $level path = $path.join ConfigDir, name + '.db'
    if ( typeName = opts.typeName )?
      Table = Database.extend $$[typeName], db
      Table.db = Table::db = db
      Table.path = Table::path = path
      Object.assign Table, opts
    else APP[name] = db
    console.debug '::::db', ':' + name.bold
  console.debug '::::db', 'ready'.green

{ Database } = @server

Database.get = (id)-> new Promise (resolve)=>
  throw new Error 'Not found: ' + id unless rec = JSON.parse await @db.get id
  resolve new @ rec

Database.del = (id)-> new Promise (resolve)=>
  @db.del id
  resolve true

Database.createFrom = (data,req)->
  try evt = await @db.get data.id
  throw new Error 'Exists' if evt?
  evt = @create data,req
