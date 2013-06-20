
@setupBenchmarkUI = ->
  # $('li.dropdown').before "<a id='benchbtn' class='btn btn-danger'><i class='icon-beaker'></i> benchmark</a>"
  $('li.dropdown').before "
    <form class='navbar-form pull-right'>
      <button id='benchbtn' class='btn btn-danger'><i class='icon-beaker'></i> benchmark</button>
      <input id='fpsbox' type='text' class='span1 disabled'>
    </form>"
  @fpsbox_selector = $('#fpsbox')
  $('#benchbtn').click (event) ->
    event.preventDefault()
    startTesting()


displayFPS = (fps) ->
  @fpsbox_selector.val "#{fps} fps"

@startTesting = ->
  console.log "Benchmarking begins!"
  if !window.FPSMeter
    alert("This test page doesn't seem to include FPSMeter: aborting")
    return

  console.log "Halting any existing streams..."
  stopScoreStreaming() if @source
  stopDetailStreaming() if @detail_source

  nullFn = ->
    a = 1
  testRun(nullFn, 10)


@testRun = (setupFn, duration=30) ->
  setupFn()

  fpsLog = []
  fpsHandler = (e) =>
    fpsLog.push e.fps
    displayFPS e.fps
    console.log "FPS: #{e.fps}"

  document.addEventListener 'fps', fpsHandler

  console.log "Beginning to profile FPS"

  FPSMeter.run()
  startScoreStreaming()

  endGame = ->
    stopScoreStreaming()
    FPSMeter.stop()
    document.removeEventListener 'fps', fpsHandler
    handleResultsFromRun(fpsLog)
  setTimeout endGame, duration*1000


handleResultsFromRun = (results) ->
  console.log results

$ ->
  setupBenchmarkUI()
