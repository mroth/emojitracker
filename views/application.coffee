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
      selector.append "<li class='emoji_char'><span class='char'>#{emoji_char.char}</span><span class='score'>#{emoji_char.score}</span></li>"

@startRefreshTimer = ->
  @refreshTimer = setInterval refreshUIFromServer, 3000

@stopRefreshTimer = ->
  clearInterval(@refreshTimer)

$ ->
  setTimeout(refreshUIFromServer, 1)
  startRefreshTimer()