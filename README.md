# emojitrack :dizzy:
emojitrack tracks realtime emoji usage on twitter!

This is but a small part of emojitracker's infrastructure.  Major components of the project include:

 - **[emojitrack-web](//github.com/mroth/emojitrack)** _the web frontend and application server (you are here!)_
 - **[emojitrack-feeder](//github.com/mroth/emojitrack-feeder)** _consumes the Twitter Streaming API and feeds our data pipeline_
 - **emojitrack-streamer** _handles streaming updates to clients via SSE_
    * [ruby version](//github.com/mroth/emojitrack-streamer) (deprecated)
    * [nodejs version](//github.com/mroth/emojitrack-nodestreamer)
    * [go version](//github.com/mroth/emojitrack-gostreamer) (currently used in production)
    * [streamer API spec](//github.com/mroth/emojitrack-streamer-spec) _defines the streamer spec, tests servers in staging_


Additionally, many of the libraries emojitrack uses have also been carved out into independent emoji-related open-source projects, see the following:

 - **[emoji_data.rb](//github.com/mroth/emoji_data.rb)** _utility library for handling the Emoji vs Unicode nightmare (Ruby)_
 - **[emoji-data-js](//github.com/mroth/emoji-data-js)** _utility library for handling the Emoji vs Unicode nightmare (Nodejs port)_
 - **[exmoji](//github.com/mroth/exmoji)** _utility library for handling the Emoji vs Unicode nightmare (Elixir/Erlang port)_
 - **[emojistatic](//github.com/mroth/emojistatic)** _generates static emoji assets for a public CDN_

As well as some general purpose libraries:

 - **[cssquirt](//github.com/mroth/cssquirt)** _Embeds images (or directories of images) directly into CSS via the Data URI scheme_
 - **[sse-bench](//github.com/mroth/sse-bench)** _benchmarks Server-Sent Events endpoints_

## emojitrack-web
This is the main web application for the emojitracker frontend and APIs.  

This used to contain everything, but things are moving out to other repos.

### Development Setup
#### Full stack
 1. Make sure you have Ruby 2.1.x installed (preferably managed with RVM or rbenv so that the `.ruby-version` for this repository will be picked up).
 2. Get the repository and basic dependencies going:

        git clone mroth/emojitrack
        cd emojitrack
        bundle install --without=production

 3. Copy `.env-sample` to `.env` and configure required variables.
 4. Make sure you have Redis installed and running.  The rules in `lib/config.rb` currently dictate the order a redis server instance is looked for.
 5. Run all processes via `foreman start`.

Be sure to note that while the processing power is fairly managable, the feeder component of emojitrack requires on its own about 2MB/s of downstream bandwith, and ~450KB/s of upstream.  You can use the `MAX_TERMS` environment variable to process less emoji chars if you don't have the bandwidth where you are.

#### Frontend development only

You can do work on the web component only by utilizing the hosted production redis instance.  First, follow the above steps for setting stuff up, but steps #1 and #2 only.

Then, set `REDIS_URL` environment variable via `.env` to be the full URI of the production redis instance (get it from @mroth if you are a developer on this project).
