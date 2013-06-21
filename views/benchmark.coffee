##############################################################################
# messy and ugly UI methods
##############################################################################
setupBenchmarkUI = ->
  $('li.dropdown').before "
    <form class='navbar-form pull-right'>
      <button id='benchbtn' class='btn btn-danger'>
        <i class='icon-beaker'></i> benchmark
      </button>
      <input id='testnamebox' style='display:none;' type='text' class='span3' disabled>
      <div id='fspcontainer' class='input-prepend' style='margin-bottom:0px; display:none;'>
        <span class='add-on'><i class='icon-time'></i></span>
        <input id='fpsbox' class='span1' type='text' disabled>
      </div>
    </form>"
  initResultsBox()
  @fpsbox_selector = $('#fpsbox')
  @testnamebox_selector = $('#testnamebox')
  $('#benchbtn').click (event) ->
    event.preventDefault()
    startBenchmarking()

testRunUIStart = (testName='unnamedTest') ->
  $('#benchbtn').attr('disabled','disabled')
  @testnamebox_selector.val testName
  @fpsbox_selector.val '-'
  @testnamebox_selector.show()
  $('#fspcontainer').show()

testRunUIStop = ->
  @testnamebox_selector.hide()
  $('#fspcontainer').hide()
  $('#benchbtn').removeAttr('disabled')

displayFPS = (fps) ->
  @fpsbox_selector.val "#{fps} fps"

initResultsBox = ->
  $('body').append '
  <div id="resultsmodal" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
    <div class="modal-header">
      <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
      <h3 id="myModalLabel">Benchmark results</h3>
    </div>
    <div class="modal-body">
      <p>One fine body…</p>
    </div>
    <div class="modal-footer">
      <button class="btn" data-dismiss="modal" aria-hidden="true">Cancel</button>
      <button id="submitbtn" class="btn btn-primary">Submit</button>
    </div>
  </div>
  '

reducePrecision = (key, val) ->
  if val.toFixed then Number(val.toFixed(1)) else val

@displayResultsBox = (results) ->
  $('#resultsmodal > .modal-body').html( "<pre>#{JSON.stringify results, reducePrecision, '  '}</pre>" )
  $('#submitbtn').click ->
    console.log "Submitting report to server...."
    $.post "/benchmarks", { report: JSON.stringify(results, reducePrecision) }, (data) ->
      console.log("...Received #{JSON.stringify data} from server.")
      $('#resultsmodal').modal('hide')

  $('#resultsmodal').modal({keyboard: true, backdrop: 'static'})

setDefaults = (animation,replace,reflow,timeout,capped_stream,cached_selectors) ->
  @use_css_animation = animation
  @replace_technique = replace
  @reflow_technique = reflow
  @timeout_technique = timeout
  @use_capped_stream = capped_stream
  @use_cached_selectors = cached_selectors

##############################################################################
# classes to handle testing, my brain actually works from this point onward
##############################################################################
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

  fpsAvg: ->
    return null if @fpsLog.length < 1
    @fpsLog.reduce( (x,y) -> x+y ) / @fpsLog.length
  fpsMin: -> Math.min @fpsLog...
  fpsMax: -> Math.max @fpsLog...

  results: ->
    {
      test_name: @name,
      results: {
        fps_min: @fpsMin(),
        fps_max: @fpsMax(),
        fps_avg: @fpsAvg()
      }
    }

  printResults: ->
    # console.log "Results for test #{@name} - #{@results()}"
    console.log "Results #{JSON.stringify @results()}"


  run: (callback=null, duration=10) ->
    console.log "*** Beginning test run for: #{@name}"
    @setupFn()
    @initFPSHandler()
    testRunUIStart(@name)

    console.log " - beginning to profile FPS..."
    FPSMeter.run()
    startScoreStreaming()

    endGame = =>
      stopScoreStreaming()
      FPSMeter.stop()
      @deinitFPSHandler()
      @printResults()
      callback() if callback
    setTimeout endGame, duration*1000


class TestRunner
  constructor: () ->
    @testQueue = []
    @resultsArray = []

  add: (test) ->
    @testQueue.push(test)

  results: ->
    {
      timestamp: new Date,
      user_agent: navigator.userAgent,
      window_size: "#{$(window).width()}x#{$(window).height()}",
      server: window.location.hostname,
      benchmarks: (test.results() for test in @resultsArray)
    }

  displayAllResults: ->
    for test in @resultsArray
      test.printResults()
    displayResultsBox( @results() )

  runNextTestIfExists: =>
    if @testQueue.length > 0
      nextTest = @testQueue.pop()
      @resultsArray.push(nextTest)
      setTimeout (=> nextTest.run(@runNextTestIfExists) ), 2500
    else
      console.log "...Test queue is exhausted!"
      testRunUIStop()
      @displayAllResults()
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
  tests.add( new Test "none+raw+nocache",       -> setDefaults(false,false,false,false,false, false) )
  tests.add( new Test "none+raw+cache",         -> setDefaults(false,false,false,false,false, true) )
  tests.add( new Test "none+rollup+nocache",    -> setDefaults(false,false,false,false,true,  false) )
  tests.add( new Test "none+rollup+cache",      -> setDefaults(false,false,false,false,true,  true) )
  tests.add( new Test "replace+raw+nocache",    -> setDefaults(true, true, false,false,false, false) )
  tests.add( new Test "replace+raw+cache",      -> setDefaults(true, true, false,false,false, true) )
  tests.add( new Test "replace+rollup+nocache", -> setDefaults(true, true, false,false,true,  false) )
  tests.add( new Test "replace+rollup+cache",   -> setDefaults(true, true, false,false,true,  true) )
  tests.add( new Test "reflow+raw+nocache",     -> setDefaults(true, false,true, false,false, false) ) unless iOS
  tests.add( new Test "reflow+raw+cache",       -> setDefaults(true, false,true, false,false, true) ) unless iOS
  tests.add( new Test "reflow+rollup+nocache",  -> setDefaults(true, false,true, false,true,  false) ) unless iOS
  tests.add( new Test "reflow+rollup+cache",    -> setDefaults(true, false,true, false,true,  true) ) unless iOS
  tests.add( new Test "timeout+raw+nocache",    -> setDefaults(true, false,false,true, false, false) )
  tests.add( new Test "timeout+raw+cache",      -> setDefaults(true, false,false,true, false, true) )
  tests.add( new Test "timeout+rollup+nocache", -> setDefaults(true, false,false,true, true,  false) )
  tests.add( new Test "timeout+rollup+cache",   -> setDefaults(true, false,false,true, true,  true) )
  console.log "Test queue: #{tests.testQueue}"
  tests.runNextTestIfExists()


$ ->
  setupBenchmarkUI()
