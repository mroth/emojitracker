@startKioskInteractionStreaming = ->
  @interaction_source = new EventSource("/subscribe/kiosk_interaction")
  @interaction_source.addEventListener("stream.interaction.request", processKioskInteractiveRequest, false)

processKioskInteractiveRequest = (event) ->
  request = $.parseJSON(event.data)
  console.log "processed interactive request for ID #{request.char} from #{request.requester}"
  stopDetailStreaming() if detail_source?.readyState == 1 #force close connections left open
  popDetails(request.char, request.requester, request.requester_profile_url)
  setTimeout ( -> $('#detailview').modal('hide') ), 30000

$ ->
  console.log "kiosk mode ENABLED!"

  # add CSS classes for proper restyling
  $('body').addClass('kiosk')
  $('body').addClass('tiles') if window.location.href.endsWith('tiles')
  $('body').addClass('numtiles') if window.location.href.endsWith('numtiles') #above can still trigger on purpose lolz
  $('body').addClass('small') if window.location.href.endsWith('small')

  #start score streaming manually (since we disable the epilepsy check)
  setTimeout startScoreStreaming, 1000

  #listen for interactive requests
  is_interactive = true and (window.location.href.endsWith('tiles') or window.location.href.endsWith('small'))
  if is_interactive
    console.log "kiosk mode set to INTERACTIVE!"
    startKioskInteractionStreaming()

