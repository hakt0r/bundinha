
class $$.ThreadLimiter
  constructor:(@limit=4)->
    @queue = []
    @active = 0
    @tick = @tick.bind @
  slot:->
    return ( new Promise (resolve)=> @queue.push resolve ) unless @active < @limit
    @active++
    @tick
  tick:->
    @active--
    return unless slot = @queue.shift()
    slot @tick
    @active++
