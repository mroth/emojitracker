# emojitrack
emojitrack tracks realtime emoji usage on twitter!

Components of this project:

 - emojitrack-web {you are here!}
 - emojitrack-streamer
    * ruby version (current)
    * node version (experimental)
 - emojitrack-feeder

Many of the libraries emojitrack uses have also been carved out into independent open-source projects, see the following:

 - [emoji_data.rb](http://github.com/mroth/emoji_data.rb)
 - [emojistatic](http://github.com/mroth/emojistatic)

## emojitrack-web
This is the main web application for emojitracker and its APIs.  

This used to contain everything, but things are moving out to other repos.

## Development Setup
### Full stack
 1. Make sure you have Ruby 2.0.0 installed (preferably managed with RVM or rbenv so that the `.ruby-version` for this repository will be picked up).
 2. Get the repository and basic dependencies going:

        git clone mroth/emojitrack
        cd emojitrack
        bundle install --without=production

 3. Copy `.env-sample` to `.env` and configure required variables.
 4. Make sure you have Redis installed and running.  The rules in `lib/config.rb` currently dictate the order a redis server instance is looked for.
 5. Run all processes via `foreman start`.

Be sure to note that while the processing power is fairly managable, the feeder component of emojitrack requires on it's own about 1MB/s of downstream bandwith, and ~250KB/s of upstream.  You can use the `MAX_TERMS` environment variable to process less emoji chars if you don't have the bandwidth where you are.

### Frontend development only

You can do work on the web component only by utilizing the hosted production redis instance.  First, follow the above steps for setting stuff up, but steps #1 and #2 only.

Then, set `REDIS_URL` environment variable via `.env` to be the full URI of the production redis instance (get it from @mroth if you are a developer on this project).

Note, if you do this, **DO NOT RUN THE FEEDER PROCESS** as it will risk corrupting our production data, just run the *web component only* with `foreman start web`.
