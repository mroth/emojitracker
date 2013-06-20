##########################
# UI methods
##########################
setupBenchmarkUI = ->
  $('li.dropdown').before "
    <form class='navbar-form pull-right'>
      <button id='benchbtn' class='btn btn-danger'><i class='icon-beaker'></i> benchmark</button>
      <input id='testnamebox' style='display:none;' type='text' class='span2' disabled>
      <input id='fpsbox' style='display:none;' type='text' class='span1' disabled>
    </form>"
  @fpsbox_selector = $('#fpsbox')
  @testnamebox_selector = $('#testnamebox')
  $('#benchbtn').click (event) ->
    event.preventDefault()
    startBenchmarking()

testRunUIStart = (testName='unnamedTest') ->
  @testnamebox_selector.val testName
  @fpsbox_selector.val '-'
  @testnamebox_selector.show()
  @fpsbox_selector.show()

displayFPS = (fps) ->
  @fpsbox_selector.val "#{fps} fps"

setDefaults = (animation,replace,reflow,timeout,capped_stream) ->
  @use_css_animation = animation
  @replace_technique = replace
  @reflow_technique = reflow
  @timeout_technique = timeout
  @use_capped_stream = capped_stream

##########################
# classes to handle testing
##########################
class Test
  constructor: (@name, @setupFn) ->
    @fpsLog = []

  toString: ->
    @name

  initFPSHandler: ->
    @fpsHandler = (e) =>
      @fpsLog.push e.fps
      displayFPS e.fps
      # console.log "FPS: #{e.fps}"
    document.addEventListener 'fps', @fpsHandler

  deinitFPSHandler: ->
    document.removeEventListener 'fps', @fpsHandler

  run: (callback=null, duration=10) ->
    console.log "*** Beginning test run for: #{@name}"
    @setupFn()
    @initFPSHandler()
    testRunUIStart()

    console.log " - beginning to profile FPS..."
    FPSMeter.run()
    startScoreStreaming()

    endGame = =>
      stopScoreStreaming()
      FPSMeter.stop()
      @deinitFPSHandler()
      handleResultsFromRun(@fpsLog)
      callback() if callback
    setTimeout endGame, duration*1000


class TestRunner
  constructor: () ->
    @testQueue = []

  add: (test) ->
    @testQueue.push(test)

  runNextTestIfExists: =>
    if @testQueue.length > 0
      setTimeout (=> @testQueue.pop().run(@runNextTestIfExists) ), 1500
    else
      console.log "...Test queue is exhausted!"
      null


##########################
# document-y methods
##########################
@startBenchmarking = ->
  console.log "It's time for some benchmarking!"
  if !window.FPSMeter
    alert("This test page doesn't seem to include FPSMeter: aborting")
    return

  console.log "Halting any existing streams..."
  stopScoreStreaming() if @source
  stopDetailStreaming() if @detail_source

  @tests = new TestRunner
  tests.add( new Test "none+raw",       -> setDefaults(false,false,false,false,false) )
  tests.add( new Test "none+capped",    -> setDefaults(false,false,false,false,true) )
  tests.add( new Test "replace+raw",    -> setDefaults(true, true, false,false,false) )
  tests.add( new Test "replace+capped", -> setDefaults(true, true, false,false,true) )
  tests.add( new Test "reflow+raw",     -> setDefaults(true, false,true, false,false) )
  tests.add( new Test "reflow+capped",  -> setDefaults(true, false,true, false,true) )
  tests.add( new Test "timeout+raw",    -> setDefaults(true, false,false,true, false) )
  tests.add( new Test "timeout+capped", -> setDefaults(true, false,false,true, true) )
  console.log "Test queue: #{tests.testQueue}"
  tests.runNextTestIfExists()


handleResultsFromRun = (results, testName='unnamedTest') ->
  console.log "Results for test "
  avg = results.reduce( (x,y) -> x+y ) / results.length
  console.log "max: #{Math.max results...}, min: #{Math.min results...}, avg: #{avg}"

$ ->
  setupBenchmarkUI()
