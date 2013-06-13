###
config
###
# animate all the things
css_animation = true
# load css sheets of images instead of individual files
use_css_sheets = true
# some urls
emojistatic_img_path = 'http://mroth.github.io/emojistatic/images/32/'
emojistatic_css_uri  = 'http://mroth.github.io/emojistatic/css-sheets/emoji-32px.min.css'

###
inits
###
@score_cache = {}
@selector_cache = {}

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
      @score_cache[emoji_char.id] = emoji_char.score
      selector.append "
        <a href='/details/#{emoji_char.id}' title='#{emoji_char.name}' data-id='#{emoji_char.id}'>
        <li class='emoji_char' id='#{emoji_char.id}' data-title='#{emoji_char.name}'>
          <span class='char emojifont'>#{emoji.replace_unified(emoji_char.char)}</span>
          <span class='score' id='score-#{emoji_char.id}'>#{emoji_char.score}</span>
        </li>
        </a>"
  callback() if (callback)

# getter for cached score_selector elements
get_cached_selectors = (id) ->
  if @selector_cache[id] != undefined
    return [@selector_cache[id][0], @selector_cache[id][1]]
  else
    score_selector = document.getElementById("score-#{id}")
    container_selector = document.getElementById(id)
    @selector_cache[id] = [score_selector, container_selector]
    return [score_selector, container_selector]

# increment the score of a single emoji char
incrementScore = (id) ->
  # TODO: figure out how to profile and either remove cached selectors or enable
  # http://jsperf.com/getelementbyid-vs-keeping-hash-updated/edit
  use_cached_selectors = false
  if use_cached_selectors
    [score_selector, container_selector] = get_cached_selectors(id)
  else
    score_selector = document.getElementById("score-#{id}")
    container_selector = document.getElementById(id)

  score_selector.innerHTML = (@score_cache[id] += 1);
  if css_animation
    replace_technique = true
    reflow_technique = false
    if replace_technique
      new_container = container_selector.cloneNode(true)
      new_container.classList.add('highlight_score_update')
      # if @disco_time is true
      #   new_container.className = 'emoji_char highlight_score_update disco'
      # else
      #   new_container.className = 'emoji_char highlight_score_update'
      container_selector.parentNode.replaceChild(new_container, container_selector)
      selector_cache[id] = [new_container.childNodes[3], new_container] if use_cached_selectors
    else if reflow_technique
      # replacement for jquery container_selector.addClass('highlighted') - WARNING: BRITTLE!
      container_selector.classList.remove('highlight_score_update')
      container_selector.focus()
      container_selector.classList.add('highlight_score_update')
      # focus needed because of http://stackoverflow.com/questions/12814612/css3-transition-to-highlight-new-elements-created-in-jquery
      # this has WAY worse performance it seems like on low power devices

###
detail page/view UI helpers
###
@emptyTweetList = ->
  tweet_list = $('#tweet_list')
  tweet_list.empty()

@appendTweetList = (tweet, new_marker = false) ->
  tweet_list = $('#tweet_list')
  tweet_list_elements = $("#tweet_list li")
  tweet_list_elements.last().remove() if tweet_list_elements.size() >= 20
  new_entry = $(formattedTweet(tweet, new_marker))
  tweet_list.prepend( new_entry )
  if css_animation
    new_entry.focus()
    # new_entry.removeClass('new') # no longer needed with animation style

###
general purpose UI helpers
###
String.prototype.linkifyHashtags = () ->
  this.replace /#(\w+)/g, "<a href='https://twitter.com/search?q=%23$1&src=hash' target='_blank'>#$1</a>"
String.prototype.linkifyUsernames = () ->
  this.replace /@(\w+)/g, "<a href='https://twitter.com/$1' target='_blank'>@$1</a>"
String.prototype.linkifyUrls = () ->
  # this.replace /(https?:\/\/[^\s]+)/g, "<a href='$1' target='_blank'>$1</a>"
  this.replace /(https?:\/\/t.co\/\w+)/g, "<a href='$1' target='_blank'>$1</a>"
String.prototype.linkify = () ->
  this.linkifyUrls().linkifyUsernames().linkifyHashtags()

formattedTweet = (tweet, new_marker = false) ->
  tweet_url = "http://twitter.com/#{tweet.username}/status/#{tweet.id}"
  #mini_profile_url = tweet.avatar.replace('_normal','_mini')
  prepared_tweet = tweet.text.linkify()
  class_to_be = "styled_tweet"
  class_to_be += " new" if new_marker && css_animation
  "<li class='#{class_to_be}'>
  <i class='icon-li icon-angle-right'></i>
  <blockquote class='twitter-tweet'>
   <p>#{emoji.replace_unified prepared_tweet}</p>
   &mdash; <strong>#{tweet.name}</strong> (@#{tweet.screen_name})
    <a class='icon' href='https://twitter.com/intent/tweet?in_reply_to=#{tweet.id}'><i class='icon-reply'></i></a>
    <a class='icon' href='https://twitter.com/intent/retweet?tweet_id=#{tweet.id}'><i class='icon-retweet'></i></a>
    <a class='icon' href='https://twitter.com/intent/favorite?tweet_id=#{tweet.id}'><i class='icon-star'></i></a>
    <a class='icon' href='#{tweet_url}'><i class='icon-external-link'></i></a>
   </blockquote>
   </li>"

###
Polling
###
@startRefreshTimer = ->
  @refreshTimer = setInterval refreshUIFromServer, 3000

@stopRefreshTimer = ->
  clearInterval(@refreshTimer)

###
Shit to dynamically load css-sheets only on browsers that don't properly support emoji fun
###
@loadEmojiSheet = (css_url) ->
  cssId = 'emoji-css-sheet' # you could encode the css path itself to generate id..
  if (!document.getElementById(cssId))
    head  = document.getElementsByTagName('head')[0]
    link  = document.createElement('link')
    link.id   = cssId
    link.rel  = 'stylesheet'
    link.type = 'text/css'
    link.href = css_url
    link.media = 'all'
    head.appendChild(link)

###
Secret disco mode (easter egg)
###
@enableDiscoMode = () ->
  @disco_time = true
  $('body').append("<div id='discoball'></div>")
  $('#discoball').focus()
  disco_embed = "
  <audio autoplay='autoplay'>
    <source src='http://mroth.info/disco/getlucky-64.mp3' type='audio/mpeg' />
    <source src='http://mroth.info/disco/getlucky-64.ogg' type='audio/ogg' />
  </audio>
  "
  $('#discoball').html(disco_embed)
  $('body').addClass('disco')
  $('.emoji_char').addClass('disco')
  $('.navbar').addClass('navbar-inverse')
  $('#discoball').addClass('in-position')

@disableDiscoMode = () ->
  @disco_time = false
  $('#discoball').removeClass('in-position')
  $('.disco').removeClass('disco')
  $('.navbar').removeClass('navbar-inverse')
  kill_music = -> $('#discoball').empty().remove()
  setTimeout kill_music, 2000

initDiscoMode = () ->
  @disco_time = false
  disco_keys = [68,73,83,67,79]
  disco_index = 0
  $(document).keydown (e) ->
    if e.keyCode is disco_keys[disco_index++]
      if disco_index is disco_keys.length
        enableDiscoMode()
    else
      disco_index = 0

  $(document).keyup (e) ->
      if e.keyCode is 27
        if disco_time is true
          disableDiscoMode()

###
Configuration vars we need to set globally
###
$ ->
  emoji.img_path = emojistatic_img_path
  emoji.init_env()
  console.log "INFO: js-emoji replace mode is #{emoji.replace_mode}"
  if emoji.replace_mode == 'css' && use_css_sheets
    console.log "In a browser that supports CSS fanciness but not emoji characters, dynamically injecting css-sheet!"
    emoji.use_css_imgs = true
    loadEmojiSheet(emojistatic_css_uri)

  initDiscoMode()
