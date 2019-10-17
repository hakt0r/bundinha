
# ████████ ███████ ███    ███ ██████  ██    ██ ███████ ███████ ██████
#    ██    ██      ████  ████ ██   ██ ██    ██ ██      ██      ██   ██
#    ██    █████   ██ ████ ██ ██████  ██    ██ ███████ █████   ██████
#    ██    ██      ██  ██  ██ ██      ██    ██      ██ ██      ██   ██
#    ██    ███████ ██      ██ ██       ██████  ███████ ███████ ██   ██

@server.User.RequireTempSession = (req,group=['$temp'])->
  hash = WalletSalt + date = Date.now()
  unless req.USER?.id?
    req.USER = id:hash, group:['$shop'], date:date, temp:true
    await AddAuthCookie req
    await APP.user.put hash, JSON.stringify req.USER
  @error 'Session could not be set up' unless req.USER?.id?

Ticket.pruneTemp = -> new Promise (resolve)->
  APP.user.createReadStream()
  .on 'data', (entry)->
    { key, value } = entry
    return unless try value = JSON.parse value
    { date, temp } = value
    return unless temp
    return if isNaN date = parseInt date
    return if Date.now() < date + SessionTimeout
    console.log 'user'.yellow.bold, 'reap', key.bold, ( Date.now() - date + SessionTimeout ) + 'm old'
    APP.user.del key
  .on 'close', resolve

@server.init = ->
  Cronish.from id:'user:temp:prune', interval:60e3, worker:-> await Ticket.pruneTemp()
  return
