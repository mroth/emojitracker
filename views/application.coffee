###
methods related to the polling UI
###
@refreshUIFromServer = ->
  $.get('/data', (response) ->
    drawEmojiStats(response)
  , "json")

drawEmojiStats = (stats) ->
  # console.log(s) for s in stats
  selector = $("#data")
  selector.empty()
  for emoji_char in stats
    do (emoji_char) ->
      selector.append "<li class='emoji_char' id='#{emoji_char.id}'><span class='char'>#{emoji_char.char}</span><span class='score'>#{emoji_char.score}</span></li>"

###
methods related to the streaming UI
###
@startStreaming = ->
  @source = new EventSource('/subscribe')
  @source.addEventListener('stream.score_updates', processScoreUpdate, false)

@stopStreaming = ->
  @source.close()

processScoreUpdate = (event) -> incrementScore event.data

incrementScore = (id) ->
  score_selector = $("li\##{id} > .score")
  count = parseInt score_selector.text()

  score_selector.stop(true)
  score_selector.css 'color', 'red'
  score_selector.text ++count
  score_selector.animate( {color: 'black'}, 1000 )

###
Polling
###
@startRefreshTimer = ->
  @refreshTimer = setInterval refreshUIFromServer, 3000

@stopRefreshTimer = ->
  clearInterval(@refreshTimer)

$ ->
  setTimeout(refreshUIFromServer, 1)
  # startRefreshTimer()
  startStreaming()
