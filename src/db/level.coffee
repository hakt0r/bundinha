
@npm ['level','level']
@require 'bundinha/db/db'

@server.Database.plugin.level =
  open: (name,opts)->
    path = $path.join ConfigDir, name + '.db'
    l = Object.assign $level(path), opts, path:path
    opts.convert = true is name is 'post'
    await @exportToText name,l if opts.convert
    l
  exportToText:(name,db)->
    out = {}
    try await $fs.mkdir$ $path.join ConfigDir, name
    await new Promise (resolve)->
      db.createReadStream()
      .on 'data', (u)-> out[u.key] = u.value
      .on 'close', resolve
    await Promise.all ( $fs.writeFile$ $path.join(ConfigDir, name, key), value for key, value of out )
  get: (id)-> new Promise (resolve)=>
    throw new Error 'Not found: ' + id unless rec = JSON.parse await @db.get id
    rec.id = id
    resolve new @ rec
  del: (id)-> new Promise (resolve)=>
    @db.del id
    resolve true
  extend:
    createFrom:(req)->
      console.log arguments
      try evt = await @db.get req.args.id
      throw new Error 'Exists' if evt?
      evt = @create req
