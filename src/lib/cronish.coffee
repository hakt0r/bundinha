
class $$.Cronish
  constructor:(opts)->
    { @id, @interval=600e3, @worker, @delay = 0 } = opts
    Cronish.byId[@id] = @
    @locked  = false
    @trigger = @trigger.bind @
    @realInterval = @interval
    console.debug 'cron'.yellow.bold, @id.bold, @interval.toString().gray
    @timer = setTimeout @trigger, @delay
  trigger:->
    if @locked
      console.debug 'locked'.red.bold, @id.bold.yellow
      return false
    console.debug 'cron'.blue.bold, @id.bold
    clearTimeout @timer
    @locked = true
    console.debug 'cron:start'.yellow.bold, @id.bold.yellow
    try r = await @worker()
    catch e
      console.debug 'cron'.red.bold, @id.bold, @interval.toString().gray, @realInterval.toString().red
      console.error e
      @realInterval = @realInterval * 2
    console.debug 'cron:stop'.green.bold, @id.bold.yellow
    @locked = false
    @timer = setTimeout @trigger, @realInterval

Cronish.byId = {}
Cronish.from = (opts)->
  return false if Cronish[opts.id]?
  new Cronish opts

Bundinha::serverCron = (func)->
  @server.Cronish = $$.Cronish
  @server.init = func

Bundinha::clientCron = (func)->
  @client.Cronish = $$.Cronish
  @client.init = func
