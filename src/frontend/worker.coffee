
# ██     ██  ██████  ██████  ██   ██ ███████ ██████
# ██     ██ ██    ██ ██   ██ ██  ██  ██      ██   ██
# ██  █  ██ ██    ██ ██████  █████   █████   ██████
# ██ ███ ██ ██    ██ ██   ██ ██  ██  ██      ██   ██
#  ███ ███   ██████  ██   ██ ██   ██ ███████ ██   ██

@scope.webWorker = (name,sources...)->
  @client.init = ->
    loadWorker = (name)->
      src = document.getElementById(name).textContent
      blob = new Blob [src], type: 'text/javascript'
      $$[name] = new Worker window.URL.createObjectURL blob
    loadWorker name for name in BunWebWorker
    return
  @webWorkerScope[name] = @compileSources sources

@phase 'build:frontend:post', =>
  @insertWorkers = ( for name, src of @webWorkerScope
    # src = minify(src).code
    """<script id="#{name}" type="text/js-worker">#{src}</script>"""
  ).join '\n'
  @workerHash = ''
  @workerHash += "'" + contentHash(@serviceWorkerSource) + "'" if @serviceWorkerSource
  @workerHash += " '" + contentHash(src) + "'" for name, src of @webWorkerScope
  console.log 'build:workers:hash'.bold.yellow, @workerHash
