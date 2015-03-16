# emojitracker :dizzy:

> Emojitracker.com tracks realtime emoji usage on Twitter.

![capture](http://f.cl.ly/items/1g3s3S460r2k0d200W1f/emojitracker_animated.gif)

Emojitracker is a complex project with a service-oriented architecture, and thus
has now been split up into multiple repositories.  This repository mainly just
serves as table of contents of sorts. Major components of the project are listed
below.

## Core Applications
The core applications of Emojitracker. Note that while these are open source for
educational purposes, they are currently _all rights reserved_. Please contact
me directly if you want to use them for something.

- **[emojitrack-web]**     _web frontend and application server._
- **[emojitrack-feeder]**  _consumes the Twitter Streaming API and feeds our data pipeline._
- **emojitrack-streamer**  _handles streaming updates to clients via SSE._
  * [Ruby version]    _(deprecated)_
  * [NodeJS version]  _(deprecated)_
  * [Go version]      _(production)_
  * [API spec]        _defines the streamer spec, tests servers in staging._

[emojitrack-web]:    https://github.com/mroth/emojitrack-web
[emojitrack-feeder]: https://github.com/mroth/emojitrack-feeder
[Ruby version]:      https://github.com/mroth/emojitrack-streamer
[NodeJS version]:    https://github.com/mroth/emojitrack-nodestreamer
[Go version]:        https://github.com/mroth/emojitrack-gostreamer
[API spec]:          https://github.com/mroth/emojitrack-streamer-spec

## Libraries and Tools
Most of the generalizable and useful pieces of Emojitracker have been carved out
into maintained open-source libraries.  **These libraries are all freely
licensed** (see individual repositories for details).

### Emoji Encoding

- **[emoji_data.rb]**
  _utility library for handling the Emoji vs Unicode nightmare (Ruby)._
- **[emoji-data-js]**
  _utility library for handling the Emoji vs Unicode nightmare (NodeJS port)._
- **[exmoji]**
  _utility library for handling the Emoji vs Unicode nightmare (Elixir/Erlang port)._

[emoji_data.rb]: https://github.com/mroth/emoji_data.rb
[emoji-data-js]: https://github.com/mroth/emoji-data-js
[exmoji]:        https://github.com/mroth/exmoji

### Emoji Assets
- **[emojistatic]**
  _Generates static Emoji assets for a public CDN._
- **[cssquirt]**
  _Embeds images (or directories of images) directly into CSS via the Data URI scheme._

[emojistatic]:   https://github.com/mroth/emojistatic
[cssquirt]:      https://github.com/mroth/cssquirt

### Streaming
- **[sseserver]**
  _High-performance Server-Sent Events endpoint for Go._
- **[sse-bench]**
  _Benchmarks and load tests Server-Sent Events endpoints._

[sseserver]: https://github.com/mroth/sseserver
[sse-bench]: https://github.com/mroth/sse-bench

## Other Information
The narrative version of how version 1.0 of this project was built is in the
Medium post ["How I Built Emojitracker"][essay].  Note however, it is quite out
of date, and does not reflect a substantial amount of change over the years.

[essay]: https://medium.com/@mroth/how-i-built-emojitracker-179cfd8238ac
