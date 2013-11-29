$ ->
  console.log "kiosk mode ENABLED!"

  # add CSS classes for proper restyling
  $('body').addClass('kiosk')
  $('body').addClass('tiles') if window.location.href.endsWith('tiles')
  $('body').addClass('small') if window.location.href.endsWith('small')

  #start score streaming manually (since we disable the epilepsy check)
  setTimeout startScoreStreaming, 1000