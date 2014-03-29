require 'rack-cache'
require 'dalli'
require 'memcachier'

# Defined in ENV on Heroku. To try locally, start memcached and uncomment:
# ENV["MEMCACHIER_SERVERS"] = "localhost"
if memcache_servers = ENV["MEMCACHIER_SERVERS"]
  use Rack::Cache,
    verbose: true,
    metastore:   "memcached://#{memcache_servers}",
    entitystore: "memcached://#{memcache_servers}"
end

require "./web"
require "./web_api"
require "./web_admin"
require "./web_stream"

$stdout.sync = true
use Rack::Deflater

map('/')            { run WebApp }
map('/api')         { run WebAPI }
map('/admin')       { run WebAdmin }
map('/subscribe')   { run WebStreamer }
