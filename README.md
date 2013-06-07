# emojitrack

## Development Setup
### Full stack
 1. Make sure you have Ruby 1.9.3 installed (preferably managed with RVM or rbenv so that the `.ruby-version` for this repository will be picked up).  We require 1.9.3 because TweetStream is not compatible with 2.0 yet.
 1. Get the repository and basic dependencies going:

 		git clone mroth/emojitrack
    	cd emojitrack
    	bundle install --without=production
    	echo "RACK_ENV=development" >> .env

 1. Also in `.env` you'll then need to set the standard Twitter credentials for `CONSUMER_KEY`, `CONSUMER_SECRET`, `OAUTH_TOKEN`, `OAUTH_TOKEN_SECRET`.  Requires credentials with an elevated track limit!  If you don't have that, set `MAX_TERMS` to 400 or less.
 1. Make sure you have redis installed and running.  The rules in `lib/config.rb` currently dictate the order a redis server instance is looked for.
 1. Run all processes via `foreman start`.

Be sure to note that while the processing power is fairly managable, the feeder component of emojitrack requires on it's own about 1MB/s of downstream bandwith, and ~250KB/s of upstream.  You can use the `MAX_TERMS` environment variable to process less emoji chars if you don't have the bandwidth where you are.

### Web only

You can do work on the web component only by utilizing the hosted production redis instance.  First, follow the above steps for setting stuff up, but steps #1 and #2 only.

Then, set `REDISTOGO_URL` environment variable via `.env` to be the full URI of the production redis instance (get it from @mroth if you are a developer on this project).

Note, if you do this, **DO NOT RUN THE FEEDER PROCESS** as it will risk corrupting our production data, just run the *web component only* with `foreman start web`.

## Production setup
For heroku:

    heroku create --stack cedar --addons redistogo:nano memcachier newrelic:standard
    heroku config:add RACK_ENV=production
    heroku config:add CONSUMER_KEY=xxx CONSUMER_SECRET=yyy OAUTH_TOKEN=aaa OAUTH_TOKEN_SECRET=bbb
