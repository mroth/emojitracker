performance tuning
 - [x] em-syncrhony? (using hiredis for now) √
 - [x] look into not having event for SSE feed (https://developer.mozilla.org/en-US/docs/Server-sent_events/Using_server-sent_events) √
 - [x] css3 hw accel transitions √
 - [ ] push a max amount of updates/second PER char? might not look as cool
 - [ ] use a faster evented web server than thin? unicorn or puma http://blog.codeship.io/2012/05/06/Unicorn-on-Heroku.html
     - unicorn is terrible for this functionality, apparently the only real alternative would be rainbows
 - [x] need to host own images! -- on S3 or cloudfront.  set up with asset_sync?
    + use cache manifest to make sure its cached?
    + this will all be managed via emojistatic!
 - [ ] switch to dynamic loading of css spritesheet for chrome
 - [ ] use rack cache for static pages http://thepugautomatic.com/2012/07/sinatra-with-rack-cache-on-heroku/ (in progress)
 - [ ] set up newrelic for monitoring!
 - [x] disregard RTs? art gets a lot of RTs... √ with basic startswith matching on text

 User experience
 - occassionally reorder.  or just refresh from server which would have same effect?
