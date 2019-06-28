
{ APP } = @server

APP.user.request = (uri)->
  url = 'http://graph.facebook.com/517267866/?fields=picture'
  http.get(url, (res) ->
    body = ''
    res.on 'data', (chunk) ->
      body += chunk
      return
    res.on 'end', ->
      fbResponse = JSON.parse(body)
      console.log 'Got a response: ', fbResponse.picture
      return
    return
  ).on 'error', (e) ->
    console.log 'Got an error: ', e
    return

APP.user = class RemoteDB
  put:-> false
  del:-> false
  get:->
