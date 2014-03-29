###
config
###

# animate ALL the things!
@css_animation = true

# cache selectors for great justice
@use_cached_selectors = true

# only one of the below css animation techniques may be set to true
@replace_technique = false
@reflow_technique  = false
@timeout_technique = true

# load css sheets of images instead of individual files
@use_css_sheets = true

# use the 60 events per second capped rollup stream instead of raw?
@use_capped_stream = true

# send cleanup events when closing event streams for SUPER LAME servers like heroku :(
# heroku labs:enable websockets may now resolve this!
@force_stream_close = true

# some urls
emojistatic_img_path = 'http://emojistatic.github.io/images/32/'
emojistatic_css_uri  = 'http://emojistatic.github.io/css-sheets/emoji-32px.min.css'

###
inits
###
@score_cache = {}
@selector_cache = {}

@iOS = false
p = navigator.platform
@iOS = true if( p == 'iPad' || p == 'iPhone' || p == 'iPod' || p == 'iPhone Simulator' || p == 'iPad Simulator' )

###
methods related to the polling UI
###
# grab the initial data and scores and pass along to draw the grid
@refreshUIFromServer = (callback) ->
  $.get('/api/rankings', (response) ->
    drawEmojiStats(response, callback)
  , "json")

###
methods related to the streaming UI
###
@startScoreStreaming = ->
  if use_capped_stream then startCappedScoreStreaming() else startRawScoreStreaming()

@startRawScoreStreaming = ->
  console.log "Subscribing to score stream (raw)"
  @source = new EventSource('/subscribe/raw')
  @source.onmessage = (event) -> incrementScore(event.data)

@startCappedScoreStreaming = ->
  console.log "Subscribing to score stream (60eps rollup)"
  @source = new EventSource('/subscribe/eps')
  @source.onmessage = (event) -> incrementMultipleScores(event.data)

@stopScoreStreaming = (async=true) ->
  console.log "Unsubscribing to score stream"
  @source.close()
  forceCloseScoreStream(async) if @force_stream_close

@startDetailStreaming = (id) ->
  console.log "Subscribing to detail stream for #{id}"
  @detail_id = id
  @detail_source = new EventSource("/subscribe/details/#{id}")
  @detail_source.addEventListener("stream.tweet_updates.#{id}", processDetailTweetUpdate, false)

@stopDetailStreaming = (async=true) ->
  console.log "Unsubscribing to detail stream #{@detail_id}"
  @detail_source.close()
  forceCloseDetailStream(@detail_id, async) if @force_stream_close

@forceCloseDetailStream = (id, async=true) ->
  console.log "Forcing disconnect cleanup for #{id}..."
  $.ajax({
      type: 'POST'
      url: "/subscribe/cleanup/details/#{id}"
      success: (data) ->
        console.log(" ...Received #{JSON.stringify data} from server.")
      async: async
    })
  true

@forceCloseScoreStream = (async=true) ->
  console.log "Forcing disconnect cleanup for score stream..."
  $.ajax({
      type: 'POST'
      url: "/subscribe/cleanup/scores"
      success: (data) ->
        console.log(" ...Received #{JSON.stringify data} from server.")
      async: async
    })
  true

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

# increment multiple scores from a JSON hash
incrementMultipleScores = (data) ->
  scores = $.parseJSON(data)
  incrementScore(key,value) for key,value of scores

# increment the score of a single emoji char
incrementScore = (id, incrby=1) ->
  if @use_cached_selectors
    [score_selector, container_selector] = get_cached_selectors(id)
  else
    score_selector = document.getElementById("score-#{id}")
    container_selector = document.getElementById(id)

  score_selector.innerHTML = (@score_cache[id] += incrby);
  if css_animation
    # various ways to do this....
    # some discussion at http://stackoverflow.com/questions/12814612/css3-transition-to-highlight-new-elements-created-in-jquery

    if replace_technique
      new_container = container_selector.cloneNode(true)
      new_container.classList.add('highlight_score_update_anim')
      container_selector.parentNode.replaceChild(new_container, container_selector)
      selector_cache[id] = [new_container.childNodes[3], new_container] if use_cached_selectors
    else if reflow_technique
      container_selector.classList.remove('highlight_score_update_anim')
      container_selector.focus()
      container_selector.classList.add('highlight_score_update_anim')
      # this has WAY worse performance it seems like on low power devices
    else if timeout_technique
      container_selector.classList.add('highlight_score_update_trans')
      setTimeout -> container_selector.classList.remove('highlight_score_update_trans')

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
  new_entry.find('time.timeago').timeago()
  tweet_list.prepend( new_entry )
  if css_animation
    new_entry.focus()
    # new_entry.removeClass('new') # no longer needed with animation style

###
general purpose UI helpers
###

String.prototype.endsWith = (suffix) ->
  @indexOf(suffix, @length - suffix.length) isnt -1

###
tweet clientside helper and formatting
BE SURE TWITTER-TEXT-JS is loaded before this!! (TODO: investigate require.js)
###
class Tweet
  constructor: (@status) ->

  text: ->
    twttr.txt.autoLink(@status.text, {urlEntities: @status.links, usernameIncludeSymbol: true, targetBlank: true})

  url: ->
    "https://twitter.com/#{@status.screen_name}/status/#{@status.id}"

  profile_url: ->
    "https://twitter.com/#{@status.screen_name}"

  profile_image_url: ->
    return "http://a0.twimg.com/sticky/default_profile_images/default_profile_4_mini.png" unless @status.profile_image_url?
    @status.profile_image_url.replace('_normal','_mini')

  created_at: ->
    return "#" unless @status.created_at?
    @status.created_at

@Handlebars.templates = {}
$ -> Handlebars.templates.styled_tweet = Handlebars.compile $('#styled-tweet-template').html()

formattedTweet = (tweet, new_marker = false) ->
  styled_tweet_template = Handlebars.compile $('#styled-tweet-template').html()
  wrappedTweet = new Tweet tweet
  context = {
    is_new: if new_marker && css_animation then 'new' else ''
    prepared_tweet_text: emoji.replace_unified( wrappedTweet.text() )
    profile_image_url: wrappedTweet.profile_image_url()
    profile_url: wrappedTweet.profile_url()
    name: emoji.replace_unified( tweet.name )
    screen_name: tweet.screen_name
    created_at: wrappedTweet.created_at()
    url: wrappedTweet.url()
    id: tweet.id
  }
  Handlebars.templates.styled_tweet(context)


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
A quick way to toggle avatar display for demos
###
@toggleAvatars = () ->
  $('#detailview, #tweets').toggleClass('disable-avatars')

###
Secret disco mode (easter egg)
###
@enableDiscoMode = () ->
  @disco_time = true
  console.log "woo disco time!!!!"
  $('body').append("<div id='discoball'></div>")
  $('#discoball').focus()

  start_music = ->
    @audio = new Audio();
    canPlayOgg = !!audio.canPlayType && audio.canPlayType('audio/ogg; codecs="vorbis"') != ""
    canPlayMP3 = !!audio.canPlayType && audio.canPlayType('audio/mpeg; codecs="mp3"') != ""
    if canPlayMP3
      console.log "can haz play mp3"
      @audio.setAttribute("src","/disco/getlucky-64.mp3")
    else if canPlayOgg
      console.log "can haz play ogg"
      @audio.setAttribute("src","/disco/getlucky-64.ogg")
    @audio.load()
    @audio.play()
  setTimeout start_music, 2000

  $('body').addClass('disco')
  $('.emoji_char').addClass('disco')
  $('.navbar').addClass('navbar-inverse')
  $('#discoball').addClass('in-position')

@disableDiscoMode = () ->
  @disco_time = false
  $('#discoball').removeClass('in-position')
  $('.disco').removeClass('disco')
  $('.navbar').removeClass('navbar-inverse')

  kill_music = -> @audio.pause()
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
