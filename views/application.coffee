###
methods related to the polling UI
###
@refreshUIFromServer = ->
  $.get('/data', (response) ->
    drawEmojiStats(response)
  , "json")

drawEmojiStats = (stats) ->
  selector = $("#data")
  selector.empty()
  for emoji_char in stats
    do (emoji_char) ->
      selector.append "
        <a href='/details/#{emoji_char.id}'>
        <li class='emoji_char' id='#{emoji_char.id}'>
          <span class='char'>#{emoji.replace_unified(emoji_char.char)}</span>
          <span class='score'>#{emoji_char.score}</span>
        </li>
        </a>"

###
methods related to the streaming UI
###
@startStreaming = ->
  @source = new EventSource('/subscribe')
  # @source.addEventListener('stream.score_updates', processScoreUpdate, false)
  @source.onmessage = (event) -> incrementScore(event.data)

@stopStreaming = ->
  @source.close()

# processScoreUpdate = (event) -> incrementScore event.data

incrementScore = (id) ->
  score_selector = $("li\##{id} > .score")
  container_selector = $("li\##{id}")

  count = parseInt score_selector.text()

  score_selector.stop(true)
  container_selector.stop(true)
  score_selector.css 'color', 'red'
  container_selector.css 'background-color', 'lightgreen'
  score_selector.text ++count
  score_selector.animate( {'color': 'black'}, 1000 )
  container_selector.animate( {'background-color': '#eee'}, 1000 )

###
Polling
###
@startRefreshTimer = ->
  @refreshTimer = setInterval refreshUIFromServer, 3000

@stopRefreshTimer = ->
  clearInterval(@refreshTimer)

$ ->
  emoji.img_path = "http://unicodey.com/js-emoji/emoji/"
