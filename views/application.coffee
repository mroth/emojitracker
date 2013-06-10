###
config
###
css_animation = true

###
methods related to the polling UI
###
# grab the initial data and scores and pass along to draw the grid
@refreshUIFromServer = (callback) ->
  $.get('/data', (response) ->
    drawEmojiStats(response, callback)
  , "json")

###
methods related to the streaming UI
###
@startScoreStreaming = ->
  console.log "Subscribing to score stream"
  @source = new EventSource('/subscribe')
  @source.onmessage = (event) -> incrementScore(event.data)

@stopScoreStreaming = ->
  console.log "Unsubscribing to score stream"
  @source.close()

@startDetailStreaming = (id) ->
  console.log "Subscribing to detail stream for #{id}"
  @detail_source = new EventSource("/subscribe/details/#{id}")
  @detail_source.addEventListener("stream.tweet_updates.#{id}", processDetailTweetUpdate, false)

@stopDetailStreaming = ->
  console.log "Unsubscribing to detail stream"
  @detail_source.close()

processDetailTweetUpdate = (event) ->
  appendTweetList $.parseJSON(event.data), true


###
index page UI helpers
###

# redraw the entire emoji grid and scores based on data
drawEmojiStats = (stats, callback) ->
  selector = $("#data")
  selector.empty()
  for emoji_char in stats
    do (emoji_char) ->
      selector.append "
        <a href='/details/#{emoji_char.id}' title='#{emoji_char.name}' data-id='#{emoji_char.id}'>
        <li class='emoji_char' id='#{emoji_char.id}' data-title='#{emoji_char.name}'>
          <span class='char emojifont'>#{emoji.replace_unified(emoji_char.char)}</span>
          <span class='score' id='score-#{emoji_char.id}'>#{emoji_char.score}</span>
        </li>
        </a>"
  callback() if (callback)

# increment the score of a single emoji char
incrementScore = (id) ->
  # score_selector = $("li\##{id} > .score")
  # score_selector = $("\#score-#{id}")
  score_selector = document.getElementById("score-#{id}")
  # container_selector = $("li\##{id}")
  # container_selector = $("\##{id}")
  container_selector = document.getElementById(id)

  # count = parseInt score_selector.text()

  if css_animation
    # container_selector.addClass('highlighted')
    container_selector.className = 'emoji_char highlighted'
    container_selector.focus()
    # focus needed because of http://stackoverflow.com/questions/12814612/css3-transition-to-highlight-new-elements-created-in-jquery
  # score_selector.text ++count
  score_selector.innerHTML = parseInt(score_selector.innerHTML) + 1
  if css_animation
    # container_selector.removeClass('highlighted')
    container_selector.className = 'emoji_char'

###
detail page/view UI helpers
###
@appendTweetList = (tweet, new_marker = false) ->
  tweet_list = $('ul#tweet_list')
  tweet_list_elements = $("ul#tweet_list li")
  tweet_list_elements.last().remove() if tweet_list_elements.size() >= 20
  new_entry = $(formattedTweet(tweet, new_marker))
  tweet_list.prepend( new_entry )
  if css_animation
    new_entry.focus()
    new_entry.removeClass('new')

###
general purpose UI helpers
###
formattedTweet = (tweet, new_marker = false) ->
  tweet_url = "http://twitter.com/#{tweet.username}/status/#{tweet.id}"
  class_to_be = "styled_tweet"
  class_to_be += " new" if new_marker && css_animation
  "<li class='#{class_to_be}'>
    <strong>@#{tweet.username}:</strong>
    <span class='emojifont-restricted'>#{emoji.replace_unified tweet.text}</span>
    <a href='#{tweet_url}'><i class='icon-external-link'></i></a>
  </li>"

###
Polling
###
@startRefreshTimer = ->
  @refreshTimer = setInterval refreshUIFromServer, 3000

@stopRefreshTimer = ->
  clearInterval(@refreshTimer)
###
Configuration vars we need to set globally
###
$ ->
  emoji.img_path = "http://mroth.github.io/emojistatic/images/32/"
